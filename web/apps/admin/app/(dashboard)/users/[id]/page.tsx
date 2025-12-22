import { notFound } from "next/navigation";
import Link from "next/link";
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

interface PageProps {
    params: Promise<{
        id: string;
    }>;
}

export default async function CustomerDetailPage({ params }: PageProps) {
    const { id } = await params;
    const customer = getCustomerById(id);
    const orders = getCustomerOrders(id);
    const payments = getCustomerPayments(id);

    if (!customer) {
        notFound();
    }

    return (
        <div className="p-6 space-y-6">
            {/* Back Button */}
            <Link href="/users">
                <Button variant="ghost" className="gap-2 -ml-2">
                    <ArrowLeft className="w-4 h-4" />
                    Back to Customers
                </Button>
            </Link>

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
                            <p className="text-2xl font-black text-foreground">{customer.totalOrders.toLocaleString()}</p>
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
                                GH₵{customer.totalSpending.toLocaleString("en-GH", {
                                    maximumFractionDigits: 0,
                                })}
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
                                GH₵{customer.creditsBalance.toLocaleString("en-GH", {
                                    maximumFractionDigits: 0,
                                })}
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
                            <p className="text-2xl font-black text-foreground">{customer.referralCount}</p>
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
                </Tabs>
            </Card>
        </div>
    );
}
