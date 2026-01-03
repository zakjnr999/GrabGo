import * as XLSX from 'xlsx';

/**
 * Export Utilities for Analytics Reports
 * Supports CSV and Excel export for all report types
 */

// ==================== CSV Export ====================

/**
 * Convert array of objects to CSV string
 */
function convertToCSV(data: any[], headers: string[]): string {
    const headerRow = headers.join(',');
    const rows = data.map(row =>
        headers.map(header => {
            const value = row[header];
            // Handle values with commas or quotes
            if (typeof value === 'string' && (value.includes(',') || value.includes('"'))) {
                return `"${value.replace(/"/g, '""')}"`;
            }
            return value ?? '';
        }).join(',')
    );
    return [headerRow, ...rows].join('\n');
}

/**
 * Download CSV file
 */
function downloadCSV(filename: string, csvContent: string) {
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);

    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

/**
 * Export User Growth Report to CSV
 */
export function exportUserGrowthCSV(data: any[]) {
    const headers = ['date', 'newUsers', 'totalUsers'];
    const csvContent = convertToCSV(data, headers);
    const filename = `user-growth-report-${new Date().toISOString().split('T')[0]}.csv`;
    downloadCSV(filename, csvContent);
}

/**
 * Export Revenue Report to CSV
 */
export function exportRevenueCSV(data: any[]) {
    const headers = ['date', 'revenue', 'orders'];
    const csvContent = convertToCSV(data, headers);
    const filename = `revenue-report-${new Date().toISOString().split('T')[0]}.csv`;
    downloadCSV(filename, csvContent);
}

/**
 * Export Vendor Performance to CSV
 */
export function exportVendorPerformanceCSV(data: any[]) {
    const headers = ['name', 'type', 'revenue', 'orders', 'rating'];
    const csvContent = convertToCSV(data, headers);
    const filename = `vendor-performance-${new Date().toISOString().split('T')[0]}.csv`;
    downloadCSV(filename, csvContent);
}

/**
 * Export Rider Performance to CSV
 */
export function exportRiderPerformanceCSV(data: any[]) {
    const headers = ['name', 'deliveries', 'earnings', 'rating', 'acceptanceRate'];
    const csvContent = convertToCSV(data, headers);
    const filename = `rider-performance-${new Date().toISOString().split('T')[0]}.csv`;
    downloadCSV(filename, csvContent);
}

/**
 * Export Order Volume to CSV
 */
export function exportOrderVolumeCSV(data: any[]) {
    const headers = ['date', 'food', 'grocery', 'pharmacy', 'market'];
    const csvContent = convertToCSV(data, headers);
    const filename = `order-volume-${new Date().toISOString().split('T')[0]}.csv`;
    downloadCSV(filename, csvContent);
}

/**
 * Export Payment Analytics to CSV
 */
export function exportPaymentAnalyticsCSV(data: any[]) {
    const headers = ['method', 'amount', 'count'];
    const csvContent = convertToCSV(data, headers);
    const filename = `payment-analytics-${new Date().toISOString().split('T')[0]}.csv`;
    downloadCSV(filename, csvContent);
}

/**
 * Export Customer Insights to CSV
 */
export function exportCustomerInsightsCSV(data: any[]) {
    const headers = ['metric', 'value', 'change'];
    const csvContent = convertToCSV(data, headers);
    const filename = `customer-insights-${new Date().toISOString().split('T')[0]}.csv`;
    downloadCSV(filename, csvContent);
}

/**
 * Export Operational Metrics to CSV
 */
export function exportOperationalMetricsCSV(data: any[]) {
    const headers = ['metric', 'value', 'target', 'status'];
    const csvContent = convertToCSV(data, headers);
    const filename = `operational-metrics-${new Date().toISOString().split('T')[0]}.csv`;
    downloadCSV(filename, csvContent);
}

// ==================== Excel Export ====================

/**
 * Create styled Excel workbook
 */
function createStyledWorkbook(sheetName: string, data: any[], headers: string[]): XLSX.WorkBook {
    const wb = XLSX.utils.book_new();

    // Create worksheet from data
    const ws = XLSX.utils.json_to_sheet(data, { header: headers });

    // Set column widths
    const colWidths = headers.map(header => ({ wch: Math.max(header.length, 15) }));
    ws['!cols'] = colWidths;

    // Add worksheet to workbook
    XLSX.utils.book_append_sheet(wb, ws, sheetName);

    return wb;
}

/**
 * Download Excel file
 */
function downloadExcel(filename: string, workbook: XLSX.WorkBook) {
    XLSX.writeFile(workbook, filename);
}

/**
 * Export User Growth Report to Excel
 */
export function exportUserGrowthExcel(data: any[]) {
    const headers = ['date', 'newUsers', 'totalUsers'];
    const wb = createStyledWorkbook('User Growth', data, headers);
    const filename = `user-growth-report-${new Date().toISOString().split('T')[0]}.xlsx`;
    downloadExcel(filename, wb);
}

