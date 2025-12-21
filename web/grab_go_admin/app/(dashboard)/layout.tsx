'use client';

import { useAuth } from "@/lib/context/AuthContext";
import { useRouter } from "next/navigation";
import { useEffect, useRef } from "react";

export default function DashboardLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    const { isAuthenticated, isLoading } = useAuth();
    const router = useRouter();
    const redirectAttempts = useRef(0);
    const MAX_REDIRECT_ATTEMPTS = 3;

    useEffect(() => {
        if (!isLoading && !isAuthenticated) {
            // Prevent infinite redirect loops
            if (redirectAttempts.current < MAX_REDIRECT_ATTEMPTS) {
                redirectAttempts.current += 1;
                router.push('/login');
            } else {
                console.error('Max redirect attempts reached. Possible redirect loop detected.');
            }
        } else if (isAuthenticated) {
            // Reset counter on successful auth
            redirectAttempts.current = 0;
        }
    }, [isAuthenticated, isLoading, router]);

    if (isLoading) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-background">
                <div className="flex flex-col items-center space-y-4">
                    <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin"></div>
                    <p className="text-sm text-muted-foreground animate-pulse">Loading dashboard...</p>
                </div>
            </div>
        );
    }

    if (!isAuthenticated) return null;

    return (
        <div className="min-h-screen bg-background">
            {/* TODO: Add Sidebar component here */}
            <main className="w-full">
                {children}
            </main>
        </div>
    );
}
