// Mock Order Data for GrabGo Admin Panel

export type OrderStatus =
    | 'pending'
    | 'confirmed'
    | 'preparing'
    | 'ready'
    | 'picked_up'
    | 'on_the_way'
    | 'delivered'
    | 'cancelled';

export type OrderType = 'food' | 'grocery' | 'pharmacy' | 'market';
export type PaymentStatus = 'pending' | 'paid' | 'failed' | 'refunded';
export type PaymentMethod = 'cash' | 'card' | 'mtn_momo' | 'vodafone_cash' | 'airtel_money';

export interface OrderItem {
    id: string;
    name: string;
    quantity: number;
    price: number;
    image?: string;
    specialInstructions?: string;
}

export interface CustomerInfo {
    id: string;
    name: string;
    email: string;
    phone: string;
    avatar?: string;
    totalOrders: number;
}

export interface VendorInfo {
    id: string;
    name: string;
    type: OrderType;
    phone: string;
    address: string;
    rating: number;
}

export interface RiderInfo {
    id: string;
    name: string;
    phone: string;
    rating: number;
    totalDeliveries: number;
    vehicleType: string;
    vehicleNumber: string;
}

export interface DeliveryInfo {
    address: string;
    city: string;
    coordinates: { lat: number; lng: number };
    instructions?: string;
    estimatedTime?: string;
}

export interface OrderPricing {
    subtotal: number;
    deliveryFee: number;
    tax: number;
    discount: number;
    total: number;
}

export interface StatusUpdate {
    status: OrderStatus;
    timestamp: string;
    note?: string;
}

export interface Order {
    id: string;
    orderNumber: string;
    type: OrderType;
    status: OrderStatus;
    paymentStatus: PaymentStatus;
    paymentMethod: PaymentMethod;
    customer: CustomerInfo;
    vendor: VendorInfo;
    rider?: RiderInfo;
    items: OrderItem[];
    pricing: OrderPricing;
    delivery: DeliveryInfo;
    timeline: StatusUpdate[];
    createdAt: string;
    updatedAt: string;
    notes?: string;
    promoCode?: string;
}

// Mock data generators
const customerNames = [
    'Sarah Johnson', 'Michael Osei', 'Akua Mensah', 'David Agyeman', 'Grace Boateng',
    'Kwame Asante', 'Ama Darko', 'John Smith', 'Abena Owusu', 'Kofi Adjei',
    'Emma Wilson', 'Yaw Mensah', 'Efua Agyei', 'James Brown', 'Adwoa Sarpong'
];

const vendorNames = {
    food: ['KFC Ghana', 'Papaye', 'Chicken Republic', 'Pizza Inn', 'Burger King', 'Chopsticks'],
    grocery: ['MaxMart', 'Shoprite', 'Game Stores', 'Melcom', 'Palace Supermarket'],
    pharmacy: ['Pharmacy Plus', 'Ernest Chemist', 'Kikiway Pharmacy', 'Medipharm'],
    market: ['Makola Market', 'Kaneshie Market', 'Madina Market', 'Tema Market']
};

const foodItems = [
    { name: 'Fried Chicken (2 pcs)', price: 25 },
    { name: 'Jollof Rice with Chicken', price: 35 },
    { name: 'Waakye with Fish', price: 30 },
    { name: 'Pizza Margherita (Large)', price: 65 },
    { name: 'Burger with Fries', price: 40 },
    { name: 'Banku with Tilapia', price: 45 },
    { name: 'Fufu with Light Soup', price: 38 },
    { name: 'Kenkey with Fish', price: 28 }
];

const groceryItems = [
    { name: 'Rice (5kg)', price: 45 },
    { name: 'Cooking Oil (2L)', price: 35 },
    { name: 'Sugar (1kg)', price: 12 },
    { name: 'Milk (1L)', price: 18 },
    { name: 'Bread (Loaf)', price: 8 },
    { name: 'Eggs (12 pcs)', price: 22 },
    { name: 'Tomatoes (1kg)', price: 15 },
    { name: 'Onions (1kg)', price: 10 }
];

