# syntax=docker/dockerfile:1
FROM python:3-alpine
ARG COMPOSE_BIN_URL BLACK_VERSION ISORT_VERSION
RUN true \
    && apk add --update docker-cli git curl gnupg \
    && wget -qO /usr/local/bin/docker-compose ${COMPOSE_BIN_URL} \
    && chmod +x /usr/local/bin/docker-compose \
    && pip install --no-cache-dir black==${BLACK_VERSION} isort==${ISORT_VERSION} \
    && rm -rf ~/.cache /tmp/* /var/lib/apt/lists/* /usr/local/man