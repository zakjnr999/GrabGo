// Constants for the GrabGo Admin Panel

// Brand Colors
export const BRAND_COLORS = {
    primary: '#FE6132',
    primaryRgb: '254, 97, 50',
} as const;

// API Endpoints (placeholder - update with actual backend URLs)
export const API_ENDPOINTS = {
    BASE_URL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000',
    AUTH: {
        LOGIN: '/api/auth/login',
        LOGOUT: '/api/auth/logout',
        FORGOT_PASSWORD: '/api/auth/forgot-password',
        RESET_PASSWORD: '/api/auth/reset-password',
        ME: '/api/auth/me',
    },
    ORDERS: {
        LIST: '/api/orders',
        DETAIL: (id: string) => `/api/orders/${id}`,
    },
    USERS: {
        LIST: '/api/users',
        DETAIL: (id: string) => `/api/users/${id}`,
    },
} as const;

// Route Paths
export const ROUTES = {
    HOME: '/',
    LOGIN: '/login',
    FORGOT_PASSWORD: '/forgot-password',
    RESET_PASSWORD: '/reset-password',
    DASHBOARD: '/dashboard',
    ORDERS: '/orders',
    USERS: '/users',
    ANALYTICS: '/analytics',
    SETTINGS: '/settings',
} as const;

// Local Storage Keys
export const STORAGE_KEYS = {
    AUTH_TOKEN: 'grabgo_admin_token',
    USER: 'grabgo_admin_user',
} as const;
