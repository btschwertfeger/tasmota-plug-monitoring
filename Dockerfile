FROM python:3.13-slim

ENV DEBIAN_FRONTEND=noninteractive

COPY dbexporter.py /app/dbexporter.py

# hadolint ignore=DL3008,DL3013
RUN --mount=type=cache,target=/var/lib/apt/,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log/apt/ \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo "LC_ALL=en_US.UTF-8" >> /etc/environment \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "LANG=en_US.UTF-8" >> /etc/locale.conf \
    && apt-get update \
    && apt-get -y upgrade \
    && apt-get -y --no-install-recommends install \
        gcc \
        libpq-dev \
        locales \
        procps \
    && locale-gen en_US.UTF.8 \
    && rm -rf /var/lib/apt/lists/* \
    && python -m pip install --no-cache-dir --compile paho-mqtt influxdb-client

ENTRYPOINT ["python", "/app/dbexporter.py"]
