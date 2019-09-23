# blockchain-kubernetes
Kubernetes manifests for running cryptocurrency nodes.

Here is quick HOWTO deploy nodes into GKE env.

###Requirements
* linux/macos terminal 
* git
* gcloud
* kubectl (version from gcloud is ok)
* helm
* follow "Before you begin" part of [GCP manual](https://cloud.google.com/kubernetes-engine/docs/how-to/iam)

###Deploy
* Create k8s GKE multi-zone cluster, use at least [n1-highmem4 instances](https://cloud.google.com/compute/docs/machine-types#n1_machine_types)
* [Install](helm.md) [Helm](https://helm.sh)
* Allocate 2 regional IP adresses, use the same region as your GKE cluster
```bash 
export PROJECT_ID=$(gcloud config get-value project)
export REGION=us-central1

gcloud compute addresses create dev-btc-0 --region $REGION  --project=$PROJECT_ID
gcloud compute addresses create dev-eth-0 --region $REGION  --project=$PROJECT_ID

gcloud compute addresses list --project=$PROJECT_ID
```
* Create [SSD storage class](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/ssd-pd), replace *K8S_CONTEXT* with real value.
```bash
export K8S_CONTEXT=baas0
kubectl --context $K8S_CONTEXT create -f sc-ssd.yaml 

``` 
* Copy `example-values-parity.yaml` and `example-values-bitcoind.yaml` to `values-parity.yaml` and `values-bitcoind.yaml`
```bash
cp example-values-parity.yaml values-parity.yaml
cp example-values-bitcoind.yaml values-bitcoind.yaml
```
* Adjust `values-parity.yaml` and `values-bitcoind.yaml`, pay attention to resource requests and limits, IP adresses, volume size, and RPC credentials. Replace `198.51.100.0` and `203.0.113.0` with real IP values of allocated adresses.
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

**TIP**: when you need archive parity node to sync up faster - get a tons of RAM and preload synced blockchain into OS cache. My case was 640GB of RAM and blockchain preload from inside container via `find | xargs cat > /dev/null` or [vmtouch](https://github.com/hoytech/vmtouch/), 3-5x speedup  from 0.5-2 blocks/sec(100-200 tx/sec) to 7-10 blocks/sec (700-1000 tx/sec) and sustained blockchain write near 150MB/s, just $1/hour with preemptible nodes.
