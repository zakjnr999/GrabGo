"use client";

import { useState, useMemo, useEffect } from "react";
import { useSearchParams, useRouter, usePathname } from "next/navigation";
import Link from "next/link";
import { Card } from "@grabgo/ui";
import { OrderStatus, OrderType, PaymentStatus, Order } from "../../../lib/mockOrderData";
import { Search, Cart, CheckCircle, Clock, Trash, Download, GraphUp } from "iconoir-react";
import { useOrderUpdates } from "../../../hooks/useOrderUpdates";
import { LiveOrderNotification } from "../../../components/orders/LiveOrderNotification";
import { OrderAnalyticsCharts } from "../../../components/orders/OrderAnalyticsCharts";

// Animated Number Component
function AnimatedNumber({ value, delay = 0 }: { value: number; delay?: number }) {
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
                    setCount(Math.floor(current));
                }
            }, duration / steps);

            return () => clearInterval(interval);
        }, delay + 300);

        return () => clearTimeout(timer);
    }, [value, delay]);

    return <>{count.toLocaleString()}</>;
}

export default function OrdersPage() {
    const searchParams = useSearchParams();
    const router = useRouter();
    const pathname = usePathname();

    const { orders: liveOrders, lastUpdate } = useOrderUpdates();
    const [selectedOrders, setSelectedOrders] = useState<string[]>([]);
    const [notification, setNotification] = useState<{ orderNumber: string; status: OrderStatus } | null>(null);
    const [showCharts, setShowCharts] = useState(false);
    const [isLoading, setIsLoading] = useState(true);

    // Sync lastUpdate to notification
    useEffect(() => {
        if (lastUpdate) {
            setNotification(lastUpdate);
        }
    }, [lastUpdate]);

    // Initialize state from URL or defaults
    const [searchQuery, setSearchQuery] = useState(searchParams.get("q") || "");
    const [orderTypeFilter, setOrderTypeFilter] = useState<string>(searchParams.get("type") || "all");
    const [statusFilter, setStatusFilter] = useState<string>(searchParams.get("status") || "all");
    const [paymentStatusFilter, setPaymentStatusFilter] = useState<string>(searchParams.get("payment_status") || "all");
    const [paymentMethodFilter, setPaymentMethodFilter] = useState<string>(searchParams.get("payment_method") || "all");
    const [dateRangeFilter, setDateRangeFilter] = useState<string>(searchParams.get("date") || "all");
    const [currentPage, setCurrentPage] = useState(Number(searchParams.get("page")) || 1);
    const [itemsPerPage, setItemsPerPage] = useState(Number(searchParams.get("limit")) || 10);

    const stats = useMemo(() => {
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const todayOrders = liveOrders.filter(o => new Date(o.createdAt) >= today);

        return {
            totalToday: todayOrders.length,
            pending: liveOrders.filter(o => o.status === 'pending').length,
            active: liveOrders.filter(o => ['confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way'].includes(o.status)).length,
            completed: todayOrders.filter(o => o.status === 'delivered').length,
            revenue: todayOrders.reduce((sum, o) => sum + o.pricing.total, 0)
        };
    }, [liveOrders]);

    // Set loading to false after minimum display time
    useEffect(() => {
        if (liveOrders.length > 0) {
            // Show skeleton for at least 800ms for better UX
            const timer = setTimeout(() => {
                setIsLoading(false);
            }, 800);
            return () => clearTimeout(timer);
        }
    }, [liveOrders]);

    // Sync state to URL
    useEffect(() => {
        const params = new URLSearchParams(searchParams.toString());

        if (searchQuery) params.set("q", searchQuery);
        else params.delete("q");

        if (orderTypeFilter !== "all") params.set("type", orderTypeFilter);
        else params.delete("type");

        if (statusFilter !== "all") params.set("status", statusFilter);
        else params.delete("status");

        if (paymentStatusFilter !== "all") params.set("payment_status", paymentStatusFilter);
        else params.delete("payment_status");

        if (paymentMethodFilter !== "all") params.set("payment_method", paymentMethodFilter);
        else params.delete("payment_method");

        if (dateRangeFilter !== "all") params.set("date", dateRangeFilter);
        else params.delete("date");

        if (currentPage !== 1) params.set("page", currentPage.toString());
        else params.delete("page");

        if (itemsPerPage !== 10) params.set("limit", itemsPerPage.toString());
        else params.delete("limit");

        const query = params.toString();
        const url = query ? `${pathname}?${query}` : pathname;

        // Use replace to avoid filling up history stack on every keystroke
        router.replace(url, { scroll: false });
    }, [searchQuery, orderTypeFilter, statusFilter, paymentStatusFilter, paymentMethodFilter, dateRangeFilter, currentPage, itemsPerPage, pathname, router, searchParams]);

    // Filtered and sorted orders
    const filteredOrders = useMemo(() => {
        return liveOrders.filter(order => {
            // Search filter
            const searchLower = searchQuery.toLowerCase();
            const matchesSearch = !searchQuery ||
                order.orderNumber.toLowerCase().includes(searchLower) ||
                order.customer.name.toLowerCase().includes(searchLower) ||
                order.vendor.name.toLowerCase().includes(searchLower);

            // Type filter
            const matchesType = orderTypeFilter === "all" || order.type === orderTypeFilter;

            // Status filter
            const matchesStatus = statusFilter === "all" || order.status === statusFilter;

            // Payment status filter
            const matchesPaymentStatus = paymentStatusFilter === "all" || order.paymentStatus === paymentStatusFilter;

            // Payment method filter
            const matchesPaymentMethod = paymentMethodFilter === "all" || order.paymentMethod === paymentMethodFilter;

            // Date range filter
            let matchesDateRange = true;
            if (dateRangeFilter !== "all") {
                const orderDate = new Date(order.createdAt);
                const now = new Date();
                const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

                switch (dateRangeFilter) {
                    case "today":
                        matchesDateRange = orderDate >= today;
                        break;
                    case "yesterday":
                        const yesterday = new Date(today);
                        yesterday.setDate(yesterday.getDate() - 1);
                        matchesDateRange = orderDate >= yesterday && orderDate < today;
                        break;
                    case "week":
                        const weekAgo = new Date(today);
                        weekAgo.setDate(weekAgo.getDate() - 7);
                        matchesDateRange = orderDate >= weekAgo;
                        break;
                    case "month":
                        const monthAgo = new Date(today);
                        monthAgo.setMonth(monthAgo.getMonth() - 1);
                        matchesDateRange = orderDate >= monthAgo;
                        break;
                }
            }

            return matchesSearch && matchesType && matchesStatus && matchesPaymentStatus && matchesPaymentMethod && matchesDateRange;
        }).sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    }, [searchQuery, orderTypeFilter, statusFilter, paymentStatusFilter, paymentMethodFilter, dateRangeFilter, liveOrders]);

    // Paginated orders
    const paginatedOrders = useMemo(() => {
        const startIndex = (currentPage - 1) * itemsPerPage;
        const endIndex = startIndex + itemsPerPage;
        return filteredOrders.slice(startIndex, endIndex);
    }, [filteredOrders, currentPage, itemsPerPage]);

    const totalPages = Math.ceil(filteredOrders.length / itemsPerPage);

    const clearFilters = () => {
        setSearchQuery("");
        setOrderTypeFilter("all");
        setStatusFilter("all");
        setPaymentStatusFilter("all");
        setPaymentMethodFilter("all");
        setDateRangeFilter("all");
        setCurrentPage(1);
        setSelectedOrders([]);
    };

    const toggleOrderSelection = (id: string) => {
        setSelectedOrders(prev =>
            prev.includes(id) ? prev.filter(oid => oid !== id) : [...prev, id]
        );
    };

    const toggleAllSelection = () => {
        if (selectedOrders.length === paginatedOrders.length) {
            setSelectedOrders([]);
        } else {
            setSelectedOrders(paginatedOrders.map(o => o.id));
        }
    };

    const getStatusColor = (status: OrderStatus) => {
        const colors: Record<OrderStatus, string> = {
            pending: 'bg-yellow-500/10 text-yellow-600 dark:text-yellow-400 dark:bg-yellow-500/20',
            confirmed: 'bg-blue-500/10 text-blue-600 dark:text-blue-400 dark:bg-blue-500/20',
            preparing: 'bg-purple-500/10 text-purple-600 dark:text-purple-400 dark:bg-purple-500/20',
            ready: 'bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 dark:bg-indigo-500/20',
            picked_up: 'bg-cyan-500/10 text-cyan-600 dark:text-cyan-400 dark:bg-cyan-500/20',
            on_the_way: 'bg-orange-500/10 text-orange-600 dark:text-orange-400 dark:bg-orange-500/20',
            delivered: 'bg-green-500/10 text-green-600 dark:text-green-400 dark:bg-green-500/20',
            cancelled: 'bg-red-500/10 text-red-600 dark:text-red-400 dark:bg-red-500/20'
        };
        return colors[status] || 'bg-gray-500/10 text-gray-600 dark:text-gray-400 dark:bg-gray-500/20';
    };

    const getPaymentStatusColor = (status: PaymentStatus) => {
        const colors: Record<PaymentStatus, string> = {
            pending: 'bg-yellow-500/10 text-yellow-600 dark:text-yellow-400 dark:bg-yellow-500/20',
            paid: 'bg-green-500/10 text-green-600 dark:text-green-400 dark:bg-green-500/20',
            failed: 'bg-red-500/10 text-red-600 dark:text-red-400 dark:bg-red-500/20',
            refunded: 'bg-gray-500/10 text-gray-600 dark:text-gray-400 dark:bg-gray-500/20'
        };
        return colors[status];
    };

    const getTypeColor = (type: OrderType) => {
        const colors: Record<OrderType, string> = {
            food: 'bg-orange-500/10 text-orange-600 dark:text-orange-400 dark:bg-orange-500/20',
            grocery: 'bg-green-500/10 text-green-600 dark:text-green-400 dark:bg-green-500/20',
            pharmacy: 'bg-blue-500/10 text-blue-600 dark:text-blue-400 dark:bg-blue-500/20',
            market: 'bg-purple-500/10 text-purple-600 dark:text-purple-400 dark:bg-purple-500/20'
        };
        return colors[type];
    };

    const formatDate = (dateString: string) => {
        const date = new Date(dateString);
        const now = new Date();
        const diffMs = now.getTime() - date.getTime();
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        if (diffDays < 7) return `${diffDays}d ago`;

        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    };

    return (
        <div className="space-y-6">
            {/* Page Header */}
            <div className="flex items-center justify-between animate-fade-in-up">
                <div>
                    <h1 className="text-4xl font-extrabold tracking-tight">Orders</h1>
                    <p className="text-muted-foreground mt-2 text-lg">Manage and track all orders in real-time</p>
                </div>
                <button
                    onClick={() => setShowCharts(!showCharts)}
                    className={`flex items-center gap-2 px-6 py-2.5 rounded-full border font-semibold shadow-sm transition-all duration-300 hover:scale-105 active:scale-95 ${showCharts
                        ? 'bg-[#FE6132] text-white border-[#FE6132] shadow-orange-100'
                        : 'bg-background text-foreground border-border hover:bg-accent'
                        }`}
                >
                    <GraphUp className="w-5 h-5" />
                    {showCharts ? 'Hide Analytics' : 'Show Analytics'}
                </button>
            </div>

            {/* Analytics Charts */}
            {showCharts && (
                <div className="animate-fade-in-up duration-500">
                    <OrderAnalyticsCharts orders={liveOrders} />
                </div>
            )}

            {/* Statistics Cards */}
            <div className="grid gap-6 md:grid-cols-4">
                <Card className="p-6 border-border/50 hover:shadow-lg transition-all duration-300 hover:-translate-y-1 group animate-fade-in-up [animation-delay:100ms] bg-card/50 backdrop-blur-sm">
                    <div className="flex items-center gap-4">
                        <div className="p-4 rounded-2xl bg-blue-500/10 group-hover:bg-blue-500/20 transition-colors">
                            <Cart className="w-8 h-8 text-blue-600" />
                        </div>
                        <div>
                            <p className="text-sm font-medium text-muted-foreground">Total Today</p>
                            <p className="text-3xl font-bold tracking-tight"><AnimatedNumber value={stats.totalToday} delay={100} /></p>
                        </div>
                    </div>
                </Card>

                <Card className="p-6 border-border/50 hover:shadow-lg transition-all duration-300 hover:-translate-y-1 group animate-fade-in-up [animation-delay:200ms] bg-card/50 backdrop-blur-sm">
                    <div className="flex items-center gap-4">
                        <div className="p-4 rounded-2xl bg-yellow-500/10 group-hover:bg-yellow-500/20 transition-colors">
                            <Clock className="w-8 h-8 text-yellow-600" />
                        </div>
                        <div>
                            <p className="text-sm font-medium text-muted-foreground">Pending</p>
                            <p className="text-3xl font-bold tracking-tight"><AnimatedNumber value={stats.pending} delay={200} /></p>
                        </div>
                    </div>
                </Card>

                <Card className="p-6 border-border/50 hover:shadow-lg transition-all duration-300 hover:-translate-y-1 group animate-fade-in-up [animation-delay:300ms] bg-card/50 backdrop-blur-sm">
                    <div className="flex items-center gap-4">
                        <div className="p-4 rounded-2xl bg-orange-500/10 group-hover:bg-orange-500/20 transition-colors">
                            <Clock className="w-8 h-8 text-orange-600" />
                        </div>
                        <div>
                            <p className="text-sm font-medium text-muted-foreground">Active</p>
                            <p className="text-3xl font-bold tracking-tight"><AnimatedNumber value={stats.active} delay={300} /></p>
                        </div>
                    </div>
                </Card>

                <Card className="p-6 border-border/50 hover:shadow-lg transition-all duration-300 hover:-translate-y-1 group animate-fade-in-up [animation-delay:400ms] bg-card/50 backdrop-blur-sm">
                    <div className="flex items-center gap-4">
                        <div className="p-4 rounded-2xl bg-green-500/10 group-hover:bg-green-500/20 transition-colors">
                            <CheckCircle className="w-8 h-8 text-green-600" />
                        </div>
                        <div>
                            <p className="text-sm font-medium text-muted-foreground">Completed Today</p>
                            <p className="text-3xl font-bold tracking-tight"><AnimatedNumber value={stats.completed} delay={400} /></p>
                        </div>
                    </div>
                </Card>
            </div>

            {/* Filters */}
            <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:500ms]">
                <div className="space-y-6">
                    {/* Search */}
                    <div className="flex gap-4 items-center">
                        <div className="flex-1 relative group">
                            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground group-focus-within:text-[#FE6132] transition-colors" />
                            <input
                                type="text"
                                placeholder="Search by order ID, customer, or vendor..."
                                value={searchQuery}
                                onChange={(e) => {
                                    setSearchQuery(e.target.value);
                                    setCurrentPage(1);
                                }}
                                className="w-full pl-12 pr-4 py-3 text-sm rounded-xl border border-border bg-background focus:outline-none focus:ring-4 focus:ring-[#FE6132]/10 focus:border-[#FE6132] transition-all"
                            />
                        </div>
                        <button
                            onClick={clearFilters}
                            className="px-6 py-3 text-sm font-semibold rounded-xl border border-border bg-background hover:bg-accent transition-all active:scale-95"
                        >
                            Clear Filters
                        </button>
                    </div>

                    {/* Filter Dropdowns */}
                    <div className="grid grid-cols-1 md:grid-cols-5 gap-6">
                        {/* ... select inputs remain same but with better styling ... */}
                        <div>
                            <label className="text-xs font-bold mb-1.5 block text-muted-foreground uppercase tracking-wider">Date Range</label>
                            <select
                                value={dateRangeFilter}
                                onChange={(e) => {
                                    setDateRangeFilter(e.target.value);
                                    setCurrentPage(1);
                                }}
                                className="w-full px-4 py-2.5 text-sm rounded-lg border border-border bg-background focus:outline-none focus:ring-2 focus:ring-[#FE6132]/20 transition-all cursor-pointer hover:border-[#FE6132]/50"
                            >
                                <option value="all">All Time</option>
                                <option value="today">Today</option>
                                <option value="yesterday">Yesterday</option>
                                <option value="week">Last 7 Days</option>
                                <option value="month">Last 30 Days</option>
                            </select>
                        </div>

                        <div>
                            <label className="text-xs font-bold mb-1.5 block text-muted-foreground uppercase tracking-wider">Order Type</label>
                            <select
                                value={orderTypeFilter}
                                onChange={(e) => {
                                    setOrderTypeFilter(e.target.value);
                                    setCurrentPage(1);
                                }}
                                className="w-full px-4 py-2.5 text-sm rounded-lg border border-border bg-background focus:outline-none focus:ring-2 focus:ring-[#FE6132]/20 transition-all cursor-pointer hover:border-[#FE6132]/50"
                            >
                                <option value="all">All Types</option>
                                <option value="food">🍕 Food</option>
                                <option value="grocery">🛒 Grocery</option>
                                <option value="pharmacy">💊 Pharmacy</option>
                                <option value="market">🏪 Market</option>
                            </select>
                        </div>

                        <div>
                            <label className="text-xs font-bold mb-1.5 block text-muted-foreground uppercase tracking-wider">Status</label>
                            <select
                                value={statusFilter}
                                onChange={(e) => {
                                    setStatusFilter(e.target.value);
                                    setCurrentPage(1);
                                }}
                                className="w-full px-4 py-2.5 text-sm rounded-lg border border-border bg-background focus:outline-none focus:ring-2 focus:ring-[#FE6132]/20 transition-all cursor-pointer hover:border-[#FE6132]/50"
                            >
                                <option value="all">All Statuses</option>
                                <option value="pending">Pending</option>
                                <option value="confirmed">Confirmed</option>
                                <option value="preparing">Preparing</option>
                                <option value="ready">Ready</option>
                                <option value="picked_up">Picked Up</option>
                                <option value="on_the_way">On The Way</option>
                                <option value="delivered">Delivered</option>
                                <option value="cancelled">Cancelled</option>
                            </select>
                        </div>

                        <div>
                            <label className="text-xs font-bold mb-1.5 block text-muted-foreground uppercase tracking-wider">Payment Status</label>
                            <select
                                value={paymentStatusFilter}
                                onChange={(e) => {
                                    setPaymentStatusFilter(e.target.value);
                                    setCurrentPage(1);
                                }}
                                className="w-full px-4 py-2.5 text-sm rounded-lg border border-border bg-background focus:outline-none focus:ring-2 focus:ring-[#FE6132]/20 transition-all cursor-pointer hover:border-[#FE6132]/50"
                            >
                                <option value="all">All Payment Statuses</option>
                                <option value="pending">Pending</option>
                                <option value="paid">Paid</option>
                                <option value="failed">Failed</option>
                                <option value="refunded">Refunded</option>
                            </select>
                        </div>

                        <div>
                            <label className="text-xs font-bold mb-1.5 block text-muted-foreground uppercase tracking-wider">Payment Method</label>
                            <select
                                value={paymentMethodFilter}
                                onChange={(e) => {
                                    setPaymentMethodFilter(e.target.value);
                                    setCurrentPage(1);
                                }}
                                className="w-full px-4 py-2.5 text-sm rounded-lg border border-border bg-background focus:outline-none focus:ring-2 focus:ring-[#FE6132]/20 transition-all cursor-pointer hover:border-[#FE6132]/50"
                            >
                                <option value="all">All Methods</option>
                                <option value="cash">Cash</option>
                                <option value="card">Card</option>
                                <option value="mtn_momo">MTN MOMO</option>
                                <option value="vodafone_cash">Vodafone Cash</option>
                                <option value="airtel_money">Airtel Money</option>
                            </select>
                        </div>
                    </div>
                </div>
            </Card>

            {/* Bulk Actions Toolbar */}
            {selectedOrders.length > 0 && (
                <div className="bg-[#FE6132] text-white p-4 rounded-xl flex items-center justify-between animate-fade-in-up duration-300 shadow-lg shadow-orange-100">
                    <div className="flex items-center gap-4">
                        <span className="font-bold flex items-center gap-2">
                            <span className="w-6 h-6 rounded-full bg-white text-[#FE6132] flex items-center justify-center text-xs">
                                {selectedOrders.length}
                            </span>
                            orders selected
                        </span>
                        <div className="h-8 w-px bg-white/20" />
                        <button className="flex items-center gap-2 text-sm font-bold hover:bg-white/10 px-4 py-2 rounded-lg transition-all active:scale-95">
                            <CheckCircle className="w-4 h-4" />
                            Mark as Delivered
                        </button>
                        <button className="flex items-center gap-2 text-sm font-bold hover:bg-white/10 px-4 py-2 rounded-lg transition-all active:scale-95">
                            <Download className="w-4 h-4" />
                            Export Selected
                        </button>
                        <button className="flex items-center gap-2 text-sm font-bold hover:bg-red-500 px-4 py-2 rounded-lg transition-all active:scale-95 text-red-50">
                            <Trash className="w-4 h-4" />
                            Cancel Selected
                        </button>
                    </div>
                </div>
            )}

            {/* Orders Table */}
            <Card className="border-border/50 overflow-hidden animate-fade-in-up [animation-delay:600ms]">
                <div className="overflow-x-auto">
                    <table className="w-full text-left text-sm">
                        <thead className="bg-accent/50 text-muted-foreground font-medium border-b border-border">
                            <tr>
                                <th className="p-4 w-10">
                                    <input
                                        type="checkbox"
                                        checked={selectedOrders.length === paginatedOrders.length && paginatedOrders.length > 0}
                                        onChange={toggleAllSelection}
                                        className="w-4 h-4 rounded border-border text-[#FE6132] focus:ring-[#FE6132]"
                                    />
                                </th>
                                <th className="p-4">Order ID</th>
                                <th className="p-4">Customer</th>
                                <th className="p-4">Vendor</th>
                                <th className="p-4">Type</th>
                                <th className="text-right p-4">Amount</th>
                                <th className="p-4">Payment</th>
                                <th className="p-4">Status</th>
                                <th className="p-4">Time</th>
                                <th className="text-right p-4">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {isLoading ? (
                                // Skeleton Loaders
                                Array.from({ length: itemsPerPage }).map((_, i) => (
                                    <tr key={`skeleton-${i}`} className="border-b border-border/50 animate-pulse">
                                        <td className="p-4">
                                            <div className="w-4 h-4 bg-muted rounded" />
                                        </td>
                                        <td className="p-4">
                                            <div className="space-y-2">
                                                <div className="h-4 w-24 bg-muted rounded" />
                                                <div className="h-3 w-16 bg-muted rounded" />
                                            </div>
                                        </td>
                                        <td className="p-4">
                                            <div className="space-y-2">
                                                <div className="h-4 w-28 bg-muted rounded" />
                                                <div className="h-3 w-20 bg-muted rounded" />
                                            </div>
                                        </td>
                                        <td className="p-4">
                                            <div className="space-y-2">
                                                <div className="h-4 w-32 bg-muted rounded" />
                                                <div className="h-3 w-24 bg-muted rounded" />
                                            </div>
                                        </td>
                                        <td className="p-4">
                                            <div className="h-6 w-16 bg-muted rounded-full" />
                                        </td>
                                        <td className="p-4 text-right">
                                            <div className="h-4 w-20 bg-muted rounded ml-auto" />
                                        </td>
                                        <td className="p-4">
                                            <div className="h-6 w-24 bg-muted rounded-full" />
                                        </td>
                                        <td className="p-4">
                                            <div className="h-6 w-20 bg-muted rounded-full" />
                                        </td>
                                        <td className="p-4">
                                            <div className="h-3 w-16 bg-muted rounded" />
                                        </td>
                                        <td className="p-4 text-right">
                                            <div className="h-8 w-16 bg-muted rounded-lg ml-auto" />
                                        </td>
                                    </tr>
                                ))
                            ) : (
                                paginatedOrders.map((order, index) => (
                                    <tr
                                        key={order.id}
                                        className="border-b border-border/50 hover:bg-accent/30 transition-all duration-200 animate-fade-in-up"
                                        style={{ animationDelay: `${700 + index * 50}ms` }}
                                    >
                                        <td className="p-4">
                                            <input
                                                type="checkbox"
                                                checked={selectedOrders.includes(order.id)}
                                                onChange={() => toggleOrderSelection(order.id)}
                                                className="w-4 h-4 rounded border-border text-[#FE6132] focus:ring-[#FE6132]"
                                            />
                                        </td>
                                        <td className="p-4">
                                            <p className="font-semibold text-foreground">{order.orderNumber}</p>
                                            {order.rider && <p className="text-xs text-muted-foreground mt-0.5">🚴 {order.rider.name}</p>}
                                        </td>
                                        <td className="py-3 px-4">
                                            <div className="flex flex-col">
                                                <span className="text-sm font-medium">{order.customer.name}</span>
                                                <span className="text-xs text-muted-foreground">{order.customer.phone}</span>
                                            </div>
                                        </td>
                                        <td className="py-3 px-4">
                                            <div className="flex flex-col">
                                                <span className="text-sm font-medium">{order.vendor.name}</span>
                                                <span className="text-xs text-muted-foreground">{order.delivery.address}</span>
                                            </div>
                                        </td>
                                        <td className="py-3 px-4">
                                            <span className={`text-xs px-2 py-1 rounded-full font-medium capitalize ${getTypeColor(order.type)}`}>
                                                {order.type}
                                            </span>
                                        </td>
                                        <td className="py-3 px-4 text-right">
                                            <span className="text-sm font-semibold">GH₵ {order.pricing.total.toFixed(2)}</span>
                                        </td>
                                        <td className="py-3 px-4">
                                            <div className="flex flex-col gap-1">
                                                <span className={`text-xs px-2 py-1 rounded-full font-medium capitalize inline-block w-fit ${getPaymentStatusColor(order.paymentStatus)}`}>
                                                    {order.paymentStatus}
                                                </span>
                                                <span className="text-xs text-muted-foreground capitalize">{order.paymentMethod.replace('_', ' ')}</span>
                                            </div>
                                        </td>
                                        <td className="py-3 px-4">
                                            <span className={`text-xs px-2 py-1 rounded-full font-medium capitalize ${getStatusColor(order.status)}`}>
                                                {order.status.replace('_', ' ')}
                                            </span>
                                        </td>
                                        <td className="py-3 px-4">
                                            <span className="text-sm text-muted-foreground">{formatDate(order.createdAt)}</span>
                                        </td>
                                        <td className="py-3 px-4 text-right">
                                            <Link
                                                href={`/orders/${order.id}`}
                                                className="text-sm text-[#FE6132] hover:underline font-medium"
                                            >
                                                View
                                            </Link>
                                        </td>
                                    </tr>
                                )
                                ))}
                        </tbody>
                    </table>
                </div>

                {/* Pagination */}
                <div className="mt-4 flex items-center justify-between border-t border-border pt-4 px-4 pb-4">
                    <div className="flex items-center gap-2">
                        <span className="text-sm text-muted-foreground">Show</span>
                        <select
                            value={itemsPerPage}
                            onChange={(e) => {
                                setItemsPerPage(Number(e.target.value));
                                setCurrentPage(1);
                            }}
                            className="px-2 py-1 text-sm rounded-md border border-border bg-background focus:outline-none"
                        >
                            <option value={10}>10</option>
                            <option value={20}>20</option>
                            <option value={50}>50</option>
                            <option value={100}>100</option>
                        </select>
                        <span className="text-sm text-muted-foreground">
                            of {filteredOrders.length} orders
                        </span>
                    </div>

                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                            disabled={currentPage === 1}
                            className="px-3 py-1 text-sm rounded-md border border-border bg-background hover:bg-accent disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                        >
                            Previous
                        </button>

                        <div className="flex gap-1">
                            {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                                let pageNum;
                                if (totalPages <= 5) {
                                    pageNum = i + 1;
                                } else if (currentPage <= 3) {
                                    pageNum = i + 1;
                                } else if (currentPage >= totalPages - 2) {
                                    pageNum = totalPages - 4 + i;
                                } else {
                                    pageNum = currentPage - 2 + i;
                                }

                                return (
                                    <button
                                        key={pageNum}
                                        onClick={() => setCurrentPage(pageNum)}
                                        className={`px-3 py-1 text-sm rounded-md border transition-colors ${currentPage === pageNum
                                            ? 'bg-[#FE6132] text-white border-[#FE6132]'
                                            : 'border-border bg-background hover:bg-accent'
                                            }`}
                                    >
                                        {pageNum}
                                    </button>
                                );
                            })}
                        </div>

                        <button
                            onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                            disabled={currentPage === totalPages || totalPages === 0}
                            className="px-3 py-1 text-sm rounded-md border border-border bg-background hover:bg-accent disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                        >
                            Next
                        </button>
                    </div>
                </div>
            </Card>

            {notification && (
                <LiveOrderNotification
                    orderNumber={notification.orderNumber}
                    status={notification.status}
                    onClose={() => setNotification(null)}
                />
            )}
        </div>
    );
}
