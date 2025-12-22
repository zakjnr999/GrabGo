"use client";

import { useState, useEffect, useRef } from "react";
import { User, Send, Cycling, Shop } from "iconoir-react";
import { Card } from "@grabgo/ui";

interface Message {
    id: string;
    sender: 'admin' | 'customer' | 'rider' | 'system';
    text: string;
    timestamp: string;
}

interface OrderChatViewProps {
    orderId: string;
    customerName: string;
    riderName?: string;
}

export function OrderChatView({ orderId, customerName, riderName }: OrderChatViewProps) {
    const [messages, setMessages] = useState<Message[]>([
        { id: '1', sender: 'system', text: 'Chat session started for Order ' + orderId, timestamp: new Date(Date.now() - 3600000).toISOString() },
        { id: '2', sender: 'customer', text: 'Hi, when will my order arrive?', timestamp: new Date(Date.now() - 3500000).toISOString() },
        { id: '3', sender: 'rider', text: 'I am currently at the restaurant. They are preparing your food.', timestamp: new Date(Date.now() - 3400000).toISOString() },
        { id: '4', sender: 'rider', text: 'Just picked it up! On my way.', timestamp: new Date(Date.now() - 2400000).toISOString() },
    ]);
    const [newMessage, setNewMessage] = useState("");
    const scrollRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (scrollRef.current) {
            scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
        }
    }, [messages]);

    const handleSendMessage = () => {
        if (!newMessage.trim()) return;

        const sentMessage: Message = {
            id: Date.now().toString(),
            sender: 'admin',
            text: newMessage,
            timestamp: new Date().toISOString()
        };

        setMessages(prev => [...prev, sentMessage]);
        setNewMessage("");

        // Simulate rider response after 2 seconds
        if (newMessage.toLowerCase().includes('location') || newMessage.toLowerCase().includes('where')) {
            setTimeout(() => {
                const response: Message = {
                    id: (Date.now() + 1).toString(),
                    sender: 'rider',
                    text: "I'm about 5 minutes away from the delivery location.",
                    timestamp: new Date().toISOString()
                };
                setMessages(prev => [...prev, response]);
            }, 2000);
        }
    };

    const getSenderInfo = (sender: Message['sender']) => {
        switch (sender) {
            case 'admin': return { label: 'Admin (You)', color: 'bg-[#FE6132] text-white', icon: <User className="w-3 h-3" /> };
            case 'customer': return { label: customerName, color: 'bg-blue-100 text-blue-700', icon: <User className="w-3 h-3" /> };
            case 'rider': return { label: riderName || 'Rider', color: 'bg-orange-100 text-orange-700', icon: <Cycling className="w-3 h-3" /> };
            case 'system': return { label: 'System', color: 'bg-gray-100 text-gray-500', icon: null };
        }
    };

    return (
        <Card className="flex flex-col h-[500px] border-border/50 overflow-hidden shadow-sm">
            {/* Chat Header */}
            <div className="p-4 border-b border-border bg-white flex items-center justify-between">
                <div>
                    <h3 className="font-bold flex items-center gap-2 text-foreground">
                        Order Communications
                        <span className="relative flex h-2.5 w-2.5">
                            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                            <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-green-500"></span>
                        </span>
                    </h3>
                    <p className="text-[10px] font-bold text-muted-foreground uppercase tracking-wider">Secure Admin-Customer-Rider Loop</p>
                </div>
            </div>

            {/* Messages Area */}
            <div
                ref={scrollRef}
                className="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50/30"
            >
                {messages.map((msg) => {
                    const info = getSenderInfo(msg.sender);
                    const isSystem = msg.sender === 'system';
                    const isAdmin = msg.sender === 'admin';

                    if (isSystem) {
                        return (
                            <div key={msg.id} className="text-center animate-in fade-in slide-in-from-bottom-2 duration-500">
                                <span className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground bg-white/50 backdrop-blur-sm px-4 py-1.5 rounded-full border border-border/50 shadow-sm">
                                    {msg.text}
                                </span>
                            </div>
                        );
                    }

                    return (
                        <div
                            key={msg.id}
                            className={`flex flex-col ${isAdmin ? 'items-end' : 'items-start'} animate-in fade-in zoom-in-95 duration-300`}
                        >
                            <div className="flex items-center gap-2 mb-1.5 px-1">
                                {isAdmin ? null : (
                                    <div className={`p-1.5 rounded-full shadow-sm ring-2 ring-white ${info.color}`}>
                                        {info.icon}
                                    </div>
                                )}
                                <span className="text-[11px] font-bold text-muted-foreground tracking-tight">{info.label}</span>
                                {isAdmin ? (
                                    <div className={`p-1.5 rounded-full shadow-sm ring-2 ring-white ${info.color}`}>
                                        {info.icon}
                                    </div>
                                ) : null}
                            </div>
                            <div className={`max-w-[85%] p-3.5 rounded-2xl text-sm font-medium shadow-sm leading-relaxed ${isAdmin
                                ? 'bg-[#FE6132] text-white rounded-tr-[4px] shadow-orange-100'
                                : 'bg-white border border-border/50 rounded-tl-[4px] text-gray-800'
                                }`}>
                                {msg.text}
                            </div>
                            <span className="text-[10px] font-bold text-muted-foreground/60 mt-1.5 px-1 uppercase tracking-tighter">
                                {new Date(msg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                            </span>
                        </div>
                    );
                })}
            </div>

            {/* Message Input */}
            <div className="p-4 border-t border-border bg-white">
                <div className="flex gap-2">
                    <input
                        type="text"
                        placeholder="Type a message..."
                        value={newMessage}
                        onChange={(e) => setNewMessage(e.target.value)}
                        onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
                        className="flex-1 px-4 py-2 rounded-full border border-border bg-gray-50 text-sm focus:outline-none focus:ring-2 focus:ring-[#FE6132]/20 transition-all"
                    />
                    <button
                        onClick={handleSendMessage}
                        disabled={!newMessage.trim()}
                        className="p-2 rounded-full bg-[#FE6132] text-white hover:bg-[#E5572D] disabled:opacity-50 disabled:cursor-not-allowed transition-colors shadow-md shadow-orange-200"
                    >
                        <Send className="w-5 h-5" />
                    </button>
                </div>
            </div>
        </Card>
    );
}
