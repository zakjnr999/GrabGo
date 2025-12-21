// Authentication related TypeScript types and interfaces

export interface User {
    _id: string;
    email: string;
    username: string;
    role: string;
    isAdmin: boolean;
    isActive: boolean;
    profilePicture?: string | null;
}

export interface LoginCredentials {
    email: string;
    password: string;
}

export interface ForgotPasswordData {
    email: string;
}

export interface ResetPasswordData {
    token: string;
    password: string;
    confirmPassword: string;
}

export interface AuthState {
    user: User | null;
    isAuthenticated: boolean;
    isLoading: boolean;
}

export interface AuthResponse {
    user: User;
    token: string;
}
