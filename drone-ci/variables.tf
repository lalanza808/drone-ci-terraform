# Meta
variable "name" {
  description = "Name to use for tagging resources"
}
variable "subdomain" {
  description = "Subdomain to use for endpoint on the existing domain"
}
variable "vpn_subdomain" {
  default = "vpn"
}
variable "domain_name" {
  description = "Route53 zone name where DNS records should be provisioned"
}
variable "key_name" {
  description = "Name of SSH key to use for provisioning resources"
}
variable "runner_instance_type" {
  description = "EC2 instance type to use for Drone CI Runners"
}
variable "server_instance_type" {
  description = "EC2 instance type to use for Drone CI server"
}
variable "vpn_instance_type" {
  description = "EC2 instance type to use for Wireguard VPN server"
}
variable "min_runner_nodes" {
  default = "1"
}
variable "max_runner_nodes" {
  default = "2"
}
variable "des_runner_nodes" {
  default = "1"
}
variable "github_admin_user" {
  description = "The primary admin user to create on the Drone CI server"
}
variable "admin_email" {
  description = "Email address to use for Lets Encrypt certs"
}
variable "server_backup_cron" {
  default     = "0 */12 * * *"
  description = "The cronjob expression to represent your backup schedule"
}
variable "force_destroy_bucket" {
  default     = true
  description = "Whether or not to forcibly delete all data in the bucket and delete it"
}

# Network
variable "vpc_id" {
  default = "VPC ID to deploy network resources into"
}
variable "public_subnets" {
  type        = list
  description = "List of subnets where server instances will be deployed to"
}
variable "private_subnets" {
  type        = list
  description = "List of subnets where runner instances will be deployed to"
}
variable "allowed_mgmt_ips" {
  type    = list
  default = []
}
variable "allowed_vpn_ips" {
  type    = list
  default = ["0.0.0.0/0"]
}
variable "internal" {
  default     = false
  description = "Whether or not the ALB for servers should be private or public"
}
variable "vpn_upstream_dns" {
  default = "4.2.2.1"
}

# Secrets
variable "DRONE_GITHUB_CLIENT_ID" {}
variable "DRONE_GITHUB_CLIENT_SECRET" {}
variable "DRONE_RPC_SECRET" {}
variable "DRONE_RPC_PROTO" {}
variable "DRONE_SERVER_PROTO" {}
variable "DRONE_RUNNER_CAPACITY" {}
variable "DRONE_RUNNER_NAME" {}
variable "VPN_ADMIN_USER" {}
variable "VPN_ADMIN_PASSWORD" {}
