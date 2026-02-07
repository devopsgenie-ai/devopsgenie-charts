# Installation

DevOps Genie can be installed on:

- **Kubernetes** – Helm chart (recommended)
- **EC2 or any Docker host** – Docker Compose

## Prerequisites

- **Container image:** Pull from GitHub Container Registry (GHCR): `ghcr.io/devopsgenie-ai/devops-genie`
- **Authentication:** You need a GitHub Personal Access Token (PAT) with `read:packages` to pull the image if it is private.
- **Anthropic API key:** Required at runtime; obtain from [Anthropic Console](https://console.anthropic.com/).

## Kubernetes (Helm)

1. Add the Helm repo:

   ```bash
   helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts/
   helm repo update
   ```

2. Create a Kubernetes secret with your API keys (do not commit these):

   ```bash
   kubectl create namespace devops-genie
   kubectl create secret generic devops-genie-secret -n devops-genie \
     --from-literal=ANTHROPIC_API_KEY='your-anthropic-key' \
     --from-literal=GITHUB_PERSONAL_ACCESS_TOKEN='your-gh-pat'
   ```

3. Create image pull secret for GHCR:

   ```bash
   kubectl create secret docker-registry ghcr -n devops-genie \
     --docker-server=ghcr.io \
     --docker-username=YOUR_GITHUB_USER \
     --docker-password=YOUR_GITHUB_PAT
   ```

4. Install the chart:

   ```bash
   helm install devops-genie devopsgenie/devops-genie -n devops-genie \
     --set existingSecret=devops-genie-secret \
     --set image.pullSecrets[0]=ghcr
   ```

5. Access the API (port-forward or Ingress):

   ```bash
   kubectl port-forward -n devops-genie svc/devops-genie-devops-genie 8000:8000
   curl http://localhost:8000/health
   ```

See [charts/devops-genie/README.md](../charts/devops-genie/README.md) for full chart options.

## EC2 / Docker Compose

1. Log in to GHCR:

   ```bash
   echo $GITHUB_PAT | docker login ghcr.io -u YOUR_GITHUB_USER --password-stdin
   ```

2. Clone or download this repo, then:

   ```bash
   cd docker-compose
   cp .env.example .env
   # Edit .env: set ANTHROPIC_API_KEY and any optional vars
   docker compose up -d
   ```

3. Verify:

   ```bash
   curl http://localhost:8000/health
   ```

See [docker-compose/README.md](../docker-compose/README.md) for details.
