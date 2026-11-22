#!/usr/bin/env bash
# Verifies Phase 4 (CloudFront + OAC). Usage: ./tests/verify-phase-04.sh
set -u
BUCKET=storage-lab-uploads-882437028576
ACCOUNT=882437028576
DIST_ID=E1NLA3C4ABR5VD
CF=$(aws cloudfront get-distribution --id $DIST_ID --query Distribution.DomainName --output text)
KEY_ID=$(aws kms describe-key --key-id alias/storage-lab-s3 --query KeyMetadata.KeyId --output text)
DIST_ARN="arn:aws:cloudfront::$ACCOUNT:distribution/$DIST_ID"
OBJ=thumbnails/end-to-end.jpg
pass=0; fail=0

expect() { # $1 description, $2 expected, $3 actual
  if [ "$3" = "$2" ]; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1 (got '$3', want '$2')"; fail=$((fail+1)); fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$1"; }

# 1. Distribution is live and uses OAC
expect "Distribution deployed" "Deployed" \
  "$(aws cloudfront get-distribution --id $DIST_ID --query Distribution.Status --output text)"
expect "Origin has an OAC attached" "yes" \
  "$(aws cloudfront get-distribution-config --id $DIST_ID --query 'DistributionConfig.Origins.Items[0].OriginAccessControlId' --output text | grep -q . && echo yes || echo no)"
# 2. Only CloudFront can read the bucket
expect "CloudFront URL returns 200" "200" "$(code https://$CF/$OBJ)"
expect "Direct S3 URL returns 403" "403" "$(code https://$BUCKET.s3.us-east-1.amazonaws.com/$OBJ)"
expect "Bucket policy pins this distribution" "$DIST_ARN" \
  "$(aws s3api get-bucket-policy --bucket $BUCKET --query Policy --output text | python3 -c 'import json,sys;print([s for s in json.load(sys.stdin)["Statement"] if s["Sid"]=="AllowCloudFrontOAC"][0]["Condition"]["StringEquals"]["aws:SourceArn"])')"
expect "Key policy lets this distribution decrypt" "$DIST_ARN" \
  "$(aws kms get-key-policy --key-id $KEY_ID --policy-name default --query Policy --output text | python3 -c 'import json,sys;print([s for s in json.load(sys.stdin)["Statement"] if s.get("Sid")=="AllowCloudFrontDecrypt"][0]["Condition"]["StringEquals"]["aws:SourceArn"])')"
# 3. HTTP is redirected to HTTPS
expect "HTTP redirects to HTTPS" "301" "$(code http://$CF/$OBJ)"
# 4. Repeated requests are served from the edge cache
hit=no
for i in 1 2 3 4 5; do
  curl -s -D - -o /dev/null https://$CF/$OBJ | grep -qi 'x-cache: Hit' && { hit=yes; break; }
  sleep 1
done
expect "Served from edge cache (Hit)" "yes" "$hit"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]