// Order Export Utilities for GrabGo Admin Panel

import { Order } from "./mockOrderData";

/**
 * Export orders to CSV format
 */
export function exportOrdersToCSV(orders: Order[], filename: string = 'orders') {
    const headers = [
        'Order Number',
        'Date',
        'Customer Name',
        'Customer Phone',
        'Vendor Name',
        'Order Type',
        'Status',
        'Payment Status',
        'Payment Method',
        'Subtotal',
        'Delivery Fee',
        'Tax',
        'Discount',
        'Total',
        'Delivery Address',
        'Rider Name',
        'Notes'
    ];

    const rows = orders.map(order => [
        order.orderNumber,
        new Date(order.createdAt).toLocaleString(),
        order.customer.name,
        order.customer.phone,
        order.vendor.name,
        order.type,
        order.status.replace('_', ' '),
        order.paymentStatus,
        order.paymentMethod.replace('_', ' '),
        order.pricing.subtotal.toFixed(2),
        order.pricing.deliveryFee.toFixed(2),
        order.pricing.tax.toFixed(2),
        order.pricing.discount.toFixed(2),
        order.pricing.total.toFixed(2),
        order.delivery.address,
        order.rider?.name || 'Not assigned',
        order.notes || ''
    ]);

    const csvContent = [
        headers.join(','),
        ...rows.map(row => row.map(cell => `"${cell}"`).join(','))
    ].join('\n');

    downloadFile(csvContent, `${filename}-${getDateString()}.csv`, 'text/csv');
}

/**
 * Export single order to CSV
 */
export function exportOrderToCSV(order: Order) {
    exportOrdersToCSV([order], `order-${order.orderNumber}`);
}

/**
 * Export orders to Excel format (using XLSX library)
 */
export async function exportOrdersToExcel(orders: Order[], filename: string = 'orders') {
    // Dynamically import xlsx to reduce bundle size
    const XLSX = await import('xlsx');

    const data = orders.map(order => ({
        'Order Number': order.orderNumber,
        'Date': new Date(order.createdAt).toLocaleString(),
        'Customer Name': order.customer.name,
        'Customer Phone': order.customer.phone,
        'Customer Email': order.customer.email,
        'Vendor Name': order.vendor.name,
        'Vendor Type': order.type,
        'Order Status': order.status.replace('_', ' '),
        'Payment Status': order.paymentStatus,
        'Payment Method': order.paymentMethod.replace('_', ' '),
        'Subtotal (GH₵)': order.pricing.subtotal,
        'Delivery Fee (GH₵)': order.pricing.deliveryFee,
        'Tax (GH₵)': order.pricing.tax,
        'Discount (GH₵)': order.pricing.discount,
        'Total (GH₵)': order.pricing.total,
        'Delivery Address': order.delivery.address,
        'Delivery City': order.delivery.city,
        'Rider Name': order.rider?.name || 'Not assigned',
        'Rider Phone': order.rider?.phone || '',
        'Items Count': order.items.length,
        'Notes': order.notes || '',
        'Promo Code': order.promoCode || ''
    }));

    const worksheet = XLSX.utils.json_to_sheet(data);

    // Set column widths
    const columnWidths = [
        { wch: 15 }, // Order Number
        { wch: 20 }, // Date
        { wch: 20 }, // Customer Name
        { wch: 15 }, // Customer Phone
        { wch: 25 }, // Customer Email
        { wch: 25 }, // Vendor Name
        { wch: 12 }, // Vendor Type
        { wch: 15 }, // Order Status
        { wch: 15 }, // Payment Status
        { wch: 15 }, // Payment Method
        { wch: 12 }, // Subtotal
        { wch: 12 }, // Delivery Fee
        { wch: 10 }, // Tax
        { wch: 10 }, // Discount
        { wch: 12 }, // Total
        { wch: 30 }, // Delivery Address
        { wch: 15 }, // Delivery City
        { wch: 20 }, // Rider Name
        { wch: 15 }, // Rider Phone
        { wch: 12 }, // Items Count
        { wch: 30 }, // Notes
        { wch: 15 }  // Promo Code
    ];
    worksheet['!cols'] = columnWidths;

    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Orders');

    XLSX.writeFile(workbook, `${filename}-${getDateString()}.xlsx`);
}

/**
 * Export single order to Excel
 */
export async function exportOrderToExcel(order: Order) {
    await exportOrdersToExcel([order], `order-${order.orderNumber}`);
}

/**
 * Print order receipt
 */
