# Kubernetes GCP Python Starter App

## Development

The project runs the application code inside of a pipenv virtualenv, but requires some amount of configuration for your global python installation.

```bash
# inside ~/.zshrc, or similar
export PIPENV_VENV_IN_PROJECT=1
```

```bash
# run once, or whenever you are working on a new machine
pip install invoke pipenv pyyaml
```
