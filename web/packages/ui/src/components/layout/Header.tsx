"use client";

import { useState, useEffect } from "react";
import { useTheme } from "next-themes";
import { useAuth } from "../../context/AuthContext";
import { Input } from "../ui/input";
import { Button } from "../ui/button";
import { Badge } from "../ui/badge";
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from "../ui/dropdown-menu";
import { Search, Bell, User, LogOut, Settings as SettingsIcon, Check, InfoCircle, UserPlus, Cart, SunLight, HalfMoon } from "iconoir-react";

interface Notification {
    id: string;
    title: string;
    description: string;
    time: string;
    type: "order" | "user" | "system";
    unread: boolean;
}

const mockNotifications: Notification[] = [
    {
        id: "1",
        title: "New Order Received",
        description: "Order #GG-8842 from John Doe is pending confirmation.",
        time: "2 mins ago",
        type: "order",
        unread: true,
    },
    {
        id: "2",
        title: "New Vendor Application",
        description: "Green Valley Grocery has applied as a vendor.",
        time: "15 mins ago",
        type: "user",
        unread: true,
    },
    {
        id: "3",
        title: "System Update",
        description: "Scheduled maintenance tonight at 12:00 AM UTC.",
        time: "1 hour ago",
        type: "system",
        unread: false,
    },
    {
        id: "4",
        title: "Order Delivered",
        description: "Order #GG-8835 was successfully delivered to Osu.",
        time: "3 hours ago",
        type: "order",
        unread: false,
    },
];

interface HeaderProps {
    isCollapsed: boolean;
}