const pharmacyItems = [
    { name: 'Paracetamol (500mg)', price: 5 },
    { name: 'Vitamin C Tablets', price: 25 },
    { name: 'Hand Sanitizer (500ml)', price: 18 },
    { name: 'Face Masks (Pack of 10)', price: 12 },
    { name: 'Cough Syrup', price: 22 },
    { name: 'Bandages (Pack)', price: 8 }
];

const addresses = [
    'East Legon, Accra',
    'Osu, Accra',
    'Tema Community 1',
    'Kumasi, Ahodwo',
    'Takoradi, Market Circle',
    'Spintex Road, Accra',
    'Madina, Accra',
    'Dansoman, Accra'
];

const riderNames = [
    'Kwabena Mensah', 'Yaw Boateng', 'Kofi Asare', 'Ama Adjei', 'Kwame Owusu',
    'Abena Darko', 'Yaw Agyei', 'Akosua Mensah', 'Kwesi Osei', 'Efua Asante'
];

function generateOrderNumber(): string {
    const prefix = 'ORD';
    const timestamp = Date.now().toString().slice(-8);
    const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
    return `${prefix}-${timestamp}-${random}`;
}

function getRandomItem<T>(array: T[]): T {
    return array[Math.floor(Math.random() * array.length)];
}

function getRandomItems<T>(array: T[], count: number): T[] {
    const shuffled = [...array].sort(() => 0.5 - Math.random());
    return shuffled.slice(0, count);
}

function generateTimeline(status: OrderStatus, createdAt: Date): StatusUpdate[] {
    const timeline: StatusUpdate[] = [];
    const statuses: OrderStatus[] = ['pending', 'confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way', 'delivered'];

    const currentIndex = statuses.indexOf(status);
    let currentTime = new Date(createdAt);

    for (let i = 0; i <= currentIndex; i++) {
        timeline.push({
            status: statuses[i],
            timestamp: currentTime.toISOString(),
            note: i === 0 ? 'Order placed' : undefined
        });

        // Add 5-15 minutes between statuses
        currentTime = new Date(currentTime.getTime() + (5 + Math.random() * 10) * 60000);
    }

    return timeline;
}

