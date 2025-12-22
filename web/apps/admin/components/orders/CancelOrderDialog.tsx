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
import { Button, Label } from "@grabgo/ui";
import { WarningCircle } from "iconoir-react";

interface CancelOrderDialogProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    onCancel: (reason: string) => void;
    orderNumber: string;
}

const cancellationReasons = [
    "Customer requested cancellation",
    "Vendor unable to fulfill order",
    "Rider unavailable",
    "Payment failed",
    "Duplicate order",
    "Out of stock items",
    "Delivery address unreachable",
    "Other"
];

export function CancelOrderDialog({ open, onOpenChange, onCancel, orderNumber }: CancelOrderDialogProps) {
    const [selectedReason, setSelectedReason] = useState<string>("");
    const [customReason, setCustomReason] = useState("");
    const [isCancelling, setIsCancelling] = useState(false);

    const handleCancel = async () => {
        const reason = selectedReason === "Other" ? customReason : selectedReason;
        if (!reason) return;

        setIsCancelling(true);
        // Simulate API call
        await new Promise(resolve => setTimeout(resolve, 1000));

        onCancel(reason);
        setIsCancelling(false);
        setSelectedReason("");
        setCustomReason("");
        onOpenChange(false);
    };

    const isValid = selectedReason && (selectedReason !== "Other" || customReason.trim().length > 0);

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="max-w-md">
                <DialogHeader>
                    <div className="flex items-center gap-3">
                        <div className="p-2 rounded-full bg-red-100">
                            <WarningCircle className="w-6 h-6 text-red-600" />
                        </div>
                        <div>
                            <DialogTitle>Cancel Order</DialogTitle>
                            <DialogDescription>
                                Order #{orderNumber}
                            </DialogDescription>
                        </div>
                    </div>
                </DialogHeader>

                <div className="space-y-4">
                    <div className="p-4 rounded-lg bg-red-50 border border-red-200">
                        <p className="text-sm text-red-800">
                            <strong>Warning:</strong> This action cannot be undone. The customer will be notified of the cancellation.
                        </p>
                    </div>

                    <div className="space-y-2">
                        <Label>Cancellation Reason *</Label>
                        <div className="space-y-2">
                            {cancellationReasons.map((reason) => (
                                <label
                                    key={reason}
                                    className="flex items-center gap-3 p-3 rounded-lg border-2 cursor-pointer transition-all hover:bg-accent/50"
                                    style={{
                                        borderColor: selectedReason === reason ? '#FE6132' : 'transparent',
                                        backgroundColor: selectedReason === reason ? 'rgba(254, 97, 50, 0.05)' : 'transparent'
                                    }}
                                >
                                    <input
                                        type="radio"
                                        name="reason"
                                        value={reason}
                                        checked={selectedReason === reason}
                                        onChange={(e) => setSelectedReason(e.target.value)}
                                        className="w-4 h-4 text-[#FE6132] focus:ring-[#FE6132]"
                                    />
                                    <span className="text-sm">{reason}</span>
                                </label>
                            ))}
                        </div>
                    </div>

                    {selectedReason === "Other" && (
                        <div className="space-y-2">
                            <Label htmlFor="customReason">Please specify the reason *</Label>
                            <textarea
                                id="customReason"
                                placeholder="Enter the cancellation reason..."
                                value={customReason}
                                onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setCustomReason(e.target.value)}
                                rows={3}
                                className="w-full px-3 py-2 text-sm rounded-md border border-border bg-background focus:outline-none focus:ring-2 focus:ring-[#FE6132]/20"
                            />
                        </div>
                    )}
                </div>

                <DialogFooter>
                    <Button
                        variant="outline"
                        onClick={() => {
                            setSelectedReason("");
                            setCustomReason("");
                            onOpenChange(false);
                        }}
                        disabled={isCancelling}
                    >
                        Keep Order
                    </Button>
                    <Button
                        onClick={handleCancel}
                        disabled={!isValid || isCancelling}
                        className="bg-red-600 hover:bg-red-700 text-white"
                    >
                        {isCancelling ? 'Cancelling...' : 'Cancel Order'}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
