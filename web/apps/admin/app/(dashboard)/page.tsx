"use client";

import { useEffect, useState } from "react";
import { Card } from "@grabgo/ui";
import {
    Group,
    Shop,
    Cart,
    Cycling,
    Clock,
} from "iconoir-react";
import {
    TrendingUp,
    TrendingDown,
    CheckCircle,
} from "lucide-react";
import { LineChart } from "../../components/charts/LineChart";
import { PieChart } from "../../components/charts/PieChart";
import { BarChart } from "../../components/charts/BarChart";
import {
    mockRevenueData,
    mockOrderStatusData,
    mockPeakHoursData,
    mockTopVendors,
    mockPopularItems,
    getTodayStats,
    getWeekStats
} from "../../lib/mockAnalyticsData";

interface StatCardProps {
    title: string;
    value: string | number;
    change?: number;
    icon: React.ElementType;
    delay?: number;
}

function StatCard({ title, value, change, icon: Icon, delay = 0 }: StatCardProps) {
    const [count, setCount] = useState(0);
    const targetValue = typeof value === "number" ? value : parseInt(value) || 0;

    // Count-up animation
    useEffect(() => {
        const duration = 1000; // 1 second
        const steps = 30;
        const increment = targetValue / steps;
        let current = 0;

        const timer = setTimeout(() => {
            const interval = setInterval(() => {
                current += increment;
                if (current >= targetValue) {
                    setCount(targetValue);
                    clearInterval(interval);
                } else {
                    setCount(Math.floor(current));
                }
            }, duration / steps);

            return () => clearInterval(interval);
        }, delay);

        return () => clearTimeout(timer);
    }, [targetValue, delay]);

    return (
        <Card
            className="p-6 hover:-translate-y-1 transition-all duration-300 shadow-lg hover:shadow-2xl hover:shadow-[#FE6132]/10 animate-fade-in-up border-border/50 bg-card/50 backdrop-blur-sm group"
            style={{ animationDelay: `${delay}ms` }}
        >
            <div className="flex items-start justify-between">
                <div className="space-y-2">
                    <p className="text-sm font-medium text-muted-foreground">{title}</p>
                    <div className="flex items-baseline gap-2">
                        <h3 className="text-3xl font-bold text-foreground">
                            {typeof value === "number" ? count.toLocaleString() : value}
                        </h3>
                        {change !== undefined && (
                            <span
                                className={`flex items-center text-sm font-medium ${change >= 0 ? "text-green-600" : "text-red-600"
                                    }`}
                            >
                                {change >= 0 ? (
                                    <TrendingUp className="w-4 h-4 mr-1" />
                                ) : (
                                    <TrendingDown className="w-4 h-4 mr-1" />
                                )}
                                {Math.abs(change)}%
                            </span>
                        )}
                    </div>
                </div>
                <div className="w-12 h-12 rounded-md flex items-center justify-center bg-gradient-to-br from-[#FE6132]/10 to-[#FE6132]/5">
                    <Icon className="w-6 h-6 text-[#FE6132]" strokeWidth={2} />
                </div>
            </div>
        </Card>
    );
}

