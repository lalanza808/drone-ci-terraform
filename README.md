## Drone CI Terraform Module

This module will provision infrastructure on AWS with a full deployment of [Drone CI](https://drone.io/).

This is still a work in progress and very much in a prototype phase.

## TODO

* ~~Clean up repo (still WIP code, secrets, etc)~~
* ~~ALB access logs to S3~~
* Persistent Drone Server DB (backup and restore)
* Tightened security
* Multiple git platform options (and not just Github)
* Restricted bucket policies
* Better networking options (private vs public)
* Improved tags
* Optional bastion for troubleshooting
* Improved secrets management
* Validate runners
* Programmatic runner scaling
* Lifecycle hooks for better automation

Far out ideas I have:

* Move everything into private subnets and front access with Wireguard access server

### Environment Variables and Secrets

* DRONE_GITHUB_CLIENT_ID
* DRONE_GITHUB_CLIENT_SECRET
* DRONE_RPC_PROTO
* DRONE_RPC_SECRET
* DRONE_SERVER_PROTO
* DRONE_RUNNER_CAPACITY
* DRONE_RUNNER_NAME
