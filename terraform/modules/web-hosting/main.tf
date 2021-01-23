resource "aws_s3_bucket" "bucket" {
  bucket = var.domain_name
  website {
    index_document = "index.html"
    error_document = "error.html"
  }
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

  tags = {
    Environment = var.env_name
  }
}

resource "aws_ssm_parameter" "bucketname" {
  name  = "/${var.env_name}/bucketName-spike-next-js-ssg"
  type  = "String"
  value = aws_s3_bucket.bucket.id
}

resource "aws_s3_bucket_policy" "bucketwithcf" {
  bucket = aws_s3_bucket.bucket.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Principal":{"CanonicalUser":"${aws_cloudfront_origin_access_identity.origin_access_identity.s3_canonical_user_id}"},
      "Action":"s3:GetObject",
      "Resource":"arn:aws:s3:::${aws_s3_bucket.bucket.id}/*"

    }
  ]
}
POLICY
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Access-Only-through-CDN-${var.env_name}"
}

resource "aws_cloudfront_distribution" "distribution" {
  count = var.basic_auth_required ? 0 : 1
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  aliases = var.domain_cnames
  comment = "CDN for ${var.env_name}"
  viewer_certificate {
    acm_certificate_arn = var.cf_ssl_cert
    ssl_support_method  = "sni-only"
  }
  enabled             = true
  http_version        = "http2"
  default_root_object = "index.html"
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"

  }
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    default_ttl     = 86400 #default one day
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
    target_origin_id       = aws_s3_bucket.bucket.id
    viewer_protocol_policy = "redirect-to-https"
  }
  origin {
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.bucket.id
  }

  tags = {
    EnvName = var.env_name
  }
}

resource "aws_cloudfront_distribution" "distribution_with_basic_auth" {
  count = var.basic_auth_required ? 1 : 0
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  aliases = var.domain_cnames
  comment = "CDN for ${var.env_name}"
  viewer_certificate {
    acm_certificate_arn = var.cf_ssl_cert
    ssl_support_method  = "sni-only"
  }
  enabled             = true
  http_version        = "http2"
  default_root_object = "index.html"
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"

  }
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    default_ttl     = 86400 #default one day
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
    target_origin_id       = aws_s3_bucket.bucket.id
    viewer_protocol_policy = "redirect-to-https"
  }
  origin {
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.bucket.id
  }

  tags = {
    EnvName = var.env_name
  }
}

resource "aws_ssm_parameter" "cloudfrontid" {
  count = var.basic_auth_required ? 0 : 1
  name  = "/${var.env_name}/cloudfrontId-spike-next-js-ssg"
  type  = "String"
  value = aws_cloudfront_distribution.distribution[count.index].id
}

resource "aws_route53_record" "cfarecord" {
  count   = var.basic_auth_required ? 0 : 1
  zone_id = var.hostedzone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.distribution[count.index].domain_name
    zone_id                = aws_cloudfront_distribution.distribution[count.index].hosted_zone_id #CloudFront's default HostedZoneId
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cfarecord_with_basic_auth" {
  count   = var.basic_auth_required ? 1 : 0
  zone_id = var.hostedzone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.distribution_with_basic_auth[count.index].domain_name
    zone_id                = aws_cloudfront_distribution.distribution_with_basic_auth[count.index].hosted_zone_id #CloudFront's default HostedZoneId
    evaluate_target_health = false
  }
}
