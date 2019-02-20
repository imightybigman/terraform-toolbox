variable "cluster_id" {}
variable "name" {
    description = "name for this module"
}

variable "container_port" {
    description = "port from which your container is exposing"
    default = 80
}
variable "vpc_id" {}
variable "subnets" {}

variable "health_check" {
    type = "map"

    default = {
        path = "/"
        http_code = 200
    }
}
variable "app_image" {
  description = "Docker image to run in the ECS cluster"
}
variable "fargate_cpu" {
  description = "Fargate instance CPU"
  default     = 256
}
variable "fargate_memory" {
  description = "Fargate instance memory"
  default     = 1024
}
variable "task_execution_role_arn" {}

variable "task_role_arn" {}
