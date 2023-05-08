#!/usr/bin/env python3

import json
import sys
import urllib3

import boto3

def record_handler(server, token, record):
    state_abbr = record['messageAttributes']['state_abbr']['stringValue']
    state_name = record['messageAttributes']['state_name']['stringValue']
    sqs_url = record['messageAttributes']['sqs_url']['stringValue']
    index = int(record['messageAttributes']['index']['stringValue'])
    total = int(record['messageAttributes']['total']['stringValue'])
    auth = {'Authorization': f"Bearer {token}"}
    esm_uuid = record['messageAttributes']['esm_uuid']['stringValue']

    output_list = json.loads(record['body'])
    body = output_list[index - 1]

    params = {
        'status': f"{body}\n#Warn #Act #WarnAct #{state_abbr} #{state_name} ({index}/{total})"
    }
    if 'in_reply_to' in record['messageAttributes']:
        in_reply_to = record['messageAttributes']['in_reply_to']['stringValue']
        params['in_reply_to_id'] = in_reply_to

    http = urllib3.PoolManager()
    result = http.request('POST', f"https://{server}/api/v1/statuses",
                          headers=auth,
                          fields=params)
    print(result.status)
    print(result.headers)
    print(result.data)
    in_reply_to = json.loads(result.data)['id']

    if index == total:
        # We're done, time to disable the event source mapping
        aws_lambda = boto3.client("lambda")
        result = aws_lambda.update_event_source_mapping(
            UUID=esm_uuid,
            Enabled=False
        )
        print(f"result = {result}")
        return True

    sqs = boto3.resource('sqs')
    queue = sqs.Queue(sqs_url)
    queue.send_message(
        MessageBody=record['body'],
        MessageAttributes={
            'sqs_url': {
                'DataType': 'String',
                'StringValue': sqs_url
            },
            'in_reply_to': {
                'DataType': 'String',
                'StringValue': in_reply_to
            },
            'index': {
                'DataType': 'Number',
                'StringValue': str(index + 1)
            },
            'total': {
                'DataType': 'Number',
                'StringValue': str(total)
            },
            'state_abbr': {
                'DataType': 'String',
                'StringValue': state_abbr
            },
            'state_name': {
                'DataType': 'String',
                'StringValue': state_name
            },
            'esm_uuid': {
                'DataType': 'String',
                'StringValue': esm_uuid
            }
        },
        DelaySeconds=10
    )
    return True

# We know that lambda_context is unused; '_' prefix avoids complaint
def posts_handler(event, _lambda_context):
    ssm = boto3.client("ssm")

    server_result = ssm.get_parameter(Name='/WARN/api_server')
    if server_result and 'Parameter' in server_result:
        server = server_result['Parameter']['Value']
    else:
        print("Error: Unable to fetch /WARN/api_server from parameter store")
        sys.exit(1)

    token_result = ssm.get_parameter(Name='/WARN/api_token', WithDecryption=True)
    if token_result and 'Parameter' in token_result:
        token = token_result['Parameter']['Value']
    else:
        print("Error: Unable to fetch /WARN/api_token from parameter store")
        sys.exit(1)

    # There should be only one record, but just in case:
    for record in event['Records']:
        if not record_handler(server, token, record):
            sys.exit(1)

def main():
    print("This is a Lambda handler, not a regular script.")

if __name__ == "main":
    main()
