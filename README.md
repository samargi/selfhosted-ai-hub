# selfhosted-ai-hub
**Chat & workflows for teams or family — fully self-hosted.**

Minimal, self-hosted ChatGPT-style environment for groups.  
Focus: **small stack**, **secure by default**, **easy to run**.

## Services

- **Open WebUI (Port 443)** – Chat interface (default access via HTTPS)
- **n8n (Port 4443)** – Automation, flows, scheduled jobs
- **PostgreSQL** – Metadata/audit (pgvector optional)
- **Qdrant (Port 4444)** – Embeddings & semantic search (or use pgvector)
- **MinIO (Port 4445)** – Object storage for raw docs
- **Ingestion service** (Python) – OCR → chunk → embed → index
- **Litellm (Port 9090)** – Refer to Litellm documentation for full setup details.
- **Redis** – Caching for improved response times and efficiency
- **no-ip DynDNS** – Simple DNS when exposing to the internet


## Use Cases

The selfhosted-ai-hub offers unique solutions for both family environments and corporate settings, facilitating efficient collaboration and personalized AI experiences.

### Family AI Hub

- **Collaborative Environment**: Easily set up an AI-driven interface for family use, allowing members to interact, share AI insights, or orchestrate tasks together from one private ecosystem.
- **Education and Learning**: Utilize the environment to support learning endeavors, acting as a smart assistant for homework or educational projects.
- **Connected Tools**: Introduce new and unique tools into the AI hub for family projects, such as planning applications, shared calendars, or content generation.

### Private Corporate AI

- **Document Indexing and Search**: Leverage Qdrant for embedding and semantic searches across corporate documentation, ensuring quick access and easy navigation of critical resources.
- **Team Collaboration Boost**: Facilitate project management and task automation within teams, using n8n for workflows and automated jobs, thus streamlining processes.
- **Development Integration**: Integrate AI capabilities directly with development tools like VSCode, providing coding assistance and improving productivity while ensuring sensitive data remains within your private cloud.
- **Private Cloud Security**: All data and interactions remain within a secure, private cloud, adhering to organizational compliance without exposure to external services.

## Quick Start

### 1) Install Docker
- Windows: Docker Desktop + WSL2 backend  
- macOS/Linux: Docker Engine (or Docker Desktop)

### Managing Services with Makefile

#### Starting and Stopping Services
- **Start the Services**:
  Run the following command to start all services in detached mode.
  ```sh
  make start
  ```

- **Stop the Services**:
  Stop all currently running services gracefully.
  ```sh
  make stop
  ```

- **Restart the Services**:
  To restart all services, ensuring they're refreshed.
  ```sh
  make restart
  ```

### Service Access

- **Open WebUI**: Accessible by default on HTTPS at `https://localhost`
- **n8n**: Access through port 4443 `https://localhost:4443`
- **Qdrant**: Access through port 4444 `https://localhost:4444`
- **MinIO**: Access through port 4445 `https://localhost:4445`
- **Litellm**: Access through port 9090 `https://localhost:9090`

### Configuration for Litellm

To set up Litellm, first copy the example configuration:

```sh
cp ./etc/litellm/config.yaml.example ./etc/litellm/config.yaml
```

Edit `config.yaml` to include your specific configurations. For detailed guidance, visit [Litellm Documentation](https://docs.litellm.ai/docs/).

### Notes

- Each service is run on a dedicated port, allowing simplified path management and direct access.

### Firewall Configuration

To ensure traffic flows correctly within your network, ensure your firewall settings allow traffic on these ports and from your expected IP ranges, maintaining both security and accessibility.

By following these steps, you'll establish a secure VPN connection and ensure outside users can access your services via an authenticated and encrypted tunnel.

### Firewall Configuration

To ensure traffic flows correctly within your network, ensure your firewall settings allow traffic on these ports and from your expected IP ranges, maintaining both security and accessibility.

By following these steps, you'll establish a secure VPN connection and ensure outside users can access your services via an authenticated and encrypted tunnel.

## SSL Certificates Configuration with Caddy

Using Caddy, you can automatically manage SSL certificates with Let's Encrypt, removing the need for manual CSR and certificate handling.

### Steps for Automatic SSL Setup

1. **Ensure Caddyfile Configuration**:

   Make sure your `Caddyfile` in the `etc/Caddy` directory is correctly set up with your domain(s). You can specify your domain and any necessary proxy settings there. No manual certificate management is needed as Caddy handles it automatically.

2. **Start Caddy**:

   With the provided configuration, Caddy will automatically request and renew SSL certificates from Let's Encrypt when started.

3. **Verify Secure Connection**:

   After starting Caddy, verify that your services are accessible over HTTPS. Certificates are automatically managed by Caddy, simplifying secure access management without manual intervention.

These steps utilize Caddy's built-in automation to secure your services with SSL certificates from Let's Encrypt, easing the deployment and maintenance burden.

### Important Notes

- **CSR Use**: CSRs serve a one-time purpose for each certificate issuance. Renewing or obtaining new certificates will typically involve creating new CSRs.
- **Security Practices**: It is crucial to secure the private keys generated alongside your CSRs to maintain encryption and access security.

### Additional Commands

- **Clear Logs for a Service**:
  Use this to clear logs of a specified service (e.g., Caddy) easily.
  ```sh
  make clear-logs selfhosted-ai-hub-caddy-1
  ```

- **Validate Docker Compose Configuration**:
  Check and validate current Docker Compose configurations.
  ```sh
  make env
  ```

