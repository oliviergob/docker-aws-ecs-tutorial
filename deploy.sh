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
    error="$(aws cloudformation update-stack \
        --capabilities CAPABILITY_NAMED_IAM \
        --stack-name $appName \
        --template-body $cloudformation \
        --region $region 2>&1  > /dev/null)"

        # If the stack update did not work
        if [ $? != 0 ] && echo $error | grep -v --quiet 'No updates are to be performed'; then
          echo $error
          exit 1
        elif echo $error | grep -v --quiet 'No updates are to be performed'; then
          echo "Waiting for the stack to complete update, this can take a while"
          sleep 10

          aws cloudformation wait stack-update-complete \
              --stack-name $appName \
              --region $region
          if [[ $? != 0 ]]; then
            echo "Login to cloudformation front end and have a look at the event logs"
            exit 1
          fi
          echo "Stack Updated"
        else
          echo "No Update to the stack"
        fi
  else
    echo $error
    exit 1
  fi
## If no error during the stack creation
else
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

fi


# Generating ecs-params.yml
echo "Generating ecs-params.yml"
subnetId="$(prop 'net.subnet.id')"
sgId="$(prop 'net.sg.id')"
sed "s/NET_SUBNET_ID/$subnetId/g" ./ecs-params.template.yml > ./ecs-params.yml
sed -i "s/NET_SG_ID/$sgId/g" ./ecs-params.yml

# TODO - Sort this out
ecs-cli configure --cluster DockerEcsHelloWorld-DockerEcsHelloWorldCluster-1N0CSYLAYS1NU --default-launch-type FARGATE --region us-east-1
ecs-cli compose --project-name HelloWorldTutorial service up --create-log-groups
exit
