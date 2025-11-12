data "aws_ami" "ami" {

  most_recent = true

  owners = ["973714476881"] #Owner ID

  filter {
    name   = "name"
    values = ["RHEL-9-DevOps-Practice"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


data "aws_ssm_parameter" "sg_id" {
  name = "/${var.project}/${var.environment}/${var.component}_sg-id"
}

# variable "sg_name" {
#   default = ["mysql", "redis", "rabbitmq", "mongodb",
#     "bastion",
#     "fronted-lb", "frontend",
#     "backend-alb",
#   "catalogue", "user", "cart", "shipping", "payment"]
# }

# resource "aws_ssm_parameter" "sg_ids" {
#   count = length(var.sg_name)
#   name  = "/${var.project}/${var.environment}/${var.sg_name[count.index]}_sg-id"
#   type  = "String"
#   value = module.sg[count.index].sg_id
# }

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project}/${var.environment}/vpc-id"
}

data "aws_ssm_parameter" "backend_alb_listener_arn" {
  name = "/${var.project}/${var.environment}/backend_alb_listener_arn"
}
data "aws_ssm_parameter" "frontend_alb_listener_arn" {
  name = "/${var.project}/${var.environment}/frontend_alb_listener_arn"
  #   name = "/${var.project}/${var.environment}/backend_alb_listener_arn"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.project}/${var.environment}/private_subnet_ids"

}

