//
//  HTMLInvoiceRenderer.swift
//  Scanninger
//
//  Created by Yeghishe Grigoryan on 13.01.26.
//

import Foundation
import WebKit
import SwiftUI

// MARK: - HTML Invoice Renderer
struct HTMLInvoiceRenderer {
    
    /// Renders an invoice using the HTML template
    static func renderInvoice(_ invoice: InvoiceModel) throws -> String {
        // Load template from bundle - try multiple paths
        var template: String?
        var lastError: Error?
        
        // Try 1: With subdirectory using path
        if let templatePath = Bundle.main.path(forResource: "invoice_template_modern", ofType: "html", inDirectory: "Templates") {
            do {
                template = try String(contentsOfFile: templatePath, encoding: .utf8)
                print("✅ HTML template loaded from path: \(templatePath)")
            } catch {
                lastError = error
                print("❌ Failed to load template from path: \(error.localizedDescription)")
            }
        }
        
        // Try 2: With subdirectory using URL
        if template == nil, let templateURL = Bundle.main.url(forResource: "invoice_template_modern", withExtension: "html", subdirectory: "Templates") {
            do {
                template = try String(contentsOf: templateURL, encoding: .utf8)
                print("✅ HTML template loaded from URL: \(templateURL.path)")
            } catch {
                lastError = error
                print("❌ Failed to load template from URL: \(error.localizedDescription)")
            }
        }
        
        // Try 3: In root directory
        if template == nil, let templateURL = Bundle.main.url(forResource: "invoice_template_modern", withExtension: "html") {
            do {
                template = try String(contentsOf: templateURL, encoding: .utf8)
                print("✅ HTML template loaded from root: \(templateURL.path)")
            } catch {
                lastError = error
                print("❌ Failed to load template from root: \(error.localizedDescription)")
            }
        }
        
        // If template not found, return error HTML
        guard let template = template else {
            print("❌ Template not found in bundle. Bundle paths: \(Bundle.main.bundlePath)")
            throw HTMLRenderError.templateNotFound
        }
        
        print("✅ Template loaded successfully, length: \(template.count) characters")
        
        // Build items rows HTML
        let itemsRows = buildItemsRows(invoice: invoice)
        
        // Format dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let invoiceDate = dateFormatter.string(from: invoice.issueDate)
        
        // Format invoice period block (only if both dates exist)
        let invoicePeriodBlock: String
        if let periodStart = invoice.periodStart, let periodEnd = invoice.periodEnd {
            let shortFormatter = DateFormatter()
            shortFormatter.dateFormat = "MMM d, yyyy"
            let periodText = "\(shortFormatter.string(from: periodStart)) – \(shortFormatter.string(from: periodEnd))"
            invoicePeriodBlock = "<div><b>Invoice Period</b> \(escapeHTML(periodText))</div>"
        } else {
            invoicePeriodBlock = ""
        }
        
        // Calculate amounts
        let subtotal = invoice.subtotal
        let taxAmount = subtotal * (invoice.taxPercent / 100.0)
        let discount: Double = 0.0 // No discount field in current model
        let total = invoice.total
        
        // Format currency amounts
        let currencyCode = invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode
        let formattedSubtotal = formatCurrency(subtotal, currencyCode: currencyCode)
        let formattedTax = formatCurrency(taxAmount, currencyCode: currencyCode)
        let formattedDiscount = formatCurrency(discount, currencyCode: currencyCode)
        let formattedTotal = formatCurrency(total, currencyCode: currencyCode)
        
        // Get current business profile data (prefer current profile over snapshot)
        let currentBusinessName = invoice.businessProfile?.name ?? invoice.businessName
        let currentBusinessAddress = invoice.businessProfile?.address ?? invoice.businessAddress
        let currentBusinessEmail = invoice.businessProfile?.email ?? invoice.businessEmail
        let currentBusinessPhone = invoice.businessProfile?.phone ?? invoice.businessPhone
        
        // Get current client profile data (prefer current profile over snapshot)
        let currentClientName = invoice.clientRef?.name ?? invoice.clientName
        let currentClientAddress = invoice.clientRef?.address ?? invoice.clientAddress
        let currentClientEmail = invoice.clientRef?.email ?? invoice.clientEmail
        let currentClientPhone = invoice.clientRef?.phone ?? invoice.clientPhone
        
        // Build conditional blocks for optional fields
        let fromAddressBlock = currentBusinessAddress.isEmpty ? "" : "<div>\(escapeHTML(currentBusinessAddress))</div>"
        let fromEmailBlock = currentBusinessEmail.isEmpty ? "" : "<div>\(escapeHTML(currentBusinessEmail))</div>"
        let fromPhoneBlock = currentBusinessPhone.isEmpty ? "" : "<div>\(escapeHTML(currentBusinessPhone))</div>"
        
        let billToAddressBlock = currentClientAddress.isEmpty ? "" : "<div>\(escapeHTML(currentClientAddress))</div>"
        let billToEmailBlock = currentClientEmail.isEmpty ? "" : "<div>\(escapeHTML(currentClientEmail))</div>"
        let billToPhoneBlock = currentClientPhone.isEmpty ? "" : "<div>\(escapeHTML(currentClientPhone))</div>"
        
        // Replace placeholders
        var html = template
        html = html.replacingOccurrences(of: "{{fromName}}", with: escapeHTML(currentBusinessName))
        html = html.replacingOccurrences(of: "{{fromAddress}}", with: fromAddressBlock)
        html = html.replacingOccurrences(of: "{{fromEmail}}", with: fromEmailBlock)
        html = html.replacingOccurrences(of: "{{fromPhone}}", with: fromPhoneBlock)
        
        html = html.replacingOccurrences(of: "{{billToName}}", with: escapeHTML(currentClientName))
        html = html.replacingOccurrences(of: "{{billToAddress}}", with: billToAddressBlock)
        html = html.replacingOccurrences(of: "{{billToEmail}}", with: billToEmailBlock)
        html = html.replacingOccurrences(of: "{{billToPhone}}", with: billToPhoneBlock)
        
        html = html.replacingOccurrences(of: "{{invoiceNumber}}", with: escapeHTML(invoice.number))
        html = html.replacingOccurrences(of: "{{invoiceDate}}", with: escapeHTML(invoiceDate))
        html = html.replacingOccurrences(of: "{{invoicePeriodBlock}}", with: invoicePeriodBlock)
        
        html = html.replacingOccurrences(of: "{{itemsRows}}", with: itemsRows)
        
        html = html.replacingOccurrences(of: "{{subtotal}}", with: escapeHTML(formattedSubtotal))
        html = html.replacingOccurrences(of: "{{tax}}", with: escapeHTML(formattedTax))
        html = html.replacingOccurrences(of: "{{discount}}", with: escapeHTML(formattedDiscount))
        html = html.replacingOccurrences(of: "{{total}}", with: escapeHTML(formattedTotal))
        
        // Notes (empty if not available)
        let notes = "" // No notes field in current model
        html = html.replacingOccurrences(of: "{{notes}}", with: escapeHTML(notes))
        
        // Verify all placeholders were replaced
        if html.contains("{{") {
            let remainingPlaceholders = html.components(separatedBy: "{{").dropFirst().map { $0.components(separatedBy: "}}").first ?? "" }
            print("⚠️ Warning: Unreplaced placeholders found: \(remainingPlaceholders.joined(separator: ", "))")
        }
        
        print("✅ HTML rendered successfully, final length: \(html.count) characters")
        return html
    }
    
