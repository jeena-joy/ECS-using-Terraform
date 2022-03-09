provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAZ7WQCZMD6ME4U5UP"
  secret_key = "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"
}

terraform {
  backend "s3" {
    bucket         = "jeena-terra"
    key            = "global/s3/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-bucket"
    encrypt        = true
  }
}

resource "aws_ecs_cluster" "demo" {
      name = "demo"
    }
    
    data "aws_iam_policy_document" "ecs_agent" {
      statement {
        actions = ["sts:AssumeRole"]

        principals {
          type        = "Service"
          identifiers = ["ec2.amazonaws.com"]
    }
  }
}

    resource "aws_iam_role" "ecs_elb" {
        name = "ecs-elb"
        assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
    }

    resource "aws_iam_policy_attachment" "ecs_elb" {
        name = "ecs_elb"
        roles = ["${aws_iam_role.ecs_elb.id}"]
        policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    }

    resource "aws_iam_instance_profile" "ecs_profile" {
        name = "ecs-agent"
        role = aws_iam_role.ecs_elb.id
    }  

    resource "aws_launch_configuration" "ecs_instance"{
        name_prefix = "ecs-instance-"
        iam_instance_profile = aws_iam_instance_profile.ecs_profile.name
        instance_type = "t2.micro"
        image_id = "ami-01e9c477d7a1eccbf"
        key_name = "jeenajeena"
        user_data = "#!/bin/bash\necho ECS_CLUSTER=demo >> /etc/ecs/ecs.config"
    }

    resource "aws_autoscaling_group" "ecs_cluster_instances"{
        availability_zones = ["ap-south-1a"]
        name = "ecs-cluster-instances"
        min_size = 2
        max_size = 2
        launch_configuration = "${aws_launch_configuration.ecs_instance.id}"
    }

    resource "aws_ecs_task_definition" "nginx" {
      family = "nginx"
      container_definitions = <<EOF
      [{
        "name": "nginx",
        "image": "nginx",
        "cpu": 1024,
        "memory": 768,
        "essential": true,
        "portMappings": [{"containerPort":80, "hostPort":80 }]
      }]
      EOF
    }

    resource "aws_ecs_service" "nginx" {
        name = "nginx"
        cluster = "${aws_ecs_cluster.demo.id}"
        task_definition = "${aws_ecs_task_definition.nginx.arn}"
        desired_count = 1
      #  iam_role = "aws_iam_role.ecs_elb.arn"
        load_balancer {
            elb_name = "${aws_elb.nginx.id}"
            container_name = "nginx"
            container_port = 80
        }
    }

    resource "aws_elb" "nginx" {
        availability_zones = ["ap-south-1a"]
        name = "nginx"
        listener {
            lb_port = 80
            lb_protocol = "http"
            instance_port = 80
            instance_protocol = "http"
        }
    }
