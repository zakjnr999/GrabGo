"use client";

import { useState, useMemo } from "react";
import { Card } from "@grabgo/ui";
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
            <div className="animate-fade-in">
                <h1 className="text-3xl font-bold text-foreground">Analytics & Reports</h1>
                <p className="text-muted-foreground mt-1">
                    Comprehensive insights and detailed reports for your business
                </p>
            </div>

            {/* Filters & Controls */}
            <Card className="p-6 border-border/50">
                <div className="grid gap-4 md:grid-cols-3">
                    {/* Report Type Selector */}
                    <div>
                        <label className="text-sm font-medium mb-2 block">Report Type</label>
                        <select
                            value={selectedReport}
                            onChange={(e) => handleReportChange(e.target.value as ReportType)}
                            className="w-full px-3 py-2 rounded-md border border-border bg-background text-foreground focus:outline-none"
                        >
                            {reportTypes.map((type) => (
                                <option key={type.value} value={type.value}>
                                    {type.label}
                                </option>
                            ))}
                        </select>
                    </div>

                    {/* Date Range Selector */}
                    <div>
                        <label className="text-sm font-medium mb-2 block">Date Range</label>
                        <select
                            value={dateRange}
                            onChange={(e) => setDateRange(e.target.value)}
                            className="w-full px-3 py-2 rounded-md border border-border bg-background text-foreground focus:outline-none"
                        >
                            {dateRangePresets.map((preset) => (
                                <option key={preset.value} value={preset.value}>
                                    {preset.label}
                                </option>
                            ))}
                        </select>
                    </div>

                    {/* Export Buttons */}
                    <div>
                        <label className="text-sm font-medium mb-2 block">Actions</label>
                        <div className="flex gap-2">
                            <button
                                onClick={exportToCSV}
                                className="flex-1 px-3 py-2 rounded-md border border-border bg-background hover:bg-accent transition-colors flex items-center justify-center gap-2"
                            >
                                <Download className="w-4 h-4" />
                                <span className="text-sm">CSV</span>
                            </button>
                            <button
                                onClick={exportToExcel}
                                className="flex-1 px-3 py-2 rounded-md border border-border bg-background hover:bg-accent transition-colors flex items-center justify-center gap-2"
                            >
                                <Download className="w-4 h-4" />
                                <span className="text-sm">Excel</span>
                            </button>
                            <button
                                onClick={handlePrint}
                                className="flex-1 px-3 py-2 rounded-md border border-border bg-background hover:bg-accent transition-colors flex items-center justify-center gap-2"
                                title="Print Report"
                            >
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
                                </svg>
                                <span className="text-sm">Print</span>
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
                                <select
                                    value={vendorTypeFilter}
                                    onChange={(e) => setVendorTypeFilter(e.target.value)}
                                    className="w-full px-3 py-2 text-sm rounded-md border border-border bg-background text-foreground focus:outline-none"
                                >
                                    <option value="all">All Types</option>
                                    <option value="food">🍕 Food</option>
                                    <option value="grocery">🛒 Grocery</option>
                                    <option value="pharmacy">💊 Pharmacy</option>
                                    <option value="market">🏪 Market</option>
                                </select>
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
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Total Users</p>
                                        <p className="text-3xl font-bold mt-2">12,458</p>
                                        <p className="text-sm text-green-600 mt-1">+12.5% from last month</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">New Users (30 days)</p>
                                        <p className="text-3xl font-bold mt-2">1,247</p>
                                        <p className="text-sm text-green-600 mt-1">+8.3% from previous period</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Avg. Daily Growth</p>
                                        <p className="text-3xl font-bold mt-2">42</p>
                                        <p className="text-sm text-muted-foreground mt-1">users per day</p>
                                    </Card>
                                </div>

                                {/* User Growth Chart */}
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-6">User Growth Trend</h3>
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
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-4">Daily Breakdown</h3>
                                    <div className="overflow-x-auto">
                                        <table className="w-full">
                                            <thead>
                                                <tr className="border-b border-border">
                                                    <th className="text-left py-3 px-4 text-sm font-medium text-muted-foreground">Date</th>
                                                    <th className="text-right py-3 px-4 text-sm font-medium text-muted-foreground">New Users</th>
                                                    <th className="text-right py-3 px-4 text-sm font-medium text-muted-foreground">Total Users</th>
                                                    <th className="text-right py-3 px-4 text-sm font-medium text-muted-foreground">Growth Rate</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {mockUserGrowthData.slice(-10).reverse().map((data, index) => (
                                                    <tr key={index} className="border-b border-border/50 hover:bg-accent/50 transition-colors">
                                                        <td className="py-3 px-4 text-sm">{new Date(data.date).toLocaleDateString()}</td>
                                                        <td className="py-3 px-4 text-sm text-right font-medium">{data.newUsers}</td>
                                                        <td className="py-3 px-4 text-sm text-right">{data.totalUsers.toLocaleString()}</td>
                                                        <td className="py-3 px-4 text-sm text-right text-green-600">
                                                            +{((data.newUsers / data.totalUsers) * 100).toFixed(2)}%
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
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Total Revenue</p>
                                        <p className="text-3xl font-bold mt-2">GH₵ 97,950</p>
                                        <p className="text-sm text-green-600 mt-1">+15.3% vs last week</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Avg. Order Value</p>
                                        <p className="text-3xl font-bold mt-2">GH₵ 84.50</p>
                                        <p className="text-sm text-muted-foreground mt-1">per order</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Total Orders</p>
                                        <p className="text-3xl font-bold mt-2">1,155</p>
                                        <p className="text-sm text-green-600 mt-1">+8.7% vs last week</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Revenue/Day</p>
                                        <p className="text-3xl font-bold mt-2">GH₵ 13,993</p>
                                        <p className="text-sm text-muted-foreground mt-1">average</p>
                                    </Card>
                                </div>

                                {/* Revenue Trend Chart */}
                                <Card className="p-6 border-border/50">
                                    <h3 className="text-lg font-semibold mb-6">Revenue Trend (Last 7 Days)</h3>
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
                                                    <tr key={vendor.id} className="border-b border-border/50 hover:bg-accent/50 transition-colors">
                                                        <td className="py-3 px-4 text-sm font-bold text-[#FE6132]">#{(currentPage - 1) * itemsPerPage + index + 1}</td>
                                                        <td className="py-3 px-4 text-sm font-medium">{vendor.name}</td>
                                                        <td className="py-3 px-4">
                                                            <span className={`text-[10px] px-2 py-1 rounded-full font-medium capitalize ${vendor.type === 'food' ? 'bg-orange-100 text-orange-700' :
                                                                vendor.type === 'grocery' ? 'bg-green-100 text-green-700' :
                                                                    vendor.type === 'pharmacy' ? 'bg-blue-100 text-blue-700' :
                                                                        'bg-purple-100 text-purple-700'
                                                                }`}>
                                                                {vendor.type}
                                                            </span>
                                                        </td>
                                                        <td className="py-3 px-4 text-sm text-right">{vendor.orders}</td>
                                                        <td className="py-3 px-4 text-sm text-right font-semibold">GH₵ {vendor.revenue.toLocaleString()}</td>
                                                        <td className="py-3 px-4 text-sm text-right">⭐ {vendor.rating}</td>
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
                                        <p className="text-3xl font-bold mt-2">1,155</p>
                                        <p className="text-sm text-green-600 mt-1">+8.7% vs last week</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Food Orders</p>
                                        <p className="text-3xl font-bold mt-2">687</p>
                                        <p className="text-sm text-muted-foreground mt-1">59.5% of total</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Grocery Orders</p>
                                        <p className="text-3xl font-bold mt-2">298</p>
                                        <p className="text-sm text-muted-foreground mt-1">25.8% of total</p>
                                    </Card>
                                    <Card className="p-6 border-border/50">
                                        <p className="text-sm text-muted-foreground">Avg. Daily Orders</p>
                                        <p className="text-3xl font-bold mt-2">165</p>
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
