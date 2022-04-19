#!/bin/sh
echo "Starting setup..."
sudo apt -f install
sudo apt -y update && sudo apt -y dist-upgrade
sudo apt -y install git
sudo apt -y install python3-pip
echo "Installing AWS CLI..."
pip3 install --upgrade awscli
sudo apt -y install awscli zip
echo "AWS CLI installed, please enter your credentials"
aws configure
sudo apt -y install build-essential libssl-dev libffi-dev python3-dev
sudo apt install -y python3-venv
git clone https://github.com/avivshabi/parkingLot.git app
echo "Successfully cloned github code..."
cd app
echo "Installing required packages..."
pip3 install -r requirements.txt
echo "Creating dynamodb table..."
aws dynamodb create-table --cli-input-json file://create-table.json
echo "Stating FastAPI server..."
nohup python3 -m uvicorn main:app --host 0.0.0.0 --port 5000 --reload