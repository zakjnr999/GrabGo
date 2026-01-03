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
import { type Vendor } from "../../../../lib/mockData";

interface SuspendVendorDialogProps {
    vendor: Vendor;
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

export function SuspendVendorDialog({
    vendor,
    open,
    onOpenChange,
}: SuspendVendorDialogProps) {
    const [isSubmitting, setIsSubmitting] = useState(false);
    const isSuspending = vendor.status !== "closed" && vendor.status !== "suspended";

    const handleSubmit = async () => {
        setIsSubmitting(true);

        // Simulate API call
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // TODO: Implement actual API call to suspend/unsuspend vendor
        console.log(`${isSuspending ? 'Suspending' : 'Unsuspending'} vendor:`, vendor.id);

        setIsSubmitting(false);
        onOpenChange(false);

        // Show success message
        alert(`Vendor ${isSuspending ? 'suspended' : 'unsuspended'} successfully!`);
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-[500px]">
                <DialogHeader>
                    <DialogTitle>
                        {isSuspending ? 'Suspend' : 'Unsuspend'} Vendor
                    </DialogTitle>
                    <DialogDescription>
                        {isSuspending
                            ? 'Suspending this vendor will temporarily disable their account. They will not be able to receive orders until unsuspended.'
                            : 'Unsuspending this vendor will restore their account access and allow them to receive orders again.'}
                    </DialogDescription>
                </DialogHeader>

                <div className="space-y-4 py-4">
                    <div className="rounded-lg border border-border/50 p-4 bg-muted/30">
                        <div className="space-y-2">
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">Vendor:</span>
                                <span className="font-medium">{vendor.name}</span>
                            </div>
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">Owner:</span>
                                <span className="font-medium">{vendor.ownerName}</span>
                            </div>
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">Type:</span>
                                <span className="font-medium capitalize">{vendor.type}</span>
                            </div>
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">Current Status:</span>
                                <span className={`font-medium ${vendor.status === 'open' ? 'text-green-600' :
                                        vendor.status === 'closed' ? 'text-gray-600' :
                                            vendor.status === 'busy' ? 'text-amber-600' :
                                                'text-red-600'
                                    }`}>
                                    {vendor.status.replace('_', ' ').toUpperCase()}
                                </span>
                            </div>
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">New Status:</span>
                                <span className={`font-medium ${isSuspending ? 'text-red-600' : 'text-green-600'}`}>
                                    {isSuspending ? 'SUSPENDED' : 'OPEN'}
                                </span>
                            </div>
                        </div>
                    </div>

                    {isSuspending && (
                        <div className="rounded-lg border border-orange-200 bg-orange-50 dark:bg-orange-950/20 p-4">
                            <p className="text-sm text-orange-800 dark:text-orange-200">
                                <strong>Warning:</strong> Suspending this vendor will:
                            </p>
                            <ul className="mt-2 text-sm text-orange-700 dark:text-orange-300 list-disc list-inside space-y-1">
                                <li>Prevent them from receiving new orders</li>
                                <li>Hide them from customer search results</li>
                                <li>Cancel any pending orders</li>
                                <li>Send a notification to the vendor</li>
                            </ul>
                        </div>
                    )}

                    {!isSuspending && (
                        <div className="rounded-lg border border-green-200 bg-green-50 dark:bg-green-950/20 p-4">
                            <p className="text-sm text-green-800 dark:text-green-200">
                                <strong>Note:</strong> Unsuspending this vendor will restore their full access and visibility on the platform.
                            </p>
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
                        className={isSuspending ? 'bg-red-600 hover:bg-red-700 text-white' : 'bg-green-600 hover:bg-green-700 text-white'}
                    >
                        {isSubmitting
                            ? `${isSuspending ? 'Suspending' : 'Unsuspending'}...`
                            : `${isSuspending ? 'Suspend' : 'Unsuspend'} Vendor`}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
