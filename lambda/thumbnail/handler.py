import io
import json
import os
from urllib.parse import unquote_plus

import boto3
from PIL import Image

s3 = boto3.client("s3")
THUMB_SIZE = (256, 256)
THUMB_PREFIX = "thumbnails/"


def handler(event, context):
    for record in event["Records"]:              # SQS messages
        body = json.loads(record["body"])
        if body.get("Event") == "s3:TestEvent":  # sent once when notifications are set up
            print("skip test event")
            continue
        for s3rec in body["Records"]:            # S3 event records inside the message
            bucket = s3rec["s3"]["bucket"]["name"]
            key = unquote_plus(s3rec["s3"]["object"]["key"])
            make_thumbnail(bucket, key)


def make_thumbnail(bucket, key):
    obj = s3.get_object(Bucket=bucket, Key=key)
    img = Image.open(io.BytesIO(obj["Body"].read()))
    img = img.convert("RGB")
    img.thumbnail(THUMB_SIZE)

    out = io.BytesIO()
    img.save(out, "JPEG", quality=85)
    name = os.path.splitext(os.path.basename(key))[0]
    dest = f"{THUMB_PREFIX}{name}.jpg"

    s3.put_object(Bucket=bucket, Key=dest, Body=out.getvalue(), ContentType="image/jpeg")
    print(json.dumps({"source": key, "thumbnail": dest, "size": img.size}))