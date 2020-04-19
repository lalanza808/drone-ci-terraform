resource "aws_s3_bucket" "server_logs" {
  bucket_prefix = "${var.name}-server-build-logs-"
  acl           = "private"
}

resource "aws_s3_bucket" "server_backups" {
  bucket_prefix = "${var.name}-server-backups-"
  acl           = "private"
}
