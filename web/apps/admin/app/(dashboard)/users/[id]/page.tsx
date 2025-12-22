"use client";

import { notFound } from "next/navigation";
import Link from "next/link";
import { useState, useEffect, use } from "react";
import { Card, Badge, Button, Tabs, TabsContent, TabsList, TabsTrigger } from "@grabgo/ui";
import {
    ArrowLeft,
    Edit,
    Key,
    Wallet,
    Bell,
    Cart,
    Group,
    CheckCircleSolid,
} from "iconoir-react";
import { TrendingUp } from "lucide-react";
import {
    getCustomerById,
    getCustomerOrders,
    getCustomerPayments,
    type Order,
    type Payment,
} from "../../../../lib/mockData";
import { format } from "date-fns";
import { CustomerProfileHeader } from "./CustomerProfileHeader";

interface CustomerPageProps {
    params: Promise<{
        id: string;
    }>;
}

// Animated Number Component
function AnimatedNumber({ value, delay = 0, decimals = 0 }: { value: number; delay?: number; decimals?: number }) {
    const [count, setCount] = useState(0);

    useEffect(() => {
        const duration = 1000;
        const steps = 30;
        const increment = value / steps;
        let current = 0;

        const timer = setTimeout(() => {
            const interval = setInterval(() => {
                current += increment;
                if (current >= value) {
                    setCount(value);
                    clearInterval(interval);
                } else {
                    setCount(current);
                }
            }, duration / steps);

            return () => clearInterval(interval);
        }, delay + 300);

        return () => clearTimeout(timer);
    }, [value, delay]);

    return <>{decimals > 0 ? count.toFixed(decimals) : Math.floor(count).toLocaleString()}</>;
}

