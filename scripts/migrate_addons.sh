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
    while [[ -z $ADDONS_TO_MIGRATE ]]; do
        read -p "Enter the addons name(s) (comma-separated): " ADDONS_TO_MIGRATE
    done
    while [[ -z $TEMP_INIT_VERSION ]]; do
        read -p "Enter the initial version name (e.g., 12.0): " TEMP_INIT_VERSION
    done
    while [[ -z $TEMP_VERSION ]]; do
        read -p "Enter the target version name (e.g., 16.0): " TEMP_VERSION
    done
    if [[ ! $TEMP_VERSION =~ \. ]]; then
        TEMP_VERSION="${TEMP_VERSION}.0"
    fi
}

run_addons_migration() {
    #Check if pip installed
    if ! command -v pip3 &> /dev/null; then
        # Install pip without root
        wget https://bootstrap.pypa.io/get-pip.py -P /tmp
        python3 /tmp/get-pip.py --user > /dev/null
        # Add pip installation directory to PATH
        echo "export PATH=\$PATH:~/.local/bin" >> ~/.bashrc
        source ~/.bashrc
    fi

    # Install or upgrade odoo-module-migrator
    pip3 install odoo-module-migrator --upgrade 2>&1 >/dev/null | grep -v 'DEPRECATION: distro-info\|DEPRECATION: python-debian'

    # Use odoo-module-migrate with the provided parameters
    odoo-module-migrate --directory addons/ --modules $ADDONS_TO_MIGRATE --init-version-name $TEMP_INIT_VERSION --target-version-name $TEMP_VERSION --no-commit
    if [[ $? -eq 0 ]]; then
        echo "Addons migrated successfully."
    else
        echo "Error while migrating addons."
        return 1
    fi
}

main() {
    set_working_directory
    set_environment_variables
    run_addons_migration
}

main