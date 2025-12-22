"use client";

import { useState } from "react";
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@grabgo/ui";
import { Button } from "@grabgo/ui";
import { type Customer } from "../../../../lib/mockData";

interface ToggleAccountStatusDialogProps {
    customer: Customer;
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

export function ToggleAccountStatusDialog({
    customer,
    open,
    onOpenChange,
}: ToggleAccountStatusDialogProps) {
    const [isSubmitting, setIsSubmitting] = useState(false);
    const isActivating = !customer.isActive;

    const handleSubmit = async () => {
        setIsSubmitting(true);

        // Simulate API call
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // TODO: Implement actual API call to toggle account status
        console.log(`${isActivating ? 'Activating' : 'Deactivating'} account for customer:`, customer.id);

        setIsSubmitting(false);
        onOpenChange(false);

        // Show success message (you can use a toast notification here)
        alert(`Customer account ${isActivating ? 'activated' : 'deactivated'} successfully!`);
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-[500px]">
                <DialogHeader>
                    <DialogTitle>
                        {isActivating ? 'Activate' : 'Deactivate'} Account
                    </DialogTitle>
                    <DialogDescription>
                        {isActivating
                            ? 'Are you sure you want to activate this customer account? The customer will regain access to the platform.'
                            : 'Are you sure you want to deactivate this customer account? The customer will lose access to the platform until reactivated.'}
                    </DialogDescription>
                </DialogHeader>

                <div className="space-y-4 py-4">
                    <div className="rounded-lg border border-border/50 p-4 bg-muted/30">
                        <div className="space-y-2">
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">Customer:</span>
                                <span className="font-medium">{customer.username}</span>
                            </div>
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">Email:</span>
                                <span className="font-medium">{customer.email}</span>
                            </div>
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">Current Status:</span>
                                <span className={`font-medium ${customer.isActive ? 'text-green-600' : 'text-red-600'}`}>
                                    {customer.isActive ? 'Active' : 'Inactive'}
                                </span>
                            </div>
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">New Status:</span>
                                <span className={`font-medium ${isActivating ? 'text-green-600' : 'text-red-600'}`}>
                                    {isActivating ? 'Active' : 'Inactive'}
                                </span>
                            </div>
                        </div>
                    </div>

                    {!isActivating && (
                        <div className="rounded-lg border border-orange-200 bg-orange-50 p-4">
                            <p className="text-sm text-orange-800">
                                <strong>Warning:</strong> Deactivating this account will:
                            </p>
                            <ul className="mt-2 text-sm text-orange-700 list-disc list-inside space-y-1">
                                <li>Prevent the customer from logging in</li>
                                <li>Cancel any pending orders</li>
                                <li>Disable all notifications</li>
                            </ul>
                        </div>
                    )}
                </div>

                <DialogFooter>
                    <Button
                        variant="outline"
                        onClick={() => onOpenChange(false)}
                        disabled={isSubmitting}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={handleSubmit}
                        disabled={isSubmitting}
                        className={isActivating ? 'bg-green-600 hover:bg-green-700' : 'bg-red-600 hover:bg-red-700'}
                    >
                        {isSubmitting
                            ? `${isActivating ? 'Activating' : 'Deactivating'}...`
                            : `${isActivating ? 'Activate' : 'Deactivate'} Account`}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
