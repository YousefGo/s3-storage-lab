# Usage: source scripts/env.sh
export AWS_PROFILE=lab
export ACCOUNT=882437028576
export BUCKET=storage-lab-uploads-882437028576
export INSTANCE_ID=i-0d8fc38656d0661fc
export Q_URL=$(aws sqs get-queue-url --queue-name storage-lab-thumbs --query QueueUrl --output text)
export DLQ_URL=$(aws sqs get-queue-url --queue-name storage-lab-thumbs-dlq --query QueueUrl --output text)
echo "BUCKET=$BUCKET"
echo "Q_URL=$Q_URL"
export DIST_ID=E1NLA3C4ABR5VD
export CF_DOMAIN=drzdkuu1s0goo.cloudfront.net
export KEY_ID=2020a802-ed2d-4c35-9083-416ed2a9d56d
export OAC_ID=E2KZFXC87TBER7
export DEST_BUCKET=storage-lab-replica-882437028576
export DEST_KEY=arn:aws:kms:us-west-2:882437028576:key/fe5f9772-b350-4e56-b7e1-790c6e0bcf45
export LOCK_BUCKET=storage-lab-locked-882437028576
