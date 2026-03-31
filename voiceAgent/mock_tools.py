# TO SIMULATE REAL CUSTOMER SUPPORT BACKEND
# TO REPLACE EACH FUNCTION BODY WITH ACTUAL API/DB CALLS
MOCK_ORDERS={
    "12345": {"status": "shipped",    "delivery": "March 30", "item": "Wireless Headphones"},
    "67890": {"status": "processing", "delivery": "April 2",  "item": "Running Shoes"},
    "11111": {"status": "delivered",  "delivery": "March 25", "item": "Coffee Maker"}
}

def check_order_status(order_id:str)->str:
    order=MOCK_ORDERS.get(str(order_id))
    if order:
        return (f"Order {order_id} for {order['item']} is currently {order['status']}. Expected delivery : {order['delivery']}")
    return f"Order {order_id} was not found in our system."

def cancel_order(order_id: str) -> str:
    if str(order_id) in MOCK_ORDERS:
        return (f"Order {order_id} has been successfully cancelled. "
                f"A full refund will be processed within 3-5 business days.")
    return f"Could not cancel order {order_id} — order not found."
 
def check_refund_status(order_id: str) -> str:
    return (f"Refund for order {order_id} is being processed. "
            f"It will appear in your account within 5-7 business days.")
 
def update_email(new_email: str) -> str:
    return f"Your email address has been successfully updated to {new_email}."
 
def escalate_to_human() -> str:
    return "I'm transferring you to a human agent right now. Please hold for a moment."
 
def check_return_policy() -> str:
    return ("Our return policy allows returns within 30 days of purchase. "
            "Items must be unused and in their original packaging. "
            "Free return shipping is provided on all eligible items.")
 
def check_delivery_options() -> str:
    return ("We offer standard delivery (5-7 days), express delivery (2-3 days), "
            "and next-day delivery for eligible areas. Free shipping on orders over ₹500.")


# REGISTRY FOR EXECUTOR TO LOOKUP AND CALL TOOLS
TOOL_MAP={
    "check_order_status" : check_order_status,
    "cancel_order" : cancel_order,
    "check_refund_status" : check_refund_status,
    "update_email" : update_email,
    "escalate_to_human" : escalate_to_human,
    "check_delivery_options" : check_delivery_options
}