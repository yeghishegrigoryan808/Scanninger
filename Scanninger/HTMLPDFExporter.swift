//
//  HTMLPDFExporter.swift
//  Scanninger
//
//  Created by Yeghishe Grigoryan on 13.01.26.
//

import Foundation
import UIKit
import WebKit
import PDFKit

// MARK: - HTML PDF Exporter
class HTMLPDFExporter: NSObject {
    
    // MARK: - Properties
    private var webView: WKWebView?
    private var completion: ((Result<URL, Error>) -> Void)?
    private let html: String
    private let fileName: String
    private let layoutSettleDelay: TimeInterval
    
    // MARK: - Initialization
    init(html: String, fileName: String, layoutSettleDelay: TimeInterval = 0.3) {
        self.html = html
        self.fileName = fileName
        self.layoutSettleDelay = layoutSettleDelay
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Exports HTML to PDF asynchronously
    func export() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            export { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Exports HTML to PDF with completion handler
    private func export(completion: @escaping (Result<URL, Error>) -> Void) {
        self.completion = completion
        
        print("📄 [HTMLPDFExporter] Starting PDF export for file: \(fileName)")
        print("📄 [HTMLPDFExporter] HTML content length: \(html.count) characters")
        
        // Use A4 width and a tall viewport so multiple HTML `.page` blocks can fully lay out.
        let a4Width: CGFloat = 595  // 210mm at 72 DPI
        let layoutHeight: CGFloat = 16000
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: a4Width, height: layoutHeight), configuration: configuration)
        webView.navigationDelegate = self
        webView.backgroundColor = .white
        
        // Strongly retain the webView
        self.webView = webView
        
        print("📄 [HTMLPDFExporter] Created WKWebView with frame: \(webView.frame)")
        
        // Load HTML with baseURL
        let baseURL = Bundle.main.bundleURL
        print("📄 [HTMLPDFExporter] Loading HTML with baseURL: \(baseURL.path)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            webView.loadHTMLString(self.html, baseURL: baseURL)
            print("📄 [HTMLPDFExporter] HTML load initiated")
        }
    }
    
    // MARK: - Private Methods
    
    private func generatePDF() {
        guard let webView = webView else {
            let error = NSError(
                domain: "HTMLPDFExporter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "WKWebView was deallocated before PDF generation"]
            )
            print("❌ [HTMLPDFExporter] WKWebView is nil, cannot generate PDF")
            completion?(.failure(error))
            return
        }
        
        print("📄 [HTMLPDFExporter] Starting PDF generation")
        let a4Rect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let formatter = webView.viewPrintFormatter()
        formatter.perPageContentInsets = .zero
        
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: a4Rect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: a4Rect), forKey: "printableRect")
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: Int.max))
        
        var pageCount = renderer.numberOfPages
        if pageCount <= 0 {
            let estimated = max(1, Int(ceil(webView.scrollView.contentSize.height / a4Rect.height)))
            pageCount = estimated
            print("⚠️ [HTMLPDFExporter] Renderer reported 0 pages, estimated \(estimated) pages")
        }
        print("📄 [HTMLPDFExporter] Rendering paged PDF with \(pageCount) page(s)")
        
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, a4Rect, nil)
        for index in 0..<pageCount {
            UIGraphicsBeginPDFPageWithInfo(a4Rect, nil)
            renderer.drawPage(at: index, in: a4Rect)
        }
        UIGraphicsEndPDFContext()
        
        let pdfData = data as Data
        print("✅ [HTMLPDFExporter] Paged PDF data generated, size: \(pdfData.count) bytes")
        writePDFToFile(data: pdfData)
    }
    
    private func writePDFToFile(data: Data) {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        print("📄 [HTMLPDFExporter] Writing PDF to: \(fileURL.path)")
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("📄 [HTMLPDFExporter] Removed existing file")
            }
            
            // Write PDF data
            try data.write(to: fileURL, options: .atomic)
            print("✅ [HTMLPDFExporter] PDF written successfully")
            
            // Verify file
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                let error = NSError(
                    domain: "HTMLPDFExporter",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "PDF file was not created at expected path"]
                )
                print("❌ [HTMLPDFExporter] File verification failed: file does not exist")
                completion?(.failure(error))
                return
            }
            
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            
            guard fileSize > 0 else {
                let error = NSError(
                    domain: "HTMLPDFExporter",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "PDF file is empty (0 bytes)"]
                )
                print("❌ [HTMLPDFExporter] File verification failed: file is empty")
                completion?(.failure(error))
                return
            }
            
            print("✅ [HTMLPDFExporter] PDF export completed successfully")
            print("📄 [HTMLPDFExporter] File size: \(fileSize) bytes")
            print("📄 [HTMLPDFExporter] File URL: \(fileURL)")
            completion?(.success(fileURL))
            
        } catch {
            let detailedError = NSError(
                domain: "HTMLPDFExporter",
                code: 5,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to write PDF file: \(error.localizedDescription)",
                    NSUnderlyingErrorKey: error
                ]
            )
            print("❌ [HTMLPDFExporter] File write failed: \(error.localizedDescription)")
            completion?(.failure(detailedError))
        }
    }
}

