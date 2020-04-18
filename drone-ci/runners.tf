resource "aws_security_group" "runners" {
  name_prefix = "${var.name}-runners-"
  description = "Allow outbound connectivity to the Drone CI server and to pull images/packages"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "runners_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.runners.id
}

data "aws_iam_policy_document" "assume_role" {
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

resource "aws_iam_role" "runners" {
  name_prefix        = "${var.name}-runners-"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "runners" {
  role       = aws_iam_role.runners.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "runners" {
  name = aws_iam_role.runners.name
  role = aws_iam_role.runners.name
}

module "runners_asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  name                      = "${var.name}-runners-"
  image_id                  = data.aws_ami.ubuntu.image_id
  instance_type             = var.runner_instance_type
  security_groups           = [aws_security_group.runners.id]
  iam_instance_profile      = aws_iam_instance_profile.runners.name
  asg_name                  = "${var.name}-runners-"
  lc_name                   = "${var.name}-runners-"
  health_check_type         = "EC2"
  vpc_zone_identifier       = var.private_subnets
  min_size                  = var.min_runner_nodes
  max_size                  = var.max_runner_nodes
  desired_capacity          = var.des_runner_nodes
  wait_for_capacity_timeout = 0
  default_cooldown          = 120
  health_check_grace_period = 120
  key_name                  = var.key_name

  user_data = templatefile("${path.module}/files/runner_user_data.sh", {
    DRONE_RPC_PROTO = var.DRONE_RPC_PROTO
    DRONE_RPC_HOST = "${var.subdomain}.${var.domain_name}"
    DRONE_RPC_SECRET = var.DRONE_RPC_SECRET
    DRONE_RUNNER_CAPACITY = var.DRONE_RUNNER_CAPACITY
    DRONE_RUNNER_NAME = var.DRONE_RUNNER_NAME
  })
  tags_as_map = {
    "Name"      = "${var.name}-runners"
    "Project"   = "DroneCI"
    "Component" = "Runners"
  }
}
