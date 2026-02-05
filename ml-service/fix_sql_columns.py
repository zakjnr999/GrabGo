"""
Script to fix SQL column names in all service files
Run this to update all SQL queries to use camelCase column names
"""

import re

files_to_fix = [
    'app/services/recommendation_service.py',
    'app/services/prediction_service.py',
    'app/services/analytics_service.py'
]

# Define replacements (snake_case -> camelCase with quotes)
replacements = {
    'oi.food_id': 'oi."foodId"',
    'oi.order_id': 'oi."orderId"',
    'oi.grocery_item_id': 'oi."groceryItemId"',
    'oi.pharmacy_item_id': 'oi."pharmacyItemId"',
    'o.customer_id': 'o."customerId"',
    'o.restaurant_id': 'o."restaurantId"',
    'o.rider_id': 'o."riderId"',
    'o.total_amount': 'o."totalAmount"',
    'o.created_at': 'o."createdAt"',
    'o.delivered_date': 'o."deliveredDate"',
    'o.order_type': 'o."orderType"',
    'f.category_id': 'f."categoryId"',
    'f.restaurant_id': 'f."restaurantId"',
    'f.is_available': 'f."isAvailable"',
    'r.restaurant_name': 'r."restaurantName"',
    'r.is_open': 'r."isOpen"',
    'r.rating_count': 'r."ratingCount"',
    'r.delivery_fee': 'r."deliveryFee"',
    'r.store_name': 'r."storeName"',
    'u.created_at': 'u."createdAt"',
    'u.last_order_date': 'u."lastOrderDate"',
}

for file_path in files_to_fix:
    try:
        # Read the file
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Apply replacements
        for old, new in replacements.items():
            content = content.replace(old, new)
        
        # Write back
        with open(file_path, 'w') as f:
            f.write(content)
        
        print(f"✅ Fixed {file_path}")
    except FileNotFoundError:
        print(f"⚠️  Skipped {file_path} (not found)")

print("\n✅ All SQL column names fixed!")
print("\nUpdated columns:")
for old, new in replacements.items():
    print(f"  {old} -> {new}")
