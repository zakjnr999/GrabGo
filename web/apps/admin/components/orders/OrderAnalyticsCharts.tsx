"use client";

import { useMemo } from "react";
import { Order } from "../../lib/mockOrderData";
import { Card } from "@grabgo/ui";
import { Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis, CartesianGrid, Bar, BarChart, Legend } from "recharts";

interface OrderAnalyticsChartsProps {
    orders: Order[];
}

export function OrderAnalyticsCharts({ orders }: OrderAnalyticsChartsProps) {
    const chartData = useMemo(() => {
        const last7Days = Array.from({ length: 7 }, (_, i) => {
            const d = new Date();
            d.setDate(d.getDate() - (6 - i));
            return d.toISOString().split('T')[0];
        });

        return last7Days.map(date => {
            const dayOrders = orders.filter(o => o.createdAt.startsWith(date));
            const revenue = dayOrders.reduce((sum, o) => sum + o.pricing.total, 0);
            const d = new Date(date);
            const label = d.toLocaleDateString('en-US', { weekday: 'short', day: 'numeric' });

            return {
                name: label,
                orders: dayOrders.length,
                revenue: Math.round(revenue)
            };
        });
    }, [orders]);

    const typeData = useMemo(() => {
        const types = ['food', 'grocery', 'pharmacy', 'market'];
        return types.map(type => ({
            name: type.charAt(0).toUpperCase() + type.slice(1),
            value: orders.filter(o => o.type === type).length
        }));
    }, [orders]);

    return (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
            <Card className="p-6 border-border/50">
                <div className="flex items-center justify-between mb-6">
                    <div>
                        <h3 className="text-lg font-semibold">Order Trends</h3>
                        <p className="text-sm text-muted-foreground">Volume and revenue for the last 7 days</p>
                    </div>
                </div>
                <div className="h-[300px] w-full">
                    <ResponsiveContainer width="100%" height="100%">
                        <LineChart data={chartData} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
                            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" opacity={0.6} />
                            <XAxis dataKey="name" fontSize={12} tickLine={false} axisLine={false} stroke="hsl(var(--muted-foreground))" />
                            <YAxis yAxisId="left" fontSize={12} tickLine={false} axisLine={false} stroke="hsl(var(--muted-foreground))" />
                            <YAxis yAxisId="right" orientation="right" fontSize={12} tickLine={false} axisLine={false} stroke="hsl(var(--muted-foreground))" />
                            <Tooltip
                                contentStyle={{
                                    backgroundColor: 'hsl(var(--card))',
                                    borderRadius: '8px',
                                    border: '1px solid hsl(var(--border))',
                                    boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)',
                                    color: 'hsl(var(--foreground))'
                                }}
                                itemStyle={{ color: 'hsl(var(--foreground))' }}
                                labelStyle={{ color: 'hsl(var(--muted-foreground))' }}
                            />
                            <Legend verticalAlign="top" height={36} />
                            <Line yAxisId="left" type="monotone" dataKey="orders" name="Orders" stroke="#FE6132" strokeWidth={2} dot={{ r: 4, fill: '#FE6132' }} activeDot={{ r: 6 }} />
                            <Line yAxisId="right" type="monotone" dataKey="revenue" name="Revenue (GH₵)" stroke="#10B981" strokeWidth={2} dot={{ r: 4, fill: '#10B981' }} activeDot={{ r: 6 }} />
                        </LineChart>
                    </ResponsiveContainer>
                </div>
            </Card>

            <Card className="p-6 border-border/50">
                <div className="flex items-center justify-between mb-6">
                    <div>
                        <h3 className="text-lg font-semibold">Orders by Type</h3>
                        <p className="text-sm text-muted-foreground">Distribution across services</p>
                    </div>
                </div>
                <div className="h-[300px] w-full">
                    <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={typeData}>
                            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" opacity={0.6} />
                            <XAxis dataKey="name" fontSize={12} tickLine={false} axisLine={false} stroke="hsl(var(--muted-foreground))" />
                            <YAxis fontSize={12} tickLine={false} axisLine={false} stroke="hsl(var(--muted-foreground))" />
                            <Tooltip
                                cursor={{ fill: 'hsl(var(--muted))', opacity: 0.1 }}
                                contentStyle={{
                                    backgroundColor: 'hsl(var(--card))',
                                    borderRadius: '8px',
                                    border: '1px solid hsl(var(--border))',
                                    boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)',
                                    color: 'hsl(var(--foreground))'
                                }}
                                itemStyle={{ color: 'hsl(var(--foreground))' }}
                                labelStyle={{ color: 'hsl(var(--muted-foreground))' }}
                            />
                            <Bar dataKey="value" name="Total Orders" fill="#FE6132" radius={[4, 4, 0, 0]} />
                        </BarChart>
                    </ResponsiveContainer>
                </div>
            </Card>
        </div>
    );
}
