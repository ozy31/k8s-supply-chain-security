#!/usr/bin/env bash
# Creates the kind cluster and a local OCI registry on the kind network.
# Host side the registry is localhost:$REGISTRY_PORT; inside the cluster
# (nodes and Kyverno) it is kind-registry:5000. Both names reach the same
# storage, so a signature pushed through one is visible through the other.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/versions.env"
reg_name=kind-registry

if [[ "$(docker inspect -f '{{.State.Running}}' "$reg_name" 2>/dev/null)" != "true" ]]; then
  docker run -d --restart=always --name "$reg_name" \
    -p "127.0.0.1:${REGISTRY_PORT}:5000" "$REGISTRY_IMAGE" >/dev/null
fi

if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --config "$root/kind/cluster.yaml" --image "$KIND_NODE_IMAGE" --wait 120s
fi

# Tell containerd on each node how to reach the registry.
for node in $(kind get nodes --name "$CLUSTER_NAME"); do
  docker exec "$node" mkdir -p "/etc/containerd/certs.d/${reg_name}:5000"
  docker exec -i "$node" tee "/etc/containerd/certs.d/${reg_name}:5000/hosts.toml" >/dev/null <<TOML
server = "http://${reg_name}:5000"

[host."http://${reg_name}:5000"]
  capabilities = ["pull", "resolve"]
TOML
done

if [[ "$(docker inspect -f '{{json .NetworkSettings.Networks.kind}}' "$reg_name")" == "null" ]]; then
  docker network connect kind "$reg_name"
fi

echo "cluster $CLUSTER_NAME ready (context $KUBE_CONTEXT), registry localhost:${REGISTRY_PORT}"
