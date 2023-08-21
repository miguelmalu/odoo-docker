#!/bin/bash
# -*- coding: utf-8 -*-

# Get the absolute path of the directory containing the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Navigate to the parent directory
cd "${SCRIPT_DIR}/.."

chown -R $USER:$USER addons/
chmod -R 755 addons/
docker-compose exec -ti odoo pip install -r addons/requirements.txt
docker-compose exec -ti odoo pip install -r addons/addons.txt
docker-compose exec -ti odoo /usr/bin/odoo -p 8015 -i all
docker-compose exec -ti odoo /usr/bin/odoo -p 8015 -u all