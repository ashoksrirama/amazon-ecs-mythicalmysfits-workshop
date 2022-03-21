#!/bin/sh

cd ~/environment/

# Clone the Githup repo
git clone https://github.com/aws-samples/amazon-ecs-mythicalmysfits-workshop.git

cd ~/environment/amazon-ecs-mythicalmysfits-workshop/workshop-1

# Run the setup script
script/setup

# Export Env variables
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
export TABLE_NAME=$(jq < ~/environment/amazon-ecs-mythicalmysfits-workshop/workshop-1/cfn-output.json -r '.DynamoTable')
export BUCKET_NAME=$(jq < ~/environment/amazon-ecs-mythicalmysfits-workshop/workshop-1/cfn-output.json -r '.SiteBucket')
export MONO_ECR_REPOSITORY_URI=$(aws ecr describe-repositories | jq -r .repositories[].repositoryUri | grep mono)

echo "export ACCOUNT_ID=${ACCOUNT_ID}" >> ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" >> ~/.bash_profile
echo "export TABLE_NAME=${TABLE_NAME}" >> ~/.bash_profile
echo "export BUCKET_NAME=${BUCKET_NAME}" >> ~/.bash_profile
echo "export CLUSTER_NAME=mythicaleks-eksctl" >> ~/.bash_profile
echo "export DASHBOARD_VERSION=v2.0.0" >> ~/.bash_profile
echo "export MONO_ECR_REPOSITORY_URI=${MONO_ECR_REPOSITORY_URI}" >> ~/.bash_profile

aws configure set default.region ${AWS_REGION}
aws configure get default.region

# SSH Key generation
ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""

aws ec2 import-key-pair --key-name "mythicaleks" --public-key-material file://~/.ssh/id_rsa.pub

# Build the monolith image

cd ~/environment/amazon-ecs-mythicalmysfits-workshop/workshop-1/app/monolith-service

cat << EoF > Dockerfile
FROM ubuntu:latest
RUN apt-get update -y
RUN apt-get install -y python3-pip python-dev build-essential
RUN pip3 install --upgrade pip
COPY ./service/requirements.txt .
RUN pip3 install -r ./requirements.txt
COPY ./service /MythicalMysfitsService
WORKDIR /MythicalMysfitsService
EXPOSE 80
ENTRYPOINT ["python3"]
CMD ["mythicalMysfitsService.py"]

EoF


docker build -t monolith-service .

MONO_ECR_REPOSITORY_URI=$(aws ecr describe-repositories | jq -r .repositories[].repositoryUri | grep mono)

docker tag monolith-service:latest $MONO_ECR_REPOSITORY_URI:latest

docker push $MONO_ECR_REPOSITORY_URI:latest

echo "Successfully completed the init script, run below command to complete the setup."

echo ". ~/.bash_profile"
