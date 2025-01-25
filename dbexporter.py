#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright (C) 2024 Benjamin Thomas Schwertfeger
# GitHub: https://github.com/btschwertfeger
#

""" MQTT to InfluxDB (version 2.7.11) bridge """

import json
import os
import re
from logging import INFO, basicConfig, getLogger
from typing import Any, Generator, NamedTuple

import paho.mqtt.client as mqtt
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

basicConfig(
    format="%(asctime)s %(levelname)8s | %(message)s",
    datefmt="%Y/%m/%d %H:%M:%S",
    level=INFO,
)
LOG = getLogger(__name__)

INFLUXDB_URL = os.getenv("INFLUXDB_HOST")
INFLUXDB_TOKEN = os.getenv("INFLUXDB_TOKEN")
INFLUXDB_BUCKET = os.getenv("INFLUXDB_DATABASE")
INFLUXDB_ORG = os.getenv("INFLUXDB_ORG")

MQTT_ADDRESS = os.getenv("MQTT_HOST")
MQTT_USERNAME = os.getenv("MQTT_USERNAME")
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD")
MQTT_TOPIC = "tele/+/SENSOR"
MQTT_REGEX = "tele/([^/]+)/([^/]+)"
MQTT_CLIENT_ID = "MQTT_InfluxDB_Bridge"

MQTT_FIELDS = [
    "Total",
    "Yesterday",
    "Today",
    "Power",
    "ApparentPower",
    "ReactivePower",
    "Factor",
    "Voltage",
    "Current",
]

influxdb_client = InfluxDBClient(
    url=INFLUXDB_URL,
    token=INFLUXDB_TOKEN,
    org=INFLUXDB_ORG,
)

write_api = influxdb_client.write_api(write_options=SYNCHRONOUS)


class SensorData(NamedTuple):
    location: str
    measurement: str
    value: float


def on_connect(
    client: mqtt.Client,
    userdata: Any,  # noqa: ARG001,ANN401
    flags: Any,  # noqa: ARG001,ANN401
    rc: int,
    props: Any,  # noqa: ARG001, ANN401
) -> None:
    """
    The callback for when the client receives a CONNACK response from the
    server.
    """
    LOG.info("Connected with result code %s", rc)
    client.subscribe(MQTT_TOPIC)


def _parse_mqtt_message(topic: str, payload: str) -> Generator:
    if match := re.match(MQTT_REGEX, topic):
        location = match.group(1)
        measurement = match.group(2)

        if measurement == "status":  # noqa: PLR2004
            LOG.info("Ignoring status message")
            return None  # noqa: B901

        payload = json.loads(payload)
        for field in MQTT_FIELDS:
            if field in payload["ENERGY"]:  # type: ignore[index]
                yield SensorData(location, field, float(payload["ENERGY"][field]))  # type: ignore[index]


def _send_sensor_data_to_influxdb(sensor_data: SensorData) -> None:
    LOG.debug(
        "Sending data to InfluxDB: location=%s, measurement=%s, value=%s",
        sensor_data.location,
        sensor_data.measurement,
        sensor_data.value,
    )
    write_api.write(
        bucket=INFLUXDB_BUCKET,
        org=INFLUXDB_ORG,
        record=(
            Point(sensor_data.measurement)
            .tag("location", sensor_data.location)
            .field("value", sensor_data.value)
        ),
        write_precision=WritePrecision.S,
    )


def on_message(
    client: mqtt.Client,  # noqa: ARG001
    userdata: Any,  # noqa: ANN401,ARG001
    msg: Any,  # noqa: ANN401
) -> None:
    """The callback for when a PUBLISH message is received from the server."""
    LOG.debug("%s %s ", msg.topic, msg.payload)
    payload = msg.payload.decode("utf-8")
    sensor_data_sets = _parse_mqtt_message(msg.topic, payload)

    if sensor_data_sets is None:
        LOG.warning("Couldn't parse sensor data!")
        return

    for sensor_data in sensor_data_sets:
        LOG.debug("Sending sensor data to InfluxDB: %s", sensor_data)
        _send_sensor_data_to_influxdb(sensor_data)


def main() -> None:
    mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, MQTT_CLIENT_ID)
    mqtt_client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    mqtt_client.on_connect = on_connect
    mqtt_client.on_message = on_message

    mqtt_client.connect(MQTT_ADDRESS, 1883)
    mqtt_client.loop_forever()


if __name__ == "__main__":
    LOG.info("MQTT to InfluxDB bridge")
    main()
