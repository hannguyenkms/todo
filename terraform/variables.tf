variable "project_id" {
  description = "Google Cloud Project ID"
  default     = "hazel-chiller-461303-m9"
}

variable "region" {
  description = "Google Cloud Region"
  default     = "asia-northeast1"
}

variable "image_registry" {
  description = "Container Registry path"
  default     = "asia-northeast1-docker.pkg.dev/hazel-chiller-461303-m9/master/todo-app"
}

variable "image_tag" {
  description = "Container image tag to deploy"
  default     = "latest"
}

variable "min_instances" {
  description = "Minimum number of instances"
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  default     = 4
}

variable "memory_limit" {
  description = "Memory limit for Cloud Run services"
  default     = "512Mi"
}

variable "cpu_limit" {
  description = "CPU limit for Cloud Run services"
  default     = "1000m"
}