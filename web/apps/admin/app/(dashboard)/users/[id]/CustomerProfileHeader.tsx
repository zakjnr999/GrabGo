"use client";

import { useState } from "react";
import { Button, Badge } from "@grabgo/ui";
import { Edit, Key, Wallet, Bell, CheckCircleSolid } from "iconoir-react";
import { type Customer } from "../../../../lib/mockData";
import { EditCustomerDialog } from "./EditCustomerDialog";
import { ResetPasswordDialog } from "./ResetPasswordDialog";
import { ManageCreditsDialog } from "./ManageCreditsDialog";
import { SendNotificationDialog } from "./SendNotificationDialog";
import { ToggleAccountStatusDialog } from "./ToggleAccountStatusDialog";

interface CustomerProfileHeaderProps {
    customer: Customer;
}

export function CustomerProfileHeader({ customer }: CustomerProfileHeaderProps) {
    const [editDialogOpen, setEditDialogOpen] = useState(false);
    const [resetPasswordDialogOpen, setResetPasswordDialogOpen] = useState(false);
    const [manageCreditsDialogOpen, setManageCreditsDialogOpen] = useState(false);
    const [sendNotificationDialogOpen, setSendNotificationDialogOpen] = useState(false);
    const [toggleStatusDialogOpen, setToggleStatusDialogOpen] = useState(false);

    return (
        <>
            <div className="flex flex-col md:flex-row md:items-start gap-6">
                {/* Avatar and Basic Info */}
                <div className="flex items-start gap-6 flex-1">
                    {/* Avatar */}
                    <div className="w-20 h-20 md:w-24 md:h-24 rounded-md bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 flex items-center justify-center text-white text-3xl font-bold flex-shrink-0">
                        {customer.username.charAt(0).toUpperCase()}
                    </div>

                    {/* Info */}
                    <div className="space-y-3">
                        <div>
                            <h1 className="text-xl md:text-2xl font-bold">{customer.username}</h1>
                            <p className="text-sm text-muted-foreground">ID: {customer.id}</p>
                        </div>

                        <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
                            {/* Email */}
                            <div className="flex items-center gap-2">
                                <span className="text-sm">{customer.email}</span>
                                {customer.emailVerified && (
                                    <CheckCircleSolid className="w-4 h-4 text-green-500" />
                                )}
                            </div>

                            {/* Phone */}
                            <div className="flex items-center gap-2">
                                <span className="text-sm text-muted-foreground">{customer.phone}</span>
                                {customer.phoneVerified && (
                                    <CheckCircleSolid className="w-4 h-4 text-green-500" />
                                )}
                            </div>

                            {/* Status */}
                            <Badge variant={customer.isActive ? "success" : "destructive"}>
                                {customer.isActive ? "Active" : "Inactive"}
                            </Badge>
                        </div>
                    </div>
                </div>

                {/* Actions */}
                <div className="grid grid-cols-2 lg:flex lg:flex-wrap gap-2 w-full md:w-auto">
                    <Button
                        variant="outline"
                        size="sm"
                        className="gap-2 border-border/50 h-10 md:h-9 w-full lg:w-auto"
                        onClick={() => setEditDialogOpen(true)}
                    >
                        <Edit className="w-4 h-4" />
                        Edit
                    </Button>
                    <Button
                        variant="outline"
                        size="sm"
                        className="gap-2 border-border/50 h-10 md:h-9 w-full lg:w-auto"
                        onClick={() => setResetPasswordDialogOpen(true)}
                    >
                        <Key className="w-4 h-4" />
                        Reset Password
                    </Button>
                    <Button
                        variant="outline"
                        size="sm"
                        className="gap-2 border-border/50 h-10 md:h-9 w-full lg:w-auto"
                        onClick={() => setManageCreditsDialogOpen(true)}
                    >
                        <Wallet className="w-4 h-4" />
                        Manage Credits
                    </Button>
                    <Button
                        variant="outline"
                        size="sm"
                        className="gap-2 border-border/50 h-10 md:h-9 w-full lg:w-auto"
                        onClick={() => setSendNotificationDialogOpen(true)}
                    >
                        <Bell className="w-4 h-4" />
                        Send Notification
                    </Button>
                    <Button
                        size="sm"
                        className={`gap-2 h-10 md:h-9 w-full lg:w-auto ${customer.isActive
                                ? 'bg-red-600 hover:bg-red-700 text-white'
                                : 'bg-green-600 hover:bg-green-700 text-white'
                            }`}
                        onClick={() => setToggleStatusDialogOpen(true)}
                    >
                        {customer.isActive ? 'Deactivate Account' : 'Activate Account'}
                    </Button>
                </div>
            </div>

            {/* All Dialogs */}
            <EditCustomerDialog
                customer={customer}
                open={editDialogOpen}
                onOpenChange={setEditDialogOpen}
            />
            <ResetPasswordDialog
                customer={customer}
                open={resetPasswordDialogOpen}
                onOpenChange={setResetPasswordDialogOpen}
            />
            <ManageCreditsDialog
                customer={customer}
                open={manageCreditsDialogOpen}
                onOpenChange={setManageCreditsDialogOpen}
            />
            <SendNotificationDialog
                customer={customer}
                open={sendNotificationDialogOpen}
                onOpenChange={setSendNotificationDialogOpen}
            />
            <ToggleAccountStatusDialog
                customer={customer}
                open={toggleStatusDialogOpen}
                onOpenChange={setToggleStatusDialogOpen}
            />
        </>
    );
}
