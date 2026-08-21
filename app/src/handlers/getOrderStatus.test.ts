import { beforeEach, describe, expect, it } from "vitest";
import { mockClient } from "aws-sdk-client-mock";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";
import { handler } from "./getOrderStatus.js";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

const ddbMock = mockClient(DynamoDBDocumentClient);

function buildEvent(orderId?: string): APIGatewayProxyEventV2 {
  return {
    pathParameters: orderId ? { orderId } : undefined,
  } as unknown as APIGatewayProxyEventV2;
}

beforeEach(() => {
  ddbMock.reset();
});

describe("getOrderStatus", () => {
  it("returns the order when found", async () => {
    ddbMock.on(GetCommand).resolves({
      Item: { orderId: "abc", status: "COMPLETED", attempts: 1 },
    });

    const result = await handler(buildEvent("abc"));

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body as string)).toMatchObject({ orderId: "abc", status: "COMPLETED" });
  });

  it("returns 404 when the order does not exist", async () => {
    ddbMock.on(GetCommand).resolves({});

    const result = await handler(buildEvent("missing"));

    expect(result.statusCode).toBe(404);
  });

  it("returns 400 when orderId is missing", async () => {
    const result = await handler(buildEvent());

    expect(result.statusCode).toBe(400);
  });
});
