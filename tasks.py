#!/usr/bin/env python3


import time
import re

import invoke
import yaml


class Context:
    """custom context class"""

    invoke: invoke.Context
    config: dict
    region: str
    repo_name: str
    version: str
    project: str
    docker_tag: str
    docker_repo: str
    python_version: str

    def __init__(self, ctx) -> None:
        self.invoke = ctx
        self.config = self._config()
        self.repo_name = self._repo_name()
        self.version = self._version()
        self.project = self._project()
        self.docker_tag = self._docker_tag()
        self.docker_repo = self._docker_repo()
        self.python_version = self._python_version()

    def run(self, *args, **kwargs):
        """run a command"""
        return self.invoke.run(*args, **kwargs)

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
        """get the region"""
        return self.config["name"]

    @property
    def region(self) -> str:
        """get the region"""
        return self.config["region"]

    def _repo_name(self) -> str:
        """get the name of the repository"""
        return self.stdout("basename -s .git `git config --get remote.origin.url`")

    def _config(self) -> dict:
        """read from config.yml"""
        with open("config.yml", "r", encoding="utf-8") as _file:
            return yaml.safe_load(_file.read())

    def _version(self) -> str:
        """compose a version string from git branch, git commit, user, and timestamp"""
        branch = self.alphanum(self.stdout("git rev-parse --abbrev-ref HEAD"))[:16]
        commit = self.alphanum(self.stdout("git rev-parse --short HEAD"))
        user = self.alphanum(self.stdout("whoami"))
        timestamp = round(time.time())
        return f"{branch}-{commit}-{user}-{timestamp}"

    def _project(self) -> str:
        """get the project id"""
        return self.stdout("gcloud config get-value project")

    def _docker_tag(self) -> str:
        """get the docker tag"""
        return f"{self.alphanum(self.name)}-{self.version}"

    def _docker_repo(self) -> str:
        """get the docker repository"""
        return f"{self.region}-docker.pkg.dev/{self.project}/{self.name}"

    def _python_version(self) -> str:
        """get the python version"""
        return self.stdout("grep python_version Pipfile").split('"')[1]


@invoke.task
def run_native(ctx: invoke.Context):
    """run the application natively"""
    ctx = Context(ctx)
    ctx.run(
        "pipenv run flask --app src/main.py --debug run --host 0.0.0.0 --port 8001",
        echo=True,
    )


@invoke.task
def build_docker(ctx: invoke.Context):
    """run the application in a docker container"""
    # get local configurations
    ctx = Context(ctx)

    # generate requirements.txt
    ctx.run("pipenv requirements > requirements.txt", echo=True)

    # build docker image
    ctx.run(
        ctx.compress(
            f"""
            docker build
                --build-arg PYTHON_VERSION={ctx.python_version}
                --tag {ctx.docker_tag} .
            """
        ),
        echo=True,
        pty=True,
    )


@invoke.task
def run_docker(ctx: invoke.Context):
    # get local configurations
    ctx = Context(ctx)

    # build docker before running
    build_docker(ctx.invoke)

    # run docker container
    ctx.invoke.run(
        f"docker run -p 8001:8001 --rm {ctx.docker_tag}",
        echo=True,
        pty=True,
    )


@invoke.task
def deploy(ctx: invoke.Context):
    """deploy the application to a kubernetes cluster"""
    # get local configurations
    ctx = Context(ctx)

    # build docker, get the tag
    build_docker(ctx.invoke)

    # deploy and infrastructure changes
    ctx.run("cd infrastructure && terraform apply", echo=True)

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
        echo=True,
    )

    # alias the docker tag
    ctx.run(
        f"docker tag docker.io/library/{ctx.docker_tag} {ctx.docker_repo}/{ctx.docker_tag}",
        echo=True,
    )

    # push the docker image
    ctx.run(f"docker push {ctx.docker_repo}/{ctx.docker_tag}", echo=True)
