from odoo import api, http, SUPERUSER_ID
from werkzeug.wrappers import Response
from odoo.http import request
from odoo.addons.auth_signup.controllers.main import AuthSignupHome as Home
from odoo.addons.web.controllers.main import db_monodb, ensure_db, set_cookie_and_redirect, login_and_redirect
import json
import math
import logging
import requests
from werkzeug.utils import redirect
from odoo import registry as registry_get
import urllib.request
import urllib.parse
import base64
import time

_logger = logging.getLogger(__name__)

class LinkedInAuth(Home):
    @http.route("/auth_oauth/linkedin", auth="public")
    def list(self, **kw):

        env = api.Environment(request.cr, SUPERUSER_ID, request.context)

        #search elements
        code = kw.get("code")

        # Set the necessary parameters for the LinkedIn access token request
        grant_type = "authorization_code"
        client_id = str(env['ir.config_parameter'].sudo().get_param('linkedin_client_id'))
        client_secret = str(env['ir.config_parameter'].sudo().get_param('linkedin_secret_id'))
        redirect_uri = str(env['ir.config_parameter'].sudo().get_param('web.base.url')) + "/auth_oauth/linkedin"

        # Construct the URL for the access token request
        access_token_url = "https://www.linkedin.com/oauth/v2/accessToken"

        # Send the HTTP POST request to obtain the access token
        response = requests.post(
            access_token_url,
            params={
                "grant_type": grant_type,
                "client_id": client_id,
                "client_secret": client_secret,
                "code": code,
                "redirect_uri": redirect_uri
            }
        )

        access_token_data = response.json()
        access_token = access_token_data.get("access_token")

        _logger.info(access_token)

        access_user_info_url = "https://api.linkedin.com/v2/me"

        response_user = requests.get(
            access_user_info_url,
            params={
                "oauth2_access_token": str(access_token)
            }
        )

        access_user_data = response_user.json()
        user_id = access_user_data.get("id")
        user_name = access_user_data.get("localizedFirstName")
        user_surname = access_user_data.get("localizedLastName")
        user_linkedin_link = "https://www.linkedin.com/in/" + str(access_user_data.get("vanityName"))

        access_user_image_url = "https://api.linkedin.com/v2/me"

        response_image = requests.get(
            access_user_info_url,
            params={
                "projection": "(id,profilePicture(displayImage~:playableStreams))",
                "oauth2_access_token": str(access_token)
            }
        )

        access_user_image = response_image.json()
        profile_picture_data = access_user_image.get("profilePicture")

        if profile_picture_data:
            display_images = profile_picture_data.get("displayImage~")
            if display_images and "elements" in display_images:
                elements = display_images["elements"]
                for element in elements:
                    identifiers = element.get("identifiers")
                    if identifiers:
                        for identifier in identifiers:
                            if identifier.get("identifierType") == "EXTERNAL_URL":
                                image_url = identifier.get("identifier")
                                if "shrink_400_400" in image_url:
                                    image_data = urllib.request.urlopen(image_url).read()
                                    break

        access_user_email_url = "https://api.linkedin.com/v2/emailAddress"

        response_email = requests.get(
            access_user_email_url,
            params={
                "q": "members",
                "projection": "(elements*(handle~))",
                "oauth2_access_token": str(access_token)
            }
        )

        email_address = ""

        access_user_email = response_email.json()
        elements = access_user_email.get("elements")
        if elements:
            profile_email_data = elements[0].get("handle~")
            if profile_email_data:
                email_address = profile_email_data.get("emailAddress")

        registry = registry_get(env.cr.dbname)
        with registry.cursor() as cr:
            try:
                credentials = request.env['res.users'].sudo().oauth_linkedin(user_id, user_name, user_surname, user_linkedin_link, email_address, str(access_token))
                request.env.cr.commit()
                url = '/'
                resp = login_and_redirect(*credentials, redirect_url=url)
                user = request.env['res.users'].sudo().search([('login', '=', credentials[1])], limit=1)
                if (image_data):
                    user.image_1920 = base64.b64encode(image_data)
                return resp
            except Exception as e:
                # signup error
                _logger.exception("OAuth2: %s" % str(e))
                url = "/web/login?oauth_error=2"
        

    @http.route("/auth_oauth/linkedin/token", auth='public')
    def token(self, *args, **kwargs):
        token = kwargs.get("access_token")

        response_data = {
            "access_token": token
        }
        response_body = json.dumps(response_data)
        return http.Response(response_body, content_type='application/json')
