# Copyright 2016 Philip G. Porada
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.ONESHELL:
.SHELL := /usr/bin/bash
.PHONY: apply destroy destroy-target plan-destroy plan plan-target init
VARS="environment/$(ENV).tfvars"
CURRENT_FOLDER=$(shell basename "$$(pwd)")
STATE_BUCKET="gamechanger.terraform-state"
DYNAMODB_TABLE="terraform-lock-table"
WORKSPACE="$(ENV)"
BOLD=$(shell tput bold)
RED=$(shell tput setaf 1)
GREEN=$(shell tput setaf 2)
YELLOW=$(shell tput setaf 3)
RESET=$(shell tput sgr0)

export AWS_DEFAULT_REGION := us-east-1


# Check for necessary tools
ifeq (, $(shell which aws))
	$(error "No aws in $(PATH), go to https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html, pick your OS, and follow the instructions")
endif

ifeq (, $(shell which terraform))
	$(error "No terraform in $(PATH), get it from https://www.terraform.io/downloads.html")
endif

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

set-env:
	@if [ -z $(ENV) ]; then \
		echo "$(BOLD)$(RED)ENV was not set$(RESET)"; \
		ERROR=1; \
	 fi

	@if [ ! -z $${ERROR} ] && [ $${ERROR} -eq 1 ]; then \
		echo "$(BOLD)Example usage: \`ENV=demo make plan\`$(RESET)"; \
		exit 1; \
	 fi
	@if [ ! -f "$(VARS)" ]; then \
		echo "$(BOLD)$(RED)Could not find .tfvars file for the environment: $(VARS)$(RESET)"; \
		exit 1; \
	 fi

init: set-env ## Prepare a new workspace (environment) if needed, configure the tfstate backend, update any modules, and switch to the workspace
	@echo "$(BOLD)Configuring the terraform backend$(RESET)"
	@terraform init \
		-input=false \
		-force-copy \
		-lock=true \
		-upgrade \
		-backend=true \
		-backend-config="bucket=$(STATE_BUCKET)" \
		-backend-config="key=$(GITHUB_REPOSITORY)/$(ENV).tfstate" \
		-backend-config="dynamodb_table=$(DYNAMODB_TABLE)"\
	    -backend-config="acl=private"

plan: init
	@terraform plan \
		-lock=true \
		-input=false \
		-refresh=true \
		-var-file="$(VARS)" \
		-out=plan.tfplan \
		-no-color

format: init ## Rewrites all Terraform configuration files to a canonical format.
	@terraform fmt \
		-write=true \
		-recursive

# https://github.com/terraform-linters/tflint
lint: init ## Check for possible errors, best practices, etc in current directory!
	@tflint

check-security:
	@tfsec .

plan-target: init ## Shows what a plan looks like for applying a specific resource
	@echo "$(YELLOW)$(BOLD)[INFO]   $(RESET)"; echo "Example to type for the following question: module.rds.aws_route53_record.rds-master"
	@read -p "PLAN target: " DATA && \
		terraform plan \
			-lock=true \
			-input=true \
			-refresh=true \
			-var-file="$(VARS)" \
			-target=$$DATA

plan-destroy: init ## Creates a destruction plan.
	@terraform plan \
		-input=false \
		-refresh=true \
		-destroy \
		-var-file="$(VARS)"

apply:
	@terraform apply \
		-lock=true \
		-input=false \
		-refresh=true \
		-auto-approve \
		"plan.tfplan"

destroy: init ## Destroy the things
	@terraform destroy \
		-lock=true \
		-input=false \
		-refresh=true \
		-var-file="$(VARS)"

destroy-target: init ## Destroy a specific resource. Caution though, this destroys chained resources.
	@echo "$(YELLOW)$(BOLD)[INFO] Specifically destroy a piece of Terraform data.$(RESET)"; echo "Example to type for the following question: module.rds.aws_route53_record.rds-master"
	@read -p "Destroy target: " DATA && \
		terraform destroy \
		-lock=true \
		-input=false \
		-refresh=true \
		-var-file=$(VARS) \
		-target=$$DATA