function generateOrder(index: number): Order {
    const type = getRandomItem<OrderType>(['food', 'grocery', 'pharmacy', 'market']);
    const statuses: OrderStatus[] = ['pending', 'confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way', 'delivered', 'cancelled'];
    const status = getRandomItem(statuses);
    const paymentMethods: PaymentMethod[] = ['cash', 'card', 'mtn_momo', 'vodafone_cash', 'airtel_money'];
    const paymentMethod = getRandomItem(paymentMethods);

    // Payment status logic
    let paymentStatus: PaymentStatus = 'pending';
    if (paymentMethod !== 'cash') {
        paymentStatus = status === 'cancelled' ? 'refunded' : Math.random() > 0.1 ? 'paid' : 'failed';
    } else {
        paymentStatus = ['delivered'].includes(status) ? 'paid' : 'pending';
    }

    // Generate items based on type
    let items: OrderItem[];
    if (type === 'food') {
        const selectedItems = getRandomItems(foodItems, Math.floor(Math.random() * 3) + 1);
        items = selectedItems.map((item, idx) => ({
            id: `item-${index}-${idx}`,
            name: item.name,
            quantity: Math.floor(Math.random() * 2) + 1,
            price: item.price
        }));
    } else if (type === 'grocery') {
        const selectedItems = getRandomItems(groceryItems, Math.floor(Math.random() * 4) + 2);
        items = selectedItems.map((item, idx) => ({
            id: `item-${index}-${idx}`,
            name: item.name,
            quantity: Math.floor(Math.random() * 3) + 1,
            price: item.price
        }));
    } else {
        const selectedItems = getRandomItems(pharmacyItems, Math.floor(Math.random() * 3) + 1);
        items = selectedItems.map((item, idx) => ({
            id: `item-${index}-${idx}`,
            name: item.name,
            quantity: Math.floor(Math.random() * 2) + 1,
            price: item.price
        }));
    }

    const subtotal = items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    const deliveryFee = type === 'food' ? 10 : type === 'grocery' ? 15 : 8;
    const tax = subtotal * 0.05;
    const discount = Math.random() > 0.7 ? subtotal * 0.1 : 0;
    const total = subtotal + deliveryFee + tax - discount;

    const createdAt = new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000); // Last 7 days
    const timeline = status === 'cancelled'
        ? [
            { status: 'pending' as OrderStatus, timestamp: createdAt.toISOString() },
            { status: 'cancelled' as OrderStatus, timestamp: new Date(createdAt.getTime() + 10 * 60000).toISOString(), note: 'Customer requested cancellation' }
        ]
        : generateTimeline(status, createdAt);

    const customer: CustomerInfo = {
        id: `customer-${index}`,
        name: getRandomItem(customerNames),
        email: `customer${index}@example.com`,
        phone: `+233${Math.floor(Math.random() * 900000000 + 100000000)}`,
        totalOrders: Math.floor(Math.random() * 50) + 1
    };

    const vendor: VendorInfo = {
        id: `vendor-${index}`,
        name: getRandomItem(vendorNames[type]),
        type,
        phone: `+233${Math.floor(Math.random() * 900000000 + 100000000)}`,
        address: getRandomItem(addresses),
        rating: 3.5 + Math.random() * 1.5
    };

    const rider: RiderInfo | undefined = ['picked_up', 'on_the_way', 'delivered'].includes(status)
        ? {
            id: `rider-${index}`,
            name: getRandomItem(riderNames),
            phone: `+233${Math.floor(Math.random() * 900000000 + 100000000)}`,
            rating: 4 + Math.random(),
            totalDeliveries: Math.floor(Math.random() * 500) + 50,
            vehicleType: getRandomItem(['Motorcycle', 'Bicycle', 'Car']),
            vehicleNumber: `GH-${Math.floor(Math.random() * 9000 + 1000)}-${Math.floor(Math.random() * 90 + 10)}`
        }
        : undefined;

    const delivery: DeliveryInfo = {
        address: getRandomItem(addresses),
        city: 'Accra',
        coordinates: {
            lat: 5.6 + Math.random() * 0.1,
            lng: -0.2 + Math.random() * 0.1
        },
        instructions: Math.random() > 0.5 ? 'Please call when you arrive' : undefined,
        estimatedTime: status === 'on_the_way' ? '15 mins' : status === 'ready' ? '20 mins' : undefined
    };

    return {
        id: `order-${index}`,
        orderNumber: generateOrderNumber(),
        type,
        status,
        paymentStatus,
        paymentMethod,
        customer,
        vendor,
        rider,
        items,
        pricing: {
            subtotal,
            deliveryFee,
            tax,
            discount,
            total
        },
        delivery,
        timeline,
        createdAt: createdAt.toISOString(),
        updatedAt: timeline[timeline.length - 1].timestamp,
        notes: Math.random() > 0.8 ? 'Customer requested extra napkins' : undefined,
        promoCode: discount > 0 ? 'SAVE10' : undefined
    };
}

// Generate 50 mock orders
export const mockOrders: Order[] = Array.from({ length: 50 }, (_, i) => generateOrder(i));

// Helper functions
export function getOrdersByStatus(status: OrderStatus): Order[] {
    return mockOrders.filter(order => order.status === status);
}

export function getOrdersByType(type: OrderType): Order[] {
    return mockOrders.filter(order => order.type === type);
}

export function getOrderById(id: string): Order | undefined {
    return mockOrders.find(order => order.id === id);
}

export function getTodayOrders(): Order[] {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return mockOrders.filter(order => new Date(order.createdAt) >= today);
}

export function getOrderStats() {
    const today = getTodayOrders();
    const pending = mockOrders.filter(o => o.status === 'pending').length;
    const active = mockOrders.filter(o => ['confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way'].includes(o.status)).length;
    const completed = today.filter(o => o.status === 'delivered').length;
    const revenue = today.filter(o => o.status === 'delivered').reduce((sum, o) => sum + o.pricing.total, 0);

    return {
        totalToday: today.length,
        pending,
        active,
        completed,
        revenue
    };
}
