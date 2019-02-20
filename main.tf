resource "aws_ecs_cluster" "fargate_cluster" {
  name = "cluster name"
}
module "task-name" {
    source = "./modules/fargate_task"
    app_image = "image"
    cluster_id = "${aws_ecs_cluster.fargate_cluster.id}"
    name = "task name"
    health_check = {
        path = "/"
        http_code = 200
    }
}