// MARK: - WKNavigationDelegate
extension HTMLPDFExporter: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ [HTMLPDFExporter] WebView navigation finished")
        
        // Get content size after navigation finishes
        let contentSize = webView.scrollView.contentSize
        print("📄 [HTMLPDFExporter] Content size after navigation: \(contentSize)")
        
        // Wait for layout to settle before generating PDF
        print("📄 [HTMLPDFExporter] Waiting \(layoutSettleDelay)s for layout to settle...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + layoutSettleDelay) { [weak self] in
            guard let self = self else { return }
            print("📄 [HTMLPDFExporter] Layout settle delay completed, generating PDF")
            self.generatePDF()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ [HTMLPDFExporter] WebView navigation failed: \(error.localizedDescription)")
        let detailedError = NSError(
            domain: "HTMLPDFExporter",
            code: 6,
            userInfo: [
                NSLocalizedDescriptionKey: "WebView navigation failed: \(error.localizedDescription)",
                NSUnderlyingErrorKey: error
            ]
        )
        completion?(.failure(detailedError))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ [HTMLPDFExporter] WebView provisional navigation failed: \(error.localizedDescription)")
        let detailedError = NSError(
            domain: "HTMLPDFExporter",
            code: 7,
            userInfo: [
                NSLocalizedDescriptionKey: "WebView provisional navigation failed: \(error.localizedDescription)",
                NSUnderlyingErrorKey: error
            ]
        )
        completion?(.failure(detailedError))
    }
}

// MARK: - Export Debug Helper
func exportDebugTwoPageHTMLPDF() async throws -> (url: URL, pageCount: Int) {
    let debugHTML = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <style>
        @page { size: A4 portrait; margin: 0; }
        html, body { margin: 0; padding: 0; }
        .page {
          width: 210mm;
          min-height: 297mm;
          box-sizing: border-box;
          padding: 20mm;
          break-after: page;
          page-break-after: always;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
        }
        .page:last-child {
          break-after: auto;
          page-break-after: auto;
        }
        h1 { margin: 0; font-size: 42px; }
      </style>
    </head>
    <body>
      <div class="page"><h1>PAGE 1</h1></div>
      <div class="page"><h1>PAGE 2</h1></div>
    </body>
    </html>
    """
    
    let exporter = HTMLPDFExporter(html: debugHTML, fileName: "PaginationDebug_2pages.pdf")
    let url = try await exporter.export()
    guard let document = PDFDocument(url: url) else {
        throw NSError(domain: "HTMLPDFExporter", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to open debug PDF"])
    }
    let count = document.pageCount
    print("📄 [HTMLPDFExporter] Debug two-page PDF pageCount: \(count)")
    return (url, count)
}
