import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";

const client = new SQSClient({});
const queueUrl = process.env.ORDERS_QUEUE_URL ?? "";

export async function enqueueOrder(orderId: string): Promise<void> {
  await client.send(
    new SendMessageCommand({
      QueueUrl: queueUrl,
      MessageBody: JSON.stringify({ orderId }),
    }),
  );
}
