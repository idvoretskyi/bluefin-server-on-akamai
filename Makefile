SHELL := /usr/bin/env bash
TOFU ?= tofu
TOFU_DIR := tofu
OVERLAY ?=
ARGS ?=
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: bootdisk
bootdisk: ## Build the BIOS boot disk for BLUEFIN_VERSION (needs docker + gh)
	scripts/build-bootdisk.sh

.PHONY: image
image: ## Upload the boot disk as a private Linode image (prints private/<id>)
	scripts/upload-image.sh

.PHONY: overlays
overlays: ## Fetch homelab/home-server Butane templates from the server release
	scripts/fetch-overlays.sh

.PHONY: ignition
ignition: ## Render build/ignition.json (OVERLAY=<name> optional)
	scripts/render-ignition.sh $(if $(OVERLAY),--overlay $(OVERLAY))

.PHONY: init plan apply destroy fmt
init: ; cd $(TOFU_DIR) && $(TOFU) init
plan: ; cd $(TOFU_DIR) && $(TOFU) plan
apply: ## tofu apply (creates the instance, costs money)
	cd $(TOFU_DIR) && $(TOFU) apply
destroy: ; cd $(TOFU_DIR) && $(TOFU) destroy
fmt: ; cd $(TOFU_DIR) && $(TOFU) fmt

.PHONY: ssh
ssh: ## SSH into the instance as root
	cd $(TOFU_DIR) && $$($(TOFU) output -raw ssh_command)

.PHONY: validate
validate: ## Offline: tofu fmt/validate, shellcheck, butane
	cd $(TOFU_DIR) && $(TOFU) fmt -check && $(TOFU) init -backend=false >/dev/null && $(TOFU) validate
	shellcheck scripts/*.sh scripts/lib/*.sh
	scripts/validate-butane.sh

.PHONY: e2e
e2e: ## Live deploy-assert-destroy against a real Linode (ARGS=--keep to keep)
	scripts/e2e-linode.sh $(ARGS)

.PHONY: clean
clean:
	rm -rf build
