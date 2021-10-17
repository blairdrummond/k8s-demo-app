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

# hosts for applications 1 and 2 in ingresses example
variable "app1_host" {
  description = "The hostname for application 1"
}

variable "app2_host" {
  description = "The hostname for application 2"
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

# Provision Digital Ocean Load Balancer
resource "digitalocean_loadbalancer" "public" {
  name   = "k8s-demo-load-balancer"
  region = "tor1"

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 80
    target_protocol = "http"
  }

  healthcheck {
    port     = 22
    protocol = "tcp"
  }
}

# Provision DNS A records that point to the loadbalancer's external IP address.
resource "digitalocean_record" "app1" {
  domain = digitalocean_domain.default.name
  type   = "A"
  name   = "@"  # <your_domain>.site
  value  = digitalocean_loadbalancer.public.ip
}

resource "digitalocean_record" "app1" {
  domain = digitalocean_domain.default.name
  type   = "A"
  name   = "app2" # app2.<your_domain>.site
  value  = digitalocean_loadbalancer.public.ip
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
    targetRevision: '@cbrown/ingress-refactor'
    path: manifests
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

  depends_on = [kubectl_manifest.argocd]
}

# Bootstrap NGINX ingress controller manifest so that the UID of the DigitalOcean load balancer can
# be passed as a pod annotation

resource "kubectl_manifest" "nginx_ingress_controller" {
  yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  annotations:
    kubernetes.digitalocean.com/load-balancer-id: "${digitalocean_loadbalancer.public.id}"
    service.beta.kubernetes.io/do-loadbalancer-size-slug: "lb-small"
  labels:
    helm.sh/chart: ingress-nginx-2.11.1
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/version: 0.34.1
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/component: controller
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  ports:
    - name: http
      port: 80
      protocol: TCP
      targetPort: http
    - name: https
      port: 443
      protocol: TCP
      targetPort: https
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/component: controller
YAML

  depends_on = [kubectl_manifest.argocd]
}

# Bootstrap ingress resources so that hosts don't have to be hard-coded in manifest
resource "kubectl_manifest" "ingresses" {
  yaml_body = <<YAML
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: echo-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - ${var.app1_host}
    - ${var.app2_host}
    secretName: echo-tls
  rules:
  - host: ${var.app1_host}
    http:
      paths:
      - backend:
          serviceName: app1
          servicePort: 80
  - host: ${var.app2_host}
    http:
      paths:
      - backend:
          serviceName: app2
          servicePort: 80
YAML

  depends_on = [kubectl_manifest.argocd]
}