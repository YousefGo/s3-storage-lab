#!/bin/bash
dnf install -y amazon-efs-utils
mkdir -p /mnt/efs
mount -t efs -o tls fs-0c44ba46a0d40d6bf:/ /mnt/efs
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
{ echo "server B read: $(cat /mnt/efs/hello.txt)"; echo "hello from server B in $AZ at $(date)"; } > /mnt/efs/from-b.txt
