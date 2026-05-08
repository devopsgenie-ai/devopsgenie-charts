#!/usr/bin/env bash
set -euo pipefail

CHART_PATH="${CHART_PATH:-charts/dg-platform-agent}"
RELEASE="${RELEASE:-dg-agent}"
NAMESPACE="${NAMESPACE:-devopsgenie}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

render() {
  helm template "$RELEASE" "$CHART_PATH" --namespace "$NAMESPACE" "$@"
}

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$file"; then
    echo "Expected to find: $expected" >&2
    echo "In file: $file" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq "$unexpected" "$file"; then
    echo "Did not expect to find: $unexpected" >&2
    echo "In file: $file" >&2
    exit 1
  fi
}

base_args=(
  --set credentials.existingSecret=test-secret
  --set imageCredentials.existingSecret=devopsgenie-pull-secret
)

direct_api_key_render="$tmpdir/direct-api-key.yaml"
render \
  --set apiKey=dk_test \
  --set imageCredentials.existingSecret=devopsgenie-pull-secret \
  > "$direct_api_key_render"
assert_contains "$direct_api_key_render" 'DG_API_KEY: "ZGtfdGVzdA=="'
assert_not_contains "$direct_api_key_render" 'DG_AGENT_ID'

inline_registry_render="$tmpdir/inline-registry.yaml"
render \
  --set apiKey=dk_test \
  --set imageCredentials.username=robot-test \
  --set imageCredentials.token=registry-token \
  --set imageCredentials.registry=registry.devopsgenie.ai \
  > "$inline_registry_render"
assert_contains "$inline_registry_render" 'kind: Secret'
assert_contains "$inline_registry_render" 'name: dg-agent-dg-platform-agent-pull-secret'

default_render="$tmpdir/default.yaml"
render "${base_args[@]}" > "$default_render"
assert_contains "$default_render" 'value: "wss://app.devopsgenie.ai/ws/agent"'
assert_contains "$default_render" 'value: "https://app.devopsgenie.ai/api/v1/agents/auth"'
assert_contains "$default_render" 'serviceAccountName: dg-agent-dg-platform-agent-agent-pod'
assert_contains "$default_render" 'automountServiceAccountToken: false'
awk '/kind: SandboxTemplate/{in_template=1} in_template && /containerPort: 8080/{getline; if ($0 ~ /protocol: TCP/) found=1} END{exit found ? 0 : 1}' "$default_render"
assert_contains "$default_render" '169.254.0.0/16'
grep -A1 'DG_CAPABILITY_TERRAFORM_CODEGEN' "$default_render" | grep -Fq 'value: "false"'
grep -A1 'DG_CAPABILITY_K8S_DEPLOYMENT' "$default_render" | grep -Fq 'value: "false"'
grep -A1 'DG_CAPABILITY_CICD_PIPELINE' "$default_render" | grep -Fq 'value: "false"'

external_secret_no_repo_render="$tmpdir/external-secret-no-repo.yaml"
render "${base_args[@]}" \
  --set agentPod.existingSecret=agent-pod-vcs-secret \
  > "$external_secret_no_repo_render"
grep -A1 'DG_CAPABILITY_CICD_PIPELINE' "$external_secret_no_repo_render" | grep -Fq 'value: "false"'

empty_public_egress_values="$tmpdir/empty-public-egress-values.yaml"
cat > "$empty_public_egress_values" <<'YAML'
credentials:
  existingSecret: test-secret
imageCredentials:
  existingSecret: devopsgenie-pull-secret
sandbox:
  networkPolicy:
    publicEgressPorts: []
YAML

empty_public_egress_render="$tmpdir/empty-public-egress.yaml"
render -f "$empty_public_egress_values" > "$empty_public_egress_render"
assert_not_contains "$empty_public_egress_render" 'cidr: 0.0.0.0/0'

legacy_warm_pool_render="$tmpdir/legacy-warm-pool.yaml"
render "${base_args[@]}" --set warmPool.enabled=true > "$legacy_warm_pool_render"
assert_not_contains "$legacy_warm_pool_render" 'kind: SandboxWarmPool'

