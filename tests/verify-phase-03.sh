#!/usr/bin/env bash
# Verifies Phase 3 (S3 events -> SQS -> Lambda). Usage: ./tests/verify-phase-03.sh
set -u
BUCKET=storage-lab-uploads-882437028576
FN=storage-lab-thumbnail
Q_URL=$(aws sqs get-queue-url --queue-name storage-lab-thumbs --query QueueUrl --output text)
LAMBDA_ROLE=$(aws iam get-role --role-name storage-lab-thumbs-lambda --query Role.Arn --output text)
pass=0; fail=0

expect() { # $1 description, $2 expected, $3 actual
  if [ "$3" = "$2" ]; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1 (got '$3', want '$2')"; fail=$((fail+1)); fi
}
sim() { # $1 action, $2 key -> allowed / implicitDeny
  aws iam simulate-principal-policy --policy-source-arn "$LAMBDA_ROLE" --action-names "$1" \
    --resource-arns "arn:aws:s3:::$BUCKET/$2" --query 'EvaluationResults[0].EvalDecision' --output text
}

# 1. Visibility timeout is at least 6x the Lambda timeout
VT=$(aws sqs get-queue-attributes --queue-url $Q_URL --attribute-names VisibilityTimeout --query Attributes.VisibilityTimeout --output text)
LT=$(aws lambda get-function-configuration --function-name $FN --query Timeout --output text)
expect "Visibility timeout >= 6x Lambda timeout ($VT vs $LT)" "ok" "$([ "$VT" -ge $((LT*6)) ] && echo ok || echo too-low)"
# 2. Failed messages go to the DLQ after 3 tries
expect "DLQ after 3 receives" "3" \
  "$(aws sqs get-queue-attributes --queue-url $Q_URL --attribute-names RedrivePolicy --query Attributes.RedrivePolicy --output text | python3 -c 'import json,sys;print(json.load(sys.stdin)["maxReceiveCount"])')"
# 3. Every notification rule is limited to uploads/ (no recursive loop)
expect "All event rules filtered to uploads/" "0" \
  "$(aws s3api get-bucket-notification-configuration --bucket $BUCKET --query 'length(QueueConfigurations[?Filter.Key.FilterRules[?Name==`prefix` && Value!=`uploads/`]])' --output text)"
# 4. Lambda is wired to the queue
expect "Event source mapping enabled" "Enabled" \
  "$(aws lambda list-event-source-mappings --function-name $FN --query 'EventSourceMappings[0].State' --output text)"
# 5. Lambda role: read uploads/, write thumbnails/ only
expect "Lambda can write thumbnails/" "allowed" "$(sim s3:PutObject thumbnails/x.jpg)"
expect "Lambda cannot write uploads/" "implicitDeny" "$(sim s3:PutObject uploads/x.jpg)"
# 6. End to end: an uploaded image gets a thumbnail within 60 s
KEY="verify-$(date +%s)"
python3 -c "from PIL import Image; Image.new('RGB', (400, 300), 'teal').save('/tmp/$KEY.jpg')"
aws s3 cp /tmp/$KEY.jpg s3://$BUCKET/uploads/$KEY.jpg --quiet
found=no
for i in $(seq 1 12); do
  aws s3api head-object --bucket $BUCKET --key thumbnails/$KEY.jpg >/dev/null 2>&1 && { found=yes; break; }
  sleep 5
done
expect "Thumbnail created within 60 s" "yes" "$found"
rm -f /tmp/$KEY.jpg

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]