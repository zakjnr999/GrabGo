"use client";

import { Card } from "@grabgo/ui";
import { Gift } from "iconoir-react";

export default function MarketItemsPage() {
    return (
        <div className="space-y-6 animate-fade-in">
            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div>
                    <h1 className="text-3xl font-bold tracking-tight">Market Items</h1>
                    <p className="text-muted-foreground mt-1">
                        Manage market items and products
                    </p>
                </div>
            </div>

            {/* Coming Soon Card */}
            <Card className="p-12 border-border/50 text-center">
                <div className="max-w-md mx-auto space-y-4">
                    <div className="w-20 h-20 rounded-full bg-purple-100 dark:bg-purple-900/30 flex items-center justify-center mx-auto">
                        <Gift className="w-10 h-10 text-purple-600 dark:text-purple-400" />
                    </div>
                    <h3 className="text-2xl font-bold">Market Items Management</h3>
                    <p className="text-muted-foreground">
                        This section will allow you to manage market items and products, including:
                    </p>
                    <ul className="text-sm text-muted-foreground space-y-2 text-left max-w-sm mx-auto">
                        <li className="flex items-start gap-2">
                            <span className="text-purple-600 dark:text-purple-400 mt-0.5">✓</span>
                            <span>View all market items across vendors</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <span className="text-purple-600 dark:text-purple-400 mt-0.5">✓</span>
                            <span>Filter by market, category, and availability</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <span className="text-purple-600 dark:text-purple-400 mt-0.5">✓</span>
                            <span>Update pricing and stock information</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <span className="text-purple-600 dark:text-purple-400 mt-0.5">✓</span>
                            <span>Manage product categories and tags</span>
                        </li>
                    </ul>
                    <div className="pt-4">
                        <span className="inline-block px-4 py-2 bg-muted rounded-full text-sm font-medium">
                            Coming Soon
                        </span>
                    </div>
                </div>
            </Card>
        </div>
    );
}
