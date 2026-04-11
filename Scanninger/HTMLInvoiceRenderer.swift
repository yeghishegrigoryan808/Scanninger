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
