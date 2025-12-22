'use client';

import { useAuth, DashboardLayout as Layout, LoadingScreen } from "@grabgo/ui";
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
        return <LoadingScreen />;
    }

    if (!isAuthenticated) return null;

    return <Layout>{children}</Layout>;
}
