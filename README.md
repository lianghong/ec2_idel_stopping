# ec2_idel_stopping

Idle EC2 instances can be costly, and being able to manage EC2 instances automatically, such as automatically shutting down idle instances, would be a great benefit. This small project takes advantage of Amazon Lambda and Cloudwatch features to help us do just that. Both services are serverless, so we don’t have to care about their operation and maintenance. 
First, we will attach a CloudWatch alarm to an EC2 instances when the state of the instance is “running”. The alarm monitors metrics and automatically stop the instance when the alarm is raised. In order to implement these behaviors.

## File introduction

StopIdelInstance.py - This is the body of the Lambda function and will be used when creating lambda function.
deploy.sh - It is script file to deploy lambda function to specific AWS region. Usage: ./deploy.sh region soucefile ( e.g. StopIdelInstance.py)
instance_tag.sh - A tool script to add a tag to the EC2 instance which will enable the automaticaly stop when it's idel. Usage: ./instance_tag.sh region instance-id True|False

## working flow

1. ./instance_tag.sh us-west-1
    check current EC2 instance
2. ./instance_tag.sh us-west-1 i-xxxxxxxxxxxxxxxx
    enable or disable on stopping idel instance for specific instance
4. ./deploy.sh us-west-1
  deploy a lambda function
  
  
