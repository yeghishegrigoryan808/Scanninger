import Foundation

// MARK: - Pagination Test Models

struct PaginationTestRenderPage {
    let pageIndex: Int
    let isFirstPage: Bool
    let isLastPage: Bool
    let showHeader: Bool
    let showParties: Bool
    let itemRows: [LineItemModel]
    let showTotals: Bool
    let showNotes: Bool
}

struct PaginationTestResult {
    let pages: [PaginationTestRenderPage]
}

// MARK: - Page Metrics

private enum PageMetrics {
    static let pageHeightMm: Double = 297.0
    static let pageTopPaddingMm: Double = 20.0
    static let pageBottomPaddingMm: Double = 20.0

    // Safety margin: prevents content from touching the CSS page boundary.
    // Keeps a buffer so rounding/rendering variance never causes the .page div
    // to overflow past 297mm (which would make UIPrintPageRenderer split it).
    static let safetyMm: Double = 3.0

    static var usableHeight: Double {
        pageHeightMm - pageTopPaddingMm - pageBottomPaddingMm - safetyMm // 254.0
    }

    // CSS px → mm.
    // WKWebView renders CSS width:210mm as 793.7 CSS-px in a 595pt viewport.
    // viewPrintFormatter() scales by 595/793.7 ≈ 0.75 to fit the A4 paper.
    // Net: 1 CSS-px = 0.75pt on paper = 25.4/96 mm ≈ 0.265mm.
    // We use 25.4/82 (~0.31mm) as a conservative estimate to absorb font-metric
    // and margin-collapsing variance across iOS versions.
    static let pxMm: Double = 25.4 / 82.0

    static var sectionGapMm: Double { 40.0 * pxMm }
    static var tableHeaderMm: Double { (20.0 + 2.0 + 14.4) * pxMm }
    static var itemRowChromeMm: Double { 29.0 * pxMm }
    static var bodyLineMm: Double { 14.0 * 1.2 * pxMm }
    static var contactLineMm: Double { 14.0 * 1.5 * pxMm }
    static var logoLineMm: Double { 42.0 * 1.2 * pxMm }
    static var blockTitleMm: Double { (14.4 + 8.0) * pxMm }
    static var infoLineMm: Double { (16.8 + 6.0) * pxMm }
    static var notesLineMm: Double { 13.0 * 1.5 * pxMm }

    static var totalsGapMm: Double { 24.0 * pxMm }

    static var totalsContentMm: Double {
        let row = (16.8 + 4.0) * pxMm
        let hr = 6.0 * pxMm
        let big = (26.4 + 4.0) * pxMm
        return 3.0 * row + hr + big
    }

    static var notesSamePageChromeMm: Double { 36.0 * pxMm }
    static var notesNewPageChromeMm: Double { 12.0 * pxMm }

    static let charsPerLine: Double = 62.0

    static var pagePaddingCSS: String { String(format: "%.0fmm", pageTopPaddingMm) }
    static var pageMinHeightCSS: String { String(format: "%.0fmm", pageHeightMm) }
}

// MARK: - Pagination Engine

enum PaginationTestInvoiceEngine {
    private static let M = PageMetrics.self

    static func render(invoice: InvoiceModel, theme: InvoiceColorTheme) -> String {
        let result = paginate(invoice: invoice)
        return buildHTML(result: result, invoice: invoice, theme: theme)
    }

