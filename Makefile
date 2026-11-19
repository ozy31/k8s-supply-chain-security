.PHONY: up down policies test-policies e2e lint release clean

up: ## kind cluster, local registry and Kyverno
	hack/cluster-up.sh
	platform/install.sh
	hack/apply-policies.sh

down: ## delete the kind cluster and the registry
	hack/cluster-down.sh

policies: ## render and apply all policies
	hack/apply-policies.sh

test-policies: ## offline policy tests, no cluster needed
	kyverno test test/policies

e2e: ## admission tests against the live cluster
	test/e2e/signatures.sh
	test/e2e/attestations.sh
	test/e2e/hardening.sh

lint: ## shellcheck and Go vet
	shellcheck hack/*.sh platform/*.sh test/e2e/*.sh
	cd app && go vet ./... && go test ./...

release: ## build, scan, sign and attest app/ (TAG=v1.2.3)
	hack/release.sh $(TAG)

clean: ## remove generated keys, SBOMs and rendered policies
	rm -rf out
