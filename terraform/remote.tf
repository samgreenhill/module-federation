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
      identifiers = [ aws_cloudfront_origin_access_identity.remote_cloudfront_s3_origin_oai.iam_arn]
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

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
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

output "remote-domain" {
  value = aws_cloudfront_distribution.remote_s3_distribution.domain_name
}
