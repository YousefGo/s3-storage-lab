#!/usr/bin/env bash
set -u
source "$(dirname "$0")/../scripts/env.sh"
fail=0
expect() { if [[ "$3" == "$2" ]]; then echo "PASS  $1"; else echo "FAIL  $1 (want: $2, got: $3)"; fail=1; fi; }

expect "backup vault exists"          "storage-lab-vault"    "$(aws backup describe-backup-vault --backup-vault-name storage-lab-vault --query BackupVaultName --output text)"
expect "DR vault in us-west-2"        "storage-lab-vault-dr" "$(aws backup describe-backup-vault --backup-vault-name storage-lab-vault-dr --region us-west-2 --query BackupVaultName --output text)"
expect "EFS recovery point completed" "COMPLETED"            "$(aws backup list-recovery-points-by-backup-vault --backup-vault-name storage-lab-vault --by-resource-type EFS --query 'RecoveryPoints[0].Status' --output text)"
expect "plan runs daily 00:00 UTC"    "cron(0 0 * * ? *)"    "$(aws backup get-backup-plan --backup-plan-id $PLAN_ID --query 'BackupPlan.Rules[0].ScheduleExpression' --output text)"
expect "plan copies to us-west-2"     "arn:aws:backup:us-west-2:${ACCOUNT}:backup-vault:storage-lab-vault-dr" "$(aws backup get-backup-plan --backup-plan-id $PLAN_ID --query 'BackupPlan.Rules[0].CopyActions[0].DestinationBackupVaultArn' --output text)"
expect "plan has a selection"         "1"                    "$(aws backup list-backup-selections --backup-plan-id $PLAN_ID --query 'length(BackupSelectionsList)' --output text)"
expect "a restore job completed"      "COMPLETED"            "$(aws backup list-restore-jobs --query 'RestoreJobs[0].Status' --output text)"
expect "datasync has a SUCCESS run"    "SUCCESS"              "$(aws datasync list-task-executions --task-arn $DS_TASK --query "TaskExecutions[?Status=='SUCCESS'] | [0].Status" --output text)"

exit $fail
