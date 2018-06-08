variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {
  description = "AWS Region for the resource"
  default = "us-east-1"
}
variable "key_path" {
  description = "SSH public key path"
  default = "nginx-kp.pub"
}
variable "etcd_instances" {
  description = "Number of etcd nodes in the cluster"
  default = "1"
}