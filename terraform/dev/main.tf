terraform {
  required_version = "~> 0.14.0"
  # ~>: pessimistic constraint operator.
  # Example: for ~> 0.9, this means >= 0.9, < 1.0.
  # Example: for ~> 0.8.4, this means >= 0.8.4, < 0.9

  required_providers {
    aws = {
      version = ">= 2.7.0"
      source  = "hashicorp/aws"
    }
  }

  backend "s3" {
    bucket = "shimpeiws-next-js-ssg"
    key    = "dev/terraform.tfstate"
  }
}

module "web-hosting" {
  source        = "../modules/web-hosting"
  env_name      = "dev"
  cf_ssl_cert   = "arn:aws:acm:us-east-1:607754652120:certificate/7fbf5ba7-375e-4db4-9684-fdd240ab7135"
  domain_name   = "next-js-ssg.test-app.info"
  hostedzone_id = "Z02547091ADCWFQ2WXDT5"
  domain_cnames = ["next-js-ssg.test-app.info"]
}
