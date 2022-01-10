.PHONY: check run

check:
	docker run --rm -v $(PWD):$(PWD) -w $(PWD) koalaman/shellcheck:latest backup.sh

run: check
	bash backup.sh -r abc123 abc123