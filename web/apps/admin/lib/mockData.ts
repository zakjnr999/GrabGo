// Mock customer data for development
export interface Customer {
    id: string
    username: string
    email: string
    phone: string
    profilePicture?: string
    emailVerified: boolean
    phoneVerified: boolean
    isActive: boolean
    role: 'customer' | 'admin' | 'vendor' | 'rider'
    createdAt: string
    lastSeen?: string
    totalOrders: number
    totalSpending: number
    referralCount: number
    creditsBalance: number
}

export const mockCustomers: Customer[] = [
    {
        id: '1',
        username: 'John Doe',
        email: 'john.doe@example.com',
        phone: '+233 24 123 4567',
        emailVerified: true,
        phoneVerified: true,
        isActive: true,
        role: 'customer',
        createdAt: '2024-01-15T10:30:00Z',
        lastSeen: '2024-12-21T15:45:00Z',
        totalOrders: 45,
        totalSpending: 2340.50,
        referralCount: 3,
        creditsBalance: 25.00,
    },
    {
        id: '2',
        username: 'Sarah Johnson',
        email: 'sarah.j@example.com',
        phone: '+233 20 987 6543',
        emailVerified: true,
        phoneVerified: false,
        isActive: true,
        role: 'customer',
        createdAt: '2024-02-20T14:20:00Z',
        lastSeen: '2024-12-22T09:15:00Z',
        totalOrders: 78,
        totalSpending: 4567.80,
        referralCount: 7,
        creditsBalance: 50.00,
    },
    {
        id: '3',
        username: 'Michael Chen',
        email: 'mchen@example.com',
        phone: '+233 55 456 7890',
        emailVerified: false,
        phoneVerified: true,
        isActive: true,
        role: 'customer',
        createdAt: '2024-03-10T08:45:00Z',
        lastSeen: '2024-12-20T18:30:00Z',
        totalOrders: 23,
        totalSpending: 1234.25,
        referralCount: 1,
        creditsBalance: 10.00,
    },
    {
        id: '4',
        username: 'Emma Williams',
        email: 'emma.w@example.com',
        phone: '+233 24 789 0123',
        emailVerified: true,
        phoneVerified: true,
        isActive: false,
        role: 'customer',
        createdAt: '2024-01-05T16:00:00Z',
        lastSeen: '2024-11-15T12:00:00Z',
        totalOrders: 12,
        totalSpending: 567.90,
        referralCount: 0,
        creditsBalance: 0.00,
    },
    {
        id: '5',
        username: 'David Brown',
        email: 'dbrown@example.com',
        phone: '+233 20 234 5678',
        emailVerified: true,
        phoneVerified: true,
        isActive: true,
        role: 'customer',
        createdAt: '2024-04-12T11:30:00Z',
        lastSeen: '2024-12-22T07:20:00Z',
        totalOrders: 156,
        totalSpending: 8901.45,
        referralCount: 12,
        creditsBalance: 100.00,
    },
    {
        id: '6',
        username: 'Lisa Anderson',
        email: 'lisa.a@example.com',
        phone: '+233 55 345 6789',
        emailVerified: false,
        phoneVerified: false,
        isActive: true,
        role: 'customer',
        createdAt: '2024-05-18T09:15:00Z',
        lastSeen: '2024-12-21T20:45:00Z',
        totalOrders: 8,
        totalSpending: 345.60,
        referralCount: 0,
        creditsBalance: 5.00,
    },
    {
        id: '7',
        username: 'James Wilson',
        email: 'jwilson@example.com',
        phone: '+233 24 567 8901',
        emailVerified: true,
        phoneVerified: true,
        isActive: true,
        role: 'customer',
        createdAt: '2024-02-28T13:45:00Z',
        lastSeen: '2024-12-22T06:30:00Z',
        totalOrders: 92,
        totalSpending: 5432.10,
        referralCount: 5,
        creditsBalance: 75.00,
    },
    {
        id: '8',
        username: 'Maria Garcia',
        email: 'maria.g@example.com',
        phone: '+233 20 678 9012',
        emailVerified: true,
        phoneVerified: true,
        isActive: true,
        role: 'customer',
        createdAt: '2024-06-05T10:00:00Z',
        lastSeen: '2024-12-21T16:20:00Z',
        totalOrders: 34,
        totalSpending: 1876.30,
        referralCount: 2,
        creditsBalance: 20.00,
    },
]

// Order data for customer detail view
export interface Order {
    id: string
    customerId: string
    date: string
    items: number
    total: number
    status: 'completed' | 'pending' | 'cancelled'
    vendorId?: string
    restaurant?: string
}

