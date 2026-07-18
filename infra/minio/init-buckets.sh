#!/bin/sh
set -eu

validate_bucket() {
  case "$1" in
    ""|*[!a-z0-9.-]*|[.-]*|*[.-]|*..*)
      echo "Invalid S3 bucket name: $1" >&2
      exit 64
      ;;
  esac
  if [ "${#1}" -lt 3 ] || [ "${#1}" -gt 63 ]; then
    echo "S3 bucket names must be between 3 and 63 characters: $1" >&2
    exit 64
  fi
}

validate_bucket "$MINIO_ARTIFACTS_BUCKET"
validate_bucket "$MINIO_IMPORTS_BUCKET"
validate_bucket "$MINIO_EXPORTS_BUCKET"

if [ "${#MINIO_ROOT_PASSWORD}" -lt 16 ] || [ "${#MINIO_APP_SECRET_KEY}" -lt 16 ]; then
  echo "MinIO root and application secrets must be at least 16 characters" >&2
  exit 64
fi

mc alias set local "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

for bucket in "$MINIO_ARTIFACTS_BUCKET" "$MINIO_IMPORTS_BUCKET" "$MINIO_EXPORTS_BUCKET"; do
  mc mb --ignore-existing "local/$bucket"
  mc anonymous set none "local/$bucket"
done

umask 077
cat > /tmp/interstellar-app-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetBucketLocation", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::$MINIO_ARTIFACTS_BUCKET",
        "arn:aws:s3:::$MINIO_IMPORTS_BUCKET",
        "arn:aws:s3:::$MINIO_EXPORTS_BUCKET"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"],
      "Resource": [
        "arn:aws:s3:::$MINIO_ARTIFACTS_BUCKET/*",
        "arn:aws:s3:::$MINIO_IMPORTS_BUCKET/*",
        "arn:aws:s3:::$MINIO_EXPORTS_BUCKET/*"
      ]
    }
  ]
}
EOF

# Re-running this one-shot container is safe: existing buckets and identities
# remain in place while the policy is refreshed and reattached.
if mc admin user info local "$MINIO_APP_ACCESS_KEY" >/dev/null 2>&1; then
  mc admin user enable local "$MINIO_APP_ACCESS_KEY"
else
  mc admin user add local "$MINIO_APP_ACCESS_KEY" "$MINIO_APP_SECRET_KEY"
fi
mc admin policy create local interstellar-app /tmp/interstellar-app-policy.json
mc admin policy attach local interstellar-app --user "$MINIO_APP_ACCESS_KEY"

echo "MinIO buckets and restricted application identity are ready."
