#!/usr/bin/env bash
set -u
source "$(dirname "$0")/../scripts/env.sh"
fail=0
expect() { if [[ "$3" == "$2" ]]; then echo "PASS  $1"; else echo "FAIL  $1 (want: $2, got: $3)"; fail=1; fi; }

expect "efs available"              "available" "$(aws efs describe-file-systems --file-system-id $EFS_ID --query 'FileSystems[0].LifeCycleState' --output text)"
expect "efs encrypted at rest"      "True"      "$(aws efs describe-file-systems --file-system-id $EFS_ID --query 'FileSystems[0].Encrypted' --output text)"
expect "throughput mode elastic"    "elastic"   "$(aws efs describe-file-systems --file-system-id $EFS_ID --query 'FileSystems[0].ThroughputMode' --output text)"
expect "2 mount targets available"  "2"         "$(aws efs describe-mount-targets --file-system-id $EFS_ID --query 'length(MountTargets[?LifeCycleState==`available`])' --output text)"
expect "mount targets in 2 AZs"     "2"         "$(aws efs describe-mount-targets --file-system-id $EFS_ID --query 'MountTargets[].AvailabilityZoneName' --output text | tr '\t' '\n' | sort -u | wc -l | tr -d ' ')"
expect "NFS only from EC2 SG"       "$EC2_SG"   "$(aws ec2 describe-security-groups --group-ids $EFS_SG --query 'SecurityGroups[0].IpPermissions[?FromPort==`2049`].UserIdGroupPairs[0].GroupId | [0]' --output text)"
expect "no 0.0.0.0/0 on EFS SG"     "0"         "$(aws ec2 describe-security-groups --group-ids $EFS_SG --query 'length(SecurityGroups[0].IpPermissions[].IpRanges[?CidrIp==`0.0.0.0/0`][])' --output text)"
expect "lifecycle to IA 30 days"    "AFTER_30_DAYS" "$(aws efs describe-lifecycle-configuration --file-system-id $EFS_ID --query 'LifecyclePolicies[?TransitionToIA].TransitionToIA | [0]' --output text)"
expect "server B terminated"        "0"         "$(aws ec2 describe-instances --filters Name=tag:Name,Values=storage-lab-efs-b Name=instance-state-name,Values=pending,running,stopping,stopped --query 'length(Reservations)' --output text)"

exit $fail