    /// Deterministic single-pass block placement.
    /// One currentY cursor. Pages are only committed when they contain content.
    static func paginate(invoice: InvoiceModel) -> PaginationTestResult {
        let allItems = LineItemModel.sortedLineItems(invoice.items)
        let hasNotes = !invoice.additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let limit = M.usableHeight

        // ── Working page state ──
        var committed: [PaginationTestRenderPage] = []
        var wkIdx = 0
        var wkFirst = true
        var wkHeader = false
        var wkParties = false
        var wkItems: [LineItemModel] = []
        var wkTotals = false
        var wkNotes = false
        var currentY: Double = 0

        /// Commit the working page IF it has at least one content block. Returns true if committed.
        @discardableResult
        func commitPage() -> Bool {
            let has = wkHeader || wkParties || !wkItems.isEmpty || wkTotals || wkNotes
            if has {
                print("[Paginate] COMMIT pg\(wkIdx): header=\(wkHeader) parties=\(wkParties) items=\(wkItems.count) totals=\(wkTotals) notes=\(wkNotes) currentY=\(f(currentY))")
                committed.append(PaginationTestRenderPage(
                    pageIndex: wkIdx, isFirstPage: wkFirst, isLastPage: false,
                    showHeader: wkHeader, showParties: wkParties,
                    itemRows: wkItems, showTotals: wkTotals, showNotes: wkNotes
                ))
            } else {
                print("[Paginate] DISCARD pg\(wkIdx) — empty (no content placed)")
            }
            return has
        }

        /// Commit current page, start a fresh working page.
        func nextPage() {
            commitPage()
            wkIdx = committed.count
            wkFirst = false
            wkHeader = false
            wkParties = false
            wkItems = []
            wkTotals = false
            wkNotes = false
            currentY = 0
            print("[Paginate] NEW PAGE pg\(wkIdx) currentY=0")
        }

        // ── 1. Header ──
        let headerH = estimateHeaderHeight(invoice: invoice)
        wkHeader = true
        currentY += headerH
        print("[Paginate] pg\(wkIdx) HEADER h=\(f(headerH)) y=\(f(currentY))")

        // ── 2. Parties ──
        let partiesH = estimatePartiesHeight(invoice: invoice)
        wkParties = true
        currentY += partiesH
        print("[Paginate] pg\(wkIdx) PARTIES h=\(f(partiesH)) y=\(f(currentY))")

        // ── 3+4. Table header + rows ──
        let thH = M.tableHeaderMm

        for (i, item) in allItems.enumerated() {
            let rowH = estimateItemRowHeight(item: item)
            let firstOnPage = wkItems.isEmpty
            let need = firstOnPage ? (thH + rowH) : rowH

            if currentY + need <= limit {
                if firstOnPage {
                    currentY += thH
                    print("[Paginate] pg\(wkIdx) TBL_HDR h=\(f(thH)) y=\(f(currentY))")
                }
                wkItems.append(item)
                currentY += rowH
                print("[Paginate] pg\(wkIdx) ITEM[\(i)] h=\(f(rowH)) y=\(f(currentY)) fit=YES")
            } else {
                print("[Paginate] pg\(wkIdx) ITEM[\(i)] h=\(f(rowH)) need=\(f(need)) avail=\(f(limit - currentY)) fit=NO → new page")
                nextPage()
                currentY += thH
                print("[Paginate] pg\(wkIdx) TBL_HDR h=\(f(thH)) y=\(f(currentY))")
                wkItems.append(item)
                currentY += rowH
                print("[Paginate] pg\(wkIdx) ITEM[\(i)] h=\(f(rowH)) y=\(f(currentY))")
            }
        }

        // ── 5. Totals ──
        let totalsWithGap = M.totalsGapMm + M.totalsContentMm
        let totalsAlone = M.totalsContentMm

        print("[Paginate] pg\(wkIdx) TOTALS? need=\(f(totalsWithGap)) avail=\(f(limit - currentY))")
        if currentY + totalsWithGap <= limit {
            wkTotals = true
            currentY += totalsWithGap
            print("[Paginate] pg\(wkIdx) TOTALS h=\(f(totalsWithGap)) y=\(f(currentY)) fit=YES")
        } else {
            print("[Paginate] pg\(wkIdx) TOTALS fit=NO → new page")
            nextPage()
            wkTotals = true
            currentY += totalsAlone
            print("[Paginate] pg\(wkIdx) TOTALS h=\(f(totalsAlone)) y=\(f(currentY))")
        }

        // ── 6. Notes ──
        if hasNotes {
            let notesSame = estimateNotesHeight(invoice.additionalNotes, isFirstChild: false)
            let notesAlone = estimateNotesHeight(invoice.additionalNotes, isFirstChild: true)

            print("[Paginate] pg\(wkIdx) NOTES? need=\(f(notesSame)) avail=\(f(limit - currentY))")
            if currentY + notesSame <= limit {
                wkNotes = true
                currentY += notesSame
                print("[Paginate] pg\(wkIdx) NOTES h=\(f(notesSame)) y=\(f(currentY)) fit=YES")
            } else {
                print("[Paginate] pg\(wkIdx) NOTES fit=NO → new page")
                nextPage()
                wkNotes = true
                currentY += notesAlone
                print("[Paginate] pg\(wkIdx) NOTES h=\(f(notesAlone)) y=\(f(currentY))")
            }
        }

        // ── Commit final working page ──
        commitPage()

        // ── Validation: discard any page with zero content (should never happen) ──
        let valid = committed.filter { pg in
            pg.showHeader || pg.showParties || !pg.itemRows.isEmpty || pg.showTotals || pg.showNotes
        }
        if valid.count != committed.count {
            print("[Paginate] ⚠️ REMOVED \(committed.count - valid.count) empty page(s)")
        }

        let pages = valid.enumerated().map { idx, pg in
            PaginationTestRenderPage(
                pageIndex: idx, isFirstPage: pg.isFirstPage,
                isLastPage: idx == valid.count - 1,
                showHeader: pg.showHeader, showParties: pg.showParties,
                itemRows: pg.itemRows, showTotals: pg.showTotals, showNotes: pg.showNotes
            )
        }

        print("[Paginate] RESULT: \(pages.count) page(s), limit=\(f(limit))mm, pxMm=\(f(M.pxMm))")
        for (i, pg) in pages.enumerated() {
            print("[Paginate]   pg\(i): header=\(pg.showHeader) parties=\(pg.showParties) items=\(pg.itemRows.count) totals=\(pg.showTotals) notes=\(pg.showNotes)")
        }
        return PaginationTestResult(pages: pages)
    }

