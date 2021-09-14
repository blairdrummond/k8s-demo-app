terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }

    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.11.3"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.4.1"
    }

    http = {
      source = "hashicorp/http"
      version = "2.1.0"
    }
  }
}

# Set the variable value in *.tfvars file
# or using -var="do_token=..." CLI option
variable "do_token" {}
variable "github_username" {
  description = "Your github username"
}
variable "cluster_name" {
  description = "A unique name for your cluster"
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# $ doctl kubernetes options versions
resource "digitalocean_kubernetes_cluster" "cluster" {
  name    = var.cluster_name
  region  = "tor1"
  version = "1.21.3-do.0"

  node_pool {
    name       = "autoscale-worker-pool"
    size       = "s-2vcpu-4gb"
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 3
  }
}

provider "kubernetes" {
  host             = digitalocean_kubernetes_cluster.cluster.endpoint
  token            = digitalocean_kubernetes_cluster.cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.cluster.kube_config[0].cluster_ca_certificate
  )
}

provider "kubectl" {
  host             = digitalocean_kubernetes_cluster.cluster.endpoint
  token            = digitalocean_kubernetes_cluster.cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.cluster.kube_config[0].cluster_ca_certificate
  )
  load_config_file       = false
}


resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    # labels = {
    #   "istio-injection" = "enabled"
    # }
  }
}


data "http" "argocd_manifest" {
  url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
}

data "kubectl_file_documents" "manifests" {
    content = data.http.argocd_manifest.body
}

resource "kubectl_manifest" "argocd" {
  override_namespace = "argocd"

  count     = length(data.kubectl_file_documents.manifests.documents)
  yaml_body = element(data.kubectl_file_documents.manifests.documents, count.index)

  depends_on = [kubernetes_namespace.argocd]
}


# Wait for the ArgoCD CRDs to be defined.
resource "time_sleep" "wait_1_minute" {
  depends_on = [kubectl_manifest.argocd]
  create_duration = "61s"
}

resource "kubectl_manifest" "root_application" {
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-application
  namespace: argocd
spec:
  project: default
  destination:
    namespace: default
    server: https://kubernetes.default.svc
  source:
    repoURL: https://github.com/${var.github_username}/k8s-demo-app.git
    targetRevision: main
    path: manifests
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

  depends_on = [kubectl_manifest.argocd]
}
