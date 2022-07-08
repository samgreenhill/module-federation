resource "aws_s3_bucket" "remote_webcontent" {
  bucket = "remote-webcontent"

  tags = {
    Name = "remotes webcontent bucket"
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_remote_cloudfront" {
  bucket = aws_s3_bucket.remote_webcontent.id
  policy = data.aws_iam_policy_document.allow_access_from_remote_cloudfront.json
}

data "aws_iam_policy_document" "allow_access_from_remote_cloudfront" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.remote_cloudfront_s3_origin_oai.iam_arn]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_bucket.remote_webcontent.arn,
      "${aws_s3_bucket.remote_webcontent.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_acl" "remote_webcontent_acl" {
  bucket = aws_s3_bucket.remote_webcontent.id
  acl    = "private"
}

locals {
  s3_remote_origin_id = "remoteS3Origin"
}

resource "aws_cloudfront_origin_access_identity" "remote_cloudfront_s3_origin_oai" {
  comment = "OAI-${aws_s3_bucket.remote_webcontent.id}"
}

resource "aws_cloudfront_distribution" "remote_s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.remote_webcontent.bucket_regional_domain_name
    origin_id   = local.s3_remote_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.remote_cloudfront_s3_origin_oai.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = replace(aws_api_gateway_stage.dev.invoke_url, "/^https?://([^/]*).*/", "$1")
    origin_id   = "apigw"
    origin_path = "/dev"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Remote distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_remote_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "DELETE", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    path_pattern           = "api*"
    target_origin_id       = "apigw"
    viewer_protocol_policy = "https-only"
    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
    compress    = true
    cache_policy_id = aws_cloudfront_cache_policy.api_gateway_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_gateway_optimized.id
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["GB"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_cache_policy" "api_gateway_optimized" {
  name        = "ApiGatewayOptimized"

  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_origin_request_policy" "api_gateway_optimized" {
  name    = "ApiGatewayOptimized"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["Accept-Charset", "Accept", "User-Agent", "Referer"]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

output "remote-domain" {
  value = aws_cloudfront_distribution.remote_s3_distribution.domain_name
}
