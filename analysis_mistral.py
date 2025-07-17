import boto3
import datetime
import json

# Time range: last 5 minutes
end_time = datetime.datetime.utcnow()
start_time = end_time - datetime.timedelta(minutes=5)
start_time_ms = int(start_time.timestamp() * 1000)
end_time_ms = int(end_time.timestamp() * 1000)

def get_logs():
    logs_client = boto3.client("logs", region_name="us-east-1")
    response = logs_client.filter_log_events(
        logGroupName='syslog',  
        startTime=start_time_ms,
        endTime=end_time_ms,
        filterPattern='"nginx"'
    )
    return response
    # if you want to return the log messages as a string:
   # return "\n".join(event['message'] for event in response.get('events', []))

def analyze_logs_with_mistral(logs):
    model_id = "mistral.mistral-7b-instruct-v0:2"
    bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")

    prompt = f"""
You are a Site Reliability engineer. Analyze the following logs and answer:
1. What failed?
2. What is the likely root cause?
3. What should be done to fix it?
4. Suggest any relevant bash commands.

Logs:
{logs}
"""

    body = {
        "prompt": f"\n\nHuman:\n{prompt.strip()}\n\nAssistant:",
        "max_tokens": 1024,
        "temperature": 0.2
    }

    response = bedrock.invoke_model(
        modelId=model_id,
        body=json.dumps(body),
        contentType="application/json",
        accept="application/json"
    )

    raw = response["body"].read()
    result = json.loads(raw)

    if "outputs" in result and isinstance(result["outputs"], list):
        return result["outputs"][0].get("text", "No output text found.")
    else:
        return "No valid output from model."

def main():
    logs = get_logs()
    if not logs:
        print("No relevant NGINX logs found.")
        return

    output = analyze_logs_with_mistral(logs)
    print(output)

if __name__ == "__main__":
    main()
