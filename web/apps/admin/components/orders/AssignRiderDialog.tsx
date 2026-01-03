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
import { Search, Cycling } from "iconoir-react";

interface Rider {
    id: string;
    name: string;
    phone: string;
    rating: number;
    totalDeliveries: number;
    vehicleType: string;
    vehicleNumber: string;
    status: 'available' | 'busy' | 'offline';
    currentOrders: number;
}

interface AssignRiderDialogProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    onAssign: (riderId: string) => void;
    currentRiderId?: string;
}

// Mock riders data
const mockRiders: Rider[] = [
    {
        id: 'rider-1',
        name: 'Kwabena Mensah',
        phone: '+233244123456',
        rating: 4.8,
        totalDeliveries: 342,
        vehicleType: 'Motorcycle',
        vehicleNumber: 'GH-1234-21',
        status: 'available',
        currentOrders: 0
    },
    {
        id: 'rider-2',
        name: 'Yaw Boateng',
        phone: '+233244234567',
        rating: 4.9,
        totalDeliveries: 521,
        vehicleType: 'Motorcycle',
        vehicleNumber: 'GH-2345-21',
        status: 'available',
        currentOrders: 0
    },
    {
        id: 'rider-3',
        name: 'Kofi Asare',
        phone: '+233244345678',
        rating: 4.7,
        totalDeliveries: 289,
        vehicleType: 'Bicycle',
        vehicleNumber: 'GH-3456-21',
        status: 'busy',
        currentOrders: 2
    },
    {
        id: 'rider-4',
        name: 'Ama Adjei',
        phone: '+233244456789',
        rating: 4.6,
        totalDeliveries: 198,
        vehicleType: 'Motorcycle',
        vehicleNumber: 'GH-4567-21',
        status: 'available',
        currentOrders: 0
    },
    {
        id: 'rider-5',
        name: 'Kwame Owusu',
        phone: '+233244567890',
        rating: 4.5,
        totalDeliveries: 156,
        vehicleType: 'Car',
        vehicleNumber: 'GH-5678-21',
        status: 'busy',
        currentOrders: 1
    }
];

export function AssignRiderDialog({ open, onOpenChange, onAssign, currentRiderId }: AssignRiderDialogProps) {
    const [searchQuery, setSearchQuery] = useState("");
    const [selectedRiderId, setSelectedRiderId] = useState<string | null>(currentRiderId || null);
    const [isAssigning, setIsAssigning] = useState(false);

    const filteredRiders = mockRiders.filter(rider => {
        const matchesSearch = !searchQuery ||
            rider.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
            rider.phone.includes(searchQuery) ||
            rider.vehicleNumber.toLowerCase().includes(searchQuery.toLowerCase());
        return matchesSearch;
    });

    const handleAssign = async () => {
        if (!selectedRiderId) return;

        setIsAssigning(true);
        // Simulate API call
        await new Promise(resolve => setTimeout(resolve, 1000));

        onAssign(selectedRiderId);
        setIsAssigning(false);
        onOpenChange(false);
    };

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'available':
                return 'bg-green-100 text-green-700';
            case 'busy':
                return 'bg-orange-100 text-orange-700';
            case 'offline':
                return 'bg-gray-100 text-gray-700';
            default:
                return 'bg-gray-100 text-gray-700';
        }
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="max-w-2xl max-h-[80vh] overflow-hidden flex flex-col">
                <DialogHeader>
                    <DialogTitle>
                        {currentRiderId ? 'Reassign Rider' : 'Assign Rider'}
                    </DialogTitle>
                    <DialogDescription>
                        Select a rider to {currentRiderId ? 'reassign' : 'assign'} to this order
                    </DialogDescription>
                </DialogHeader>

                <div className="flex-1 overflow-hidden flex flex-col gap-4">
                    {/* Search */}
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                        <input
                            type="text"
                            placeholder="Search by name, phone, or vehicle number..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="w-full pl-10 pr-4 py-2 text-sm rounded-md border border-border bg-background focus:outline-none focus:ring-2 focus:ring-[#FE6132]/20"
                        />
                    </div>

                    {/* Riders List */}
                    <div className="flex-1 overflow-y-auto space-y-2 pr-2">
                        {filteredRiders.length === 0 ? (
                            <div className="text-center py-8 text-muted-foreground">
                                No riders found
                            </div>
                        ) : (
                            filteredRiders.map((rider) => (
                                <button
                                    key={rider.id}
                                    onClick={() => setSelectedRiderId(rider.id)}
                                    className={`w-full p-4 rounded-lg border-2 transition-all text-left ${selectedRiderId === rider.id
                                            ? 'border-[#FE6132] bg-[#FE6132]/5'
                                            : 'border-border hover:border-[#FE6132]/50 hover:bg-accent/50'
                                        }`}
                                >
                                    <div className="flex items-start gap-3">
                                        <div className="p-2 rounded-full bg-accent">
                                            <Cycling className="w-5 h-5 text-[#FE6132]" />
                                        </div>
                                        <div className="flex-1 min-w-0">
                                            <div className="flex items-center justify-between gap-2 mb-1">
                                                <h4 className="font-semibold">{rider.name}</h4>
                                                <span className={`text-xs px-2 py-1 rounded-full font-medium capitalize ${getStatusColor(rider.status)}`}>
                                                    {rider.status}
                                                </span>
                                            </div>
                                            <div className="flex items-center gap-4 text-sm text-muted-foreground mb-2">
                                                <span>{rider.phone}</span>
                                                <span>•</span>
                                                <span>{rider.vehicleType}</span>
                                                <span>•</span>
                                                <span>{rider.vehicleNumber}</span>
                                            </div>
                                            <div className="flex items-center gap-4 text-sm">
                                                <div className="flex items-center gap-1">
                                                    <span>⭐</span>
                                                    <span className="font-medium">{rider.rating.toFixed(1)}</span>
                                                </div>
                                                <span className="text-muted-foreground">
                                                    {rider.totalDeliveries} deliveries
                                                </span>
                                                {rider.currentOrders > 0 && (
                                                    <span className="text-orange-600 font-medium">
                                                        {rider.currentOrders} active order{rider.currentOrders > 1 ? 's' : ''}
                                                    </span>
                                                )}
                                            </div>
                                        </div>
                                    </div>
                                </button>
                            ))
                        )}
                    </div>
                </div>

                <DialogFooter>
                    <Button
                        variant="outline"
                        onClick={() => onOpenChange(false)}
                        disabled={isAssigning}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={handleAssign}
                        disabled={!selectedRiderId || isAssigning}
                        className="bg-[#FE6132] hover:bg-[#FE6132]/90"
                    >
                        {isAssigning ? 'Assigning...' : currentRiderId ? 'Reassign Rider' : 'Assign Rider'}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
