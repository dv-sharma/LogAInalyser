import base64
import gzip
import json
import os
import boto3
from datetime import datetime

REGION = os.environ.get("REGION", "us-east-2")
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
MODEL_ID = os.environ.get("MODEL_ID", "mistral.mistral-large-3-675b-instruct")

MAX_SAMPLES = int(os.environ.get("MAX_SAMPLES", "20"))
MAX_SAMPLE_CHARS = int(os.environ.get("MAX_SAMPLE_CHARS", "400"))
MAX_TOKENS = int(os.environ.get("MAX_TOKENS", "900"))
TEMPERATURE = float(os.environ.get("TEMPERATURE", "0.2"))
TOP_P = float(os.environ.get("TOP_P", "0.9"))

sns = boto3.client("sns", region_name=REGION)
bedrock = boto3.client("bedrock-runtime", region_name=REGION)

def decode_subscription_event(event) -> dict:
    compressed = base64.b64decode(event["awslogs"]["data"])
    decompressed = gzip.decompress(compressed)
    return json.loads(decompressed)

def iso(ms: int) -> str:
    return datetime.utcfromtimestamp(ms / 1000).isoformat() + "Z"

def call_bedrock_rca(log_group: str, log_stream: str, lines: list[str]) -> str:
    # Keep prompt bounded
    joined = "\n".join(lines)

    prompt = (
        "You are a DevOps/SRE.\n"
        "Analyze the following log lines (they are error signals from syslog).\n"
        "Be specific and only infer what the logs support.\n\n"
        f"Log group: {log_group}\n"
        f"Log stream: {log_stream}\n\n"
        "Logs:\n"
        f"{joined}\n\n"
        "Return:\n"
        "1) What failed?\n"
        "2) Likely root cause (and what evidence)\n"
        "3) Fix steps (ordered)\n"
        "4) Bash commands to confirm + fix\n"
        "5) Confidence (low/med/high)\n"
    )

    # Use Converse API (works with messages-style models)
    resp = bedrock.converse(
        modelId=MODEL_ID,
        messages=[{"role": "user", "content": [{"text": prompt}]}],
        inferenceConfig={
            "maxTokens": MAX_TOKENS,
            "temperature": TEMPERATURE,
            "topP": TOP_P,
        },
    )
    return resp["output"]["message"]["content"][0]["text"].strip()

def lambda_handler(event, context):
    payload = decode_subscription_event(event)
    log_group = payload.get("logGroup", "unknown")
    log_stream = payload.get("logStream", "unknown")
    log_events = payload.get("logEvents", [])

    print(f"[OK] logGroup={log_group} logStream={log_stream} events={len(log_events)}")

    if not log_events:
        return {"status": "ok", "events": 0}

    # Build sample lines for email + RCA input (bounded)
    lines = []
    for e in log_events[:MAX_SAMPLES]:
        ts = int(e.get("timestamp", 0))
        msg = (e.get("message") or "").strip().replace("\n", " ")
        if len(msg) > MAX_SAMPLE_CHARS:
            msg = msg[:MAX_SAMPLE_CHARS] + "..."
        lines.append(f"{iso(ts)}  {msg}")

    # Bedrock RCA
    try:
        rca = call_bedrock_rca(log_group, log_stream, lines)
    except Exception as ex:
        rca = f"(Bedrock RCA failed: {ex})"

    subject = f"Syslog RCA: {len(log_events)} new error events"
    message = (
        f"Log group: {log_group}\n"
        f"Log stream: {log_stream}\n"
        f"Events: {len(log_events)}\n\n"
        f"Sample lines:\n" + "\n".join(f"- {l}" for l in lines[:5]) +
        "\n\n--- Bedrock RCA ---\n" + rca
    )

    sns.publish(TopicArn=SNS_TOPIC_ARN, Subject=subject, Message=message)
    return {"status": "ok", "events": len(log_events), "model": MODEL_ID}