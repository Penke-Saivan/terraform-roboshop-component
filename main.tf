#-----------Created the instance----------------
resource "aws_instance" "main" {
  ami                    = data.aws_ami.ami.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [local.sg_id]
  subnet_id              = local.private_subnet_id
  #   subnet_id              = split(",", data.aws_ssm_parameter.public_subnet_ids.value)[0]


  tags = merge(local.common_tags,
  { Name = "${local.common_name_suffix}-${var.component}" })
}

#COnfiguring using ansible

resource "terraform_data" "main" {


  triggers_replace = [
    aws_instance.main.id #dependent on instaNCE creation
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.main.private_ip
  }

  #Provisioner used to copy files or directories from the machine executing Terraform to the newly created resource.
  #how to copy a file from terraform to ec2


  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = ["chmod +x /tmp/bootstrap.sh",
      "sudo sh /tmp/bootstrap.sh ${var.component} ${var.environment}"
    ]
  }
}

#------------Now next step is stop the instance before taking AMI ---------------------

resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on  = [terraform_data.main] #explicitly telling to run after the resource in []
}


#------Taking AMI out of catalogue instance ID-------------
resource "aws_ami_from_instance" "main" {
  name               = "${local.common_name_suffix}-${var.component}-ami"
  source_instance_id = aws_instance.main.id
  depends_on         = [aws_ec2_instance_state.main] #explicitly telling to run after the resource in []

  tags = merge(local.common_tags,
    { Name = "${local.common_name_suffix}-${var.component}-ami" }
  )
}

#Now creating Target Group

resource "aws_lb_target_group" "main" {
  name = "${local.common_name_suffix}-${var.component}"
  port = local.tg_port # if frontend port is 80, otherwise port is 8080
  #    tg_port = "${var.component}"== "frontend" ? 80 : 8080
  deregistration_delay = 60 #like a notice period as he has to complete his current roles' responsibilities
  #waiting period before deleting the instance

  #  (May be required, Forces new resource) Port on which targets receive traffic, unless overridden when registering a specific target. Required when target_type is instance, ip or alb. Does not apply when target_type is lambda
  protocol = "HTTP"
  vpc_id   = data.aws_ssm_parameter.vpc_id.value
  health_check {
    path = local.health_check_path
    port = local.tg_port
    # The port the load balancer uses when performing health checks on targets. Valid values are either traffic-port, to use the same port as the target group, or a valid port number between 1 and 65536. Default is traffic-port.
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 2
    interval            = 10
    matcher             = "200-299"

    # The HTTP or gRPC codes to use when checking for a successful response from a target. The health_check.protocol must be one of HTTP or HTTPS or the target_type must be lambda. Values can be comma-separated individual values (e.g., "200,202") or a range of values (e.g., "200-299").
  }
}
#aws_launch_template

resource "aws_launch_template" "main" {
  name                                 = "${local.common_name_suffix}-${var.component}"
  image_id                             = aws_ami_from_instance.main.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t3.micro"
  vpc_security_group_ids               = [local.sg_id]
  #  #+++when we run terraform apply again, a new version will be created with new AMI ID-++++++++++++
  update_default_version = true
  tag_specifications {
    #tags attached to the instance
    resource_type = "instance"
    tags = merge(local.common_tags,
    { Name = "${local.common_name_suffix}-${var.component}" })
  }
  tag_specifications {
    #tags attached to the volume created by the instance
    resource_type = "volume"
    tags = merge(local.common_tags,
    { Name = "${local.common_name_suffix}-${var.component}" })
  }

  #tags attached to the Launch template
  tags = merge(local.common_tags,
  { Name = "${local.common_name_suffix}-${var.component}" })
}

#Autoscaling group

resource "aws_autoscaling_group" "main" {
  name                      = "${local.common_name_suffix}-${var.component}"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 100
  health_check_type         = "ELB"
  desired_capacity          = 1
  #Number of Amazon EC2 instances that should be running in the group
  force_delete = false
  #instead of placement group - target group++++++++
  #launch template
  launch_template {
    id      = aws_launch_template.main.id
    version = aws_launch_template.main.latest_version
  }


  vpc_zone_identifier = local.private_subnet_ids #array of private subnets

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50 #atleast 50% of instances should be up
    }
    triggers = ["launch_template"]
  }

  dynamic "tag" {

    #we get the iterationr with name as tag
    for_each = merge(local.common_tags,
    { Name = "${local.common_name_suffix}-${var.component}" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }


  }


  timeouts {
    delete = "15m"
  }
  target_group_arns = [aws_lb_target_group.main.arn]
  # Set of aws_alb_target_group ARNs, for use with Application or Network Load Balancing. To remove all target group attachments an empty list should be specified.

}




#Autoscaling policy

resource "aws_autoscaling_policy" "main" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  name                   = "${local.common_name_suffix}-${var.component}"
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }
}


resource "aws_lb_listener_rule" "main" {
  listener_arn = local.listener_arn
   priority     = var.rule_priority
#   priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }



  condition {
    host_header {
      values = [local.host_context]
    }
  }
}

resource "terraform_data" "main_local" {


  triggers_replace = [
    aws_instance.main.id #dependent on instaNCE creation
  ]

  depends_on = [aws_autoscaling_policy.main]

  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
  }
}
