"""
Comprehensive script to fix ALL SQL column names in service files
This will handle both prefixed (o.created_at) and non-prefixed (created_at) columns
"""

import re

files_to_fix = [
    'app/services/recommendation_service.py',
    'app/services/prediction_service.py',
    'app/services/analytics_service.py'
]

# Column mappings - comprehensive list
column_mappings = {
    # Order columns
    'order_id': '"orderId"',
    'customer_id': '"customerId"',
    'restaurant_id': '"restaurantId"',
    'rider_id': '"riderId"',
    'total_amount': '"totalAmount"',
    'created_at': '"createdAt"',
    'delivered_date': '"deliveredDate"',
    'order_type': '"orderType"',
    'order_number': '"orderNumber"',
    'delivery_fee': '"deliveryFee"',
    'payment_method': '"paymentMethod"',
    'payment_status': '"paymentStatus"',
    
    # OrderItem columns
    'food_id': '"foodId"',
    'grocery_item_id': '"groceryItemId"',
    'pharmacy_item_id': '"pharmacyItemId"',
    'item_type': '"itemType"',
    
    # Food columns
    'category_id': '"categoryId"',
    'is_available': '"isAvailable"',
    
    # Restaurant columns
    'restaurant_name': '"restaurantName"',
    'is_open': '"isOpen"',
    'rating_count': '"ratingCount"',
    'store_name': '"storeName"',
    
    # User columns
    'last_order_date': '"lastOrderDate"',
    'first_name': '"firstName"',
    'last_name': '"lastName"',
}

def fix_sql_columns(content):
    """Fix SQL column names in the content"""
    
    # Pattern 1: Fix table-prefixed columns (e.g., o.created_at, r.restaurant_name)
    for snake, camel in column_mappings.items():
        # Match: table_alias.column_name
        pattern = r'(\w+)\.' + snake + r'\b'
        replacement = r'\1.' + camel
        content = re.sub(pattern, replacement, content)
    
    # Pattern 2: Fix non-prefixed columns in SQL strings
    # Only fix if it's clearly in a SQL context (after SELECT, WHERE, GROUP BY, ORDER BY, etc.)
    for snake, camel in column_mappings.items():
        # Match standalone column names (not already quoted, not part of a longer word)
        # This is more conservative to avoid false positives
        patterns = [
            (r'\bSELECT\s+([^F]*?)\b' + snake + r'\b', r'SELECT \1' + camel),
            (r'\bWHERE\s+([^F]*?)\b' + snake + r'\b', r'WHERE \1' + camel),
            (r'\bGROUP BY\s+([^O]*?)\b' + snake + r'\b', r'GROUP BY \1' + camel),
            (r'\bORDER BY\s+([^L]*?)\b' + snake + r'\b', r'ORDER BY \1' + camel),
            (r'\bAND\s+' + snake + r'\b', r'AND ' + camel),
            (r'\bOR\s+' + snake + r'\b', r'OR ' + camel),
            (r',\s*' + snake + r'\b', r', ' + camel),
        ]
        
        for pattern, repl in patterns:
            content = re.sub(pattern, repl, content, flags=re.IGNORECASE)
    
    return content

for file_path in files_to_fix:
    try:
        # Read the file
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Apply fixes
        fixed_content = fix_sql_columns(content)
        
        # Write back
        with open(file_path, 'w') as f:
            f.write(fixed_content)
        
        print(f"✅ Fixed {file_path}")
    except FileNotFoundError:
        print(f"⚠️  Skipped {file_path} (not found)")
    except Exception as e:
        print(f"❌ Error fixing {file_path}: {e}")

print("\n✅ All SQL column names fixed!")
print(f"\nFixed {len(column_mappings)} column mappings")
