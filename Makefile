IMAGE=karlvr/ubuntu-net

.PHONY: all
all: pull build

.PHONY: build
build:
	docker build . -t $(IMAGE):latest

.PHONY: pull
pull:
	docker pull ubuntu:20.04

.PHONY: push
push: build
	docker push $(IMAGE):latest

.PHONY: run
run: build
	docker run -it --entrypoint bash $(IMAGE)
