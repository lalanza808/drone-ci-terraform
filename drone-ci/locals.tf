locals {
  region = data.aws_region.current.name

  tags = {
    ProjectName = var.name
  }
}
