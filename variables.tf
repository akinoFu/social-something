variable "region" {
  description = "The AWS region where the infrastructure will be deployed"
  type        = string
}
variable "bucket_name" {
  description = "The AWS S3 bucket name for social something app"
  type        = string
}

variable "database_admin_password" {
  description = "The db password"
  type        = string
}