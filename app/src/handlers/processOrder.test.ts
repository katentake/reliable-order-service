import { beforeEach, describe, expect, it } from "vitest";
import { mockClient } from "aws-sdk-client-mock";
import { DynamoDBDocumentClient, GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { handler } from "./processOrder.js";
import type { SQSEvent } from "aws-lambda";

const ddbMock = mockClient(DynamoDBDocumentClient);

function buildEvent(orderId: string, messageId = "msg-1"): SQSEvent {
  return {
    Records: [
      {
        messageId,
        body: JSON.stringify({ orderId }),
      } as unknown as SQSEvent["Records"][number],
    ],
  };
}

beforeEach(() => {
  ddbMock.reset();
});

describe("processOrder", () => {
  it("marks the order completed on success", async () => {
    ddbMock.on(GetCommand).resolves({
      Item: { orderId: "abc", simulateFailure: false },
    });
    ddbMock.on(UpdateCommand).resolves({});

    const result = await handler(buildEvent("abc"), {} as never, () => undefined);

    expect(result?.batchItemFailures).toHaveLength(0);
    const updateCalls = ddbMock.commandCalls(UpdateCommand);
    expect(updateCalls).toHaveLength(2);
    expect(updateCalls[1].args[0].input.ExpressionAttributeValues).toMatchObject({
      ":completed": "COMPLETED",
    });
  });

  it("reports a batch item failure when simulateFailure is set", async () => {
    ddbMock.on(GetCommand).resolves({
      Item: { orderId: "abc", simulateFailure: true },
    });
    ddbMock.on(UpdateCommand).resolves({});

    const result = await handler(buildEvent("abc", "msg-2"), {} as never, () => undefined);

    expect(result?.batchItemFailures).toEqual([{ itemIdentifier: "msg-2" }]);
  });

  it("drops the message when the order record no longer exists", async () => {
    ddbMock.on(GetCommand).resolves({});

    const result = await handler(buildEvent("missing"), {} as never, () => undefined);

    expect(result?.batchItemFailures).toHaveLength(0);
    expect(ddbMock.commandCalls(UpdateCommand)).toHaveLength(0);
  });
});
