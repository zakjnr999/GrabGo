"use client";

import { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { Card } from "@grabgo/ui";
import { getOrderById, OrderStatus } from "../../../../lib/mockOrderData";
import { NavArrowLeft, User, Shop, Cycling, MapPin, CreditCard, Package, Clock, CheckCircle, Download, Printer } from "iconoir-react";
import { AssignRiderDialog } from "../../../../components/orders/AssignRiderDialog";
import { UpdateStatusDialog } from "../../../../components/orders/UpdateStatusDialog";
import { CancelOrderDialog } from "../../../../components/orders/CancelOrderDialog";
import { ProcessRefundDialog } from "../../../../components/orders/ProcessRefundDialog";
import { OrderChatView } from "../../../../components/orders/OrderChatView";
import { exportOrderToCSV, exportOrderToExcel, printOrderReceipt } from "../../../../lib/orderExportUtils";

export default function OrderDetailPage() {
    const params = useParams();
    const router = useRouter();
    const orderId = params.id as string;

    // Dialog states
    const [assignRiderOpen, setAssignRiderOpen] = useState(false);
    const [updateStatusOpen, setUpdateStatusOpen] = useState(false);
    const [cancelOrderOpen, setCancelOrderOpen] = useState(false);
    const [refundDialogOpen, setRefundDialogOpen] = useState(false);

    const order = getOrderById(orderId);

    if (!order) {
        return (
            <div className="flex items-center justify-center min-h-[400px]">
                <div className="text-center">
                    <h2 className="text-2xl font-bold mb-2">Order Not Found</h2>
                    <p className="text-muted-foreground mb-4">The order you're looking for doesn't exist.</p>
                    <Link href="/orders" className="text-[#FE6132] hover:underline">
                        Back to Orders
                    </Link>
                </div>
            </div>
        );
    }

    const getStatusColor = (status: OrderStatus) => {
        const colors: Record<OrderStatus, string> = {
            pending: 'bg-yellow-100 text-yellow-700 border-yellow-200',
            confirmed: 'bg-blue-100 text-blue-700 border-blue-200',
            preparing: 'bg-purple-100 text-purple-700 border-purple-200',
            ready: 'bg-indigo-100 text-indigo-700 border-indigo-200',
            picked_up: 'bg-cyan-100 text-cyan-700 border-cyan-200',
            on_the_way: 'bg-orange-100 text-orange-700 border-orange-200',
            delivered: 'bg-green-100 text-green-700 border-green-200',
            cancelled: 'bg-red-100 text-red-700 border-red-200'
        };
        return colors[status];
    };

    const getStatusIcon = (status: OrderStatus): React.ReactElement => {
        const icons: Record<OrderStatus, React.ReactElement> = {
            pending: <Clock className="w-4 h-4" />,
            confirmed: <CheckCircle className="w-4 h-4" />,
            preparing: <Package className="w-4 h-4" />,
            ready: <CheckCircle className="w-4 h-4" />,
            picked_up: <Cycling className="w-4 h-4" />,
            on_the_way: <Cycling className="w-4 h-4" />,
            delivered: <CheckCircle className="w-4 h-4" />,
            cancelled: <CheckCircle className="w-4 h-4" />
        };
        return icons[status];
    };

    const formatDate = (dateString: string) => {
        return new Date(dateString).toLocaleString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    const formatTime = (dateString: string) => {
        return new Date(dateString).toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    const getTypeColor = (type: string) => {
        const colors: Record<string, string> = {
            food: 'bg-orange-100 text-orange-700',
            grocery: 'bg-green-100 text-green-700',
            pharmacy: 'bg-blue-100 text-blue-700',
            market: 'bg-purple-100 text-purple-700'
        };
        return colors[type] || 'bg-gray-100 text-gray-700';
    };

    // Action handlers
    const handleAssignRider = (riderId: string) => {
        console.log('Assigning rider:', riderId);
        // TODO: Implement API call to assign rider
        alert(`Rider ${riderId} assigned successfully!`);
        // Refresh page or update state
        router.refresh();
    };

    const handleUpdateStatus = (newStatus: OrderStatus, note?: string) => {
        console.log('Updating status to:', newStatus, 'Note:', note);
        // TODO: Implement API call to update status
        alert(`Order status updated to ${newStatus}${note ? ` with note: ${note}` : ''}`);
        // Refresh page or update state
        router.refresh();
    };

    const handleCancelOrder = (reason: string) => {
        console.log('Cancelling order with reason:', reason);
        // TODO: Implement API call to cancel order
        alert(`Order cancelled. Reason: ${reason}`);
        // Redirect to orders list
        router.push('/orders');
    };

    const handleRefund = (amount: number, reason: string) => {
        console.log('Processing refund:', amount, 'Reason:', reason);
        // TODO: Implement API call to process refund
        alert(`Refund of GH₵ ${amount.toFixed(2)} processed successfully!\nReason: ${reason}`);
        // Refresh page or update state
        router.refresh();
    };

    const handleExportCSV = () => {
        exportOrderToCSV(order);
    };

    const handleExportExcel = async () => {
        await exportOrderToExcel(order);
    };

    const handlePrint = () => {
        printOrderReceipt(order);
    };

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex flex-col gap-6 animate-fade-in-up">
                <div className="flex items-center gap-4">
                    <button
                        onClick={() => router.back()}
                        className="p-2.5 rounded-full hover:bg-accent transition-all hover:scale-110 active:scale-90"
                    >
                        <NavArrowLeft className="w-6 h-6" />
                    </button>
                    <div className="flex-1">
                        <h1 className="text-4xl font-bold tracking-tight">Order {order.orderNumber}</h1>
                        <p className="text-muted-foreground mt-1 text-lg">Placed on {formatDate(order.createdAt)}</p>
                    </div>
                    <div className={`px-6 py-2.5 rounded-full border-2 font-bold capitalize text-sm shadow-sm ${getStatusColor(order.status)}`}>
                        {order.status.replace('_', ' ')}
                    </div>
                </div>

                {/* Quick Action Buttons */}
                {order.status !== 'delivered' && order.status !== 'cancelled' && (
                    <div className="flex gap-4">
                        <button
                            onClick={() => setUpdateStatusOpen(true)}
                            className="px-6 py-2.5 text-sm rounded-full bg-[#FE6132] text-white hover:bg-[#FE6132]/90 transition-all font-bold shadow-md shadow-orange-100 hover:scale-105 active:scale-95"
                        >
                            Update Status
                        </button>
                        <button
                            onClick={() => setAssignRiderOpen(true)}
                            className="px-6 py-2.5 text-sm rounded-full border border-border bg-background hover:bg-accent transition-all font-bold shadow-sm hover:scale-105 active:scale-95"
                        >
                            {order.rider ? 'Reassign Rider' : 'Assign Rider'}
                        </button>
                        <button
                            onClick={() => setCancelOrderOpen(true)}
                            className="px-6 py-2.5 text-sm rounded-full border border-red-200 text-red-600 hover:bg-red-50 transition-all font-bold shadow-sm hover:scale-105 active:scale-95"
                        >
                            Cancel Order
                        </button>
                    </div>
                )}
            </div>

            {/* Dialogs */}
            <AssignRiderDialog
                open={assignRiderOpen}
                onOpenChange={setAssignRiderOpen}
                onAssign={handleAssignRider}
                currentRiderId={order.rider?.id}
            />
            <UpdateStatusDialog
                open={updateStatusOpen}
                onOpenChange={setUpdateStatusOpen}
                currentStatus={order.status}
                onUpdate={handleUpdateStatus}
            />
            <CancelOrderDialog
                open={cancelOrderOpen}
                onOpenChange={setCancelOrderOpen}
                onCancel={handleCancelOrder}
                orderNumber={order.orderNumber}
            />

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Left Column - Main Info */}
                <div className="lg:col-span-2 space-y-6">
                    {/* Order Timeline */}
                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:100ms] hover:shadow-md transition-shadow">
                        <h2 className="text-lg font-bold mb-6 flex items-center gap-2">
                            <Clock className="w-5 h-5 text-[#FE6132]" />
                            Order Timeline
                        </h2>
                        <div className="space-y-0">
                            {order.timeline.map((update, index) => (
                                <div
                                    key={index}
                                    className="flex gap-6 animate-fade-in-up"
                                    style={{ animationDelay: `${200 + index * 100}ms` }}
                                >
                                    <div className="flex flex-col items-center">
                                        <div className={`p-2.5 rounded-full shadow-sm transition-transform hover:scale-110 ${getStatusColor(update.status)}`}>
                                            {getStatusIcon(update.status)}
                                        </div>
                                        {index < order.timeline.length - 1 && (
                                            <div className="w-0.5 h-16 bg-gradient-to-b from-border to-transparent my-1" />
                                        )}
                                    </div>
                                    <div className="flex-1 pb-8">
                                        <p className="font-bold capitalize text-foreground">{update.status.replace('_', ' ')}</p>
                                        <p className="text-xs font-medium text-muted-foreground mt-0.5">{formatDate(update.timestamp)}</p>
                                        {update.note && (
                                            <p className="text-sm text-muted-foreground mt-2 bg-accent/30 p-3 rounded-xl border border-border/50">
                                                {update.note}
                                            </p>
                                        )}
                                    </div>
                                </div>
                            ))}
                        </div>
                    </Card>

                    {/* Order Items */}
                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:200ms] hover:shadow-md transition-shadow">
                        <h2 className="text-lg font-bold mb-6 flex items-center gap-2">
                            <Package className="w-5 h-5 text-[#FE6132]" />
                            Order Items
                        </h2>
                        <div className="space-y-4">
                            {order.items.map((item, idx) => (
                                <div
                                    key={item.id}
                                    className="flex items-center justify-between py-4 border-b border-border/50 last:border-0 hover:bg-accent/10 rounded-xl px-2 transition-colors animate-fade-in-up"
                                    style={{ animationDelay: `${300 + idx * 50}ms` }}
                                >
                                    <div className="flex items-center gap-4">
                                        <div className="w-16 h-16 rounded-2xl bg-accent/50 flex items-center justify-center shadow-inner group overflow-hidden">
                                            <Package className="w-8 h-8 text-muted-foreground group-hover:scale-110 transition-transform" />
                                        </div>
                                        <div>
                                            <p className="font-bold text-foreground">{item.name}</p>
                                            <p className="text-sm font-medium text-muted-foreground">Quantity: {item.quantity}</p>
                                            {item.specialInstructions && (
                                                <div className="flex items-start gap-1.5 mt-2 bg-orange-50/50 p-2 rounded-lg border border-orange-100">
                                                    <span className="text-[10px] text-orange-600 font-bold uppercase tracking-wider">Note:</span>
                                                    <p className="text-xs text-orange-700 italic">{item.specialInstructions}</p>
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                    <p className="font-bold text-lg text-foreground">GH₵ {(item.price * item.quantity).toFixed(2)}</p>
                                </div>
                            ))}
                        </div>

                        {/* Pricing Breakdown */}
                        <div className="mt-6 pt-4 border-t border-border space-y-2">
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">Subtotal</span>
                                <span>GH₵ {order.pricing.subtotal.toFixed(2)}</span>
                            </div>
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">Delivery Fee</span>
                                <span>GH₵ {order.pricing.deliveryFee.toFixed(2)}</span>
                            </div>
                            <div className="flex justify-between text-sm">
                                <span className="text-muted-foreground">Tax</span>
                                <span>GH₵ {order.pricing.tax.toFixed(2)}</span>
                            </div>
                            {order.pricing.discount > 0 && (
                                <div className="flex justify-between text-sm text-green-600">
                                    <span>Discount {order.promoCode && `(${order.promoCode})`}</span>
                                    <span>- GH₵ {order.pricing.discount.toFixed(2)}</span>
                                </div>
                            )}
                            <div className="flex justify-between text-lg font-bold pt-2 border-t border-border">
                                <span>Total</span>
                                <span>GH₵ {order.pricing.total.toFixed(2)}</span>
                            </div>
                        </div>
                    </Card>
                </div>

                {/* Right Column - Details */}
                <div className="space-y-6">
                    {/* Customer Info */}
                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:300ms] hover:shadow-md transition-all group">
                        <div className="flex items-center gap-3 mb-6">
                            <div className="p-2 rounded-lg bg-orange-50 group-hover:bg-orange-100 transition-colors">
                                <User className="w-5 h-5 text-[#FE6132]" />
                            </div>
                            <h2 className="text-lg font-bold">Customer</h2>
                        </div>
                        <div className="space-y-4">
                            <div className="flex items-center gap-4">
                                <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 flex items-center justify-center text-white text-xl font-bold shadow-sm ring-4 ring-orange-50">
                                    {order.customer.name.charAt(0)}
                                </div>
                                <div className="flex-1">
                                    <p className="font-bold text-lg leading-tight">{order.customer.name}</p>
                                    <p className="text-sm font-medium text-[#FE6132] mt-1">{order.customer.totalOrders} successful orders</p>
                                </div>
                            </div>
                            <div className="space-y-2 p-4 rounded-xl bg-accent/30 border border-border/50">
                                <p className="text-sm font-medium text-foreground flex items-center gap-2">
                                    <span className="text-muted-foreground">📞</span> {order.customer.phone}
                                </p>
                                <p className="text-sm font-medium text-foreground flex items-center gap-2">
                                    <span className="text-muted-foreground">✉️</span> {order.customer.email}
                                </p>
                            </div>
                            <Link
                                href={`/users/${order.customer.id}`}
                                className="w-full text-center px-4 py-2.5 text-sm font-bold text-[#FE6132] bg-orange-50 hover:bg-orange-100 rounded-xl transition-colors block"
                            >
                                View Detailed Profile
                            </Link>
                        </div>
                    </Card>

                    {/* Vendor Info */}
                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:400ms] hover:shadow-md transition-all group">
                        <div className="flex items-center gap-3 mb-6">
                            <div className="p-2 rounded-lg bg-orange-50 group-hover:bg-orange-100 transition-colors">
                                <Shop className="w-5 h-5 text-[#FE6132]" />
                            </div>
                            <h2 className="text-lg font-bold">Vendor</h2>
                        </div>
                        <div className="space-y-4">
                            <div>
                                <h3 className="font-bold text-lg text-foreground">{order.vendor.name}</h3>
                                <div className="flex items-center gap-2 mt-1">
                                    <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider ${getTypeColor(order.vendor.type)}`}>
                                        {order.vendor.type}
                                    </span>
                                    <div className="flex items-center gap-1.5 ml-auto">
                                        <span className="text-sm">⭐</span>
                                        <span className="text-sm font-bold">{order.vendor.rating.toFixed(1)}</span>
                                    </div>
                                </div>
                            </div>
                            <div className="space-y-2 p-4 rounded-xl bg-accent/30 border border-border/50">
                                <p className="text-sm font-medium text-foreground flex items-center gap-2">
                                    <span className="text-muted-foreground">📞</span> {order.vendor.phone}
                                </p>
                                <p className="text-sm font-medium text-foreground leading-snug">
                                    <span className="text-muted-foreground mr-1.5">📍</span> {order.vendor.address}
                                </p>
                            </div>
                            <Link
                                href={`/vendors/${order.vendor.id}`}
                                className="w-full text-center px-4 py-2.5 text-sm font-bold text-[#FE6132] bg-orange-50 hover:bg-orange-100 rounded-xl transition-colors block"
                            >
                                View Vendor Store
                            </Link>
                        </div>
                    </Card>

                    {/* Rider Info */}
                    {order.rider && (
                        <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:500ms] hover:shadow-md transition-all group">
                            <div className="flex items-center gap-3 mb-6">
                                <div className="p-2 rounded-lg bg-orange-50 group-hover:bg-orange-100 transition-colors">
                                    <Cycling className="w-5 h-5 text-[#FE6132]" />
                                </div>
                                <h2 className="text-lg font-bold">Rider</h2>
                            </div>
                            <div className="space-y-4">
                                <div className="flex items-center gap-4">
                                    <div className="w-14 h-14 rounded-2xl bg-orange-100 flex items-center justify-center text-2xl shadow-inner">
                                        🚴
                                    </div>
                                    <div className="flex-1">
                                        <p className="font-bold text-lg leading-tight">{order.rider.name}</p>
                                        <p className="text-sm font-medium text-muted-foreground mt-0.5">{order.rider.vehicleType} • {order.rider.vehicleNumber}</p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-6 p-4 rounded-xl bg-accent/30 border border-border/50">
                                    <div className="text-center flex-1 border-r border-border/50">
                                        <p className="text-xs font-bold text-muted-foreground uppercase tracking-tighter">Rating</p>
                                        <p className="text-lg font-bold text-foreground">⭐ {order.rider.rating.toFixed(1)}</p>
                                    </div>
                                    <div className="text-center flex-1">
                                        <p className="text-xs font-bold text-muted-foreground uppercase tracking-tighter">Deliveries</p>
                                        <p className="text-lg font-bold text-foreground">{order.rider.totalDeliveries}</p>
                                    </div>
                                </div>
                                <div className="flex gap-2">
                                    <button className="flex-1 py-2 text-sm font-bold text-[#FE6132] bg-orange-50 hover:bg-orange-100 rounded-xl transition-colors">
                                        Call Rider
                                    </button>
                                    <button className="flex-1 py-2 text-sm font-bold text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-xl transition-colors">
                                        Live Track
                                    </button>
                                </div>
                            </div>
                        </Card>
                    )}

                    {/* Delivery Info */}
                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:600ms] hover:shadow-md transition-all group">
                        <div className="flex items-center gap-3 mb-6">
                            <div className="p-2 rounded-lg bg-orange-50 group-hover:bg-orange-100 transition-colors">
                                <MapPin className="w-5 h-5 text-[#FE6132]" />
                            </div>
                            <h2 className="text-lg font-bold">Delivery Info</h2>
                        </div>
                        <div className="space-y-4">
                            <div className="p-4 rounded-xl bg-accent/30 border border-border/50 space-y-1">
                                <p className="font-bold text-foreground">{order.delivery.address}</p>
                                <p className="text-sm font-medium text-muted-foreground">{order.delivery.city}</p>
                            </div>
                            {order.delivery.instructions && (
                                <div className="p-4 rounded-xl bg-blue-50 border border-blue-100 border-dashed">
                                    <div className="flex items-center gap-2 mb-2">
                                        <span className="text-blue-600">📝</span>
                                        <p className="text-xs font-bold text-blue-700 uppercase tracking-wider">Instructions</p>
                                    </div>
                                    <p className="text-sm text-blue-800 font-medium italic">{order.delivery.instructions}</p>
                                </div>
                            )}
                            {order.delivery.estimatedTime && (
                                <div className="flex items-center justify-between p-4 rounded-xl bg-green-50 border border-green-100">
                                    <div className="flex items-center gap-2 text-green-700">
                                        <Clock className="w-5 h-5" />
                                        <span className="text-sm font-bold">Expected Delivery</span>
                                    </div>
                                    <span className="text-sm font-bold text-green-700">{order.delivery.estimatedTime}</span>
                                </div>
                            )}
                        </div>
                    </Card>

                    {/* Payment Info */}
                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:700ms] hover:shadow-md transition-all group">
                        <div className="flex items-center gap-3 mb-6">
                            <div className="p-2 rounded-lg bg-orange-50 group-hover:bg-orange-100 transition-colors">
                                <CreditCard className="w-5 h-5 text-[#FE6132]" />
                            </div>
                            <h2 className="text-lg font-bold">Payment Details</h2>
                        </div>
                        <div className="space-y-4">
                            <div className="flex items-center justify-between p-3 rounded-xl bg-accent/30 border border-border/50">
                                <span className="text-sm font-medium text-muted-foreground">Payment Method</span>
                                <span className="text-sm font-bold capitalize flex items-center gap-2">
                                    {order.paymentMethod === 'card' ? '💳' : '📱'} {order.paymentMethod.replace('_', ' ')}
                                </span>
                            </div>
                            <div className="flex items-center justify-between p-3 rounded-xl bg-accent/30 border border-border/50">
                                <span className="text-sm font-medium text-muted-foreground">Transaction Status</span>
                                <span className={`text-[10px] px-3 py-1 rounded-full font-bold uppercase tracking-widest ${order.paymentStatus === 'paid' ? 'bg-green-100 text-green-700 ring-2 ring-green-50' :
                                    order.paymentStatus === 'pending' ? 'bg-yellow-100 text-yellow-700 ring-2 ring-yellow-50' :
                                        order.paymentStatus === 'failed' ? 'bg-red-100 text-red-700 ring-2 ring-red-50' :
                                            'bg-gray-100 text-gray-700'
                                    }`}>
                                    {order.paymentStatus}
                                </span>
                            </div>
                            <div className="flex items-center justify-between pt-4 border-t border-border">
                                <span className="text-base font-bold text-foreground">Settled Amount</span>
                                <span className="text-2xl font-black text-[#FE6132]">GH₵ {order.pricing.total.toFixed(2)}</span>
                            </div>

                            {/* Payment Actions */}
                            {order.paymentStatus === 'paid' && order.status !== 'cancelled' && (
                                <div className="pt-4">
                                    <button
                                        onClick={() => setRefundDialogOpen(true)}
                                        className="w-full px-6 py-3 text-sm font-bold rounded-xl border-2 border-orange-200 text-[#FE6132] hover:bg-orange-50 transition-all hover:scale-[1.02] active:scale-95 shadow-sm"
                                    >
                                        Process Order Refund
                                    </button>
                                </div>
                            )}
                        </div>
                    </Card>

                    {/* Export & Print Actions */}
                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:800ms] hover:shadow-md transition-all">
                        <h2 className="text-lg font-bold mb-6 flex items-center gap-2">
                            <Printer className="w-5 h-5 text-[#FE6132]" />
                            Operational Actions
                        </h2>
                        <div className="grid grid-cols-1 gap-3">
                            <button
                                onClick={handlePrint}
                                className="flex-1 flex items-center justify-center gap-3 px-6 py-3 text-sm font-bold rounded-xl border border-border bg-background hover:bg-accent transition-all hover:scale-[1.02] active:scale-95"
                            >
                                <Printer className="w-5 h-5 text-[#FE6132]" />
                                Print Professional Receipt
                            </button>
                            <div className="flex gap-3">
                                <button
                                    onClick={handleExportCSV}
                                    className="flex-1 flex items-center justify-center gap-2 px-4 py-3 text-xs font-bold rounded-xl border border-border bg-background hover:bg-accent transition-all hover:scale-[1.02] active:scale-95"
                                >
                                    <Download className="w-4 h-4" />
                                    Export CSV
                                </button>
                                <button
                                    onClick={handleExportExcel}
                                    className="flex-1 flex items-center justify-center gap-2 px-4 py-3 text-xs font-bold rounded-xl border border-border bg-background hover:bg-accent transition-all hover:scale-[1.02] active:scale-95"
                                >
                                    <Download className="w-4 h-4" />
                                    Export Excel
                                </button>
                            </div>
                        </div>
                    </Card>

                    {/* Notes */}
                    {order.notes && (
                        <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:900ms] bg-yellow-50/30 border-dashed hover:shadow-md transition-all">
                            <h2 className="text-lg font-bold mb-4 flex items-center gap-2">
                                <span className="text-xl">📌</span>
                                Order Notes
                            </h2>
                            <p className="text-sm text-foreground font-medium bg-white p-4 rounded-xl border border-border/50 shadow-sm leading-relaxed">
                                {order.notes}
                            </p>
                        </Card>
                    )}

                    {/* Order Chat */}
                    <div className="animate-fade-in-up [animation-delay:1000ms]">
                        <OrderChatView
                            orderId={order.orderNumber}
                            customerName={order.customer.name}
                            riderName={order.rider?.name}
                        />
                    </div>
                </div>
            </div>

            {/* Refund Dialog */}
            <ProcessRefundDialog
                open={refundDialogOpen}
                onOpenChange={setRefundDialogOpen}
                onRefund={handleRefund}
                orderNumber={order.orderNumber}
                totalAmount={order.pricing.total}
                paymentMethod={order.paymentMethod}
            />
        </div>
    );
}
