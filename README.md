# blockchain-kubernetes
Kubernetes manifests for running cryptocurrency nodes.

Here is quick HOWTO deploy nodes into GKE env.

### Requirements
* linux/macos terminal 
* git
* gcloud
* kubectl (version from gcloud is ok)
* helm
* follow "Before you begin" part of [GCP manual](https://cloud.google.com/kubernetes-engine/docs/how-to/iam)

### Deploy

* Create GKE cluster:

```bash
gcloud container clusters create baas0 \
    --preemptible \
    --num-nodes 1 
    --enable-autoscaling --max-nodes=1 --min-nodes=1 \
    --machine-type=n1-highmem-4 \
    --zone=us-central1-a 
```

* Init and patch [Helm](https://helm.sh):

```bash

helm init
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```


* Create SSD storage class:

```bash
kubectl create -f sc-ssd.yaml 
```
 
* Copy `example-values-parity.yaml` and `example-values-bitcoind.yaml` to `values-parity.yaml` and `values-bitcoind.yaml`
```bash
cp example-values-parity.yaml values-parity.yaml
cp example-values-bitcoind.yaml values-bitcoind.yaml
```
* Adjust `values-parity.yaml` and `values-bitcoind.yaml`, pay attention to [resource requests and limits](resources.md), IP adresses, volume size, and RPC credentials. Replace `198.51.100.0` and `203.0.113.0` with real IP values of allocated adresses.
```bash
export EDITOR=vi
$EDITOR values-bitcoind.yaml
$EDITOR values-parity.yaml
```
* Deploy cryptonodes
```bash
helm --kube-context $K8S_CONTEXT install charts/parity/ --namespace dev-eth-0 --name dev-eth-0 --values values-parity.yaml
helm --kube-context $K8S_CONTEXT install charts/bitcoind/ --namespace dev-btc-0 --name dev-btc-0 --values values-bitcoind.yaml

``` 
* Use `kubectl describe` to check/troubleshoot, for example:
```bash
kubectl --context $K8S_CONTEXT --namespace dev-eth-0 describe statefulset dev-eth-0-parity
kubectl --context $K8S_CONTEXT --namespace dev-eth-0 describe pod dev-eth-0-parity-0
```
Please check [separate file](ops.md) for more details about additional troubleshooting.

**TIP**: when you need archive parity node to sync up faster - get a tons of RAM and preload synced blockchain into OS cache. My case was 640GB of RAM and blockchain preload from inside container via `find | xargs cat > /dev/null` or [vmtouch](https://github.com/hoytech/vmtouch/), 3-5x speedup  from 0.5-2 blocks/sec(100-200 tx/sec) to 7-10 blocks/sec (700-1000 tx/sec) and sustained blockchain write near 150MB/s, just $1/hour with preemptible nodes.
