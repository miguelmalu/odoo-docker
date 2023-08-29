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
    while [[ -z $BACKUP_FILENAME ]]; do
        read -p "Enter Backup filename (with extension): " BACKUP_FILENAME
    done
    while [[ -z $ODOO_DB ]]; do
        read -p "Enter Odoo database name: " ODOO_DB
    done
    while [[ -z $ODOO_ADMIN_PASSWORD ]]; do
        read -sp "Enter Odoo admin password: " ODOO_ADMIN_PASSWORD
    done
    while [[ -z $ODOO_ENDPOINT ]]; do
        read -p "Enter Odoo endpoint URL (without http): " ODOO_ENDPOINT
    done

    BACKUP_DIR=backups
    ODOO_ENDPOINT_URL=http://$ODOO_ENDPOINT
}

restore_backup() {
    # Send a POST request to initiate the restore process and capture the error output
    curl_output=$(curl -X POST \
        -F "master_pwd=${ODOO_ADMIN_PASSWORD}" \
        -F "name=${ODOO_DB}" \
        -F "backup_file=@${BACKUP_DIR}/${BACKUP_FILENAME}" \
        ${ODOO_ENDPOINT_URL}/web/database/restore 2>&1)

    # Check the exit status of the curl command
    if [[ $? -ne 0 ]]; then
        echo "Error details: $curl_output"
        echo "Failed to restore backup."
    else
        echo "Backup restored successfully."
    fi
}

main() {
    set_working_directory
    set_environment_variables
    restore_backup
}

main
