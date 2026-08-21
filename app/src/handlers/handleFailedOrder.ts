import type { SQSHandler } from "aws-lambda";
import { UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, ORDERS_TABLE } from "../lib/dynamo.js";

export const handler: SQSHandler = async (event) => {
  for (const record of event.Records) {
    const { orderId } = JSON.parse(record.body) as { orderId: string };
    const now = new Date().toISOString();

    console.error("Order exhausted retries and landed in the dead-letter queue", { orderId });

    await ddb.send(
      new UpdateCommand({
        TableName: ORDERS_TABLE,
        Key: { orderId },
        UpdateExpression: "SET #status = :failed, #error = :error, updatedAt = :now",
        ExpressionAttributeNames: { "#status": "status", "#error": "error" },
        ExpressionAttributeValues: {
          ":failed": "FAILED",
          ":error": "Exhausted retries; moved to dead-letter queue",
          ":now": now,
        },
      }),
    );
  }
};