/**
 * Export Revenue Report to Excel
 */
export function exportRevenueExcel(data: any[]) {
    const headers = ['date', 'revenue', 'orders'];
    const wb = createStyledWorkbook('Revenue', data, headers);
    const filename = `revenue-report-${new Date().toISOString().split('T')[0]}.xlsx`;
    downloadExcel(filename, wb);
}

/**
 * Export Vendor Performance to Excel
 */
export function exportVendorPerformanceExcel(data: any[]) {
    const headers = ['name', 'type', 'revenue', 'orders', 'rating'];
    const wb = createStyledWorkbook('Vendor Performance', data, headers);
    const filename = `vendor-performance-${new Date().toISOString().split('T')[0]}.xlsx`;
    downloadExcel(filename, wb);
}

/**
 * Export Rider Performance to Excel
 */
export function exportRiderPerformanceExcel(data: any[]) {
    const headers = ['name', 'deliveries', 'earnings', 'rating', 'acceptanceRate'];
    const wb = createStyledWorkbook('Rider Performance', data, headers);
    const filename = `rider-performance-${new Date().toISOString().split('T')[0]}.xlsx`;
    downloadExcel(filename, wb);
}

/**
 * Export Order Volume to Excel
 */
export function exportOrderVolumeExcel(data: any[]) {
    const headers = ['date', 'food', 'grocery', 'pharmacy', 'market'];
    const wb = createStyledWorkbook('Order Volume', data, headers);
    const filename = `order-volume-${new Date().toISOString().split('T')[0]}.xlsx`;
    downloadExcel(filename, wb);
}

/**
 * Export Payment Analytics to Excel
 */
export function exportPaymentAnalyticsExcel(data: any[]) {
    const headers = ['method', 'amount', 'count'];
    const wb = createStyledWorkbook('Payment Analytics', data, headers);
    const filename = `payment-analytics-${new Date().toISOString().split('T')[0]}.xlsx`;
    downloadExcel(filename, wb);
}

/**
 * Export Customer Insights to Excel
 */
export function exportCustomerInsightsExcel(data: any[]) {
    const headers = ['metric', 'value', 'change'];
    const wb = createStyledWorkbook('Customer Insights', data, headers);
    const filename = `customer-insights-${new Date().toISOString().split('T')[0]}.xlsx`;
    downloadExcel(filename, wb);
}

/**
 * Export Operational Metrics to Excel
 */
export function exportOperationalMetricsExcel(data: any[]) {
    const headers = ['metric', 'value', 'target', 'status'];
    const wb = createStyledWorkbook('Operational Metrics', data, headers);
    const filename = `operational-metrics-${new Date().toISOString().split('T')[0]}.xlsx`;
    downloadExcel(filename, wb);
}

/**
 * Export All Reports to Excel (Multi-sheet)
 */
export function exportAllReportsExcel(reports: {
    userGrowth?: any[];
    revenue?: any[];
    vendors?: any[];
    riders?: any[];
    orderVolume?: any[];
    payments?: any[];
    customers?: any[];
    operations?: any[];
}) {
    const wb = XLSX.utils.book_new();

    // Add each report as a separate sheet
    if (reports.userGrowth) {
        const ws = XLSX.utils.json_to_sheet(reports.userGrowth);
        XLSX.utils.book_append_sheet(wb, ws, 'User Growth');
    }

    if (reports.revenue) {
        const ws = XLSX.utils.json_to_sheet(reports.revenue);
        XLSX.utils.book_append_sheet(wb, ws, 'Revenue');
    }

    if (reports.vendors) {
        const ws = XLSX.utils.json_to_sheet(reports.vendors);
        XLSX.utils.book_append_sheet(wb, ws, 'Vendors');
    }

    if (reports.riders) {
        const ws = XLSX.utils.json_to_sheet(reports.riders);
        XLSX.utils.book_append_sheet(wb, ws, 'Riders');
    }

    if (reports.orderVolume) {
        const ws = XLSX.utils.json_to_sheet(reports.orderVolume);
        XLSX.utils.book_append_sheet(wb, ws, 'Order Volume');
    }

    if (reports.payments) {
        const ws = XLSX.utils.json_to_sheet(reports.payments);
        XLSX.utils.book_append_sheet(wb, ws, 'Payments');
    }

    if (reports.customers) {
        const ws = XLSX.utils.json_to_sheet(reports.customers);
        XLSX.utils.book_append_sheet(wb, ws, 'Customers');
    }

    if (reports.operations) {
        const ws = XLSX.utils.json_to_sheet(reports.operations);
        XLSX.utils.book_append_sheet(wb, ws, 'Operations');
    }

    const filename = `grabgo-analytics-${new Date().toISOString().split('T')[0]}.xlsx`;
    downloadExcel(filename, wb);
}
