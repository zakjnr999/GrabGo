"use client";

import { Bar, BarChart as RechartsBarChart, ResponsiveContainer, Tooltip, XAxis, YAxis, CartesianGrid } from "recharts";

interface BarChartProps {
    data: any[];
    xKey: string;
    yKey: string;
    color?: string;
    height?: number;
}

export function BarChart({ data, xKey, yKey, color = "#FE6132", height = 300 }: BarChartProps) {
    return (
        <ResponsiveContainer width="100%" height={height}>
            <RechartsBarChart data={data} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" vertical={false} />
                <XAxis
                    dataKey={xKey}
                    stroke="#6b7280"
                    fontSize={12}
                    tickLine={false}
                    axisLine={false}
                />
                <YAxis
                    stroke="#6b7280"
                    fontSize={12}
                    tickLine={false}
                    axisLine={false}
                />
                <Tooltip
                    contentStyle={{
                        backgroundColor: "white",
                        border: "1px solid #e5e7eb",
                        borderRadius: "8px",
                        padding: "8px 12px",
                    }}
                    cursor={{ fill: 'rgba(254, 97, 50, 0.1)' }}
                />
                <Bar
                    dataKey={yKey}
                    fill={color}
                    radius={[4, 4, 0, 0]}
                />
            </RechartsBarChart>
        </ResponsiveContainer>
    );
}