export function printOrderReceipt(order: Order) {
    const printWindow = window.open('', '_blank');
    if (!printWindow) {
        alert('Please allow popups to print the receipt');
        return;
    }

    const receiptHTML = `
        <!DOCTYPE html>
        <html>
        <head>
            <title>Order Receipt - ${order.orderNumber}</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 20px;
                    color: #333;
                }
                .header {
                    text-align: center;
                    border-bottom: 2px solid #FE6132;
                    padding-bottom: 20px;
                    margin-bottom: 20px;
                }
                .header h1 {
                    color: #FE6132;
                    margin: 0;
                }
                .section {
                    margin-bottom: 20px;
                }
                .section-title {
                    font-weight: bold;
                    font-size: 16px;
                    margin-bottom: 10px;
                    color: #FE6132;
                }
                .info-row {
                    display: flex;
                    justify-content: space-between;
                    padding: 5px 0;
                }
                .info-label {
                    font-weight: bold;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 10px 0;
                }
                th, td {
                    padding: 10px;
                    text-align: left;
                    border-bottom: 1px solid #ddd;
                }
                th {
                    background-color: #f5f5f5;
                    font-weight: bold;
                }
                .total-row {
                    font-weight: bold;
                    font-size: 18px;
                    background-color: #f5f5f5;
                }
                .status-badge {
                    display: inline-block;
                    padding: 4px 12px;
                    border-radius: 12px;
                    font-size: 12px;
                    font-weight: bold;
                    text-transform: capitalize;
                }
                @media print {
                    body {
                        padding: 0;
                    }
                }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>GrabGo</h1>
                <p>Order Receipt</p>
            </div>

            <div class="section">
                <div class="info-row">
                    <span class="info-label">Order Number:</span>
                    <span>${order.orderNumber}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Date:</span>
                    <span>${new Date(order.createdAt).toLocaleString()}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Status:</span>
                    <span class="status-badge">${order.status.replace('_', ' ')}</span>
                </div>
            </div>

            <div class="section">
                <div class="section-title">Customer Information</div>
                <div class="info-row">
                    <span class="info-label">Name:</span>
                    <span>${order.customer.name}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Phone:</span>
                    <span>${order.customer.phone}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Email:</span>
                    <span>${order.customer.email}</span>
                </div>
            </div>

            <div class="section">
                <div class="section-title">Vendor Information</div>
                <div class="info-row">
                    <span class="info-label">Name:</span>
                    <span>${order.vendor.name}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Type:</span>
                    <span>${order.type.toUpperCase()}</span>
                </div>
            </div>

            <div class="section">
                <div class="section-title">Delivery Information</div>
                <div class="info-row">
                    <span class="info-label">Address:</span>
                    <span>${order.delivery.address}, ${order.delivery.city}</span>
                </div>
                ${order.delivery.instructions ? `
                <div class="info-row">
                    <span class="info-label">Instructions:</span>
                    <span>${order.delivery.instructions}</span>
                </div>
                ` : ''}
                ${order.rider ? `
                <div class="info-row">
                    <span class="info-label">Rider:</span>
                    <span>${order.rider.name} (${order.rider.phone})</span>
                </div>
                ` : ''}
            </div>

            <div class="section">
                <div class="section-title">Order Items</div>
                <table>
                    <thead>
                        <tr>
                            <th>Item</th>
                            <th>Quantity</th>
                            <th>Price</th>
                            <th>Total</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${order.items.map(item => `
                            <tr>
                                <td>${item.name}</td>
                                <td>${item.quantity}</td>
                                <td>GH₵ ${item.price.toFixed(2)}</td>
                                <td>GH₵ ${(item.price * item.quantity).toFixed(2)}</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            </div>

            <div class="section">
                <div class="section-title">Payment Summary</div>
                <div class="info-row">
                    <span>Subtotal:</span>
                    <span>GH₵ ${order.pricing.subtotal.toFixed(2)}</span>
                </div>
                <div class="info-row">
                    <span>Delivery Fee:</span>
                    <span>GH₵ ${order.pricing.deliveryFee.toFixed(2)}</span>
                </div>
                <div class="info-row">
                    <span>Tax:</span>
                    <span>GH₵ ${order.pricing.tax.toFixed(2)}</span>
                </div>
                ${order.pricing.discount > 0 ? `
                <div class="info-row" style="color: green;">
                    <span>Discount ${order.promoCode ? `(${order.promoCode})` : ''}:</span>
                    <span>- GH₵ ${order.pricing.discount.toFixed(2)}</span>
                </div>
                ` : ''}
                <div class="info-row total-row">
                    <span>Total:</span>
                    <span>GH₵ ${order.pricing.total.toFixed(2)}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Payment Method:</span>
                    <span>${order.paymentMethod.replace('_', ' ').toUpperCase()}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Payment Status:</span>
                    <span class="status-badge">${order.paymentStatus.toUpperCase()}</span>
                </div>
            </div>

            ${order.notes ? `
            <div class="section">
                <div class="section-title">Notes</div>
                <p>${order.notes}</p>
            </div>
            ` : ''}

            <div style="text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666;">
                <p>Thank you for using GrabGo!</p>
                <p style="font-size: 12px;">This is a computer-generated receipt.</p>
            </div>

            <script>
                window.onload = function() {
                    window.print();
                    window.onafterprint = function() {
                        window.close();
                    };
                };
            </script>
        </body>
        </html>
    `;

    printWindow.document.write(receiptHTML);
    printWindow.document.close();
}

/**
 * Helper function to download file
 */
function downloadFile(content: string, filename: string, mimeType: string) {
    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
}

/**
 * Helper function to get formatted date string
 */
function getDateString(): string {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}
