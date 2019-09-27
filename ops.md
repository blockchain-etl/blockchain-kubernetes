Here is short HOWTO to maintain and troubleshoot GKE and cryptonodes.

You may also use [official doc](https://cloud.google.com/kubernetes-engine/docs/troubleshooting) to troubleshoot GKE cluster.

We assume kubectl default context is configured correctly to connect to the required cluster. 

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

Get peers count, 
* parity, look before `peers` word
```bash
kubectl -n dev-eth-0 logs --tail=10 dev-eth0-parity-0
```
* bitcoind, it should be 8+
```bash
kubectl -n dev-btc-0 exec -it  dev-btc0-bitcoind-0 bash
bitcoin-cli  -datadir=/data -getinfo|grep connections
```
