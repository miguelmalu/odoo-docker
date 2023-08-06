# -*- coding: utf-8 -*-

import base64
import urllib.request
import urllib.parse
import time
import re
from odoo import api, fields, models
from odoo.exceptions import ValidationError
from linkedin_api import Linkedin

class ResPartnerInherit(models.Model):

    _inherit = 'res.partner'

    linkedin = fields.Char(string="LinkedIn", widget="url")
    linkedin_confirm = fields.Boolean(default=True)

    def update_partner_image(self):
        if self.linkedin != False:
            if not self.is_valid_linkedin_url(self.linkedin):
                raise ValidationError("LinkedIn profile url not valid")

            # Authenticate using any Linkedin account credentials
            email = self.env['ir.config_parameter'].sudo().get_param('linkedin_email')
            password = self.env['ir.config_parameter'].sudo().get_param('linkedin_password')

            max_attempts = 5

            for attempt in range(max_attempts):
                try:
                    api = Linkedin(email, password)
                    break
                except Exception as e:
                    if str(e) != 'CHALLENGE':
                        raise ValidationError("Error authenticating with LinkedIn: %s" % str(e))
                    else:
                        if(attempt == max_attempts - 1):
                            raise ValidationError("Error authenticating with LinkedIn: %s" % str(e))

            # GET a profile
            profile = api.get_profile(urllib.parse.unquote(self.linkedin).split("/in/")[1].strip("/"))

            try:
                headline = profile['headline']
                if headline:
                    self.write({
                        'function': headline
                    })
            except Exception as e:
                print("Could not Update the headline from linkedin")

            try:
                image_url = profile['displayPictureUrl'] + profile['img_800_800']
                if image_url:
                    image_data = urllib.request.urlopen(image_url).read()
                    self.write({
                        'image_1920': base64.b64encode(image_data),
                    })
            except Exception as e:
                 print("Could not Update the headline from linkedin")

    @api.model 
    def cron_update_image(self):
        for record in self:
            if record.linkedin_confirm and record.linkedin:
                record.update_partner_image()
                time.sleep(30)

    @api.constrains('linkedin', 'linkedin_confirm')
    def _check_linkedin(self):
        for record in self:
            record.update_partner_image()

    def is_valid_linkedin_url(self, url):
        pattern = re.compile(r'^https?://(?:www\.)?linkedin\.com/(?:in|pub|company)/.*$')
        return bool(pattern.match(url))