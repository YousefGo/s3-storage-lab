#!/usr/bin/env bash
# Verifies Phase 1 (EC2 + EBS). Usage: ./tests/verify-phase-01.sh <public-ip>
set -u
IP="${1:?usage: $0 <public-ip>}"
pass=0; fail=0
expect() { # $1 description, $2 expected, $3 actual
  if [ "$3" = "$2" ]; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1 (got '$3', want '$2')"; fail=$((fail+1)); fi
}

# 1. App is reachable through Nginx on port 80
expect "App reachable on port 80" "200" \
  "$(curl -s -o /dev/null -w '%{http_code}' -m 5 "http://$IP/health")"

# 2. Port 8000 is not exposed (Security Group drops it, so no response)
expect "Port 8000 not exposed" "000" \
  "$(curl -s -o /dev/null -w '%{http_code}' -m 5 "http://$IP:8000/health")"

# 3. Data volume is encrypted
expect "Data volume encrypted" "True" \
  "$(aws ec2 describe-volumes --filters Name=tag:Name,Values=storage-lab-data-enc --query 'Volumes[0].Encrypted' --output text)"

expect "Data volume kept on termination" "False" \
  "$(aws ec2 describe-volumes --filters Name=tag:Name,Values=storage-lab-data-enc --query 'Volumes[0].Attachments[0].DeleteOnTermination' --output text)"


  expect "EBS encryption by default" "True" \
    "$(aws ec2 get-ebs-encryption-by-default --query EbsEncryptionByDefault --output text)"



  expect "No unencrypted snapshots" "0" \
    "$(aws ec2 describe-snapshots --owner-ids self --filters Name=tag:Project,Values=storage-lab Name=encrypted,Values=false --query 'length(Snapshots)' --output text)"

    expect "DR Snapchat encrypted" "True" \
      "$(aws ec2 describe-snapshots --region us-west-2 --owner-ids self --filters Name=tag:Name,Values=storage-lab-data-dr --query 'Snapshots[0].Encrypted' --output text)"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]

