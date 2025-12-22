"use client";

import { useState } from "react";
import { useAuth } from "../../context/AuthContext";
import { Input } from "../ui/input";
import { Button } from "../ui/button";
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from "../ui/dropdown-menu";
import { Search, Bell, User, LogOut, Settings as SettingsIcon } from "iconoir-react";

interface HeaderProps {
    isCollapsed: boolean;
}

export function Header({ isCollapsed }: HeaderProps) {
    const { user, logout } = useAuth();
    const [searchQuery, setSearchQuery] = useState("");

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
                    {/* Notifications */}
                    <Button
                        variant="ghost"
                        size="icon"
                        className="relative hover:bg-accent transition-all duration-300 border border-transparent hover:border-border/50"
                    >
                        <Bell className="w-5 h-5" />
                        {/* Notification Badge */}
                        <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-[#FE6132] rounded-full animate-pulse" />
                    </Button>

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
