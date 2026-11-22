# Usage: source scripts/env.sh
export AWS_PROFILE=lab
export ACCOUNT=882437028576
export BUCKET=storage-lab-uploads-882437028576
export INSTANCE_ID=i-0d8fc38656d0661fc
export Q_URL=$(aws sqs get-queue-url --queue-name storage-lab-thumbs --query QueueUrl --output text)
export DLQ_URL=$(aws sqs get-queue-url --queue-name storage-lab-thumbs-dlq --query QueueUrl --output text)
echo "BUCKET=$BUCKET"
echo "Q_URL=$Q_URL"
