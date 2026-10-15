# Configured at init (-backend-config); locking is S3-native (use_lockfile), the DynamoDB table in ./state is legacy.

terraform {
  backend "s3" {
    encrypt = true
  }
}
