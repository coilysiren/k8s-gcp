help: ## Show this help.
	@egrep '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

ifdef CI
python: # python should already be installed in CI
	python --version
else
python: # install python
	pyenv install --skip-existing
endif

install: ## install python, and python packages
	$(MAKE) python
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
