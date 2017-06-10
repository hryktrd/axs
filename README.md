# axs: Access to AWS without API tools (POSIX sh)
A simple 'aws' command 'axs' written in POSIX sh. axs(access) to aws(amazon web services) with posixism.

# SYNOPSIS
```
axs [option]... [FILE]
```
# DESCROPTION
## The feature of this command is
Without AWS API tools:  
There is no need to worry about version of AWS SDK,CLI anymore. Sig 4 is generated only by shellscript.

POSIX sh compliant:  
Write Onece, Run Anywhere, Run for Good. (Unix, Linux & Win)

True REST API:  
Just Write RESTful HTTP request in ASCII text format to access AWS. It is very intuitive. 
Free from too many options and subcommands.

## Requisites
- cat, grep, sed, awk, echo, printf
- openssl ver1.X.X
- curl
- wget

## Manual Installation
### 1. Clone repository
```
git clone https://github.com/BRAVEMAN-L-BRID/axs.git ~/axs
```
### 2. Add a path to PATH
make sure axs/bin be listed under $PATH.
```
export PATH="$PATH:/home/user/axs/bin"
```

## Configuration
Write access key ID and secret access key in ~ /.aws/credentials file as follows. Please be careful about permissions. or you can use IAM role in EC2 or Lambda.
```
[default]
aws_access_key_id = hogehoge
aws_secret_access_key = mogemoge
```

## USAGE
Usage is easy. It just reads the setting file (the way of writing is RESTful). It acts as a filter. Input is stdin and output is stdout.  
For example, using the cat command
```
$cat RESTful_API_file | axs
```
Or just put the REST API file in the argument
```
$axs RESTful_API_file
```
### RESTful_API_file
The format of RESTful_API_FILE is almost clear in HTTP request format. The only difference from normal is the description of the query, which is broken down into key value form.
```
METHOD URI    
Key Value
key Value
Key Value    
Host: ec2.ap-northeast-1.amazonaws.com 
Content-Type: application/hoghoge 
X-Amz-moge: hogehogehoge 

body (JSON, XML. Binary)
```
### RESPONSE
RESPONSE contains the response header and body. Because the AWS REST API uses header information frequently. Of course, you can erase the header information with the -q option if you get in the way
```
HTTP/1.1 200 OK
x-amz-id-2: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
x-amz-request-id: XXXXXXXXXXXXXXXX
Date: Sat, 10 Jun 2017 XX:XX:XXX GMT
x-amz-bucket-region: us-east-1
Content-Type: application/xml
Transfer-Encoding: chunked
Server: AmazonS3

<xml ......>
```
# OPTIONS
```
-f (image.jpg, video.mp4, music.mp3)...
    Separate the body part into another file (eg body.txt,image.jpg) and axs!
-q
    With this option you can delete the response header. 
    In this case, xml, json and binary will be returned directly, so it is convenient to process with pipe.
```

# EXAMPLES
In the following example, the image file is uploaded to S3
```
$cat<<END | axs -f moon.jpg
PUT /image.jpg
Host: Bucket.s3.amazonaws.com (東京リージョンの場合はbucket.s3-ap-northeast-1.amazonaws.com)
Content-Type: image/jpeg
END
```

With polly, get mp3 file
```
cat <<END axs -q > polly.mp3
POST /v1/speech
Host: polly.us-east-1.amazonaws.com
Content-Type: application/json

{
  "OutputFormat": "mp3",
  "Text": "Hello from SHELL",
  "VoiceId": "Mizuki"
}
END
```
All other AWS services can be used. EC2, RDB, S3, Polly, Lex, Rekognition, etc...
