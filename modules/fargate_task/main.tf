resource "aws_security_group" "alb" {
    name = "${var.name}-ecs-elb"
    description = "ALB Security Group"
    vpc_id = "${var.vpc_id}"

    ingress {
        protocol = "tcp"
        from_port = 80
        to_port = 80
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    egress {
        from_port = 0
        to_port   = 0
        protocol  = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Traffic to the ECS Cluster should only come from the ALB
resource "aws_security_group" "fargate_task" {
  name        = "${var.name}-ecs-tasks"
  description = "allow inbound access from the ALB only"
  vpc_id      = "${var.vpc_id}"

  ingress {
    protocol        = "tcp"
    from_port       = "${var.container_port}"
    to_port         = "${var.container_port}"
    security_groups = ["${aws_security_group.alb.id}"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "fargate_alb" {
    name = "${var.name}-alb"
    subnets = "${var.subnets}"
    security_groups = ["${aws_security_group.alb.id}"]
}
resource "aws_alb_target_group" "target_group" {
  name        = "${var.name}-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "${var.vpc_id}"
  target_type = "ip"

  health_check {
    path = "${var.health_check["path"]}"
    matcher = "${var.health_check["http_code"]}"
    interval = 5
    timeout = 2
  }
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = "${aws_alb.fargate_alb.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.target_group.id}"
    type             = "forward"
  }
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${var.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.fargate_cpu}"
  memory                   = "${var.fargate_memory}"
  execution_role_arn       = "${var.task_execution_role_arn}"
  task_role_arn            = "${var.task_role_arn}",


  container_definitions = <<DEFINITION
[
  {
    "cpu": ${var.fargate_cpu},
    "image": "${var.app_image}",
    "memory": ${var.fargate_memory},
    "memoryReservation": ${var.fargate_memory},
    "name": "${var.name}",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": ${var.container_port},
        "hostPort": ${var.container_port}
      }
    ]
  }
]
DEFINITION
}

resource "aws_ecs_service" "service" {
  name            = "${var.name}-ecs-services"
  cluster         = "${var.cluster_id}"
  task_definition = "${aws_ecs_task_definition.task_definition.arn}"
  desired_count   = 1
  launch_type     = "FARGATE"
  health_check_grace_period_seconds = 60
  

  network_configuration {
    security_groups = ["${aws_security_group.fargate_task.id}"]
    subnets         = "${var.subnets}"
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.target_group.id}"
    container_name   = "${var.name}"
    container_port   = "${var.container_port}"
  }

  depends_on = [
    "aws_alb_listener.alb_listener",
  ]
}