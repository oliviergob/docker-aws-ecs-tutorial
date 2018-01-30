#!/bin/bash

# Check if the AWS CLI is in the PATH
found=$(which aws)
if [ -z "$found" ]; then
  echo "Please install the AWS CLI under your PATH: http://aws.amazon.com/cli/"
  exit 1
fi

# Check if jq is in the PATH
found=$(which jq)
if [ -z "$found" ]; then
  echo "Please install jq under your PATH: http://stedolan.github.io/jq/"
  exit 1
fi

# Check if config.json is present
if [ ! -f config.json ]
then
  echo "config.json not found, please copy config.json.sample and edit the required values"
  exit 1
fi


# Read other configuration from config.json
region=$(jq -r '.deploymentRegion' config.json)
appName=$(jq -r '.appName' config.json)

cloudformation="file://cloudformation.json"
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Creating the cloudformation stack
aws cloudformation create-stack \
    --capabilities CAPABILITY_NAMED_IAM \
    --stack-name $appName \
    --template-body $cloudformation \
    --region $region >/dev/null

if [[ $? != 0 ]]; then
  exit 1
fi

echo "Waiting for the stack to complete creation, this can take a while"
sleep 10

aws cloudformation wait stack-create-complete \
    --stack-name $appName \
    --region $region

if [[ $? != 0 ]]; then
  echo "Login to cloudformation front end and have a look at the event logs"
  exit 1
fi

echo "Stack Created"

exit
