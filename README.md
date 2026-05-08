# DevOps Genie Helm Charts

Helm charts for **[DevOps Genie](https://devopsgenie.ai)** — AI-powered DevOps automation.

## Repository structure

```
devopsgenie-charts/
├── charts/
│   └── dg-platform-agent/      # DevOps Genie Agent for client clusters
├── README.md
└── (gh-pages branch: index.yaml, *.tgz, index.html)
```

- **Source:** `main` branch holds chart source under `charts/`.
- **Helm repo:** The `gh-pages` branch holds the built repo (`index.yaml`, `.tgz` packages). GitHub Pages serves the Helm index.

## Charts

| Chart | Description |
|-------|-------------|
| [dg-platform-agent](charts/dg-platform-agent/) | DevOps Genie Agent — deploys the controller, agent-sandbox, and SandboxTemplate into your cluster |

## Quick start

```bash
# Add the Helm repo
helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts/
helm repo update

# Create namespace and secrets
kubectl create namespace devopsgenie

kubectl create secret docker-registry devopsgenie-pull-secret \
  --docker-server=registry.devopsgenie.ai \
  --docker-username=<registry-username> \
  --docker-password=<registry-password> \
  -n devopsgenie

kubectl create secret generic dg-platform-agent \
  --from-literal=DG_API_KEY=<your-api-key> \
  -n devopsgenie

# Install
helm install dg-agent devopsgenie/dg-platform-agent \
  --set credentials.existingSecret=dg-platform-agent \
  --set imageCredentials.existingSecret=devopsgenie-pull-secret \
  --namespace devopsgenie
```

See [charts/dg-platform-agent/README.md](charts/dg-platform-agent/README.md) for full configuration details.

## Image registry

Container images are published to the private DevOps Genie Harbor registry:

- `registry.devopsgenie.ai/devopsgenie-agent/dg-controller`
- `registry.devopsgenie.ai/devopsgenie-agent/dg-agent-pod`

Your cluster needs a pull secret. See
[Private Registry Setup](charts/dg-platform-agent/README.md#private-registry-setup) for instructions.

## Adding this Helm repo

```bash
helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts/
helm search repo devopsgenie
```

## Documentation

- Chart documentation: [charts/dg-platform-agent/README.md](charts/dg-platform-agent/README.md)
- Product documentation: [docs.devopsgenie.ai](https://docs.devopsgenie.ai)

## License

See the license applicable to each chart or product.