    /// Builds the HTML rows for invoice items
    private static func buildItemsRows(invoice: InvoiceModel) -> String {
        guard let items = invoice.items, !items.isEmpty else {
            return """
            <div class="item-row">
                <div class="item-title">No items</div>
                <div class="right">—</div>
                <div class="right">—</div>
                <div class="right">—</div>
            </div>
            """
        }
        
        let currencyCode = invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode
        
        return items.map { item in
            let description = escapeHTML(item.title)
            let details = item.details.isEmpty ? "" : "<br><small style=\"color:#888;\">\(escapeHTML(item.details))</small>"
            let rate = formatCurrency(item.price, currencyCode: currencyCode)
            let qty = "\(item.qty) \(escapeHTML(item.unit))"
            let amount = formatCurrency(item.total, currencyCode: currencyCode)
            
            return """
            <div class="item-row">
                <div class="item-title">\(description)\(details)</div>
                <div class="right">\(rate)</div>
                <div class="right">\(qty)</div>
                <div class="right">\(amount)</div>
            </div>
            """
        }.joined(separator: "\n")
    }
    
    /// Escapes HTML special characters
    private static func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    /// Formats currency amount
    private static func formatCurrency(_ amount: Double, currencyCode: String) -> String {
        let code = currencyCode.isEmpty ? "USD" : currencyCode
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}

// MARK: - HTML Render Error
enum HTMLRenderError: LocalizedError {
    case templateNotFound
    
