Install helm agent(tiller) into the cluster, adjust RBAC
```bash
helm init
kubectl create -f helm-rbac.yaml
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```
