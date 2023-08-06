# -*- coding: utf-8 -*-
{
"name": "LinkedIn Plugin",
"summary": "Adds a linkedin field in the contacts model and imports the profile picture from the personal account",
"license": "AGPL-3",
"description": "Add linkedIn field in Contact and add profile picture from it",
"author": "Unite",
'depends': [
    "base",
    "contacts",
    "web", 
    "base_setup", 
    "auth_signup",
    "auth_oauth",
],
"application": True,
"data": [
	"views/partner_views.xml",
    "views/user_views.xml",
    "views/res_config_settings_view.xml",
    "views/config_parameters.xml",
    'views/auth_oauth_templates.xml',
    "data/cron.xml",
]
}