export const mockOrders: Order[] = [
    { id: 'ORD-001', customerId: '1', vendorId: 'VEN-001', date: '2024-12-20T14:30:00Z', items: 3, total: 45.50, status: 'completed', restaurant: 'Pizza Palace' },
    { id: 'ORD-002', customerId: '1', date: '2024-12-18T19:15:00Z', items: 2, total: 32.00, status: 'completed', restaurant: 'Burger House' },
    { id: 'ORD-003', customerId: '1', date: '2024-12-15T12:45:00Z', items: 5, total: 78.25, status: 'completed', restaurant: 'Sushi Bar' },
    { id: 'ORD-004', customerId: '1', date: '2024-12-10T18:00:00Z', items: 1, total: 15.00, status: 'cancelled', restaurant: 'Taco Stand' },
    { id: 'ORD-005', customerId: '2', vendorId: 'VEN-002', date: '2024-12-21T11:20:00Z', items: 4, total: 56.80, status: 'completed', restaurant: 'Noodle Shop' },
    { id: 'ORD-006', customerId: '2', vendorId: 'VEN-001', date: '2024-12-19T16:30:00Z', items: 2, total: 28.50, status: 'completed', restaurant: 'Cafe Delight' },
    { id: 'ORD-007', customerId: '3', vendorId: 'VEN-001', date: '2024-12-22T10:00:00Z', items: 1, total: 25.00, status: 'pending', restaurant: 'Pizza Palace' },
]

// Payment data for customer detail view
export interface Payment {
    id: string
    customerId: string
    date: string
    method: 'card' | 'mobile_money' | 'cash'
    amount: number
    status: 'success' | 'pending' | 'failed'
}

export const mockPayments: Payment[] = [
    { id: 'PAY-001', customerId: '1', date: '2024-12-20T14:30:00Z', method: 'card', amount: 45.50, status: 'success' },
    { id: 'PAY-002', customerId: '1', date: '2024-12-18T19:15:00Z', method: 'mobile_money', amount: 32.00, status: 'success' },
    { id: 'PAY-003', customerId: '1', date: '2024-12-15T12:45:00Z', method: 'card', amount: 78.25, status: 'success' },
    { id: 'PAY-004', customerId: '1', date: '2024-12-10T18:00:00Z', method: 'cash', amount: 15.00, status: 'failed' },
    { id: 'PAY-005', customerId: '2', date: '2024-12-21T11:20:00Z', method: 'mobile_money', amount: 56.80, status: 'success' },
    { id: 'PAY-006', customerId: '2', date: '2024-12-19T16:30:00Z', method: 'card', amount: 28.50, status: 'success' },
]

// Vendor data for vendors management module
export interface Vendor {
    id: string
    name: string
    type: 'food' | 'grocery' | 'pharmacy' | 'market'
    ownerName: string
    email: string
    phone: string
    address: string
    status: 'open' | 'closed' | 'busy' | 'under_review' | 'suspended'
    rating: number
    totalRevenue: number
    orderCount: number
    isVerified: boolean
    isFeatured: boolean
    createdAt: string
    logo?: string
    preparationTime?: number // in minutes
    deliveryRadius?: number // in km
    minOrderValue?: number
}

export interface CatalogItem {
    id: string
    vendorId: string
    name: string
    description: string
    price: number
    category: string
    image?: string
    inStock: boolean
    isAvailable: boolean
}

