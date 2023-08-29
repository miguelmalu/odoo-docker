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
    while [[ -z $ODOO_DB ]]; do
        read -p "Enter Odoo database name: " ODOO_DB
    done
    while [[ -z $ODOO_ADMIN_PASSWORD ]]; do
        read -sp "Enter Odoo admin password: " ODOO_ADMIN_PASSWORD
        echo
    done
    while [[ -z $ODOO_ENDPOINT ]]; do
        read -p "Enter Odoo endpoint URL (without http): " ODOO_ENDPOINT
    done

    BACKUP_DIR=backups
    ODOO_ENDPOINT_URL=http://$ODOO_ENDPOINT
}

create_backup() {
    # Create a backup directory
    mkdir -p ${BACKUP_DIR}

    # Delete old backups
    find ${BACKUP_DIR} -type f -mtime +30 -name "${ODOO_DB}*.zip" -delete

    # Generate a timestamp for the backup file
    TIMESTAMP=$(date +%F_%H-%M-%S)

    # Create a backup
    BACKUP_FILENAME=${ODOO_DB}.${TIMESTAMP}.zip
    curl -X POST \
        -F "master_pwd=${ODOO_ADMIN_PASSWORD}" \
        -F "name=${ODOO_DB}" \
        -F "backup_format=zip" \
        -o ${BACKUP_DIR}/${BACKUP_FILENAME} \
        ${ODOO_ENDPOINT_URL}/web/database/backup

    # Check the exit status of the curl command
    if [[ $? -eq 0 ]]; then
        echo "Backup created successfully: ${BACKUP_FILENAME}"
    else
        echo "Failed to create backup."
        return 1
    fi
}

main() {
    set_working_directory
    set_environment_variables
    create_backup
}

main
