#!/usr/bin/env python3


import invoke
import yaml


def _compress(command: str) -> str:
    """compress whitespace in string"""
    return " ".join(command.split())


def _version(ctx: invoke.Context) -> str:
    """compose a version string from git branch, commit and user"""
    branch = (
        output.stdout.strip()
        if (output := ctx.run("git rev-parse --abbrev-ref HEAD", hide=True))
        else "NA"
    )
    commit = (
        output.stdout.strip()
        if (output := ctx.run("git rev-parse --short HEAD", hide=True))
        else "NA"
    )
    # the extra spaces after `whoami` are intentional to keep visual consistency
    user = (
        output.stdout.strip()
        if (output := ctx.run("whoami      ", hide=True))
        else "NA"
    )
    return f"{branch}-{commit}-{user}"


def _config() -> dict:
    with open("config.yml", "r", encoding="utf-8") as _file:
        return yaml.safe_load(_file.read())


@invoke.task
def run_native(ctx: invoke.Context):
    """run the application natively"""
    ctx.run(
        "pipenv run flask --app src/main.py --debug run --host 0.0.0.0 --port 8001",
        echo=True,
    )


@invoke.task
def run_docker(ctx: invoke.Context):
    """run the application in a docker container"""
    # get local configurations
    image_version = _version(ctx)
    config = _config()
    docker_tag = f"{config['name']}:{image_version}"

    # get python version
    python_version = (
        output.stdout.split('"')[1]
        if (output := ctx.run("grep python_version Pipfile", echo=True))
        else None
    )
    if not python_version:
        raise RuntimeError("python version not found")

    # generate requirements.txt
    ctx.run("pipenv requirements > requirements.txt", echo=True)

    # build docker image
    ctx.run(
        _compress(
            f"""
            docker build
                --build-arg PYTHON_VERSION={python_version}
                --tag {docker_tag} .
        """
        ),
        echo=True,
        pty=True,
    )

    # run docker container
    ctx.run(
        f"docker run -p 8001:8001 --rm {docker_tag}",
        echo=True,
        pty=True,
    )
