const mongoose = require('mongoose');
require('dotenv').config();

const Food = require('../models/Food');
const Category = require('../models/Category');
const Restaurant = require('../models/Restaurant');

const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo-db', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('✅ Connected to MongoDB');
  } catch (error) {
    console.error('❌ MongoDB connection error:', error);
    process.exit(1);
  }
};

const categories = [
  { name: 'Fast Food', description: 'Quick and delicious meals', emoji: '🍔' },
  { name: 'Pizza', description: 'Italian style pizzas', emoji: '🍕' },
  { name: 'Asian Cuisine', description: 'Asian dishes and specialties', emoji: '🍜' },
  { name: 'Local Dishes', description: 'Traditional local cuisine', emoji: '🍲' },
  { name: 'Desserts', description: 'Sweet treats and desserts', emoji: '🍰' },
  { name: 'Beverages', description: 'Drinks and refreshments', emoji: '🥤' },
  { name: 'Breakfast', description: 'Morning meals and snacks', emoji: '🥞' },
  { name: 'Grilled', description: 'Grilled and barbecued items', emoji: '🔥' }
];

const restaurants = [
  {
    restaurant_name: "Adepa Restaurant",
    email: "adepa@gmail.com",
    phone: "0552501805",
    address: "Adenta Madina",
    city: "Accra",
    owner_full_name: "Adepa Res",
    owner_contact_number: "0536997662",
    business_id_number: "AHHSJJ66634",
    password: "password123",
    food_type: "Local & International",
    description: "Adepa Restaurant is a cozy and vibrant dining spot that blends traditional and modern flavors to create an unforgettable experience.",
    latitude: 5.6969,
    longitude: -0.1674,
    average_delivery_time: "25-30 mins",
    delivery_fee: 5.00,
    min_order: 20.00,
    opening_hours: "9:00 AM - 10:00 PM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800",
      "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=500",
    rating: 4.2,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Tasty Bites",
    email: "tastybites@gmail.com",
    phone: "0241234567",
    address: "Accra Central",
    city: "Accra",
    owner_full_name: "John Doe",
    owner_contact_number: "0241234567",
    business_id_number: "TB123456789",
    password: "password123",
    food_type: "Fast Food & Quick Bites",
    description: "Tasty Bites offers delicious fast food options with a focus on quality and speed.",
    latitude: 5.6037,
    longitude: -0.1870,
    average_delivery_time: "20-25 mins",
    delivery_fee: 4.50,
    min_order: 15.00,
    opening_hours: "8:00 AM - 11:00 PM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1551782450-17144efb9c50?w=800",
      "https://images.unsplash.com/photo-1550547660-d9450f859349?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500",
    rating: 4.5,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Pizza Palace",
    email: "pizzapalace@gmail.com",
    phone: "0247654321",
    address: "East Legon",
    city: "Accra",
    owner_full_name: "Jane Smith",
    owner_contact_number: "0247654321",
    business_id_number: "PP987654321",
    password: "password123",
    food_type: "Italian & Pizza",
    description: "Pizza Palace serves authentic Italian pizzas with fresh ingredients and traditional recipes.",
    latitude: 5.6267,
    longitude: -0.1536,
    average_delivery_time: "30-35 mins",
    delivery_fee: 6.00,
    min_order: 25.00,
    opening_hours: "11:00 AM - 12:00 AM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=800",
      "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500",
    rating: 4.3,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Golden Spoon",
    email: "goldenspoon@gmail.com",
    phone: "0501234567",
    address: "Osu",
    city: "Accra",
    owner_full_name: "Mary Johnson",
    owner_contact_number: "0501234567",
    business_id_number: "GS456789123",
    password: "password123",
    food_type: "Local & Continental",
    description: "Golden Spoon specializes in authentic Ghanaian cuisine with a modern twist.",
    latitude: 5.5558,
    longitude: -0.1828,
    average_delivery_time: "35-40 mins",
    delivery_fee: 7.00,
    min_order: 30.00,
    opening_hours: "10:00 AM - 9:00 PM",
    payment_methods: ["Cash", "Mobile Money"],
    banner_images: [
      "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800",
      "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500",
    rating: 4.1,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Mama's Kitchen",
    email: "mamaskitchen@gmail.com",
    phone: "0544123456",
    address: "Dansoman",
    city: "Accra",
    owner_full_name: "Mama Esi",
    owner_contact_number: "0544123456",
    business_id_number: "MK789123456",
    password: "password123",
    food_type: "Traditional Ghanaian",
    description: "Mama's Kitchen brings you the authentic taste of home with traditional Ghanaian recipes passed down through generations.",
    latitude: 5.5399,
    longitude: -0.2370,
    average_delivery_time: "40-45 mins",
    delivery_fee: 6.50,
    min_order: 25.00,
    opening_hours: "7:00 AM - 9:00 PM",
    payment_methods: ["Cash", "Mobile Money"],
    banner_images: [
      "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800",
      "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=500",
    rating: 4.7,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Dragon Palace",
    email: "dragonpalace@gmail.com",
    phone: "0207654321",
    address: "Airport Residential",
    city: "Accra",
    owner_full_name: "Wong Li Ming",
    owner_contact_number: "0207654321",
    business_id_number: "DP456789012",
    password: "password123",
    food_type: "Chinese Cuisine",
    description: "Dragon Palace offers authentic Chinese cuisine with a modern twist, featuring fresh ingredients and traditional cooking methods.",
    latitude: 5.6052,
    longitude: -0.1719,
    average_delivery_time: "30-35 mins",
    delivery_fee: 8.00,
    min_order: 35.00,
    opening_hours: "11:00 AM - 11:00 PM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800",
      "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=500",
    rating: 4.4,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Burger Junction",
    email: "burgerjunction@gmail.com",
    phone: "0553456789",
    address: "Achimota",
    city: "Accra",
    owner_full_name: "Michael Brown",
    owner_contact_number: "0553456789",
    business_id_number: "BJ123789456",
    password: "password123",
    food_type: "American Fast Food",
    description: "Burger Junction serves gourmet burgers, crispy fries, and milkshakes in a fun, casual atmosphere.",
    latitude: 5.6786,
    longitude: -0.2297,
    average_delivery_time: "20-25 mins",
    delivery_fee: 5.50,
    min_order: 18.00,
    opening_hours: "10:00 AM - 12:00 AM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1551782450-17144efb9c50?w=800",
      "https://images.unsplash.com/photo-1594212699903-ec8a3eca50f5?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500",
    rating: 4.0,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Spice Garden",
    email: "spicegarden@gmail.com",
    phone: "0249876543",
    address: "Tema",
    city: "Tema",
    owner_full_name: "Priya Sharma",
    owner_contact_number: "0249876543",
    business_id_number: "SG987654321",
    password: "password123",
    food_type: "Indian Cuisine",
    description: "Spice Garden brings you the rich flavors of India with authentic spices and traditional cooking techniques.",
    latitude: 5.6698,
    longitude: -0.0166,
    average_delivery_time: "35-40 mins",
    delivery_fee: 7.50,
    min_order: 30.00,
    opening_hours: "12:00 PM - 10:30 PM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800",
      "https://images.unsplash.com/photo-1574653118792-2db2ed767df8?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=500",
    rating: 4.6,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Ocean Breeze Seafood",
    email: "oceanbreeze@gmail.com",
    phone: "0558765432",
    address: "Labadi",
    city: "Accra",
    owner_full_name: "Captain James",
    owner_contact_number: "0558765432",
    business_id_number: "OB654321987",
    password: "password123",
    food_type: "Seafood & Coastal",
    description: "Ocean Breeze Seafood offers the freshest catch of the day prepared with coastal flavors and international techniques.",
    latitude: 5.5500,
    longitude: -0.1645,
    average_delivery_time: "40-45 mins",
    delivery_fee: 9.00,
    min_order: 40.00,
    opening_hours: "2:00 PM - 11:00 PM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1559847844-d7b65e8b2b09?w=800",
      "https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=500",
    rating: 4.5,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Le Petit Café",
    email: "lepetitcafe@gmail.com",
    phone: "0502345678",
    address: "Cantonment",
    city: "Accra",
    owner_full_name: "Marie Dubois",
    owner_contact_number: "0502345678",
    business_id_number: "LPC345678901",
    password: "password123",
    food_type: "French Bistro",
    description: "Le Petit Café brings French elegance to Accra with authentic pastries, coffee, and bistro classics.",
    latitude: 5.5612,
    longitude: -0.1956,
    average_delivery_time: "25-30 mins",
    delivery_fee: 6.00,
    min_order: 22.00,
    opening_hours: "7:00 AM - 8:00 PM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800",
      "https://images.unsplash.com/photo-1506084868230-bb9d95c24759?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500",
    rating: 4.3,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Taco Fiesta",
    email: "tacofiesta@gmail.com",
    phone: "0245678901",
    address: "East Legon Extension",
    city: "Accra",
    owner_full_name: "Carlos Rodriguez",
    owner_contact_number: "0245678901",
    business_id_number: "TF678901234",
    password: "password123",
    food_type: "Mexican Cuisine",
    description: "Taco Fiesta serves authentic Mexican street food with fresh ingredients and bold flavors.",
    latitude: 5.6389,
    longitude: -0.1445,
    average_delivery_time: "25-30 mins",
    delivery_fee: 5.50,
    min_order: 20.00,
    opening_hours: "11:00 AM - 10:00 PM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1565299585323-38174c6db101?w=800",
      "https://images.unsplash.com/photo-1625944230945-1b7dd3b949ab?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1565299585323-38174c6db101?w=500",
    rating: 4.2,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Healthy Bowls",
    email: "healthybowls@gmail.com",
    phone: "0557890123",
    address: "Dzorwulu",
    city: "Accra",
    owner_full_name: "Sarah Green",
    owner_contact_number: "0557890123",
    business_id_number: "HB890123456",
    password: "password123",
    food_type: "Healthy & Organic",
    description: "Healthy Bowls focuses on nutritious, organic meals that fuel your body and satisfy your taste buds.",
    latitude: 5.5889,
    longitude: -0.1978,
    average_delivery_time: "20-25 mins",
    delivery_fee: 4.00,
    min_order: 16.00,
    opening_hours: "8:00 AM - 7:00 PM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1511690743698-d9d85f2fbf38?w=800",
      "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1511690743698-d9d85f2fbf38?w=500",
    rating: 4.4,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "BBQ Masters",
    email: "bbqmasters@gmail.com",
    phone: "0543210987",
    address: "Spintex",
    city: "Accra",
    owner_full_name: "Big Joe Williams",
    owner_contact_number: "0543210987",
    business_id_number: "BBQ321098765",
    password: "password123",
    food_type: "Barbecue & Grill",
    description: "BBQ Masters specializes in slow-smoked meats and grilled specialties with homemade sauces and rubs.",
    latitude: 5.5756,
    longitude: -0.1134,
    average_delivery_time: "35-40 mins",
    delivery_fee: 7.00,
    min_order: 32.00,
    opening_hours: "12:00 PM - 11:00 PM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1544025162-d76694265947?w=800",
      "https://images.unsplash.com/photo-1532550907401-a500c9a57435?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1544025162-d76694265947?w=500",
    rating: 4.5,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Sweet Treats Bakery",
    email: "sweettreats@gmail.com",
    phone: "0509876543",
    address: "Tema Station",
    city: "Tema",
    owner_full_name: "Betty Johnson",
    owner_contact_number: "0509876543",
    business_id_number: "STB987654321",
    password: "password123",
    food_type: "Bakery & Desserts",
    description: "Sweet Treats Bakery creates artisanal cakes, pastries, and desserts using the finest ingredients.",
    latitude: 5.6234,
    longitude: -0.0789,
    average_delivery_time: "30-35 mins",
    delivery_fee: 5.00,
    min_order: 15.00,
    opening_hours: "6:00 AM - 8:00 PM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=800",
      "https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500",
    rating: 4.6,
    is_open: true,
    status: "approved"
  },
  {
    restaurant_name: "Noodle House",
    email: "noodlehouse@gmail.com",
    phone: "0246543210",
    address: "North Kaneshie",
    city: "Accra",
    owner_full_name: "Akiko Tanaka",
    owner_contact_number: "0246543210",
    business_id_number: "NH543210987",
    password: "password123",
    food_type: "Japanese & Asian Noodles",
    description: "Noodle House serves authentic Japanese ramen and Asian noodle dishes in a cozy, modern setting.",
    latitude: 5.5945,
    longitude: -0.2578,
    average_delivery_time: "30-35 mins",
    delivery_fee: 6.50,
    min_order: 25.00,
    opening_hours: "11:30 AM - 10:00 PM",
    payment_methods: ["Cash", "Mobile Money", "Card"],
    banner_images: [
      "https://images.unsplash.com/photo-1557872943-16a5ac26437e?w=800",
      "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800"
    ],
    logo: "https://images.unsplash.com/photo-1557872943-16a5ac26437e?w=500",
    rating: 4.3,
    is_open: true,
    status: "approved"
  }
];

// Expanded food items for production-level testing
const foodTemplates = [
  // Fast Food (20+ items)
  {
    name: "Classic Burger",
    description: "Juicy beef patty with fresh lettuce, tomato, and special sauce",
    price: 25.99,
    categoryName: "Fast Food",
    food_image: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500",
    ingredients: ["beef patty", "lettuce", "tomato", "cheese", "special sauce"],
    rating: 4.2,
    totalReviews: 156
  },
  {
    name: "Chicken Burger",
    description: "Grilled chicken breast with avocado and mayo",
    price: 23.50,
    categoryName: "Fast Food",
    food_image: "https://images.unsplash.com/photo-1553979459-d2229ba7433a?w=500",
    ingredients: ["chicken breast", "avocado", "lettuce", "mayo", "tomato"],
    rating: 4.0,
    totalReviews: 89
  },
  {
    name: "French Fries",
    description: "Crispy golden fries with seasoning",
    price: 12.00,
    categoryName: "Fast Food",
    food_image: "https://images.unsplash.com/photo-1630431341129-b653e634e4de?w=500",
    ingredients: ["potatoes", "oil", "salt"],
    rating: 4.3,
    totalReviews: 203
  },
  
  // Pizza
  {
    name: "Margherita Pizza",
    description: "Classic pizza with fresh tomatoes, mozzarella, and basil",
    price: 35.00,
    categoryName: "Pizza",
    food_image: "https://images.unsplash.com/photo-1604382355076-af4b0eb60143?w=500",
    ingredients: ["tomato sauce", "mozzarella", "basil", "olive oil"],
    rating: 4.5,
    totalReviews: 178
  },
  {
    name: "Pepperoni Pizza",
    description: "Delicious pizza topped with pepperoni and cheese",
    price: 42.00,
    categoryName: "Pizza",
    food_image: "https://images.unsplash.com/photo-1628840042765-356cda07504e?w=500",
    ingredients: ["tomato sauce", "mozzarella", "pepperoni"],
    rating: 4.4,
    totalReviews: 145
  },
  {
    name: "Chicken BBQ Pizza",
    description: "BBQ chicken with onions and bell peppers",
    price: 45.00,
    categoryName: "Pizza",
    food_image: "https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=500",
    ingredients: ["BBQ sauce", "chicken", "onions", "bell peppers", "mozzarella"],
    rating: 4.6,
    totalReviews: 98
  },

  // Asian Cuisine
  {
    name: "Chicken Fried Rice",
    description: "Wok-fried rice with chicken and vegetables",
    price: 28.00,
    categoryName: "Asian Cuisine",
    food_image: "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=500",
    ingredients: ["rice", "chicken", "carrots", "peas", "soy sauce", "eggs"],
    rating: 4.1,
    totalReviews: 234
  },
  {
    name: "Beef Noodles",
    description: "Stir-fried noodles with tender beef and vegetables",
    price: 32.00,
    categoryName: "Asian Cuisine",
    food_image: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=500",
    ingredients: ["noodles", "beef", "vegetables", "soy sauce", "garlic"],
    rating: 4.3,
    totalReviews: 167
  },
  {
    name: "Sweet & Sour Chicken",
    description: "Crispy chicken in sweet and sour sauce",
    price: 30.00,
    categoryName: "Asian Cuisine",
    food_image: "https://images.unsplash.com/photo-1626804475297-41608ea09aeb?w=500",
    ingredients: ["chicken", "bell peppers", "pineapple", "sweet and sour sauce"],
    rating: 4.2,
    totalReviews: 112
  },

  // Local Dishes
  {
    name: "Jollof Rice with Chicken",
    description: "Spicy rice cooked in tomato sauce with grilled chicken",
    price: 35.00,
    categoryName: "Local Dishes",
    food_image: "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=500",
    ingredients: ["rice", "tomatoes", "chicken", "onions", "spices"],
    rating: 4.7,
    totalReviews: 298
  },
  {
    name: "Banku with Tilapia",
    description: "Traditional fermented corn dough with grilled tilapia",
    price: 40.00,
    categoryName: "Local Dishes",
    food_image: "https://images.unsplash.com/photo-1580554530778-ca36943938b2?w=500",
    ingredients: ["corn dough", "tilapia", "pepper sauce", "onions"],
    rating: 4.4,
    totalReviews: 189
  },
  {
    name: "Kelewele",
    description: "Spiced fried plantain cubes",
    price: 15.00,
    categoryName: "Local Dishes",
    food_image: "https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=500",
    ingredients: ["plantain", "ginger", "pepper", "spices"],
    rating: 4.5,
    totalReviews: 145
  },

  // Breakfast
  {
    name: "Pancakes",
    description: "Fluffy pancakes served with maple syrup and butter",
    price: 18.00,
    categoryName: "Breakfast",
    food_image: "https://images.unsplash.com/photo-1506084868230-bb9d95c24759?w=500",
    ingredients: ["flour", "eggs", "milk", "maple syrup", "butter"],
    rating: 4.3,
    totalReviews: 87
  },
  {
    name: "Full English Breakfast",
    description: "Eggs, bacon, sausage, beans, and toast",
    price: 32.00,
    categoryName: "Breakfast",
    food_image: "https://images.unsplash.com/photo-1525351484163-7529414344d8?w=500",
    ingredients: ["eggs", "bacon", "sausage", "baked beans", "toast"],
    rating: 4.2,
    totalReviews: 156
  },

  // Grilled
  {
    name: "Grilled Chicken",
    description: "Marinated grilled chicken breast with herbs",
    price: 28.00,
    categoryName: "Grilled",
    food_image: "https://images.unsplash.com/photo-1532550907401-a500c9a57435?w=500",
    ingredients: ["chicken breast", "herbs", "spices", "marinade"],
    rating: 4.4,
    totalReviews: 167
  },
  {
    name: "BBQ Ribs",
    description: "Tender pork ribs with BBQ sauce",
    price: 45.00,
    categoryName: "Grilled",
    food_image: "https://images.unsplash.com/photo-1544025162-d76694265947?w=500",
    ingredients: ["pork ribs", "BBQ sauce", "spices"],
    rating: 4.6,
    totalReviews: 134
  },

  // Desserts
  {
    name: "Chocolate Cake",
    description: "Rich chocolate cake with cream frosting",
    price: 22.00,
    categoryName: "Desserts",
    food_image: "https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500",
    ingredients: ["chocolate", "flour", "eggs", "cream", "sugar"],
    rating: 4.5,
    totalReviews: 201
  },
  {
    name: "Ice Cream Sundae",
    description: "Vanilla ice cream with chocolate sauce and nuts",
    price: 16.00,
    categoryName: "Desserts",
    food_image: "https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=500",
    ingredients: ["vanilla ice cream", "chocolate sauce", "nuts", "cherry"],
    rating: 4.2,
    totalReviews: 145
  },

  // Beverages
  {
    name: "Fresh Orange Juice",
    description: "Freshly squeezed orange juice",
    price: 12.00,
    categoryName: "Beverages",
    food_image: "https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=500",
    ingredients: ["fresh oranges"],
    rating: 4.1,
    totalReviews: 78
  },
  {
    name: "Iced Coffee",
    description: "Cold brew coffee with ice and cream",
    price: 15.00,
    categoryName: "Beverages",
    food_image: "https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=500",
    ingredients: ["coffee beans", "ice", "cream", "sugar"],
    rating: 4.3,
    totalReviews: 92
  },

  // Additional Fast Food Items
  {
    name: "Double Cheeseburger",
    description: "Double beef patties with melted cheese and crispy bacon",
    price: 35.50,
    categoryName: "Fast Food",
    food_image: "https://images.unsplash.com/photo-1594212699903-ec8a3eca50f5?w=500",
    ingredients: ["beef patties", "cheese", "bacon", "lettuce", "tomato", "onion"],
    rating: 4.4,
    totalReviews: 289
  },
  {
    name: "Fish Burger",
    description: "Crispy fish fillet with tartar sauce and lettuce",
    price: 27.00,
    categoryName: "Fast Food",
    food_image: "https://images.unsplash.com/photo-1615297928068-0dc2e7cdf9d2?w=500",
    ingredients: ["fish fillet", "tartar sauce", "lettuce", "cheese", "bun"],
    rating: 4.0,
    totalReviews: 145
  },
  {
    name: "Chicken Wings (6pcs)",
    description: "Spicy buffalo chicken wings with ranch dip",
    price: 24.00,
    categoryName: "Fast Food",
    food_image: "https://images.unsplash.com/photo-1608039755401-742074f0548d?w=500",
    ingredients: ["chicken wings", "buffalo sauce", "ranch dip"],
    rating: 4.5,
    totalReviews: 312
  },
  {
    name: "Chicken Nuggets (10pcs)",
    description: "Crispy chicken nuggets with honey mustard sauce",
    price: 18.50,
    categoryName: "Fast Food",
    food_image: "https://images.unsplash.com/photo-1562967916-eb82221dfb38?w=500",
    ingredients: ["chicken", "breadcrumbs", "honey mustard sauce"],
    rating: 4.2,
    totalReviews: 198
  },
  {
    name: "Loaded Fries",
    description: "Fries topped with cheese, bacon, and green onions",
    price: 16.00,
    categoryName: "Fast Food",
    food_image: "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=500",
    ingredients: ["fries", "cheese", "bacon", "green onions", "sour cream"],
    rating: 4.3,
    totalReviews: 256
  },
  {
    name: "Onion Rings",
    description: "Crispy golden onion rings with spicy mayo",
    price: 14.00,
    categoryName: "Fast Food",
    food_image: "https://images.unsplash.com/photo-1639744211460-9cf5c3b9eb36?w=500",
    ingredients: ["onions", "batter", "spicy mayo"],
    rating: 4.1,
    totalReviews: 178
  },
  {
    name: "Hot Dog",
    description: "All-beef hot dog with mustard, ketchup, and onions",
    price: 13.50,
    categoryName: "Fast Food",
    food_image: "https://images.unsplash.com/photo-1612392164886-ba0656b4c8f3?w=500",
    ingredients: ["beef hot dog", "bun", "mustard", "ketchup", "onions"],
    rating: 3.9,
    totalReviews: 134
  },
  {
    name: "Chicken Wrap",
    description: "Grilled chicken wrap with vegetables and ranch",
    price: 21.00,
    categoryName: "Fast Food",
    food_image: "https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=500",
    ingredients: ["chicken", "tortilla", "vegetables", "ranch dressing"],
    rating: 4.2,
    totalReviews: 167
  },

  // Additional Pizza Items
  {
    name: "Hawaiian Pizza",
    description: "Ham and pineapple with mozzarella cheese",
    price: 38.00,
    categoryName: "Pizza",
    food_image: "https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=500",
    ingredients: ["ham", "pineapple", "mozzarella", "tomato sauce"],
    rating: 4.1,
    totalReviews: 189
  },
  {
    name: "Meat Lovers Pizza",
    description: "Loaded with pepperoni, sausage, ham, and bacon",
    price: 52.00,
    categoryName: "Pizza",
    food_image: "https://images.unsplash.com/photo-1571407982968-6b89779ca38d?w=500",
    ingredients: ["pepperoni", "sausage", "ham", "bacon", "mozzarella"],
    rating: 4.6,
    totalReviews: 234
  },
  {
    name: "Veggie Supreme Pizza",
    description: "Bell peppers, mushrooms, onions, and olives",
    price: 36.00,
    categoryName: "Pizza",
    food_image: "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=500",
    ingredients: ["bell peppers", "mushrooms", "onions", "olives", "mozzarella"],
    rating: 4.0,
    totalReviews: 156
  },
  {
    name: "Four Cheese Pizza",
    description: "Mozzarella, cheddar, parmesan, and blue cheese",
    price: 41.00,
    categoryName: "Pizza",
    food_image: "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500",
    ingredients: ["mozzarella", "cheddar", "parmesan", "blue cheese"],
    rating: 4.3,
    totalReviews: 198
  },
  {
    name: "Buffalo Chicken Pizza",
    description: "Spicy buffalo chicken with ranch drizzle",
    price: 44.00,
    categoryName: "Pizza",
    food_image: "https://images.unsplash.com/photo-1585238342024-78d387f4a707?w=500",
    ingredients: ["buffalo chicken", "mozzarella", "ranch", "celery"],
    rating: 4.4,
    totalReviews: 167
  },

  // Additional Asian Cuisine Items
  {
    name: "Pad Thai",
    description: "Traditional Thai stir-fried noodles with shrimp",
    price: 29.00,
    categoryName: "Asian Cuisine",
    food_image: "https://images.unsplash.com/photo-1559847844-d7b65e8b2b09?w=500",
    ingredients: ["rice noodles", "shrimp", "bean sprouts", "peanuts", "lime"],
    rating: 4.5,
    totalReviews: 245
  },
  {
    name: "General Tso's Chicken",
    description: "Crispy chicken in sweet and spicy sauce",
    price: 31.00,
    categoryName: "Asian Cuisine",
    food_image: "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=500",
    ingredients: ["chicken", "sweet sauce", "spicy sauce", "broccoli", "rice"],
    rating: 4.3,
    totalReviews: 198
  },
  {
    name: "Sushi Combo",
    description: "8 pieces of fresh sushi with wasabi and ginger",
    price: 45.00,
    categoryName: "Asian Cuisine",
    food_image: "https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=500",
    ingredients: ["fresh fish", "sushi rice", "nori", "wasabi", "ginger"],
    rating: 4.7,
    totalReviews: 289
  },
  {
    name: "Ramen Bowl",
    description: "Rich pork broth with noodles, egg, and vegetables",
    price: 26.00,
    categoryName: "Asian Cuisine",
    food_image: "https://images.unsplash.com/photo-1557872943-16a5ac26437e?w=500",
    ingredients: ["ramen noodles", "pork broth", "egg", "vegetables", "seaweed"],
    rating: 4.4,
    totalReviews: 234
  },
  {
    name: "Orange Chicken",
    description: "Battered chicken in tangy orange sauce",
    price: 28.50,
    categoryName: "Asian Cuisine",
    food_image: "https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=500",
    ingredients: ["chicken", "orange sauce", "bell peppers", "onions"],
    rating: 4.2,
    totalReviews: 156
  },

  // Additional Local Dishes
  {
    name: "Waakye with Chicken",
    description: "Rice and beans with spicy chicken and vegetables",
    price: 32.00,
    categoryName: "Local Dishes",
    food_image: "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=500",
    ingredients: ["rice", "beans", "chicken", "pepper sauce", "vegetables"],
    rating: 4.6,
    totalReviews: 267
  },
  {
    name: "Fufu with Palm Nut Soup",
    description: "Traditional cassava fufu with rich palm nut soup",
    price: 38.00,
    categoryName: "Local Dishes",
    food_image: "https://images.unsplash.com/photo-1604329760661-e71dc83f8f26?w=500",
    ingredients: ["cassava", "palm nuts", "meat", "fish", "vegetables"],
    rating: 4.5,
    totalReviews: 198
  },
  {
    name: "Red Red",
    description: "Black-eyed peas stew with fried plantain",
    price: 22.00,
    categoryName: "Local Dishes",
    food_image: "https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=500",
    ingredients: ["black-eyed peas", "plantain", "palm oil", "onions", "spices"],
    rating: 4.3,
    totalReviews: 134
  },
  {
    name: "Kontomire Stew",
    description: "Cocoyam leaves stew with fish and meat",
    price: 35.00,
    categoryName: "Local Dishes",
    food_image: "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=500",
    ingredients: ["cocoyam leaves", "fish", "meat", "palm oil", "spices"],
    rating: 4.4,
    totalReviews: 167
  },
  {
    name: "Tuo Zaafi",
    description: "Northern Ghanaian dish with ayoyo soup",
    price: 30.00,
    categoryName: "Local Dishes",
    food_image: "https://images.unsplash.com/photo-1580554530778-ca36943938b2?w=500",
    ingredients: ["corn flour", "ayoyo leaves", "meat", "dawadawa", "spices"],
    rating: 4.2,
    totalReviews: 89
  },

  // Additional Breakfast Items
  {
    name: "Waffles with Berries",
    description: "Crispy waffles topped with fresh berries and syrup",
    price: 22.00,
    categoryName: "Breakfast",
    food_image: "https://images.unsplash.com/photo-1562376552-0d160dc2f296?w=500",
    ingredients: ["waffles", "fresh berries", "maple syrup", "whipped cream"],
    rating: 4.4,
    totalReviews: 178
  },
  {
    name: "French Toast",
    description: "Golden French toast with cinnamon and sugar",
    price: 19.50,
    categoryName: "Breakfast",
    food_image: "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=500",
    ingredients: ["bread", "eggs", "milk", "cinnamon", "sugar", "syrup"],
    rating: 4.3,
    totalReviews: 145
  },
  {
    name: "Breakfast Burrito",
    description: "Scrambled eggs, bacon, and cheese in a flour tortilla",
    price: 24.00,
    categoryName: "Breakfast",
    food_image: "https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=500",
    ingredients: ["eggs", "bacon", "cheese", "tortilla", "salsa"],
    rating: 4.2,
    totalReviews: 156
  },
  {
    name: "Avocado Toast",
    description: "Toasted bread with smashed avocado and egg",
    price: 21.00,
    categoryName: "Breakfast",
    food_image: "https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?w=500",
    ingredients: ["bread", "avocado", "egg", "tomato", "seasoning"],
    rating: 4.1,
    totalReviews: 134
  },
  {
    name: "Oatmeal Bowl",
    description: "Steel-cut oats with fruits and nuts",
    price: 16.50,
    categoryName: "Breakfast",
    food_image: "https://images.unsplash.com/photo-1493770348161-369560ae357d?w=500",
    ingredients: ["oats", "fruits", "nuts", "honey", "milk"],
    rating: 4.0,
    totalReviews: 89
  },

  // Additional Grilled Items
  {
    name: "Grilled Salmon",
    description: "Fresh Atlantic salmon with lemon and herbs",
    price: 42.00,
    categoryName: "Grilled",
    food_image: "https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=500",
    ingredients: ["salmon", "lemon", "herbs", "olive oil"],
    rating: 4.5,
    totalReviews: 198
  },
  {
    name: "Beef Steak",
    description: "Tender beef steak grilled to perfection",
    price: 55.00,
    categoryName: "Grilled",
    food_image: "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=500",
    ingredients: ["beef steak", "seasoning", "herbs", "garlic"],
    rating: 4.6,
    totalReviews: 267
  },
  {
    name: "Grilled Vegetables",
    description: "Mixed seasonal vegetables grilled with olive oil",
    price: 18.00,
    categoryName: "Grilled",
    food_image: "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=500",
    ingredients: ["bell peppers", "zucchini", "eggplant", "olive oil", "herbs"],
    rating: 4.0,
    totalReviews: 123
  },
  {
    name: "Lamb Chops",
    description: "Marinated lamb chops with mint sauce",
    price: 48.00,
    categoryName: "Grilled",
    food_image: "https://images.unsplash.com/photo-1544025162-d76694265947?w=500",
    ingredients: ["lamb chops", "mint sauce", "rosemary", "garlic"],
    rating: 4.4,
    totalReviews: 156
  },

  // Additional Desserts
  {
    name: "Cheesecake",
    description: "New York style cheesecake with berry topping",
    price: 25.00,
    categoryName: "Desserts",
    food_image: "https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=500",
    ingredients: ["cream cheese", "graham crackers", "berries", "sugar"],
    rating: 4.5,
    totalReviews: 234
  },
  {
    name: "Tiramisu",
    description: "Classic Italian tiramisu with coffee and mascarpone",
    price: 28.00,
    categoryName: "Desserts",
    food_image: "https://images.unsplash.com/photo-1571115764595-644a1f56a55c?w=500",
    ingredients: ["mascarpone", "coffee", "ladyfingers", "cocoa"],
    rating: 4.6,
    totalReviews: 189
  },
  {
    name: "Apple Pie",
    description: "Homemade apple pie with vanilla ice cream",
    price: 23.00,
    categoryName: "Desserts",
    food_image: "https://images.unsplash.com/photo-1621303837174-89787a4d4729?w=500",
    ingredients: ["apples", "pie crust", "cinnamon", "vanilla ice cream"],
    rating: 4.3,
    totalReviews: 167
  },
  {
    name: "Brownies",
    description: "Fudgy chocolate brownies with nuts",
    price: 18.00,
    categoryName: "Desserts",
    food_image: "https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=500",
    ingredients: ["chocolate", "flour", "nuts", "butter", "sugar"],
    rating: 4.2,
    totalReviews: 145
  },

  // Additional Beverages
  {
    name: "Smoothie Bowl",
    description: "Acai smoothie bowl with granola and fruits",
    price: 19.00,
    categoryName: "Beverages",
    food_image: "https://images.unsplash.com/photo-1511690743698-d9d85f2fbf38?w=500",
    ingredients: ["acai", "banana", "granola", "fresh fruits"],
    rating: 4.4,
    totalReviews: 178
  },
  {
    name: "Bubble Tea",
    description: "Taiwanese bubble tea with tapioca pearls",
    price: 17.00,
    categoryName: "Beverages",
    food_image: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=500",
    ingredients: ["tea", "milk", "tapioca pearls", "sugar"],
    rating: 4.1,
    totalReviews: 234
  },
  {
    name: "Lemonade",
    description: "Fresh squeezed lemonade with mint",
    price: 10.00,
    categoryName: "Beverages",
    food_image: "https://images.unsplash.com/photo-1523371683702-1325c2eeeb84?w=500",
    ingredients: ["lemons", "water", "sugar", "mint"],
    rating: 4.0,
    totalReviews: 156
  },
  {
    name: "Green Tea",
    description: "Traditional green tea with honey",
    price: 8.50,
    categoryName: "Beverages",
    food_image: "https://images.unsplash.com/photo-1564890614385-9b7b6b99a5c1?w=500",
    ingredients: ["green tea leaves", "honey", "water"],
    rating: 3.9,
    totalReviews: 89
  },
  {
    name: "Milkshake",
    description: "Vanilla milkshake with whipped cream",
    price: 16.00,
    categoryName: "Beverages",
    food_image: "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=500",
    ingredients: ["vanilla ice cream", "milk", "whipped cream", "cherry"],
    rating: 4.2,
    totalReviews: 167
  }
];

const createDummyData = async () => {
  try {
    await connectDB();

    console.log('\n🗑️  Clearing existing food and restaurant data...');
    await Food.deleteMany({});
    await Restaurant.deleteMany({});

    console.log('\n📋 Checking existing categories...');
    const existingCategories = await Category.find({});
    console.log(`   Found ${existingCategories.length} existing categories`);
    
    const createdCategories = [...existingCategories];
    
    // Only create missing categories
    for (const category of categories) {
      const exists = existingCategories.find(c => c.name === category.name);
      if (!exists) {
        console.log(`   Creating missing category: ${category.name}`);
        const newCategory = await Category.create(category);
        createdCategories.push(newCategory);
      }
    }
    
    console.log(`✅ Total categories available: ${createdCategories.length}`);

    console.log('\n🏪 Creating restaurants...');
    const createdRestaurants = await Restaurant.insertMany(restaurants);
    console.log(`✅ Created ${createdRestaurants.length} restaurants`);

    console.log('\n🍽️  Creating food items for each restaurant...');
    
    const allFoods = [];
    
    for (const restaurant of createdRestaurants) {
      console.log(`   📍 Adding foods to ${restaurant.restaurant_name}...`);
      
      // Each restaurant gets 20-35 random food items for production testing
      const numFoods = Math.floor(Math.random() * 16) + 20; // 20-35 items
      const selectedFoods = foodTemplates
        .sort(() => 0.5 - Math.random())
        .slice(0, numFoods);
      
      for (const foodTemplate of selectedFoods) {
        const category = createdCategories.find(c => c.name === foodTemplate.categoryName);
        if (category) {
          // Add some price variation (±15%) for each restaurant
          const priceVariation = 0.85 + Math.random() * 0.3; // 0.85 to 1.15
          const adjustedPrice = Math.round(foodTemplate.price * priceVariation * 100) / 100;
          
          const food = {
            name: foodTemplate.name,
            description: foodTemplate.description,
            price: adjustedPrice,
            food_image: foodTemplate.food_image,
            category: category._id,
            restaurant: restaurant._id,
            isAvailable: true,
            ingredients: foodTemplate.ingredients,
            rating: foodTemplate.rating + (Math.random() * 0.6 - 0.3), // Slight variation
            totalReviews: Math.floor(foodTemplate.totalReviews * (0.5 + Math.random() * 1.0))
          };
          
          allFoods.push(food);
        }
      }
    }

    const createdFoods = await Food.insertMany(allFoods);
    console.log(`✅ Created ${createdFoods.length} food items across all restaurants`);

    // Summary
    console.log('\n📊 Summary:');
    console.log(`   📋 Categories: ${createdCategories.length}`);
    console.log(`   🏪 Restaurants: ${createdRestaurants.length}`);
    console.log(`   🍽️  Foods: ${createdFoods.length}`);
    
    console.log('\n🏪 Restaurant Distribution:');
    for (const restaurant of createdRestaurants) {
      const foodCount = createdFoods.filter(f => f.restaurant.toString() === restaurant._id.toString()).length;
      console.log(`   ${restaurant.restaurant_name}: ${foodCount} items`);
    }

    console.log('\n✅ Dummy data created successfully!');
    console.log('   You can now test your food endpoints with populated data.');
    
  } catch (error) {
    console.error('❌ Error creating dummy data:', error);
  } finally {
    mongoose.connection.close();
  }
};

if (require.main === module) {
  createDummyData();
}

module.exports = { createDummyData };