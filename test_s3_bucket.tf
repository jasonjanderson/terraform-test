resource "aws_s3_bucket" "bucket" {
  bucket = "jasona-terraform-test"
  acl    = "private"
}


