module "certs" {
  source  = "terraform-aws-modules/acm/aws"

  domain_name               = var.domain_name
  zone_id                   = data.aws_route53_zone.domain.zone_id
  wait_for_validation       = true
  subject_alternative_names = ["${var.subdomain}.${var.domain_name}"]
  tags                      = local.tags
}
