#!/bin/bash
#######################################
# File Name: instance_tag.sh
# Author: lianghong
# mail: feilianghong@gmail.com
# Created Time: Fri Aug 20 11:21:07 2021
########################################
set -e

tag_name="stopIdel"
tag_value="False"

if [ -z $1 ]; then
	echo -e "\nUsage: $0 region instance-id True|False\n"
	exit 1
else
	region=$1
fi

if [ -z $2 ]; then
	aws ec2 describe-instances \
		--region ${region} \
		--output table \
		--query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress,Tags[?Key==`stopIdel`].Value | [0]]'
	exit 1
else
	instanceId=$2
fi

if [ ! -z $3 ]; then
    tag_value=$3
fi

echo "Create/modify instance tag"
aws ec2 create-tags \
    --region ${region} \
    --resources ${instanceId} \
    --tags Key=${tag_name},Value=${tag_value} \
    --output text

echo "Verify instance tag"
	aws ec2 describe-instances \
		--region ${region} \
		--output table \
		--instance-ids ${instanceId} \
		--query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress,Tags[?Key==`stopIdel`].Value | [0]]'


echo "Done."
