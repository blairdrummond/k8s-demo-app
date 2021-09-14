# k8s-demo-app

**FORK THIS REPO**

A little repo to bootstrap a kubernetes cluster.

**Steps:**
1. Create a digital ocean account and get a doctl token.
2. Run `make all` to download all apps (only works on {linux,darwin} x86)
3. Run `terraform apply` and input the appropriate variables.
4. ... Wait a few minutes! You'll have a cluster with argocd, minio, nginx.


## How does it work?

- The makefile installs a bunch of helpful binaries

- The terraform creates the cluster and deploys
  + argocd 
  + an argocd application pointing to the `manifests` folder

- The manifests repo showcases `kustomize` as well as `helm`, to
  show how argocd can deploy apps using either.