    var errorDescription: String? {
        switch self {
        case .templateNotFound:
            return "Invoice template file not found in bundle. Please ensure invoice_template_modern.html is included in the app target."
        }
    }
    
    /// Returns a fallback HTML with error message
    static func fallbackHTML(error: HTMLRenderError) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <title>Invoice Template Error</title>
        <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial;
            background: #f4f6f8;
            padding: 40px;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .error-box {
            max-width: 600px;
            background: white;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.08);
        }
        h1 { color: #d32f2f; margin-top: 0; }
        p { color: #666; line-height: 1.6; }
        </style>
        </head>
        <body>
        <div class="error-box">
        <h1>⚠️ Template Loading Error</h1>
        <p><strong>Error:</strong> \(error.localizedDescription ?? "Unknown error")</p>
        <p>The invoice template file (invoice_template_modern.html) could not be found in the app bundle.</p>
        <p><strong>Please check:</strong></p>
        <ul>
        <li>The file exists in the Templates folder</li>
        <li>The file is included in the app target membership</li>
        <li>The file is copied to the app bundle during build</li>
        </ul>
        </div>
        </body>
        </html>
        """
    }
}

// MARK: - HTML Invoice Preview View
struct HTMLInvoicePreviewView: UIViewRepresentable {
    let html: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .systemBackground
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Use Bundle.main.bundleURL as baseURL to ensure resources load correctly
        let baseURL = Bundle.main.bundleURL
        print("📄 Loading HTML into WKWebView, length: \(html.count) characters, baseURL: \(baseURL)")
        
        if html.isEmpty {
            print("❌ HTML content is empty!")
            let errorHTML = """
            <!DOCTYPE html>
            <html>
            <head><meta charset="UTF-8"><title>Error</title></head>
            <body style="font-family: -apple-system; padding: 40px;">
                <h1 style="color: red;">Error: HTML content is empty</h1>
                <p>The invoice template could not be loaded or rendered.</p>
            </body>
            </html>
            """
            webView.loadHTMLString(errorHTML, baseURL: baseURL)
        } else {
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WKWebView finished loading HTML")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WKWebView failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WKWebView failed provisional navigation: \(error.localizedDescription)")
        }
    }
}

// MARK: - PDF Export from HTML
func generatePDFFromHTML(_ html: String, invoiceNumber: String) async throws -> URL {
    let fileName = "Invoice_\(invoiceNumber.replacingOccurrences(of: " ", with: "_")).pdf"
    
    // Use HTMLPDFExporter service for robust PDF generation
    let exporter = HTMLPDFExporter(html: html, fileName: fileName)
    return try await exporter.export()
}
