from odoo import models, fields, api
from linkedin_api import Linkedin
from odoo.exceptions import ValidationError

class LinkedinConfig(models.TransientModel):
    _inherit = 'res.config.settings'

    linkedin_auth = fields.Boolean(string='Enable LinkedIn Authentication')
    linkedin_client_id = fields.Char(string='Client ID')
    linkedin_secret_id = fields.Char(string='Secret ID')
    linkedin_email = fields.Char(string='Email')
    linkedin_password = fields.Char(string='Password')

    @api.model
    def get_values(self):
        res = super(LinkedinConfig, self).get_values()
        res.update(
            linkedin_auth=self.env['ir.config_parameter'].sudo().get_param('linkedin_auth'),
            linkedin_client_id=self.env['ir.config_parameter'].sudo().get_param('linkedin_client_id'),
            linkedin_secret_id=self.env['ir.config_parameter'].sudo().get_param('linkedin_secret_id'),
            linkedin_email=self.env['ir.config_parameter'].sudo().get_param('linkedin_email'),
            linkedin_password=self.env['ir.config_parameter'].sudo().get_param('linkedin_password'),
        )
        return res

    def set_values(self):
        super(LinkedinConfig, self).set_values()
        self.env['ir.config_parameter'].sudo().set_param('linkedin_auth', self.linkedin_auth)
        self.env['ir.config_parameter'].sudo().set_param('linkedin_client_id', self.linkedin_client_id)
        self.env['ir.config_parameter'].sudo().set_param('linkedin_secret_id', self.linkedin_secret_id)
        self.env['ir.config_parameter'].sudo().set_param('linkedin_email', self.linkedin_email)
        self.env['ir.config_parameter'].sudo().set_param('linkedin_password', self.linkedin_password)
        try:
            linkedin_api = Linkedin(
                self.linkedin_email,
                self.linkedin_password
            )
        except Exception as e:
            raise ValidationError("Error authenticating with LinkedIn: %s" % str(e))