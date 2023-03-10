import azure.functions as func
import logging
import os
import random
from azure.eventhub.aio import EventHubProducerClient
from azure.eventhub import EventData

app = func.FunctionApp()

EVENTHUB_NAMESPACE_CONNECTION_STRING = os.getenv("EVENTHUB_NAMESPACE_CONNECTION_STRING")
EVENTHUB_NAME                        = os.getenv("EVENTHUB_NAME")
DATABASE_NAME                        = os.getenv("DATABASE_NAME")
COLLECTION_NAME                      = os.getenv("COLLECTION_NAME")


@app.function_name(name="source")
@app.schedule(
        arg_name="timer",
        schedule="*/10 * * * * *", 
        run_on_startup=True,
        use_monitor=False)
# sends a random integer on an event hub
async def source(timer: func.TimerRequest) -> None:
    producer = EventHubProducerClient.from_connection_string(
        conn_str=EVENTHUB_NAMESPACE_CONNECTION_STRING, eventhub_name=EVENTHUB_NAME
    )
    async with producer:
        event_data_batch = await producer.create_batch()
        i = str(random.randint(0, 10))
        event_data_batch.add(EventData(i))
        print("SENDING: " + str(i))
        await producer.send_batch(event_data_batch)


@app.function_name(name="sink")
@app.event_hub_message_trigger(
    arg_name="event", 
    event_hub_name=EVENTHUB_NAME,
    connection="EVENTHUB_NAMESPACE_CONNECTION_STRING"
    ) 
@app.cosmos_db_input(
    arg_name="states", 
    database_name=DATABASE_NAME,
    collection_name=COLLECTION_NAME,
    connection_string_setting="COSMOSDB_CONNECTION_STRING"
    )
@app.cosmos_db_output(
    arg_name="newState", 
    database_name=DATABASE_NAME,
    collection_name=COLLECTION_NAME,
    connection_string_setting="COSMOSDB_CONNECTION_STRING",
    create_if_not_exists=False
    )
# sums the integers received from the event hub
def sink(event: func.EventHubEvent, states: func.DocumentList, newState: func.Out[func.Document]) -> None:
    input_value = 0
    if (len(states) > 0):
        input_value = int(states[-1].get("sum", 0))

    event_value = int(event.get_body().decode('utf-8'))
    new_sum = input_value + event_value

    output_doc = func.Document.from_dict({"sum": str(new_sum)})
    newState.set(output_doc)
    logging.info("sum: %s", str(new_sum))
