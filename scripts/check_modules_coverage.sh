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
    while [[ -z $TEMP_VERSION ]]; do
        # Extract Target Odoo version from the docker-compose.yml file
        TEMP_VERSION=$(( $(grep -oP 'image: odoo:\K\d+' docker-compose.yml) + 1 )).0
        echo "Target Odoo version: $TEMP_VERSION"
    done
}

# Define a function to run the main script logic
run_module_check() {
    # Run the psql command and capture the output and extract module names using awk and store them in a var
    module_names=$(docker-compose exec -T postgres psql -U odoo -d $ODOO_DB -t -c "SELECT name FROM ir_module_module WHERE state = 'installed';" | sed '$d' | sed 's/ //g' | sed 's/\r//g')
    # Convert module names to an array
    IFS=$'\n' read -d '' -ra pre_module_list <<< "$module_names"

    # Use find to get a list of subdirectory names and store them in an array
    mapfile -t addons_list < <(find addons/ -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
    
    # Create a new array without the specified addons
    module_list=()
    for module in "${pre_module_list[@]}"; do
        if [[ ! " ${addons_list[@]} " =~ " $module " ]]; then
            module_list+=("$module")
        fi
    done

    # Install pip3 packages
    pip3 install requests beautifulsoup4 2>&1 >/dev/null | grep -v 'DEPRECATION: distro-info\|DEPRECATION: python-debian'
    # Run the Python script with the parameter
    python3 scripts/get_modules_coverage.py "$TEMP_VERSION"
    if [ $? -eq 1 ]; then
        echo "Error getting module coverage."
        return 1
    fi

    # Read module names from the exported file into an array
    readarray -t coverage_list < scripts/modules_coverage.txt

    rm -f scripts/modules_coverage.txt

    # Iterate through each value in module_names array
    for module in "${module_list[@]}"; do
        # Check if the module is missing in the coverage list
        if [[ ! " ${coverage_list[*]} " == *" $module "* ]]; then
            echo "$module is missing from the coverage list"
            missing_modules=1
        fi
    done
    # Return 0 if no missing modules are found, otherwise return 1
    if [[ $missing_modules -eq 0 ]]; then
        echo "There is module coverage."
    else
        echo "There is not module coverage."
        return 1
    fi
}

main() {
    set_working_directory
    set_environment_variables
    run_module_check
}

main