//
//  HTMLPDFExporter.swift
//  Scanninger
//
//  Created by Yeghishe Grigoryan on 13.01.26.
//

import Foundation
import WebKit

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
        
        // Create off-screen WKWebView with A4 dimensions (210mm x 297mm at 72 DPI = 595 x 842 points)
        // Using slightly larger frame to accommodate content
        let a4Width: CGFloat = 595  // 210mm at 72 DPI
        let a4Height: CGFloat = 842 // 297mm at 72 DPI
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: a4Width, height: a4Height), configuration: configuration)
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
        
        // Get content size for PDF configuration
        let contentSize = webView.scrollView.contentSize
        print("📄 [HTMLPDFExporter] WebView content size: \(contentSize)")
        
        // Ensure we have a valid content size
        let pdfRect: CGRect
        if contentSize.width > 0 && contentSize.height > 0 {
            pdfRect = CGRect(origin: .zero, size: contentSize)
        } else {
            // Fallback to webView frame size
            let frameSize = webView.frame.size
            pdfRect = CGRect(origin: .zero, size: frameSize)
            print("⚠️ [HTMLPDFExporter] Using fallback PDF rect from frame: \(pdfRect)")
        }
        
        // Create PDF configuration
        let pdfConfig = WKPDFConfiguration()
        // Set rect based on content size
        pdfConfig.rect = pdfRect
        if let configuredRect = pdfConfig.rect {
            print("📄 [HTMLPDFExporter] PDF configuration rect: \(configuredRect)")
        } else {
            print("📄 [HTMLPDFExporter] PDF configuration using default rect (nil)")
        }
        
        // Generate PDF on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            webView.createPDF(configuration: pdfConfig) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let pdfData):
                    print("✅ [HTMLPDFExporter] PDF data generated, size: \(pdfData.count) bytes")
                    self.writePDFToFile(data: pdfData)
                    
                case .failure(let error):
                    let detailedError = NSError(
                        domain: "HTMLPDFExporter",
                        code: 2,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to generate PDF: \(error.localizedDescription)",
                            NSUnderlyingErrorKey: error
                        ]
                    )
                    print("❌ [HTMLPDFExporter] PDF generation failed: \(error.localizedDescription)")
                    self.completion?(.failure(detailedError))
                }
            }
        }
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
