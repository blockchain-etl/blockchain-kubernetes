# Blockchain Kubernetes

Kubernetes manifests for running cryptocurrency nodes.

1. Install kustomize https://github.com/kubernetes-sigs/kustomize/blob/master/docs/INSTALL.md. 

```bash
brew install kustomize
```

1. Build configs:

```bash
kustomize build overlays/eth-prod-1 | kubectl apply -f - && \
kustomize build overlays/eth-prod-2 | kubectl apply -f -
```

