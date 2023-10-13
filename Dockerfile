ARG PYTHON_VERSION
FROM python:${PYTHON_VERSION}-slim-buster

ENV PYTHONUNBUFFERED 1
EXPOSE 8001

WORKDIR /project
COPY ./src /project/src
COPY ./requirements.txt /project/requirements.txt
COPY ./config.yml /project/config.yml

RUN pip install -r requirements.txt

CMD ["gunicorn", "--bind", "0.0.0.0:8001", "src.main:app"]
