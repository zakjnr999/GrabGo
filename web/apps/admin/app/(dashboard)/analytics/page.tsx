"use client";

import { useState, useMemo, useEffect } from "react";
import {
    Card,
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@grabgo/ui";
import { Calendar, Download, Filter } from "lucide-react";
import { LineChart } from "../../../components/charts/LineChart";
import { BarChart } from "../../../components/charts/BarChart";
import {
    mockRevenueData,
    mockUserGrowthData,
    mockTopVendors,
    mockTopRiders,
    mockOrderVolumeData,
    mockPaymentMethodData,
    mockCustomerInsights,
    mockOperationalMetrics,
    mockOrderStatusData
} from "../../../lib/mockAnalyticsData";
import * as ExportUtils from "../../../lib/exportUtils";

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

type ReportType =
    | "user-growth"
    | "order-volume"
    | "revenue"
    | "vendor-performance"
    | "rider-performance"
    | "payment-analytics"
    | "customer-insights"
    | "operational-metrics";

const reportTypes = [
    { value: "user-growth", label: "User Growth Report" },
    { value: "order-volume", label: "Order Volume Report" },
    { value: "revenue", label: "Revenue Report" },
    { value: "vendor-performance", label: "Vendor Performance Report" },
    { value: "rider-performance", label: "Rider Performance Report" },
    { value: "payment-analytics", label: "Payment Analytics" },
    { value: "customer-insights", label: "Customer Insights" },
    { value: "operational-metrics", label: "Operational Metrics" },
];

const dateRangePresets = [
    { value: "today", label: "Today" },
    { value: "7days", label: "Last 7 Days" },
    { value: "30days", label: "Last 30 Days" },
    { value: "thisMonth", label: "This Month" },
    { value: "lastMonth", label: "Last Month" },
    { value: "custom", label: "Custom Range" },
];

export default function AnalyticsPage() {
    const [selectedReport, setSelectedReport] = useState<ReportType>("user-growth");
    const [dateRange, setDateRange] = useState("30days");
    const [isLoading, setIsLoading] = useState(false);

    // Advanced filtering states
    const [vendorTypeFilter, setVendorTypeFilter] = useState<string>("all");
    const [searchQuery, setSearchQuery] = useState("");
    const [sortConfig, setSortConfig] = useState<{ key: string; direction: 'asc' | 'desc' } | null>(null);

    // Pagination states
    const [currentPage, setCurrentPage] = useState(1);
    const [itemsPerPage, setItemsPerPage] = useState(10);

    const handleReportChange = (newReport: ReportType) => {
        setIsLoading(true);
        // Reset filters and pagination when changing reports
        setVendorTypeFilter("all");
        setSearchQuery("");
        setSortConfig(null);
        setCurrentPage(1);
        // Simulate loading delay for smooth animation
        setTimeout(() => {
            setSelectedReport(newReport);
            setIsLoading(false);
        }, 300);
    };

    const exportToCSV = () => {
        switch (selectedReport) {
            case "user-growth":
                ExportUtils.exportUserGrowthCSV(mockUserGrowthData);
                break;
            case "revenue":
                ExportUtils.exportRevenueCSV(mockRevenueData);
                break;
            case "vendor-performance":
                ExportUtils.exportVendorPerformanceCSV(mockTopVendors);
                break;
            case "rider-performance":
                ExportUtils.exportRiderPerformanceCSV(mockTopRiders);
                break;
            case "order-volume":
                ExportUtils.exportOrderVolumeCSV(mockOrderVolumeData);
                break;
            case "payment-analytics":
                ExportUtils.exportPaymentAnalyticsCSV(mockPaymentMethodData);
                break;
            case "customer-insights":
                ExportUtils.exportCustomerInsightsCSV(mockCustomerInsights);
                break;
            case "operational-metrics":
                ExportUtils.exportOperationalMetricsCSV(mockOperationalMetrics);
                break;
            default:
                alert("Export not available for this report");
        }
    };

    const exportToExcel = () => {
        switch (selectedReport) {
            case "user-growth":
                ExportUtils.exportUserGrowthExcel(mockUserGrowthData);
                break;
            case "revenue":
                ExportUtils.exportRevenueExcel(mockRevenueData);
                break;
            case "vendor-performance":
                ExportUtils.exportVendorPerformanceExcel(mockTopVendors);
                break;
            case "rider-performance":
                ExportUtils.exportRiderPerformanceExcel(mockTopRiders);
                break;
            case "order-volume":
                ExportUtils.exportOrderVolumeExcel(mockOrderVolumeData);
                break;
            case "payment-analytics":
                ExportUtils.exportPaymentAnalyticsExcel(mockPaymentMethodData);
                break;
            case "customer-insights":
                ExportUtils.exportCustomerInsightsExcel(mockCustomerInsights);
                break;
            case "operational-metrics":
                ExportUtils.exportOperationalMetricsExcel(mockOperationalMetrics);
                break;
            default:
                alert("Export not available for this report");
        }
    };

    const handlePrint = () => {
        window.print();
    };

    const handleSort = (key: string) => {
        let direction: 'asc' | 'desc' = 'asc';
        if (sortConfig && sortConfig.key === key && sortConfig.direction === 'asc') {
            direction = 'desc';
        }
        setSortConfig({ key, direction });
    };

    // Memoized filtered and sorted vendor data
    const filteredSortedVendors = useMemo(() => {
        return mockTopVendors
            .filter(vendor => {
                if (vendorTypeFilter !== "all" && vendor.type !== vendorTypeFilter) {
                    return false;
                }
                if (searchQuery && !vendor.name.toLowerCase().includes(searchQuery.toLowerCase())) {
                    return false;
                }
                return true;
            })
            .sort((a, b) => {
                if (!sortConfig) return 0;
                const aValue = a[sortConfig.key as keyof typeof a];
                const bValue = b[sortConfig.key as keyof typeof b];
                if (aValue < bValue) return sortConfig.direction === 'asc' ? -1 : 1;
                if (aValue > bValue) return sortConfig.direction === 'asc' ? 1 : -1;
                return 0;
            });
    }, [vendorTypeFilter, searchQuery, sortConfig]);

    // Memoized filtered and sorted rider data
    const filteredSortedRiders = useMemo(() => {
        return mockTopRiders
            .filter(rider => {
                if (searchQuery && !rider.name.toLowerCase().includes(searchQuery.toLowerCase())) {
                    return false;
                }
                return true;
            })
            .sort((a, b) => {
                if (!sortConfig) return 0;
                const aValue = a[sortConfig.key as keyof typeof a];
                const bValue = b[sortConfig.key as keyof typeof b];
                if (aValue < bValue) return sortConfig.direction === 'asc' ? -1 : 1;
                if (aValue > bValue) return sortConfig.direction === 'asc' ? 1 : -1;
                return 0;
            });
    }, [searchQuery, sortConfig]);

    // Paginated vendor data
    const paginatedVendors = useMemo(() => {
        const startIndex = (currentPage - 1) * itemsPerPage;
        const endIndex = startIndex + itemsPerPage;
        return filteredSortedVendors.slice(startIndex, endIndex);
    }, [filteredSortedVendors, currentPage, itemsPerPage]);

    // Paginated rider data
    const paginatedRiders = useMemo(() => {
        const startIndex = (currentPage - 1) * itemsPerPage;
        const endIndex = startIndex + itemsPerPage;
        return filteredSortedRiders.slice(startIndex, endIndex);
    }, [filteredSortedRiders, currentPage, itemsPerPage]);

    // Total pages calculation
    const totalVendorPages = Math.ceil(filteredSortedVendors.length / itemsPerPage);
    const totalRiderPages = Math.ceil(filteredSortedRiders.length / itemsPerPage);

    return (
        <div className="space-y-6">
            {/* Page Header */}
            <div className="animate-fade-in-up">
                <h1 className="text-4xl font-extrabold tracking-tight text-foreground">Intelligence Center</h1>
                <p className="text-muted-foreground mt-2 text-lg">
                    Advanced business analytics and real-time performance reports
                </p>
            </div>

            {/* Filters & Controls */}
            <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:100ms] hover:shadow-md transition-shadow">
                <div className="grid gap-6 md:grid-cols-3">
                    {/* Report Type Selector */}
                    <div>
                        <label className="text-xs font-black uppercase tracking-widest text-[#FE6132] mb-2 block">Analytical Lens</label>
                        <Select value={selectedReport} onValueChange={(v) => handleReportChange(v as ReportType)}>
                            <SelectTrigger className="w-full h-11 rounded-xl border-border bg-accent/30 text-foreground font-bold focus:ring-2 focus:ring-[#FE6132]/20 transition-all outline-none">
                                <SelectValue placeholder="Select report" />
                            </SelectTrigger>
                            <SelectContent className="rounded-xl border-border/50 shadow-xl bg-card text-foreground">
                                {reportTypes.map((type) => (
                                    <SelectItem key={type.value} value={type.value} className="font-medium rounded-lg cursor-pointer my-0.5">
                                        {type.label}
                                    </SelectItem>
                                ))}
                            </SelectContent>
                        </Select>
                    </div>

                    {/* Date Range Selector */}
                    <div>
                        <label className="text-xs font-black uppercase tracking-widest text-[#FE6132] mb-2 block">Time Horizon</label>
                        <Select value={dateRange} onValueChange={setDateRange}>
                            <SelectTrigger className="w-full h-11 rounded-xl border-border bg-accent/30 text-foreground font-bold focus:ring-2 focus:ring-[#FE6132]/20 transition-all outline-none">
                                <SelectValue placeholder="Select range" />
                            </SelectTrigger>
                            <SelectContent className="rounded-xl border-border/50 shadow-xl bg-card text-foreground">
                                {dateRangePresets.map((preset) => (
                                    <SelectItem key={preset.value} value={preset.value} className="font-medium rounded-lg cursor-pointer my-0.5">
                                        {preset.label}
                                    </SelectItem>
                                ))}
                            </SelectContent>
                        </Select>
                    </div>

                    {/* Export Buttons */}
                    <div>
                        <label className="text-xs font-black uppercase tracking-widest text-[#FE6132] mb-2 block">Extract Intelligence</label>
                        <div className="flex gap-2">
                            <button
                                onClick={exportToCSV}
                                className="flex-1 px-3 py-2.5 rounded-xl border border-border bg-background hover:bg-accent transition-all flex items-center justify-center gap-2 font-bold shadow-sm active:scale-95"
                            >
                                <Download className="w-4 h-4" />
                                <span className="text-sm">CSV</span>
                            </button>
                            <button
                                onClick={exportToExcel}
                                className="flex-1 px-3 py-2.5 rounded-xl border border-border bg-background hover:bg-accent transition-all flex items-center justify-center gap-2 font-bold shadow-sm active:scale-95"
                            >
                                <Download className="w-4 h-4" />
                                <span className="text-sm">Excel</span>
                            </button>
                            <button
                                onClick={handlePrint}
                                className="px-4 py-2.5 rounded-xl border border-border bg-background hover:bg-accent transition-all flex items-center justify-center font-bold shadow-sm active:scale-95"
                                title="Print Report"
                            >
                                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
                                </svg>
                            </button>
                        </div>
                    </div>
                </div>
            </Card>

            {/* Advanced Filters */}
            {(selectedReport === "vendor-performance" || selectedReport === "rider-performance" || selectedReport === "order-volume") && (
                <Card className="p-4 border-border/50">
                    <div className="flex flex-wrap gap-4 items-center">
                        {/* Vendor Type Filter (only for vendor-performance and order-volume) */}
                        {(selectedReport === "vendor-performance" || selectedReport === "order-volume") && (
                            <div className="flex-1 min-w-[200px]">
                                <label className="text-xs font-medium mb-1 block text-muted-foreground">Vendor Type</label>
                                <Select value={vendorTypeFilter} onValueChange={setVendorTypeFilter}>
                                    <SelectTrigger className="w-full px-3 py-2 text-sm rounded-md border border-border bg-background text-foreground focus:outline-none">
                                        <SelectValue placeholder="All Types" />
                                    </SelectTrigger>
                                    <SelectContent className="rounded-lg border-border bg-card text-foreground">
                                        <SelectItem value="all">All Types</SelectItem>
                                        <SelectItem value="food">🍕 Food</SelectItem>
                                        <SelectItem value="grocery">🛒 Grocery</SelectItem>
                                        <SelectItem value="pharmacy">💊 Pharmacy</SelectItem>
                                        <SelectItem value="market">🏪 Market</SelectItem>
                                    </SelectContent>
                                </Select>
                            </div>
                        )}

                        {/* Search Bar */}
                        <div className="flex-1 min-w-[250px]">
                            <label className="text-xs font-medium mb-1 block text-muted-foreground">Search</label>
                            <input
                                type="text"
                                value={searchQuery}
                                onChange={(e) => setSearchQuery(e.target.value)}
                                placeholder={selectedReport === "vendor-performance" ? "Search vendors..." : "Search riders..."}
                                className="w-full px-3 py-2 text-sm rounded-md border border-border bg-background text-foreground focus:outline-none placeholder:text-muted-foreground"
                            />
                        </div>

                        {/* Clear Filters */}
                        {(vendorTypeFilter !== "all" || searchQuery !== "") && (
                            <button
                                onClick={() => {
                                    setVendorTypeFilter("all");
                                    setSearchQuery("");
                                }}
                                className="px-4 py-2 text-sm rounded-md border border-border bg-background hover:bg-accent transition-colors mt-5"
                            >
                                Clear Filters
                            </button>
                        )}
                    </div>
                </Card>
            )}

            {/* Skeleton Loading State */}
            {isLoading && (
                <div className="space-y-6 animate-pulse">
                    {/* Skeleton Summary Cards */}
                    <div className="grid gap-6 md:grid-cols-4">
                        {[1, 2, 3, 4].map((i) => (
                            <Card key={i} className="p-6 border-border/50">
                                <div className="h-4 bg-muted rounded w-24 mb-3"></div>
                                <div className="h-8 bg-muted rounded w-32 mb-2"></div>
                                <div className="h-3 bg-muted rounded w-20"></div>
                            </Card>
                        ))}
                    </div>

                    {/* Skeleton Chart */}
                    <Card className="p-6 border-border/50">
                        <div className="h-6 bg-muted rounded w-48 mb-6"></div>
                        <div className="h-[350px] bg-gradient-to-r from-muted via-muted/50 to-muted rounded-lg relative overflow-hidden">
                            <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent animate-shimmer"></div>
                        </div>
                    </Card>

                    {/* Skeleton Table */}
                    <Card className="p-6 border-border/50">
                        <div className="h-6 bg-muted rounded w-40 mb-4"></div>
                        <div className="space-y-3">
                            {[1, 2, 3, 4, 5].map((i) => (
                                <div key={i} className="flex items-center gap-4 p-3 rounded-md bg-accent/50">
                                    <div className="h-4 bg-muted rounded w-8"></div>
                                    <div className="h-4 bg-muted rounded flex-1"></div>
                                    <div className="h-4 bg-muted rounded w-20"></div>
                                    <div className="h-4 bg-muted rounded w-24"></div>
                                </div>
                            ))}
                        </div>
                    </Card>
                </div>
            )}

            {/* Report Content with Animation */}
            <div className={`transition-opacity duration-300 ${isLoading ? 'opacity-0' : 'opacity-100 animate-fade-in'}`}>
                {!isLoading && (
                    <>
                        {/* Report Content */}
                        {selectedReport === "user-growth" && (
                            <div className="space-y-6">
                                {/* Summary Cards */}
                                <div className="grid gap-6 md:grid-cols-3">
                                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:200ms] hover:shadow-lg transition-all group">
                                        <p className="text-xs font-black uppercase tracking-widest text-muted-foreground">Total Active Users</p>
                                        <p className="text-4xl font-black mt-2 text-foreground group-hover:text-[#FE6132] transition-colors"><AnimatedNumber value={12458} delay={200} /></p>
                                        <div className="flex items-center gap-2 mt-2">
                                            <span className="px-2 py-0.5 rounded-full bg-green-100 text-green-700 text-[10px] font-black uppercase tracking-wider">+12.5%</span>
                                            <p className="text-xs font-bold text-muted-foreground">vs last month</p>
                                        </div>
                                    </Card>
                                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:300ms] hover:shadow-lg transition-all group">
                                        <p className="text-xs font-black uppercase tracking-widest text-muted-foreground">New Acquisitions</p>
                                        <p className="text-4xl font-black mt-2 text-foreground group-hover:text-[#FE6132] transition-colors"><AnimatedNumber value={1247} delay={300} /></p>
                                        <div className="flex items-center gap-2 mt-2">
                                            <span className="px-2 py-0.5 rounded-full bg-green-100 text-green-700 text-[10px] font-black uppercase tracking-wider">+8.3%</span>
                                            <p className="text-xs font-bold text-muted-foreground">vs prev. period</p>
                                        </div>
                                    </Card>
                                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:400ms] hover:shadow-lg transition-all group">
                                        <p className="text-xs font-black uppercase tracking-widest text-muted-foreground">Velocity Curve</p>
                                        <p className="text-4xl font-black mt-2 text-foreground group-hover:text-[#FE6132] transition-colors"><AnimatedNumber value={42} delay={400} /></p>
                                        <p className="text-xs font-bold text-muted-foreground mt-2">Daily Growth Average</p>
                                    </Card>
                                </div>

                                {/* User Growth Chart */}
                                <Card className="p-8 border-border/50 animate-fade-in-up [animation-delay:500ms] hover:shadow-md transition-all">
                                    <h3 className="text-xl font-black mb-8">User Growth Trendline</h3>
                                    <LineChart
                                        data={mockUserGrowthData.map(d => ({
                                            ...d,
                                            date: new Date(d.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
                                        }))}
                                        xKey="date"
                                        yKey="newUsers"
                                        color="#10b981"
                                        height={350}
                                    />
                                </Card>

                                {/* User Breakdown Table */}
                                <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:600ms]">
                                    <h3 className="text-xl font-black mb-6">Granular Expansion Log</h3>
                                    <div className="overflow-x-auto rounded-xl border border-border/50">
                                        <table className="w-full">
                                            <thead>
                                                <tr className="bg-accent/30 border-b border-border">
                                                    <th className="text-left py-4 px-6 text-xs font-black uppercase tracking-widest text-[#FE6132]">Intelligence Snapshot</th>
                                                    <th className="text-right py-4 px-6 text-xs font-black uppercase tracking-widest text-[#FE6132]">New Onboardings</th>
                                                    <th className="text-right py-4 px-6 text-xs font-black uppercase tracking-widest text-[#FE6132]">Cumulative Base</th>
                                                    <th className="text-right py-4 px-6 text-xs font-black uppercase tracking-widest text-[#FE6132]">Velocity ∆</th>
                                                </tr>
                                            </thead>
                                            <tbody className="divide-y divide-border/50">
                                                {mockUserGrowthData.slice(-10).reverse().map((data, index) => (
                                                    <tr
                                                        key={index}
                                                        className="hover:bg-accent/50 transition-all group animate-fade-in-up"
                                                        style={{ animationDelay: `${700 + index * 50}ms` }}
                                                    >
                                                        <td className="py-4 px-6 text-sm font-bold text-foreground">{new Date(data.date).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}</td>
                                                        <td className="py-4 px-6 text-sm text-right font-black text-[#FE6132] bg-[#FE6132]/5 group-hover:bg-[#FE6132]/10 transition-colors">{data.newUsers.toLocaleString()}</td>
                                                        <td className="py-4 px-6 text-sm text-right font-bold text-muted-foreground">{data.totalUsers.toLocaleString()}</td>
                                                        <td className="py-4 px-6 text-sm text-right">
                                                            <span className="px-2.5 py-1 rounded-lg bg-green-100 text-green-700 font-black text-xs">
                                                                +{((data.newUsers / data.totalUsers) * 100).toFixed(2)}%
                                                            </span>
                                                        </td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>
                                </Card>
                            </div>
                        )}

                        {selectedReport === "revenue" && (
                            <div className="space-y-6">
                                {/* Revenue Summary Cards */}
                                <div className="grid gap-6 md:grid-cols-4">
                                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:200ms] hover:shadow-lg transition-all group">
                                        <p className="text-xs font-black uppercase tracking-widest text-[#FE6132]">Gross Revenue</p>
                                        <p className="text-3xl font-black mt-2">GH₵ 97,950</p>
                                        <p className="text-xs font-black text-green-600 mt-2 uppercase tracking-wide">+15.3% vs LW</p>
                                    </Card>
                                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:300ms] hover:shadow-lg transition-all group">
                                        <p className="text-xs font-black uppercase tracking-widest text-muted-foreground">Unit Ticket</p>
                                        <p className="text-3xl font-black mt-2">GH₵ 84.50</p>
                                        <p className="text-xs font-black text-muted-foreground mt-2 uppercase tracking-wide">Avg. per order</p>
                                    </Card>
                                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:400ms] hover:shadow-lg transition-all group">
                                        <p className="text-xs font-black uppercase tracking-widest text-[#FE6132]">Volume Base</p>
                                        <p className="text-3xl font-black mt-2">1,155</p>
                                        <p className="text-xs font-black text-green-600 mt-2 uppercase tracking-wide">+8.7% vs LW</p>
                                    </Card>
                                    <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:500ms] hover:shadow-lg transition-all group">
                                        <p className="text-xs font-black uppercase tracking-widest text-muted-foreground">Daily Index</p>
                                        <p className="text-3xl font-black mt-2">GH₵ 13.9k</p>
                                        <p className="text-xs font-black text-muted-foreground mt-2 uppercase tracking-wide">Mean Revenue</p>
                                    </Card>
                                </div>

                                {/* Revenue Trend Chart */}
                                <Card className="p-8 border-border/50 animate-fade-in-up [animation-delay:600ms] hover:shadow-md transition-all">
                                    <h3 className="text-xl font-black mb-8">Revenue Momentum (L7D)</h3>
                                    <BarChart
                                        data={mockRevenueData.map(d => ({
                                            ...d,
                                            date: new Date(d.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
                                        }))}
                                        xKey="date"
                                        yKey="revenue"
                                        height={350}
                                    />
                                </Card>
                            </div>
                        )}

                        {selectedReport === "vendor-performance" && (
                            <div className="space-y-6">
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-4">Top Performing Vendors</h3>
                                    <div className="overflow-x-auto">
                                        <table className="w-full">
                                            <thead>
                                                <tr className="border-b border-border">
                                                    <th className="text-left py-3 px-4 text-sm font-medium text-muted-foreground">Rank</th>
                                                    <th
                                                        className="text-left py-3 px-4 text-sm font-medium text-muted-foreground cursor-pointer hover:text-foreground"
                                                        onClick={() => handleSort('name')}
                                                    >
                                                        Vendor Name {sortConfig?.key === 'name' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                    </th>
                                                    <th className="text-left py-3 px-4 text-sm font-medium text-muted-foreground">Type</th>
                                                    <th
                                                        className="text-right py-3 px-4 text-sm font-medium text-muted-foreground cursor-pointer hover:text-foreground"
                                                        onClick={() => handleSort('orders')}
                                                    >
                                                        Orders {sortConfig?.key === 'orders' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                    </th>
                                                    <th
                                                        className="text-right py-3 px-4 text-sm font-medium text-muted-foreground cursor-pointer hover:text-foreground"
                                                        onClick={() => handleSort('revenue')}
                                                    >
                                                        Revenue {sortConfig?.key === 'revenue' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                    </th>
                                                    <th
                                                        className="text-right py-3 px-4 text-sm font-medium text-muted-foreground cursor-pointer hover:text-foreground"
                                                        onClick={() => handleSort('rating')}
                                                    >
                                                        Rating {sortConfig?.key === 'rating' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                    </th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {paginatedVendors.map((vendor, index) => (
                                                    <tr
                                                        key={vendor.id}
                                                        className="hover:bg-accent/50 transition-all group animate-fade-in-up"
                                                        style={{ animationDelay: `${200 + index * 50}ms` }}
                                                    >
                                                        <td className="py-4 px-6 text-sm font-black text-[#FE6132] bg-[#FE6132]/5 group-hover:bg-[#FE6132]/10 transition-colors">#{(currentPage - 1) * itemsPerPage + index + 1}</td>
                                                        <td className="py-4 px-6 text-sm font-bold text-foreground">{vendor.name}</td>
                                                        <td className="py-4 px-6">
                                                            <span className={`text-[10px] px-2.5 py-1 rounded-full font-black uppercase tracking-widest ${vendor.type === 'food' ? 'bg-orange-100 text-orange-700' :
                                                                vendor.type === 'grocery' ? 'bg-green-100 text-green-700' :
                                                                    vendor.type === 'pharmacy' ? 'bg-blue-100 text-blue-700' :
                                                                        'bg-purple-100 text-purple-700'
                                                                }`}>
                                                                {vendor.type}
                                                            </span>
                                                        </td>
                                                        <td className="py-4 px-6 text-sm text-right font-bold text-muted-foreground">{vendor.orders.toLocaleString()}</td>
                                                        <td className="py-4 px-6 text-sm text-right font-black text-foreground">GH₵ {vendor.revenue.toLocaleString()}</td>
                                                        <td className="py-4 px-6 text-right">
                                                            <div className="flex items-center justify-end gap-1.5 font-black text-[#FE6132]">
                                                                <span className="text-xs">⭐</span>
                                                                <span className="text-sm">{vendor.rating.toFixed(1)}</span>
                                                            </div>
                                                        </td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>

                                    {/* Pagination Controls */}
                                    <div className="mt-4 flex items-center justify-between border-t border-border pt-4">
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
                                                <option value={5}>5</option>
                                                <option value={10}>10</option>
                                                <option value={20}>20</option>
                                                <option value={50}>50</option>
                                            </select>
                                            <span className="text-sm text-muted-foreground">
                                                of {filteredSortedVendors.length} vendors
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
                                                {Array.from({ length: Math.min(5, totalVendorPages) }, (_, i) => {
                                                    let pageNum;
                                                    if (totalVendorPages <= 5) {
                                                        pageNum = i + 1;
                                                    } else if (currentPage <= 3) {
                                                        pageNum = i + 1;
                                                    } else if (currentPage >= totalVendorPages - 2) {
                                                        pageNum = totalVendorPages - 4 + i;
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
                                                onClick={() => setCurrentPage(prev => Math.min(totalVendorPages, prev + 1))}
                                                disabled={currentPage === totalVendorPages || totalVendorPages === 0}
                                                className="px-3 py-1 text-sm rounded-md border border-border bg-background hover:bg-accent disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                                            >
                                                Next
                                            </button>
                                        </div>
                                    </div>
                                </Card>
                            </div>
                        )}

                        {selectedReport === "order-volume" && (
                            <div className="space-y-6">
                                {/* Summary Cards */}
                                <div className="grid gap-6 md:grid-cols-4">
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Total Orders</p>
                                        <p className="text-3xl font-bold mt-2"><AnimatedNumber value={1155} delay={200} /></p>
                                        <p className="text-sm text-green-600 mt-1">+8.7% vs last week</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Food Orders</p>
                                        <p className="text-3xl font-bold mt-2"><AnimatedNumber value={687} delay={300} /></p>
                                        <p className="text-sm text-muted-foreground mt-1">59.5% of total</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Grocery Orders</p>
                                        <p className="text-3xl font-bold mt-2"><AnimatedNumber value={298} delay={400} /></p>
                                        <p className="text-sm text-muted-foreground mt-1">25.8% of total</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Avg. Daily Orders</p>
                                        <p className="text-3xl font-bold mt-2"><AnimatedNumber value={165} delay={500} /></p>
                                        <p className="text-sm text-muted-foreground mt-1">orders per day</p>
                                    </Card>
                                </div>

                                {/* Order Volume by Type Chart */}
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-6">Order Volume by Service Type</h3>
                                    <BarChart
                                        data={mockOrderVolumeData.map(d => ({
                                            date: new Date(d.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
                                            total: d.food + d.grocery + d.pharmacy + d.market
                                        }))}
                                        xKey="date"
                                        yKey="total"
                                        color="#3b82f6"
                                        height={350}
                                    />
                                </Card>

                                {/* Order Status Distribution */}
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-4">Order Status Breakdown</h3>
                                    <div className="grid gap-4 md:grid-cols-5">
                                        {mockOrderStatusData.map((status) => (
                                            <div key={status.status} className="p-4 rounded-md border border-border">
                                                <p className="text-sm text-muted-foreground">{status.status}</p>
                                                <p className="text-2xl font-bold mt-1" style={{ color: status.color }}>{status.count}</p>
                                            </div>
                                        ))}
                                    </div>
                                </Card>
                            </div>
                        )}

                        {selectedReport === "rider-performance" && (
                            <div className="space-y-6">
                                {/* Summary Cards */}
                                <div className="grid gap-6 md:grid-cols-4">
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Total Riders</p>
                                        <p className="text-3xl font-bold mt-2">89</p>
                                        <p className="text-sm text-green-600 mt-1">+5 new this month</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Avg. Deliveries</p>
                                        <p className="text-3xl font-bold mt-2">213</p>
                                        <p className="text-sm text-muted-foreground mt-1">per rider/month</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Avg. Rating</p>
                                        <p className="text-3xl font-bold mt-2">4.7</p>
                                        <p className="text-sm text-muted-foreground mt-1">⭐ out of 5.0</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Acceptance Rate</p>
                                        <p className="text-3xl font-bold mt-2">88%</p>
                                        <p className="text-sm text-green-600 mt-1">+3% vs last month</p>
                                    </Card>
                                </div>

                                {/* Top Riders Table */}
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-4">Top Performing Riders</h3>
                                    <div className="overflow-x-auto">
                                        <table className="w-full">
                                            <thead>
                                                <tr className="border-b border-border">
                                                    <th className="text-left py-3 px-4 text-sm font-medium text-muted-foreground">Rank</th>
                                                    <th
                                                        className="text-left py-3 px-4 text-sm font-medium text-muted-foreground cursor-pointer hover:text-foreground"
                                                        onClick={() => handleSort('name')}
                                                    >
                                                        Rider Name {sortConfig?.key === 'name' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                    </th>
                                                    <th
                                                        className="text-right py-3 px-4 text-sm font-medium text-muted-foreground cursor-pointer hover:text-foreground"
                                                        onClick={() => handleSort('deliveries')}
                                                    >
                                                        Deliveries {sortConfig?.key === 'deliveries' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                    </th>
                                                    <th
                                                        className="text-right py-3 px-4 text-sm font-medium text-muted-foreground cursor-pointer hover:text-foreground"
                                                        onClick={() => handleSort('earnings')}
                                                    >
                                                        Earnings {sortConfig?.key === 'earnings' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                    </th>
                                                    <th
                                                        className="text-right py-3 px-4 text-sm font-medium text-muted-foreground cursor-pointer hover:text-foreground"
                                                        onClick={() => handleSort('rating')}
                                                    >
                                                        Rating {sortConfig?.key === 'rating' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                    </th>
                                                    <th
                                                        className="text-right py-3 px-4 text-sm font-medium text-muted-foreground cursor-pointer hover:text-foreground"
                                                        onClick={() => handleSort('acceptanceRate')}
                                                    >
                                                        Acceptance {sortConfig?.key === 'acceptanceRate' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                                                    </th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {paginatedRiders.map((rider, index) => (
                                                    <tr key={rider.id} className="border-b border-border/50 hover:bg-accent/50 transition-colors">
                                                        <td className="py-3 px-4 text-sm font-bold text-[#FE6132]">#{(currentPage - 1) * itemsPerPage + index + 1}</td>
                                                        <td className="py-3 px-4 text-sm font-medium">{rider.name}</td>
                                                        <td className="py-3 px-4 text-sm text-right">{rider.deliveries}</td>
                                                        <td className="py-3 px-4 text-sm text-right font-semibold">GH₵ {rider.earnings.toLocaleString()}</td>
                                                        <td className="py-3 px-4 text-sm text-right">⭐ {rider.rating}</td>
                                                        <td className="py-3 px-4 text-sm text-right">{rider.acceptanceRate}%</td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>

                                    {/* Pagination Controls */}
                                    <div className="mt-4 flex items-center justify-between border-t border-border pt-4">
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
                                                <option value={5}>5</option>
                                                <option value={10}>10</option>
                                                <option value={20}>20</option>
                                                <option value={50}>50</option>
                                            </select>
                                            <span className="text-sm text-muted-foreground">
                                                of {filteredSortedRiders.length} riders
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
                                                {Array.from({ length: Math.min(5, totalRiderPages) }, (_, i) => {
                                                    let pageNum;
                                                    if (totalRiderPages <= 5) {
                                                        pageNum = i + 1;
                                                    } else if (currentPage <= 3) {
                                                        pageNum = i + 1;
                                                    } else if (currentPage >= totalRiderPages - 2) {
                                                        pageNum = totalRiderPages - 4 + i;
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
                                                onClick={() => setCurrentPage(prev => Math.min(totalRiderPages, prev + 1))}
                                                disabled={currentPage === totalRiderPages || totalRiderPages === 0}
                                                className="px-3 py-1 text-sm rounded-md border border-border bg-background hover:bg-accent disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                                            >
                                                Next
                                            </button>
                                        </div>
                                    </div>
                                </Card>
                            </div>
                        )}

                        {selectedReport === "payment-analytics" && (
                            <div className="space-y-6">
                                {/* Summary Cards */}
                                <div className="grid gap-6 md:grid-cols-4">
                                    {mockPaymentMethodData.map((method) => (
                                        <Card key={method.method} className="p-6 border-border/50">
                                            <p className="text-sm text-muted-foreground">{method.method}</p>
                                            <p className="text-3xl font-bold mt-2">GH₵ {method.amount.toLocaleString()}</p>
                                            <p className="text-sm text-muted-foreground mt-1">{method.count} transactions</p>
                                        </Card>
                                    ))}
                                </div>

                                {/* Payment Distribution Chart */}
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-6">Payment Method Distribution</h3>
                                    <BarChart
                                        data={mockPaymentMethodData}
                                        xKey="method"
                                        yKey="amount"
                                        color="#8b5cf6"
                                        height={350}
                                    />
                                </Card>

                                {/* Payment Success Rate */}
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-4">Payment Performance</h3>
                                    <div className="grid gap-6 md:grid-cols-3">
                                        <div className="p-4 rounded-md bg-green-50 border border-green-200">
                                            <p className="text-sm text-green-700">Success Rate</p>
                                            <p className="text-3xl font-bold text-green-700 mt-2">97.8%</p>
                                        </div>
                                        <div className="p-4 rounded-md bg-red-50 border border-red-200">
                                            <p className="text-sm text-red-700">Failed Payments</p>
                                            <p className="text-3xl font-bold text-red-700 mt-2">2.2%</p>
                                        </div>
                                        <div className="p-4 rounded-md bg-blue-50 border border-blue-200">
                                            <p className="text-sm text-blue-700">Avg. Transaction</p>
                                            <p className="text-3xl font-bold text-blue-700 mt-2">GH₵ 78.50</p>
                                        </div>
                                    </div>
                                </Card>
                            </div>
                        )}

                        {selectedReport === "customer-insights" && (
                            <div className="space-y-6">
                                {/* Customer Metrics Cards */}
                                <div className="grid gap-6 md:grid-cols-4">
                                    {mockCustomerInsights.map((insight) => (
                                        <Card key={insight.metric} className="p-6 border-border/50">
                                            <p className="text-sm text-muted-foreground">{insight.metric}</p>
                                            <p className="text-3xl font-bold mt-2">
                                                {insight.metric.includes('Rate') || insight.metric.includes('Retention')
                                                    ? `${insight.value}%`
                                                    : insight.metric.includes('Value')
                                                        ? `GH₵ ${insight.value}`
                                                        : insight.value}
                                            </p>
                                            <p className={`text-sm mt-1 ${insight.change >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                                                {insight.change >= 0 ? '+' : ''}{insight.change}% vs last month
                                            </p>
                                        </Card>
                                    ))}
                                </div>

                                {/* Customer Segmentation */}
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-4">Customer Segmentation</h3>
                                    <div className="grid gap-4 md:grid-cols-3">
                                        <div className="p-4 rounded-md border border-border">
                                            <p className="text-sm text-muted-foreground">New Customers</p>
                                            <p className="text-2xl font-bold mt-2">2,458</p>
                                            <p className="text-sm text-muted-foreground mt-1">19.7% of total</p>
                                        </div>
                                        <div className="p-4 rounded-md border border-border">
                                            <p className="text-sm text-muted-foreground">Regular Customers</p>
                                            <p className="text-2xl font-bold mt-2">7,234</p>
                                            <p className="text-sm text-muted-foreground mt-1">58.1% of total</p>
                                        </div>
                                        <div className="p-4 rounded-md border border-border">
                                            <p className="text-sm text-muted-foreground">VIP Customers</p>
                                            <p className="text-2xl font-bold mt-2">2,766</p>
                                            <p className="text-sm text-muted-foreground mt-1">22.2% of total</p>
                                        </div>
                                    </div>
                                </Card>

                                {/* Top Spending Customers */}
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-4">Top Spending Customers</h3>
                                    <div className="space-y-3">
                                        {['Sarah Johnson', 'Michael Osei', 'Akua Mensah', 'David Agyeman', 'Grace Boateng'].map((name, index) => (
                                            <div key={name} className="flex items-center justify-between p-3 rounded-md bg-accent/50">
                                                <div className="flex items-center gap-3">
                                                    <span className="text-sm font-bold text-[#FE6132]">#{index + 1}</span>
                                                    <span className="font-medium">{name}</span>
                                                </div>
                                                <div className="text-right">
                                                    <p className="font-semibold">GH₵ {(4500 - index * 500).toLocaleString()}</p>
                                                    <p className="text-xs text-muted-foreground">{78 - index * 8} orders</p>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </Card>
                            </div>
                        )}

                        {selectedReport === "operational-metrics" && (
                            <div className="space-y-6">
                                {/* Operational Metrics Cards */}
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-4">Key Performance Indicators</h3>
                                    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                                        {mockOperationalMetrics.map((metric) => (
                                            <div
                                                key={metric.metric}
                                                className={`p-4 rounded-md border ${metric.status === 'good' ? 'border-green-200 bg-green-50' :
                                                    metric.status === 'warning' ? 'border-yellow-200 bg-yellow-50' :
                                                        'border-red-200 bg-red-50'
                                                    }`}
                                            >
                                                <p className="text-sm font-medium text-foreground">{metric.metric}</p>
                                                <div className="flex items-baseline gap-2 mt-2">
                                                    <p className={`text-2xl font-bold ${metric.status === 'good' ? 'text-green-700' :
                                                        metric.status === 'warning' ? 'text-yellow-700' :
                                                            'text-red-700'
                                                        }`}>
                                                        {metric.value}
                                                    </p>
                                                    <p className="text-sm text-muted-foreground">/ {metric.target}</p>
                                                </div>
                                                <div className="mt-2">
                                                    <span className={`text-xs px-2 py-1 rounded-full ${metric.status === 'good' ? 'bg-green-200 text-green-800' :
                                                        metric.status === 'warning' ? 'bg-yellow-200 text-yellow-800' :
                                                            'bg-red-200 text-red-800'
                                                        }`}>
                                                        {metric.status === 'good' ? '✓ On Target' :
                                                            metric.status === 'warning' ? '⚠ Needs Attention' :
                                                                '✗ Critical'}
                                                    </span>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </Card>

                                {/* System Health */}
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-4">System Health</h3>
                                    <div className="grid gap-4 md:grid-cols-3">
                                        <div className="p-4 rounded-md bg-green-50 border border-green-200">
                                            <p className="text-sm text-green-700">Uptime</p>
                                            <p className="text-3xl font-bold text-green-700 mt-2">99.9%</p>
                                            <p className="text-xs text-green-600 mt-1">Last 30 days</p>
                                        </div>
                                        <div className="p-4 rounded-md bg-blue-50 border border-blue-200">
                                            <p className="text-sm text-blue-700">API Response Time</p>
                                            <p className="text-3xl font-bold text-blue-700 mt-2">142ms</p>
                                            <p className="text-xs text-blue-600 mt-1">Average</p>
                                        </div>
                                        <div className="p-4 rounded-md bg-purple-50 border border-purple-200">
                                            <p className="text-sm text-purple-700">Active Users</p>
                                            <p className="text-3xl font-bold text-purple-700 mt-2">3,247</p>
                                            <p className="text-xs text-purple-600 mt-1">Right now</p>
                                        </div>
                                    </div>
                                </Card>
                            </div>
                        )}

                        {/* Placeholder for other reports */}
                        {!["user-growth", "revenue", "vendor-performance", "order-volume", "rider-performance", "payment-analytics", "customer-insights", "operational-metrics"].includes(selectedReport) && (
                            <Card className="p-12 border-border/50 text-center">
                                <Filter className="w-16 h-16 text-muted-foreground mx-auto mb-4" />
                                <h3 className="text-xl font-semibold mb-2">Report Coming Soon</h3>
                                <p className="text-muted-foreground">
                                    The {reportTypes.find(r => r.value === selectedReport)?.label} is currently under development.
                                </p>
                            </Card>
                        )}
                    </>
                )}
            </div>
        </div>
    );
}
