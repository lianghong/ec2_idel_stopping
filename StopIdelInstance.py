#!/usr/bin/env python3
#######################################
# > File Name: StopIdelInstance.py
# > Author: lianghong
# > Mail: feilianghong@gmail.com
# > Created Time: Tue Aug 17 14:05:15 2021
######################################
# -*- coding:utf-8 -*-

import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CPU_ALARM_NAME = "CPU_ALERT"
CPU_ALARM_DESC = "Alarm when instance CPU does not exceed CPU_THRESHOLD%"
CPU_METRIC_NAME = "CPUUtilization"
CPU_NAMESPACE = "AWS/EC2"
CPU_STATISTICS = "Average"
CPU_ALARM_PERIOD = 300
CPU_EVALUATION_PERIOD = 2
CPU_THRESHOLD = 3
CPU_COMPARISON = "LessThanOrEqualToThreshold"
CPU_TREATMISSIONDATA = "notBreaching"


def put_cpu_alarm(region, instance_id):
    cloudWatch = boto3.client("cloudwatch", region_name=region)
    cloudWatch.put_metric_alarm(
        AlarmName=CPU_ALARM_NAME + "_" + instance_id,
        AlarmDescription=CPU_ALARM_DESC,
        ActionsEnabled=True,
        AlarmActions=["arn:aws:automate:" + region + ":ec2:stop"],
        MetricName=CPU_METRIC_NAME,
        Namespace=CPU_NAMESPACE,
        Statistic=CPU_STATISTICS,
        Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
        Period=CPU_ALARM_PERIOD,
        EvaluationPeriods=CPU_EVALUATION_PERIOD,
        Threshold=CPU_THRESHOLD,
        ComparisonOperator=CPU_COMPARISON,
        TreatMissingData=CPU_TREATMISSIONDATA,
    )


def lambda_handler(event, context):
    region = os.environ["AWS_REGION"]
    instance_id = event["detail"]["instance-id"]
    logger.info("region: %s, instaceId: %s", region, instance_id)
    ec2 = boto3.resource("ec2", region_name=region)
    instance = ec2.Instance(instance_id)
    stopidel_tag = [x["Value"] for x in instance.tags if x["Key"] == "stopIdel"]

    if (
        instance.instance_type.endswith("xlarge")
        and instance.instance_lifecycle is None
        and stopidel_tag != ["False"]
    ):
        logger.info("exec put_cpu_alarm for instance of %s", instance_id)
        put_cpu_alarm(region, instance_id)

    return {
        "statusCode": 200,
        "body": json.dumps("Hello from Lambda function of StopIdelInstance!"),
    }
