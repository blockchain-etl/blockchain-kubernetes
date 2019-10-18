Here is short HOWTO to maintain and troubleshoot GKE and cryptonodes.

You may also use [official doc](https://cloud.google.com/kubernetes-engine/docs/troubleshooting) to troubleshoot GKE cluster.

We assume kubectl default context is configured correctly to connect to the required cluster. 

### Diagnose and troubleshooting
Locate required pods
```bash
# get namespaces list
kubectl get ns
# get pods list per namespace dev-eth-0
kubectl -n dev-eth-0 get pod
```
Check pod logs (`-f` to follow)
```bash
kubectl -n dev-eth-0 logs -f dev-eth0-parity-0 --tail=10
```
Check pod info to troubleshoot startup problems, liveness check problems, etc:
```bash
kubectl -n dev-eth-0 describe pod dev-eth0-parity-0
```
Restart pod in case of hung
```bash
kubectl -n dev-eth-0 delete pod dev-eth0-parity-0
```
Check allocated disk size 
```bash
kubectl -n dev-eth-0 get pvc
``` 
Shell exec to container to check/troubleshoot from inside
```bash
kubectl -n dev-eth-0 exec -it dev-eth0-parity-0 bash
``` 

Get blockchain-specific logs
* parity
```bash
kubectl -n dev-eth-0 exec -it dev-eth0-parity-0 bash
tail -f parity.log
```
* bitcoind
```bash
kubectl -n dev-btc-0 exec -it  dev-btc0-bitcoind-0 bash
tail -f debug.log 
```

Get current block count
* parity, look after `Syncing` word
```bash
kubectl -n dev-eth-0 logs --tail=10 dev-eth0-parity-0
```

* bitcoind
```bash
kubectl -n dev-btc-0 exec -it  dev-btc0-bitcoind-0 bash
bitcoin-cli -datadir=/data getblockcount
```

Get peers count 
* parity, look before `peers` word
```bash
kubectl -n dev-eth-0 logs --tail=10 dev-eth0-parity-0
```
* bitcoind, it should be 8+ connections
```bash
kubectl -n dev-btc-0 exec -it  dev-btc0-bitcoind-0 bash
bitcoin-cli  -datadir=/data -getinfo|grep connections
```
### Upgrade cryptonode version 
Let's assume you need to upgrade parity from `v2.5.8-stable` to `v2.5.10-stable`. Here is what you need to do:
* update `values-parity.yaml` you used before to deploy parity or create new `values-parity.yaml` file with following content  
```yaml
image:
  repository: parity/parity
  tag: v2.5.10-stable
```
* upgrade parity helm release in the cluster, we use release named `dev-eth0` in example below
```bash
cd blockchain-kubernetes
helm upgrade dev-eth0 charts/parity/ --reuse-values --force --atomic --values values-parity.yaml
```

### Snapshot disk with blockchain
Let's assume you need to snapshot disk from pod `dev-eth0-parity-0` in namespace `dev-eth-0`. First we need to find what disk is actually used by this pod
```bash
kubectl -n dev-eth-0 describe pod dev-eth0-parity-0
```
Check output for Volumes, my case is
```yaml
Volumes:
  parity-pvc:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  parity-pvc-dev-eth0-parity-0
    ReadOnly:   false
```
We get `ClaimName: parity-pvc-dev-eth0-parity-0`, now we need to find corresponding `PersistentVolume`:
```bash
kubectl -n dev-eth-0 describe pvc parity-pvc-dev-eth0-parity-0 
``` 
Check output for Volumes, my case is
```yaml
Volume:        pvc-d0846f83-df05-11e9-8a31-42010a8001be
```
And now we need to get disk name from PV
```bash
kubectl describe pv pvc-d0846f83-df05-11e9-8a31-42010a8001be
```
Check output for `Source`
```yaml
Source:
    Type:       GCEPersistentDisk (a Persistent Disk resource in Google Compute Engine)
    PDName:     gke-baas0-fff79c5e-dyn-pvc-d0846f83-df05-11e9-8a31-42010a8001be
``` 
We get `gke-baas0-fff79c5e-dyn-pvc-d0846f83-df05-11e9-8a31-42010a8001be`, that's the name of disk we need to snapshot.
You may use [official doc](https://cloud.google.com/compute/docs/disks/create-snapshots) to create snapshot, here is quick example command to do so
```bash
gcloud compute disks snapshot gke-baas0-fff79c5e-dyn-pvc-d0846f83-df05-11e9-8a31-42010a8001be --snapshot-names=dev-eth0-parity
```
It may be better to stop blockchain node [to get consistent snapshot with high probability](https://cloud.google.com/compute/docs/disks/snapshot-best-practices). Here is how you can do it for example with eth node:
```bash
kubectl -n dev-eth-0 scale statefulset dev-eth0-parity --replicas=0
``` 
Wait 1 minute and then create the snapshot. Use following command to start node again:
```bash
kubectl -n dev-eth-0 scale statefulset dev-eth0-parity --replicas=1
```
You may need to convert your snapshot to an image, for example to share the image
```bash
gcloud compute images create parity-2019-10-16 --source-snapshot=dev-eth0-parity
``` 
### Provision cryptonode with pre-existing image
When you have someone who shared pre-synced cryptonode disk image with you, you can create a new disk from this image and use it with your cryptonode, and here is how.
* (optional) copy disk image to your project
```bash
gcloud compute images create parity-2-5-5-2019-10-16 --source-image=parity-2-5-5-2019-10-16 --source-image-project=<SOURCE-PROJECT>
```
Now we have two options - single zone disk or regional disk, choose one
#### Single zone disk
* just create SSD disk from the image, pay attention to zone, it must be the same as your GKE cluster 
```bash
gcloud compute disks create parity-0 --type pd-ssd --zone us-central1-b  --image=parity-2-5-5-2019-10-16 --image-project=<SOURCE-PROJECT>
```
#### Regional disk
Due to `Creating a regional disk from a source image is not supported yet.` we need to perform this task with intermediate steps
* create single zone standard disk from the image
```bash
gcloud compute disks create parity-tmp --type pd-standard --zone us-central1-b  --image=parity-2-5-5-2019-10-16 --image-project=<SOURCE-PROJECT>
```
* create a snapshot from disk we just created. We can then create regional disk from snapshot it the corresponding region
```bash
gcloud compute disks snapshot parity-tmp --snapshot-names=parity-2-5-5-2019-10-16 --storage-location=us-central1 --zone us-central1-b
```
* remove standard disk, we don't need it
```bash
gcloud compute disks delete parity-tmp --zone us-central1-b
```
* create regional SSD disk from the snapshot, use same `replica-zones` as your GKE cluster  
```bash
gcloud compute disks create parity-0 --type pd-ssd --region us-central1 --replica-zones=us-central1-c,us-central1-b --source-snapshot=parity-2-5-5-2019-10-16
```
#### Attaching disk to cryptonode pod
Now we need to create [PersistentVolume in Kubernetes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)(PV) and use this PV with [PersistentVolumeClaim](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims) (PVC) we already have.
* adjust [pv.yaml](pv.yaml)(1 zone disk) or [pv-r.yaml](pv-r.yaml)(regional disk) with your disk name, zones etc. In this manual we assume you have required storage classes already from cryptonode deployment.
* create PV via following command, use one of them:
```bash
kubectl create -f pv.yaml
# or
kubectl create -f pv-r.yaml
```
* shutdown cryptonode:
```bash
kubectl -n prod-eth-0 scale statefulset prod-eth0-parity --replicas=0
``` 
let it some time to shutdown, you can monitor it with `kubectl -n prod-eth-0 get pod -w` usually

* replace existing PVC by a copy with another disk name `parity-0`, I use `parity-pvc-prod-eth1-parity-0` PVC in `prod-eth-1` namespace in the example below:
```bash
# backup just in case
kubectl -n prod-eth-1 get pvc parity-pvc-prod-eth1-parity-0 -o yaml > parity-pvc-prod-eth1-parity-0.yaml 
kubectl -n prod-eth-1 get pvc parity-pvc-prod-eth1-parity-0 -o json|jq '.spec.volumeName="parity-0"'| kubectl -n prod-eth-1 replace --force -f -
```
* start cryptonode up and check logs
```bash
kubectl -n prod-eth-0 scale statefulset prod-eth0-parity --replicas=1
kubectl -n prod-eth-0 get pod -w
kubectl -n prod-eth-0 logs -f prod-eth0-parity-0
``` 
