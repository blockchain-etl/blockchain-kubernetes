We use GCP [Cloud Build](https://cloud.google.com/cloud-build/docs/) to package charts in this repo and push result to GCS bucket.
Check [How-to guides](https://cloud.google.com/cloud-build/docs/how-to) to cover common Cloud Build use cases.
In this manual we explain our Cloud Build configuration step by step.
### Why do we need build?
[Helm](https://helm.sh) can deploy releases into [Kubernetes](https://k8s.io) from file system or repositories. 
Common practice is to add external/remote chart repository into helm and use repo for deploys and updates. 
Thus we can build our charts once to be usable for everyone from chart repository, and we have a standard way to deliver updates - 
just push new chart version into the chart repo. Cloud Build, like other CI/CDs, offloads this part from developers to machines.
### cloudbuild.yaml review   
We use single Cloud Build manifest with [substitutions](https://cloud.google.com/cloud-build/docs/configuring-builds/substitute-variable-values) to pack 2 charts - bitcoind and parity.
Structure of our manifest is the following:
1. `steps`. Build steps, package and push happens here. Files are passed between steps
2. `substitutions`. Variables with default values and override possibility during manual or automatically triggered builds
3. `options`. Various build options
4. `artifacts`. Artifacts [are used](https://cloud.google.com/cloud-build/docs/configuring-builds/store-images-artifacts#storing_artifacts_in)
    to upload build results such as binaries, archives, text files etc to some permanent storage or repository
     
Let's dive in:
#### steps
We use in-project helm cloud builder image just to speed up builds due to smaller image. It's image from 
[GCP helm cloud builder](https://github.com/GoogleCloudPlatform/cloud-builders-community/tree/master/helm), but `gcloud-slim`-based.
You may use [this manual](https://github.com/GoogleCloudPlatform/cloud-builders-community/tree/master/helm#building-this-builder) 
to build your own helm cloud builder image. 

Here is steps description:
1. `helm package` 
    1. install [helm-gcs plugin](https://github.com/hayorov/helm-gcs) to support GCS buckets as chart repository storage
    1. configure helm to use chart repository from substituted environment variables
    1. package chart to archive
1. `add version plugin`. Install [helm-local-chart-version](https://github.com/mbenabda/helm-local-chart-version) plugin
1. `save version to artifact`. Get chart version and save it to file
1. `helm push`. Push packaged chart to chart repository and update repository metadata
#### substitutions
 * `_REGISTRY` base registry domain, use `eu.gcr.io` to save bandwidth with EU deployments
 * `_ENV` environment we build chart for. Used with artifacts 
 * `_CHART_NAME` bitcoind or parity
 * `_HELM_REPO_NAME` local name of chart repository 
 * `_HELM_REPO_URL` chart repository URL we push packaged chart to
 * `_ARTIFACT_URL` GCS bucket path Cloud Build uploads artifacts to on success
 * `_ARTIFACT_FILENAME` file name to store latest build chart version
#### options
 * `env` var `SKIP_CLUSTER_CONFIG` is required by helm cloud builder to skip configuration of kubectl context. It's added to every step. 
 Thus you don't require working GKE cluster in the project where you want to run builds from this cloudbuild manifest.
#### artifacts
 * `location` - path where Cloud Build uploads artifacts on success. We use `_ENV` as a path part to store artifacts for environments separately
 * `paths` - path list of files/directories to upload. We store single file with chart version only
### Manual Cloud Build usage
1. Please meet the requirements from [this readme](README.md)
1. Activate Cloud Build API on GCP side:
    ```bash
    export GCP_PROJECT_ID=$(gcloud config get-value project)
    gcloud services enable cloudbuild.googleapis.com --project=${GCP_PROJECT_ID}
    ```
1. Create GCS buckets to store chart repository and artifacts. We use single bucket in this manual to store both.
    ```bash
   export HELM_REPO_BUCKET=${GCP_PROJECT_ID}-helm-repo
   gsutil mb -p ${GCP_PROJECT_ID} -c standard gs://${HELM_REPO_BUCKET}
   export HELM_REPO_URL=gs://${HELM_REPO_BUCKET}/charts/
   export ARTIFACT_URL=gs://${HELM_REPO_BUCKET}/versions/
    ```
1. [Build](https://github.com/GoogleCloudPlatform/cloud-builders-community/tree/master/helm#building-this-builder) 
    GCP [helm cloud builder](https://github.com/GoogleCloudPlatform/cloud-builders-community/tree/master/helm) to have this builder image in your project
1. Install [helm-gcs plugin](https://github.com/hayorov/helm-gcs)
    ```bash
    # 0.2.2 is the last version with helm 2 support 
    helm plugin install https://github.com/hayorov/helm-gcs --version 0.2.2
    ```
1. Init chart repository in GCS bucket. We have to do it once per every new chart repository
    ```bash
    helm gcs init ${HELM_REPO_URL}
    ```
1. Clone this git repo and change dir to the cloned repo root
1. Run Cloud Build. We build `parity` chart in this example:
    ```bash
   gcloud builds submit --config=cloudbuild.yaml . --project=${GCP_PROJECT_ID} --substitutions=_HELM_REPO_URL=${HELM_REPO_URL},_ARTIFACT_URL=${ARTIFACT_URL},_CHART_NAME=parity,_ARTIFACT_FILENAME=parity-chart-version
    ``` 
    Check console output for `REMOTE BUILD OUTPUT`, it may take some time to finish. You may hit errors during build, here are some examples:
    * "not a valid chart repository"
        ```bash
        Step #0 - "helm package": Error: Looks like "gs://..." is not a valid chart repository or cannot be reached: plugin "scripts/pull.sh" exited with error
        Finished Step #0 - "helm package"
        ERROR
        ```
       It looks like init of GCS chart repo failed/wasn't performed on path specified in the error text. Retry chart repo init, check repo paths match.   
    * "chart already indexed"
        ```bash
        Step #3 - "helm push": chart parity-0.1.38 already indexed. Use --force to still upload the chart
        Step #3 - "helm push": Error: plugin "gcs" exited with error
        Finished Step #3 - "helm push"
        ERROR
        ERROR: build step 3 "gcr.io/.../helm" failed: exit status 1
        ```
        It means that you have this chart version in the repo already. Increasing chart version in `Chart.yaml` file at `version:` line is the recommended way to solve this.
        Then rerun `gcloud builds ...` again.
        
    You may get further support [here](https://cloud.google.com/cloud-build/docs/getting-support)
### Cloud Build trigger configuration
Usually you need to trigger Cloud Build on every push to your Github repo. Take a note - Cloud Build is a paid service, 
check [pricing](https://cloud.google.com/cloud-build/pricing) before proceed.

Use official [docs](https://cloud.google.com/cloud-build/docs/running-builds/create-manage-triggers) to configure triggers,
[Github](https://cloud.google.com/cloud-build/docs/create-github-app-triggers) triggers specially.  We just emphasize key points:
* create one trigger per resulting chart
* use `Included files filter (glob)`, for example `charts/bitcoind/**` for bitcoind chart to trigger corresponding build when related files are changed only.
* specify `Substitution variables`, at least
    1. `_HELM_REPO_URL`
    1. `_ARTIFACT_URL`
    1. `_CHART_NAME`
    1. `_ARTIFACT_FILENAME`
### Teardown / cleanup
You may need to cleanup staff after you've stopped to use Cloud Build. Here is a check list:
* helm cloud builder images in container registry inside your project
* chart repo and artifacts in GCS bucket(s)
* "<project_name>_cloudbuild" GCS bucket to store code for manual Cloud Build submits
* Cloud Build trigger(s) and/or connected repositories   