terraform_root_render="$tmpdir/terraform-root.yaml"
render "${base_args[@]}" \
  --set vcs.token=ghp_vcs \
  --set vcs.infrastructureRepoUrl=https://github.com/acme/infra.git \
  > "$terraform_root_render"
grep -A1 'DG_CAPABILITY_TERRAFORM_CODEGEN' "$terraform_root_render" | grep -Fq 'value: "true"'

k8s_root_render="$tmpdir/k8s-root.yaml"
render "${base_args[@]}" \
  --set vcs.token=ghp_vcs \
  --set vcs.deploymentRepoUrl=https://github.com/acme/k8s.git \
  > "$k8s_root_render"
grep -A1 'DG_CAPABILITY_K8S_DEPLOYMENT' "$k8s_root_render" | grep -Fq 'value: "true"'

external_vcs_secret_render="$tmpdir/external-vcs-secret.yaml"
render "${base_args[@]}" \
  --set agentPod.existingSecret=agent-pod-vcs-secret \
  --set vcs.infrastructureRepoUrl=https://github.com/acme/infra.git \
  --set vcs.deploymentRepoUrl=https://github.com/acme/k8s.git \
  > "$external_vcs_secret_render"
grep -A1 'DG_CAPABILITY_TERRAFORM_CODEGEN' "$external_vcs_secret_render" | grep -Fq 'value: "true"'
grep -A1 'DG_CAPABILITY_K8S_DEPLOYMENT' "$external_vcs_secret_render" | grep -Fq 'value: "true"'
grep -A1 'DG_CAPABILITY_CICD_PIPELINE' "$external_vcs_secret_render" | grep -Fq 'value: "true"'

eso_render="$tmpdir/eso-datafrom.yaml"
render \
  --set credentials.externalSecret.enabled=true \
  --set credentials.externalSecret.secretStoreRef.name=aws-sm \
  --set credentials.externalSecret.secretStoreRef.kind=ClusterSecretStore \
  --set 'credentials.externalSecret.dataFrom[0].extract.key=prod/dg-platform-agent' \
  --set imageCredentials.existingSecret=devopsgenie-pull-secret \
  > "$eso_render"
assert_contains "$eso_render" 'dataFrom:'
assert_contains "$eso_render" 'key: prod/dg-platform-agent'
assert_not_contains "$eso_render" 'key: null'

if render "${base_args[@]}" \
  --set vcs.infrastructureRepoUrl=https://github.com/acme/infra.git \
  --set-string vcs.githubApp.id=12345 \
  > "$tmpdir/incomplete-github-app.yaml" 2> "$tmpdir/incomplete-github-app.err"; then
  echo "Expected incomplete GitHub App auth to fail schema validation" >&2
  exit 1
fi
assert_contains "$tmpdir/incomplete-github-app.err" 'installationId'
assert_contains "$tmpdir/incomplete-github-app.err" 'privateKey'

if render "${base_args[@]}" \
  --set vcs.infrastructureRepoUrl=https://github.com/acme/infra.git \
  > "$tmpdir/missing-vcs-auth.yaml" 2> "$tmpdir/missing-vcs-auth.err"; then
  echo "Expected repo URLs without VCS credentials to fail schema validation" >&2
  exit 1
fi
assert_contains "$tmpdir/missing-vcs-auth.err" 'vcs'

if render --set imageCredentials.existingSecret=devopsgenie-pull-secret > "$tmpdir/missing-api-key.yaml" 2> "$tmpdir/missing-api-key.err"; then
  echo "Expected chart render without apiKey or credentials secret to fail" >&2
  exit 1
fi
assert_contains "$tmpdir/missing-api-key.err" 'apiKey'
assert_not_contains "$tmpdir/missing-api-key.err" 'agentId'

assert_not_contains "$CHART_PATH/README.md" 'raw.githubusercontent.com/devopsgenie-ai/devopsgenie-charts/main/charts/dg-platform-agent/crds/'
