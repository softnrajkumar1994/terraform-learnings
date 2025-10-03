import json
import urllib.request

def handler(event, context):
    for record in event.get('Records', []):
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        print(f"Hello World! New object uploaded: {key} in bucket: {bucket}")

    image_url = "https://via.placeholder.com/150"
    try:
        response = urllib.request.urlopen(image_url)
        data = response.read()
        print(f"Downloaded public image of size: {len(data)} bytes")
    except Exception as e:
        print(f"Failed to download public image: {e}")

    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
