variable "project" {
	default="gridu-gcp"
}

variable "zone" {
	default="us-central1-c"
}

variable "base_instance_name" {
	default="gcpspy"
}

variable "region" {
	default="us-central1"
}

variable "ssh_pub_key_file" {
	default="../creds/public_rsa"
}
variable "port" {
	default="80"
}

variable "target_size" {
	default="3"
}

variable "max_replicas" {
	default="3"
}

variable "readiness_timeout" {
  description = "Readiness health check timeout sec"
  default     = 5
}

variable "readiness_check_interval" {
  description = "Readiness health check interval sec"
  default     = 10
}
