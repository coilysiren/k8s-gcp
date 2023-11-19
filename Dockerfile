FROM python:3.11 as base

EXPOSE 8080

WORKDIR /usr/app
COPY ./src/* /usr/app

ENV PYTHONUNBUFFERED 1
ENV PYTHONPATH "$(pwd):$PYTHONPATH"

EXPOSE 8080
RUN pip install -r requirements.txt
CMD "gunicorn --bind 0.0.0.0:8080 app:app"

FROM base AS dev

RUN pip install -r requirements-dev.txt
CMD "pytest"
