# Parking Lot Management Cloud Application
A simple parking lot management cloud application using AWS EC2 & DynamoDB and written in Python.
This is a school project I created as part of the course "Cloud Computing" I enrolled in during my studies.

## Run Locally (with a remote DynamoDB table)

Please make sure you have installed and configured AWS CLI on your local machine.  

```
git clone https://github.com/avivshabi/parkingLot.git app  
cd app
pip3 install -r requirements.txt
aws dynamodb create-table --cli-input-json file://create-table.json
uvicorn main:app --host 0.0.0.0 --port 5000
```

## Deploy to AWS

Please make sure you have installed and configured AWS CLI on your local machine.  

```
git clone https://github.com/avivshabi/parkingLot.git app  
cd app
./setup.sh
```

## API
### POST /entry  

Inserts a car parking record into DynamoDB
```
method: POST
path: /entry?plate=<CAR LICENSE PLATE NUM>&parkingLot=<PARKING LOT ID>
body: None
response type: json
response: { 
             ticketId: <GENERATED TICKET ID>
          }
```

### POST /exit  

Deletes a car parking record from DynamoDB (if exists) and returns a receipt
```
method: POST
path: /exit?tIcketId=<GENERATED TICKET ID>
body: None
response type: json
response: {
            'License Plate': <CAR LICENSE PLATE NUM>,
            'Total Parked Time (m)': <TOTAL PARKED TIME IN MINUTES>,
            'Parking Lot': <PARKING LOT ID>,
            'Charge ($)': <CHARGE AMOUNT>
          }
```

```<CHARGE AMOUNT>``` is calculated according to a rate of 10$ per hour and based on 15 minutes increments (2.5$ per 15 minutes)

##### Please note that the app doesn't check for correctness of the input and assumes no malicious input is supplied