#!/bin/bash
# -*- coding: utf-8 -*-
docker-compose exec -ti odoo pip install -r addons/requirements.txt
docker-compose exec -ti odoo /usr/bin/odoo -p 8015 -i all
docker-compose exec -ti odoo /usr/bin/odoo -p 8015 -u all