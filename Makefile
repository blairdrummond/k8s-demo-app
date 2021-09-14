# Handy
OKGREEN := '\033[92m'
ENDC := '\033[0m'
BOLD := '\033[1m'

all: bin init plan
	@echo "Now do a `make apply` or `terraform apply`"
	@echo "At the end, run `make kubeconfig` to connect"

bin:
	mkdir -p $@
	wget -O $@/Makefile \
		https://gist.githubusercontent.com/blairdrummond/c147d67f78028f84f8b56a57dea337b5/raw/2d5d5a3b0d2eb8718e2cda9aab2477eaf5b881f7/Makefile
	cd $@ && make
	rm -f $@/Makefile

init plan apply:
	export PATH=$$PATH:bin ; \
	terraform $@

kubeconfig:
	@printf $(OKGREEN)
	@printf $(BOLD)
	@echo doctl kubernetes cluster kubeconfig save '<cluster-name>'
	@read -p "Enter Cluster Name: " cluster ; \
	export PATH=$$PATH:bin ; \
	doctl kubernetes cluster kubeconfig save $$cluster
	@printf $(ENDC)


argo-login:
	@printf $(OKGREEN)
	@printf $(BOLD)
	@echo "ArgoCD Login: http://localhost:8000"
	@echo "=========================="
	@echo "ArgoCD Username is: admin"
	@printf "ArgoCD Password is: %s\n" $$(kubectl -n argocd \
		get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d)
	@echo "=========================="
	@printf $(ENDC)
	export PATH=$$PATH:bin ; \
	kubectl port-forward -n argocd svc/argocd-server 8000:80
