"use client";

import { Card } from "@grabgo/ui";
import { PharmacyCrossTag } from "iconoir-react";

export default function PharmacyItemsPage() {
    return (
        <div className="space-y-6 animate-fade-in">
            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div>
                    <h1 className="text-3xl font-bold tracking-tight">Pharmacy Items</h1>
                    <p className="text-muted-foreground mt-1">
                        Manage pharmacy items and medications
                    </p>
                </div>
            </div>

            {/* Coming Soon Card */}
            <Card className="p-12 border-border/50 text-center">
                <div className="max-w-md mx-auto space-y-4">
                    <div className="w-20 h-20 rounded-full bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center mx-auto">
                        <PharmacyCrossTag className="w-10 h-10 text-blue-600 dark:text-blue-400" />
                    </div>
                    <h3 className="text-2xl font-bold">Pharmacy Items Management</h3>
                    <p className="text-muted-foreground">
                        This section will allow you to manage pharmacy items and medications, including:
                    </p>
                    <ul className="text-sm text-muted-foreground space-y-2 text-left max-w-sm mx-auto">
                        <li className="flex items-start gap-2">
                            <span className="text-blue-600 dark:text-blue-400 mt-0.5">✓</span>
                            <span>View all pharmacy items and medications</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <span className="text-blue-600 dark:text-blue-400 mt-0.5">✓</span>
                            <span>Filter by pharmacy, category, and prescription status</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <span className="text-blue-600 dark:text-blue-400 mt-0.5">✓</span>
                            <span>Manage medication details and dosage information</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <span className="text-blue-600 dark:text-blue-400 mt-0.5">✓</span>
                            <span>Monitor stock levels and expiry dates</span>
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
