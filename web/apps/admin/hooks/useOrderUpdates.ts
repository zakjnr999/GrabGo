"use client";

import { useState, useEffect, useCallback } from "react";
import { Order, mockOrders, OrderStatus } from "../lib/mockOrderData";

/**
 * Custom hook to simulate real-time order updates via "WebSockets"
 */
export function useOrderUpdates() {
    const [orders, setOrders] = useState<Order[]>(mockOrders);
    const [lastUpdate, setLastUpdate] = useState<{ orderNumber: string; status: OrderStatus } | null>(null);

    // Simulate status progression for an active order
    const simulateStatusUpdate = useCallback(() => {
        const activeOrders = orders.filter(o =>
            !['delivered', 'cancelled'].includes(o.status)
        );

        if (activeOrders.length === 0) return;

        // Pick a random active order
        const randomIndex = Math.floor(Math.random() * activeOrders.length);
        const orderToUpdate = activeOrders[randomIndex];

        const nextStatusMap: Record<string, OrderStatus> = {
            'pending': 'confirmed',
            'confirmed': 'preparing',
            'preparing': 'ready',
            'ready': 'picked_up',
            'picked_up': 'on_the_way',
            'on_the_way': 'delivered'
        };

        const newStatus = nextStatusMap[orderToUpdate.status];
        if (!newStatus) return;

        setOrders(prev => prev.map(o =>
            o.id === orderToUpdate.id
                ? {
                    ...o,
                    status: newStatus,
                    updatedAt: new Date().toISOString(),
                    timeline: [
                        {
                            status: newStatus,
                            timestamp: new Date().toISOString(),
                            note: `Status auto-updated via system simulation`
                        },
                        ...o.timeline
                    ]
                }
                : o
        ));

        setLastUpdate({ orderNumber: orderToUpdate.orderNumber, status: newStatus });

        // Clear notification after 5 seconds
        setTimeout(() => setLastUpdate(null), 5000);
    }, [orders]);

    // Simulate new order arrival
    const simulateNewOrder = useCallback(() => {
        const orderId = `NEW-${Math.floor(Math.random() * 9000) + 1000}`;
        const newOrder: Order = {
            id: orderId,
            orderNumber: `#GG-${orderId.split('-')[1]}`,
            type: ['food', 'grocery', 'pharmacy', 'market'][Math.floor(Math.random() * 4)] as any,
            status: 'pending',
            paymentStatus: Math.random() > 0.3 ? 'paid' : 'pending',
            paymentMethod: ['mtn_momo', 'card', 'cash'][Math.floor(Math.random() * 3)] as any,
            customer: {
                id: 'cust-new',
                name: 'New Customer',
                phone: '+233 24 000 0000',
                email: 'new@example.com',
                avatar: 'https://i.pravatar.cc/150?u=new',
                totalOrders: 1
            },
            vendor: orders[0].vendor, // Just reuse a vendor for mock
            items: [
                {
                    id: 'item-1',
                    name: 'Mystery Package',
                    quantity: 1,
                    price: 45.00
                }
            ],
            pricing: {
                subtotal: 45.00,
                deliveryFee: 10.00,
                tax: 2.25,
                discount: 0,
                total: 57.25
            },
            delivery: {
                address: 'New Delivery Street, Accra',
                city: 'Accra',
                coordinates: { lat: 5.6037, lng: -0.1870 },
                estimatedTime: '30-45 mins'
            },
            timeline: [
                {
                    status: 'pending',
                    timestamp: new Date().toISOString(),
                    note: 'Order placed'
                }
            ],
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };

        setOrders(prev => [newOrder, ...prev]);
        setLastUpdate({ orderNumber: newOrder.orderNumber, status: 'pending' });

        // Clear notification after 5 seconds
        setTimeout(() => setLastUpdate(null), 5000);
    }, [orders]);

    useEffect(() => {
        // Run simulation every 15-30 seconds
        const timer = setInterval(() => {
            const rand = Math.random();
            if (rand < 0.2) {
                simulateNewOrder();
            } else if (rand < 0.7) {
                simulateStatusUpdate();
            }
        }, 20000);

        return () => clearInterval(timer);
    }, [simulateNewOrder, simulateStatusUpdate]);

    return { orders, lastUpdate };
}
