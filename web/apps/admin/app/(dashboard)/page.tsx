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
        }, delay + 300); // Standardize entry offset

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
                <div className="w-12 h-12 rounded-md flex items-center justify-center bg-linear-to-br from-[#FE6132]/10 to-[#FE6132]/5">
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
            <div className="animate-fade-in-up">
                <h1 className="text-4xl font-extrabold tracking-tight text-foreground">Dashboard</h1>
                <p className="text-muted-foreground mt-2 text-lg">
                    Welcome back! Here&apos;s a real-time overview of GrabGo performance.
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
                <Card
                    className="p-6 border-border/50 animate-fade-in-up hover:shadow-lg transition-all hover:-translate-y-1 group"
                    style={{ animationDelay: "400ms" }}
                >
                    <div className="flex items-center gap-4">
                        <div className="w-14 h-14 rounded-2xl flex items-center justify-center bg-green-500/10 group-hover:scale-110 transition-transform">
                            <CheckCircle className="w-7 h-7 text-green-600" />
                        </div>
                        <div>
                            <p className="text-sm font-bold text-muted-foreground uppercase tracking-wider">Completed Today</p>
                            <p className="text-3xl font-black">1,124</p>
                        </div>
                    </div>
                </Card>

                <Card
                    className="p-6 border-border/50 animate-fade-in-up hover:shadow-lg transition-all hover:-translate-y-1 group"
                    style={{ animationDelay: "500ms" }}
                >
                    <div className="flex items-center gap-4">
                        <div className="w-14 h-14 rounded-2xl flex items-center justify-center bg-yellow-500/10 group-hover:scale-110 transition-transform">
                            <Clock className="w-7 h-7 text-yellow-600" />
                        </div>
                        <div>
                            <p className="text-sm font-bold text-muted-foreground uppercase tracking-wider">Pending Orders</p>
                            <p className="text-3xl font-black">23</p>
                        </div>
                    </div>
                </Card>

                <Card
                    className="p-6 border-border/50 animate-fade-in-up hover:shadow-lg transition-all hover:-translate-y-1 group"
                    style={{ animationDelay: "600ms" }}
                >
                    <div className="flex items-center gap-4">
                        <div className="w-14 h-14 rounded-2xl flex items-center justify-center bg-[#FE6132]/10 group-hover:scale-110 transition-transform">
                            <TrendingUp className="w-7 h-7 text-[#FE6132]" />
                        </div>
                        <div>
                            <p className="text-sm font-bold text-muted-foreground uppercase tracking-wider">Revenue Today</p>
                            <p className="text-3xl font-black">GH₵ 45,230</p>
                        </div>
                    </div>
                </Card>
            </div>

            {/* Analytics Charts */}
            <div className="grid gap-6 lg:grid-cols-2">
                {/* Revenue Trend Chart */}
                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-md transition-all" style={{ animationDelay: "700ms" }}>
                    <div className="flex items-center justify-between mb-8">
                        <div>
                            <h3 className="text-xl font-bold">Revenue Trend</h3>
                            <p className="text-sm font-medium text-muted-foreground mt-1">Daily revenue performance across all services</p>
                        </div>
                        <div className="text-right p-3 rounded-xl bg-orange-500/10 border border-[#FE6132]/20">
                            <p className="text-xs font-bold text-[#FE6132]/80 uppercase tracking-wider mb-1">Total Revenue</p>
                            <p className="text-2xl font-black text-[#FE6132]">
                                GH₵ {mockRevenueData.reduce((sum, day) => sum + day.revenue, 0).toLocaleString()}
                            </p>
                        </div>
                    </div>
                    <div className="h-[250px] w-full">
                        <LineChart
                            data={mockRevenueData.map(d => ({
                                ...d,
                                date: new Date(d.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
                            }))}
                            xKey="date"
                            yKey="revenue"
                            height={250}
                        />
                    </div>
                </Card>

                {/* Order Status Distribution */}
                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-md transition-all" style={{ animationDelay: "800ms" }}>
                    <div className="mb-8">
                        <h3 className="text-xl font-bold">Order Live Status</h3>
                        <p className="text-sm font-medium text-muted-foreground mt-1">Real-time breakdown of current order states</p>
                    </div>
                    <div className="h-[250px] w-full flex items-center justify-center">
                        <PieChart
                            data={mockOrderStatusData}
                            dataKey="count"
                            nameKey="status"
                            height={250}
                        />
                    </div>
                </Card>
            </div>

            {/* Peak Hours Chart */}
            <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-md transition-all" style={{ animationDelay: "900ms" }}>
                <div className="mb-8">
                    <h3 className="text-xl font-bold">Busiest Store Hours</h3>
                    <p className="text-sm font-medium text-muted-foreground mt-1">Aggregated order volume by hour (24h system)</p>
                </div>
                <div className="h-[250px]">
                    <BarChart
                        data={mockPeakHoursData}
                        xKey="hour"
                        yKey="orders"
                        height={250}
                    />
                </div>
            </Card>

            {/* Top Performers */}
            <div className="grid gap-6 lg:grid-cols-2">
                {/* Top Performing Vendors */}
                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-md transition-all" style={{ animationDelay: "1000ms" }}>
                    <div className="flex items-center justify-between mb-6">
                        <div>
                            <h3 className="text-xl font-bold text-foreground">Elite Vendors</h3>
                            <p className="text-sm font-medium text-muted-foreground mt-1">Highest grossing stores this month</p>
                        </div>
                        <div className="p-2.5 rounded-xl bg-[#FE6132]/10">
                            <Shop className="w-5 h-5 text-[#FE6132]" />
                        </div>
                    </div>
                    <div className="space-y-3">
                        {mockTopVendors.slice(0, 5).map((vendor, index) => (
                            <div
                                key={vendor.id}
                                className="flex items-center justify-between p-3.5 rounded-xl bg-accent/30 hover:bg-accent/60 transition-all cursor-pointer group animate-fade-in-up"
                                style={{ animationDelay: `${1100 + index * 50}ms` }}
                            >
                                <div className="flex items-center gap-4">
                                    <div className="w-10 h-10 rounded-xl bg-linear-to-br from-[#FE6132] to-[#FE6132]/80 flex items-center justify-center shadow-sm group-hover:scale-110 transition-transform">
                                        <span className="text-sm font-black text-white">{index + 1}</span>
                                    </div>
                                    <div>
                                        <div className="flex items-center gap-2">
                                            <p className="font-bold text-foreground">{vendor.name}</p>
                                            <span className={`text-[9px] px-2 py-0.5 rounded-full font-black uppercase tracking-widest ${vendor.type === 'food' ? 'bg-orange-500/10 text-orange-600 dark:bg-orange-500/20 dark:text-orange-400' :
                                                vendor.type === 'grocery' ? 'bg-green-500/10 text-green-600 dark:bg-green-500/20 dark:text-green-400' :
                                                    vendor.type === 'pharmacy' ? 'bg-blue-500/10 text-blue-600 dark:bg-blue-500/20 dark:text-blue-400' :
                                                        'bg-purple-500/10 text-purple-600 dark:bg-purple-500/20 dark:text-purple-400'
                                                }`}>
                                                {vendor.type}
                                            </span>
                                        </div>
                                        <p className="text-xs font-bold text-muted-foreground mt-0.5">{vendor.orders.toLocaleString()} Successful Orders</p>
                                    </div>
                                </div>
                                <div className="text-right">
                                    <p className="font-black text-foreground">GH₵ {vendor.revenue.toLocaleString()}</p>
                                    <div className="flex items-center justify-end gap-1 text-xs font-bold text-orange-600">
                                        <span>⭐</span>
                                        <span>{vendor.rating.toFixed(1)}</span>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                </Card>

                {/* Popular Items */}
                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-md transition-all" style={{ animationDelay: "1100ms" }}>
                    <div className="flex items-center justify-between mb-6">
                        <div>
                            <h3 className="text-xl font-bold text-foreground">Trending Goods</h3>
                            <p className="text-sm font-medium text-muted-foreground mt-1">Most loved items across the platform</p>
                        </div>
                        <div className="p-2.5 rounded-xl bg-[#FE6132]/10">
                            <Cart className="w-5 h-5 text-[#FE6132]" />
                        </div>
                    </div>
                    <div className="space-y-3">
                        {mockPopularItems.slice(0, 5).map((item, index) => (
                            <div
                                key={item.id}
                                className="flex items-center justify-between p-3.5 rounded-xl bg-accent/30 hover:bg-accent/60 transition-all cursor-pointer group animate-fade-in-up"
                                style={{ animationDelay: `${1200 + index * 50}ms` }}
                            >
                                <div className="flex items-center gap-4">
                                    <div className="w-10 h-10 rounded-xl bg-[#FE6132]/10 flex items-center justify-center shadow-inner group-hover:scale-110 transition-transform">
                                        <span className="text-sm font-black text-[#FE6132]">{index + 1}</span>
                                    </div>
                                    <div>
                                        <div className="flex items-center gap-2">
                                            <p className="font-bold text-foreground">{item.name}</p>
                                            <span className={`text-[9px] px-2 py-0.5 rounded-full font-black uppercase tracking-widest ${item.type === 'food' ? 'bg-orange-500/10 text-orange-600 dark:bg-orange-500/20 dark:text-orange-400' :
                                                item.type === 'grocery' ? 'bg-green-500/10 text-green-600 dark:bg-green-500/20 dark:text-green-400' :
                                                    item.type === 'pharmacy' ? 'bg-blue-500/10 text-blue-600 dark:bg-blue-500/20 dark:text-blue-400' :
                                                        'bg-purple-500/10 text-purple-600 dark:bg-purple-500/20 dark:text-purple-400'
                                                }`}>
                                                {item.type}
                                            </span>
                                        </div>
                                        <p className="text-xs font-bold text-muted-foreground mt-0.5">from {item.vendor}</p>
                                    </div>
                                </div>
                                <div className="text-right">
                                    <p className="font-black text-foreground">{item.orders.toLocaleString()} Sold</p>
                                    <p className="text-xs font-bold text-muted-foreground">GH₵ {item.revenue.toLocaleString()}</p>
                                </div>
                            </div>
                        ))}
                    </div>
                </Card>
            </div>

            {/* Pending Actions */}
            <div className="grid gap-6 md:grid-cols-2">
                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-md transition-all" style={{ animationDelay: "1300ms" }}>
                    <h3 className="text-xl font-bold mb-6 flex items-center gap-2">
                        <span className="relative flex h-3 w-3">
                            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-400 opacity-75"></span>
                            <span className="relative inline-flex rounded-full h-3 w-3 bg-[#FE6132]"></span>
                        </span>
                        Pending Approvals
                    </h3>
                    <div className="space-y-3">
                        <div className="flex items-center justify-between p-4 rounded-xl bg-orange-500/10 border border-[#FE6132]/20 hover:bg-orange-500/20 transition-all cursor-pointer group">
                            <div className="flex items-center gap-4">
                                <div className="w-12 h-12 rounded-xl bg-card border border-[#FE6132]/20 flex items-center justify-center shadow-sm group-hover:scale-110 transition-transform text-[#FE6132]">
                                    <Shop className="w-6 h-6" />
                                </div>
                                <div>
                                    <p className="font-bold text-[#FE6132]">Vendor Applications</p>
                                    <p className="text-xs font-bold text-[#FE6132]/60 uppercase tracking-tighter">5 stores awaiting review</p>
                                </div>
                            </div>
                            <span className="text-sm font-black text-[#FE6132] group-hover:translate-x-1 transition-transform">GO →</span>
                        </div>

                        <div className="flex items-center justify-between p-4 rounded-xl bg-blue-500/10 border border-blue-500/20 hover:bg-blue-500/20 transition-all cursor-pointer group">
                            <div className="flex items-center gap-4">
                                <div className="w-12 h-12 rounded-xl bg-card border border-blue-500/20 flex items-center justify-center shadow-sm group-hover:scale-110 transition-transform text-blue-500">
                                    <Cycling className="w-6 h-6" />
                                </div>
                                <div>
                                    <p className="font-bold text-blue-500">Rider Onboarding</p>
                                    <p className="text-xs font-bold text-blue-500/60 uppercase tracking-tighter">8 riders pending check</p>
                                </div>
                            </div>
                            <span className="text-sm font-black text-blue-500 group-hover:translate-x-1 transition-transform">GO →</span>
                        </div>
                    </div>
                </Card>

                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-md transition-all" style={{ animationDelay: "1400ms" }}>
                    <h3 className="text-xl font-bold mb-6">Recent Activity Stream</h3>
                    <div className="space-y-4">
                        <div className="flex items-start gap-4 p-3.5 rounded-xl bg-accent/30 hover:bg-accent/50 transition-colors border border-transparent hover:border-border/50">
                            <div className="w-3 h-3 rounded-full bg-green-500 mt-1.5 shadow-[0_0_10px_rgba(34,197,94,0.3)] animate-pulse" />
                            <div className="flex-1">
                                <p className="text-sm font-bold text-foreground">New order successfully placed</p>
                                <p className="text-xs font-bold text-muted-foreground mt-0.5">Order #ORD-1234 • <span className="text-green-600">2 min ago</span></p>
                            </div>
                        </div>

                        <div className="flex items-start gap-4 p-3.5 rounded-xl bg-accent/30 hover:bg-accent/50 transition-colors border border-transparent hover:border-border/50">
                            <div className="w-3 h-3 rounded-full bg-blue-500 mt-1.5 shadow-[0_0_10px_rgba(59,130,246,0.3)]" />
                            <div className="flex-1">
                                <p className="text-sm font-bold text-foreground">Premium Vendor approved</p>
                                <p className="text-xs font-bold text-muted-foreground mt-0.5">Tasty Bites • <span className="text-blue-600">15 min ago</span></p>
                            </div>
                        </div>

                        <div className="flex items-start gap-4 p-3.5 rounded-xl bg-accent/30 hover:bg-accent/50 transition-colors border border-transparent hover:border-border/50">
                            <div className="w-3 h-3 rounded-full bg-yellow-500 mt-1.5 shadow-[0_0_10px_rgba(234,179,8,0.3)]" />
                            <div className="flex-1">
                                <p className="text-sm font-bold text-foreground">Rider verification pending</p>
                                <p className="text-xs font-bold text-muted-foreground mt-0.5">John Doe • <span className="text-yellow-600">1 hour ago</span></p>
                            </div>
                        </div>
                    </div>
                </Card>
            </div>
        </div>
    );
}
