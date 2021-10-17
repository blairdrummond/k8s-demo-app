
## Tutorial

### Automated teardown of resources provisioned by terraform

```bash
terraform apply -destroy
```

## Learning Resources

- [ConfigMap in Kubernetes Explanation](https://www.youtube.com/watch?v=FAnQTgr04mU)
- [ConfigMap in Terraform](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map)
- [DigitalOcean Load Balancer in Terraform](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/loadbalancer#vpc_uuid)

- [Load-Balancer ID Pod Annotations](https://github.com/digitalocean/digitalocean-cloud-controller-manager/blob/master/docs/getting-started.md#load-balancer-id-annotations)
- [Example of using Load Balancer ID Pod Annotation from Docs](https://docs.digitalocean.com/products/kubernetes/how-to/configure-load-balancers/#slug-size-annotation) *Note* that the annotation is `kubernetes.digitalocean.com/load-balancer-id: "your-load-balancer-id"` to ensure Digital Ocean doesn't provision a new load balancer for the ingress controller.

- [Terraform DO DNS Records](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/record)

- [Troubleshooting Cert-Manager](https://cert-manager.io/docs/faq/troubleshooting/)