resource "aws_security_group" "vpn" {
  name_prefix = "${var.name}-vpn-"
  description = "Allow inbound connectivity to the Drone CI server and runners"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "vpn_inbound_22" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_mgmt_ips
  security_group_id = aws_security_group.vpn.id
}

resource "aws_security_group_rule" "vpn_inbound_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_mgmt_ips
  security_group_id = aws_security_group.vpn.id
}

resource "aws_security_group_rule" "vpn_inbound_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_mgmt_ips
  security_group_id = aws_security_group.vpn.id
}

resource "aws_security_group_rule" "vpn_inbound_51820" {
  type              = "ingress"
  from_port         = 51820
  to_port           = 51820
  protocol          = "tcp"
  cidr_blocks       = var.allowed_vpn_ips
  security_group_id = aws_security_group.vpn.id
}

resource "aws_security_group_rule" "vpn_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vpn.id
}

data "aws_iam_policy_document" "vpn_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "vpn_iam" {
  statement {
    actions = [
      "route53:ListHostedZones",
      "route53:GetChange"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${data.aws_route53_zone.domain.zone_id}"
    ]
  }
}

resource "aws_iam_policy" "vpn_iam" {
  name_prefix = aws_iam_role.vpn.name
  description = "Wireguard VPN server programmatic access to manage resources"
  policy      = data.aws_iam_policy_document.vpn_iam.json
}

resource "aws_iam_role_policy_attachment" "vpn_iam" {
  role       = aws_iam_role.vpn.name
  policy_arn = aws_iam_policy.vpn_iam.arn
}

resource "aws_iam_role" "vpn" {
  name_prefix        = "${var.name}-vpn-"
  assume_role_policy = data.aws_iam_policy_document.vpn_assume_role.json
}

resource "aws_iam_role_policy_attachment" "vpn" {
  role       = aws_iam_role.vpn.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "vpn" {
  name = aws_iam_role.vpn.name
  role = aws_iam_role.vpn.name
}

module "vpn_asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  name                      = "${var.name}-vpn-"
  image_id                  = data.aws_ami.ubuntu.image_id
  instance_type             = var.vpn_instance_type
  security_groups           = [aws_security_group.vpn.id]
  iam_instance_profile      = aws_iam_instance_profile.vpn.name
  asg_name                  = "${var.name}-vpn-"
  lc_name                   = "${var.name}-vpn-"
  health_check_type         = "EC2"
  vpc_zone_identifier       = var.public_subnets
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  default_cooldown          = 120
  health_check_grace_period = 120
  key_name                  = var.key_name

  user_data = templatefile("${path.module}/files/vpn_user_data.sh", {
    VPN_SERVER_HOST    = "${var.vpn_subdomain}.${var.subdomain}.${var.domain_name}"
    VPN_ADMIN_USER     = var.VPN_ADMIN_USER
    VPN_ADMIN_PASSWORD = var.VPN_ADMIN_PASSWORD
    ADMIN_EMAIL        = var.admin_email
    ZONE_ID            = data.aws_route53_zone.domain.zone_id
    UPSTREAM_DNS       = var.vpn_upstream_dns
  })
  tags_as_map = {
    "Name"      = "${var.name}-vpn"
    "Project"   = "DroneCI"
    "Component" = "vpn"
  }
}
