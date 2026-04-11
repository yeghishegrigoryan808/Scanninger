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

    /// Renders invoice HTML using the built-in paginated engines (no bundle templates).
    static func renderInvoice(_ invoice: InvoiceModel, theme: InvoiceColorTheme? = nil, template: PDFTemplate = .professional) -> String {
        let t = theme ?? .ocean
        switch template {
        case .professional:
            return PaginationTestInvoiceEngine.render(invoice: invoice, theme: t)
        case .elegant:
            return ElegantPaginatedInvoiceEngine.render(invoice: invoice, theme: t)
        case .classic:
            return ClassicPaginatedInvoiceEngine.render(invoice: invoice, theme: t)
        }
    }
}

// MARK: - HTML Render Error (legacy fallback UI)
enum HTMLRenderError: LocalizedError {
    case templateNotFound

    var errorDescription: String? {
        switch self {
        case .templateNotFound:
            return "Invoice HTML could not be rendered."
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
        <h1>⚠️ Rendering Error</h1>
        <p><strong>Error:</strong> \(error.localizedDescription ?? "Unknown error")</p>
        </div>
        </body>
        </html>
        """
    }
}

// MARK: - PDF Export from HTML
func generatePDFFromHTML(_ html: String, invoiceNumber: String) async throws -> URL {
    let fileName = "Invoice_\(invoiceNumber.replacingOccurrences(of: " ", with: "_")).pdf"

    // Use HTMLPDFExporter service for robust PDF generation
    let exporter = HTMLPDFExporter(html: html, fileName: fileName)
    return try await exporter.export()
}
