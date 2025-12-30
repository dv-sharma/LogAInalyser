import boto3
import base64
import gzip
import json
import os
from datetime import datetime

# ---------- Config ----------
REGION = os.environ.get("REGION", "us-east-1")
MODEL_ID = os.environ.get("MODEL_ID", "mistral.mistral-7b-instruct-v0:2")
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

bedrock = boto3.client("bedrock-runtime", region_name=REGION)
sns = boto3.client("sns", region_name=REGION)

# ---------- Helpers ----------

def decode_cloudwatch_event(event):
    """
    Decode CloudWatch Logs subscription payload
    """
    compressed = base64.b64decode(event["awslogs"]["data"])
    decompressed = gzip.decompress(compressed)
    return json.loads(decompressed)


def aggregate_logs(log_events):
    """
    Group log events by message while preserving timestamps
    """
    aggregated = {}

    for e in log_events:
        message = e["message"].strip()
        timestamp = e["timestamp"]

        aggregated.setdefault(message, []).append(timestamp)

    return aggregated


def build_prompt(message, timestamps):
    """
    Build Bedrock prompt with timestamp awareness
    """
    timestamps.sort()

    first_seen = datetime.utcfromtimestamp(timestamps[0] / 1000).isoformat()
    last_seen = datetime.utcfromtimestamp(timestamps[-1] / 1000).isoformat()

    timeline = "\n".join(
        datetime.utcfromtimestamp(ts / 1000).isoformat()
        for ts in timestamps
    )

    return f"""<s>[INST]
You are a DevOps SRE.

The following error occurred multiple times:

Message:
{message}

Occurrences:
{len(timestamps)}

First seen:
{first_seen} UTC

Last seen:
{last_seen} UTC

Event timeline:
{timeline}

Answer:
1. What failed?
2. Likely root cause?
3. Suggested fixes?
4. Relevant bash commands?
[/INST]"""


def analyze_with_bedrock(prompt):
    body = {
        "prompt": prompt,
        "max_tokens": 1024,
        "temperature": 0.2
    }

    response = bedrock.invoke_model(
        modelId=MODEL_ID,
        body=json.dumps(body),
        contentType="application/json",
        accept="application/json"
    )

    raw = response["body"].read()
    result = json.loads(raw)

    return result["outputs"][0]["text"]


def send_notification(message):
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject="Log Incident Analysis",
        Message=message
    )

# ---------- Lambda Handler ----------

def lambda_handler(event, context):
    payload = decode_cloudwatch_event(event)
    log_events = payload.get("logEvents", [])

    if not log_events:
        return {"status": "ok", "processed": 0}

    aggregated = aggregate_logs(log_events)

    for message, timestamps in aggregated.items():
        prompt = build_prompt(message, timestamps)
        analysis = analyze_with_bedrock(prompt)
        send_notification(analysis)

    return {
        "status": "ok",
        "incidents": len(aggregated)
    }
