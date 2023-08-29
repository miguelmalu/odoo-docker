#!/bin/bash
# -*- coding: utf-8 -*-

# Define a function to be executed when Ctrl+C is pressed or on errors
cleanup() {
    echo "Script was interrupted or encountered an error. Cleaning up..."
    cd $OG_DIR
    # Check if the upgrade directory exists
    if [[ -d "../upgrade" ]]; then
        docker-compose -f ../upgrade/docker-compose.yml down -v
        rm -rf ../upgrade
    fi
    docker-compose -f docker-compose.yml up -d
    exit 1
}

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
    while [[ -z $TARGET_VERSION ]]; do
    read -p "Enter the target version name (e.g., 16.0): " TARGET_VERSION
    done
    if [[ ! $TARGET_VERSION =~ \. ]]; then
        TARGET_VERSION="${TARGET_VERSION}.0"
    fi
}

# Method to wait a few seconds
wait_for_start() {
    seconds=5
    for ((i=$seconds; i>=1; i--)); do
        echo -ne "Waiting for $i seconds... \r"
        sleep 1
    done
    echo -e "\nDone waiting."
}

# Function to ask the user a yes/no question
ask_question() {
    local question="$1"
    local default_answer="$2"
    default_answer_uc=$(echo "$default_answer" | tr '[:lower:]' '[:upper:]')
    local alternative_answer="$3"
    read -p "$question ($default_answer_uc/$alternative_answer): " answer

    if [[ -z "$answer" ]]; then
        answer="$default_answer"
    fi

    answer_lc=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

    if [[ "$answer_lc" != $default_answer ]] && [[ "$answer_lc" != $alternative_answer ]]; then
        echo "Invalid input."
        ask_question "$question" "$default_answer" "$alternative_answer"
    else
        result_answer="$answer_lc"
    fi
}

# Function to perform the actual upgrade
openupgrade() {
    # Check if is a retry
    if [[ ! -d "../upgrade/addons/OpenUpgrade" ]]; then
        # Get OpenUpgrade files
        git clone -b $TEMP_VERSION --depth 1 https://github.com/OCA/OpenUpgrade.git ../upgrade/addons/OpenUpgrade
    
        # Avoid permission errors
        chown -R $USER:$USER ../upgrade/addons/OpenUpgrade
        chmod -R 755 ../upgrade/addons/OpenUpgrade

        # Modify the Odoo version in docker-compose.yml
        sed -i "s/image: odoo:[0-9]\+\(\.[0-9]\+\)\?/image: odoo:${TEMP_VERSION}/" ../upgrade/docker-compose.yml
    fi

    # Recreate the Odoo container
    docker-compose -f ../upgrade/docker-compose.yml up -d
    wait_for_start
 
    # Install openupgradelib
    docker-compose -f ../upgrade/docker-compose.yml exec odoo pip3 install openupgradelib 2>&1 >/dev/null | grep -v 'DEPRECATION: distro-info\|DEPRECATION: python-debian'

    # Run the OpenUpgrade script for the specific version
    if (( $(bc <<< "$TEMP_VERSION >= 14.0") )); then
        docker-compose -f ../upgrade/docker-compose.yml exec odoo odoo --database=$ODOO_DB --addons-path=/mnt/extra-addons/OpenUpgrade/ --upgrade-path=/mnt/extra-addons/OpenUpgrade/openupgrade_scripts/scripts --load=base,web,openupgrade_framework --update all --stop-after-init
    else
        docker-compose -f ../upgrade/docker-compose.yml exec odoo /mnt/extra-addons/OpenUpgrade/odoo-bin --database=$ODOO_DB --update all --stop-after-init
    fi
    # Check the exit status
    if [ $? -eq 0 ]; then
        echo "OpenUpgrade applied to $TEMP_VERSION"
        ask_question "Was the upgrade to $TEMP_VERSION successful?" "y" "n"
        if [[ "$result_answer" == "n" ]]; then
            echo "Try to resolve errors (in the 'upgrade' folder) by googling them."
            result_error=true
        fi
    else
        echo "Try to resolve errors (in the 'upgrade' folder) by googling them."
    fi
    # If there were errors or user chose not to proceed
    if [[ -z result_error ]]; then
        ask_question "Once you have corrected the errors, do you want to retry the migration?" "y" "n"
        if [[ "$result_answer" == "y" ]]; then
            openupgrade
        else
            return 1
        fi
    fi
}

