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
    static func renderInvoice(_ invoice: InvoiceModel, theme: InvoiceColorTheme? = nil, template: PDFTemplate = .professional) throws -> String {
        if template == .paginationTest {
            return PaginationTestInvoiceEngine.render(invoice: invoice, theme: theme ?? .ocean)
        }

        // Get template file name from PDFTemplate
        let templateFileName = template.templateFileName
        
        // Load template from bundle - try multiple paths
        var templateContent: String?
        var lastError: Error?
        
        // Try 1: With subdirectory using path
        if let templatePath = Bundle.main.path(forResource: templateFileName, ofType: "html", inDirectory: "Templates") {
            do {
                templateContent = try String(contentsOfFile: templatePath, encoding: .utf8)
                print("✅ HTML template loaded from path: \(templatePath)")
            } catch {
                lastError = error
                print("❌ Failed to load template from path: \(error.localizedDescription)")
            }
        }
        
        // Try 2: With subdirectory using URL
        if templateContent == nil, let templateURL = Bundle.main.url(forResource: templateFileName, withExtension: "html", subdirectory: "Templates") {
            do {
                templateContent = try String(contentsOf: templateURL, encoding: .utf8)
                print("✅ HTML template loaded from URL: \(templateURL.path)")
            } catch {
                lastError = error
                print("❌ Failed to load template from URL: \(error.localizedDescription)")
            }
        }
        
        // Try 3: In root directory
        if templateContent == nil, let templateURL = Bundle.main.url(forResource: templateFileName, withExtension: "html") {
            do {
                templateContent = try String(contentsOf: templateURL, encoding: .utf8)
                print("✅ HTML template loaded from root: \(templateURL.path)")
            } catch {
                lastError = error
                print("❌ Failed to load template from root: \(error.localizedDescription)")
            }
        }
        
        // If template not found, return error HTML
        guard let htmlTemplate = templateContent else {
            print("❌ Template not found in bundle. Bundle paths: \(Bundle.main.bundlePath)")
            throw HTMLRenderError.templateNotFound
        }
        
        print("✅ Template loaded successfully, length: \(htmlTemplate.count) characters")
        
        // Build items rows HTML (template-specific format)
        let itemsRows = buildItemsRows(invoice: invoice, template: template)
        
        // Format dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let invoiceDate = dateFormatter.string(from: invoice.issueDate)
        
        // Format invoice period block (only if both dates exist)
        // Support template-specific period blocks.
        let invoicePeriodBlock: String
        if let periodStart = invoice.periodStart, let periodEnd = invoice.periodEnd {
            let shortFormatter = DateFormatter()
            shortFormatter.dateFormat = "MMM d, yyyy"
            let periodText = "\(shortFormatter.string(from: periodStart)) – \(shortFormatter.string(from: periodEnd))"
            let modernFormat = "<div><b>Invoice Period</b> \(escapeHTML(periodText))</div>"
            let elegantFormat = "<div class=\"meta-row\"><div class=\"meta-label\">Period</div><div class=\"meta-value\">\(escapeHTML(periodText))</div></div>"
            let classicFormat = "<div style=\"margin:0 0 8mm 0;font-size:13px;font-weight:600;color:#111111;\">Period: \(escapeHTML(periodText))</div>"
            switch template {
            case .professional, .paginationTest:
                invoicePeriodBlock = modernFormat
            case .elegant:
                invoicePeriodBlock = elegantFormat
            case .classic:
                invoicePeriodBlock = classicFormat
            }
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
        
        // Always render from invoice snapshots to preserve historical integrity.
        let currentBusinessName = invoice.businessName
        let currentBusinessAddress = invoice.businessAddress
        let currentBusinessEmail = invoice.businessEmail
        let currentBusinessPhone = invoice.businessPhone
        
        let currentClientName = invoice.clientName
        let currentClientAddress = invoice.clientAddress
        let currentClientEmail = invoice.clientEmail
        let currentClientPhone = invoice.clientPhone
        
        // Build conditional blocks for optional fields
        let fromAddressBlock = currentBusinessAddress.isEmpty ? "" : "<div>\(escapeHTML(currentBusinessAddress))</div>"
        let fromEmailBlock = currentBusinessEmail.isEmpty ? "" : "<div>\(escapeHTML(currentBusinessEmail))</div>"
        let fromPhoneBlock = currentBusinessPhone.isEmpty ? "" : "<div>\(escapeHTML(currentBusinessPhone))</div>"
        
        let billToAddressBlock = currentClientAddress.isEmpty ? "" : "<div>\(escapeHTML(currentClientAddress))</div>"
        let billToEmailBlock = currentClientEmail.isEmpty ? "" : "<div>\(escapeHTML(currentClientEmail))</div>"
        let billToPhoneBlock = currentClientPhone.isEmpty ? "" : "<div>\(escapeHTML(currentClientPhone))</div>"
        
        // Replace placeholders
        var html = htmlTemplate
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
        
        // Apply theme colors (default to ocean if not provided)
        let theme = theme ?? .ocean
        html = html.replacingOccurrences(of: "{{accentColor}}", with: theme.accentColor)
        html = html.replacingOccurrences(of: "{{accentSoftColor}}", with: theme.accentSoftColor)
        html = html.replacingOccurrences(of: "{{titleColor}}", with: theme.titleColor)
        html = html.replacingOccurrences(of: "{{borderColor}}", with: theme.borderColor)
        
        html = html.replacingOccurrences(of: "{{itemsRows}}", with: itemsRows)
        
        // Build block-style placeholders for elegant template
        let fromAddressBlockCombined = currentBusinessAddress.isEmpty ? "" : "<div>\(escapeHTML(currentBusinessAddress))</div>"
        let billToAddressBlockCombined = currentClientAddress.isEmpty ? "" : "<div>\(escapeHTML(currentClientAddress))</div>"
        
        // Tax block (only if tax > 0)
        let taxBlock: String
        if taxAmount > 0 {
            switch template {
            case .classic:
                taxBlock = "<tr><td class=\"label\">Tax</td><td class=\"value\">\(escapeHTML(formattedTax))</td></tr>"
            case .professional, .elegant, .paginationTest:
                taxBlock = "<div class=\"total-row\"><div class=\"label\">Tax</div><div class=\"value\">\(escapeHTML(formattedTax))</div></div>"
            }
        } else {
            taxBlock = ""
        }
        
        // Discount block (only if discount > 0)
        let discountBlock: String
        if discount > 0 {
            switch template {
            case .classic:
                discountBlock = "<tr><td class=\"label\">Discount</td><td class=\"value\">\(escapeHTML(formattedDiscount))</td></tr>"
            case .professional, .elegant, .paginationTest:
                discountBlock = "<div class=\"total-row\"><div class=\"label\">Discount</div><div class=\"value\">\(escapeHTML(formattedDiscount))</div></div>"
            }
        } else {
            discountBlock = ""
        }
        
        // Payment info block (empty - no payment info field)
        let paymentInfoBlock = ""
        
        let additionalNotesSection = buildAdditionalNotesSection(invoice: invoice)
        
        // Replace block-style placeholders (for elegant template)
        html = html.replacingOccurrences(of: "{{fromAddressBlock}}", with: fromAddressBlockCombined)
        html = html.replacingOccurrences(of: "{{billToAddressBlock}}", with: billToAddressBlockCombined)
        html = html.replacingOccurrences(of: "{{paymentInfoBlock}}", with: paymentInfoBlock)
        html = html.replacingOccurrences(of: "{{notesBlock}}", with: "")
        html = html.replacingOccurrences(of: "{{additionalNotesSection}}", with: additionalNotesSection)
        html = html.replacingOccurrences(of: "{{taxBlock}}", with: taxBlock)
        html = html.replacingOccurrences(of: "{{discountBlock}}", with: discountBlock)
        
        // Replace individual placeholders (for modern template - backward compatibility)
        html = html.replacingOccurrences(of: "{{subtotal}}", with: escapeHTML(formattedSubtotal))
        html = html.replacingOccurrences(of: "{{tax}}", with: escapeHTML(formattedTax))
        html = html.replacingOccurrences(of: "{{discount}}", with: escapeHTML(formattedDiscount))
        html = html.replacingOccurrences(of: "{{total}}", with: escapeHTML(formattedTotal))
        
        html = html.replacingOccurrences(of: "{{notes}}", with: "")
        
        // Verify all placeholders were replaced
        if html.contains("{{") {
            let remainingPlaceholders = html.components(separatedBy: "{{").dropFirst().map { $0.components(separatedBy: "}}").first ?? "" }
            print("⚠️ Warning: Unreplaced placeholders found: \(remainingPlaceholders.joined(separator: ", "))")
        }
        
        print("✅ HTML rendered successfully, final length: \(html.count) characters")
        return html
    }
    
    /// Renders optional additional notes after totals; empty string when `additionalNotes` is blank.
    private static func buildAdditionalNotesSection(invoice: InvoiceModel) -> String {
        let trimmed = invoice.additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let escaped = escapeHTML(trimmed)
        return """
        <div class="notes-section">
            <div class="notes-title">Additional Notes</div>
            <div class="notes-text">\(escaped)</div>
        </div>
        """
    }
    
    /// Builds the HTML rows for invoice items (template-specific format)
    private static func buildItemsRows(invoice: InvoiceModel, template: PDFTemplate) -> String {
        guard let items = invoice.items, !items.isEmpty else {
            // Return empty row based on template format
            switch template {
            case .professional, .paginationTest:
                return """
                <div class="item-row">
                    <div class="item-title">No items</div>
                    <div class="right">—</div>
                    <div class="right">—</div>
                    <div class="right">—</div>
                </div>
                """
            case .elegant:
                return """
                <tr>
                    <td>No items</td>
                    <td class="num">—</td>
                    <td class="num">—</td>
                    <td class="num">—</td>
                </tr>
                """
            case .classic:
                return """
                <tr>
                    <td>
                        <div class="item-title">No items</div>
                    </td>
                    <td class="num">—</td>
                    <td class="num">—</td>
                    <td class="num">—</td>
                </tr>
                <tr class="empty-space-row">
                    <td></td>
                    <td></td>
                    <td></td>
                    <td></td>
                </tr>
                """
            }
        }
        
        let currencyCode = invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode
        
        switch template {
        case .professional, .paginationTest:
            // Professional template uses div-based grid layout
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
            
        case .elegant:
            // Elegant template uses proper HTML table rows
            return items.map { item in
                let title = escapeHTML(item.title)
                let description = item.details.isEmpty ? "" : escapeHTML(item.details)
                let rate = formatCurrency(item.price, currencyCode: currencyCode)
                let qty = "\(item.qty) \(escapeHTML(item.unit))"
                let amount = formatCurrency(item.total, currencyCode: currencyCode)
                
                var titleCell = "<div class=\"item-title\">\(title)</div>"
                if !description.isEmpty {
                    titleCell += "<div class=\"item-desc\">\(description)</div>"
                }
                
                return """
                <tr>
                    <td>\(titleCell)</td>
                    <td class="num">\(rate)</td>
                    <td class="num">\(qty)</td>
                    <td class="num">\(amount)</td>
                </tr>
                """
            }.joined(separator: "\n")
        case .classic:
            // Classic template uses proper HTML table rows
            return items.map { item in
                let title = escapeHTML(item.title)
                let description = item.details.isEmpty ? "" : escapeHTML(item.details)
                let rate = formatCurrency(item.price, currencyCode: currencyCode)
                let qty = "\(item.qty) \(escapeHTML(item.unit))"
                let amount = formatCurrency(item.total, currencyCode: currencyCode)
                
                var titleCell = "<div class=\"item-title\">\(title)</div>"
                if !description.isEmpty {
                    titleCell += "<div class=\"item-desc\">\(description)</div>"
                }
                
                return """
                <tr>
                    <td>\(titleCell)</td>
                    <td class="num">\(rate)</td>
                    <td class="num">\(qty)</td>
                    <td class="num">\(amount)</td>
                </tr>
                """
            }.joined(separator: "\n")
        }
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
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.isUserInteractionEnabled = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let normalizedHTML = buildA4PreviewHTML(from: html)
        if context.coordinator.lastLoadedHTML != normalizedHTML {
            context.coordinator.lastLoadedHTML = normalizedHTML
            webView.loadHTMLString(normalizedHTML, baseURL: Bundle.main.bundleURL)
        } else {
            context.coordinator.applyFitScale(on: webView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func buildA4PreviewHTML(from content: String) -> String {
        var sanitizedContent = content.replacingOccurrences(
            of: #"<meta[^>]*name=["']viewport["'][^>]*>"#,
            with: "",
            options: .regularExpression
        )
        
        let standardViewport = #"<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">"#
        let previewResetStyle = """
        <style>
        html, body {
            margin: 0;
            padding: 0;
            width: 100%;
            height: 100%;
            overflow: hidden;
            background: #ffffff;
        }
        </style>
        """
        
        if sanitizedContent.range(of: "</head>", options: .caseInsensitive) != nil {
            sanitizedContent = sanitizedContent.replacingOccurrences(
                of: "</head>",
                with: "\(standardViewport)\n\(previewResetStyle)\n</head>",
                options: .caseInsensitive
            )
        } else {
            sanitizedContent = "\(standardViewport)\n\(previewResetStyle)\n\(sanitizedContent)"
        }
        
        return sanitizedContent
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedHTML: String?
        
        private let fitScript = """
        (function() {
            const root =
                document.querySelector('.page') ||
                document.querySelector('.invoice') ||
                document.body.firstElementChild ||
                document.body;
            if (!root) { return; }
        
            root.style.transform = 'none';
            root.style.transformOrigin = 'top left';
        
            document.documentElement.style.overflow = 'hidden';
            document.body.style.overflow = 'hidden';
        
            const viewportWidth = window.innerWidth || document.documentElement.clientWidth || 1;
            const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 1;
            const rect = root.getBoundingClientRect();
            if (!rect.width || !rect.height) { return; }
        
            const scale = Math.min(viewportWidth / rect.width, viewportHeight / rect.height);
            const safeScale = (Number.isFinite(scale) && scale > 0) ? scale : 1;
            const x = (viewportWidth - (rect.width * safeScale)) / 2;
            const y = (viewportHeight - (rect.height * safeScale)) / 2;
        
            root.style.transform = `translate(${x}px, ${y}px) scale(${safeScale})`;
            root.style.transformOrigin = 'top left';
        })();
        """
        
        func applyFitScale(on webView: WKWebView) {
            webView.evaluateJavaScript(fitScript, completionHandler: nil)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applyFitScale(on: webView)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.applyFitScale(on: webView)
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("HTML preview load failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("HTML preview provisional load failed: \(error.localizedDescription)")
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
