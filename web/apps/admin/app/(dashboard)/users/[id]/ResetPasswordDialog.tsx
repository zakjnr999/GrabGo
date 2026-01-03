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

interface ResetPasswordDialogProps {
    customer: Customer;
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

export function ResetPasswordDialog({
    customer,
    open,
    onOpenChange,
}: ResetPasswordDialogProps) {
    const [isSubmitting, setIsSubmitting] = useState(false);

    const handleReset = async () => {
        setIsSubmitting(true);

        // Simulate API call
        await new Promise((resolve) => setTimeout(resolve, 1000));

        console.log("Password reset for customer:", customer.id);

        setIsSubmitting(false);
        onOpenChange(false);

        // TODO: Show success toast
        alert(`Password reset email sent to ${customer.email}`);
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-[425px]">
                <DialogHeader>
                    <DialogTitle>Reset Password</DialogTitle>
                    <DialogDescription>
                        Are you sure you want to reset the password for this customer?
                    </DialogDescription>
                </DialogHeader>

                <div className="py-4 space-y-4">
                    <div
                        className="rounded-md p-4 animate-fade-in"
                        style={{
                            backgroundColor: 'rgba(254, 242, 242, 1)',
                            border: '1px solid rgba(254, 226, 226, 1)'
                        }}
                    >
                        <div className="flex items-start gap-3">
                            <div className="flex-shrink-0">
                                <svg className="w-5 h-5 mt-0.5" style={{ color: '#f87171' }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                </svg>
                            </div>
                            <div className="flex-1">
                                <h3 className="text-sm font-semibold" style={{ color: '#dc2626' }}>
                                    Warning
                                </h3>
                                <p className="mt-1 text-sm" style={{ color: '#ef4444' }}>
                                    A password reset email will be sent to{" "}
                                    <span className="font-semibold">{customer.email}</span>. The customer will
                                    need to follow the link in the email to set a new password.
                                </p>
                            </div>
                        </div>
                    </div>

                    <div className="space-y-2">
                        <p className="text-sm font-medium">Customer Details:</p>
                        <div className="text-sm text-muted-foreground space-y-1">
                            <p>Name: {customer.username}</p>
                            <p>Email: {customer.email}</p>
                            <p>ID: {customer.id}</p>
                        </div>
                    </div>
                </div>

                <DialogFooter>
                    <Button
                        type="button"
                        variant="outline"
                        onClick={() => onOpenChange(false)}
                        disabled={isSubmitting}
                    >
                        Cancel
                    </Button>
                    <Button
                        type="button"
                        variant="destructive"
                        onClick={handleReset}
                        disabled={isSubmitting}
                    >
                        {isSubmitting ? "Sending..." : "Reset Password"}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
