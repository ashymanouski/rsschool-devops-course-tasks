resource "aws_s3_bucket" "demo" {
  bucket = var.s3_bucket_name

  tags = var.tags
}

# Block public access
resource "aws_s3_bucket_public_access_block" "demo" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
} 