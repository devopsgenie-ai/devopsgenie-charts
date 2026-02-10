# DevOps Genie SRE Agent

Helm chart for **DevOps Genie SRE Agent** – an AI agent for cloud troubleshooting and alert investigation. This chart is a branded distribution of the [HolmesGPT](https://github.com/HolmesGPT/holmesgpt) SRE agent (fork).

## Prerequisites

- Kubernetes 1.19+
- Helm 3

## Install

```bash
helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts/
helm repo update
helm install sre-agent devopsgenie/devops-genie-sre-agent -n <namespace> --create-namespace
```

## Default image

The chart defaults to the GitHub Container Registry image:

- `ghcr.io/devopsgenie-ai/devops-genie-sre-agent:0.1.0`

Override in values:

```yaml
registry: ghcr.io
image: devopsgenie-ai/devops-genie-sre-agent:0.1.0  # or use :latest
```

## Configuration

See [values.yaml](values.yaml) for toolsets, MCP addons (AWS, GCP, Azure, GitHub, MariaDB), autoscaling, and RBAC options. The chart preserves the same structure as the upstream HolmesGPT chart for compatibility.

## Links

- [DevOps Genie SRE Agent repo](https://github.com/devopsgenie-ai/devops-sre-agent)
- [Distribution strategy](https://github.com/devopsgenie-ai/devops-sre-agent/blob/main/DISTRIBUTION_STRATEGY.md)
