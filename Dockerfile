FROM python:3.11 as base

EXPOSE 8080

RUN mkdir -p /usr/app/src
WORKDIR /usr/app
COPY ./src /usr/app/src

RUN pip install -r src/requirements.txt
CMD ["env", "PYTHONPATH=.", "gunicorn", "--bind=0.0.0.0:8080", "src.main.cli:app"]

FROM base AS dev

RUN pip install -r src/requirements-dev.txt
CMD ["env", "PYTHONPATH=.", "flask", "--app=src.main.cli:app", "run", "--debug", "--host=0.0.0.0", "--port=8080"]
