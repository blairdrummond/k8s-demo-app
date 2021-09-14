bin:
	mkdir -p $@
	wget -O $@/Makefile \
		https://gist.githubusercontent.com/blairdrummond/c147d67f78028f84f8b56a57dea337b5/raw/2d5d5a3b0d2eb8718e2cda9aab2477eaf5b881f7/Makefile
	cd $@ && make
	rm -f $@/Makefile

init plan apply:
	export PATH=$$PATH:bin ; \
	terraform $@
