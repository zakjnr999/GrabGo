# Database Schema Column Names Reference

## Prisma uses camelCase in models, but columns in PostgreSQL are also camelCase

### Order Table (`orders`)
- `id`
- `customerId` (not customer_id)
- `restaurantId`
- `riderId`
- `status`

### OrderItem Table (`order_items`)
- `id`
- `orderId` (not order_id)
- `foodId` (not food_id)
- `groceryItemId`
- `pharmacyItemId`

### Food Table (`foods`)
- `id`
- `name`
- `price`
- `rating`
- `categoryId` (not category_id)
- `restaurantId` (not restaurant_id)
- `isAvailable` (not is_available)

### Restaurant Table (`restaurants`)
- `id`
- `restaurantName` (not restaurant_name)
- `rating`
- `ratingCount` (not rating_count)
- `isOpen` (not is_open)
- `status`

## SQL Query Fix

When writing raw SQL queries, use double quotes for camelCase columns:
```sql
SELECT oi."foodId", oi."orderId"
FROM order_items oi
WHERE oi."orderId" = '123'
```
