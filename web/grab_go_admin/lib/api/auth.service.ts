import apiClient from './client';
import type { LoginCredentials, ForgotPasswordData, AuthResponse } from '@/lib/types/auth.types';

export const authService = {
    /**
     * Login user with email and password
     */
    login: async (credentials: LoginCredentials): Promise<AuthResponse> => {
        try {
            const response = await apiClient.post('/users/login', credentials);

            if (response.data.token && response.data.user) {
                // Store token and user data (SSR safe)
                if (typeof window !== 'undefined') {
                    localStorage.setItem('grabgo_admin_token', response.data.token);
                    localStorage.setItem('grabgo_admin_user', JSON.stringify(response.data.user));
                }

                return {
                    user: response.data.user,
                    token: response.data.token,
                };
            }

            throw new Error(response.data.message || 'Login failed');
        } catch (error: any) {
            const message = error.response?.data?.message || error.message || 'Login failed';
            throw new Error(message);
        }
    },

    /**
     * Logout user
     */
    logout: async (): Promise<void> => {
        try {
            // Call logout endpoint (optional - backend may not have this)
            await apiClient.post('/users/logout').catch(() => {
                // Ignore errors from logout endpoint
            });
        } finally {
            // Always clear local storage (SSR safe)
            if (typeof window !== 'undefined') {
                localStorage.removeItem('grabgo_admin_token');
                localStorage.removeItem('grabgo_admin_user');
            }
        }
    },

    /**
     * Request password reset email
     */
    forgotPassword: async (data: ForgotPasswordData): Promise<void> => {
        try {
            const response = await apiClient.post('/users/forgot-password', data);
            // If we're here, axios didn't throw, so status is 2xx
            return;
        } catch (error: any) {
            const message = error.response?.data?.message || error.message || 'Failed to send reset email';
            throw new Error(message);
        }
    },

    /**
     * Get current user from token
     */
    getCurrentUser: async (): Promise<AuthResponse> => {
        try {
            const response = await apiClient.get('/users/me');

            if (response.data.user) {
                // Update stored user data (SSR safe)
                if (typeof window !== 'undefined') {
                    localStorage.setItem('grabgo_admin_user', JSON.stringify(response.data.user));
                }

                const token = typeof window !== 'undefined' ? localStorage.getItem('grabgo_admin_token') || '' : '';

                return {
                    user: response.data.user,
                    token,
                };
            }

            throw new Error('Failed to get user data');
        } catch (error: any) {
            // Clear invalid session (SSR safe)
            if (typeof window !== 'undefined') {
                localStorage.removeItem('grabgo_admin_token');
                localStorage.removeItem('grabgo_admin_user');
            }
            throw error;
        }
    },

    /**
     * Check if user is authenticated
     */
    isAuthenticated: (): boolean => {
        if (typeof window === 'undefined') return false;
        const token = localStorage.getItem('grabgo_admin_token');
        return !!token;
    },

    /**
     * Get stored user data
     */
    getStoredUser: () => {
        if (typeof window === 'undefined') return null;
        const userStr = localStorage.getItem('grabgo_admin_user');
        if (!userStr) return null;

        try {
            return JSON.parse(userStr);
        } catch {
            return null;
        }
    },
};