export const mockVendors: Vendor[] = [
    {
        id: 'VEN-001',
        name: 'Pizza Palace',
        type: 'food',
        ownerName: 'James Cook',
        email: 'contact@pizzapalace.com',
        phone: '+233 24 111 2222',
        address: '123 Ring Road, Accra',
        status: 'open',
        rating: 4.8,
        totalRevenue: 15420.50,
        orderCount: 450,
        isVerified: true,
        isFeatured: true,
        createdAt: '2023-10-01T08:00:00Z',
        preparationTime: 25,
        deliveryRadius: 5.0,
        minOrderValue: 20.0,
    },
    {
        id: 'VEN-002',
        name: 'Fresh Mart',
        type: 'grocery',
        ownerName: 'Alice Green',
        email: 'alice@freshmart.com',
        phone: '+233 20 333 4444',
        address: '45 Spintex Road, Accra',
        status: 'open',
        rating: 4.5,
        totalRevenue: 28900.00,
        orderCount: 1200,
        isVerified: true,
        isFeatured: false,
        createdAt: '2023-11-15T09:00:00Z',
        preparationTime: 30,
        deliveryRadius: 8.0,
        minOrderValue: 30.0,
    },
    {
        id: 'VEN-003',
        name: 'City Pharmacy',
        type: 'pharmacy',
        ownerName: 'Dr. Robert Smith',
        email: 'info@citypharmacy.com',
        phone: '+233 55 555 6666',
        address: '78 Labadi Link, Accra',
        status: 'busy',
        rating: 4.9,
        totalRevenue: 4500.25,
        orderCount: 150,
        isVerified: true,
        isFeatured: false,
        createdAt: '2024-01-20T10:30:00Z',
        preparationTime: 15,
        deliveryRadius: 3.0,
        minOrderValue: 10.0,
    },
    {
        id: 'VEN-004',
        name: 'Organic Roots',
        type: 'grocery',
        ownerName: 'Elena Gilbert',
        email: 'elena@organicroots.com',
        phone: '+233 24 777 8888',
        address: '22 Cantonments, Accra',
        status: 'closed',
        rating: 4.2,
        totalRevenue: 12300.75,
        orderCount: 320,
        isVerified: false,
        isFeatured: false,
        createdAt: '2024-02-10T11:00:00Z',
        preparationTime: 40,
        deliveryRadius: 10.0,
        minOrderValue: 50.0,
    },
    {
        id: 'VEN-005',
        name: 'Burger House',
        type: 'food',
        ownerName: 'Chef Antoine',
        email: 'orders@burgerhouse.gh',
        phone: '+233 20 999 0000',
        address: '5 Osu Oxford Street',
        status: 'open',
        rating: 4.7,
        totalRevenue: 9850.30,
        orderCount: 280,
        isVerified: true,
        isFeatured: true,
        createdAt: '2023-12-05T14:45:00Z',
        preparationTime: 20,
        deliveryRadius: 5.0,
        minOrderValue: 15.0,
    },
    {
        id: 'VEN-006',
        name: 'The Central Market',
        type: 'market',
        ownerName: 'Samuel Mensah',
        email: 'sam@centralmarket.com',
        phone: '+233 55 123 4455',
        address: 'Makola, Accra',
        status: 'under_review',
        rating: 0.0,
        totalRevenue: 0.00,
        orderCount: 0,
        isVerified: false,
        isFeatured: false,
        createdAt: '2024-12-15T16:20:00Z',
        preparationTime: 20,
        deliveryRadius: 4.0,
        minOrderValue: 15.0,
    },
]

export const mockCatalogItems: CatalogItem[] = [
    {
        id: 'ITM-001',
        vendorId: 'VEN-001',
        name: 'Margherita Pizza',
        description: 'Classic pizza with tomato sauce, mozzarella, and basil',
        price: 45.00,
        category: 'Pizza',
        inStock: true,
        isAvailable: true,
    },
    {
        id: 'ITM-002',
        vendorId: 'VEN-001',
        name: 'Pepperoni Feast',
        description: 'Loaded with spicy pepperoni and double cheese',
        price: 65.00,
        category: 'Pizza',
        inStock: true,
        isAvailable: true,
    },
    {
        id: 'ITM-003',
        vendorId: 'VEN-001',
        name: 'Garlic Knots',
        description: 'Baked dough with garlic butter and herbs',
        price: 20.00,
        category: 'Sides',
        inStock: true,
        isAvailable: true,
    },
    {
        id: 'ITM-004',
        vendorId: 'VEN-002',
        name: 'Organic Milk',
        description: '1 liter of fresh organic whole milk',
        price: 15.50,
        category: 'Dairy',
        inStock: true,
        isAvailable: true,
    },
    {
        id: 'ITM-005',
        vendorId: 'VEN-002',
        name: 'Brown Bread',
        description: 'Whole wheat high fiber bread',
        price: 12.00,
        category: 'Bakery',
        inStock: true,
        isAvailable: true,
    },
    {
        id: 'ITM-006',
        vendorId: 'VEN-003',
        name: 'Paracetamol',
        description: 'Pain relief and fever reducer, 500mg',
        price: 5.00,
        category: 'OTC Drugs',
        inStock: true,
        isAvailable: true,
    },
]

// Helper function to get customer by ID
export function getCustomerById(id: string): Customer | undefined {
    return mockCustomers.find(customer => customer.id === id)
}

// Helper function to get orders for a customer
export function getCustomerOrders(customerId: string): Order[] {
    return mockOrders.filter(order => order.customerId === customerId)
}

// Helper function to get payments for a customer
export function getCustomerPayments(customerId: string): Payment[] {
    return mockPayments.filter(payment => payment.customerId === customerId)
}

// Helper function to get vendor by ID
export function getVendorById(id: string): Vendor | undefined {
    return mockVendors.find(vendor => vendor.id === id)
}

export function getVendorCatalog(vendorId: string): CatalogItem[] {
    return mockCatalogItems.filter(item => item.vendorId === vendorId)
}

export function getVendorOrders(vendorId: string): Order[] {
    return mockOrders.filter(order => order.vendorId === vendorId)
}
