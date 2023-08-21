#!/bin/bash
# -*- coding: utf-8 -*-

# Get the absolute path of the directory containing the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Navigate to the parent directory
cd "${SCRIPT_DIR}/.."

# Load environment variables from .env
source .env

# Odoo vars
BACKUP_DIR=backups
ODOO_DATABASE=$ODOO_DB
ADMIN_PASSWORD=$ODOO_ADMIN_PASSWORD
ODOO_ENDPOINT_URL=http://$ODOO_ENDPOINT

# S3 vars
MINIO_BUCKET=$MINIO_BUCKET
MINIO_ROOT_USER=$MINIO_ROOT_USER
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
S3_ENDPOINT_URL=http://$MINIO_ENDPOINT

# Create a backup directory
mkdir -p ${BACKUP_DIR}

# Generate a timestamp for the backup file
TIMESTAMP=$(date +%F_%H-%M-%S)

# Create a backup
BACKUP_FILENAME=${ODOO_DATABASE}.${TIMESTAMP}.zip
curl -X POST \
    -F "master_pwd=${ADMIN_PASSWORD}" \
    -F "name=${ODOO_DATABASE}" \
    -F "backup_format=zip" \
    -o ${BACKUP_DIR}/${BACKUP_FILENAME} \
    ${ODOO_ENDPOINT_URL}/web/database/backup

# Delete old backups
find ${BACKUP_DIR} -type f -mtime +30 -name "${ODOO_DATABASE}*.zip" -delete

# Check if mc (MinIO Client) is already installed
if ! command -v mc &> /dev/null; then
    # MinIO mc install
    curl https://dl.min.io/client/mc/release/linux-amd64/mc \
        --create-dirs \
        -o $HOME/minio-binaries/mc

    chmod +x $HOME/minio-binaries/mc
    export PATH=$PATH:$HOME/minio-binaries/
fi

# Set MinIO alias
mc alias set minio ${S3_ENDPOINT_URL} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}

# Upload the backup file to the MinIO bucket
mc cp ${BACKUP_DIR}/${BACKUP_FILENAME} minio/${MINIO_BUCKET}/${BACKUP_FILENAME}
