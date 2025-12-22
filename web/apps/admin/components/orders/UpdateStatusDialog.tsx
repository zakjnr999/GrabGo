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
import { OrderStatus } from "../../lib/mockOrderData";
import { CheckCircle, Clock, Package, Cycling } from "iconoir-react";

interface UpdateStatusDialogProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    currentStatus: OrderStatus;
    onUpdate: (newStatus: OrderStatus, note?: string) => void;
}

const statusProgression: Record<OrderStatus, OrderStatus[]> = {
    pending: ['confirmed', 'cancelled'],
    confirmed: ['preparing', 'cancelled'],
    preparing: ['ready', 'cancelled'],
    ready: ['picked_up', 'cancelled'],
    picked_up: ['on_the_way'],
    on_the_way: ['delivered'],
    delivered: [],
    cancelled: []
};

const statusLabels: Record<OrderStatus, string> = {
    pending: 'Pending',
    confirmed: 'Confirmed',
    preparing: 'Preparing',
    ready: 'Ready for Pickup',
    picked_up: 'Picked Up',
    on_the_way: 'On The Way',
    delivered: 'Delivered',
    cancelled: 'Cancelled'
};

const statusDescriptions: Record<OrderStatus, string> = {
    pending: 'Order is awaiting confirmation',
    confirmed: 'Vendor has confirmed the order',
    preparing: 'Vendor is preparing the order',
    ready: 'Order is ready for rider pickup',
    picked_up: 'Rider has collected the order',
    on_the_way: 'Rider is delivering to customer',
    delivered: 'Order successfully delivered',
    cancelled: 'Order has been cancelled'
};

const statusIcons: Record<OrderStatus, React.ReactElement> = {
    pending: <Clock className="w-5 h-5" />,
    confirmed: <CheckCircle className="w-5 h-5" />,
    preparing: <Package className="w-5 h-5" />,
    ready: <CheckCircle className="w-5 h-5" />,
    picked_up: <Cycling className="w-5 h-5" />,
    on_the_way: <Cycling className="w-5 h-5" />,
    delivered: <CheckCircle className="w-5 h-5" />,
    cancelled: <CheckCircle className="w-5 h-5" />
};

export function UpdateStatusDialog({ open, onOpenChange, currentStatus, onUpdate }: UpdateStatusDialogProps) {
    const [selectedStatus, setSelectedStatus] = useState<OrderStatus | null>(null);
    const [note, setNote] = useState("");
    const [isUpdating, setIsUpdating] = useState(false);

    const availableStatuses = statusProgression[currentStatus] || [];

    const handleUpdate = async () => {
        if (!selectedStatus) return;

        setIsUpdating(true);
        // Simulate API call
        await new Promise(resolve => setTimeout(resolve, 1000));

        onUpdate(selectedStatus, note || undefined);
        setIsUpdating(false);
        setSelectedStatus(null);
        setNote("");
        onOpenChange(false);
    };

    const getStatusColor = (status: OrderStatus) => {
        const colors: Record<OrderStatus, string> = {
            pending: 'border-yellow-300 bg-yellow-50 hover:bg-yellow-100',
            confirmed: 'border-blue-300 bg-blue-50 hover:bg-blue-100',
            preparing: 'border-purple-300 bg-purple-50 hover:bg-purple-100',
            ready: 'border-indigo-300 bg-indigo-50 hover:bg-indigo-100',
            picked_up: 'border-cyan-300 bg-cyan-50 hover:bg-cyan-100',
            on_the_way: 'border-orange-300 bg-orange-50 hover:bg-orange-100',
            delivered: 'border-green-300 bg-green-50 hover:bg-green-100',
            cancelled: 'border-red-300 bg-red-50 hover:bg-red-100'
        };
        return colors[status];
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="max-w-md">
                <DialogHeader>
                    <DialogTitle>Update Order Status</DialogTitle>
                    <DialogDescription>
                        Current status: <span className="font-semibold capitalize">{statusLabels[currentStatus]}</span>
                    </DialogDescription>
                </DialogHeader>

                <div className="space-y-4">
                    {availableStatuses.length === 0 ? (
                        <div className="text-center py-8 text-muted-foreground">
                            No status updates available for {statusLabels[currentStatus].toLowerCase()} orders
                        </div>
                    ) : (
                        <>
                            <div className="space-y-2">
                                <Label>Select New Status</Label>
                                {availableStatuses.map((status) => (
                                    <button
                                        key={status}
                                        onClick={() => setSelectedStatus(status)}
                                        className={`w-full p-4 rounded-lg border-2 transition-all text-left ${selectedStatus === status
                                            ? 'border-[#FE6132] bg-[#FE6132]/5'
                                            : `${getStatusColor(status)} border-transparent`
                                            }`}
                                    >
                                        <div className="flex items-start gap-3">
                                            <div className={`p-2 rounded-full ${selectedStatus === status ? 'bg-[#FE6132]/10 text-[#FE6132]' : 'bg-white/50'
                                                }`}>
                                                {statusIcons[status]}
                                            </div>
                                            <div className="flex-1">
                                                <h4 className="font-semibold capitalize mb-1">
                                                    {statusLabels[status]}
                                                </h4>
                                                <p className="text-sm text-muted-foreground">
                                                    {statusDescriptions[status]}
                                                </p>
                                            </div>
                                        </div>
                                    </button>
                                ))}
                            </div>

                            <div className="space-y-2">
                                <Label htmlFor="note">Note (Optional)</Label>
                                <textarea
                                    id="note"
                                    placeholder="Add a note about this status update..."
                                    value={note}
                                    onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setNote(e.target.value)}
                                    rows={3}
                                    className="w-full px-3 py-2 text-sm rounded-md border border-border bg-background focus:outline-none focus:ring-2 focus:ring-[#FE6132]/20"
                                />
                            </div>
                        </>
                    )}
                </div>

                <DialogFooter>
                    <Button
                        variant="outline"
                        onClick={() => {
                            setSelectedStatus(null);
                            setNote("");
                            onOpenChange(false);
                        }}
                        disabled={isUpdating}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={handleUpdate}
                        disabled={!selectedStatus || isUpdating || availableStatuses.length === 0}
                        className="bg-[#FE6132] hover:bg-[#FE6132]/90"
                    >
                        {isUpdating ? 'Updating...' : 'Update Status'}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
