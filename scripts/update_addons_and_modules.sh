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
}

list_addons() {
    # Avoid permission errors
    chown -R $USER:$USER addons/
    chmod -R 755 addons/

    # Use find to get a list of subdirectory names and store them in an array
    mapfile -t folder_names < <(find addons/ -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
    
    # Join the array elements with commas
    CUSTOM_ADDONS_LIST=$(IFS=,; echo "${folder_names[*]}")
}

install_requirements() {
    # Get addons requirements
    python3 scripts/get_addons_requeriments.py
    if [ $? -eq 1 ]; then
        echo "Error getting addons requirements."
        return 1
    fi

    # Install addons requirements
    docker-compose exec odoo pip3 install -r /mnt/extra-addons/addons_requeriments.txt 2>&1 >/dev/null | grep -v 'DEPRECATION: distro-info\|DEPRECATION: python-debian'
    
    # Install extra requirements
    docker-compose exec odoo pip3 install -r /mnt/extra-addons/extra_requeriments.txt 2>&1 >/dev/null | grep -v 'DEPRECATION: distro-info\|DEPRECATION: python-debian'
}

install_and_update_addons_and_modules() {
    # Install extra modules
    docker-compose exec odoo pip3 install -r /mnt/extra-addons/extra_modules.txt 2>&1 >/dev/null | grep -v 'DEPRECATION: distro-info\|DEPRECATION: python-debian'
    
    # Install modules and addons (custom modules located in addons folder)
    docker-compose exec odoo odoo -d $ODOO_DB -i $CUSTOM_ADDONS_LIST --stop-after-init
    if [ $? -eq 1 ]; then
        echo "Error while installing modules and addons"
        return 1
    fi
    
    # Update modules and addons (custom modules located in addons folder)
    docker-compose exec odoo odoo -d $ODOO_DB -u $CUSTOM_ADDONS_LIST --stop-after-init
    if [ $? -eq 1 ]; then
        echo "Error while updating modules and addons"
        return 1
    fi

    # Restart Odoo to apply changes
    docker-compose restart odoo
}

main() {
    set_working_directory
    set_environment_variables
    list_addons
    source scripts/backup.sh
    install_requirements
    install_and_update_addons_and_modules
}

main
