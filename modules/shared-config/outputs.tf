output "entries" {
  value = {

    main = {
      client_name              = local.client_name
      tf_module_name           = local.tf_module_name
      environment_name         = local.environment_name
      project_environment_name = local.project_environment_name
      main_aws_region          = local.main_aws_region
    }

    amis = {
      base_ami = local.base_ami
    }

    network = {
      vpc_cidr               = local.environment_cidr
      public_sub_1a_cidr     = local.environment_public_sub_1a_cidr
      public_sub_1a_zone_id  = local.environment_public_sub_1a_zone_id
      public_sub_1b_cidr     = local.environment_public_sub_1b_cidr
      public_sub_1b_zone_id  = local.environment_public_sub_1b_zone_id
      private_sub_1a_cidr    = local.environment_private_sub_1a_cidr
      private_sub_1a_zone_id = local.environment_private_sub_1a_zone_id
      private_sub_1b_cidr    = local.environment_private_sub_1b_cidr
      private_sub_1b_zone_id = local.environment_private_sub_1b_zone_id
      nlb_fargate_lis_hello  = local.environment_nlb_fargate_lisener_hello
      nlb_fargate_targ_hello = local.environment_nlb_fargate_target_hello
    }

    dns = {
      api_dns               = local.environment_api_dns
      domain                = local.environment_primary_domain
      main_public_hosted_id = local.environment_api_hosted_id
    }

    tags = {
      prefix   = local.name_prefix
      standard = local.standard
    }

    ecs = {
      task_hello_cpu            = local.environment_task_hello_cpu 
      task_hello_mem            = local.environment_task_hello_mem
      task_hello_asg_max        = local.environment_task_hello_asg_max
      task_hello_asg_min        = local.environment_task_hello_asg_min
      task_hello_asg_mem        = local.environment_task_hello_asg_mem
      task_hello_asg_cpu        = local.environment_task_hello_asg_cpu
      task_hello_cont_demo_name = local.environment_task_hello_cont_demo_name 
      task_hello_cont_demo_tag  = local.environment_task_hello_cont_demo_tag 
      task_hello_cont_demo_mem  = local.environment_task_hello_cont_demo_mem 
      task_hello_cont_demo_cpu  = local.environment_task_hello_cont_demo_cpu
    }
  }
}