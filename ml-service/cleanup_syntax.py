"""
Script to fix syntax errors introduced by over-aggressive regex.
This will restore snake_case variable names in function signatures and internal code,
while preserving the double-quoted camelCase columns INSIDE SQL strings.
"""
import os
import re

files_to_fix = [
    'app/services/recommendation_service.py',
    'app/services/prediction_service.py',
    'app/services/analytics_service.py'
]

# Mapping of camelCase quotes to snake_case variables for Python code
reverse_mappings = {
    '"orderId"': 'order_id',
    '"foodId"': 'food_id',
    '"groceryItemId"': 'grocery_item_id',
    '"pharmacyItemId"': 'pharmacy_item_id',
    '"customerId"': 'user_id', # Note: mapping back to what was likely the original variable name
    '"restaurantId"': 'restaurant_id',
    '"riderId"': 'rider_id',
    '"totalAmount"': 'total_amount',
    '"createdAt"': 'created_at',
    '"deliveredDate"': 'delivered_date',
    '"orderType"': 'order_type',
    '"orderNumber"': 'order_number',
    '"deliveryFee"': 'delivery_fee',
    '"paymentMethod"': 'payment_method',
    '"paymentStatus"': 'payment_status',
    '"itemType"': 'item_type',
    '"categoryId"': 'category_id',
    '"isAvailable"': 'is_available',
    '"restaurantName"': 'restaurant_name',
    '"isOpen"': 'is_open',
    '"ratingCount"': 'rating_count',
    '"storeName"': 'store_name',
    '"lastOrderDate"': 'last_order_date',
}

def fix_syntax(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    # We want to replace quoted camelCase WITH snake_case ONLY IF NOT inside a SQL string.
    # A simple heuristic: if it's followed by a colon or equals sign outside of a multiline string.
    
    # 1. Fix function signatures: "camelCase": -> snake_case:
    for camel, snake in reverse_mappings.items():
        # Match parameter definition: , "camelCase": or (self, "camelCase":
        content = re.sub(r'([\(,]\s*)' + re.escape(camel) + r'(\s*[:=])', r'\1' + snake + r'\2', content)

    # 2. Fix dictionary keys where they should be snake_case (this is trickier, as some dicts are for SQL params)
    # Actually, the main issue is function signatures and potentially some internal variables.
    
    # 3. Specific line 26 fix for prediction_service.py just in case
    content = content.replace('delivery_location: Tuple[float, float], "riderId": Optional[str] = None', 
                              'delivery_location: Tuple[float, float],\n        rider_id: Optional[str] = None')

    with open(file_path, 'w') as f:
        f.write(content)

for f in files_to_fix:
    if os.path.exists(os.path.join('ml-service', f)):
        fix_syntax(os.path.join('ml-service', f))
        print(f"✅ Cleaned up {f}")
