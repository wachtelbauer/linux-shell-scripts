#!/bin/bash
###########################################################################################################
#
# S3-AWSV4-upload.sh
# POST files to Amazon S3 with CURL
# no python or anything else.
# Friedhelm Budnick 11.11.2014 
#
###########################################################################################################
# When I moved my Amazon VPC to Frankfurt, I did so with my S3 bucket that holds my daily backups.
# It was painful to find out, that my upload skripts (using CURL) did not work anymore with this new bucket
# The V4 signing process seemed not to be strait foreward.
# A sample that I found on https://github.com/emmanuel/aws-bash/blob/master/sign-aws.sh
# did not work for me out of the box.
# I stole from there, what could help me and made my own script. It cost me a lot of head scratching,
# so I hope, you enjoy this sample 
# After all, signing an S3 upload with V4 is not that complicated.
###########################################################################################################
# To make this code work, you need:
# An S3 bucket. Change the values of BUCKET and REQUEST_REGION below 
# A file /home/ubuntu/aws/security/AWS_SECRET_KEY that contains the AWS_SECRET_KEY 
# A file /home/ubuntu/aws/security/AWS_ACCESS_KEY that contains the AWS_ACCESS_KEY
# A file /home/ubuntu/Zauberlehrling.txt. This is the file to be uploaded.
# The file will be uploaded to a folder named "Schiller". This folder will be created, if it does not exist.
# According to the value of EXPIRE this code will work until 2015-01-01
# Later on, you have to change this value.
###########################################################################################################


HMAC-SHA256s(){
 KEY="$1"
 DATA="$2"
 shift 2
 printf "$DATA" | openssl dgst -binary -sha256 -hmac "$KEY" | od -An -vtx1 | sed 's/[ \n]//g' | sed 'N;s/\n//'
}

HMAC-SHA256h(){
 KEY="$1"
 DATA="$2"
 shift 2
 printf "$DATA" | openssl dgst -binary -sha256 -mac HMAC -macopt "hexkey:$KEY" | od -An -vtx1 | sed 's/[ \n]//g' | sed 'N;s/\n//'
}


AWS_SECRET_KEY=$(cat /home/ubuntu/aws/security/AWS_SECRET_KEY)
AWS_ACCESS_KEY=$(cat /home/ubuntu/aws/security/AWS_ACCESS_KEY)

FILE_TO_UPLOAD="/home/ubuntu/Zauberlehrling.txt"
BUCKET="tekanet-backup"
STARTS_WITH="Schiller/Zauberlehrling"

REQUEST_TIME=$(date +"%Y%m%dT%H%M%SZ")
REQUEST_REGION="eu-central-1"
REQUEST_SERVICE="s3"
REQUEST_DATE=$(printf "${REQUEST_TIME}" | cut -c 1-8)
AWS4SECRET="AWS4"$AWS_SECRET_KEY
ALGORITHM="AWS4-HMAC-SHA256"
EXPIRE="2015-01-01T00:00:00.000Z"
ACL="private"

POST_POLICY='{"expiration":"'$EXPIRE'","conditions": [{"bucket":"'$BUCKET'" },{"acl":"'$ACL'" },["starts-with", "$key", "'$STARTS_WITH'"],["eq", "$Content-Type", "application/octet-stream"],{"x-amz-credential":"'$AWS_ACCESS_KEY'/'$REQUEST_DATE'/'$REQUEST_REGION'/'$REQUEST_SERVICE'/aws4_request"},{"x-amz-algorithm":"'$ALGORITHM'"},{"x-amz-date":"'$REQUEST_TIME'"}]}'

UPLOAD_REQUEST=$(printf "$POST_POLICY" | openssl base64 )
UPLOAD_REQUEST=$(echo -en $UPLOAD_REQUEST |  sed "s/ //g")

SIGNATURE=$(HMAC-SHA256h $(HMAC-SHA256h $(HMAC-SHA256h $(HMAC-SHA256h $(HMAC-SHA256s $AWS4SECRET $REQUEST_DATE ) $REQUEST_REGION) $REQUEST_SERVICE) "aws4_request") $UPLOAD_REQUEST)

curl --silent \
	-F "key=""$STARTS_WITH" \
	-F "acl="$ACL"" \
	-F "Content-Type="application/octet-stream"" \
	-F "x-amz-algorithm="$ALGORITHM"" \
	-F "x-amz-credential="$AWS_ACCESS_KEY/$REQUEST_DATE/$REQUEST_REGION/$REQUEST_SERVICE/aws4_request"" \
	-F "x-amz-date="$REQUEST_TIME"" \
	-F "Policy="$UPLOAD_REQUEST"" \
	-F "X-Amz-Signature="$SIGNATURE"" \
	-F "file=@"$FILE_TO_UPLOAD http://$BUCKET.s3.amazonaws.com/


