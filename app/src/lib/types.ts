export interface OrderLineItem {
  name: string;
  quantity: number;
}

export interface OrderRequest {
  orderId: string;
  restaurantId: string;
  items: OrderLineItem[];
  customerName?: string;
  simulateFailure?: boolean;
}

export type OrderStatus = "PENDING" | "PROCESSING" | "COMPLETED" | "FAILED";

export interface OrderResult {
  confirmedAt: string;
  message: string;
}

export interface OrderRecord {
  orderId: string;
  restaurantId: string;
  items: OrderLineItem[];
  customerName?: string;
  simulateFailure?: boolean;
  status: OrderStatus;
  createdAt: string;
  updatedAt: string;
  attempts: number;
  result?: OrderResult;
  error?: string;
}
