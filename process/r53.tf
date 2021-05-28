
resource "aws_route53_record" "api_subdomain" {
  name    = "api"
  zone_id = module.config.entries.dns.main_public_hosted_id
  type    = "A"

  alias {
    evaluate_target_health = false
    name                   = aws_api_gateway_domain_name.rest_api_nlb_custom_domain.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.rest_api_nlb_custom_domain.regional_zone_id
  }
}