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

drop_database() {
    # Send a POST request to initiate the drop process and capture the error output
    curl_output=$(curl -X POST \
        -F "master_pwd=${ODOO_ADMIN_PASSWORD}" \
        -F "name=${ODOO_DB}" \
        ${ODOO_ENDPOINT_URL}/web/database/drop 2>&1)

    # Check the exit status of the curl command
    if [[ $? -ne 0 ]]; then
        echo "Error details: $curl_output"
        echo "Failed to drop database."
    else
        echo "Database dropped successfully."
    fi
}

main() {
    set_working_directory
    set_environment_variables
    drop_database
}

main
