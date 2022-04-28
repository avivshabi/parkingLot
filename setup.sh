#!/bin/sh
# debug
# set -o xtrace

ID=$(gdate +'%N')
KEY_NAME="cloud-course-$ID"
KEY_PEM="$KEY_NAME.pem"
AWS_SETTINGS_FILE="aws.env"

echo "Creating dynamodb table..."
aws dynamodb create-table --cli-input-json file://create-table.json >/dev/null

echo "create key pair $KEY_PEM to connect to instances and save locally"
aws ec2 create-key-pair --key-name $KEY_NAME \
    | jq -r ".KeyMaterial" > $KEY_PEM

# secure the key pair
chmod 400 $KEY_PEM

SEC_GRP="my-sg-$ID"

echo "setup firewall $SEC_GRP"
aws ec2 create-security-group   \
    --group-name $SEC_GRP       \
    --description "Access my instances"

# figure out my ip
MY_IP=$(curl ipinfo.io/ip)
echo "My IP: $MY_IP"

echo "setup rule allowing HTTP (port 5000) access to $MY_IP only"
aws ec2 authorize-security-group-ingress        \
    --group-name $SEC_GRP --port 5000 --protocol tcp \
    --cidr $MY_IP/32 >/dev/null

echo "setup rule allowing SSH access to $MY_IP only"
aws ec2 authorize-security-group-ingress        \
    --group-name $SEC_GRP --port 22 --protocol tcp \
    --cidr $MY_IP/32 >/dev/null

UBUNTU_20_04_AMI="ami-042e8287309f5df03"

echo "Creating Ubuntu 20.04 instance..."
RUN_INSTANCES=$(aws ec2 run-instances   \
    --image-id $UBUNTU_20_04_AMI        \
    --instance-type t3.micro            \
    --key-name $KEY_NAME                \
    --security-groups $SEC_GRP)

INSTANCE_ID=$(echo $RUN_INSTANCES | jq -r '.Instances[0].InstanceId')

echo "Waiting for instance creation..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

PUBLIC_IP=$(aws ec2 describe-instances  --instance-ids $INSTANCE_ID |
    jq -r '.Reservations[0].Instances[0].PublicIpAddress'
)

echo "New instance $INSTANCE_ID @ $PUBLIC_IP"

echo "deploying code to production"
# overwrite AWS settings file if exists
echo "AWS_ACCESS_KEY_ID=`aws configure get aws_access_key_id`" > $AWS_SETTINGS_FILE
echo "AWS_SECRET_ACCESS_KEY=`aws configure get aws_secret_access_key`" >> $AWS_SETTINGS_FILE
echo "AWS_DEFAULT_REGION=`aws configure get region`" >> $AWS_SETTINGS_FILE
scp -v -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=60" $AWS_SETTINGS_FILE launch.sh ubuntu@$PUBLIC_IP:/home/ubuntu/
rm $AWS_SETTINGS_FILE

echo "setup production environment"
ssh -tt -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=10" ubuntu@$PUBLIC_IP 'sh ./launch.sh' < /dev/tty
ssh -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=10" ubuntu@$PUBLIC_IP <<EOF
    echo "Stating FastAPI server..."
    set -a
    source $AWS_SETTINGS_FILE
    set +a
    cd app
    nohup uvicorn main:app --host 0.0.0.0 --port 5000 &>/dev/null &
    exit
EOF

wait 10
echo "test that it all worked"
curl  --retry-connrefused --retry 10 --retry-delay 1  http://$PUBLIC_IP:5000
echo "log to http://$PUBLIC_IP:5000"