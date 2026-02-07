# devopsgenie-charts

Helm charts, deployment manifests, and documentation for **DevOps Genie** and related products from [devopsgenie-ai](https://github.com/devopsgenie-ai).

## Contents

| Path | Description |
|------|-------------|
| [charts/devops-genie](charts/devops-genie/) | Helm chart for deploying DevOps Genie on Kubernetes |
| [docker-compose](docker-compose/) | Docker Compose setup for EC2 or any Docker host |

## Quick start

### Kubernetes (Helm)

```bash
helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts/
helm repo update
helm install devops-genie devopsgenie/devops-genie -f my-values.yaml
```

See [charts/devops-genie/README.md](charts/devops-genie/README.md) for chart options and [docs.devopsgenie.ai](https://docs.devopsgenie.ai) for full documentation.

### Docker Compose (EC2 / single host)

```bash
cd docker-compose
cp .env.example .env
# Edit .env with your API keys and settings
docker compose up -d
```

See [docker-compose/README.md](docker-compose/README.md) for details.

## Documentation

Documentation (installation, configuration) is hosted at **https://docs.devopsgenie.ai** (repo: [devops-genie-docs](https://github.com/devopsgenie-ai/devops-genie-docs)).

Helm repo: **https://devopsgenie-ai.github.io/devopsgenie-charts/**

## Image registry

Container images are published to GitHub Container Registry (GHCR):

- `ghcr.io/devopsgenie-ai/devops-genie`

You need a GitHub Personal Access Token with `read:packages` to pull private images. See [docs.devopsgenie.ai](https://docs.devopsgenie.ai) for authentication.

## Adding this Helm repo

```bash
helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts/
helm search repo devopsgenie
```

## Publishing (maintainers)

Charts are published via the **Publish Helm charts** workflow (on release or manual run). It builds the Helm package, merges the index, and deploys to GitHub Pages.

If you see *"Get Pages site failed"*: enable Pages in **Settings → Pages → Build and deployment → Source: GitHub Actions**. The workflow also tries to enable Pages automatically when the repo allows it.

## License

See the license applicable to each chart or product.
