import boto3
import hashlib
import sys
import argparse
import uuid

def parse_arguments():
	parser = argparse.ArgumentParser(description = "calculate the streaming md5 sum for s3 objects")
	parser.add_argument('-b', '--bucketName', required=True, help='s3 bucket')
	parser.add_argument('-o', '--objectName', required=True, help='object key in s3 bucket')
	args = parser.parse_args()

	return args


s3 = boto3.resource('s3')
client = boto3.client('s3')

def md5ObjectSum(bucketName, objectName):
	bucket = s3.Bucket(bucketName)
	obj = bucket.Object(objectName)

	size = obj.content_length

	hash_md5 = hashlib.md5()

	step = 5000000
	front = 0
	back = 0 + step
	while front != (size + 1):
		byteRange = 'bytes=' + str(front) + '-' +str(back)
		response = client.get_object(
			Bucket = bucketName,
			Key = objectName,
			Range = byteRange
		)

		body = response['Body']
		length  = response['ResponseMetadata']['HTTPHeaders']['content-length']
		chunk = body.read()
		hash_md5.update(chunk)

		front = back + 1
		if (back + step) > size:
			back = size
		else:
			back = back + step

	guid = str(uuid.uuid4())
	line = guid + '\t' + hash_md5.hexdigest() + '\t' + str(size) + '\t' + 'PROJECT-ID' + '\t' + 's3://' + bucketName + '/' + objectName
	
	fileName = "output/" + objectName + ".tsv"
	print "putting the manifest file for object back into s3 without making file first"
	bucket.put_object(Body = line.encode(), Key = fileName)


	print line

	return hash_md5.hexdigest()

if __name__ == '__main__':
	args = parse_arguments()
	md5 = md5ObjectSum(args.bucketName, args.objectName)
	