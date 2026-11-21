#!/usr/bin/env bash
# Generate code from the OpenAPI 3.1 contracts in /api.
#   tools/openapi/generate.sh go     -> agent/internal/api/agentapi/agent.gen.go (oapi-codegen, via derived 3.0.3)
#   tools/openapi/generate.sh dart   -> app/packages/hnt_agent_api, app/packages/hnt_cloud_api (openapi-generator dart-dio)
#   tools/openapi/generate.sh all
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOLS="$ROOT/tools/openapi"
BUILD="$ROOT/build/openapi"
OAPI_CODEGEN_VERSION="v2.5.1"

mkdir -p "$BUILD"

gen_go() {
  python3 "$TOOLS/downconvert.py" "$ROOT/api/agent.openapi.yaml" "$BUILD/agent.oas30.yaml"
  mkdir -p "$ROOT/agent/internal/api/agentapi"
  (cd "$ROOT" && go run "github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@${OAPI_CODEGEN_VERSION}" \
      -config "$TOOLS/oapi-codegen.agent.yaml" "$BUILD/agent.oas30.yaml")
}

gen_dart() {
  for api in agent cloud; do
    out="$ROOT/app/packages/hnt_${api}_api"
    rm -rf "$out"
    (cd "$TOOLS" && npx --no-install openapi-generator-cli generate \
      -i "$ROOT/api/${api}.openapi.yaml" \
      -g dart-dio \
      -o "$out" \
      --global-property=apiTests=false,modelTests=false \
      --additional-properties="pubName=hnt_${api}_api,pubDescription=Generated client for the ${api} API (do not edit),serializationLibrary=json_serializable,dateLibrary=core,equalityCheckMethod=equatable,pubPublishTo=none")
    # mutualTLS is handled by the app's AgentTransport (dio HttpClientAdapter with SecurityContext), not the generator.
    echo "Generated $out. Run 'dart run build_runner build -d' inside it."
  done
}

case "${1:-all}" in
  go) gen_go ;;
  dart) gen_dart ;;
  all) gen_go; gen_dart ;;
  *) echo "usage: $0 [go|dart|all]" >&2; exit 2 ;;
esac
