"use client";

import { useState, useMemo } from "react";
import { useRouter } from "next/navigation";
import {
    Card,
    Input,
    Button,
    Badge,
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@grabgo/ui";
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuRadioGroup,
    DropdownMenuRadioItem,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from "@grabgo/ui";
import { Search, Filter, Download, Plus, CheckCircleSolid, Xmark } from "iconoir-react";
import { mockCustomers, type Customer } from "../../../lib/mockData";
import { format } from "date-fns";

export default function UsersPage() {
    const router = useRouter();
    const [searchQuery, setSearchQuery] = useState("");
    const [statusFilter, setStatusFilter] = useState<"all" | "active" | "inactive">("all");
    const [verificationFilter, setVerificationFilter] = useState<"all" | "verified" | "unverified">("all");
    const [currentPage, setCurrentPage] = useState(1);
    const [itemsPerPage, setItemsPerPage] = useState(10);
    const [customers] = useState<Customer[]>(mockCustomers);
    const [isInitialLoading, setIsInitialLoading] = useState(true);

    // Simulate initial loading
    useMemo(() => {
        const timer = setTimeout(() => {
            setIsInitialLoading(false);
        }, 1000);
        return () => clearTimeout(timer);
    }, []);

    // Apply all filters
    const filteredCustomers = useMemo(() => {
        return customers.filter((customer) => {
            // Search filter
            const query = searchQuery.toLowerCase();
            const matchesSearch =
                customer.username.toLowerCase().includes(query) ||
                customer.email.toLowerCase().includes(query) ||
                customer.phone.includes(query);

            // Status filter
            const matchesStatus =
                statusFilter === "all" ||
                (statusFilter === "active" && customer.isActive) ||
                (statusFilter === "inactive" && !customer.isActive);

            // Verification filter
            const matchesVerification =
                verificationFilter === "all" ||
                (verificationFilter === "verified" && customer.emailVerified && customer.phoneVerified) ||
                (verificationFilter === "unverified" && (!customer.emailVerified || !customer.phoneVerified));

            return matchesSearch && matchesStatus && matchesVerification;
        });
    }, [customers, searchQuery, statusFilter, verificationFilter]);

    // Pagination calculations
    const totalPages = Math.ceil(filteredCustomers.length / itemsPerPage);
    const startIndex = (currentPage - 1) * itemsPerPage;
    const endIndex = Math.min(startIndex + itemsPerPage, filteredCustomers.length);
    const paginatedCustomers = filteredCustomers.slice(startIndex, endIndex);

    // Reset to page 1 when filters change
    const handleFilterChange = () => {
        setCurrentPage(1);
    };

    // Clear all filters
    const clearFilters = () => {
        setStatusFilter("all");
        setVerificationFilter("all");
        setSearchQuery("");
        setCurrentPage(1);
    };

    // Handle Export
    const handleExport = () => {
        const headers = ["ID", "Username", "Email", "Phone", "Status", "Total Orders", "Total Spending", "Joined Date"];
        const csvContent = [
            headers.join(","),
            ...filteredCustomers.map(c => [
                c.id,
                `"${c.username}"`,
                c.email,
                `"${c.phone}"`,
                c.isActive ? "Active" : "Inactive",
                c.totalOrders,
                c.totalSpending.toFixed(2),
                format(new Date(c.createdAt), "yyyy-MM-dd")
            ].join(","))
        ].join("\n");

        const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
        const link = document.createElement("a");
        const url = URL.createObjectURL(blob);
        link.setAttribute("href", url);
        link.setAttribute("download", `customers_export_${format(new Date(), "yyyyMMdd_HHmmss")}.csv`);
        link.style.visibility = "hidden";
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    };

    // Count active filters
    const activeFilterCount =
        (statusFilter !== "all" ? 1 : 0) +
        (verificationFilter !== "all" ? 1 : 0);

    return (
        <div className="space-y-6">
            {/* Page Header */}
            <div className="flex items-center justify-between animate-fade-in-up">
                <div>
                    <h1 className="text-4xl font-extrabold tracking-tight">Customer Network</h1>
                    <p className="text-muted-foreground mt-2 text-lg font-medium">
                        Comprehensive management and behavioral monitoring of all user accounts
                    </p>
                </div>
                <Button
                    className="bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 text-white hover:shadow-lg hover:shadow-orange-200 transition-all font-bold rounded-xl h-12 px-6 hover:scale-105 active:scale-95"
                >
                    <Plus className="w-5 h-5 mr-2" />
                    Expand Network
                </Button>
            </div>

            {/* Filters and Search */}
            <Card className="p-6 border-border/50 animate-fade-in-up [animation-delay:100ms] hover:shadow-md transition-shadow">
                <div className="flex items-center gap-4">
                    <div className="flex-1 relative group">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground group-focus-within:text-[#FE6132] transition-colors" />
                        <Input
                            placeholder="Search by identity, email, or digital contact..."
                            value={searchQuery}
                            onChange={(e: React.ChangeEvent<HTMLInputElement>) => setSearchQuery(e.target.value)}
                            className="pl-12 h-12 bg-accent/30 border-border/50 focus:bg-background transition-all rounded-xl font-medium"
                        />
                    </div>
                    <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                            <Button variant="outline" className="gap-2 border-border/50 h-12 px-5 rounded-xl font-bold bg-background hover:bg-accent transition-all">
                                <Filter className="w-4 h-4" />
                                Filter Intelligence
                                {activeFilterCount > 0 && (
                                    <Badge className="ml-1 px-2 py-0.5 text-[10px] bg-[#FE6132] text-white font-black border-0">
                                        {activeFilterCount}
                                    </Badge>
                                )}
                            </Button>
                        </DropdownMenuTrigger>
                        {/* ... content remains same ... */}
                        <DropdownMenuContent align="end" className="w-64 p-2 rounded-xl border-border/50 shadow-xl">
                            <DropdownMenuLabel className="px-3 py-2 text-xs font-black uppercase tracking-widest text-muted-foreground">Account Status</DropdownMenuLabel>
                            <DropdownMenuRadioGroup
                                value={statusFilter}
                                onValueChange={(value) => {
                                    setStatusFilter(value as "all" | "active" | "inactive");
                                    handleFilterChange();
                                }}
                            >
                                <DropdownMenuRadioItem value="all" className="rounded-lg">All Statuses</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="active" className="rounded-lg">Active Performance</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="inactive" className="rounded-lg">Inactive Accounts</DropdownMenuRadioItem>
                            </DropdownMenuRadioGroup>

                            <DropdownMenuSeparator className="my-2" />

                            <DropdownMenuLabel className="px-3 py-2 text-xs font-black uppercase tracking-widest text-muted-foreground">Verification Tier</DropdownMenuLabel>
                            <DropdownMenuRadioGroup
                                value={verificationFilter}
                                onValueChange={(value) => {
                                    setVerificationFilter(value as "all" | "verified" | "unverified");
                                    handleFilterChange();
                                }}
                            >
                                <DropdownMenuRadioItem value="all" className="rounded-lg">All Verifications</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="verified" className="rounded-lg">Verified Identity</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="unverified" className="rounded-lg">Pending Verification</DropdownMenuRadioItem>
                            </DropdownMenuRadioGroup>

                            {activeFilterCount > 0 && (
                                <>
                                    <DropdownMenuSeparator className="my-2" />
                                    <DropdownMenuItem onClick={clearFilters} className="text-destructive font-bold rounded-lg focus:bg-red-50 focus:text-red-600 transition-colors">
                                        <Xmark className="w-4 h-4 mr-2" />
                                        Reset All Filters
                                    </DropdownMenuItem>
                                </>
                            )}
                        </DropdownMenuContent>
                    </DropdownMenu>
                    <Button
                        variant="outline"
                        className="gap-2 border-border/50 h-12 px-5 rounded-xl font-bold hover:shadow-sm transition-all"
                        onClick={handleExport}
                        disabled={filteredCustomers.length === 0}
                    >
                        <Download className="w-4 h-4" />
                        Export Data
                    </Button>
                </div>
            </Card>

            {/* Customer Table */}
            <Card className="overflow-hidden border-border/50 animate-fade-in-up" style={{ animationDelay: "200ms" }}>
                <div className="overflow-x-auto">
                    <table className="w-full">
                        <thead className="bg-muted/50 border-b border-border/50">
                            <tr>
                                <th className="text-left p-4 font-semibold text-sm">Customer</th>
                                <th className="text-left p-4 font-semibold text-sm">Contact</th>
                                <th className="text-left p-4 font-semibold text-sm">Status</th>
                                <th className="text-left p-4 font-semibold text-sm">Orders</th>
                                <th className="text-left p-4 font-semibold text-sm">Spending</th>
                                <th className="text-left p-4 font-semibold text-sm">Joined</th>
                                <th className="text-right p-4 font-semibold text-sm">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-border/50">
                            {isInitialLoading ? (
                                // Skeleton Loaders
                                Array.from({ length: itemsPerPage }).map((_, i) => (
                                    <tr key={`skeleton-${i}`} className="animate-pulse">
                                        <td className="p-4">
                                            <div className="flex items-center gap-3">
                                                <div className="w-10 h-10 rounded-md bg-muted" />
                                                <div className="space-y-2">
                                                    <div className="h-4 w-24 bg-muted rounded" />
                                                    <div className="h-3 w-12 bg-muted rounded" />
                                                </div>
                                            </div>
                                        </td>
                                        <td className="p-4">
                                            <div className="space-y-2">
                                                <div className="h-4 w-40 bg-muted rounded" />
                                                <div className="h-4 w-32 bg-muted rounded" />
                                            </div>
                                        </td>
                                        <td className="p-4">
                                            <div className="h-6 w-16 bg-muted rounded-full" />
                                        </td>
                                        <td className="p-4">
                                            <div className="h-4 w-8 bg-muted rounded" />
                                        </td>
                                        <td className="p-4">
                                            <div className="h-4 w-20 bg-muted rounded" />
                                        </td>
                                        <td className="p-4">
                                            <div className="h-4 w-24 bg-muted rounded" />
                                        </td>
                                        <td className="p-4 text-right">
                                            <div className="flex justify-end gap-2">
                                                <div className="h-8 w-12 bg-muted rounded" />
                                                <div className="h-8 w-12 bg-muted rounded" />
                                            </div>
                                        </td>
                                    </tr>
                                ))
                            ) : (
                                paginatedCustomers.map((customer, index) => (
                                    <tr
                                        key={customer.id}
                                        onClick={() => router.push(`/users/${customer.id}`)}
                                        className="hover:bg-accent/40 transition-all cursor-pointer group animate-fade-in-up border-b border-border/50 last:border-0"
                                        style={{ animationDelay: `${200 + index * 50}ms` }}
                                    >
                                        {/* Customer Info */}
                                        <td className="p-4">
                                            <div className="flex items-center gap-4">
                                                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 flex items-center justify-center text-white font-black shadow-sm group-hover:scale-110 transition-transform">
                                                    {customer.username.charAt(0).toUpperCase()}
                                                </div>
                                                <div>
                                                    <div className="font-bold text-foreground group-hover:text-[#FE6132] transition-colors">{customer.username}</div>
                                                    <div className="text-xs font-bold text-muted-foreground uppercase tracking-tighter">
                                                        U-ID: {customer.id.slice(0, 8)}
                                                    </div>
                                                </div>
                                            </div>
                                        </td>

                                        {/* Contact */}
                                        <td className="p-4">
                                            <div className="space-y-1.5">
                                                <div className="flex items-center gap-2 text-sm font-medium">
                                                    <span>{customer.email}</span>
                                                    {customer.emailVerified && (
                                                        <CheckCircleSolid className="w-4 h-4 text-green-500" />
                                                    )}
                                                </div>
                                                <div className="flex items-center gap-2 text-xs font-bold text-muted-foreground">
                                                    <span className="bg-accent/50 px-1.5 py-0.5 rounded text-[10px]">PHONE</span>
                                                    <span>{customer.phone}</span>
                                                    {customer.phoneVerified && (
                                                        <CheckCircleSolid className="w-3.5 h-3.5 text-green-500" />
                                                    )}
                                                </div>
                                            </div>
                                        </td>

                                        {/* Status */}
                                        <td className="p-4">
                                            <div className="group-hover:scale-105 transition-transform origin-left">
                                                <Badge variant={customer.isActive ? "success" : "destructive"}>
                                                    {customer.isActive ? "Active" : "Inactive"}
                                                </Badge>
                                            </div>
                                        </td>

                                        {/* Orders */}
                                        <td className="p-4">
                                            <div className="font-black text-foreground">{customer.totalOrders.toLocaleString()}</div>
                                        </td>

                                        {/* Spending */}
                                        <td className="p-4">
                                            <div className="font-black text-foreground">
                                                GH₵{customer.totalSpending.toLocaleString("en-GH", {
                                                    minimumFractionDigits: 2,
                                                    maximumFractionDigits: 2,
                                                })}
                                            </div>
                                        </td>

                                        {/* Joined Date */}
                                        <td className="p-4">
                                            <div className="text-sm font-bold text-muted-foreground">
                                                {format(new Date(customer.createdAt), "MMM dd, yyyy")}
                                            </div>
                                        </td>

                                        {/* Actions */}
                                        <td className="p-4">
                                            <div className="flex items-center justify-end gap-2">
                                                <Button variant="ghost" size="sm" className="rounded-lg h-9 font-bold hover:bg-accent transition-all ring-0 border-0 outline-none">
                                                    More
                                                </Button>
                                            </div>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>

                {/* Empty State */}
                {!isInitialLoading && filteredCustomers.length === 0 && (
                    <div className="p-12 text-center animate-fade-in">
                        <div className="flex flex-col items-center justify-center space-y-3">
                            <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center">
                                <Search className="w-8 h-8 text-muted-foreground opacity-20" />
                            </div>
                            <div className="space-y-1">
                                <h3 className="text-lg font-semibold">No customers found</h3>
                                <p className="text-muted-foreground max-w-sm mx-auto text-sm">
                                    We couldn't find any customers matching your current search or filters. Try adjusting them.
                                </p>
                            </div>
                            <Button
                                variant="outline"
                                size="sm"
                                onClick={clearFilters}
                                className="mt-2 border-border/50"
                            >
                                Clear all filters
                            </Button>
                        </div>
                    </div>
                )}

                {/* Pagination */}
                <div className="border-t border-border/50 p-4 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <span className="text-sm text-muted-foreground">Show</span>
                        <Select
                            value={itemsPerPage.toString()}
                            onValueChange={(value) => {
                                setItemsPerPage(Number(value));
                                setCurrentPage(1);
                            }}
                        >
                            <SelectTrigger className="w-20 h-8 border-border/50">
                                <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="10">10</SelectItem>
                                <SelectItem value="25">25</SelectItem>
                                <SelectItem value="50">50</SelectItem>
                                <SelectItem value="100">100</SelectItem>
                            </SelectContent>
                        </Select>
                        <span className="text-sm text-muted-foreground">per page</span>
                    </div>

                    <div className="text-sm text-muted-foreground">
                        Showing {filteredCustomers.length > 0 ? startIndex + 1 : 0}-{endIndex} of {filteredCustomers.length} customers
                    </div>

                    <div className="flex items-center gap-2">
                        <Button
                            variant="outline"
                            size="sm"
                            className="border-border/50"
                            onClick={() => setCurrentPage(currentPage - 1)}
                            disabled={currentPage === 1}
                        >
                            Previous
                        </Button>
                        <span className="text-sm text-muted-foreground">
                            Page {currentPage} of {totalPages || 1}
                        </span>
                        <Button
                            variant="outline"
                            size="sm"
                            className="border-border/50"
                            onClick={() => setCurrentPage(currentPage + 1)}
                            disabled={currentPage >= totalPages}
                        >
                            Next
                        </Button>
                    </div>
                </div>
            </Card>
        </div>
    );
}
