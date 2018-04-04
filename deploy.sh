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
subnetIds="$(prop 'net.subnet.ids')"
sgIds="$(prop 'net.sg.ids')"
vpcId="$(prop 'net.vpc.id')"

# Checking if the stack exists already
error="$(aws cloudformation describe-stacks \
    --stack-name $appName \
    --region $region 2>&1 > /dev/null)"

# If describe-stacks returned ok, the stack exists
if [[ $? == 0 ]]; then
  echo "Updating existing stack $appName"
  stack_action=update-stack
  wait_action=stack-update-complete
# If the stack does not exist
elif echo $error | grep --quiet "does not exist"; then
  echo "Creating stack $appName"
  stack_action=create-stack
  wait_action=stack-create-complete
# If there is an error
else
  echo $error
  exit 1
fi

# Creating/Updating the cloudformation stack
error="$(aws cloudformation $stack_action \
    --capabilities CAPABILITY_NAMED_IAM \
    --stack-name $appName \
    --template-body $cloudformation \
    --region $region \
    --parameters ParameterKey=SubnetListParam,ParameterValue="\"$subnetIds\"" \
      ParameterKey=SecurityGroupsListParam,ParameterValue=$sgIds \
      ParameterKey=VpcIdParam,ParameterValue=$vpcId 2>&1 > /dev/null)"

# If aws cli cloudformation returned an error
if [[ $? != 0 ]]; then
  if echo $error | grep --quiet 'No updates are to be performed'; then
    echo "No Update to the stack"
  else
    echo $error
    exit 1
  fi
else
  echo "Waiting for the stack to complete creation/update, this can take a while"
  aws cloudformation wait $wait_action \
      --stack-name $appName \
      --region $region
  if [[ $? != 0 ]]; then
    echo "Login to cloudformation front end and have a look at the event logs"
    exit 1
  fi
  echo "Cloudformation creation/update completed"
fi

# Retreiving the target group arn created by the cloudofrmation stack
targetGroup="$(aws cloudformation describe-stacks \
                  --stack-name $appName \
                  --region $region \
                  --query 'Stacks[0].Outputs[0].OutputValue')"

# Removing quotes from targetGroup
targetGroup="${targetGroup%\"}"
targetGroup="${targetGroup#\"}"

# Generating ecs-params.yml
echo "Generating ecs-params.yml"

# Removing double quotes and using only the first subnet id
# Dirty hack!! Find something better
#tempSub="${subnetIds%\"}"
#tempSub="${tempSub#\"}"
tempSub="$(echo $subnetIds | cut -d',' -f1)"
tempSg="$(echo $sgIds | cut -d',' -f1)"
# Adding subnet id and security group id to the ecs params file
sed "s/NET_SUBNET_ID/$tempSub/g" ./ecs-params.template.yml > ./ecs-params.yml
sed -i "s/NET_SG_ID/$tempSg/g" ./ecs-params.yml

# Deploying the cluster
ecs-cli configure --cluster DockerEcsHelloWorldCluster --default-launch-type FARGATE --region us-east-1

echo "stopping the service (if running)"
ecs-cli compose --project-name HelloWorldTutorial service down 2>/dev/null

echo starting the service
ecs-cli compose --project-name HelloWorldTutorial service up \
                --target-group-arn $targetGroup \
                --container-name web \
                --container-port 80


exit
