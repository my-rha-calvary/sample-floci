import json
import os
import uuid
from datetime import datetime, timezone
import boto3

BUCKET_NAME = os.environ.get("BUCKET_NAME", "floci-sample-bucket")
TABLE_NAME = os.environ.get("TABLE_NAME", "FlociSampleItems")
ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL")

s3 = boto3.client("s3", endpoint_url=ENDPOINT_URL)
dynamodb = boto3.resource("dynamodb", endpoint_url=ENDPOINT_URL)


def lambda_handler(event, context):
    """Write a sample record to DynamoDB and an object to S3."""
    item_id = event.get("id", str(uuid.uuid4()))
    message = event.get("message", "Hello from Python Lambda on Floci!")
    timestamp = datetime.now(timezone.utc).isoformat()

    # 1. Put item into DynamoDB
    table = dynamodb.Table(TABLE_NAME)
    item = {
        "id": item_id,
        "message": message,
        "created_at": timestamp,
    }
    table.put_item(Item=item)

    # 2. Upload JSON snapshot to S3
    s3_key = f"items/{item_id}.json"
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=s3_key,
        Body=json.dumps(item),
        ContentType="application/json",
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "status": "ok",
            "item": item,
            "s3_uri": f"s3://{BUCKET_NAME}/{s3_key}",
        }),
    }