export default function CustomerDetailPage({ params }: CustomerPageProps) {
    const { id } = use(params);
    const customer = getCustomerById(id);
    const orders = getCustomerOrders(id);
    const payments = getCustomerPayments(id);

    if (!customer) {
        notFound();
    }

    return (
        <div className="p-6 space-y-6">
            <div className="flex items-center gap-4">
                <Link href="/users">
                    <Button variant="outline" size="sm" className="gap-2">
                        <ArrowLeft className="w-4 h-4" />
                        Back to Customers
                    </Button>
                </Link>
            </div>

            {/* Profile Header */}
            <Card className="p-6 border-border/50 animate-fade-in-up">
                <CustomerProfileHeader customer={customer} />
            </Card>

            {/* Stat Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                {/* Total Orders */}
                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-lg transition-all hover:-translate-y-1 group" style={{ animationDelay: "100ms" }}>
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-xl bg-blue-500/10 flex items-center justify-center group-hover:scale-110 transition-transform">
                            <Cart className="w-6 h-6 text-blue-600" />
                        </div>
                        <div>
                            <p className="text-2xl font-black text-foreground"><AnimatedNumber value={customer.totalOrders} delay={100} /></p>
                            <p className="text-xs font-bold text-muted-foreground uppercase tracking-widest">Orders</p>
                        </div>
                    </div>
                </Card>

                {/* Total Spending */}
                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-lg transition-all hover:-translate-y-1 group" style={{ animationDelay: "200ms" }}>
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-xl bg-[#FE6132]/10 flex items-center justify-center group-hover:scale-110 transition-transform">
                            <TrendingUp className="w-6 h-6 text-[#FE6132]" />
                        </div>
                        <div>
                            <p className="text-2xl font-black text-foreground">
                                GH₵<AnimatedNumber value={customer.totalSpending} delay={200} />
                            </p>
                            <p className="text-xs font-bold text-muted-foreground uppercase tracking-widest">Spent</p>
                        </div>
                    </div>
                </Card>

                {/* Credits Balance */}
                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-lg transition-all hover:-translate-y-1 group" style={{ animationDelay: "300ms" }}>
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-xl bg-green-500/10 flex items-center justify-center group-hover:scale-110 transition-transform">
                            <Wallet className="w-6 h-6 text-green-600" />
                        </div>
                        <div>
                            <p className="text-2xl font-black text-foreground">
                                GH₵<AnimatedNumber value={customer.creditsBalance} delay={300} />
                            </p>
                            <p className="text-xs font-bold text-muted-foreground uppercase tracking-widest">Credits</p>
                        </div>
                    </div>
                </Card>

                {/* Referrals */}
                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-lg transition-all hover:-translate-y-1 group" style={{ animationDelay: "400ms" }}>
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-xl bg-purple-500/10 flex items-center justify-center group-hover:scale-110 transition-transform">
                            <Group className="w-6 h-6 text-purple-600" />
                        </div>
                        <div>
                            <p className="text-2xl font-black text-foreground"><AnimatedNumber value={customer.referralCount} delay={400} /></p>
                            <p className="text-xs font-bold text-muted-foreground uppercase tracking-widest">Referrals</p>
                        </div>
                    </div>
                </Card>
            </div>

            {/* Tabs Section */}
            <Card className="border-border/50 animate-fade-in-up" style={{ animationDelay: "500ms" }}>
                <Tabs defaultValue="personal" className="w-full">
                    <div className="border-b border-border/50">
                        <TabsList className="bg-transparent h-auto p-0 w-full justify-start px-6">
                            <TabsTrigger
                                value="personal"
                                className="rounded-none border-b-2 border-transparent data-[state=active]:border-[#FE6132] data-[state=active]:bg-transparent data-[state=active]:text-foreground text-muted-foreground hover:text-foreground transition-all px-6 py-4 font-medium data-[state=active]:shadow-none"
                            >
                                Personal Info
                            </TabsTrigger>
                            <TabsTrigger
                                value="orders"
                                className="rounded-none border-b-2 border-transparent data-[state=active]:border-[#FE6132] data-[state=active]:bg-transparent data-[state=active]:text-foreground text-muted-foreground hover:text-foreground transition-all px-6 py-4 font-medium data-[state=active]:shadow-none"
                            >
                                Order History
                            </TabsTrigger>
                            <TabsTrigger
                                value="payments"
                                className="rounded-none border-b-2 border-transparent data-[state=active]:border-[#FE6132] data-[state=active]:bg-transparent data-[state=active]:text-foreground text-muted-foreground hover:text-foreground transition-all px-6 py-4 font-medium data-[state=active]:shadow-none"
                            >
                                Payment History
                            </TabsTrigger>
                            <TabsTrigger
                                value="favorites"
                                className="rounded-none border-b-2 border-transparent data-[state=active]:border-[#FE6132] data-[state=active]:bg-transparent data-[state=active]:text-foreground text-muted-foreground hover:text-foreground transition-all px-6 py-4 font-medium data-[state=active]:shadow-none"
                            >
                                Favorites
                            </TabsTrigger>
                            <TabsTrigger
                                value="settings"
                                className="rounded-none border-b-2 border-transparent data-[state=active]:border-[#FE6132] data-[state=active]:bg-transparent data-[state=active]:text-foreground text-muted-foreground hover:text-foreground transition-all px-6 py-4 font-medium data-[state=active]:shadow-none"
                            >
                                Settings
                            </TabsTrigger>
                        </TabsList>
                    </div>

                    {/* Personal Info Tab */}
                    <TabsContent value="personal" className="p-6 space-y-6">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                            <div>
                                <label className="text-sm font-medium text-muted-foreground">Username</label>
                                <p className="mt-1 text-base">{customer.username}</p>
                            </div>
                            <div>
                                <label className="text-sm font-medium text-muted-foreground">Email</label>
                                <div className="mt-1 flex items-center gap-2">
                                    <p className="text-base">{customer.email}</p>
                                    {customer.emailVerified && (
                                        <Badge variant="success" className="text-xs">Verified</Badge>
                                    )}
                                </div>
                            </div>
                            <div>
                                <label className="text-sm font-medium text-muted-foreground">Phone</label>
                                <div className="mt-1 flex items-center gap-2">
                                    <p className="text-base">{customer.phone}</p>
                                    {customer.phoneVerified && (
                                        <Badge variant="success" className="text-xs">Verified</Badge>
                                    )}
                                </div>
                            </div>
                            <div>
                                <label className="text-sm font-medium text-muted-foreground">Account Status</label>
                                <div className="mt-1">
                                    <Badge variant={customer.isActive ? "success" : "destructive"}>
                                        {customer.isActive ? "Active" : "Inactive"}
                                    </Badge>
                                </div>
                            </div>
                            <div>
                                <label className="text-sm font-medium text-muted-foreground">Account Created</label>
                                <p className="mt-1 text-base">{format(new Date(customer.createdAt), "PPP")}</p>
                            </div>
                            <div>
                                <label className="text-sm font-medium text-muted-foreground">Last Seen</label>
                                <p className="mt-1 text-base">
                                    {customer.lastSeen ? format(new Date(customer.lastSeen), "PPP 'at' p") : "Never"}
                                </p>
                            </div>
                        </div>
                    </TabsContent>

                    {/* Order History Tab */}
                    <TabsContent value="orders" className="p-6">
                        {orders.length > 0 ? (
                            <div className="overflow-x-auto">
                                <table className="w-full">
                                    <thead className="bg-muted/50 border-b border-border/50">
                                        <tr>
                                            <th className="text-left p-4 font-semibold text-sm">Order ID</th>
                                            <th className="text-left p-4 font-semibold text-sm">Date</th>
                                            <th className="text-left p-4 font-semibold text-sm">Restaurant</th>
                                            <th className="text-left p-4 font-semibold text-sm">Items</th>
                                            <th className="text-left p-4 font-semibold text-sm">Total</th>
                                            <th className="text-left p-4 font-semibold text-sm">Status</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-border/50">
                                        {orders.map((order) => (
                                            <tr key={order.id} className="hover:bg-muted/30 transition-colors">
                                                <td className="p-4 font-medium">{order.id}</td>
                                                <td className="p-4 text-sm">{format(new Date(order.date), "MMM dd, yyyy")}</td>
                                                <td className="p-4 text-sm">{order.restaurant || "N/A"}</td>
                                                <td className="p-4 text-sm">{order.items}</td>
                                                <td className="p-4 font-medium">
                                                    GH₵{order.total.toLocaleString("en-GH", {
                                                        minimumFractionDigits: 2,
                                                        maximumFractionDigits: 2,
                                                    })}
                                                </td>
                                                <td className="p-4">
                                                    <Badge
                                                        variant={
                                                            order.status === "completed"
                                                                ? "success"
                                                                : order.status === "pending"
                                                                    ? "warning"
                                                                    : "destructive"
                                                        }
                                                    >
                                                        {order.status}
                                                    </Badge>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        ) : (
                            <div className="p-16 text-center animate-fade-in">
                                <div className="flex flex-col items-center justify-center space-y-3">
                                    <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center">
                                        <Cart className="w-8 h-8 text-muted-foreground opacity-20" />
                                    </div>
                                    <div className="space-y-1">
                                        <h3 className="text-lg font-semibold text-foreground/80">No orders yet</h3>
                                        <p className="text-muted-foreground max-w-sm mx-auto text-sm">
                                            This customer hasn't placed any orders on GrabGo platforms yet.
                                        </p>
                                    </div>
                                </div>
                            </div>
                        )}
                    </TabsContent>

                    {/* Payment History Tab */}
                    <TabsContent value="payments" className="p-6">
                        {payments.length > 0 ? (
                            <div className="overflow-x-auto">
                                <table className="w-full">
                                    <thead className="bg-muted/50 border-b border-border/50">
                                        <tr>
                                            <th className="text-left p-4 font-semibold text-sm">Transaction ID</th>
                                            <th className="text-left p-4 font-semibold text-sm">Date</th>
                                            <th className="text-left p-4 font-semibold text-sm">Method</th>
                                            <th className="text-left p-4 font-semibold text-sm">Amount</th>
                                            <th className="text-left p-4 font-semibold text-sm">Status</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-border/50">
                                        {payments.map((payment) => (
                                            <tr key={payment.id} className="hover:bg-muted/30 transition-colors">
                                                <td className="p-4 font-medium">{payment.id}</td>
                                                <td className="p-4 text-sm">{format(new Date(payment.date), "MMM dd, yyyy")}</td>
                                                <td className="p-4 text-sm capitalize">{payment.method.replace("_", " ")}</td>
                                                <td className="p-4 font-medium">
                                                    GH₵{payment.amount.toLocaleString("en-GH", {
                                                        minimumFractionDigits: 2,
                                                        maximumFractionDigits: 2,
                                                    })}
                                                </td>
                                                <td className="p-4">
                                                    <Badge
                                                        variant={
                                                            payment.status === "success"
                                                                ? "success"
                                                                : payment.status === "pending"
                                                                    ? "warning"
                                                                    : "destructive"
                                                        }
                                                    >
                                                        {payment.status}
                                                    </Badge>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        ) : (
                            <div className="p-16 text-center animate-fade-in">
                                <div className="flex flex-col items-center justify-center space-y-3">
                                    <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center">
                                        <Wallet className="w-8 h-8 text-muted-foreground opacity-20" />
                                    </div>
                                    <div className="space-y-1">
                                        <h3 className="text-lg font-semibold text-foreground/80">No payments found</h3>
                                        <p className="text-muted-foreground max-w-sm mx-auto text-sm">
                                            There is no recorded payment transaction history for this customer.
                                        </p>
                                    </div>
                                </div>
                            </div>
                        )}
                    </TabsContent>

                    {/* Favorites Tab */}
                    <TabsContent value="favorites" className="p-6">
                        <div className="space-y-6">
                            {/* Favorite Restaurants */}
                            <div>
                                <h3 className="text-lg font-bold mb-4">Favorite Restaurants</h3>
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                    {/* Mock favorite restaurants */}
                                    <Card className="p-4 border-border/50 hover:shadow-md transition-all">
                                        <div className="flex items-center gap-3">
                                            <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-[#FE6132]/10 to-[#FE6132]/5 flex items-center justify-center">
                                                <span className="text-xl font-bold text-[#FE6132]">P</span>
                                            </div>
                                            <div className="flex-1">
                                                <p className="font-semibold">Pizza Palace</p>
                                                <p className="text-xs text-muted-foreground">Italian • Fast Food</p>
                                            </div>
                                            <Badge variant="success" className="text-xs">⭐ 4.8</Badge>
                                        </div>
                                    </Card>
                                    <Card className="p-4 border-border/50 hover:shadow-md transition-all">
                                        <div className="flex items-center gap-3">
                                            <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-blue-500/10 to-blue-500/5 flex items-center justify-center">
                                                <span className="text-xl font-bold text-blue-600">B</span>
                                            </div>
                                            <div className="flex-1">
                                                <p className="font-semibold">Burger House</p>
                                                <p className="text-xs text-muted-foreground">American • Burgers</p>
                                            </div>
                                            <Badge variant="success" className="text-xs">⭐ 4.7</Badge>
                                        </div>
                                    </Card>
                                    <Card className="p-4 border-border/50 hover:shadow-md transition-all">
                                        <div className="flex items-center gap-3">
                                            <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-green-500/10 to-green-500/5 flex items-center justify-center">
                                                <span className="text-xl font-bold text-green-600">S</span>
                                            </div>
                                            <div className="flex-1">
                                                <p className="font-semibold">Sushi Bar</p>
                                                <p className="text-xs text-muted-foreground">Japanese • Sushi</p>
                                            </div>
                                            <Badge variant="success" className="text-xs">⭐ 4.9</Badge>
                                        </div>
                                    </Card>
                                </div>
                            </div>

                            {/* Favorite Grocery Stores */}
                            <div>
                                <h3 className="text-lg font-bold mb-4">Favorite Grocery Stores</h3>
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                    {/* Mock favorite grocery stores */}
                                    <Card className="p-4 border-border/50 hover:shadow-md transition-all">
                                        <div className="flex items-center gap-3">
                                            <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-purple-500/10 to-purple-500/5 flex items-center justify-center">
                                                <span className="text-xl font-bold text-purple-600">F</span>
                                            </div>
                                            <div className="flex-1">
                                                <p className="font-semibold">Fresh Mart</p>
                                                <p className="text-xs text-muted-foreground">Groceries • Fresh Produce</p>
                                            </div>
                                            <Badge variant="success" className="text-xs">⭐ 4.5</Badge>
                                        </div>
                                    </Card>
                                    <Card className="p-4 border-border/50 hover:shadow-md transition-all">
                                        <div className="flex items-center gap-3">
                                            <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-orange-500/10 to-orange-500/5 flex items-center justify-center">
                                                <span className="text-xl font-bold text-orange-600">O</span>
                                            </div>
                                            <div className="flex-1">
                                                <p className="font-semibold">Organic Roots</p>
                                                <p className="text-xs text-muted-foreground">Organic • Health Foods</p>
                                            </div>
                                            <Badge variant="success" className="text-xs">⭐ 4.6</Badge>
                                        </div>
                                    </Card>
                                </div>
                            </div>

                            {/* Favorite Food Items */}
                            <div>
                                <h3 className="text-lg font-bold mb-4">Favorite Food Items</h3>
                                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                                    {/* Mock favorite food items */}
                                    <Card className="p-4 border-border/50 hover:shadow-md transition-all">
                                        <div className="space-y-2">
                                            <div className="flex items-start justify-between">
                                                <div className="flex-1">
                                                    <p className="font-semibold">Margherita Pizza</p>
                                                    <p className="text-xs text-muted-foreground">Pizza Palace</p>
                                                </div>
                                                <p className="font-bold text-[#FE6132]">GH₵45</p>
                                            </div>
                                            <p className="text-xs text-muted-foreground line-clamp-2">Classic pizza with tomato sauce, mozzarella, and basil</p>
                                        </div>
                                    </Card>
                                    <Card className="p-4 border-border/50 hover:shadow-md transition-all">
                                        <div className="space-y-2">
                                            <div className="flex items-start justify-between">
                                                <div className="flex-1">
                                                    <p className="font-semibold">Classic Burger</p>
                                                    <p className="text-xs text-muted-foreground">Burger House</p>
                                                </div>
                                                <p className="font-bold text-[#FE6132]">GH₵32</p>
                                            </div>
                                            <p className="text-xs text-muted-foreground line-clamp-2">Juicy beef patty with lettuce, tomato, and special sauce</p>
                                        </div>
                                    </Card>
                                    <Card className="p-4 border-border/50 hover:shadow-md transition-all">
                                        <div className="space-y-2">
                                            <div className="flex items-start justify-between">
                                                <div className="flex-1">
                                                    <p className="font-semibold">California Roll</p>
                                                    <p className="text-xs text-muted-foreground">Sushi Bar</p>
                                                </div>
                                                <p className="font-bold text-[#FE6132]">GH₵28</p>
                                            </div>
                                            <p className="text-xs text-muted-foreground line-clamp-2">Fresh sushi roll with crab, avocado, and cucumber</p>
                                        </div>
                                    </Card>
                                </div>
                            </div>

                            {/* Favorite Grocery Items */}
                            <div>
                                <h3 className="text-lg font-bold mb-4">Favorite Grocery Items</h3>
                                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                                    {/* Mock favorite grocery items */}
                                    <Card className="p-4 border-border/50 hover:shadow-md transition-all">
                                        <div className="space-y-2">
                                            <div className="flex items-start justify-between">
                                                <div className="flex-1">
                                                    <p className="font-semibold">Organic Milk</p>
                                                    <p className="text-xs text-muted-foreground">Fresh Mart</p>
                                                </div>
                                                <p className="font-bold text-[#FE6132]">GH₵15.50</p>
                                            </div>
                                            <p className="text-xs text-muted-foreground line-clamp-2">1 liter of fresh organic whole milk</p>
                                        </div>
                                    </Card>
                                    <Card className="p-4 border-border/50 hover:shadow-md transition-all">
                                        <div className="space-y-2">
                                            <div className="flex items-start justify-between">
                                                <div className="flex-1">
                                                    <p className="font-semibold">Brown Bread</p>
                                                    <p className="text-xs text-muted-foreground">Fresh Mart</p>
                                                </div>
                                                <p className="font-bold text-[#FE6132]">GH₵12</p>
                                            </div>
                                            <p className="text-xs text-muted-foreground line-clamp-2">Whole wheat high fiber bread</p>
                                        </div>
                                    </Card>
                                    <Card className="p-4 border-border/50 hover:shadow-md transition-all">
                                        <div className="space-y-2">
                                            <div className="flex items-start justify-between">
                                                <div className="flex-1">
                                                    <p className="font-semibold">Fresh Avocados</p>
                                                    <p className="text-xs text-muted-foreground">Organic Roots</p>
                                                </div>
                                                <p className="font-bold text-[#FE6132]">GH₵8/each</p>
                                            </div>
                                            <p className="text-xs text-muted-foreground line-clamp-2">Ripe organic avocados, perfect for salads</p>
                                        </div>
                                    </Card>
                                </div>
                            </div>
                        </div>
                    </TabsContent>

                    {/* Notification Settings Tab */}
                    <TabsContent value="settings" className="p-6">
                        <div className="space-y-6">
                            <div>
                                <h3 className="text-lg font-bold mb-2">Notification Preferences</h3>
                                <p className="text-sm text-muted-foreground mb-6">Manage how this customer receives notifications</p>
                            </div>

                            {/* Order Notifications */}
                            <div className="space-y-4">
                                <h4 className="font-semibold text-sm">Order Updates</h4>
                                <div className="space-y-3">
                                    <div className="flex items-center justify-between p-3 rounded-lg border border-border/50">
                                        <div>
                                            <p className="font-medium text-sm">Order Status Updates</p>
                                            <p className="text-xs text-muted-foreground">Notifications about order preparation and delivery</p>
                                        </div>
                                        <Badge variant="success">Enabled</Badge>
                                    </div>
                                    <div className="flex items-center justify-between p-3 rounded-lg border border-border/50">
                                        <div>
                                            <p className="font-medium text-sm">Delivery Notifications</p>
                                            <p className="text-xs text-muted-foreground">Updates when rider is nearby</p>
                                        </div>
                                        <Badge variant="success">Enabled</Badge>
                                    </div>
                                </div>
                            </div>

                            {/* Promotional Notifications */}
                            <div className="space-y-4">
                                <h4 className="font-semibold text-sm">Promotions & Offers</h4>
                                <div className="space-y-3">
                                    <div className="flex items-center justify-between p-3 rounded-lg border border-border/50">
                                        <div>
                                            <p className="font-medium text-sm">Special Offers</p>
                                            <p className="text-xs text-muted-foreground">Discounts and promotional campaigns</p>
                                        </div>
                                        <Badge variant="success">Enabled</Badge>
                                    </div>
                                    <div className="flex items-center justify-between p-3 rounded-lg border border-border/50">
                                        <div>
                                            <p className="font-medium text-sm">New Restaurant Alerts</p>
                                            <p className="text-xs text-muted-foreground">Notifications about new restaurants</p>
                                        </div>
                                        <Badge className="bg-gray-200 text-gray-700">Disabled</Badge>
                                    </div>
                                </div>
                            </div>

                            {/* Engagement Notifications */}
                            <div className="space-y-4">
                                <h4 className="font-semibold text-sm">Engagement</h4>
                                <div className="space-y-3">
                                    <div className="flex items-center justify-between p-3 rounded-lg border border-border/50">
                                        <div>
                                            <p className="font-medium text-sm">Meal Time Nudges</p>
                                            <p className="text-xs text-muted-foreground">Reminders during breakfast, lunch, and dinner</p>
                                        </div>
                                        <Badge variant="success">Enabled</Badge>
                                    </div>
                                    <div className="flex items-center justify-between p-3 rounded-lg border border-border/50">
                                        <div>
                                            <p className="font-medium text-sm">Cart Abandonment</p>
                                            <p className="text-xs text-muted-foreground">Reminders about items left in cart</p>
                                        </div>
                                        <Badge variant="success">Enabled</Badge>
                                    </div>
                                    <div className="flex items-center justify-between p-3 rounded-lg border border-border/50">
                                        <div>
                                            <p className="font-medium text-sm">Referral Reminders</p>
                                            <p className="text-xs text-muted-foreground">Encourage sharing with friends</p>
                                        </div>
                                        <Badge className="bg-gray-200 text-gray-700">Disabled</Badge>
                                    </div>
                                </div>
                            </div>

                            {/* Communication Channels */}
                            <div className="space-y-4">
                                <h4 className="font-semibold text-sm">Communication Channels</h4>
                                <div className="space-y-3">
                                    <div className="flex items-center justify-between p-3 rounded-lg border border-border/50">
                                        <div>
                                            <p className="font-medium text-sm">Push Notifications</p>
                                            <p className="text-xs text-muted-foreground">Mobile app notifications</p>
                                        </div>
                                        <Badge variant="success">Enabled</Badge>
                                    </div>
                                    <div className="flex items-center justify-between p-3 rounded-lg border border-border/50">
                                        <div>
                                            <p className="font-medium text-sm">Email Notifications</p>
                                            <p className="text-xs text-muted-foreground">Order confirmations and receipts</p>
                                        </div>
                                        <Badge variant="success">Enabled</Badge>
                                    </div>
                                    <div className="flex items-center justify-between p-3 rounded-lg border border-border/50">
                                        <div>
                                            <p className="font-medium text-sm">SMS Notifications</p>
                                            <p className="text-xs text-muted-foreground">Text message updates</p>
                                        </div>
                                        <Badge className="bg-gray-200 text-gray-700">Disabled</Badge>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </TabsContent>
                </Tabs>
            </Card>
        </div>
    );
}
