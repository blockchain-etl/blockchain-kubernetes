Cryptonodes require resources to perform initial sync and to stay in sync.
 
 We'll focus on these resources
* CPU
* Memory
* Disk size
* Disk IOPS and latency

We store full archive nodes with traces/txindex in all cases where possible, so here you'll see maximum cryptonodes requirements. Full (but not archive) node requires less resources.
Data is actual at the end of 2019. 
Let's start from [parity](https://www.parity.io/ethereum/)

## Parity
Parity version 2.5/2.6 loves memory. And it absolutely loves low disk latency, which isn't perfect with cloud disks including SSD. 
Simple IOPS increase may not help, as disk access is more or less single-threaded during sync and thus may be limited by IO latency instead of IOPS.
Local NVMe disk will do it's job for chains like ETC, but it's size is not enough to work with ETH mainnet usually. 
Here is some hack to speedup initial sync - get instance with tons of RAM and preload synced blockchain into OS cache. 
My case was 640GB of RAM and blockchain preload from inside container via `find | xargs cat > /dev/null` or [vmtouch](https://github.com/hoytech/vmtouch/), 
3-5x speedup from 0.5-2 blocks/sec(100-200 tx/sec) to 7-10 blocks/sec (700-1000 tx/sec) and sustained blockchain write near 150MB/s, just $1/hour with preemptible nodes.  
Get presynced spanshot when you can :)

### Initial sync

| Chain | CPU req/lim | Memory req/lim | Disk size | Disk IOPS | Disk latency|
|-------|-------------|----------------|-----------|-----------|-------------|
|ETH mainnet|2/4|20G/30G|4TB SSD|1000+|as low as you can get|
|ETC|2/4|20G/30G|600GB SSD|1000+|as low as you can get|
|Kovan|2/4|20G/30G|500 GB SSD|1000+|as low as you can get|

### Keep chain synced
You may use less resources to keep chain synced, except ETH mainnet. It requires even more resources, than during initial sync.

| Chain | CPU req/lim | Memory req/lim | Disk size | Disk IOPS | Disk latency|
|-------|-------------|----------------|-----------|-----------|-------------|
|ETH mainnet|2/4|20G/30G|4TB SSD|2000+|as low as you can get|
|ETC|0.3/1|15G/20G|600GB SSD|100+|low|
|Kovan|2/4|10G/15G|500 GB SSD|100+|low|

## Bitcoind-like nodes
All the bitcoind-like cryptonodes have similar requirements. 

### Initial sync
It's better to use SSD with BTC and BCH during initial sync or reindex.

| Chain | CPU req/lim | Memory req/lim | Disk size | Disk IOPS | Disk latency|
|-------|-------------|----------------|-----------|-----------|-------------|
| BTC|1/2|2G/3G|400GB SSD|500+|low|
| BCH|1/2|2G/3G|250GB SSD|500+|low|
| DASH|1/2|2G/3G|30GB HDD|50+|medium|
| DOGE|1/2|2G/3G|50GB HDD|50+|medium|
| LTC|1/2|2G/3G|40GB HDD|50+|medium|
| ZCASH|1/2|2G/3G|40GB HDD|50+|medium|

### Keep chain synced
All these nodes require ~ 0.01 CPU to keep chain in sync. You'll need more CPU to start up, warm up, serve RPC requests etc. 

| Chain | CPU req/lim | Memory req/lim | Disk size | Disk IOPS | Disk latency|
|-------|-------------|----------------|-----------|-----------|-------------|
| BTC|0.1/1|2G/3G|400GB HDD|30+|medium|
| BCH|0.1/1|0.5G/1G|250GB HDD|30+|medium|
| DASH|0.1/1|1G/2G|30GB HDD|30+|medium|
| DOGE|0.1/1|2G/3G|50GB HDD|30+|medium|
| LTC|0.1/1|1G/2G|40GB HDD|30+|medium|
| ZCASH|0.1/1|2G/3G|40GB HDD|30+|medium|
