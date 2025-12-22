"use client";

import { useState, useMemo, useEffect } from "react";
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
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuRadioGroup,
    DropdownMenuRadioItem,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from "@grabgo/ui";
import { Search, Filter, Download, Plus, Star, Shop, Xmark } from "iconoir-react";
import { mockVendors, type Vendor } from "../../../lib/mockData";
import { format } from "date-fns";

import { RegisterVendorDialog } from "./RegisterVendorDialog";

export default function VendorsPage() {
    const router = useRouter();
    const [searchQuery, setSearchQuery] = useState("");
    const [typeFilter, setTypeFilter] = useState<"all" | "food" | "grocery" | "pharmacy" | "market">("all");
    const [statusFilter, setStatusFilter] = useState<"all" | "open" | "closed" | "busy" | "under_review">("all");
    const [currentPage, setCurrentPage] = useState(1);
    const [itemsPerPage, setItemsPerPage] = useState(10);
    const [isInitialLoading, setIsInitialLoading] = useState(true);
    const [vendors, setVendors] = useState<Vendor[]>(mockVendors);
    const [isRegisterOpen, setIsRegisterOpen] = useState(false);

    // Simulate initial loading
    useEffect(() => {
        const timer = setTimeout(() => {
            setIsInitialLoading(false);
        }, 1000);
        return () => clearTimeout(timer);
    }, []);

    // Apply filters
    const filteredVendors = useMemo(() => {
        return vendors.filter((vendor) => {
            const matchesSearch = vendor.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                vendor.ownerName.toLowerCase().includes(searchQuery.toLowerCase());

            const matchesType = typeFilter === "all" || vendor.type === typeFilter;
            const matchesStatus = statusFilter === "all" || vendor.status === statusFilter;

            return matchesSearch && matchesType && matchesStatus;
        });
    }, [searchQuery, typeFilter, statusFilter, vendors]);

    // Pagination
    const totalPages = Math.ceil(filteredVendors.length / itemsPerPage);
    const startIndex = (currentPage - 1) * itemsPerPage;
    const endIndex = Math.min(startIndex + itemsPerPage, filteredVendors.length);
    const paginatedVendors = filteredVendors.slice(startIndex, endIndex);

    const clearFilters = () => {
        setSearchQuery("");
        setTypeFilter("all");
        setStatusFilter("all");
        setCurrentPage(1);
    };

    const handleRegisterSuccess = (newVendor: Vendor) => {
        setVendors((prev) => [newVendor, ...prev]);
        setTypeFilter("all");
        setStatusFilter("all");
        setSearchQuery("");
    };

    const activeFilterCount = (typeFilter !== "all" ? 1 : 0) + (statusFilter !== "all" ? 1 : 0);

    const getStatusBadge = (status: Vendor["status"]) => {
        switch (status) {
            case "open": return <Badge variant="success">Open</Badge>;
            case "busy": return <Badge variant="warning">Busy</Badge>;
            case "closed": return <Badge variant="destructive">Closed</Badge>;
            case "under_review": return <Badge variant="outline" className="border-amber-500 text-amber-600">Under Review</Badge>;
            default: return <Badge variant="outline">{status}</Badge>;
        }
    };

    const getTypeIcon = (type: Vendor["type"]) => {
        // You could use different icons here for each type
        return <Shop className="w-4 h-4" />;
    };

    return (
        <div className="p-6 space-y-6">
            {/* Page Header */}
            <div className="flex items-center justify-between animate-fade-in-left">
                <div>
                    <h1 className="text-3xl font-bold">Vendors</h1>
                    <p className="text-muted-foreground mt-1">
                        Manage restaurants, groceries, pharmacies, and markets
                    </p>
                </div>
                <Button
                    onClick={() => setIsRegisterOpen(true)}
                    className="bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 text-white hover:opacity-90"
                >
                    <Plus className="w-4 h-4 mr-2" />
                    Register Vendor
                </Button>
            </div>

            {/* Filters */}
            <Card className="p-6 border-border/50 animate-fade-in-right">
                <div className="flex items-center gap-4">
                    <div className="flex-1 relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                        <Input
                            placeholder="Search by vendor name or owner..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="pl-10 bg-accent/50 border-border/50 focus:bg-background transition-colors"
                        />
                    </div>

                    {/* Service Type Tab-like Filter */}
                    <div className="hidden lg:flex items-center bg-muted/40 p-1 rounded-lg border border-border/50 gap-1 h-10">
                        {["all", "food", "grocery", "pharmacy", "market"].map((type) => (
                            <button
                                key={type}
                                onClick={() => { setTypeFilter(type as any); setCurrentPage(1); }}
                                className={`px-4 h-full rounded-md text-sm font-medium transition-all duration-200 ${typeFilter === type
                                    ? "bg-background text-[#FE6132] shadow-sm ring-1 ring-black/5 dark:ring-white/5"
                                    : "text-muted-foreground hover:text-foreground hover:bg-background/40"
                                    } capitalize`}
                            >
                                {type}
                            </button>
                        ))}
                    </div>

                    <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                            <Button variant="outline" className="gap-2 border-border/50">
                                <Filter className="w-4 h-4" />
                                Filters
                                {activeFilterCount > 0 && (
                                    <Badge variant="secondary" className="ml-1 px-1.5 py-0 text-xs">
                                        {activeFilterCount}
                                    </Badge>
                                )}
                            </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="w-56">
                            <DropdownMenuLabel>Service Type</DropdownMenuLabel>
                            <DropdownMenuRadioGroup value={typeFilter} onValueChange={(v) => { setTypeFilter(v as any); setCurrentPage(1); }}>
                                <DropdownMenuRadioItem value="all">All Services</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="food">Food</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="grocery">Grocery</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="pharmacy">Pharmacy</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="market">Market</DropdownMenuRadioItem>
                            </DropdownMenuRadioGroup>

                            <DropdownMenuSeparator />

                            <DropdownMenuLabel>Operation Status</DropdownMenuLabel>
                            <DropdownMenuRadioGroup value={statusFilter} onValueChange={(v) => { setStatusFilter(v as any); setCurrentPage(1); }}>
                                <DropdownMenuRadioItem value="all">All Statuses</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="open">Open</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="busy">Busy</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="closed">Closed</DropdownMenuRadioItem>
                                <DropdownMenuRadioItem value="under_review">Under Review</DropdownMenuRadioItem>
                            </DropdownMenuRadioGroup>

                            {activeFilterCount > 0 && (
                                <>
                                    <DropdownMenuSeparator />
                                    <DropdownMenuItem onClick={clearFilters} className="text-destructive">
                                        <Xmark className="w-4 h-4 mr-2" />
                                        Clear Filters
                                    </DropdownMenuItem>
                                </>
                            )}
                        </DropdownMenuContent>
                    </DropdownMenu>

                    <Button variant="outline" className="gap-2 border-border/50">
                        <Download className="w-4 h-4" />
                        Export
                    </Button>
                </div>
            </Card>

            {/* List Table */}
            <Card className="overflow-hidden border-border/50 animate-fade-in-up">
                <div className="overflow-x-auto">
                    <table className="w-full">
                        <thead className="bg-muted/50 border-b border-border/50">
                            <tr>
                                <th className="text-left p-4 font-semibold text-sm">Vendor</th>
                                <th className="text-left p-4 font-semibold text-sm">Type</th>
                                <th className="text-left p-4 font-semibold text-sm">Owner & Contact</th>
                                <th className="text-left p-4 font-semibold text-sm">Status</th>
                                <th className="text-left p-4 font-semibold text-sm">Rating</th>
                                <th className="text-left p-4 font-semibold text-sm">Performance</th>
                                <th className="text-right p-4 font-semibold text-sm">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-border/50">
                            {isInitialLoading ? (
                                Array.from({ length: 5 }).map((_, i) => (
                                    <tr key={i} className="animate-pulse">
                                        <td className="p-4" colSpan={7}>
                                            <div className="h-12 bg-muted rounded-md w-full" />
                                        </td>
                                    </tr>
                                ))
                            ) : paginatedVendors.map((vendor) => (
                                <tr
                                    key={vendor.id}
                                    className="hover:bg-muted/30 transition-colors cursor-pointer"
                                    onClick={() => router.push(`/vendors/${vendor.id}`)}
                                >
                                    <td className="p-4">
                                        <div className="flex items-center gap-3">
                                            <div className="w-10 h-10 rounded-md bg-gradient-to-br from-accent to-accent-foreground/10 flex items-center justify-center text-primary font-bold">
                                                {vendor.logo ? (
                                                    <img src={vendor.logo} alt={vendor.name} className="w-full h-full object-cover rounded-md" />
                                                ) : (
                                                    vendor.name.charAt(0)
                                                )}
                                            </div>
                                            <div>
                                                <div className="font-semibold flex items-center gap-2">
                                                    {vendor.name}
                                                    {vendor.isVerified && <Badge variant="outline" className="text-[10px] px-1 py-0 border-blue-200 text-blue-600 bg-blue-50">Verified</Badge>}
                                                </div>
                                                <div className="text-xs text-muted-foreground">{vendor.id}</div>
                                            </div>
                                        </div>
                                    </td>
                                    <td className="p-4">
                                        <div className="flex items-center gap-2 capitalize text-sm">
                                            {getTypeIcon(vendor.type)}
                                            {vendor.type}
                                        </div>
                                    </td>
                                    <td className="p-4">
                                        <div className="text-sm">
                                            <div className="font-medium">{vendor.ownerName}</div>
                                            <div className="text-muted-foreground">{vendor.phone}</div>
                                        </div>
                                    </td>
                                    <td className="p-4">
                                        {getStatusBadge(vendor.status)}
                                    </td>
                                    <td className="p-4">
                                        <div className="flex items-center gap-1">
                                            <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                                            <span className="font-medium">{vendor.rating.toFixed(1)}</span>
                                        </div>
                                    </td>
                                    <td className="p-4">
                                        <div className="text-sm">
                                            <div className="font-semibold">GH₵{vendor.totalRevenue.toLocaleString()}</div>
                                            <div className="text-muted-foreground text-xs">{vendor.orderCount} orders</div>
                                        </div>
                                    </td>
                                    <td className="p-4 text-right">
                                        <Button variant="ghost" size="sm">Manage</Button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>

                {paginatedVendors.length === 0 && !isInitialLoading && (
                    <div className="p-12 text-center">
                        <div className="flex flex-col items-center justify-center space-y-3">
                            <Shop className="w-10 h-10 text-muted-foreground opacity-20" />
                            <h3 className="text-lg font-semibold">No vendors found</h3>
                            <p className="text-muted-foreground max-w-sm mx-auto text-sm">
                                Try adjusting your filters or search query to find the vendor you're looking for.
                            </p>
                            <Button variant="outline" size="sm" onClick={clearFilters}>Clear Filters</Button>
                        </div>
                    </div>
                )}
            </Card>

            <RegisterVendorDialog
                open={isRegisterOpen}
                onOpenChange={setIsRegisterOpen}
                onSuccess={handleRegisterSuccess}
            />
        </div>
    );
}
