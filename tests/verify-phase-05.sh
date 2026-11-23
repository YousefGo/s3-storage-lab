#!/usr/bin/env bash
set -u
source "$(dirname "$0")/../scripts/env.sh"
fail=0
expect() { if [[ "$3" == "$2" ]]; then echo "PASS  $1"; else echo "FAIL  $1 (want: $2, got: $3)"; fail=1; fi; }

expect "lifecycle rule enabled"      "Enabled" "$(aws s3api get-bucket-lifecycle-configuration --bucket $BUCKET --query "Rules[?ID=='uploads-tiering'].Status | [0]" --output text)"
expect "intelligent-tiering object"  "INTELLIGENT_TIERING" "$(aws s3api head-object --bucket $BUCKET --key reports/report.png --query StorageClass --output text)"
expect "replication rule enabled"    "Enabled" "$(aws s3api get-bucket-replication --bucket $BUCKET --query 'ReplicationConfiguration.Rules[0].Status' --output text)"
expect "replica bucket versioning"   "Enabled" "$(aws s3api get-bucket-versioning --bucket $DEST_BUCKET --region us-west-2 --query Status --output text)"
expect "source object replicated"    "COMPLETED" "$(aws s3api head-object --bucket $BUCKET --key uploads/crr-test.txt --query ReplicationStatus --output text)"
expect "replica uses us-west-2 key"  "$DEST_KEY" "$(aws s3api head-object --bucket $DEST_BUCKET --region us-west-2 --key uploads/crr-test.txt --query SSEKMSKeyId --output text)"
expect "object lock default mode"    "GOVERNANCE" "$(aws s3api get-object-lock-configuration --bucket $LOCK_BUCKET --query ObjectLockConfiguration.Rule.DefaultRetention.Mode --output text)"
expect "invoice version is locked"   "GOVERNANCE" "$(aws s3api head-object --bucket $LOCK_BUCKET --key invoice.txt --query ObjectLockMode --output text)"

exit $fail
