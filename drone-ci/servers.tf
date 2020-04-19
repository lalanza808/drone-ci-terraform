resource "aws_security_group" "servers" {
  name_prefix = "${var.name}-servers-"
  description = "Allow inbound connectivity to the Drone CI server and outbound to pull images/packages"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "servers_inbound_22" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpn.id
  security_group_id        = aws_security_group.servers.id
}

resource "aws_security_group_rule" "servers_inbound_80" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpn.id
  security_group_id        = aws_security_group.servers.id
}

resource "aws_security_group_rule" "servers_inbound_443" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpn.id
  security_group_id        = aws_security_group.servers.id
}

resource "aws_security_group_rule" "servers_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.servers.id
}

data "aws_iam_policy_document" "servers_assume_role" {
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

data "aws_iam_policy_document" "server_iam" {
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
      "s3:Put*"
    ]
    resources = [
      "${aws_s3_bucket.server_backups.arn}/*"
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

resource "aws_iam_policy" "server_iam" {
  name_prefix = aws_iam_role.servers.name
  description = "Drone CI server programmatic access to manage resources"
  policy      = data.aws_iam_policy_document.server_iam.json
}

resource "aws_iam_role_policy_attachment" "server_iam" {
  role       = aws_iam_role.servers.name
  policy_arn = aws_iam_policy.server_iam.arn
}

resource "aws_iam_role" "servers" {
  name_prefix        = "${var.name}-servers-"
  assume_role_policy = data.aws_iam_policy_document.servers_assume_role.json
}

resource "aws_iam_role_policy_attachment" "servers" {
  role       = aws_iam_role.servers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "servers" {
  name = aws_iam_role.servers.name
  role = aws_iam_role.servers.name
}

module "servers_asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  name                      = "${var.name}-servers-"
  image_id                  = data.aws_ami.ubuntu.image_id
  instance_type             = var.server_instance_type
  security_groups           = [aws_security_group.servers.id]
  iam_instance_profile      = aws_iam_instance_profile.servers.name
  asg_name                  = "${var.name}-servers-"
  lc_name                   = "${var.name}-servers-"
  health_check_type         = "EC2"
  vpc_zone_identifier       = var.private_subnets
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  default_cooldown          = 120
  health_check_grace_period = 120
  key_name                  = var.key_name


  user_data = templatefile("${path.module}/files/server_user_data.sh", {
    DRONE_GITHUB_CLIENT_ID     = var.DRONE_GITHUB_CLIENT_ID
    DRONE_GITHUB_CLIENT_SECRET = var.DRONE_GITHUB_CLIENT_SECRET
    DRONE_RPC_SECRET           = var.DRONE_RPC_SECRET
    DRONE_SERVER_HOST          = "${var.subdomain}.${var.domain_name}"
    DRONE_SERVER_PROTO         = var.DRONE_SERVER_PROTO
    DRONE_S3_BUCKET            = aws_s3_bucket.server_logs.id
    DRONE_USER_FILTER          = var.github_admin_user
    DRONE_USER_CREATE          = "username:${var.github_admin_user},admin:true"
    ADMIN_EMAIL                = var.admin_email
    BACKUP_BUCKET              = aws_s3_bucket.server_backups.id
    CRON_EXPRESSION            = var.server_backup_cron
    ZONE_ID                    = data.aws_route53_zone.domain.zone_id
  })
  tags_as_map = {
    "Name"      = "${var.name}-servers"
    "Project"   = "DroneCI"
    "Component" = "servers"
  }
}
