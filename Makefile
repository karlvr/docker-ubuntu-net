IMAGE=karlvr/$(shell basename $(shell pwd))

.PHONY: build
build: pull
	docker build . -t $(IMAGE):latest

.PHONY: pull
pull:
	docker pull ubuntu:20.04

.PHONY: push
push:
	docker push $(IMAGE):latest