upgrade() {
    # Check if the upgrade directory exists
    if [[ -d "../upgrade" ]]; then
        docker-compose -f ../upgrade/docker-compose.yml down -v
        rm -rf ../upgrade
    fi

    docker-compose up -d
    wait_for_start

    ask_question "Do you have an S3 Bucket?" "n" "y"
    if [[ "$result_answer" == "n" ]]; then
        # Create a backup of the database of original project
        source scripts/backup.sh
    else
        S3_BUCKET=true
        source scripts/s3_backup.sh
    fi

    # Extract Odoo version from the docker-compose.yml file
    INIT_VERSION=$(grep -oP 'image: odoo:\K\d+' docker-compose.yml).0
    echo "Current Odoo version: $INIT_VERSION"

    docker-compose down

    # Generate a timestamp for the backup folder
    TIMESTAMP=$(date +%F_%H-%M-%S)
    # Copy the contents of the current directory to the backup directory
    echo "Creating a backup folder of the project..."
    cp -r . ../backup.$TIMESTAMP

    # Copy the contents of the current directory to the upgrade directory
    echo "Creating a copy folder of the project..."
    cp -r . ../upgrade

    docker-compose -f ../upgrade/docker-compose.yml up -d
    wait_for_start

    # Restore the database backup in the new temp project
    source ../upgrade/scripts/restore_backup.sh
    cd $OG_DIR

    # Use find to get a list of subdirectory names and store them in an array
    mapfile -t folder_names < <(find ../upgrade/addons/ -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
    # Join the array elements with commas
    CUSTOM_ADDONS_LIST=$(IFS=,; echo "${folder_names[*]}")

    ask_question "Do you want to migrate all your custom addons?" "y" "n"
    if [[ "$result_answer" == "y" ]]; then
        ADDONS_TO_MIGRATE=$CUSTOM_ADDONS_LIST
    fi

    # Loop through versions starting from the current version up to the target version
    for ((version="${INIT_VERSION%%.*}+1"; version <= "${TARGET_VERSION%%.*}"; version++)); do
        TEMP_INIT_VERSION=$((version - 1)).0
        TEMP_VERSION="${version}.0"
        echo "Starting the upgrade to $TEMP_VERSION"

        # Disable error capture
        trap - INT ERR
        # Check modules coverage on the temp version
        source ../upgrade/scripts/check_modules_coverage.sh
        check_modules_coverage_exit_status=$?
        # Enable error capture
        trap cleanup INT ERR
        # Check it there was an error
        if [ $check_modules_coverage_exit_status -eq 1 ]; then
            if [ "$TEMP_INIT_VERSION" = "$INIT_VERSION" ]; then
                echo "No upgrade available"
                cleanup # Exit
            else
                echo "Upgrade is only possible up to version $TEMP_INIT_VERSION"
                break
            fi
        fi

        # Migrate addons to the temp version
        source ../upgrade/scripts/migrate_addons.sh

        openupgrade
        rm -rf ../upgrade/addons/OpenUpgrade
    done
    cd $OG_DIR

    if [[ -z S3_BUCKET ]]; then
        # Backup the resultant backup
        source ../upgrade/scripts/backup.sh
    else
        source ../upgrade/scripts/s3_backup.sh
    fi
    cd $OG_DIR

    docker-compose -f ../upgrade/docker-compose.yml down -v
    wait_for_start

    # Go one directory back
    cd ..
    # Apply changes to OG project
    rm -rf $OG_FOLDER
    cp -r upgrade $OG_FOLDER
    rm -rf upgrade
    cd $OG_DIR

    ask_question "Do you want to also upgrade Postgres (only if there are not more DB)?" "n" "y"
    if [[ "$result_answer" == "y" ]]; then
        POSTGRES_VOLUME_NAME="${OG_DIR}_$(grep ':/var/lib/postgresql' docker-compose.yml | awk -F':' '{print $1}' | tr -d '-' | sed 's/^[[:space:]]*//')"
        docker volume rm $POSTGRES_VOLUME_NAME

        # Modify the Postgres version in docker-compose.yml
        sed -i "s/image: postgres:[0-9]\+\(\.[0-9]\+\)\?/image: postgres:${TEMP_INIT_VERSION%%.*}/" docker-compose.yml
    fi

    docker-compose up -d
    wait_for_start

    if [[ -z $POSTGRES_VOLUME_NAME ]]; then
        # Drop OG database in the OG project
        source scripts/drop_database.sh 
    fi

    # Restore final database in the OG project
    source scripts/restore_backup.sh
}

main() {
    # Set the trap to execute the cleanup function on Ctrl+C (SIGINT) and errors (SIGERR)
    trap cleanup INT ERR
    set_working_directory
    set_environment_variables
    upgrade
}

main
