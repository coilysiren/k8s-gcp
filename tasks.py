#!/usr/bin/env python3


import time
import re

import invoke
import yaml


class Context:
    """custom context class"""

    invoke: invoke.Context
    config: dict
    repo_name: str
    version: str
    docker_repo: str
    python_version: str
    kubeconfig = "./infrastructure/kubeconfig.yml"

    def __init__(self, ctx) -> None:
        self.invoke = ctx
        self.config = self._config()
        self.repo_name = self._repo_name()
        self.version = self._version()
        self.docker_repo = self._docker_repo()
        self.python_version = self._python_version()

    def run(self, *args, echo=True, pty=True, **kwargs):
        """run a command"""
        return self.invoke.run(*args, echo=echo, pty=pty, **kwargs)

    def compress(self, command: str) -> str:
        """compress whitespace in string"""
        return " ".join(command.split())

    def alphanum(self, value: str) -> str:
        """remove non-alphanumeric characters from string"""
        return re.sub(r"[^a-z0-9]", "", value.lower())

    def stdout(self, command: str) -> str:
        """get output from command"""
        output = self.invoke.run(command, hide=True)
        value = output.stdout.strip() if output else None
        if not value:
            raise RuntimeError(f"output from {command} not found")
        return value

    @property
    def name(self) -> str:
        """get the name"""
        return self.config["name"]

    @property
    def region(self) -> str:
        """get the region"""
        return self.config["region"]

    @property
    def project(self) -> str:
        """get the project id"""
        return self.config["project"]

    def get_kubeconfig(self) -> str:
        with open(self.kubeconfig, "r", encoding="utf-8") as _file:
            return yaml.safe_load(_file.read())

    def update_image(self, kubeconfig: dict) -> dict:
        for item in kubeconfig["items"]:
            if item["kind"] == "Deployment":
                item["spec"]["template"]["spec"]["containers"][0]["image"] = f"{self.docker_repo}:{self.version}"
        return kubeconfig

    def write_kubeconfig(self, value: str) -> None:
        with open(self.kubeconfig, "w", encoding="utf-8") as _file:
            yaml.dump(value, _file)

    def _repo_name(self) -> str:
        """get the name of the repository"""
        return self.stdout("basename -s .git `git config --get remote.origin.url`")

    def _config(self) -> dict:
        """read from config.yml"""
        with open("config.yml", "r", encoding="utf-8") as _file:
            return yaml.safe_load(_file.read())

    def _version(self) -> str:
        """compose a version string from git branch, git commit, and user"""
        branch = self.alphanum(self.stdout("git rev-parse --abbrev-ref HEAD"))[:16]
        commit = self.alphanum(self.stdout("git rev-parse --short HEAD"))
        user = self.alphanum(self.stdout("whoami"))
        return f"{branch}-{commit}-{user}"

    def _docker_repo(self) -> str:
        """get the docker repository"""
        return f"{self.region}-docker.pkg.dev/{self.project}/repository/{self.name}"

    def _python_version(self) -> str:
        """get the python version"""
        return self.stdout("cat .python-version")


@invoke.task
def build(ctx: [invoke.Context, Context]):
    """run the application in a docker container"""
    # get local configurations
    ctx = Context(ctx)

    # build docker image
    ctx.run(f"BUILDKIT_PROGRESS=plain docker build --tag {ctx.name}:{ctx.version} . --target base")


@invoke.task
def deploy(ctx: [invoke.Context, Context]):
    """deploy the application to a kubernetes cluster"""
    # get local configurations
    ctx = Context(ctx)

    # build docker, get the tag
    build(ctx.invoke)

    # deploy foundational infrastructure
    ctx.run("cd infrastructure/foundation && terraform init")
    ctx.run("cd infrastructure/foundation && terraform apply")

    # set the project
    ctx.run(f"gcloud config set project {ctx.project}")

    # authenticate with gcloud for docker registry
    ctx.run(
        ctx.compress(
            f"""
            gcloud auth print-access-token \
                    | docker login \
                        -u oauth2accesstoken \
                        --password-stdin https://{ctx.region}-docker.pkg.dev
            """
        ),
    )

    # authenticate with gcloud for kubernetes
    ctx.run(f"gcloud container clusters get-credentials {ctx.name} --region={ctx.region}")

    # alias the docker tag
    ctx.run(f"docker tag docker.io/library/{ctx.name}:{ctx.version} {ctx.docker_repo}:{ctx.version}")

    # push the docker image
    ctx.run(f"docker push {ctx.docker_repo}:{ctx.version}")

    # deploy to k8s cluster
    kubeconfig = ctx.get_kubeconfig()
    kubeconfig = ctx.update_image(kubeconfig)
    ctx.write_kubeconfig(kubeconfig)
    ctx.run(f"kubectl apply -f {ctx.kubeconfig}")

    # deploy application infrastructure
    ctx.run("cd infrastructure/application && terraform init")
    ctx.run("cd infrastructure/application && terraform apply")


@invoke.task
def flask(ctx: [invoke.Context, Context]):
    """serve up the application, so that it can be accessed locally"""
    ctx.run("BUILDKIT_PROGRESS=plain docker compose up --build flask")


@invoke.task
def gunicorn(ctx: [invoke.Context, Context]):
    """serve up the application, so that it can be accessed locally"""
    ctx.run("BUILDKIT_PROGRESS=plain docker compose up --build gunicorn")


@invoke.task
def test(ctx: [invoke.Context, Context]):
    """run tests"""
    ctx.run("BUILDKIT_PROGRESS=plain docker compose run --build pytest")


@invoke.task
def test_watch(ctx: [invoke.Context, Context]):
    """run tests in watch mode"""
    ctx.run("BUILDKIT_PROGRESS=plain docker compose run --build ptw")


@invoke.task
def migration_create(ctx: [invoke.Context, Context]):
    """create a new database migration"""
    ctx.run("BUILDKIT_PROGRESS=plain docker compose run --build create-migration")


@invoke.task
def migration_run_locally(ctx: [invoke.Context, Context]):
    """run a local database migration"""
    ctx.run("BUILDKIT_PROGRESS=plain docker compose run --build run-local-migration")
