IMAGE=karlvr/ubuntu-net

.PHONY: all
all: build

.PHONY: build
build:
	docker buildx build --platform=linux/amd64,linux/arm64 --pull . -t $(IMAGE):latest

.PHONY: push
push: build
	docker push $(IMAGE):latest

.PHONY: run
run: build
	docker run -it --rm --entrypoint /bin/bash $(IMAGE)
