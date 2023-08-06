# -*- coding: utf-8 -*-
# Part of Odoo. See LICENSE file for full copyright and licensing details.

import json

import requests
import werkzeug.http
from odoo.tools import config, frozendict

from odoo import api, fields, models, tools
from odoo.exceptions import AccessDenied, UserError
from odoo.addons.auth_signup.models.res_users import SignupError


from odoo.addons import base
base.models.res_users.USER_PRIVATE_FIELDS.append('oauth_access_token')

class ResUsers(models.Model):
    _inherit = 'res.users'

    oauth_linkedin_id = fields.Char(string='OAuth User ID', help="Oauth Provider user_id", copy=False)
    oauth_linkedin_token = fields.Char(string='OAuth User Token', help="Oauth Provider token", copy=False)
    
    @api.model
    def oauth_linkedin(self, user_id, user_name, user_surname, user_linkedin_link, email_address, token):

        login = self._auth_oauth_signin_linkedin(user_id, user_name, user_surname, user_linkedin_link, email_address, token)
        if not login:
            raise AccessDenied()

        return (self.env.cr.dbname, login, token)

    @api.model
    def _auth_oauth_signin_linkedin(self, user_id, user_name, user_surname, user_linkedin_link, email_address, token):

        try:
            oauth_user = self.search([("oauth_linkedin_id", "=", user_id)])
            if not oauth_user:
                existing_user = self.search([("login", "=", email_address)])
                if existing_user:
                    existing_user.write({'oauth_linkedin_token': token})
                    existing_user.write({'oauth_access_token': token})
                    existing_user.write({'linkedin': user_linkedin_link})
                    return existing_user.login
                raise AccessDenied()
            assert len(oauth_user) == 1
            oauth_user.write({'oauth_linkedin_token': token})
            oauth_user.write({'oauth_access_token': token})
            oauth_user.write({'linkedin': user_linkedin_link})
            return oauth_user.login
        except AccessDenied as access_denied_exception:
            if self.env.context.get('no_user_creation'):
                return None

            lang_code = self.env['res.lang'].sudo().search([('active', '=', True)], limit=1).code

            values = {
                'name': str(user_name) + " " + str(user_surname),
                'login': email_address,
                'email': email_address,
                'oauth_linkedin_id': user_id,
                'oauth_uid': user_id,
                'oauth_linkedin_token': token,
                'oauth_access_token': token,
                'linkedin': user_linkedin_link,
                'lang': lang_code,
                'active': True,
            }
            _, login, _ = self.signup(values)
            return login