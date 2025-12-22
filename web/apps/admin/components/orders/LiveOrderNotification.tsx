"use client";

import { useEffect, useState } from "react";
import { OrderStatus } from "../../lib/mockOrderData";
import { ShoppingBag, CheckCircle, Clock, WarningCircle, Xmark } from "iconoir-react";

interface LiveOrderNotificationProps {
    orderNumber: string;
    status: OrderStatus;
    onClose: () => void;
}

export function LiveOrderNotification({ orderNumber, status, onClose }: LiveOrderNotificationProps) {
    const [isVisible, setIsVisible] = useState(false);

    useEffect(() => {
        setIsVisible(true);
        // Play notification sound
        const audio = new Audio("https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3");
        audio.play().catch(e => console.log("Audio play blocked by browser", e));
    }, []);

    const getStatusInfo = (status: OrderStatus) => {
        switch (status) {
            case 'pending':
                return {
                    label: 'New Order Received!',
                    icon: <ShoppingBag className="w-5 h-5 text-blue-600" />,
                    bg: 'bg-blue-50',
                    border: 'border-blue-200'
                };
            case 'delivered':
                return {
                    label: 'Order Delivered Successfully',
                    icon: <CheckCircle className="w-5 h-5 text-green-600" />,
                    bg: 'bg-green-50',
                    border: 'border-green-200'
                };
            case 'cancelled':
                return {
                    label: 'Order Cancelled',
                    icon: <WarningCircle className="w-5 h-5 text-red-600" />,
                    bg: 'bg-red-50',
                    border: 'border-red-200'
                };
            default:
                return {
                    label: `Order Update: ${status.replace('_', ' ')}`,
                    icon: <Clock className="w-5 h-5 text-orange-600" />,
                    bg: 'bg-orange-50',
                    border: 'border-orange-200'
                };
        }
    };

    const info = getStatusInfo(status);

    return (
        <div
            className={`fixed bottom-6 right-6 z-50 transition-all duration-500 transform ${isVisible ? 'translate-y-0 opacity-100' : 'translate-y-12 opacity-0'
                }`}
        >
            <div className={`p-4 rounded-lg border shadow-lg ${info.bg} ${info.border} min-w-[300px]`}>
                <div className="flex items-start gap-3">
                    <div className="p-2 rounded-full bg-white shadow-sm">
                        {info.icon}
                    </div>
                    <div className="flex-1">
                        <h4 className="font-bold text-gray-900">{info.label}</h4>
                        <p className="text-sm text-gray-600 mt-0.5">Order {orderNumber}</p>
                    </div>
                    <button
                        onClick={() => {
                            setIsVisible(false);
                            setTimeout(onClose, 500);
                        }}
                        className="p-1 hover:bg-black/5 rounded-md transition-colors"
                    >
                        <Xmark className="w-4 h-4 text-gray-400" />
                    </button>
                </div>
            </div>
        </div>
    );
}
