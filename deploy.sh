#!/bin/bash


function prop {
    grep "${1}" config.properties|cut -d'=' -f2
}

# Check if the AWS CLI is in the PATH
found=$(which aws)
if [ -z "$found" ]; then
  echo "Please install the AWS CLI under your PATH: http://aws.amazon.com/cli/"
  exit 1
fi

# Check if config.json is present
if [ ! -f config.properties ]
then
  echo "config.properties not found, please copy config.properties.template and edit the required values"
  exit 1
fi


# Read other configuration from config.json
region="$(prop 'app.region')"
appName="$(prop 'app.name')"
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cloudformation="file://cloudformation.json"


aws cloudformation describe-stacks \
  --stack-name $appName \
  --region $region >/dev/null

  if [[ $? != 0 ]]; then
    echo AAAAAAAAAAAaa
    exit 1
  fi

# Creating the cloudformation stack
error="$(aws cloudformation create-stack \
    --capabilities CAPABILITY_NAMED_IAM \
    --stack-name $appName \
    --template-body $cloudformation \
    --region $region 2>&1 > /dev/null)"

# If the stack creation returned an error
if [[ $? != 0 ]]; then
  if echo $error | grep --quiet AlreadyExistsException; then
    echo "Stack already exists, updating"
    aws cloudformation update-stack \
        --capabilities CAPABILITY_NAMED_IAM \
        --stack-name $appName \
        --template-body $cloudformation \
        --region $region > /dev/null

        # If the stack update did not work
        if [[ $? != 0 ]]; then
          exit 1
        fi
  else
    echo $error
    exit 1
  fi

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
