#!/bin/bash
# -*- coding: utf-8 -*-
# Copyright (C) 2024 Benjamin Thomas Schwertfeger
# GitHub: https://github.com/btschwertfeger
#
# A simple script to backup Docker volumes for the Tasmota Plug Monitoring
# project.
# 1. Check and update paths if necessary
# 2. Execute this script in crontab

echo "Starting backup process..."

# Configuration
VOLUMES=("tasmota-plug-monitoring_grafana_data" "tasmota-plug-monitoring_influxdb_data")
BACKUP_DIR="/data/backups"  # Directory where backups will be stored
TIMESTAMP=$(date +"%Y%m%d%H%M%S")  # Timestamp format (e.g., 20231225123045)
# Change this to the directory where this script is located:
BASE_DIR=/home/ubuntu/src/tasmota-plug-monitoring

mkdir -p ${BACKUP_DIR}

# Loop over each volume
for VOLUME_NAME in "${VOLUMES[@]}"; do
  echo "Creating backup for ${VOLUME_NAME}..."
  cd $BASE_DIR

  THIS_BACKUP_DIR="${BACKUP_DIR}/${VOLUME_NAME}"
  mkdir -p ${THIS_BACKUP_DIR}
  BACKUP_FILE="backup_${VOLUME_NAME}_${TIMESTAMP}.tar.gz"

  # Create a backup of the current Docker volume
  echo "Running Docker container for backing up ${VOLUME_NAME}..."
  docker run \
    --rm \
    -v ${VOLUME_NAME}:/volume \
    -v ${BASE_DIR}:/backup \
    --name smart_home_backup alpine \
    tar -czf /backup/${BACKUP_FILE} /volume

  mv ${BACKUP_FILE} ${THIS_BACKUP_DIR}

  # Retain only the last 14 backups for this volume
  cd ${THIS_BACKUP_DIR}
  ls -t | grep "backup_${VOLUME_NAME}_" | sed -e '1,14d' | xargs -I {} rm -f {}
  echo "Backup for ${VOLUME_NAME} created successfully."
done
