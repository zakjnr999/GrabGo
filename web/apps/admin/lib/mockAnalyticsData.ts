// Analytics Mock Data

// Revenue data for the last 7 days
export interface RevenueData {
    date: string
    revenue: number
    orders: number
}

export const mockRevenueData: RevenueData[] = [
    { date: '2024-12-16', revenue: 12450.00, orders: 145 },
    { date: '2024-12-17', revenue: 13200.50, orders: 158 },
    { date: '2024-12-18', revenue: 11800.75, orders: 132 },
    { date: '2024-12-19', revenue: 14500.25, orders: 172 },
    { date: '2024-12-20', revenue: 15200.00, orders: 185 },
    { date: '2024-12-21', revenue: 16800.50, orders: 198 },
    { date: '2024-12-22', revenue: 14200.00, orders: 165 },
]

// Order status distribution
export interface OrderStatusData {
    status: string
    count: number
    color: string
}

export const mockOrderStatusData: OrderStatusData[] = [
    { status: 'Delivered', count: 1245, color: '#10b981' },
    { status: 'On the way', count: 45, color: '#3b82f6' },
    { status: 'Preparing', count: 32, color: '#f59e0b' },
    { status: 'Pending', count: 18, color: '#6b7280' },
    { status: 'Cancelled', count: 67, color: '#ef4444' },
]

// Peak hours data (orders by hour)
export interface PeakHoursData {
    hour: string
    orders: number
}

export const mockPeakHoursData: PeakHoursData[] = [
    { hour: '00:00', orders: 5 },
    { hour: '01:00', orders: 2 },
    { hour: '02:00', orders: 1 },
    { hour: '03:00', orders: 0 },
    { hour: '04:00', orders: 1 },
    { hour: '05:00', orders: 3 },
    { hour: '06:00', orders: 8 },
    { hour: '07:00', orders: 25 },
    { hour: '08:00', orders: 42 },
    { hour: '09:00', orders: 35 },
    { hour: '10:00', orders: 28 },
    { hour: '11:00', orders: 45 },
    { hour: '12:00', orders: 98 },
    { hour: '13:00', orders: 112 },
    { hour: '14:00', orders: 78 },
    { hour: '15:00', orders: 52 },
    { hour: '16:00', orders: 48 },
    { hour: '17:00', orders: 65 },
    { hour: '18:00', orders: 125 },
    { hour: '19:00', orders: 145 },
    { hour: '20:00', orders: 98 },
    { hour: '21:00', orders: 72 },
    { hour: '22:00', orders: 45 },
    { hour: '23:00', orders: 18 },
]

// Payment method distribution
export interface PaymentMethodData {
    method: string
    amount: number
    count: number
    color: string
}

export const mockPaymentMethodData: PaymentMethodData[] = [
    { method: 'Mobile Money', amount: 45200.00, count: 542, color: '#f59e0b' },
    { method: 'Cash', amount: 28500.50, count: 385, color: '#10b981' },
    { method: 'Card', amount: 18750.25, count: 198, color: '#3b82f6' },
    { method: 'Wallet', amount: 5450.00, count: 82, color: '#8b5cf6' },
]

// Top performing vendors (across all service types)
export interface TopVendor {
    id: string
    name: string
    type: 'food' | 'grocery' | 'pharmacy' | 'market'
    revenue: number
    orders: number
    rating: number
}

export const mockTopVendors: TopVendor[] = [
    { id: '1', name: 'Pizza Palace', type: 'food', revenue: 18500.00, orders: 245, rating: 4.8 },
    { id: '2', name: 'Fresh Mart Grocery', type: 'grocery', revenue: 15200.50, orders: 312, rating: 4.6 },
    { id: '3', name: 'HealthPlus Pharmacy', type: 'pharmacy', revenue: 12800.75, orders: 156, rating: 4.9 },
    { id: '4', name: 'Burger Haven', type: 'food', revenue: 11500.00, orders: 198, rating: 4.5 },
    { id: '5', name: 'City Market', type: 'market', revenue: 9800.25, orders: 142, rating: 4.7 },
    { id: '6', name: 'QuickMeds Pharmacy', type: 'pharmacy', revenue: 8500.00, orders: 187, rating: 4.4 },
    { id: '7', name: 'Organic Grocers', type: 'grocery', revenue: 7200.50, orders: 98, rating: 4.6 },
    { id: '8', name: 'Sushi Express', type: 'food', revenue: 6800.00, orders: 112, rating: 4.5 },
    { id: '9', name: 'Wellness Pharmacy', type: 'pharmacy', revenue: 5900.75, orders: 95, rating: 4.3 },
    { id: '10', name: 'Farmers Market', type: 'market', revenue: 4500.00, orders: 78, rating: 4.8 },
]

// Popular items across all services
export interface PopularItem {
    id: string
    name: string
    vendor: string
    type: 'food' | 'grocery' | 'pharmacy' | 'market'
    orders: number
    revenue: number
    category: string
}

export const mockPopularItems: PopularItem[] = [
    { id: '1', name: 'Margherita Pizza', vendor: 'Pizza Palace', type: 'food', orders: 342, revenue: 5130.00, category: 'Pizza' },
    { id: '2', name: 'Fresh Milk (1L)', vendor: 'Fresh Mart Grocery', type: 'grocery', orders: 298, revenue: 2980.00, category: 'Dairy' },
    { id: '3', name: 'Paracetamol 500mg', vendor: 'HealthPlus Pharmacy', type: 'pharmacy', orders: 245, revenue: 1225.00, category: 'Pain Relief' },
    { id: '4', name: 'Classic Burger', vendor: 'Burger Haven', type: 'food', orders: 234, revenue: 4680.00, category: 'Burgers' },
    { id: '5', name: 'Fresh Tomatoes (1kg)', vendor: 'City Market', type: 'market', orders: 198, revenue: 1980.00, category: 'Vegetables' },
    { id: '6', name: 'Vitamin C Tablets', vendor: 'QuickMeds Pharmacy', type: 'pharmacy', orders: 187, revenue: 2805.00, category: 'Supplements' },
    { id: '7', name: 'Bread Loaf', vendor: 'Organic Grocers', type: 'grocery', orders: 156, revenue: 1560.00, category: 'Bakery' },
    { id: '8', name: 'California Roll', vendor: 'Sushi Express', type: 'food', orders: 142, revenue: 3550.00, category: 'Sushi' },
]

