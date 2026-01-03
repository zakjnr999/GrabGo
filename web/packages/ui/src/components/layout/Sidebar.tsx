"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "../../lib/utils";
import {
    ViewGrid,
    Group,
    Shop,
    Cart,
    Cycling,
    CreditCard,
    Gift,
    MessageText,
    Bell,
    StatsReport,
    Settings as SettingsIcon,
    NavArrowLeft,
    NavArrowRight,
    ShieldCheck,
    Database,
    NavArrowDown,
    FastArrowDown,
    PharmacyCrossTag,
    Leaf,
} from "iconoir-react";
import { useAuth } from "../../context/AuthContext";

interface SidebarProps {
    isCollapsed: boolean;
    onToggle: () => void;
}

const mainNavigation = [
    { name: "Dashboard", href: "/", icon: ViewGrid },
    { name: "Customers", href: "/users", icon: Group },
    { name: "Vendors", href: "/vendors", icon: Shop },
];

const catalogNavigation = [
    { name: "Food Items", href: "/food-items", icon: Database },
    { name: "Grocery Items", href: "/grocery-items", icon: Leaf },
    { name: "Pharmacy Items", href: "/pharmacy-items", icon: PharmacyCrossTag },
    { name: "Market Items", href: "/market-items", icon: Gift },
];

const bottomNavigation = [
    { name: "Orders", href: "/orders", icon: Cart },
    { name: "Riders", href: "/riders", icon: Cycling },
    { name: "Payments", href: "/payments", icon: CreditCard },
    { name: "Promotions", href: "/promotions", icon: Gift },
    { name: "Chats", href: "/chats", icon: MessageText },
    { name: "Notifications", href: "/notifications", icon: Bell },
    { name: "Analytics", href: "/analytics", icon: StatsReport },
    { name: "Settings", href: "/settings", icon: SettingsIcon },
];

