"use client";

import { notFound } from "next/navigation";
import Link from "next/link";
import { useState, use, useEffect } from "react";
import { Card, Badge, Button, Tabs, TabsContent, TabsList, TabsTrigger } from "@grabgo/ui";
import {
    ArrowLeft,
    Edit,
    Shop,
    Star,
    StatsReport,
    ArrowUp,
    CheckCircleSolid,
    CheckCircle,
    InfoCircle,
    Settings,
    Database,
    Cart,
    Plus,
    Clock,
    FireFlame,
} from "iconoir-react";
import { TrendingUp } from "lucide-react";
import { getVendorById, getVendorCatalog, getVendorOrders, type Vendor } from "../../../../lib/mockData";
import { format } from "date-fns";
import { RejectVendorDialog } from "./RejectVendorDialog";
import { SuspendVendorDialog } from "./SuspendVendorDialog";
import { EditVendorDialog } from "./EditVendorDialog";
import { DeliverySettingsDialog } from "./DeliverySettingsDialog";
interface VendorPageProps {
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

export default function VendorDetailPage({ params }: VendorPageProps) {
    const { id } = use(params);
    const initialVendor = getVendorById(id);
    const catalog = getVendorCatalog(id);
    const recentOrders = getVendorOrders(id);

    if (!initialVendor) {
        notFound();
    }

    const [vendor, setVendor] = useState(initialVendor);
    const categories = Array.from(new Set(catalog.map(item => item.category)));
    const [rejectDialogOpen, setRejectDialogOpen] = useState(false);
    const [suspendDialogOpen, setSuspendDialogOpen] = useState(false);
    const [editDialogOpen, setEditDialogOpen] = useState(false);
    const [deliverySettingsDialogOpen, setDeliverySettingsDialogOpen] = useState(false);

    const handleStatusToggle = () => {
        setVendor(prev => ({
            ...prev,
            status: prev.status === "open" ? "closed" : "open"
        }));
    };

    const handleVerifyVendor = () => {
        setVendor(prev => ({
            ...prev,
            isVerified: true,
            status: prev.status === "under_review" ? "open" : prev.status
        }));
    };

    const handleFeaturedToggle = () => {
        setVendor(prev => ({
            ...prev,
            isFeatured: !prev.isFeatured
        }));
    };

    const getStatusVariant = (status: Vendor["status"]) => {
        switch (status) {
            case "open": return "success";
            case "busy": return "warning";
            case "closed": return "destructive";
            case "under_review": return "outline";
            default: return "secondary";
        }
    };

    return (
        <div className="p-6 space-y-6">
            {/* Back Button */}
            <Link href="/vendors">
                <Button variant="ghost" className="gap-2 -ml-2">
                    <ArrowLeft className="w-4 h-4" />
                    Back to Vendors
                </Button>
            </Link>

            {/* Profile Header */}
            <Card className="p-6 border-border/50 animate-fade-in-up">
                <div className="flex flex-col md:flex-row md:items-start justify-between gap-6">
                    <div className="flex items-start gap-6 flex-1">
                        {/* Vendor Logo/Icon */}
                        <div className="w-24 h-24 rounded-md bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 flex items-center justify-center text-white text-3xl font-bold flex-shrink-0">
                            {vendor.logo ? (
                                <img src={vendor.logo} alt={vendor.name} className="w-full h-full object-cover rounded-md" />
                            ) : (
                                vendor.name.charAt(0).toUpperCase()
                            )}
                        </div>

                        {/* Vendor Basic Info */}
                        <div className="space-y-3">
                            <div>
                                <div className="flex items-center gap-2">
                                    <h1 className="text-2xl font-bold">{vendor.name}</h1>
                                    {vendor.isVerified && <CheckCircleSolid className="w-5 h-5 text-blue-500" />}
                                    {vendor.isFeatured && <Badge variant="secondary" className="bg-amber-100 text-amber-700 border-amber-200">Featured</Badge>}
                                </div>
                                <p className="text-sm text-muted-foreground flex items-center gap-2 mt-1">
                                    <span className="capitalize">{vendor.type}</span>
                                    <span>•</span>
                                    <span>{vendor.id}</span>
                                </p>
                            </div>

                            <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
                                <Badge variant={getStatusVariant(vendor.status)}>
                                    {vendor.status.replace("_", " ")}
                                </Badge>
                                <div className="flex items-center gap-1 text-sm font-medium">
                                    <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                                    {vendor.rating.toFixed(1)}
                                </div>
                                <div className="text-sm text-muted-foreground">
                                    {vendor.address}
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Actions */}
                    <div className="grid grid-cols-2 lg:flex lg:flex-wrap gap-2 w-full md:w-auto">
                        <Button
                            variant="outline"
                            size="sm"
                            className="gap-2 border-border/50 h-10 md:h-9"
                            onClick={() => setEditDialogOpen(true)}
                        >
                            <Edit className="w-4 h-4" />
                            Edit Profile
                        </Button>
                        <Button
                            variant="outline"
                            size="sm"
                            className="gap-2 border-border/50 h-10 md:h-9"
                            onClick={() => setDeliverySettingsDialogOpen(true)}
                        >
                            <Settings className="w-4 h-4" />
                            Delivery Settings
                        </Button>

                        {vendor.status === "under_review" ? (
                            <>
                                <Button
                                    className="gap-2 h-10 md:h-9 bg-blue-600 hover:bg-blue-700 text-white"
                                    onClick={handleVerifyVendor}
                                >
                                    <CheckCircleSolid className="w-4 h-4" />
                                    Approve Vendor
                                </Button>
                                <Button
                                    className="gap-2 h-10 md:h-9 bg-red-600 hover:bg-red-700 text-white"
                                    onClick={() => setRejectDialogOpen(true)}
                                >
                                    Reject Application
                                </Button>
                            </>
                        ) : (
                            <>
                                <Button
                                    className={`gap-2 h-10 md:h-9 ${vendor.status === "open" ? "bg-red-500 hover:bg-red-600" : "bg-green-500 hover:bg-green-600"} text-white`}
                                    onClick={handleStatusToggle}
                                >
                                    {vendor.status === "open" ? "Close Vendor" : "Open Vendor"}
                                </Button>
                                <Button
                                    className="gap-2 h-10 md:h-9 bg-orange-600 hover:bg-orange-700 text-white"
                                    onClick={() => setSuspendDialogOpen(true)}
                                >
                                    {vendor.status === "suspended" ? "Unsuspend" : "Suspend"} Vendor
                                </Button>
                            </>
                        )}
                    </div>
                </div>
            </Card>

            {/* Dialogs */}
            <RejectVendorDialog
                vendor={vendor}
                open={rejectDialogOpen}
                onOpenChange={setRejectDialogOpen}
            />
            <SuspendVendorDialog
                vendor={vendor}
                open={suspendDialogOpen}
                onOpenChange={setSuspendDialogOpen}
            />
            <EditVendorDialog
                vendor={vendor}
                open={editDialogOpen}
                onOpenChange={setEditDialogOpen}
            />
            <DeliverySettingsDialog
                vendor={vendor}
                open={deliverySettingsDialogOpen}
                onOpenChange={setDeliverySettingsDialogOpen}
            />

            {/* Stats Row */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-lg transition-all hover:-translate-y-1 group" style={{ animationDelay: "100ms" }}>
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-xl bg-[#FE6132]/10 flex items-center justify-center group-hover:scale-110 transition-transform">
                            <TrendingUp className="w-6 h-6 text-[#FE6132]" />
                        </div>
                        <div>
                            <p className="text-2xl font-black text-foreground">GH₵<AnimatedNumber value={vendor.totalRevenue} delay={100} /></p>
                            <p className="text-xs font-bold text-muted-foreground uppercase tracking-widest">Revenue</p>
                        </div>
                    </div>
                </Card>

                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-lg transition-all hover:-translate-y-1 group" style={{ animationDelay: "200ms" }}>
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-xl bg-blue-500/10 flex items-center justify-center group-hover:scale-110 transition-transform">
                            <Cart className="w-6 h-6 text-blue-600" />
                        </div>
                        <div>
                            <p className="text-2xl font-black text-foreground"><AnimatedNumber value={vendor.orderCount} delay={200} /></p>
                            <p className="text-xs font-bold text-muted-foreground uppercase tracking-widest">Total Orders</p>
                        </div>
                    </div>
                </Card>

                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-lg transition-all hover:-translate-y-1 group" style={{ animationDelay: "300ms" }}>
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-xl bg-purple-500/10 flex items-center justify-center group-hover:scale-110 transition-transform">
                            <Star className="w-6 h-6 text-purple-600" />
                        </div>
                        <div>
                            <p className="text-2xl font-black text-foreground"><AnimatedNumber value={vendor.rating} delay={300} decimals={1} /></p>
                            <p className="text-xs font-bold text-muted-foreground uppercase tracking-widest">Avg Rating</p>
                        </div>
                    </div>
                </Card>

                <Card className="p-6 border-border/50 animate-fade-in-up hover:shadow-lg transition-all hover:-translate-y-1 group" style={{ animationDelay: "400ms" }}>
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-4">
                            <div className="w-12 h-12 rounded-xl bg-green-500/10 flex items-center justify-center group-hover:scale-110 transition-transform">
                                <ArrowUp className="w-6 h-6 text-green-600" />
                            </div>
                            <div>
                                <p className="text-2xl font-black text-foreground">+<AnimatedNumber value={12} delay={400} />%</p>
                                <p className="text-xs font-bold text-muted-foreground uppercase tracking-widest">Growth</p>
                            </div>
                        </div>
                    </div>
                </Card>
            </div>

            {/* Tabs Content */}
            <Card className="border-border/50 overflow-hidden animate-fade-in-up" style={{ animationDelay: "500ms" }}>
                <Tabs defaultValue="info" className="w-full">
                    <div className="border-b border-border/50">
                        <TabsList className="bg-transparent h-auto p-0 w-full justify-start px-6">
                            <TabsTrigger
                                value="info"
                                className="rounded-none border-b-2 border-transparent data-[state=active]:border-[#FE6132] data-[state=active]:bg-transparent data-[state=active]:text-foreground text-muted-foreground hover:text-foreground transition-all px-6 py-4 font-medium data-[state=active]:shadow-none"
                            >
                                <InfoCircle className="w-4 h-4 mr-2" />
                                Vendor Info
                            </TabsTrigger>
                            <TabsTrigger
                                value="catalog"
                                className="rounded-none border-b-2 border-transparent data-[state=active]:border-[#FE6132] data-[state=active]:bg-transparent data-[state=active]:text-foreground text-muted-foreground hover:text-foreground transition-all px-6 py-4 font-medium data-[state=active]:shadow-none"
                            >
                                <Database className="w-4 h-4 mr-2" />
                                Catalog / Inventory
                            </TabsTrigger>
                            <TabsTrigger
                                value="orders"
                                className="rounded-none border-b-2 border-transparent data-[state=active]:border-[#FE6132] data-[state=active]:bg-transparent data-[state=active]:text-foreground text-muted-foreground hover:text-foreground transition-all px-6 py-4 font-medium data-[state=active]:shadow-none"
                            >
                                <Cart className="w-4 h-4 mr-2" />
                                Recent Orders
                            </TabsTrigger>
                            <TabsTrigger
                                value="verification"
                                className="rounded-none border-b-2 border-transparent data-[state=active]:border-[#FE6132] data-[state=active]:bg-transparent data-[state=active]:text-foreground text-muted-foreground hover:text-foreground transition-all px-6 py-4 font-medium data-[state=active]:shadow-none"
                            >
                                <CheckCircle className="w-4 h-4 mr-2" />
                                Verification
                            </TabsTrigger>
                            <TabsTrigger
                                value="settings"
                                className="rounded-none border-b-2 border-transparent data-[state=active]:border-[#FE6132] data-[state=active]:bg-transparent data-[state=active]:text-foreground text-muted-foreground hover:text-foreground transition-all px-6 py-4 font-medium data-[state=active]:shadow-none"
                            >
                                <Settings className="w-4 h-4 mr-2" />
                                Settings
                            </TabsTrigger>
                        </TabsList>
                    </div>

                    {/* Verification Tab */}
                    <TabsContent value="verification" className="p-6 space-y-6 animate-fade-in">
                        <div className="space-y-6">
                            {/* Documents Section */}
                            <div>
                                <h3 className="font-semibold text-lg border-b pb-2 mb-4">Verification Documents</h3>
                                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                                    {/* Business ID Photo */}
                                    <div className="space-y-2">
                                        <label className="text-sm font-medium text-muted-foreground">Business ID Document</label>
                                        <div className="border-2 border-dashed border-border/50 rounded-lg p-4 bg-muted/20 hover:bg-muted/40 transition-colors">
                                            <div className="aspect-video bg-gradient-to-br from-gray-100 to-gray-200 dark:from-gray-800 dark:to-gray-900 rounded flex items-center justify-center">
                                                <p className="text-sm text-muted-foreground">Business ID Photo</p>
                                                {/* TODO: Replace with actual image when available */}
                                                {/* <img src={vendor.business_id_photo} alt="Business ID" className="w-full h-full object-cover rounded" /> */}
                                            </div>
                                        </div>
                                        <p className="text-xs text-muted-foreground">Business registration or license document</p>
                                    </div>

                                    {/* Owner Photo */}
                                    <div className="space-y-2">
                                        <label className="text-sm font-medium text-muted-foreground">Owner ID Photo</label>
                                        <div className="border-2 border-dashed border-border/50 rounded-lg p-4 bg-muted/20 hover:bg-muted/40 transition-colors">
                                            <div className="aspect-video bg-gradient-to-br from-gray-100 to-gray-200 dark:from-gray-800 dark:to-gray-900 rounded flex items-center justify-center">
                                                <p className="text-sm text-muted-foreground">Owner Photo</p>
                                                {/* TODO: Replace with actual image when available */}
                                                {/* <img src={vendor.owner_photo} alt="Owner ID" className="w-full h-full object-cover rounded" /> */}
                                            </div>
                                        </div>
                                        <p className="text-xs text-muted-foreground">Owner's identification document</p>
                                    </div>

                                    {/* Logo */}
                                    <div className="space-y-2">
                                        <label className="text-sm font-medium text-muted-foreground">Business Logo</label>
                                        <div className="border-2 border-dashed border-border/50 rounded-lg p-4 bg-muted/20 hover:bg-muted/40 transition-colors">
                                            <div className="aspect-video bg-gradient-to-br from-gray-100 to-gray-200 dark:from-gray-800 dark:to-gray-900 rounded flex items-center justify-center">
                                                <p className="text-sm text-muted-foreground">Logo</p>
                                                {/* TODO: Replace with actual image when available */}
                                                {/* <img src={vendor.logo} alt="Logo" className="w-full h-full object-contain rounded" /> */}
                                            </div>
                                        </div>
                                        <p className="text-xs text-muted-foreground">Business logo for display</p>
                                    </div>
                                </div>
                            </div>

                            {/* Business Verification Details */}
                            <div>
                                <h3 className="font-semibold text-lg border-b pb-2 mb-4">Business Verification Details</h3>
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                                    <div className="space-y-4">
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Owner Full Name</label>
                                            <p className="mt-1 font-medium">{vendor.ownerName}</p>
                                        </div>
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Owner Contact Number</label>
                                            <p className="mt-1 font-medium">{vendor.phone}</p>
                                        </div>
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Business ID Number</label>
                                            <p className="mt-1 font-medium">BIZ-{vendor.id}-2024</p>
                                            <p className="text-xs text-muted-foreground mt-1">Unique business registration number</p>
                                        </div>
                                    </div>
                                    <div className="space-y-4">
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Business Type</label>
                                            <p className="mt-1 font-medium capitalize">{vendor.type}</p>
                                        </div>
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Service Category</label>
                                            <p className="mt-1 font-medium">
                                                {vendor.type === 'food' ? 'Food Delivery' :
                                                    vendor.type === 'grocery' ? 'Grocery Shopping' :
                                                        vendor.type === 'pharmacy' ? 'Pharmacy Services' : 'Market Place'}
                                            </p>
                                        </div>
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Registration Date</label>
                                            <p className="mt-1 font-medium">{format(new Date(vendor.createdAt), "PPP")}</p>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            {/* Operating Details */}
                            <div>
                                <h3 className="font-semibold text-lg border-b pb-2 mb-4">Operating Details</h3>
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                                    <div className="space-y-4">
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Opening Hours</label>
                                            <p className="mt-1 font-medium">9:00 AM - 10:00 PM (Daily)</p>
                                            <p className="text-xs text-muted-foreground mt-1">Standard operating hours</p>
                                        </div>
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Average Delivery Time</label>
                                            <p className="mt-1 font-medium">{vendor.preparationTime || 30} minutes</p>
                                        </div>
                                    </div>
                                    <div className="space-y-4">
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Payment Methods</label>
                                            <div className="mt-1 flex flex-wrap gap-2">
                                                <span className="px-3 py-1.5 bg-green-600 text-white rounded-full text-xs font-medium shadow-sm">Cash</span>
                                                <span className="px-3 py-1.5 bg-blue-600 text-white rounded-full text-xs font-medium shadow-sm">Mobile Money</span>
                                                <span className="px-3 py-1.5 bg-purple-600 text-white rounded-full text-xs font-medium shadow-sm">Card</span>
                                            </div>
                                        </div>
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Delivery Coverage</label>
                                            <p className="mt-1 font-medium">{vendor.deliveryRadius || 5} km radius</p>
                                            <p className="text-xs text-muted-foreground mt-1">From business location</p>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            {/* Location Details */}
                            <div>
                                <h3 className="font-semibold text-lg border-b pb-2 mb-4">Location Information</h3>
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                                    <div className="space-y-4">
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Full Address</label>
                                            <p className="mt-1 font-medium">{vendor.address}</p>
                                        </div>
                                        <div>
                                            <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Coordinates</label>
                                            <p className="mt-1 font-mono text-sm">Lat: 5.6037, Lng: -0.1870</p>
                                            <p className="text-xs text-muted-foreground mt-1">GPS coordinates for mapping</p>
                                        </div>
                                    </div>
                                    <div className="space-y-4">
                                        <div className="border-2 border-dashed border-border/50 rounded-lg p-4 bg-muted/20 h-48 flex items-center justify-center">
                                            <p className="text-sm text-muted-foreground">Map Preview</p>
                                            {/* TODO: Add Google Maps integration */}
                                        </div>
                                    </div>
                                </div>
                            </div>

                            {/* Verification Status */}
                            {vendor.status === "under_review" && (
                                <div
                                    className="rounded-md p-4 animate-fade-in"
                                    style={{
                                        backgroundColor: 'rgba(254, 248, 242, 0.5)',
                                        border: '1px solid rgba(254, 226, 200, 0.8)'
                                    }}
                                >
                                    <div className="flex items-start gap-3">
                                        <div className="flex-shrink-0">
                                            <Clock className="w-5 h-5 mt-0.5" style={{ color: '#FE6132' }} />
                                        </div>
                                        <div className="flex-1">
                                            <h3 className="text-sm font-semibold" style={{ color: '#c2410c' }}>
                                                Pending Verification
                                            </h3>
                                            <p className="mt-1 text-sm" style={{ color: '#ea580c' }}>
                                                Please review all documents and details above before approving or rejecting this vendor application.
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            )}
                        </div>
                    </TabsContent>

                    <TabsContent value="info" className="p-6 space-y-8 animate-fade-in">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                            <div className="space-y-4">
                                <h3 className="font-semibold text-lg border-b pb-2">Business Details</h3>
                                <div className="grid grid-cols-2 gap-4">
                                    <div>
                                        <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Owner</label>
                                        <p className="mt-1 font-medium">{vendor.ownerName}</p>
                                    </div>
                                    <div>
                                        <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Email</label>
                                        <p className="mt-1 font-medium">{vendor.email}</p>
                                    </div>
                                    <div>
                                        <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Phone</label>
                                        <p className="mt-1 font-medium">{vendor.phone}</p>
                                    </div>
                                    <div>
                                        <label className="text-xs text-muted-foreground font-medium uppercase tracking-wider">Joined</label>
                                        <p className="mt-1 font-medium">{format(new Date(vendor.createdAt), "PPP")}</p>
                                    </div>
                                </div>
                            </div>

                            <div className="space-y-4">
                                <h3 className="font-semibold text-lg border-b pb-2">Operational Hours</h3>
                                <div className="space-y-2">
                                    <div className="flex justify-between items-center text-sm">
                                        <span className="text-muted-foreground font-medium">Monday - Friday</span>
                                        <span className="font-semibold">08:00 AM - 10:00 PM</span>
                                    </div>
                                    <div className="flex justify-between items-center text-sm">
                                        <span className="text-muted-foreground font-medium">Saturday</span>
                                        <span className="font-semibold">09:00 AM - 11:00 PM</span>
                                    </div>
                                    <div className="flex justify-between items-center text-sm">
                                        <span className="text-muted-foreground font-medium">Sunday</span>
                                        <span className="font-semibold text-red-500">Closed</span>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div className="space-y-4">
                            <h3 className="font-semibold text-lg border-b pb-2">Location</h3>
                            <div className="aspect-[21/9] bg-muted rounded-md flex items-center justify-center text-muted-foreground border border-dashed">
                                Map View Placeholder for {vendor.address}
                            </div>
                        </div>
                    </TabsContent>

                    <TabsContent value="catalog" className="p-6 space-y-6 animate-fade-in">
                        <div className="flex items-center justify-between">
                            <div>
                                <h3 className="text-lg font-semibold">Inventory & Catalog</h3>
                                <p className="text-sm text-muted-foreground">Manage products, pricing, and availability</p>
                            </div>
                            <Button className="bg-[#FE6132] hover:bg-[#FE6132]/90 text-white">
                                <Plus className="w-4 h-4 mr-2" />
                                Add Item
                            </Button>
                        </div>

                        {catalog.length > 0 ? (
                            <div className="space-y-6">
                                {/* Popular Items Section */}
                                <div>
                                    <div className="flex items-center justify-between mb-4">
                                        <h3 className="font-semibold text-lg flex items-center gap-2">
                                            <FireFlame className="w-5 h-5 text-[#FE6132]" />
                                            Popular Items
                                        </h3>
                                        <Badge className="bg-[#FE6132]/10 text-[#FE6132] border-[#FE6132]/20">
                                            Top Sellers
                                        </Badge>
                                    </div>
                                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                                        {catalog.slice(0, 3).map((item, idx) => (
                                            <Card key={item.id} className="p-4 border-border/50 bg-gradient-to-br from-[#FE6132]/5 to-transparent hover:shadow-lg transition-all hover:-translate-y-1 group animate-fade-in-up" style={{ animationDelay: `${idx * 50}ms` }}>
                                                <div className="flex gap-4">
                                                    <div className="w-16 h-16 rounded-xl bg-muted flex items-center justify-center text-muted-foreground flex-shrink-0 group-hover:scale-105 transition-transform overflow-hidden relative">
                                                        {item.image ? (
                                                            <img src={item.image} alt={item.name} className="w-full h-full object-cover" />
                                                        ) : (
                                                            <Database className="w-6 h-6 opacity-40" />
                                                        )}
                                                        <div className="absolute top-0 right-0 bg-[#FE6132] text-white text-[10px] font-bold px-1.5 py-0.5 rounded-bl">
                                                            #{idx + 1}
                                                        </div>
                                                    </div>
                                                    <div className="flex-1 space-y-1">
                                                        <h4 className="font-bold text-sm group-hover:text-[#FE6132] transition-colors line-clamp-1">{item.name}</h4>
                                                        <p className="text-xs text-muted-foreground line-clamp-1">{item.description}</p>
                                                        <div className="flex items-center justify-between mt-2">
                                                            <span className="text-sm font-black text-[#FE6132]">GH₵ {item.price.toFixed(2)}</span>
                                                            <span className="text-xs text-muted-foreground">
                                                                {Math.floor(Math.random() * 100) + 50} sold
                                                            </span>
                                                        </div>
                                                    </div>
                                                </div>
                                            </Card>
                                        ))}
                                    </div>
                                </div>

                                {/* All Items Section */}
                                <div>
                                    <h3 className="font-semibold text-lg mb-4">All Items ({catalog.length})</h3>

                                    {/* Categories Quick Filter */}
                                    <div className="flex gap-2 overflow-x-auto pb-2">
                                        <Badge variant="outline" className="cursor-pointer bg-[#FE6132]/10 text-[#FE6132] border-[#FE6132]/20">All Items</Badge>
                                        {categories.map(cat => (
                                            <Badge key={cat} variant="outline" className="cursor-pointer hover:bg-muted transition-colors">{cat}</Badge>
                                        ))}
                                    </div>

                                    {/* Items Grid */}
                                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                                        {catalog.map((item, idx) => (
                                            <Card key={item.id} className="p-4 border-border/50 hover:shadow-lg transition-all hover:-translate-y-1 group animate-fade-in-up" style={{ animationDelay: `${idx * 50}ms` }}>
                                                <div className="flex gap-4">
                                                    <div className="w-20 h-20 rounded-xl bg-accent/30 flex items-center justify-center text-muted-foreground flex-shrink-0 group-hover:scale-105 transition-transform overflow-hidden">
                                                        {item.image ? (
                                                            <img src={item.image} alt={item.name} className="w-full h-full object-cover" />
                                                        ) : (
                                                            <Database className="w-8 h-8 opacity-40" />
                                                        )}
                                                    </div>
                                                    <div className="flex-1 space-y-1">
                                                        <div className="flex items-start justify-between">
                                                            <h4 className="font-bold text-sm group-hover:text-[#FE6132] transition-colors">{item.name}</h4>
                                                            <span className="text-sm font-black text-[#FE6132]">GH₵ {item.price.toFixed(2)}</span>
                                                        </div>
                                                        <p className="text-xs font-medium text-muted-foreground line-clamp-2">{item.description}</p>
                                                        <div className="flex items-center justify-between mt-3">
                                                            <Badge className="text-[10px] px-2 py-0.5 font-black uppercase tracking-widest bg-accent/50 text-foreground border-0">{item.category}</Badge>
                                                            <div className="flex items-center gap-1.5 font-bold">
                                                                <div className={`w-2 h-2 rounded-full ${item.inStock ? "bg-green-500" : "bg-red-500"} shadow-sm`} />
                                                                <span className="text-[10px] uppercase text-muted-foreground">{item.inStock ? "Ready" : "Sold Out"}</span>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </Card>
                                        ))}
                                    </div>
                                </div>
                            </div>
                        ) : (
                            <div className="py-12 text-center">
                                <Database className="w-12 h-12 text-muted-foreground opacity-20 mx-auto mb-4" />
                                <h3 className="text-lg font-semibold">No Items Found</h3>
                                <p className="text-muted-foreground max-w-sm mx-auto text-sm">
                                    This vendor doesn't have any items in their catalog yet.
                                </p>
                            </div>
                        )}
                    </TabsContent>

                    <TabsContent value="orders" className="p-6 space-y-6 animate-fade-in">
                        <div className="flex items-center justify-between">
                            <div>
                                <h3 className="text-lg font-semibold">Recent Vendor Orders</h3>
                                <p className="text-sm text-muted-foreground">Real-time order tracking for this vendor</p>
                            </div>
                            <Button variant="outline" size="sm" className="border-border/50">View All Orders</Button>
                        </div>

                        {recentOrders.length > 0 ? (
                            <div className="border border-border/50 rounded-lg overflow-hidden">
                                <table className="w-full text-sm text-left">
                                    <thead className="bg-muted/40 text-muted-foreground font-medium border-b border-border/50">
                                        <tr>
                                            <th className="px-4 py-3">Order ID</th>
                                            <th className="px-4 py-3">Date</th>
                                            <th className="px-4 py-3">Items</th>
                                            <th className="px-4 py-3">Total</th>
                                            <th className="px-4 py-3">Status</th>
                                            <th className="px-4 py-3 text-right">Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-border/50">
                                        {recentOrders.map((order) => (
                                            <tr key={order.id} className="hover:bg-muted/30 transition-colors">
                                                <td className="px-4 py-3 font-medium">{order.id}</td>
                                                <td className="px-4 py-3 text-muted-foreground">
                                                    {format(new Date(order.date), "MMM d, h:mm a")}
                                                </td>
                                                <td className="px-4 py-3">{order.items} Items</td>
                                                <td className="px-4 py-3 font-semibold">GH₵ {order.total.toFixed(2)}</td>
                                                <td className="px-4 py-3">
                                                    <Badge
                                                        variant={
                                                            order.status === "completed"
                                                                ? "success"
                                                                : order.status === "pending"
                                                                    ? "warning"
                                                                    : "destructive"
                                                        }
                                                        className="capitalize"
                                                    >
                                                        {order.status}
                                                    </Badge>
                                                </td>
                                                <td className="px-4 py-3 text-right">
                                                    <Button variant="ghost" size="sm">Details</Button>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        ) : (
                            <div className="py-12 text-center border border-dashed border-border/50 rounded-lg">
                                <Cart className="w-12 h-12 text-muted-foreground opacity-20 mx-auto mb-4" />
                                <h3 className="text-lg font-semibold">No Recent Orders</h3>
                                <p className="text-muted-foreground max-w-sm mx-auto text-sm">
                                    No orders have been placed with this vendor yet.
                                </p>
                            </div>
                        )}
                    </TabsContent>

                    <TabsContent value="settings" className="p-6 space-y-8 animate-fade-in">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                            <div className="space-y-4">
                                <h3 className="font-semibold text-lg border-b pb-2">Operational Settings</h3>
                                <div className="space-y-4">
                                    <div className="flex items-center justify-between">
                                        <div className="space-y-0.5">
                                            <label className="text-sm font-medium">Preparation Time</label>
                                            <p className="text-sm text-muted-foreground">Average time to prepare an order</p>
                                        </div>
                                        <div className="flex items-center gap-2">
                                            <span className="font-bold text-lg">{vendor.preparationTime || 0}</span>
                                            <span className="text-sm text-muted-foreground">mins</span>
                                        </div>
                                    </div>
                                    <div className="flex items-center justify-between">
                                        <div className="space-y-0.5">
                                            <label className="text-sm font-medium">Delivery Radius</label>
                                            <p className="text-sm text-muted-foreground">Maximum distance for delivery</p>
                                        </div>
                                        <div className="flex items-center gap-2">
                                            <span className="font-bold text-lg">{vendor.deliveryRadius || 0}</span>
                                            <span className="text-sm text-muted-foreground">km</span>
                                        </div>
                                    </div>
                                    <div className="flex items-center justify-between">
                                        <div className="space-y-0.5">
                                            <label className="text-sm font-medium">Minimum Order Value</label>
                                            <p className="text-sm text-muted-foreground">Minimum amount required for delivery</p>
                                        </div>
                                        <div className="flex items-center gap-2">
                                            <span className="text-sm text-muted-foreground">GH₵</span>
                                            <span className="font-bold text-lg">{vendor.minOrderValue?.toFixed(2) || "0.00"}</span>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div className="space-y-4">
                                <h3 className="font-semibold text-lg border-b pb-2">Platform Features</h3>
                                <div className="space-y-4">
                                    <div className="flex items-center justify-between p-3 border rounded-lg bg-muted/30">
                                        <div className="space-y-0.5">
                                            <label className="text-sm font-medium">Verified Status</label>
                                            <p className="text-xs text-muted-foreground">Display verification badge</p>
                                        </div>
                                        <Badge variant={vendor.isVerified ? "success" : "secondary"}>
                                            {vendor.isVerified ? "Verified" : "Unverified"}
                                        </Badge>
                                    </div>
                                    <div className="flex items-center justify-between p-3 border rounded-lg bg-muted/30">
                                        <div className="space-y-0.5">
                                            <label className="text-sm font-medium">Featured Vendor</label>
                                            <p className="text-xs text-muted-foreground">Show in featured sections</p>
                                        </div>
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            className="p-0 h-auto hover:bg-transparent"
                                            onClick={handleFeaturedToggle}
                                        >
                                            <Badge variant={vendor.isFeatured ? "warning" : "secondary"} className="cursor-pointer">
                                                {vendor.isFeatured ? "Featured" : "Regular"}
                                            </Badge>
                                        </Button>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div className="pt-4 flex justify-end">
                            <Button className="bg-[#FE6132] hover:bg-[#FE6132]/90 text-white">
                                <Edit className="w-4 h-4 mr-2" />
                                Edit Settings
                            </Button>
                        </div>
                    </TabsContent>
                </Tabs>
            </Card>
        </div>
    );
}
