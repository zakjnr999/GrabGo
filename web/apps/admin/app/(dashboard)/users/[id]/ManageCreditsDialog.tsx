"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@grabgo/ui";
import { Button, Input, Label } from "@grabgo/ui";
import { type Customer } from "../../../../lib/mockData";

const manageCreditsSchema = z.object({
    action: z.enum(["add", "deduct"]),
    amount: z.number().positive("Amount must be positive"),
    reason: z.string().min(5, "Please provide a reason (minimum 5 characters)"),
});

type ManageCreditsFormData = z.infer<typeof manageCreditsSchema>;

interface ManageCreditsDialogProps {
    customer: Customer;
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

export function ManageCreditsDialog({
    customer,
    open,
    onOpenChange,
}: ManageCreditsDialogProps) {
    const [isSubmitting, setIsSubmitting] = useState(false);

    const {
        register,
        handleSubmit,
        formState: { errors },
        watch,
        reset,
        setValue,
    } = useForm<ManageCreditsFormData>({
        resolver: zodResolver(manageCreditsSchema),
        defaultValues: {
            action: "add",
            amount: 0,
            reason: "",
        },
    });

    const action = watch("action");
    const amount = watch("amount") || 0;

    const newBalance =
        action === "add"
            ? customer.creditsBalance + amount
            : customer.creditsBalance - amount;

    const onSubmit = async (data: ManageCreditsFormData) => {
        setIsSubmitting(true);

        // Simulate API call
        await new Promise((resolve) => setTimeout(resolve, 1000));

        console.log("Credits updated:", data);

        setIsSubmitting(false);
        onOpenChange(false);
        reset();

        // TODO: Show success toast
        alert(
            `Successfully ${data.action === "add" ? "added" : "deducted"} GH₵${data.amount.toFixed(2)}`
        );
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-[500px]">
                <DialogHeader>
                    <DialogTitle>Manage Credits</DialogTitle>
                    <DialogDescription>
                        Add or deduct credits from customer's account.
                    </DialogDescription>
                </DialogHeader>

                <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
                    {/* Current Balance */}
                    <div className="bg-muted/50 rounded-md p-4">
                        <p className="text-sm text-muted-foreground">Current Balance</p>
                        <p className="text-2xl font-bold">
                            GH₵{customer.creditsBalance.toLocaleString("en-GH", {
                                minimumFractionDigits: 2,
                                maximumFractionDigits: 2,
                            })}
                        </p>
                    </div>

                    {/* Action Toggle */}
                    <div className="space-y-2">
                        <Label>Action</Label>
                        <div className="flex gap-2">
                            <Button
                                type="button"
                                variant={action === "add" ? "default" : "outline"}
                                className={
                                    action === "add"
                                        ? "flex-1 bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 text-white hover:opacity-90"
                                        : "flex-1 border-border/50"
                                }
                                onClick={() => setValue("action", "add")}
                            >
                                Add Credits
                            </Button>
                            <Button
                                type="button"
                                variant={action === "deduct" ? "destructive" : "outline"}
                                className="flex-1 border-border/50"
                                onClick={() => setValue("action", "deduct")}
                            >
                                Deduct Credits
                            </Button>
                        </div>
                        <input type="hidden" {...register("action")} />
                    </div>

                    {/* Amount */}
                    <div className="space-y-2">
                        <Label htmlFor="amount">Amount (GH₵)</Label>
                        <Input
                            id="amount"
                            type="number"
                            step="0.01"
                            {...register("amount", { valueAsNumber: true })}
                            placeholder="Enter amount"
                            className={errors.amount ? "border-destructive" : ""}
                        />
                        {errors.amount && (
                            <p className="text-sm text-destructive">{errors.amount.message}</p>
                        )}
                    </div>

                    {/* Reason */}
                    <div className="space-y-2">
                        <Label htmlFor="reason">Reason</Label>
                        <textarea
                            id="reason"
                            {...register("reason")}
                            placeholder="Enter reason for this transaction"
                            rows={3}
                            className={`flex w-full rounded-md border border-input bg-background px-3 py-2 text-sm placeholder:text-muted-foreground focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50 ${errors.reason ? "border-destructive" : ""
                                }`}
                        />
                        {errors.reason && (
                            <p className="text-sm text-destructive">{errors.reason.message}</p>
                        )}
                    </div>

                    {/* Preview */}
                    {amount > 0 && (
                        <div className="bg-blue-50 dark:bg-blue-950/20 border border-blue-200 dark:border-blue-900 rounded-md p-4">
                            <p className="text-sm font-medium text-blue-900 dark:text-blue-100">
                                Transaction Preview
                            </p>
                            <div className="mt-2 space-y-1 text-sm text-blue-800 dark:text-blue-200">
                                <p>
                                    Current Balance: GH₵{customer.creditsBalance.toFixed(2)}
                                </p>
                                <p>
                                    {action === "add" ? "Adding" : "Deducting"}: GH₵{amount.toFixed(2)}
                                </p>
                                <p className="font-semibold pt-1 border-t border-blue-200 dark:border-blue-800">
                                    New Balance: GH₵{newBalance.toFixed(2)}
                                </p>
                            </div>
                        </div>
                    )}

                    <DialogFooter>
                        <Button
                            type="button"
                            variant="outline"
                            onClick={() => {
                                onOpenChange(false);
                                reset();
                            }}
                            disabled={isSubmitting}
                        >
                            Cancel
                        </Button>
                        <Button
                            type="submit"
                            disabled={isSubmitting}
                            className="bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 text-white hover:opacity-90"
                        >
                            {isSubmitting ? "Processing..." : "Apply"}
                        </Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    );
}
