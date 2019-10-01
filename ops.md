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
gcloud compute disks snapshot gke-baas0-fff79c5e-dyn-pvc-d0846f83-df05-11e9-8a31-42010a8001be
```
It may be better to stop blockchain node [to get consistent snapshot with high probability](https://cloud.google.com/compute/docs/disks/snapshot-best-practices). Here is how you can do it for example with eth node:
```bash
kubectl -n dev-eth-0 scale statefulset dev-eth0-parity --replicas=0
``` 
Wait 1 minute and then create the snapshot. Use following command to start node again:
```bash
kubectl -n dev-eth-0 scale statefulset dev-eth0-parity --replicas=1
```
