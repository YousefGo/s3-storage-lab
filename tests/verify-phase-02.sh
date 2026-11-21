#!/usr/bin/env bash
# Verifies Phase 2 (S3). Usage: ./tests/verify-phase-02.sh
set -u
BUCKET=storage-lab-uploads-882437028576
ROLE_ARN=$(aws iam get-role --role-name storage-lab-ec2 --query Role.Arn --output text)
pass=0; fail=0

expect() { # $1 description, $2 expected, $3 actual
  if [ "$3" = "$2" ]; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1 (got '$3', want '$2')"; fail=$((fail+1)); fi
}
sim() { # $1 action, $2 key -> allowed / implicitDeny
  aws iam simulate-principal-policy --policy-source-arn "$ROLE_ARN" --action-names "$1" \
    --resource-arns "arn:aws:s3:::$BUCKET/$2" --query 'EvaluationResults[0].EvalDecision' --output text
}

# 1. Bucket is fully private
expect "Block Public Access (all 4)" "True" \
  "$(aws s3api get-public-access-block --bucket $BUCKET --query 'PublicAccessBlockConfiguration.BlockPublicAcls && PublicAccessBlockConfiguration.IgnorePublicAcls && PublicAccessBlockConfiguration.BlockPublicPolicy && PublicAccessBlockConfiguration.RestrictPublicBuckets' --output text)"
# 2. Versioning is on
expect "Versioning enabled" "Enabled" \
  "$(aws s3api get-bucket-versioning --bucket $BUCKET --query Status --output text)"
# 3. Default encryption is SSE-KMS with a Bucket Key
expect "Default encryption SSE-KMS" "aws:kms" \
  "$(aws s3api get-bucket-encryption --bucket $BUCKET --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text)"
expect "Bucket Key enabled" "True" \
  "$(aws s3api get-bucket-encryption --bucket $BUCKET --query 'ServerSideEncryptionConfiguration.Rules[0].BucketKeyEnabled' --output text)"
# 4. Plain HTTP is refused by the bucket policy
expect "HTTP request denied" "denied" \
  "$(aws s3 ls s3://$BUCKET/uploads/ --endpoint-url http://s3.us-east-1.amazonaws.com >/dev/null 2>&1 && echo allowed || echo denied)"
# 5. EC2 role: least privilege
expect "Role can PutObject on uploads/" "allowed" "$(sim s3:PutObject uploads/x.txt)"
expect "Role cannot PutObject outside uploads/" "implicitDeny" "$(sim s3:PutObject other/x.txt)"
expect "Role cannot DeleteObject" "implicitDeny" "$(sim s3:DeleteObject uploads/x.txt)"
# 6. Presigned URLs work, then expire
URL=$(aws s3 presign s3://$BUCKET/uploads/versioning-demo.txt --expires-in 60)
expect "Valid presigned GET" "200" "$(curl -s -o /dev/null -w '%{http_code}' "$URL")"
URL=$(aws s3 presign s3://$BUCKET/uploads/versioning-demo.txt --expires-in 1); sleep 2
expect "Expired presigned GET" "403" "$(curl -s -o /dev/null -w '%{http_code}' "$URL")"
# 7. No hidden incomplete multipart uploads
expect "No incomplete multipart uploads" "0" \
  "$(aws s3api list-multipart-uploads --bucket $BUCKET --query 'length(Uploads || `[]`)' --output text)"
# 8. CORS never allows every origin
expect "CORS has no wildcard origin" "False" \
  "$(aws s3api get-bucket-cors --bucket $BUCKET --query "contains(CORSRules[0].AllowedOrigins, '*')" --output text)"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