export function Sidebar({ isCollapsed, onToggle }: SidebarProps) {
    const pathname = usePathname();
    const { user } = useAuth();
    const [catalogExpanded, setCatalogExpanded] = useState(true);

    // Check if any catalog item is active
    const isCatalogActive = catalogNavigation.some(item => pathname.startsWith(item.href));

    return (
        <aside
            className={cn(
                "fixed left-0 top-0 z-50 h-screen transition-all duration-300 ease-in-out",
                isCollapsed ? "w-20" : "w-64"
            )}
        >
            {/* Glassmorphism Background */}
            <div className="absolute inset-0 bg-gradient-to-b from-card/95 via-card/90 to-card/95 backdrop-blur-xl border-r border-border/50" />

            {/* Content */}
            <div className="relative h-full flex flex-col">
                {/* Logo Section */}
                <div className="flex items-center justify-between p-4 border-b border-border/50 h-20">
                    <Link
                        href="/"
                        className={cn(
                            "flex items-center gap-3 transition-all duration-300",
                            isCollapsed ? "opacity-0 invisible w-0" : "opacity-100 visible"
                        )}
                    >
                        {/* Logo Icon */}
                        <div className="w-10 h-10 rounded-md flex items-center justify-center bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 shadow-lg shadow-[#FE6132]/20">
                            <ShieldCheck className="w-6 h-6 text-white" />
                        </div>

                        {/* Logo Text */}
                        <div className="flex flex-col animate-fade-in">
                            <span className="text-lg font-bold text-foreground">
                                GrabGo
                            </span>
                            <span className="text-xs text-muted-foreground font-medium">
                                Admin Panel
                            </span>
                        </div>
                    </Link>

                    {/* Toggle Button - Dynamic Position */}
                    <button
                        onClick={onToggle}
                        className={cn(
                            "p-2 rounded-md hover:bg-accent transition-all duration-300 border border-transparent hover:border-border/50",
                            isCollapsed ? "absolute left-1/2 -translate-x-1/2" : "relative"
                        )}
                        aria-label={isCollapsed ? "Expand sidebar" : "Collapse sidebar"}
                    >
                        {isCollapsed ? (
                            <div className="flex flex-col items-center gap-1">
                                <ShieldCheck className="w-6 h-6 text-[#FE6132] mb-2" />
                                <NavArrowRight className="w-4 h-4 text-muted-foreground" />
                            </div>
                        ) : (
                            <NavArrowLeft className="w-4 h-4 text-muted-foreground" />
                        )}
                    </button>
                </div>

                {/* Navigation */}
                <nav className="flex-1 overflow-y-auto p-4 space-y-1 custom-scrollbar">
                    {/* Main Navigation */}
                    {mainNavigation.map((item, index) => {
                        const isActive = pathname === item.href;
                        const Icon = item.icon;

                        return (
                            <Link
                                key={item.name}
                                href={item.href}
                                className={cn(
                                    "flex items-center gap-3 px-3 py-2.5 rounded-md transition-all duration-200",
                                    "hover:-translate-y-0.5 group",
                                    isActive
                                        ? "bg-[#FE6132] text-white shadow-lg shadow-[#FE6132]/20"
                                        : "text-muted-foreground hover:text-foreground hover:bg-accent",
                                    isCollapsed && "justify-center px-2",
                                    "animate-fade-in-left"
                                )}
                                title={isCollapsed ? item.name : ""}
                                style={{ animationDelay: `${index * 30}ms` }}
                            >
                                <Icon className={cn("w-5 h-5 flex-shrink-0 transition-transform duration-200", !isActive && "group-hover:scale-110")} />
                                {!isCollapsed && (
                                    <span className="font-medium whitespace-nowrap">{item.name}</span>
                                )}
                            </Link>
                        );
                    })}

                    {/* Catalog Management Section */}
                    {!isCollapsed && (
                        <div className="pt-2">
                            <button
                                onClick={() => setCatalogExpanded(!catalogExpanded)}
                                className={cn(
                                    "w-full flex items-center justify-between px-3 py-2.5 rounded-md transition-all duration-200",
                                    "hover:bg-accent group",
                                    isCatalogActive ? "text-foreground" : "text-muted-foreground hover:text-foreground"
                                )}
                            >
                                <div className="flex items-center gap-3">
                                    <Database className="w-5 h-5 flex-shrink-0" />
                                    <span className="font-medium whitespace-nowrap">Catalog Management</span>
                                </div>
                                <NavArrowDown className={cn(
                                    "w-4 h-4 transition-transform duration-200",
                                    catalogExpanded && "rotate-180"
                                )} />
                            </button>

                            {/* Submenu */}
                            {catalogExpanded && (
                                <div className="ml-4 mt-1 space-y-1 border-l-2 border-border/50 pl-2">
                                    {catalogNavigation.map((item, index) => {
                                        const isActive = pathname.startsWith(item.href);
                                        const Icon = item.icon;

                                        return (
                                            <Link
                                                key={item.name}
                                                href={item.href}
                                                className={cn(
                                                    "flex items-center gap-3 px-3 py-2 rounded-md transition-all duration-200",
                                                    "hover:-translate-y-0.5 group text-sm",
                                                    isActive
                                                        ? "bg-[#FE6132] text-white shadow-lg shadow-[#FE6132]/20"
                                                        : "text-muted-foreground hover:text-foreground hover:bg-accent",
                                                    "animate-fade-in-left"
                                                )}
                                                style={{ animationDelay: `${(index + 3) * 30}ms` }}
                                            >
                                                <Icon className={cn("w-4 h-4 flex-shrink-0 transition-transform duration-200", !isActive && "group-hover:scale-110")} />
                                                <span className="font-medium whitespace-nowrap">{item.name}</span>
                                            </Link>
                                        );
                                    })}
                                </div>
                            )}
                        </div>
                    )}

                    {/* Collapsed Catalog Icon */}
                    {isCollapsed && (
                        <Link
                            href="/food-items"
                            className={cn(
                                "flex items-center justify-center px-2 py-2.5 rounded-md transition-all duration-200",
                                "hover:-translate-y-0.5 group",
                                isCatalogActive
                                    ? "bg-[#FE6132] text-white shadow-lg shadow-[#FE6132]/20"
                                    : "text-muted-foreground hover:text-foreground hover:bg-accent"
                            )}
                            title="Catalog Management"
                        >
                            <Database className={cn("w-5 h-5 flex-shrink-0 transition-transform duration-200", !isCatalogActive && "group-hover:scale-110")} />
                        </Link>
                    )}

                    {/* Bottom Navigation */}
                    <div className="pt-2 mt-2 border-t border-border/50">
                        {bottomNavigation.map((item, index) => {
                            const isActive = pathname === item.href;
                            const Icon = item.icon;

                            return (
                                <Link
                                    key={item.name}
                                    href={item.href}
                                    className={cn(
                                        "flex items-center gap-3 px-3 py-2.5 rounded-md transition-all duration-200",
                                        "hover:-translate-y-0.5 group",
                                        isActive
                                            ? "bg-[#FE6132] text-white shadow-lg shadow-[#FE6132]/20"
                                            : "text-muted-foreground hover:text-foreground hover:bg-accent",
                                        isCollapsed && "justify-center px-2",
                                        "animate-fade-in-left"
                                    )}
                                    title={isCollapsed ? item.name : ""}
                                    style={{ animationDelay: `${(index + 7) * 30}ms` }}
                                >
                                    <Icon className={cn("w-5 h-5 flex-shrink-0 transition-transform duration-200", !isActive && "group-hover:scale-110")} />
                                    {!isCollapsed && (
                                        <span className="font-medium whitespace-nowrap">{item.name}</span>
                                    )}
                                </Link>
                            );
                        })}
                    </div>
                </nav>

                {/* User Section */}
                <div className="p-4 border-t border-border/50 animate-fade-in">
                    <div className={cn(
                        "flex items-center rounded-md transition-all duration-300",
                        isCollapsed ? "justify-center p-0 bg-transparent" : "gap-3 p-3 bg-accent/50"
                    )}>
                        <div className={cn(
                            "rounded-full bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 flex items-center justify-center text-white font-semibold shadow-md transition-all duration-300",
                            isCollapsed ? "w-10 h-10 hover:scale-110 cursor-pointer" : "w-10 h-10"
                        )}>
                            {user?.username?.charAt(0).toUpperCase() || "A"}
                        </div>
                        {!isCollapsed && (
                            <div className="flex-1 min-w-0">
                                <p className="text-sm font-semibold truncate leading-none mb-1">
                                    {user?.username || "Admin User"}
                                </p>
                                <p className="text-[10px] text-muted-foreground truncate opacity-80 uppercase tracking-wider font-semibold">
                                    {user?.email || "admin@grabgo.com"}
                                </p>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </aside>
    );
}
