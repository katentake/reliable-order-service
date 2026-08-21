import type { APIGatewayProxyEventV2, APIGatewayProxyStructuredResultV2 } from "aws-lambda";
import { GetCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, ORDERS_TABLE } from "../lib/dynamo.js";
import { enqueueOrder } from "../lib/sqs.js";
import { jsonResponse } from "../lib/http.js";
import { orderRequestSchema } from "../lib/validation.js";
import type { OrderRecord } from "../lib/types.js";

export const handler = async (
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyStructuredResultV2> => {
  let body: unknown;
  try {
    body = JSON.parse(event.body ?? "{}");
  } catch {
    return jsonResponse(400, { message: "Request body must be valid JSON" });
  }

  const parsed = orderRequestSchema.safeParse(body);
  if (!parsed.success) {
    return jsonResponse(400, {
      message: "Invalid order payload",
      errors: parsed.error.flatten(),
    });
  }

  const order = parsed.data;
  const now = new Date().toISOString();

  try {
    await ddb.send(
      new PutCommand({
        TableName: ORDERS_TABLE,
        Item: {
          orderId: order.orderId,
          restaurantId: order.restaurantId,
          items: order.items,
          customerName: order.customerName,
          simulateFailure: order.simulateFailure ?? false,
          status: "PENDING",
          createdAt: now,
          updatedAt: now,
          attempts: 0,
        } satisfies OrderRecord,
        // Clients may retry the same orderId; only the first attempt should create the record and enqueue work.
        ConditionExpression: "attribute_not_exists(orderId)",
      }),
    );
  } catch (err) {
    if (isConditionalCheckFailed(err)) {
      const existing = await ddb.send(
        new GetCommand({ TableName: ORDERS_TABLE, Key: { orderId: order.orderId } }),
      );
      return jsonResponse(200, toStatusResponse(existing.Item as OrderRecord));
    }
    throw err;
  }

  await enqueueOrder(order.orderId);

  return jsonResponse(202, { orderId: order.orderId, status: "PENDING" });
};

function isConditionalCheckFailed(err: unknown): boolean {
  return err instanceof Error && err.name === "ConditionalCheckFailedException";
}

function toStatusResponse(item: OrderRecord) {
  return {
    orderId: item.orderId,
    status: item.status,
    result: item.result,
    error: item.error,
  };
}
