Here are commands to create GKE cluster
```bash
gcloud config set  compute/region us-central1
gcloud config set  compute/zone us-central1-b


gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com


export PROJECT_ID=$(gcloud config get-value project)
export SA_NAME=baas-gke-nodes
export CLUSTER_NAME=baas0

export MASTER_ZONE=us-central1-b
export NODE_LOCATIONS="us-central1-c,us-central1-b"
export K8S_CONTEXT=baas0

gcloud iam service-accounts create $SA_NAME \
    --display-name="baas gke nodes"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/logging.logWriter

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/monitoring.metricWriter

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/monitoring.viewer

gcloud container clusters create $CLUSTER_NAME --create-subnetwork name=${CLUSTER_NAME}-0 --num-nodes 1 --enable-autoscaling --max-nodes=1 --min-nodes=1 --machine-type=n1-highmem-4 --preemptible   --cluster-version latest --enable-network-policy --enable-autorepair --enable-ip-alias  --enable-master-authorized-networks --master-authorized-networks 46.4.94.145/32,159.224.49.180/32,35.195.137.161/32 --no-enable-basic-auth --zone=$MASTER_ZONE --node-locations="$NODE_LOCATIONS" --service-account="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" --project=$PROJECT_ID

gcloud projects add-iam-policy-binding $PROJECT_ID --member=user:$(gcloud config get-value core/account) --role=roles/container.admin
gcloud container clusters get-credentials $CLUSTER_NAME --project=$PROJECT_ID

kubectl config rename-context  gke_${PROJECT_ID}_${MASTER_ZONE}_${CLUSTER_NAME}  $K8S_CONTEXT

kubectl --context $K8S_CONTEXT create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user $(gcloud config get-value core/account)

```