// User growth data (last 30 days)
export interface UserGrowthData {
    date: string
    newUsers: number
    totalUsers: number
}

export const mockUserGrowthData: UserGrowthData[] = Array.from({ length: 30 }, (_, i) => {
    const date = new Date()
    date.setDate(date.getDate() - (29 - i))
    return {
        date: date.toISOString().split('T')[0],
        newUsers: Math.floor(Math.random() * 50) + 10,
        totalUsers: 1000 + (i * 30) + Math.floor(Math.random() * 20),
    }
})

// Top performing riders
export interface TopRider {
    id: string
    name: string
    deliveries: number
    earnings: number
    rating: number
    acceptanceRate: number
}

export const mockTopRiders: TopRider[] = [
    { id: '1', name: 'Kwame Mensah', deliveries: 342, earnings: 5130.00, rating: 4.9, acceptanceRate: 95 },
    { id: '2', name: 'Ama Asante', deliveries: 298, earnings: 4470.00, rating: 4.8, acceptanceRate: 92 },
    { id: '3', name: 'Kofi Boateng', deliveries: 245, earnings: 3675.00, rating: 4.7, acceptanceRate: 88 },
    { id: '4', name: 'Akua Owusu', deliveries: 234, earnings: 3510.00, rating: 4.8, acceptanceRate: 90 },
    { id: '5', name: 'Yaw Agyeman', deliveries: 198, earnings: 2970.00, rating: 4.6, acceptanceRate: 85 },
    { id: '6', name: 'Abena Osei', deliveries: 187, earnings: 2805.00, rating: 4.7, acceptanceRate: 89 },
    { id: '7', name: 'Kwabena Frimpong', deliveries: 156, earnings: 2340.00, rating: 4.5, acceptanceRate: 82 },
    { id: '8', name: 'Efua Adjei', deliveries: 142, earnings: 2130.00, rating: 4.6, acceptanceRate: 87 },
]

// Order volume by type
export interface OrderVolumeData {
    date: string
    food: number
    grocery: number
    pharmacy: number
    market: number
}

export const mockOrderVolumeData: OrderVolumeData[] = Array.from({ length: 7 }, (_, i) => {
    const date = new Date()
    date.setDate(date.getDate() - (6 - i))
    return {
        date: date.toISOString().split('T')[0],
        food: Math.floor(Math.random() * 50) + 80,
        grocery: Math.floor(Math.random() * 40) + 40,
        pharmacy: Math.floor(Math.random() * 20) + 15,
        market: Math.floor(Math.random() * 15) + 10,
    }
})

// Customer insights
export interface CustomerInsight {
    metric: string
    value: number
    change: number
}

export const mockCustomerInsights: CustomerInsight[] = [
    { metric: 'Avg. Lifetime Value', value: 450.50, change: 12.3 },
    { metric: 'Repeat Order Rate', value: 68.5, change: 5.2 },
    { metric: 'Avg. Order Frequency', value: 3.2, change: 8.1 },
    { metric: 'Customer Retention', value: 72.8, change: -2.1 },
]

// Operational metrics
export interface OperationalMetric {
    metric: string
    value: string | number
    target: string | number
    status: 'good' | 'warning' | 'critical'
}

export const mockOperationalMetrics: OperationalMetric[] = [
    { metric: 'Avg. Delivery Time', value: '28 min', target: '30 min', status: 'good' },
    { metric: 'Order Completion Rate', value: '94.2%', target: '95%', status: 'warning' },
    { metric: 'Customer Satisfaction', value: 4.6, target: 4.5, status: 'good' },
    { metric: 'Vendor Response Time', value: '5 min', target: '10 min', status: 'good' },
    { metric: 'Rider Availability', value: '87%', target: '90%', status: 'warning' },
    { metric: 'Failed Deliveries', value: '2.1%', target: '< 3%', status: 'good' },
]

// Helper functions
export function getRevenueByDateRange(startDate: Date, endDate: Date): RevenueData[] {
    return mockRevenueData.filter(data => {
        const date = new Date(data.date)
        return date >= startDate && date <= endDate
    })
}

export function getTodayStats() {
    const today = mockRevenueData[mockRevenueData.length - 1]
    const yesterday = mockRevenueData[mockRevenueData.length - 2]

    return {
        todayRevenue: today.revenue,
        todayOrders: today.orders,
        yesterdayRevenue: yesterday.revenue,
        yesterdayOrders: yesterday.orders,
        revenueChange: ((today.revenue - yesterday.revenue) / yesterday.revenue) * 100,
        ordersChange: ((today.orders - yesterday.orders) / yesterday.orders) * 100,
    }
}

export function getWeekStats() {
    const thisWeek = mockRevenueData.slice(-7)
    const totalRevenue = thisWeek.reduce((sum, day) => sum + day.revenue, 0)
    const totalOrders = thisWeek.reduce((sum, day) => sum + day.orders, 0)

    return {
        weekRevenue: totalRevenue,
        weekOrders: totalOrders,
        avgDailyRevenue: totalRevenue / 7,
        avgDailyOrders: totalOrders / 7,
    }
}
