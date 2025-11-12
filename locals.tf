locals {
  common_name = "${var.project}- ${var.environment}"
  # vpc_id      = data.aws_ssm_parameter.vpc_id.value

  # private_subnet_id  = split(",", data.aws_ssm_parameter.private_subnet_ids.value)[0]
  # private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  #   backend_alb_listener_arn = data.aws_ssm_parameter.backend_alb_listener_arn.value
  backend_alb_listener_arn  = data.aws_ssm_parameter.backend_alb_listener_arn.value
  frontend_alb_listener_arn = data.aws_ssm_parameter.frontend_alb_listener_arn.value
  listener_arn              = "${var.component}" == "frontend" ? local.frontend_alb_listener_arn : local.backend_alb_listener_arn
  sg_id                     = data.aws_ssm_parameter.sg_id.value
  host_context              = "${var.component}" == "frontend" ? "${var.project}-${var.environment}.${var.zone_name}" : "${var.component}.backend-alb-${var.environment}.${var.zone_name}"
  tg_port                   = "${var.component}" == "frontend" ? 80 : 8080
  health_check_path         = "${var.component}" == "frontend" ? "/" : "/health"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Terraform   = true
  }
  common_name_suffix = "${var.project}-${var.environment}"
}
