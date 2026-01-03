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
import { Button, Label, Input } from "@grabgo/ui";
import { WarningCircle, CreditCard } from "iconoir-react";

interface ProcessRefundDialogProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    onRefund: (amount: number, reason: string) => void;
    orderNumber: string;
    totalAmount: number;
    paymentMethod: string;
}

const refundReasons = [
    "Customer requested refund",
    "Order cancelled by vendor",
    "Order cancelled by admin",
    "Payment error",
    "Duplicate charge",
    "Service not delivered",
    "Quality issues",
    "Other"
];

export function ProcessRefundDialog({
    open,
    onOpenChange,
    onRefund,
    orderNumber,
    totalAmount,
    paymentMethod
}: ProcessRefundDialogProps) {
    const [refundType, setRefundType] = useState<'full' | 'partial'>('full');
    const [refundAmount, setRefundAmount] = useState(totalAmount.toString());
    const [selectedReason, setSelectedReason] = useState<string>("");
    const [customReason, setCustomReason] = useState("");
    const [isProcessing, setIsProcessing] = useState(false);

    const handleRefund = async () => {
        const reason = selectedReason === "Other" ? customReason : selectedReason;
        if (!reason) return;

        const amount = refundType === 'full' ? totalAmount : parseFloat(refundAmount);
        if (isNaN(amount) || amount <= 0 || amount > totalAmount) return;

        setIsProcessing(true);
        // Simulate API call
        await new Promise(resolve => setTimeout(resolve, 1500));

        onRefund(amount, reason);
        setIsProcessing(false);
        setRefundType('full');
        setRefundAmount(totalAmount.toString());
        setSelectedReason("");
        setCustomReason("");
        onOpenChange(false);
    };

    const isValid = selectedReason && (selectedReason !== "Other" || customReason.trim().length > 0) &&
        (refundType === 'full' || (parseFloat(refundAmount) > 0 && parseFloat(refundAmount) <= totalAmount));

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="max-w-md">
                <DialogHeader>
                    <div className="flex items-center gap-3">
                        <div className="p-2 rounded-full bg-orange-100">
                            <CreditCard className="w-6 h-6 text-orange-600" />
                        </div>
                        <div>
                            <DialogTitle>Process Refund</DialogTitle>
                            <DialogDescription>
                                Order #{orderNumber}
                            </DialogDescription>
                        </div>
                    </div>
                </DialogHeader>

                <div className="space-y-4">
                    <div className="p-4 rounded-lg bg-orange-50 border border-orange-200">
                        <p className="text-sm text-orange-800">
                            <strong>Payment Method:</strong> {paymentMethod.replace('_', ' ').toUpperCase()}
                        </p>
                        <p className="text-sm text-orange-800 mt-1">
                            <strong>Total Amount:</strong> GH₵ {totalAmount.toFixed(2)}
                        </p>
                    </div>

                    <div className="space-y-2">
                        <Label>Refund Type</Label>
                        <div className="flex gap-2">
                            <button
                                onClick={() => {
                                    setRefundType('full');
                                    setRefundAmount(totalAmount.toString());
                                }}
                                className={`flex-1 p-3 rounded-lg border-2 transition-all ${refundType === 'full'
                                        ? 'border-[#FE6132] bg-[#FE6132]/5'
                                        : 'border-border hover:border-[#FE6132]/50'
                                    }`}
                            >
                                <p className="font-semibold">Full Refund</p>
                                <p className="text-sm text-muted-foreground">GH₵ {totalAmount.toFixed(2)}</p>
                            </button>
                            <button
                                onClick={() => setRefundType('partial')}
                                className={`flex-1 p-3 rounded-lg border-2 transition-all ${refundType === 'partial'
                                        ? 'border-[#FE6132] bg-[#FE6132]/5'
                                        : 'border-border hover:border-[#FE6132]/50'
                                    }`}
                            >
                                <p className="font-semibold">Partial Refund</p>
                                <p className="text-sm text-muted-foreground">Custom amount</p>
                            </button>
                        </div>
                    </div>

                    {refundType === 'partial' && (
                        <div className="space-y-2">
                            <Label htmlFor="refundAmount">Refund Amount (GH₵) *</Label>
                            <Input
                                id="refundAmount"
                                type="number"
                                step="0.01"
                                min="0"
                                max={totalAmount}
                                value={refundAmount}
                                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setRefundAmount(e.target.value)}
                                placeholder="Enter refund amount"
                            />
                            {parseFloat(refundAmount) > totalAmount && (
                                <p className="text-sm text-red-600">Amount cannot exceed total order amount</p>
                            )}
                        </div>
                    )}

                    <div className="space-y-2">
                        <Label>Refund Reason *</Label>
                        <div className="space-y-2 max-h-48 overflow-y-auto">
                            {refundReasons.map((reason) => (
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
                                placeholder="Enter the refund reason..."
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
                            setRefundType('full');
                            setRefundAmount(totalAmount.toString());
                            setSelectedReason("");
                            setCustomReason("");
                            onOpenChange(false);
                        }}
                        disabled={isProcessing}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={handleRefund}
                        disabled={!isValid || isProcessing}
                        className="bg-orange-600 hover:bg-orange-700 text-white"
                    >
                        {isProcessing ? 'Processing...' : `Refund GH₵ ${refundType === 'full' ? totalAmount.toFixed(2) : (parseFloat(refundAmount) || 0).toFixed(2)}`}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
