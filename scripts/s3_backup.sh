#!/bin/bash
# -*- coding: utf-8 -*-

set_working_directory() {
    # Get the parent directory of the script's directory
    OG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    # Get the working directory name
    OG_FOLDER=$(basename "$OG_DIR")
    # Navigate to the working directory
    cd $OG_DIR
}

set_environment_variables() {
    source .env

    # Check if the required variables are defined
    while [[ -z $MINIO_BUCKET ]]; do
        read -p "Enter MinIO bucket name: " MINIO_BUCKET
    done
    while [[ -z $MINIO_ROOT_USER ]]; do
        read -p "Enter MinIO root user: " MINIO_ROOT_USER
    done
    while [[ -z $MINIO_ROOT_PASSWORD ]]; do
        read -sp "Enter MinIO root password: " MINIO_ROOT_PASSWORD
        echo
    done
    while [[ -z $MINIO_ENDPOINT ]]; do
        read -p "Enter MinIO endpoint URL (without http): " MINIO_ENDPOINT
    done

    MINIO_ENDPOINT_URL=http://$MINIO_ENDPOINT
}

upload_backup() {
    # Run and source the backup script to access variables defined there
    source scripts/backup.sh

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
    mc alias set minio ${MINIO_ENDPOINT_URL} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}

    # Upload the backup file to the MinIO bucket
    mc cp ${BACKUP_DIR}/${BACKUP_FILENAME} minio/${MINIO_BUCKET}/${BACKUP_FILENAME}

    # Check the exit status of the mc cp command
    if [[ $? -eq 0 ]]; then
        echo "Backup uploaded successfully to MinIO."
    else
        echo "Failed to upload backup to MinIO."
    fi
}

main() {
    set_working_directory
    set_environment_variables
    upload_backup
}

main
