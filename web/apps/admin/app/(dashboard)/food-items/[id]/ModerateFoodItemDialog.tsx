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
import { CheckCircle, Xmark, WarningCircle } from "iconoir-react";

interface ModerateFoodItemDialogProps {
    foodItem: {
        id: string;
        name: string;
        moderationStatus: "approved" | "pending" | "rejected";
        moderationReason?: string;
    };
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

export function ModerateFoodItemDialog({
    foodItem,
    open,
    onOpenChange,
}: ModerateFoodItemDialogProps) {
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [rejectionReason, setRejectionReason] = useState("");
    const [showRejectionInput, setShowRejectionInput] = useState(false);

    const handleAction = async (status: "approved" | "rejected") => {
        if (status === "rejected" && !rejectionReason && showRejectionInput) {
            alert("Please provide a reason for rejection.");
            return;
        }

        setIsSubmitting(true);
        // Simulate API call
        await new Promise((resolve) => setTimeout(resolve, 1000));

        console.log(`Food item ${status}:`, { id: foodItem.id, status, reason: rejectionReason });

        setIsSubmitting(false);
        onOpenChange(false);
        alert(`Food item has been ${status}.`);
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-[500px]">
                <DialogHeader>
                    <DialogTitle>Moderate Food Item</DialogTitle>
                    <DialogDescription>
                        Review the food item details and image for compliance with platform standards.
                    </DialogDescription>
                </DialogHeader>

                <div className="space-y-6 py-4">
                    <div className="p-4 rounded-lg bg-muted/50 space-y-2">
                        <p className="text-sm font-semibold">Item: {foodItem.name}</p>
                        <p className="text-xs text-muted-foreground italic">
                            Current Status: <span className="capitalize font-medium">{foodItem.moderationStatus}</span>
                        </p>
                    </div>

                    {!showRejectionInput ? (
                        <div className="grid grid-cols-2 gap-4">
                            <Button
                                onClick={() => handleAction("approved")}
                                className="h-24 flex-col gap-2 bg-green-50 text-green-700 border-green-200 hover:bg-green-100 hover:text-green-800"
                                variant="outline"
                                disabled={isSubmitting}
                            >
                                <CheckCircle className="w-8 h-8" />
                                <span>Approve Item</span>
                            </Button>
                            <Button
                                onClick={() => setShowRejectionInput(true)}
                                className="h-24 flex-col gap-2 bg-red-50 text-red-700 border-red-200 hover:bg-red-100 hover:text-red-800"
                                variant="outline"
                                disabled={isSubmitting}
                            >
                                <Xmark className="w-8 h-8" />
                                <span>Reject Item</span>
                            </Button>
                        </div>
                    ) : (
                        <div className="space-y-4 animate-fade-in">
                            <div className="space-y-2">
                                <Label htmlFor="reason">Rejection Reason</Label>
                                <textarea
                                    id="reason"
                                    value={rejectionReason}
                                    onChange={(e) => setRejectionReason(e.target.value)}
                                    placeholder="e.g., Low quality image, inappropriate description, etc."
                                    className="flex min-h-[100px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                                />
                            </div>
                            <div className="flex gap-2">
                                <Button
                                    variant="outline"
                                    className="flex-1"
                                    onClick={() => setShowRejectionInput(false)}
                                    disabled={isSubmitting}
                                >
                                    Go Back
                                </Button>
                                <Button
                                    className="flex-1 bg-red-600 text-white hover:bg-red-700"
                                    onClick={() => handleAction("rejected")}
                                    disabled={isSubmitting}
                                >
                                    Confirm Rejection
                                </Button>
                            </div>
                        </div>
                    )}

                    <div className="flex items-start gap-2 text-xs text-muted-foreground bg-amber-50 dark:bg-amber-950/20 p-3 rounded-md border border-amber-200 dark:border-amber-900">
                        <WarningCircle className="w-4 h-4 text-amber-600 mt-0.5" />
                        <p>
                            Approving this item will make it visible to customers in the app.
                            Rejecting it will notify the vendor and prompt them to make changes.
                        </p>
                    </div>
                </div>

                {!showRejectionInput && (
                    <DialogFooter>
                        <Button variant="ghost" onClick={() => onOpenChange(false)}>
                            Cancel
                        </Button>
                    </DialogFooter>
                )}
            </DialogContent>
        </Dialog>
    );
}