    // MARK: Height Estimates

    private static func estimateItemRowHeight(item: LineItemModel) -> Double {
        let lines = estimatedLines(item.title, minimum: 1) + estimatedLines(item.details, minimum: 0)
        return M.itemRowChromeMm + lines * M.bodyLineMm
    }

    private static func estimateHeaderHeight(invoice: InvoiceModel) -> Double {
        let contactLines = estimatedLines(invoice.businessName, minimum: 1) +
            estimatedLines(invoice.businessAddress, minimum: 0) +
            estimatedLines(invoice.businessEmail, minimum: 0) +
            estimatedLines(invoice.businessPhone, minimum: 0) +
            estimatedLines(invoice.businessTaxId, minimum: 0)
        return max(M.logoLineMm, contactLines * M.contactLineMm) + M.sectionGapMm
    }

    private static func estimatePartiesHeight(invoice: InvoiceModel) -> Double {
        let clientLines = estimatedLines(invoice.clientName, minimum: 1) +
            estimatedLines(invoice.clientAddress, minimum: 0) +
            estimatedLines(invoice.clientEmail, minimum: 0) +
            estimatedLines(invoice.clientPhone, minimum: 0) +
            estimatedLines(invoice.clientTaxId, minimum: 0)
        let leftH = M.blockTitleMm + clientLines * M.bodyLineMm
        let infoCount = 2.0 + (invoice.periodStart != nil && invoice.periodEnd != nil ? 1 : 0)
        let rightH = infoCount * M.infoLineMm
        return max(leftH, rightH) + M.sectionGapMm
    }

    private static func estimateNotesHeight(_ notes: String, isFirstChild: Bool) -> Double {
        let lines = estimatedLines(notes, minimum: 1)
        let chrome = isFirstChild ? M.notesNewPageChromeMm : M.notesSamePageChromeMm
        return chrome + lines * M.notesLineMm
    }

