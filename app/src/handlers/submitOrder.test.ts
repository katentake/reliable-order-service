import { beforeEach, describe, expect, it } from "vitest";
import { mockClient } from "aws-sdk-client-mock";
import { DynamoDBDocumentClient, GetCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";
import { handler } from "./submitOrder.js";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

const ddbMock = mockClient(DynamoDBDocumentClient);
const sqsMock = mockClient(SQSClient);

const orderId = "9c858901-8a57-4791-81fe-4c455b099bc9";

function buildEvent(body: unknown): APIGatewayProxyEventV2 {
  return {
    body: JSON.stringify(body),
  } as unknown as APIGatewayProxyEventV2;
}

beforeEach(() => {
  ddbMock.reset();
  sqsMock.reset();
});

describe("submitOrder", () => {
  it("accepts a new order and enqueues it", async () => {
    ddbMock.on(PutCommand).resolves({});
    sqsMock.on(SendMessageCommand).resolves({});

    const result = await handler(
      buildEvent({
        orderId,
        restaurantId: "restaurant-1",
        items: [{ name: "Burger", quantity: 2 }],
      }),
    );

    expect(result.statusCode).toBe(202);
    expect(JSON.parse(result.body as string)).toEqual({ orderId, status: "PENDING" });
    expect(sqsMock.commandCalls(SendMessageCommand)).toHaveLength(1);
  });

  it("is idempotent when the same order is submitted twice", async () => {
    const conflict = new Error("conflict");
    conflict.name = "ConditionalCheckFailedException";
    ddbMock.on(PutCommand).rejects(conflict);
    ddbMock.on(GetCommand).resolves({
      Item: { orderId, status: "PROCESSING" },
    });

    const result = await handler(
      buildEvent({
        orderId,
        restaurantId: "restaurant-1",
        items: [{ name: "Burger", quantity: 2 }],
      }),
    );

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body as string)).toMatchObject({ orderId, status: "PROCESSING" });
    expect(sqsMock.commandCalls(SendMessageCommand)).toHaveLength(0);
  });

  it("rejects an invalid payload", async () => {
    const result = await handler(buildEvent({ orderId, restaurantId: "restaurant-1", items: [] }));

    expect(result.statusCode).toBe(400);
    expect(ddbMock.commandCalls(PutCommand)).toHaveLength(0);
  });

  it("rejects a malformed JSON body", async () => {
    const result = await handler({ body: "{not json" } as unknown as APIGatewayProxyEventV2);

    expect(result.statusCode).toBe(400);
  });
});
