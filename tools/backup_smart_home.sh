#!/bin/bash
# -*- coding: utf-8 -*-
# Copyright (C) 2024 Benjamin Thomas Schwertfeger
# GitHub: https://github.com/btschwertfeger
#
# ... put this into crontab

echo "Starting backup process..."

# Configuration
VOLUMES=("smart-home_grafana_data" "smart-home_influxdb_data")
BACKUP_DIR="/data/backups"  # Directory where backups will be stored
TIMESTAMP=$(date +"%Y%m%d%H%M%S")  # Timestamp format (e.g., 20231225123045)
BASE_DIR=/home/ubuntu/src/smart-home

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