export default function DashboardPage() {
    return (
        <div className="space-y-6">
            {/* Page Header */}
            <div className="animate-fade-in">
                <h1 className="text-3xl font-bold text-foreground">Dashboard</h1>
                <p className="text-muted-foreground mt-1">
                    Welcome back! Here's what's happening with GrabGo today.
                </p>
            </div>

            {/* Stats Grid */}
            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
                <StatCard
                    title="Total Users"
                    value={12458}
                    change={12.5}
                    icon={Group}
                    delay={0}
                />
                <StatCard
                    title="Active Vendors"
                    value={342}
                    change={8.2}
                    icon={Shop}
                    delay={100}
                />
                <StatCard
                    title="Orders Today"
                    value={1247}
                    change={-3.1}
                    icon={Cart}
                    delay={200}
                />
                <StatCard
                    title="Active Riders"
                    value={89}
                    change={5.7}
                    icon={Cycling}
                    delay={300}
                />
            </div>

            {/* Quick Stats Row */}
            <div className="grid gap-6 md:grid-cols-3">
                <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "400ms" }}>
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-md flex items-center justify-center bg-green-500/10">
                            <CheckCircle className="w-6 h-6 text-green-600" />
                        </div>
                        <div>
                            <p className="text-sm text-muted-foreground">Completed Today</p>
                            <p className="text-2xl font-bold">1,124</p>
                        </div>
                    </div>
                </Card>

                <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "500ms" }}>
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-md flex items-center justify-center bg-yellow-500/10">
                            <Clock className="w-6 h-6 text-yellow-600" />
                        </div>
                        <div>
                            <p className="text-sm text-muted-foreground">Pending Orders</p>
                            <p className="text-2xl font-bold">23</p>
                        </div>
                    </div>
                </Card>

                <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "600ms" }}>
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-md flex items-center justify-center bg-[#FE6132]/10">
                            <TrendingUp className="w-6 h-6 text-[#FE6132]" />
                        </div>
                        <div>
                            <p className="text-sm text-muted-foreground">Revenue Today</p>
                            <p className="text-2xl font-bold">GH₵ 45,230</p>
                        </div>
                    </div>
                </Card>
            </div>

            {/* Analytics Charts */}
            <div className="grid gap-6 lg:grid-cols-2">
                {/* Revenue Trend Chart */}
                <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "700ms" }}>
                    <div className="flex items-center justify-between mb-6">
                        <div>
                            <h3 className="text-lg font-semibold">Revenue Trend</h3>
                            <p className="text-sm text-muted-foreground">Last 7 days</p>
                        </div>
                        <div className="text-right">
                            <p className="text-2xl font-bold text-[#FE6132]">
                                GH₵ {mockRevenueData.reduce((sum, day) => sum + day.revenue, 0).toLocaleString()}
                            </p>
                            <p className="text-sm text-muted-foreground">Total revenue</p>
                        </div>
                    </div>
                    <LineChart
                        data={mockRevenueData.map(d => ({
                            ...d,
                            date: new Date(d.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
                        }))}
                        xKey="date"
                        yKey="revenue"
                        height={250}
                    />
                </Card>

                {/* Order Status Distribution */}
                <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "800ms" }}>
                    <div className="mb-6">
                        <h3 className="text-lg font-semibold">Order Status Distribution</h3>
                        <p className="text-sm text-muted-foreground">Current orders breakdown</p>
                    </div>
                    <PieChart
                        data={mockOrderStatusData}
                        dataKey="count"
                        nameKey="status"
                        height={250}
                    />
                </Card>
            </div>

            {/* Peak Hours Chart */}
            <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "900ms" }}>
                <div className="mb-6">
                    <h3 className="text-lg font-semibold">Peak Hours</h3>
                    <p className="text-sm text-muted-foreground">Orders by hour (24-hour view)</p>
                </div>
                <BarChart
                    data={mockPeakHoursData}
                    xKey="hour"
                    yKey="orders"
                    height={250}
                />
            </Card>

            {/* Top Performers */}
            <div className="grid gap-6 lg:grid-cols-2">
                {/* Top Performing Vendors */}
                <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "1000ms" }}>
                    <div className="flex items-center justify-between mb-6">
                        <div>
                            <h3 className="text-lg font-semibold">Top Performing Vendors</h3>
                            <p className="text-sm text-muted-foreground">By revenue (this month)</p>
                        </div>
                        <Shop className="w-5 h-5 text-[#FE6132]" />
                    </div>
                    <div className="space-y-3">
                        {mockTopVendors.slice(0, 5).map((vendor, index) => (
                            <div key={vendor.id} className="flex items-center justify-between p-3 rounded-md bg-accent/50 hover:bg-accent transition-colors">
                                <div className="flex items-center gap-3">
                                    <div className="w-8 h-8 rounded-md bg-gradient-to-br from-[#FE6132]/20 to-[#FE6132]/10 flex items-center justify-center">
                                        <span className="text-sm font-bold text-[#FE6132]">#{index + 1}</span>
                                    </div>
                                    <div>
                                        <div className="flex items-center gap-2">
                                            <p className="font-medium">{vendor.name}</p>
                                            <span className={`text-[10px] px-1.5 py-0.5 rounded-full font-medium capitalize ${vendor.type === 'food' ? 'bg-orange-100 text-orange-700' :
                                                vendor.type === 'grocery' ? 'bg-green-100 text-green-700' :
                                                    vendor.type === 'pharmacy' ? 'bg-blue-100 text-blue-700' :
                                                        'bg-purple-100 text-purple-700'
                                                }`}>
                                                {vendor.type}
                                            </span>
                                        </div>
                                        <p className="text-xs text-muted-foreground">{vendor.orders} orders</p>
                                    </div>
                                </div>
                                <div className="text-right">
                                    <p className="font-semibold">GH₵ {vendor.revenue.toLocaleString()}</p>
                                    <div className="flex items-center gap-1 text-xs text-muted-foreground">
                                        <span>⭐</span>
                                        <span>{vendor.rating}</span>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                </Card>

                {/* Popular Items */}
                <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "1100ms" }}>
                    <div className="flex items-center justify-between mb-6">
                        <div>
                            <h3 className="text-lg font-semibold">Popular Items</h3>
                            <p className="text-sm text-muted-foreground">Most ordered across all services</p>
                        </div>
                        <Cart className="w-5 h-5 text-[#FE6132]" />
                    </div>
                    <div className="space-y-3">
                        {mockPopularItems.slice(0, 5).map((item, index) => (
                            <div key={item.id} className="flex items-center justify-between p-3 rounded-md bg-accent/50 hover:bg-accent transition-colors">
                                <div className="flex items-center gap-3">
                                    <div className="w-8 h-8 rounded-md bg-gradient-to-br from-[#FE6132]/20 to-[#FE6132]/10 flex items-center justify-center">
                                        <span className="text-sm font-bold text-[#FE6132]">#{index + 1}</span>
                                    </div>
                                    <div>
                                        <div className="flex items-center gap-2">
                                            <p className="font-medium">{item.name}</p>
                                            <span className={`text-[10px] px-1.5 py-0.5 rounded-full font-medium capitalize ${item.type === 'food' ? 'bg-orange-100 text-orange-700' :
                                                    item.type === 'grocery' ? 'bg-green-100 text-green-700' :
                                                        item.type === 'pharmacy' ? 'bg-blue-100 text-blue-700' :
                                                            'bg-purple-100 text-purple-700'
                                                }`}>
                                                {item.type}
                                            </span>
                                        </div>
                                        <p className="text-xs text-muted-foreground">{item.vendor}</p>
                                    </div>
                                </div>
                                <div className="text-right">
                                    <p className="font-semibold">{item.orders} orders</p>
                                    <p className="text-xs text-muted-foreground">GH₵ {item.revenue.toLocaleString()}</p>
                                </div>
                            </div>
                        ))}
                    </div>
                </Card>
            </div>

            {/* Pending Actions */}
            <div className="grid gap-6 md:grid-cols-2">
                <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "700ms" }}>
                    <h3 className="text-lg font-semibold mb-4">Pending Approvals</h3>
                    <div className="space-y-3">
                        <div className="flex items-center justify-between p-3 rounded-md bg-accent/50 hover:bg-accent transition-colors cursor-pointer">
                            <div className="flex items-center gap-3">
                                <div className="w-10 h-10 rounded-md bg-[#FE6132]/10 flex items-center justify-center">
                                    <Shop className="w-5 h-5 text-[#FE6132]" />
                                </div>
                                <div>
                                    <p className="font-medium">New Vendor Applications</p>
                                    <p className="text-sm text-muted-foreground">5 pending review</p>
                                </div>
                            </div>
                            <span className="text-sm font-medium text-[#FE6132]">Review →</span>
                        </div>

                        <div className="flex items-center justify-between p-3 rounded-md bg-accent/50 hover:bg-accent transition-colors cursor-pointer">
                            <div className="flex items-center gap-3">
                                <div className="w-10 h-10 rounded-md bg-[#FE6132]/10 flex items-center justify-center">
                                    <Cycling className="w-5 h-5 text-[#FE6132]" />
                                </div>
                                <div>
                                    <p className="font-medium">Rider Verifications</p>
                                    <p className="text-sm text-muted-foreground">8 pending verification</p>
                                </div>
                            </div>
                            <span className="text-sm font-medium text-[#FE6132]">Review →</span>
                        </div>
                    </div>
                </Card>

                <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "800ms" }}>
                    <h3 className="text-lg font-semibold mb-4">Recent Activity</h3>
                    <div className="space-y-3">
                        <div className="flex items-start gap-3 p-3 rounded-md bg-accent/50">
                            <div className="w-2 h-2 rounded-full bg-green-500 mt-2" />
                            <div className="flex-1">
                                <p className="text-sm font-medium">New order placed</p>
                                <p className="text-xs text-muted-foreground">Order #ORD-1234 • 2 min ago</p>
                            </div>
                        </div>

                        <div className="flex items-start gap-3 p-3 rounded-md bg-accent/50">
                            <div className="w-2 h-2 rounded-full bg-blue-500 mt-2" />
                            <div className="flex-1">
                                <p className="text-sm font-medium">Vendor approved</p>
                                <p className="text-xs text-muted-foreground">Tasty Bites • 15 min ago</p>
                            </div>
                        </div>

                        <div className="flex items-start gap-3 p-3 rounded-md bg-accent/50">
                            <div className="w-2 h-2 rounded-full bg-yellow-500 mt-2" />
                            <div className="flex-1">
                                <p className="text-sm font-medium">Rider verification pending</p>
                                <p className="text-xs text-muted-foreground">John Doe • 1 hour ago</p>
                            </div>
                        </div>
                    </div>
                </Card>
            </div>
        </div>
    );
}
