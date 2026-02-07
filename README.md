# devopsgenie-charts

Helm charts, deployment manifests, and documentation for **DevOps Genie** and related products from [devopsgenie-ai](https://github.com/devopsgenie-ai).

## Contents

| Path | Description |
|------|-------------|
| [charts/devops-genie](charts/devops-genie/) | Helm chart for deploying DevOps Genie on Kubernetes |
| [docker-compose](docker-compose/) | Docker Compose setup for EC2 or any Docker host |
| [docs](docs/) | Documentation (install guides, configuration reference) |

## Quick start

### Kubernetes (Helm)

```bash
helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts/
helm repo update
helm install devops-genie devopsgenie/devops-genie -f my-values.yaml
```

See [charts/devops-genie/README.md](charts/devops-genie/README.md) for chart options and [docs](docs/) for full documentation.

### Docker Compose (EC2 / single host)

```bash
cd docker-compose
cp .env.example .env
# Edit .env with your API keys and settings
docker compose up -d
```

See [docker-compose/README.md](docker-compose/README.md) for details.

## Documentation

- **Installation:** [docs/installation.md](docs/installation.md)
- **Configuration:** [docs/configuration.md](docs/configuration.md)

Documentation is also published at: **https://devopsgenie-ai.github.io/devopsgenie-charts/**

## Image registry

Container images are published to GitHub Container Registry (GHCR):

- `ghcr.io/devopsgenie-ai/devops-genie`

You need a GitHub Personal Access Token with `read:packages` to pull private images. See [docs/installation.md](docs/installation.md) for authentication.

## Adding this Helm repo

```bash
helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts/
helm search repo devopsgenie
```

## License

See the license applicable to each chart or product.
