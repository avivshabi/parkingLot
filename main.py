import time
import uuid

from boto3 import resource
from botocore.exceptions import ClientError
from fastapi import FastAPI, HTTPException

ENTRY_URL = '/entry'
EXIT_URL = '/exit'
TABLE = 'ParkingLotTable'
S_TO_MIN_CONST = 60
CHARGE_TIME = 15
FEE = 2.5

dynamodb = resource('dynamodb')
table = dynamodb.Table(TABLE)
app = FastAPI()


@app.post(path=ENTRY_URL)
async def enter(plate: str, parkingLot: str):
    try:
        table.put_item(
            Item={
                'PlateNumber': plate,
                'ParkingLot': parkingLot,
                'StartTime': int(time.time() // S_TO_MIN_CONST),
                'TicketID': uuid.uuid4().hex
            }
        )
    except ClientError as err:
        raise HTTPException(
            status_code=500,
            detail=f"Couldn't park {plate} in {parkingLot}. Here's why: {err.response['Error']['Code']}: {err.response['Error']['Message']}"
        )

    return {'status': 'parked'}


@app.post(path=EXIT_URL)
async def leave(ticketId: str):
    query = {'TicketID': ticketId}
    try:
        response = table.get_item(Key=query)
        if 'Item' not in response:
            raise HTTPException(
                status_code=404,
                detail=f"Couldn't find a vehicle with ticket id {ticketId}. Please make sure you have entered the right id."
            )
        response = response['Item']
        table.delete_item(Key=query)
    except ClientError as err:
        raise HTTPException(
            status_code=500,
            detail=f"Couldn't get vehicle with ticket id {ticketId}. Here's why: {err.response['Error']['Code']}: {err.response['Error']['Message']}"
        )
    else:
        total_time = (time.time() // S_TO_MIN_CONST) - int(response['StartTime'])
        total_cost = (total_time // CHARGE_TIME) * FEE
        return {
            'License Plate': response['PlateNumber'],
            'Total Parked Time (m)': total_time,
            'Parking Lot': response['ParkingLot'],
            'Charge ($)': total_cost
        }
