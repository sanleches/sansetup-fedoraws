.PHONY: test lint check

lint:
	bash -n sansetup.sh lib/sansetup/*.sh tests/*.sh

test:
	./tests/run.sh

check: lint test
