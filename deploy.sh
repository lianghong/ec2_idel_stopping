#!/bin/bash
#######################################
# File Name: deploy.sh
# Author: lianghong
# mail: feilianghong@gmail.com
# Created Time: Tue Aug 17 14:06:26 2021
########################################
set -e

#region="us-west-2"
function_name="StopIdelInstance"

function error() {
	echo "$1" "ERROR"
  	exit 127
}

account=$(aws sts get-caller-identity --query 'Account')
role_name="${function_name}Role"
rule_name="${function_name}Rule"

rule_description="check EC2 CPU utilization"
rule_pattern="{\"source\":[\"aws.ec2\"],\"detail-type\":[\"EC2 Instance State-change Notification\"],\"detail\":{\"state\":[\"running\"]}}"
rule_arn="arn:aws:iam::${account}:role/${role_name}"

function_handler="${function_name}.lambda_handler"
function_description="Stop idel EC2 instance"
function_runetime="python3.9"
memory_size="128"

if ! command -v zip &>/dev/null; then
    error "ZIP tool is not installed. Please install it and re-run this script."
fi

if ! command -v aws &>/dev/null; then
    error "awscli is not installed. Please install it and re-run this script."
fi

if [ -z $1 ]; then
	echo -e "\nUsage: $0 region soucefile ( e.g. StopIdelInstance.py)\n"
	exit 1
else
	region=$1
fi

if [ ! -z $2 ]; then
	function_name=$2
fi

if [ -z ${account} ]; then
	error "Can not found aws accound."
fi

if [ ! -f "${function_name}.py" ]; then
	error "Lambda function source file "${function_name}.py" is not exist."
fi

echo "*** Region - ${region}, Account - ${account}, Function - ${function_name} ***"
echo "*** Role - ${role_name}, Rule - ${rule_name} ***"

echo -e "\n*** Process IAM role ***"
# Get roles list
roles_list=$(aws iam list-roles \
	--query 'Roles[*].RoleName' \
	--output text | sed -E -e 's/[[:blank:]]+/\n/g')

if grep -q "${role_name}"  <<< "${roles_list}" ; then
	echo "Role of ${role_name} is exist."
	attached_policy=$(aws iam list-attached-role-policies \
		--role-name "${role_name}" \
		--query 'AttachedPolicies[].PolicyArn' \
		--output text)

	for policy in ${attached_policy} ; do
		echo "Detach policy of ${policy}"
    	aws iam detach-role-policy \
    		--role-name "${role_name}" \
    		--policy-arn "${policy}" \
			--output text
	done
    echo "Delete role of ${role_name}"
    aws iam delete-role --role-name "${role_name}"
fi

echo -e "\nCreate role of ${role_name}"
aws iam create-role \
    --role-name "${role_name}" \
    --assume-role-policy-document \
	'{"Version": "2012-10-17","Statement": [{ "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}' \
    --output text \
	 &>/dev/null

echo "Attach policy of AWSLambdaBasicExecutionRole to the role of ${role_name}"
aws iam attach-role-policy \
    --role-name "${role_name}" \
    --policy-arn \
	"arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" \
    --output text

echo "Attach policy of AmazonEC2FullAccess to the role of ${role_name}"
aws iam attach-role-policy \
    --role-name "${role_name}" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonEC2FullAccess" \
    --output text

echo -e "\n*** Process event rules ***"
# Get rules list
rule=$(aws events list-rules \
	--name-prefix "${rule_name}" \
	--query 'Rules[].{NAME:Name}' \
	--region ${region} \
	--output text)

# check rule exist
if [ ! -z ${rule} ]; then
	echo "Delete rule's target"
	aws events remove-targets \
		--rule "${rule_name}" \
		--ids "1" \
		--region ${region} \
		--output text \
		 &>/dev/null

	# delete rule
	echo "Delete rule of ${rule_name}"
	aws events delete-rule \
		--name "${rule_name}" \
		--region ${region} \
		--output text \
		 &>/dev/null
fi

echo -e "\nCreate event rule"
aws events put-rule \
	--name "${rule_name}" \
	--description "${rule_description}" \
	--event-pattern "{\"source\":[\"aws.ec2\"],\"detail-type\":[\"EC2 Instance State-change Notification\"],\"detail\":{\"state\":[\"running\"]}}" \
	--region ${region} \
	--output text

echo -e "\n*** Process lambda function ***"
functions=$(aws lambda list-functions \
	--region ${region} \
	--query 'Functions[].{NAME:FunctionName}' \
	--output text)

if grep -q "${function_name}"  <<< "${functions}" ; then
	echo "Delete lambda function of ${function_name}"
	aws lambda delete-function \
		--function-name "${function_name}" \
		--region ${region} \
		--output text
fi

if [ ! -f "${function_name}.zip" ]; then
	echo "Package source file to ${function_name}.zip"
	zip "${function_name}.zip"  "${function_name}.py" > /dev/null
fi

# create lambda function
echo "create lambda function"
aws lambda create-function \
	--region ${region} \
    --function-name ${function_name} \
    --runtime ${function_runetime} \
    --zip-file fileb://${function_name}.zip \
    --handler ${function_handler} \
    --role "arn:aws:iam::${account}:role/${role_name}" \
	--description "${function_description}" \
	--package-type Zip \
	--timeout 300 \
	--memory-size ${memory_size} \
	--output text \
	 &>/dev/null

# add permission
echo "add permission to lambda function"
aws lambda add-permission \
	--region ${region} \
	--function-name "${function_name}" \
	--statement-id "${function_name}_id" \
	--action 'lambda:InvokeFunction' \
	--principal 'events.amazonaws.com' \
	--source-arn "arn:aws:events:${region}:${account}:rule/${rule_name}" \
	--output text \
	 &>/dev/null

# event put target
echo "Create event target"
aws events put-targets \
	--region ${region} \
	--rule "${rule}" \
	--targets \
	"Id"="1","Arn"="arn:aws:lambda:${region}:${account}:function:${function_name}" \
	--output text


if [ -f  "${function_name}.zip" ]; then
	/bin/rm  "${function_name}.zip"
fi

echo ""
echo "Done."
