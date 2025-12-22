"use client";

import { Card } from "@grabgo/ui";
import { Leaf } from "iconoir-react";

export default function GroceryItemsPage() {
    return (
        <div className="space-y-6 animate-fade-in">
            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div>
                    <h1 className="text-3xl font-bold tracking-tight">Grocery Items</h1>
                    <p className="text-muted-foreground mt-1">
                        Manage grocery items across all stores
                    </p>
                </div>
            </div>

            {/* Coming Soon Card */}
            <Card className="p-12 border-border/50 text-center">
                <div className="max-w-md mx-auto space-y-4">
                    <div className="w-20 h-20 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center mx-auto">
                        <Leaf className="w-10 h-10 text-green-600 dark:text-green-400" />
                    </div>
                    <h3 className="text-2xl font-bold">Grocery Items Management</h3>
                    <p className="text-muted-foreground">
                        This section will allow you to manage grocery items from all stores, including:
                    </p>
                    <ul className="text-sm text-muted-foreground space-y-2 text-left max-w-sm mx-auto">
                        <li className="flex items-start gap-2">
                            <span className="text-green-600 dark:text-green-400 mt-0.5">✓</span>
                            <span>View all grocery items across stores</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <span className="text-green-600 dark:text-green-400 mt-0.5">✓</span>
                            <span>Filter by store, category, and availability</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <span className="text-green-600 dark:text-green-400 mt-0.5">✓</span>
                            <span>Update pricing and stock status</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <span className="text-green-600 dark:text-green-400 mt-0.5">✓</span>
                            <span>Manage grocery categories</span>
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