    private static func estimatedLines(_ text: String, minimum: Double) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return minimum }
        return max(minimum, trimmed.components(separatedBy: "\n").reduce(0.0) { sum, line in
            sum + max(1, ceil(Double(max(line.count, 1)) / M.charsPerLine))
        })
    }

    private static func f(_ v: Double) -> String { String(format: "%.1f", v) }

    // MARK: HTML

    private static func buildHTML(result: PaginationTestResult, invoice: InvoiceModel, theme: InvoiceColorTheme) -> String {
        let cc = invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode
        let df = DateFormatter(); df.dateStyle = .long
        let invoiceDate = df.string(from: invoice.issueDate)
        let periodBlock = buildPeriodBlock(invoice: invoice)
        let notesBlock = buildNotesBlock(invoice: invoice)
        let sub = cur(invoice.subtotal, cc)
        let tax = cur(invoice.subtotal * (invoice.taxPercent / 100), cc)
        let disc = cur(0, cc)
        let tot = cur(invoice.total, cc)

        let totalPages = result.pages.count
        let pagesHTML = result.pages.map { page in
            let cont = (page.showHeader || page.showParties) ? "" : " continuation"
            let pageNum = page.pageIndex + 1
            var h = "<div class=\"page\(cont)\"><div class=\"page-number\">Page \(pageNum) of \(totalPages)</div><div class=\"invoice\">"
            if page.showHeader {
                h += """
                <div class="header">
                    <div class="logo">invoice</div>
                    <div class="contact">
                        \(fieldDiv(invoice.businessName))
                        \(fieldDivMultiline(invoice.businessAddress))
                        \(fieldDiv(invoice.businessEmail))
                        \(fieldDiv(invoice.businessPhone))
                        \(labeledFieldDiv("Tax ID", invoice.businessTaxId))
                    </div>
                </div>
                """
            }
            if page.showParties {
                h += """
                <div class="section">
                    <div class="block">
                        <div class="block-title">BILL TO</div>
                        \(fieldDiv(invoice.clientName))
                        \(fieldDivMultiline(invoice.clientAddress))
                        \(fieldDiv(invoice.clientEmail))
                        \(fieldDiv(invoice.clientPhone))
                        \(labeledFieldDiv("Tax ID", invoice.clientTaxId))
                    </div>
                    <div class="invoice-info">
                        <div><b>Invoice #</b> <span class="meta-value">\(esc(invoice.number))</span></div>
                        <div><b>Issue Date</b> \(esc(invoiceDate))</div>
                        \(periodBlock)
                    </div>
                </div>
                """
            }
            if !page.itemRows.isEmpty {
                let rows = page.itemRows.map { item in
                    let det = item.details.isEmpty ? "" : "<br><small style=\"color:#888;\">\(esc(item.details))</small>"
                    return """
                    <div class="item-row">
                        <div class="item-title">\(esc(item.title))\(det)</div>
                        <div class="right">\(cur(item.price, cc))</div>
                        <div class="right">\(item.qty) \(esc(item.unit))</div>
                        <div class="right">\(cur(item.total, cc))</div>
                    </div>
                    """
                }.joined(separator: "\n")
                h += """
                <div class="items">
                    <div class="items-header">
                        <div>Description</div>
                        <div class="right">Rate</div>
                        <div class="right">Qty</div>
                        <div class="right">Amount</div>
                    </div>
                    \(rows)
                </div>
                """
            }
            if page.showTotals {
                h += """
                <div class="total-section">
                    <div class="total-box">
                        <div class="total-row"><div>Subtotal</div><div>\(sub)</div></div>
                        <div class="total-row"><div>Tax</div><div>\(tax)</div></div>
                        <div class="total-row"><div>Discount</div><div>\(disc)</div></div>
                        <hr>
                        <div class="total-row total"><div>Total</div><div>\(tot)</div></div>
                    </div>
                </div>
                """
            }
            if page.showNotes { h += notesBlock }
            h += "</div></div>"
            return h
        }.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <title>Invoice</title>
        <style>
        @page { size: A4 portrait; margin: 0; }
        html, body { margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background:#f4f6f8; }
        .invoice-document { display:block; width:100%; }
        .page {
          display:block; width:210mm; min-height:\(M.pageMinHeightCSS);
          margin:0 auto 24px auto; padding:\(M.pagePaddingCSS);
          page-break-after:always; break-after:page; box-sizing:border-box;
          position:relative;
        }
        .page:last-child { page-break-after:auto; break-after:auto; margin-bottom:0; }
        .invoice { width:100%; background:white; border-radius:12px; box-shadow:0 10px 30px rgba(0,0,0,0.08); box-sizing:border-box; display:block; }
        .invoice > .items, .invoice > .total-section, .invoice > .notes-section { display:block; }
        .header,.section,.total-section,.notes-section,.item-row,.total-box { page-break-inside:avoid; break-inside:avoid; }
        .header{ display:flex; justify-content:space-between; margin-bottom:40px; }
        .logo{ font-size:42px; font-weight:300; color:\(theme.accentColor); flex:0 0 48%; max-width:48%; }
        .contact{ flex:0 0 48%; max-width:48%; min-width:0; font-size:14px; color:#555; line-height:1.5; text-align:left; padding:12px; box-sizing:border-box; }
        .section{ display:flex; justify-content:space-between; margin-bottom:40px; }
        .block-title{ color:\(theme.titleColor); letter-spacing:2px; font-size:12px; margin-bottom:8px; }
        .block{ font-size:14px; flex:0 0 48%; max-width:48%; min-width:0; padding:12px; box-sizing:border-box; text-align:left; }
        .invoice-info{ text-align:left; font-size:14px; flex:0 0 48%; max-width:48%; min-width:0; padding:12px; box-sizing:border-box; }
        .invoice-info div{ margin-bottom:6px; max-width:100%; overflow:hidden; overflow-wrap:break-word; word-break:break-word; }
        .meta-value{ display:inline-block; max-width:100%; white-space:normal; overflow-wrap:break-word; word-break:break-word; }
        .field-line{ display:block; width:100%; white-space:normal; overflow-wrap:break-word; word-break:break-word; text-align:left; line-height:1.5; }
        .items{ margin-top:40px; }
        .items-header{ display:grid; grid-template-columns:3fr 1fr 1fr 1fr; gap:12px; padding:10px 0; border-bottom:2px solid \(theme.borderColor); color:\(theme.accentColor); font-size:12px; letter-spacing:1px; }
        .item-row{ display:grid; grid-template-columns:3fr 1fr 1fr 1fr; gap:12px; padding:14px 0; border-bottom:1px solid #eee; font-size:14px; }
        .item-title{ font-weight:600; }
        .right{ text-align:right; white-space:nowrap; }
        .total-section{ margin-top:24px; display:block; }
        .total-box{ width:300px; margin-left:auto; }
        .total-row{ display:flex; justify-content:space-between; margin-bottom:4px; }
        .total{ font-size:22px; font-weight:700; color:\(theme.accentColor); }
        .notes-section{ margin-top:24px; padding-top:12px; }
        .page.continuation .items:first-child,
        .page.continuation .total-section:first-child,
        .page.continuation .notes-section:first-child { margin-top:0; }
        .notes-title{ font-size:12px; font-weight:600; color:#666; margin-bottom:6px; text-transform:uppercase; letter-spacing:0.5px; }
        .notes-text{ font-size:13px; color:#222; line-height:1.5; white-space:pre-wrap; }
        .page-number{ position:absolute; bottom:10mm; right:20mm; font-size:12px; font-weight:600; color:#7a7a79; letter-spacing:0.04em; z-index:4; pointer-events:none; }
        @media print {
            body { margin:0; padding:0; background:white; }
            .page { margin:0; padding:\(M.pagePaddingCSS); height:\(M.pageMinHeightCSS); overflow:hidden; }
            .invoice { box-shadow:none; border-radius:0; }
        }
        </style>
        </head>
        <body>
          <div class="invoice-document">
            \(pagesHTML)
          </div>
        </body>
        </html>
        """
    }

    // MARK: Helpers

    private static func buildPeriodBlock(invoice: InvoiceModel) -> String {
        guard let s = invoice.periodStart, let e = invoice.periodEnd else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return "<div><b>Invoice Period</b> \(esc("\(f.string(from: s)) – \(f.string(from: e))"))</div>"
    }

    private static func buildNotesBlock(invoice: InvoiceModel) -> String {
        let n = invoice.additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return "" }
        return """
        <div class="notes-section">
            <div class="notes-title">Additional Notes</div>
            <div class="notes-text">\(esc(n))</div>
        </div>
        """
    }

    private static func fieldDiv(_ t: String) -> String {
        let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "" : "<div class=\"field-line\">\(esc(s))</div>"
    }

    private static func fieldDivMultiline(_ t: String) -> String {
        let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }
        let normalized = s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let html = esc(normalized).replacingOccurrences(of: "\n", with: "<br>")
        return "<div class=\"field-line\">\(html)</div>"
    }

    private static func labeledFieldDiv(_ label: String, _ value: String) -> String {
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "" : "<div class=\"field-line\">\(esc(label)): \(esc(s))</div>"
    }

    private static func optDiv(_ t: String) -> String {
        let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "" : "<div>\(esc(s))</div>"
    }

    private static func esc(_ t: String) -> String {
        t.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func cur(_ amount: Double, _ code: String) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        f.currencyCode = code.isEmpty ? "USD" : code
        return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}
