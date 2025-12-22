"use client";

import { Line, LineChart as RechartsLineChart, ResponsiveContainer, Tooltip, XAxis, YAxis, CartesianGrid } from "recharts";

interface LineChartProps {
    data: any[];
    xKey: string;
    yKey: string;
    color?: string;
    height?: number;
}

export function LineChart({ data, xKey, yKey, color = "#FE6132", height = 300 }: LineChartProps) {
    return (
        <ResponsiveContainer width="100%" height={height}>
            <RechartsLineChart data={data} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                <XAxis
                    dataKey={xKey}
                    stroke="#6b7280"
                    fontSize={12}
                    tickLine={false}
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
                    labelStyle={{ color: "#374151", fontWeight: 600 }}
                />
                <Line
                    type="monotone"
                    dataKey={yKey}
                    stroke={color}
                    strokeWidth={2}
                    dot={{ fill: color, r: 4 }}
                    activeDot={{ r: 6 }}
                />
            </RechartsLineChart>
        </ResponsiveContainer>
    );
}
