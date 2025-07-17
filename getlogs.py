import boto3
import datetime
import time

client = boto3.client(
    service_name="logs",  # Using the logs service
    region_name="us-east-1"
)

end_time = datetime.datetime.utcnow()
start_time = end_time - datetime.timedelta(hours=1)

start_time_ms = int(start_time.timestamp() * 1000)
end_time_ms = int(end_time.timestamp() * 1000)

def get_logs():
    response = client.get_log_events(
        logGroupName='syslog',
        logStreamName='i-004ef5cfe0a88b484',
        startTime=start_time_ms,
        endTime=end_time_ms,
        limit=123,
    )

    for event in response['events']:
        print(f"{event['timestamp']}: {event['message']}")

""" def get_logs():
    response = client.list_log_groups(
        limit=10
    )

    for group in response['logGroups']:
        print(group['logGroupName'])  """
## For filtering the logs filter_log_events can be used as coded below:
def get_logs():
    logs_client = boto3.client("logs", region_name="us-east-1")
    response = logs_client.filter_log_events(
        logGroupName='syslog',  
        startTime=start_time_ms,
        endTime=end_time_ms,
        filterPattern='"nginx"'
    )
    return response
    
if __name__ == "__main__":
    get_logs()

    #et_logs()
   #print("Listed log groups successfully.")
