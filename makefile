help: ## Show this help.
	@egrep '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

pyenv-ubuntu: ## install pyenv on ubuntu
	sudo apt-get update
	sudo apt-get install -y make build-essential libssl-dev zlib1g-dev \
		libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
		libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev \
		liblzma-dev python-openssl git
	curl https://pyenv.run | bash

install: ## install python, and python packages
	pyenv install --skip-existing
	pip install invoke pyyaml
	python -m venv venv
	./venv/bin/pip install --upgrade pip pipenv
	./venv/bin/pip install -r src/requirements-dev.txt
	env PIPENV_VERBOSITY=-1 ./venv/bin/pipenv install

update: ## update and lock python packages
	$(MAKE) install
	env PIPENV_VERBOSITY=-1 ./venv/bin/pipenv upgrade
	env PIPENV_VERBOSITY=-1 ./venv/bin/pipenv update
	env PIPENV_VERBOSITY=-1 ./venv/bin/pipenv requirements > src/requirements.txt
	env PIPENV_VERBOSITY=-1 ./venv/bin/pipenv requirements --dev > src/requirements-dev.txt
	$(MAKE) install
