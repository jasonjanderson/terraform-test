resource "aws_s3_bucket" "b" {
  bucket = "jasona-terraform-test"
  acl = "private"
}