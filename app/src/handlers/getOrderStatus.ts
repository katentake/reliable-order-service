import type { APIGatewayProxyEventV2, APIGatewayProxyStructuredResultV2 } from "aws-lambda";
import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, ORDERS_TABLE } from "../lib/dynamo.js";
import { jsonResponse } from "../lib/http.js";
import type { OrderRecord } from "../lib/types.js";

export const handler = async (
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyStructuredResultV2> => {
  const orderId = event.pathParameters?.orderId;
  if (!orderId) {
    return jsonResponse(400, { message: "orderId path parameter is required" });
  }

  const result = await ddb.send(
    new GetCommand({ TableName: ORDERS_TABLE, Key: { orderId } }),
  );

  if (!result.Item) {
    return jsonResponse(404, { message: `Order ${orderId} not found` });
  }

  const item = result.Item as OrderRecord;
  return jsonResponse(200, {
    orderId: item.orderId,
    status: item.status,
    result: item.result,
    error: item.error,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
    attempts: item.attempts,
  });
};
