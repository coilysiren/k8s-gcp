# Kubernetes GCP Python Starter App

## Install

OSX system requirements:

- pyenv - `brew install pyenv`
- docker - `brew install --cask docker`
- httpie - `brew install httpie`

These are listed individually to avoid polluting your global installation unknowingly.

After installing the above, you can run the following command to setup your local dependencies. It sets up on a virtualenv for you.

```bash
make install
```

You should run this command every time your python dependencies change.

## Development

The development workflow involves using one or two terminal windows, depending on the type of work you are doing.

All of our python commands use `inv` / `invoke` eg [`pyinvoke`](https://www.pyinvoke.org/), a makefile replacement written in python. This allows us a degree of flexibility and comfort with our dev time tooling.

For the context of this API, all of the work you do should be able to be covered by 100% unit test coverage. Also, the primary mechanism of testing development work should be [`pytest-watch`](https://pypi.org/project/pytest-watch/).

When testing via a more "hands on" approach, we use a combination of `flask run` (via invoke) and `httpie`. `httpie` is used as a UX friendly alternative to `curl`, although we do utilize `curl` to confirm that we are aligned with the project spec.

### Pytest

```bash
$ source ./venv/bin/activate
$ invoke test
```

### Pytest Watch

```bash
$ source ./venv/bin/activate
$ invoke test-watch
```

This terminal will now watch for changes, and automatically re-run the tests when it finds them.

The majority of our tests were written in this way.

### httpie

```bash
# first terminal
$ source ./venv/bin/activate
$ invoke serve
```

```bash
# second terminal
$ http :8080/api/healthcheck
> HTTP/1.1 200 OK
```

### curl

```bash
# first terminal
$ source ./venv/bin/activate
$ invoke serve
```

```bash
# second terminal
$ curl http://0.0.0.0:8080/api/healthcheck
> OK
```

### Updating Dependencies

You can update dependencies via the following commands:

```bash
$ source ./venv/bin/activate
$ pipenv install < some package >
$ make upgrade
```

## Deployment

This deployment command assumes you are locally authenticated to both gcloud and kubectl. Directions on how to do so are out of scope for this documentation. Please consult your team's local deployment tooling and instructions!

```bash
source ./venv/bin/activate
invoke deploy # see tasks.py for source code
```
