import boto3
import datetime
import json
import os

region = os.environ.get('REGION', 'us-east-1')
log_group = os.environ['LOG_GROUP']
filter_pattern = os.environ.get('FILTER_PATTERN', '?fail ?failed ?error ?denied ?unauthorized ?invalid ?panic ?refused ?unreachable ?unavailable ?timeout ?segfault ?corrupt ?crash ?fatal ?exited ?"authentication failure" ?"Connection refused" ?"Control process exited" ?"Failed with result" ?"test failed"')
model_id = os.environ.get('MODEL_ID', 'mistral.mistral-7b-instruct-v0:2')
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def get_logs():
    logs_client = boto3.client("logs", region_name=region)

    end_time = datetime.datetime.utcnow()
    # slight overlap to reduce miss risk
    start_time = end_time - datetime.timedelta(minutes=int(os.environ.get("LOOKBACK_MINUTES", "5")))
    start_ms = int(start_time.timestamp() * 1000)
    end_ms = int(end_time.timestamp() * 1000)

    events = []
    next_token = None
    fetched = 0
    max_events = int(os.environ.get("MAX_EVENTS", "5000"))  # safety cap

    while True:
        kwargs = {
            "logGroupName": log_group,
            "startTime": start_ms,
            "endTime": end_ms,
            "filterPattern": filter_pattern,
            "limit": 1000,
        }
        if next_token:
            kwargs["nextToken"] = next_token

        resp = logs_client.filter_log_events(**kwargs)
        batch = resp.get('events', [])
        events.extend(batch)
        fetched += len(batch)

        next_token = resp.get('nextToken')
        if not next_token or fetched >= max_events:
            break

    logs = "\n".join(e['message'] for e in events)
    return logs.strip()

def analyze_logs_with_bedrock(logs: str) -> str:
    bedrock = boto3.client("bedrock-runtime", region_name=region)
    prompt = f"""<s>[INST]
You are a DevOps SRE. Analyze these logs:

{logs}

Answer:
1. What failed?
2. What is the likely root cause?
3. What actions can fix the issue?
4. Any relevant bash commands?
[/INST]"""

    body = {"prompt": prompt, "max_tokens": 1024, "temperature": 0.2}

    try:
        response = bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps(body),
            contentType="application/json",
            accept="application/json"
        )
        raw = response["body"].read()
        result = json.loads(raw)
        # Bedrock Mistral format: {"outputs":[{"text":"..."}], ...}
        return result["outputs"][0]["text"]
    except Exception as e:
        return f"Error in LLM call: {e}"

def send_notification(message: str):
    sns = boto3.client("sns", region_name=region)
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject='Log Alert & Analysis',
        Message=message
    )

def lambda_handler(event, context):
    logs = get_logs()
    if not logs:
        print("No error logs found.")
        return {"status": "ok", "found": 0}

    summary = analyze_logs_with_bedrock(logs)
    send_notification(summary)
    return {"status": "ok", "found": 1}