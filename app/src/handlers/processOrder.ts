import type { SQSBatchItemFailure, SQSBatchResponse, SQSHandler } from "aws-lambda";
import { GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, ORDERS_TABLE } from "../lib/dynamo.js";
import type { OrderRecord } from "../lib/types.js";

export const handler: SQSHandler = async (event): Promise<SQSBatchResponse> => {
  const batchItemFailures: SQSBatchItemFailure[] = [];

  for (const record of event.Records) {
    try {
      const { orderId } = JSON.parse(record.body) as { orderId: string };
      await processOne(orderId);
    } catch (err) {
      console.error("Failed to process order", {
        messageId: record.messageId,
        error: err instanceof Error ? err.message : err,
      });
      batchItemFailures.push({ itemIdentifier: record.messageId });
    }
  }

  return { batchItemFailures };
};

async function processOne(orderId: string): Promise<void> {
  const existing = await ddb.send(
    new GetCommand({ TableName: ORDERS_TABLE, Key: { orderId } }),
  );

  if (!existing.Item) {
    // Nothing to recover here — the message refers to a record that no longer exists, so don't retry it.
    console.error("Order record not found, dropping message", { orderId });
    return;
  }

  const order = existing.Item as OrderRecord;
  const now = new Date().toISOString();

  await ddb.send(
    new UpdateCommand({
      TableName: ORDERS_TABLE,
      Key: { orderId },
      UpdateExpression:
        "SET #status = :processing, updatedAt = :now, attempts = attempts + :one",
      ExpressionAttributeNames: { "#status": "status" },
      ExpressionAttributeValues: { ":processing": "PROCESSING", ":now": now, ":one": 1 },
    }),
  );

  // simulateFailure is read fresh from the record (not the SQS message) so that flipping it
  // and redriving a DLQ'd message is enough to demonstrate recovery without resubmitting.
  if (order.simulateFailure) {
    throw new Error("Simulated downstream failure");
  }

  await ddb.send(
    new UpdateCommand({
      TableName: ORDERS_TABLE,
      Key: { orderId },
      UpdateExpression: "SET #status = :completed, #result = :result, updatedAt = :now REMOVE #error",
      ExpressionAttributeNames: {
        "#status": "status",
        "#result": "result",
        "#error": "error",
      },
      ExpressionAttributeValues: {
        ":completed": "COMPLETED",
        ":result": { confirmedAt: now, message: "Order accepted by kitchen" },
        ":now": now,
      },
    }),
  );
}
