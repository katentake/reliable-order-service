import { z } from "zod";

export const orderRequestSchema = z.object({
  orderId: z.string().uuid(),
  restaurantId: z.string().min(1),
  items: z
    .array(
      z.object({
        name: z.string().min(1),
        quantity: z.number().int().positive(),
      }),
    )
    .min(1),
  customerName: z.string().min(1).optional(),
  simulateFailure: z.boolean().optional(),
});
