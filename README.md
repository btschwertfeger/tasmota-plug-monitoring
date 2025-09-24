# Tasmota Plug Monitoring

This repository contains the necessary knowledge and resources to setup and
monitor energy consumption measured by Tasmota-driven smart plugs using
InfluxDB, Grafana, and MQTT.

The setup consists of the following components:

- [InfluxDB](https://www.influxdata.com/products/influxdb-overview/) as a time
  series database to store the metrics.
- [Grafana](https://grafana.com/) as a visualization tool to create dashboards
  and panels.
- [Mosquitto](https://mosquitto.org/) as a MQTT broker to receive the metrics
  from the Tasmota plugs.
- A custom script that listens to the MQTT broker and writes the metrics to the
  InfluxDB.

The dashboard is designed to automatically detect new devices and include them
in the visualization.

<div align="center">
  <figure>
    <img
    src="resources/dashboard.png?raw=true"
    alt="Grafana dashboard of collected data"
    style="background-color: white; border-radius: 7px">
    <figcaption>Grafana dashboard of collected data</figcaption>
  </figure>
</div>

## Requirements

- Docker
- Docker Compose
- Tasmota plug(s), e.g. https://www.amazon.de/dp/B0CHMMKZCQ

## Setup and Configuration

1. Connect the Tasmota smart plug(s) to your network by following the
   instructions provided by the manufacturer. You can find the IP address of the
   plug by checking the DHCP leases of your router. You may also want to assign
   a static IP address to the plug(s).
2. Install the latest version of Tasmota on your devices.
3. Create a password file for mosquitto by running the official docker image to
   execute the `mosquitto_passwd` command.

   ```bash
   docker run -it eclipse-mosquitto:latest sh
   $ mosquitto_passwd -c passwd_file mqtt_user
   Password: ********
   Reenter password: ********

   $ cat passwd_file
   mqtt_user:................
   ```

   Copy the content of `passwd_file` into `./mosquitto/passwd_file` on your host
   system.

   Do **not** change the path to `passwd_file` file within
   `./mosquitto/mosquitto.conf`. This file must be present in the working
   directory in which docker is run later on.

4. Run the docker-compose file to start the services, but first, ensure that the
   required environment variables are set.

   The host must match the IP address of the machine running the Docker
   containers. For simplicity, we take the same password for MQTT and
   InfluxDB.

   Note: The MQTT password must match the password used when generating the
   `passwd_file`.

   The InfluxDB token must be created in the InfluxDB web UI in the next
   step.

   ```bash
   # InfluxDB
   export INFLUXDB_HOST="http://192.168.2.141:8086"
   export INFLUXDB_USERNAME="influxdb_user"
   export INFLUXDB_PASSWORD="influxdb_password"
   export INFLUXDB_DATABASE="smart_home"
   export INFLUXDB_ORG="smart_home"
   export INFLUXDB_TOKEN="You have to create a token in the influxdb IU"

   # MQTT
   export MQTT_HOST="192.168.2.141"
   export MQTT_USERNAME="mqtt_user"
   export MQTT_PASSWORD="${INFLUXDB_PASSWORD}"
   ```

   ```bash
   docker compose up
   ```

5. Open the InfluxDB web UI at http://192.168.2.141:8086/, login using the
   credentials and create a new API token at "Load Data" -> "API Tokens".
6. Stop the services started using Docker Compose and update the
   `INFLUXDB_TOKEN` with the newly created token.

   ```bash
   docker compose down
   export INFLUXDB_TOKEN="<the new token>"
   docker compose up -d
   ```

7. Setup the Tasmota devices to use the MQTT broker. The IP address must match
   the host of the MQTT broker. The username and password must match the
   `MQTT_USERNAME` and `MQTT_PASSWORD` environment variables. For this go to the
   IP address of the Tasmota smart plugs, go to "Configuration" -> "Configure
   MQTT" and enter the values. You may also want to rename the "Topic" to
   distinguish the devices. You can verify the connection by reviewing the logs
   of the MQTT service container and the Tasmota smart plug logs. Additionally,
   you can use tools like [mqtt-explorer](https://mqtt-explorer.com/) to verify
   the connection.
8. Increase the frequency of publishing metrics by setting `TelePeriod 10` in
   the Tasmota console ("Tools" -> "Console"). This will ensure that the metrics
   are updated every 10 seconds.
9. Login to the Grafana web UI at http://192.168.2.141:3000/ using the default
   credentials `admin` and `admin`.

   9.1 Add the InfluxDB as a data source at "Connections" -> "Data Sources".

   9.2 Set the query language to "Flux"

   9.3 Enter the correct IP and port to access the InfluxDB.

   9.4 Enter the "organization" and "token" to the values defined earlier.

10. Now its time to import the Dashboard provided in this repository via
    copy-pasting the content of the `grafana/dashboard.json` file into the
    "Dashboards" -> "New" -> "Import" section of the Grafana UI.

    Note: You may need to click through each panel, select your InfluxDB
    data source, and hit "Refresh".

11. You may have to adjust the `price_per_kWh` variable in some of the panels to
    match your electricity price.

## Notes

- This is a basic setup and can be extended with more features like alerts,
  additional metrics, and more.
- The setup is designed to be run on a local network and is not secured for
  public access. You may want to add more security features like SSL
  certificates, further authentication, and authorization.
- The setup is tested and running on Ubuntu 24.04. It should work on other
  systems as well.
- For any questions, issues, or feature requests please open an issue in this
  repository.
- In case the device don't auto-popup the config page when connecting with the
  Smart Plugs' Hotspot, you can enter the page via http://192.168.4.1.
- Resetting the WLAN settings for Tasmota Smart Plugs can be done by pressing
  the button 6 times (tested with Tasmota >= v15). Sometimes it needs a few
  tries.
