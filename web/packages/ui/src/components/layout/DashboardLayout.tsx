"use client";

import { useState } from "react";
import { Sidebar } from "./Sidebar";
import { Header } from "./Header";

interface DashboardLayoutProps {
    children: React.ReactNode;
}

export function DashboardLayout({ children }: DashboardLayoutProps) {
    const [isCollapsed, setIsCollapsed] = useState(false);

    return (
        <div className="min-h-screen bg-gradient-to-br from-background via-background to-secondary/20">
            {/* Animated Background Orbs - Neutral & Subtle */}
            <div className="fixed inset-0 overflow-hidden pointer-events-none z-0">
                <div
                    className="absolute top-0 -left-4 w-96 h-96 rounded-full blur-3xl animate-blob"
                    style={{
                        background:
                            "radial-gradient(circle, rgba(254, 97, 50, 0.08) 0%, rgba(254, 97, 50, 0.01) 100%)",
                    }}
                />
                <div
                    className="absolute top-0 -right-4 w-96 h-96 rounded-full blur-3xl animate-blob animation-delay-2000"
                    style={{
                        background:
                            "radial-gradient(circle, rgba(254, 97, 50, 0.06) 0%, transparent 100%)",
                    }}
                />
                <div
                    className="absolute -bottom-8 left-20 w-96 h-96 rounded-full blur-3xl animate-blob animation-delay-4000"
                    style={{
                        background:
                            "radial-gradient(circle, rgba(254, 97, 50, 0.08) 0%, rgba(254, 97, 50, 0.01) 100%)",
                    }}
                />
            </div>

            {/* Floating Grid Pattern - Subtle */}
            <div className="fixed inset-0 bg-[linear-gradient(to_right,#80808012_1px,transparent_1px),linear-gradient(to_bottom,#80808012_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_80%_50%_at_50%_0%,#000_70%,transparent_100%)] z-0" />

            {/* Sidebar */}
            <Sidebar isCollapsed={isCollapsed} onToggle={() => setIsCollapsed(!isCollapsed)} />

            {/* Main Content */}
            <div
                className={`transition-all duration-300 ${isCollapsed ? "ml-20" : "ml-64"
                    }`}
            >
                <Header isCollapsed={isCollapsed} />

                {/* Page Content */}
                <main className="relative z-10 p-6">
                    {children}
                </main>
            </div>
        </div>
    );
}
