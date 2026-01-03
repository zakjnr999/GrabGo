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
import {
    Button,
    Input,
    Label,
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@grabgo/ui";
import { type Customer } from "../../../../lib/mockData";

const notificationSchema = z.object({
    title: z.string().min(3, "Title must be at least 3 characters"),
    message: z.string().min(10, "Message must be at least 10 characters"),
    priority: z.enum(["low", "medium", "high"]),
});

type NotificationFormData = z.infer<typeof notificationSchema>;

interface SendNotificationDialogProps {
    customer: Customer;
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

export function SendNotificationDialog({
    customer,
    open,
    onOpenChange,
}: SendNotificationDialogProps) {
    const [isSubmitting, setIsSubmitting] = useState(false);

    const {
        register,
        handleSubmit,
        formState: { errors },
        setValue,
        watch,
        reset,
    } = useForm<NotificationFormData>({
        resolver: zodResolver(notificationSchema),
        defaultValues: {
            title: "",
            message: "",
            priority: "medium",
        },
    });

    const priority = watch("priority");

    const onSubmit = async (data: NotificationFormData) => {
        setIsSubmitting(true);

        // Simulate API call
        await new Promise((resolve) => setTimeout(resolve, 1000));

        console.log("Notification sent:", data);

        setIsSubmitting(false);
        onOpenChange(false);
        reset();

        // TODO: Show success toast
        alert(`Notification sent to ${customer.username}`);
    };

    const getPriorityColor = (p: string) => {
        switch (p) {
            case "high":
                return "text-red-600 dark:text-red-400";
            case "medium":
                return "text-amber-600 dark:text-amber-400";
            case "low":
                return "text-blue-600 dark:text-blue-400";
            default:
                return "";
        }
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-[550px]">
                <DialogHeader>
                    <DialogTitle>Send Notification</DialogTitle>
                    <DialogDescription>
                        Send a targeted notification to {customer.username}.
                    </DialogDescription>
                </DialogHeader>

                <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
                    {/* Recipient Info */}
                    <div className="bg-muted/50 rounded-md p-3">
                        <p className="text-sm text-muted-foreground">Recipient</p>
                        <p className="font-medium">{customer.username}</p>
                        <p className="text-sm text-muted-foreground">{customer.email}</p>
                    </div>

                    {/* Title */}
                    <div className="space-y-2">
                        <Label htmlFor="title">Notification Title</Label>
                        <Input
                            id="title"
                            {...register("title")}
                            placeholder="Enter notification title"
                            className={errors.title ? "border-destructive" : ""}
                        />
                        {errors.title && (
                            <p className="text-sm text-destructive">{errors.title.message}</p>
                        )}
                    </div>

                    {/* Message */}
                    <div className="space-y-2">
                        <Label htmlFor="message">Message</Label>
                        <textarea
                            id="message"
                            {...register("message")}
                            placeholder="Enter your message"
                            rows={4}
                            className={`flex w-full rounded-md border border-input bg-background px-3 py-2 text-sm placeholder:text-muted-foreground focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50 ${errors.message ? "border-destructive" : ""
                                }`}
                        />
                        {errors.message && (
                            <p className="text-sm text-destructive">{errors.message.message}</p>
                        )}
                    </div>

                    {/* Priority */}
                    <div className="space-y-2">
                        <Label htmlFor="priority">Priority</Label>
                        <Select
                            value={priority}
                            onValueChange={(value) =>
                                setValue("priority", value as "low" | "medium" | "high")
                            }
                        >
                            <SelectTrigger className="border-border/50">
                                <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="low">
                                    <span className={getPriorityColor("low")}>● Low Priority</span>
                                </SelectItem>
                                <SelectItem value="medium">
                                    <span className={getPriorityColor("medium")}>
                                        ● Medium Priority
                                    </span>
                                </SelectItem>
                                <SelectItem value="high">
                                    <span className={getPriorityColor("high")}>● High Priority</span>
                                </SelectItem>
                            </SelectContent>
                        </Select>
                        <input type="hidden" {...register("priority")} />
                    </div>

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
                            {isSubmitting ? "Sending..." : "Send Notification"}
                        </Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    );
}
