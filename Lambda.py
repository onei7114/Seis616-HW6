import json
import boto3
import os
from urllib.parse import unquote_plus

s3 = boto3.client('s3')
OUTPUT_BUCKET = os.environ['OUTPUT_BUCKET']

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    for record in event['Records']:
        src_bucket = record['s3']['bucket']['name']
        src_key = unquote_plus(record['s3']['object']['key'])
        result = f"Processed image: {src_key}"

        dest_key = f"results/{src_key}.txt"
        s3.put_object(
            Bucket=OUTPUT_BUCKET,
            Key=dest_key,
            Body=result.encode('utf-8')
        )

    return {"status": "success"}

def thumbnail_handler(event, context):
    for record in event['Records']:
        message = json.loads(record['body'])
        key = message['Records'][0]['s3']['object']['key']
        print(f"[THUMBNAIL] Processing {key}")

def recognition_handler(event, context):
    for record in event['Records']:
        message = json.loads(record['body'])
        key = message['Records'][0]['s3']['object']['key']
        print(f"[RECOGNITION] Processing {key}")

def metadata_handler(event, context):
    for record in event['Records']:
        message = json.loads(record['body'])
        key = message['Records'][0]['s3']['object']['key']
        print(f"[METADATA] Processing {key}")
