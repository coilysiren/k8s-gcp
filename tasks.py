#!/usr/bin/env python3


import re

import invoke
import yaml


# https://stackoverflow.com/questions/25108581/python-yaml-dump-bad-indentation
class MyDumper(yaml.Dumper):
    def increase_indent(self, flow=False, indentless=False):
        return super(MyDumper, self).increase_indent(flow, False)


class Context:
    """custom context class"""

    invoke: invoke.Context
    config: dict
    repo_name: str
    version: str
    docker_repo: str
    python_version: str

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
    def email(self) -> str:
        """get the email"""
        return self.config["email"]

    @property
    def domain(self) -> str:
        """get the domain"""
        return self.config["domain"]

    @property
    def project(self) -> str:
        """get the project id"""
        return self.config["project"]

    @property
    def cert_manager_url(self) -> str:
        """get the cert-manager url"""
        return (
            "https://github.com/cert-manager/cert-manager/releases/download/"
            f'{self.config["cert-manager-version"]}/cert-manager.yaml'
        )

    def get_kubeconfig(self, kubeconfig) -> str:
        with open(kubeconfig, "r", encoding="utf-8") as _file:
            return yaml.safe_load(_file.read())

    def update_image(self, kubeconfig: dict, image: str) -> dict:
        for item in kubeconfig["items"]:
            if item["kind"] == "Deployment":
                item["spec"]["template"]["spec"]["containers"][0]["image"] = image
        return kubeconfig

    def update_email(self, kubeconfig: dict, email: str) -> dict:
        for item in kubeconfig["items"]:
            if item["kind"] == "Issuer":
                item["spec"]["acme"]["email"] = email
        return kubeconfig

    def update_domain(self, kubeconfig: dict, domain: str) -> dict:
        for item in kubeconfig["items"]:
            if item["kind"] == "Ingress":
                item["spec"]["tls"][0]["hosts"][0] = domain
            if item["kind"] == "ClusterIssuer":
                item["spec"]["acme"]["solvers"][0]["selector"]["dnsZones"][0] = domain
        return kubeconfig

    def write_kubeconfig(self, kubeconfig, value: str) -> None:
        with open(kubeconfig, "w", encoding="utf-8") as _file:
            yaml.dump(value, _file, Dumper=MyDumper, default_flow_style=False)

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
    kubeconfig = ctx.get_kubeconfig("infrastructure/kubeconfig.yml")
    kubeconfig = ctx.update_image(kubeconfig, f"{ctx.docker_repo}:{ctx.version}")
    ctx.write_kubeconfig("infrastructure/kubeconfig.yml", kubeconfig)
    ctx.run("kubectl apply -f infrastructure/kubeconfig.yml")

    # deploy application infrastructure
    ctx.run("cd infrastructure/application && terraform init")
    ctx.run("cd infrastructure/application && terraform apply")
    ctx.run(f"kubectl apply -f {ctx.cert_manager_url}")
    kubeconfig = ctx.get_kubeconfig("infrastructure/cert.yml")
    kubeconfig = ctx.update_email(kubeconfig, ctx.email)
    kubeconfig = ctx.update_domain(kubeconfig, ctx.domain)
    ctx.write_kubeconfig("infrastructure/cert.yml", kubeconfig)
    ctx.run("kubectl apply -f infrastructure/cert.yml")

    # deploy the final ingress (eg. domain name)
    ctx.run("cd infrastructure/ingress && terraform init")
    ctx.run("cd infrastructure/ingress && terraform apply")


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
