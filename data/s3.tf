# Get the account id of the AWS NLB and ELB service account in a given region for the
# purpose of whitelisting in a S3 bucket policy.
data "aws_elb_service_account" "main" {
}
# The AWS account id
data "aws_caller_identity" "current" {
}
# The AWS partition for differentiating between AWS commercial and GovCloud
data "aws_partition" "current" {
}

locals {
  nlb_logs_prefixes = ["fargate/nlb"]
  bucket_arn        = "arn:${data.aws_partition.current.partition}:s3:::${module.config.entries.tags.prefix}logs"
}

locals {
  # NLB locals
  # doesn't support logging to multiple accounts
  nlb_account = data.aws_caller_identity.current.account_id
  # supports logging to multiple prefixes
  nlb_effect = "Allow"
  # create a list of paths, but remove any prefixes containing "" using compact
  nlb_logs_path = formatlist("%s/AWSLogs", compact(local.nlb_logs_prefixes))
  # finally, format the full final resources ARN list
  nlb_resources = sort(formatlist("${local.bucket_arn}/%s/${local.nlb_account}/*", local.nlb_logs_path))
}

data "aws_iam_policy_document" "main" {
  # ALB bucket policies
  statement {
    sid    = "nlb-logs-put-object"
    effect = local.nlb_effect
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = local.nlb_resources
  }
  statement {
    sid    = "nlb-check-acl"
    effect = local.nlb_effect
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [local.bucket_arn]
  }
}

resource "aws_s3_bucket" "aws_logs" {
  bucket        = "${module.config.entries.tags.prefix}logs"
  acl           = "log-delivery-write"
  policy        = data.aws_iam_policy_document.main.json
  force_destroy = true

  lifecycle_rule {
    id      = "expire_all_logs"
    prefix  = "/*"
    enabled = true
    expiration {
      days = 1
    }
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  tags = merge(
    module.config.entries.tags.standard,
    {
      "Name" = "${module.config.entries.tags.prefix}logs"
    },
  )
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.aws_logs.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}