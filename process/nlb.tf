
resource "aws_alb" "fargate_nlb" {
  name               = "${module.config.entries.tags.prefix}fargate-private-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets = [
    data.terraform_remote_state.net_state.outputs.entries.subnet_id.private_sub_1a_id,
    data.terraform_remote_state.net_state.outputs.entries.subnet_id.private_sub_1b_id
  ]

  access_logs {
    bucket  = data.terraform_remote_state.data_state.outputs.entries.s3_id.log
    prefix  = "fargate/nlb"
    enabled = true
  }
  tags = merge(
    module.config.entries.tags.standard,
    {
      "Name" = "${module.config.entries.tags.prefix}fargate-private-nlb"
    },
  )
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "fargate_nlb_listener_http_hello" {
  load_balancer_arn = aws_alb.fargate_nlb.id
  port              = module.config.entries.network.nlb_fargate_lis_hello.port
  protocol          = module.config.entries.network.nlb_fargate_lis_hello.protocol
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = data.terraform_remote_state.sec_state.outputs.entries.acm_cert_arn.api

  default_action {
    target_group_arn = aws_alb_target_group.fargate_nlb_target_http_hello.id
    type             = module.config.entries.network.nlb_fargate_lis_hello.type
  }
}

resource "aws_alb_target_group" "fargate_nlb_target_http_hello" {
  name        = "${module.config.entries.tags.prefix}fargate-nlb-http-hello"
  port        = module.config.entries.network.nlb_fargate_targ_hello.port
  protocol    = module.config.entries.network.nlb_fargate_targ_hello.protocol
  vpc_id      = data.terraform_remote_state.net_state.outputs.entries.vpc.mainvpc_id
  target_type = module.config.entries.network.nlb_fargate_targ_hello.type

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = module.config.entries.network.nlb_fargate_targ_hello.health.protocol
    path                = module.config.entries.network.nlb_fargate_targ_hello.health.path
    unhealthy_threshold = "3"
  }
  depends_on = [aws_alb.fargate_nlb]
}