export function Header({ isCollapsed }: HeaderProps) {
    const { user, logout } = useAuth();
    const { theme, setTheme } = useTheme();
    const [mounted, setMounted] = useState(false);
    const [searchQuery, setSearchQuery] = useState("");
    const [notifications, setNotifications] = useState<Notification[]>(mockNotifications);

    // Initial mounting to avoid hydration mismatch
    useEffect(() => {
        setMounted(true);
    }, []);

    const markAsRead = (id: string) => {
        setNotifications(notifications.map(n =>
            n.id === id ? { ...n, unread: false } : n
        ));
    };

    const markAllAsRead = () => {
        setNotifications(notifications.map(n => ({ ...n, unread: false })));
    };

    return (
        <header className="sticky top-0 z-30 border-b border-border/50 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
            <div className="flex h-16 items-center justify-between gap-4 px-6">
                {/* Search Bar */}
                <div className="flex-1 max-w-md">
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                        <Input
                            type="search"
                            placeholder="Search orders, users, restaurants..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="pl-10 bg-accent/50 border-border/50 focus:bg-background transition-colors"
                        />
                    </div>
                </div>

                {/* Right Section */}
                <div className="flex items-center gap-2">
                    {/* Theme Toggle */}
                    <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
                        className="hover:bg-accent transition-all duration-300 border border-transparent hover:border-border/50"
                    >
                        {!mounted ? (
                            <SunLight className="w-5 h-5 text-muted-foreground animate-pulse" />
                        ) : theme === "dark" ? (
                            <SunLight className="w-5 h-5 text-orange-400" />
                        ) : (
                            <HalfMoon className="w-5 h-5 text-muted-foreground" />
                        )}
                    </Button>

                    {/* Notifications */}
                    <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                            <Button
                                variant="ghost"
                                size="icon"
                                className="relative hover:bg-accent transition-all duration-300 border border-transparent hover:border-border/50"
                            >
                                <Bell className="w-5 h-5" />
                                {/* Notification Badge */}
                                {notifications.some(n => n.unread) && (
                                    <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-[#FE6132] rounded-full animate-pulse" />
                                )}
                            </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="w-[380px] p-0 overflow-hidden backdrop-blur-xl bg-background/95 border-border/50 shadow-2xl animate-in fade-in zoom-in-95 duration-200">
                            <div className="flex items-center justify-between p-4 border-b border-border/50 bg-accent/30">
                                <div className="flex items-center gap-2">
                                    <DropdownMenuLabel className="p-0 text-base font-bold">Notifications</DropdownMenuLabel>
                                    {notifications.filter(n => n.unread).length > 0 && (
                                        <Badge className="bg-[#FE6132] text-white hover:bg-[#FE6132] border-0 text-[10px] h-4 min-w-[20px] flex items-center justify-center px-1">
                                            {notifications.filter(n => n.unread).length}
                                        </Badge>
                                    )}
                                </div>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="h-8 text-[11px] font-bold text-[#FE6132] hover:text-[#FE6132] hover:bg-[#FE6132]/10 rounded-full"
                                    onClick={markAllAsRead}
                                >
                                    Mark all as read
                                </Button>
                            </div>
                            <div className="max-h-[400px] overflow-y-auto overflow-x-hidden custom-scrollbar">
                                {notifications.length > 0 ? (
                                    notifications.map((notification, idx) => (
                                        <DropdownMenuItem
                                            key={notification.id}
                                            className={`flex flex-col items-start p-4 cursor-pointer border-b border-border/40 last:border-0 hover:bg-accent/50 focus:bg-accent transition-colors relative group ${notification.unread ? 'bg-[#FE6132]/5' : ''}`}
                                            onClick={() => markAsRead(notification.id)}
                                        >
                                            <div className="flex gap-4 w-full">
                                                <div className={`mt-1 flex-shrink-0 w-9 h-9 rounded-xl flex items-center justify-center ${notification.type === 'order' ? 'bg-orange-100 text-[#FE6132]' :
                                                    notification.type === 'user' ? 'bg-blue-100 text-blue-600' :
                                                        'bg-purple-100 text-purple-600'
                                                    }`}>
                                                    {notification.type === 'order' ? <Cart className="w-5 h-5" /> :
                                                        notification.type === 'user' ? <UserPlus className="w-5 h-5" /> :
                                                            <InfoCircle className="w-5 h-5" />}
                                                </div>
                                                <div className="flex-1 space-y-1">
                                                    <div className="flex items-center justify-between gap-2">
                                                        <p className={`text-sm font-bold leading-none ${notification.unread ? 'text-foreground' : 'text-muted-foreground'}`}>
                                                            {notification.title}
                                                        </p>
                                                        <span className="text-[10px] font-medium text-muted-foreground whitespace-nowrap">
                                                            {notification.time}
                                                        </span>
                                                    </div>
                                                    <p className="text-xs text-muted-foreground leading-relaxed line-clamp-2 pr-4">
                                                        {notification.description}
                                                    </p>
                                                </div>
                                            </div>
                                            {notification.unread && (
                                                <div className="absolute top-1/2 -translate-y-1/2 right-3 w-1.5 h-1.5 bg-[#FE6132] rounded-full" />
                                            )}
                                        </DropdownMenuItem>
                                    ))
                                ) : (
                                    <div className="p-8 text-center bg-accent/5">
                                        <Bell className="w-10 h-10 text-muted-foreground/20 mx-auto mb-3" />
                                        <p className="text-sm font-semibold text-muted-foreground">All caught up!</p>
                                        <p className="text-xs text-muted-foreground/60 mt-1">Check back later for new alerts.</p>
                                    </div>
                                )}
                            </div>
                            <div className="p-3 border-t border-border/50 bg-accent/20">
                                <Button className="w-full h-9 rounded-xl text-xs font-bold bg-[#FE6132] hover:bg-[#FE6132]/90 text-white shadow-lg shadow-orange-100 dark:shadow-none transition-all hover:scale-[1.02] active:scale-95">
                                    See all notifications
                                </Button>
                            </div>
                        </DropdownMenuContent>
                    </DropdownMenu>

                    {/* User Menu */}
                    <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                            <Button
                                variant="ghost"
                                className="flex items-center gap-2 hover:bg-accent transition-all duration-300 border border-transparent hover:border-border/50 focus:border-transparent active:border-transparent data-[state=open]:border-transparent data-[state=closed]:border-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
                            >
                                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 flex items-center justify-center text-white font-semibold text-sm">
                                    {user?.username?.charAt(0).toUpperCase() || "A"}
                                </div>
                                <div className="hidden md:flex flex-col items-start">
                                    <span className="text-sm font-medium">
                                        {user?.username || "Admin"}
                                    </span>
                                    <span className="text-xs text-muted-foreground">
                                        {user?.role || "Administrator"}
                                    </span>
                                </div>
                            </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="w-56">
                            <DropdownMenuLabel>
                                <div className="flex flex-col space-y-1">
                                    <p className="text-sm font-medium">
                                        {user?.username || "Admin User"}
                                    </p>
                                    <p className="text-xs text-muted-foreground">
                                        {user?.email || "admin@grabgo.com"}
                                    </p>
                                </div>
                            </DropdownMenuLabel>
                            <DropdownMenuSeparator />
                            <DropdownMenuItem>
                                <User className="mr-2 h-4 w-4" />
                                <span>Profile</span>
                            </DropdownMenuItem>
                            <DropdownMenuItem>
                                <SettingsIcon className="mr-2 h-4 w-4" />
                                <span>Settings</span>
                            </DropdownMenuItem>
                            <DropdownMenuSeparator />
                            <DropdownMenuItem
                                onClick={logout}
                                className="text-red-600 focus:text-red-600"
                            >
                                <LogOut className="mr-2 h-4 w-4" />
                                <span>Log out</span>
                            </DropdownMenuItem>
                        </DropdownMenuContent>
                    </DropdownMenu>
                </div>
            </div>
        </header>
    );
}
