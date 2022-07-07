resource "aws_s3_bucket" "host_webcontent" {
  bucket = "host-webcontent"

  tags = {
    Name = "Hosts webcontent bucket"
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_host_cloudfront" {
  bucket = aws_s3_bucket.host_webcontent.id
  policy = data.aws_iam_policy_document.allow_access_from_host_cloudfront.json
}

data "aws_iam_policy_document" "allow_access_from_host_cloudfront" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [ aws_cloudfront_origin_access_identity.host_cloudfront_s3_origin_oai.iam_arn]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_bucket.host_webcontent.arn,
      "${aws_s3_bucket.host_webcontent.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_acl" "host_webcontent_acl" {
  bucket = aws_s3_bucket.host_webcontent.id
  acl    = "private"
}

locals {
  s3_host_origin_id = "hostS3Origin"
}

resource "aws_cloudfront_origin_access_identity" "host_cloudfront_s3_origin_oai" {
  comment = "OAI-${aws_s3_bucket.host_webcontent.id}"
}

resource "aws_cloudfront_distribution" "host_s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.host_webcontent.bucket_regional_domain_name
    origin_id   = local.s3_host_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.host_cloudfront_s3_origin_oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_host_origin_id

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

output "host-domain" {
  value = aws_cloudfront_distribution.host_s3_distribution.domain_name
}
