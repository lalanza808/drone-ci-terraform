data "aws_route53_zone" "domain" {
  name = var.domain_name
}

resource "aws_route53_record" "drone-endpoint" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = var.subdomain
  type    = "A"

  alias {
    name                   = aws_lb.servers.dns_name
    zone_id                = aws_lb.servers.zone_id
    evaluate_target_health = true
  }
}
