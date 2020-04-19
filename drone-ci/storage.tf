resource "aws_s3_bucket" "server_logs" {
  bucket_prefix = "${var.name}-server-build-logs-"
  acl           = "private"
}

resource "aws_s3_bucket" "server_backups" {
  bucket_prefix = "${var.name}-server-backups-"
  acl           = "private"
}

resource "aws_s3_bucket_policy" "server_logs" {
  bucket = aws_s3_bucket.server_logs.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${lookup(local.elb_logging, local.region, "us-east-1")}:root"
            },
            "Action": "s3:PutObject",
            "Resource": "${aws_s3_bucket.server_alb_logs.arn}/*"
        }
    ]
}
POLICY
}

resource "aws_s3_bucket" "server_alb_logs" {
  bucket_prefix = "${var.name}-alb-logs-"
  acl           = "private"
  force_destroy = var.force_destroy_bucket

  tags = var.tags

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
