resource "aws_s3_bucket" "b" {
  bucket = "jasona-terraform-test2"
  acl    = "private"
}