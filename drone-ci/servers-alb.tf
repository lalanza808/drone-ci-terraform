resource "aws_security_group" "servers_alb" {
  name_prefix = "${var.name}-servers-alb"
  description = "Allow public HTTP access to the load balancer for ${var.subdomain}.${var.domain_name}"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "servers_alb_inbound_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ips
  security_group_id = aws_security_group.servers_alb.id
}

resource "aws_security_group_rule" "servers_alb_inbound_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ips
  security_group_id = aws_security_group.servers_alb.id
}

resource "aws_security_group_rule" "servers_alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.servers_alb.id
}

resource "aws_lb" "servers" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.servers_alb.id]
  subnets            = var.public_subnets

  enable_deletion_protection = false

  # access_logs {
  #   bucket  = "${aws_s3_bucket.lb_logs.bucket}"
  #   prefix  = "test-lb"
  #   enabled = true
  # }

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "servers_80" {
  name     = "${var.name}-http"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/healthz"
    matcher = "200,307"
    interval = 5
    timeout = 3
  }
}

resource "aws_lb_target_group" "servers_443" {
  name     = "${var.name}-https"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = var.vpc_id

  health_check {
    path = "/healthz"
    matcher = "200"
    protocol = "HTTPS"
    interval = 5
    timeout = 3
  }
}

resource "aws_lb_listener" "servers_80" {
  load_balancer_arn = aws_lb.servers.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.servers_80.arn
  }
}

resource "aws_lb_listener" "servers_443" {
  load_balancer_arn = aws_lb.servers.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = module.certs.this_acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.servers_443.arn
  }
}
