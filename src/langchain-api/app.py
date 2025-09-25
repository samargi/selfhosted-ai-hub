import os
from io import BytesIO
from typing import Optional

from fastapi import FastAPI, Header, HTTPException, UploadFile, File, Request
from pydantic import BaseModel

from qdrant_client import QdrantClient
from qdrant_client.http.models import Distance, VectorParams
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain_community.vectorstores import Qdrant
from langchain.text_splitter import RecursiveCharacterTextSplitter

import boto3
import redis

# --- Config ---
API_KEY = os.getenv("API_KEY")
REQUIRE_HEADERS = os.getenv("REQUIRE_HEADERS", "true").lower() == "true"

LITELLM_BASE_URL = os.getenv("LITELLM_BASE_URL")
LITELLM_MODEL = os.getenv("LITELLM_MODEL", "gpt-4o")

QDRANT_URL = os.getenv("QDRANT_URL")
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")

MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT")
# Accept both naming schemes for creds (match your compose)
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY") or os.getenv("MINIO_ROOT_USER")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY") or os.getenv("MINIO_ROOT_PASSWORD")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "documents")

COLLECTION = os.getenv("QDRANT_COLLECTION", "docs")
EMBED_DIM = int(os.getenv("EMBED_DIM", "1536"))  # adjust if you use other embeddings

# --- Clients ---
app = FastAPI()

llm = ChatOpenAI(
    base_url=LITELLM_BASE_URL,
    model=LITELLM_MODEL,
    api_key=os.getenv("OPENAI_API_KEY"),
)
emb = OpenAIEmbeddings(base_url=LITELLM_BASE_URL)

qdrant_http = QdrantClient(url=QDRANT_URL)
r = redis.Redis.from_url(REDIS_URL, decode_responses=True)
s3 = boto3.client(
    "s3",
    endpoint_url=MINIO_ENDPOINT,
    aws_access_key_id=MINIO_ACCESS_KEY,
    aws_secret_access_key=MINIO_SECRET_KEY,
)

# Ensure collection exists
try:
    qdrant_http.get_collection(COLLECTION)
except Exception:
    qdrant_http.recreate_collection(
        COLLECTION,
        vectors_config=VectorParams(size=EMBED_DIM, distance=Distance.COSINE)
    )

# --- Models ---
class AskInput(BaseModel):
    question: str
    top_k: int = 5
    session_id: Optional[str] = None

# --- Helpers ---
def _auth(request: Request):
    if API_KEY and request.headers.get("x-api-key") != API_KEY:
        raise HTTPException(status_code=401, detail="invalid api key")

def _require_headers(customer_id: Optional[str], project_id: Optional[str]):
    if REQUIRE_HEADERS and (not customer_id or not project_id):
        raise HTTPException(status_code=400, detail="customer_id and project_id required")

def _ns(customer_id: str, project_id: str) -> str:
    return f"{customer_id}:{project_id}"

# --- Routes ---
@app.get("/healthz")
def healthz():
    return {"ok": True}

@app.post("/ingest")
async def ingest(
    request: Request,
    customer_id: str = Header(None),
    project_id: str = Header(None),
    file: UploadFile = File(...),
):
    _auth(request)
    _require_headers(customer_id, project_id)
    ns = _ns(customer_id, project_id)

    content = await file.read()
    key = f"{ns}/{file.filename}"
    s3.upload_fileobj(BytesIO(content), MINIO_BUCKET, key)

    text = content.decode(errors="ignore")
    splitter = RecursiveCharacterTextSplitter(chunk_size=1200, chunk_overlap=150)
    chunks = splitter.split_text(text)

    vs = Qdrant(client=qdrant_http, collection_name=COLLECTION, embeddings=emb, namespace=ns)
    vs.add_texts(
        texts=chunks,
        metadatas=[{"source": key, "customer_id": customer_id, "project_id": project_id}] * len(chunks),
    )

    return {"ok": True, "chunks": len(chunks), "key": key}

@app.post("/ask")
async def ask(
    inp: AskInput,
    request: Request,
    customer_id: str = Header(None),
    project_id: str = Header(None),
):
    _auth(request)
    _require_headers(customer_id, project_id)
    ns = _ns(customer_id, project_id)

    vs = Qdrant(client=qdrant_http, collection_name=COLLECTION, embeddings=emb, namespace=ns)
    docs = vs.similarity_search(inp.question, k=inp.top_k)
    context = "\n\n".join(d.page_content for d in docs)

    system = "Vastaa suomeksi. Käytä vain annettua kontekstia, ja jos et tiedä, sano ettet tiedä."
    prompt = f"{system}\n\nKonteksti:\n{context}\n\nKysymys: {inp.question}"

    out = llm.invoke(prompt)
    return {
        "answer": out.content,
        "sources": [d.metadata for d in docs],
        "k": inp.top_k,
    }
