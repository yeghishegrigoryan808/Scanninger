import Foundation

// MARK: - Elegant Paginated Invoice Engine
//
// Replicates the exact visual design of the elegant template (invoice_template_elegant_02)
// but renders multiple pages using the same deterministic pagination approach as
// PaginationTestInvoiceEngine.
//
// Pagination behaviour (matches PaginationTest):
//   • Header (hero) and bill-to appear ONLY on the first page
//   • Continuation pages have NO header — only items / totals / notes
//   • Table header repeats on every page that contains item rows
//   • Totals appear only on the last page
//   • Decorative elements (accent bar, corner lines, gradient shapes) appear on every page

enum ElegantPaginatedInvoiceEngine {

    // MARK: - Page Metrics (derived from elegant template CSS values)

    private enum M {
        static let pageHeightMm: Double = 297.0
        static let safetyMm: Double = 1.0

        /// Moderately conservative CSS-px → mm conversion.
        /// True value ≈ 25.4/96 (0.265mm); we use 25.4/90 (0.282mm) to absorb
        /// font-metric and margin-collapsing variance while staying closer to reality.
        static let pxMm: Double = 25.4 / 90.0

        /// Top accent bar: 14 CSS-px.
        static var topAccentMm: Double { 14.0 * pxMm }
        /// `.inner` padding — top stays generous, bottom reduced so content flows lower.
        static let innerPaddingTopMm: Double = 18.0
        static let innerPaddingBottomMm: Double = 6.0

        /// Usable content height inside `.inner` per page.
        static var usableHeight: Double {
            pageHeightMm - topAccentMm - innerPaddingTopMm - innerPaddingBottomMm - safetyMm
        }

        // -- Hero (header) ------------------------------------------------
        // business-name 17px + mb16, invoice-title 42px + mb16
        static var heroFixedMm: Double { (17.0 + 16.0 + 42.0 + 16.0) * pxMm }
        // from-lines: 13px font, line-height 1.7
        static var fromLineMm: Double { 13.0 * 1.7 * pxMm }
        // meta-row: 13px font + 8px margin-bottom
        static var metaRowMm: Double { (13.0 + 8.0) * pxMm }
        // hero margin-bottom
        static let heroGapMm: Double = 14.0

        // -- Bill-to ------------------------------------------------------
        // section-label (11+10), card padding top+bottom (18+18), client-name (16+8)
        static var billToChromeMm: Double { (11.0 + 10.0 + 36.0 + 16.0 + 8.0) * pxMm }
        // client-lines: 13px, line-height 1.65
        static var clientLineMm: Double { 13.0 * 1.65 * pxMm }
        // bill-to margin-bottom
        static let billToGapMm: Double = 14.0

        // -- Items table --------------------------------------------------
        // thead th: padding 14+14, font ~14.4
        static var tableHeaderMm: Double { (28.0 + 14.4) * pxMm }
        // tbody td: padding 14+14 = 28px chrome per row
        static var itemRowChromeMm: Double { 29.0 * pxMm }
        // body text line ~14px * 1.2 effective line-height
        static var bodyLineMm: Double { 14.0 * 1.2 * pxMm }

        // -- Totals (compact card) ----------------------------------------
        // Gap before totals = items-wrap CSS margin-bottom
        static let totalsGapMm: Double = 6.0
        // Compact card: chrome 20px + 2 rows × 19px + divider 9px + grand 56px
        static var totalsContentMm: Double {
            let cardChrome = 20.0 * pxMm   // padding 10+10
            let rows       = 2.0 * 19.0 * pxMm  // subtotal + tax rows (3+13+3 each)
            let divider    = 9.0 * pxMm    // 4 + 1 + 4
            let grand      = 56.0 * pxMm   // grand-total box (6+11+2 top + 30.8+6 amount)
            return cardChrome + rows + divider + grand
        }

        // -- Notes --------------------------------------------------------
        static var notesSamePageChromeMm: Double { 36.0 * pxMm }
        static var notesNewPageChromeMm: Double  { 12.0 * pxMm }
        static var notesLineMm: Double { 13.0 * 1.5 * pxMm }

        static let charsPerLine: Double = 58.0
    }

    // MARK: - Public API

    static func render(invoice: InvoiceModel, theme: InvoiceColorTheme) -> String {
        let result = paginate(invoice: invoice)
        return buildHTML(result: result, invoice: invoice, theme: theme)
    }

    // MARK: - Pagination (same behaviour as PaginationTestInvoiceEngine)

    static func paginate(invoice: InvoiceModel) -> PaginationTestResult {
        let allItems = LineItemModel.sortedLineItems(invoice.items)
        let hasNotes = !invoice.additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let limit    = M.usableHeight

        let headerH  = estimateHeaderHeight(invoice: invoice)
        let partiesH = estimatePartiesHeight(invoice: invoice)

        var committed: [PaginationTestRenderPage] = []
        var wkIdx     = 0
        var wkFirst   = true
        var wkHeader  = true
        var wkParties = false
        var wkItems:  [LineItemModel] = []
        var wkTotals  = false
        var wkNotes   = false
        var currentY: Double = 0

        @discardableResult
        func commitPage() -> Bool {
            let has = wkHeader || wkParties || !wkItems.isEmpty || wkTotals || wkNotes
            if has {
                print("[ElegantPag] COMMIT pg\(wkIdx): hdr=\(wkHeader) parties=\(wkParties) items=\(wkItems.count) totals=\(wkTotals) notes=\(wkNotes) y=\(f(currentY))")
                committed.append(PaginationTestRenderPage(
                    pageIndex: wkIdx, isFirstPage: wkFirst, isLastPage: false,
                    showHeader: wkHeader, showParties: wkParties,
                    itemRows: wkItems, showTotals: wkTotals, showNotes: wkNotes
                ))
            }
            return has
        }

        func nextPage() {
            commitPage()
            wkIdx     = committed.count
            wkFirst   = false
            wkHeader  = false     // NO header on continuation pages
            wkParties = false
            wkItems   = []
            wkTotals  = false
            wkNotes   = false
            currentY  = 0         // fresh page — no header overhead
            print("[ElegantPag] NEW pg\(wkIdx) currentY=0")
        }

        // ── 1. Header ──
        currentY += headerH
        print("[ElegantPag] pg\(wkIdx) HEADER h=\(f(headerH)) y=\(f(currentY))")

        // ── 2. Bill-to (first page only) ──
        wkParties = true
        currentY += partiesH
        print("[ElegantPag] pg\(wkIdx) BILL-TO h=\(f(partiesH)) y=\(f(currentY))")

        // ── 3. Items ──
        let thH = M.tableHeaderMm

        for (i, item) in allItems.enumerated() {
            let rowH = estimateItemRowHeight(item: item)
            let firstOnPage = wkItems.isEmpty
            let need = firstOnPage ? (thH + rowH) : rowH

            if currentY + need <= limit {
                if firstOnPage {
                    currentY += thH
                    print("[ElegantPag] pg\(wkIdx) TBL_HDR h=\(f(thH)) y=\(f(currentY))")
                }
                wkItems.append(item)
                currentY += rowH
                print("[ElegantPag] pg\(wkIdx) ITEM[\(i)] h=\(f(rowH)) y=\(f(currentY)) fit=YES")
            } else {
                print("[ElegantPag] pg\(wkIdx) ITEM[\(i)] need=\(f(need)) avail=\(f(limit - currentY)) → new page")
                nextPage()
                currentY += thH
                print("[ElegantPag] pg\(wkIdx) TBL_HDR h=\(f(thH)) y=\(f(currentY))")
                wkItems.append(item)
                currentY += rowH
                print("[ElegantPag] pg\(wkIdx) ITEM[\(i)] h=\(f(rowH)) y=\(f(currentY))")
            }
        }

        // ── 4. Totals ──
        let totalsWithGap = M.totalsGapMm + M.totalsContentMm
        let totalsAlone   = M.totalsContentMm

        print("[ElegantPag] pg\(wkIdx) TOTALS? need=\(f(totalsWithGap)) avail=\(f(limit - currentY))")
        if currentY + totalsWithGap <= limit {
            wkTotals  = true
            currentY += totalsWithGap
            print("[ElegantPag] pg\(wkIdx) TOTALS fit=YES y=\(f(currentY))")
        } else {
            print("[ElegantPag] pg\(wkIdx) TOTALS fit=NO → new page")
            nextPage()
            wkTotals  = true
            currentY += totalsAlone
            print("[ElegantPag] pg\(wkIdx) TOTALS h=\(f(totalsAlone)) y=\(f(currentY))")
        }

        // ── 5. Notes ──
        if hasNotes {
            let notesSame  = estimateNotesHeight(invoice.additionalNotes, isFirstChild: false)
            let notesAlone = estimateNotesHeight(invoice.additionalNotes, isFirstChild: true)

            print("[ElegantPag] pg\(wkIdx) NOTES? need=\(f(notesSame)) avail=\(f(limit - currentY))")
            if currentY + notesSame <= limit {
                wkNotes   = true
                currentY += notesSame
                print("[ElegantPag] pg\(wkIdx) NOTES fit=YES y=\(f(currentY))")
            } else {
                print("[ElegantPag] pg\(wkIdx) NOTES fit=NO → new page")
                nextPage()
                wkNotes   = true
                currentY += notesAlone
                print("[ElegantPag] pg\(wkIdx) NOTES h=\(f(notesAlone)) y=\(f(currentY))")
            }
        }

        // ── Commit final page ──
        commitPage()

        // ── Validate & finalize ──
        let valid = committed.filter {
            $0.showHeader || $0.showParties || !$0.itemRows.isEmpty || $0.showTotals || $0.showNotes
        }
        let pages = valid.enumerated().map { idx, pg in
            PaginationTestRenderPage(
                pageIndex: idx, isFirstPage: pg.isFirstPage,
                isLastPage: idx == valid.count - 1,
                showHeader: pg.showHeader, showParties: pg.showParties,
                itemRows: pg.itemRows, showTotals: pg.showTotals, showNotes: pg.showNotes
            )
        }

        print("[ElegantPag] RESULT: \(pages.count) page(s), usable=\(f(limit))mm")
        for (i, pg) in pages.enumerated() {
            print("[ElegantPag]   pg\(i): hdr=\(pg.showHeader) parties=\(pg.showParties) items=\(pg.itemRows.count) totals=\(pg.showTotals) notes=\(pg.showNotes) first=\(pg.isFirstPage) last=\(pg.isLastPage)")
        }
        return PaginationTestResult(pages: pages)
    }

    // MARK: - Height Estimates

    private static func estimateHeaderHeight(invoice: InvoiceModel) -> Double {
        let fromLines = estimatedLines(invoice.businessAddress, minimum: 0)
            + estimatedLines(invoice.businessEmail, minimum: 0)
            + estimatedLines(invoice.businessPhone, minimum: 0)
            + estimatedLines(invoice.businessTaxId, minimum: 0)
        let leftH     = M.heroFixedMm + fromLines * M.fromLineMm

        let metaCount = 2.0 + (invoice.periodStart != nil && invoice.periodEnd != nil ? 1.0 : 0.0)
        let rightH    = metaCount * M.metaRowMm

        return max(leftH, rightH) + M.heroGapMm
    }

    private static func estimatePartiesHeight(invoice: InvoiceModel) -> Double {
        let clientLines = estimatedLines(invoice.clientAddress, minimum: 0)
            + estimatedLines(invoice.clientEmail, minimum: 0)
            + estimatedLines(invoice.clientPhone, minimum: 0)
            + estimatedLines(invoice.clientTaxId, minimum: 0)
        return M.billToChromeMm + clientLines * M.clientLineMm + M.billToGapMm
    }

    private static func estimateItemRowHeight(item: LineItemModel) -> Double {
        let lines = estimatedLines(item.title, minimum: 1)
            + estimatedLines(item.details, minimum: 0)
        return M.itemRowChromeMm + lines * M.bodyLineMm
    }

    private static func estimateNotesHeight(_ notes: String, isFirstChild: Bool) -> Double {
        let lines  = estimatedLines(notes, minimum: 1)
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

    // MARK: - HTML Generation

    private static func buildHTML(result: PaginationTestResult, invoice: InvoiceModel, theme: InvoiceColorTheme) -> String {
        let cc  = invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode
        let df  = DateFormatter(); df.dateStyle = .long
        let invoiceDate = df.string(from: invoice.issueDate)

        let sub       = cur(invoice.subtotal, cc)
        let taxAmount = invoice.subtotal * (invoice.taxPercent / 100)
        let tax       = cur(taxAmount, cc)
        let tot       = cur(invoice.total, cc)

        let totalPages = result.pages.count
        let pagesHTML = result.pages.map { page -> String in
            var sections = ""

            if page.showHeader {
                sections += heroHTML(invoice: invoice, invoiceDate: invoiceDate)
            }
            if page.showParties {
                sections += billToHTML(invoice: invoice)
            }
            if !page.itemRows.isEmpty {
                sections += itemsTableHTML(items: page.itemRows, cc: cc)
            }
            if page.showTotals {
                sections += totalsHTML(sub: sub, taxAmount: taxAmount, tax: tax, tot: tot)
            }
            if page.showNotes {
                sections += notesHTML(invoice: invoice)
            }

            let cls = page.isFirstPage ? "page" : "page continuation"
            let pageNum = page.pageIndex + 1
            return """
            <div class="\(cls)">
              <div class="top-accent"></div>
              <div class="corner-line-top"></div>
              <div class="corner-line-bottom"></div>
              <div class="page-number">Page \(pageNum) of \(totalPages)</div>
              <div class="inner">\(sections)</div>
            </div>
            """
        }.joined(separator: "\n")

        return fullDocument(pagesHTML: pagesHTML, theme: theme)
    }

    // MARK: Section Builders

    private static func heroHTML(invoice: InvoiceModel, invoiceDate: String) -> String {
        var fromParts: [String] = []
        let addr = invoice.businessAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr.isEmpty { fromParts.append(escBr(addr)) }
        let email = invoice.businessEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.isEmpty { fromParts.append(esc(email)) }
        let phone = invoice.businessPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phone.isEmpty { fromParts.append(esc(phone)) }
        let taxId = invoice.businessTaxId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !taxId.isEmpty { fromParts.append("Tax ID: \(esc(taxId))") }
        let fromHTML = fromParts.joined(separator: "<br>")

        var periodRow = ""
        if let s = invoice.periodStart, let e = invoice.periodEnd {
            let pf = DateFormatter(); pf.dateFormat = "MMM d, yyyy"
            periodRow = """
            <div class="meta-row">
              <div class="meta-label">Period</div>
              <div class="meta-value">\(esc("\(pf.string(from: s)) – \(pf.string(from: e))"))</div>
            </div>
            """
        }

        return """
        <div class="hero">
          <div class="left-head">
            <div class="business-name">\(esc(invoice.businessName))</div>
            <div class="invoice-title">Invoice</div>
            <div class="from-lines">\(fromHTML)</div>
          </div>
          <div class="right-head">
            <div class="meta-row">
              <div class="meta-label">Invoice #</div>
              <div class="meta-value">\(esc(invoice.number))</div>
            </div>
            <div class="meta-row">
              <div class="meta-label">Issued</div>
              <div class="meta-value">\(esc(invoiceDate))</div>
            </div>
            \(periodRow)
          </div>
        </div>
        """
    }

    private static func billToHTML(invoice: InvoiceModel) -> String {
        var detailParts: [String] = []
        let addr = invoice.clientAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr.isEmpty { detailParts.append(escBr(addr)) }
        let email = invoice.clientEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.isEmpty { detailParts.append(esc(email)) }
        let phone = invoice.clientPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phone.isEmpty { detailParts.append(esc(phone)) }
        let taxId = invoice.clientTaxId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !taxId.isEmpty { detailParts.append("Tax ID: \(esc(taxId))") }
        let detailHTML = detailParts.joined(separator: "<br>")

        return """
        <div class="bill-to-section">
          <div class="section-label">Billed To</div>
          <div class="client-card">
            <div class="client-name">\(esc(invoice.clientName))</div>
            <div class="client-lines">\(detailHTML)</div>
          </div>
        </div>
        """
    }

    private static func itemsTableHTML(items: [LineItemModel], cc: String) -> String {
        let rows = items.map { item -> String in
            var titleCell = "<div class=\"item-title\">\(esc(item.title))</div>"
            let desc = item.details.trimmingCharacters(in: .whitespacesAndNewlines)
            if !desc.isEmpty {
                titleCell += "<div class=\"item-desc\">\(esc(desc))</div>"
            }
            return """
            <tr>
              <td>\(titleCell)</td>
              <td class="num">\(cur(item.price, cc))</td>
              <td class="num">\(item.qty) \(esc(item.unit))</td>
              <td class="num">\(cur(item.total, cc))</td>
            </tr>
            """
        }.joined(separator: "\n")

        return """
        <div class="items-wrap">
          <div class="table-shell">
            <table>
              <thead>
                <tr>
                  <th>Description</th>
                  <th class="num" style="width:120px;">Rate</th>
                  <th class="num" style="width:90px;">Qty</th>
                  <th class="num" style="width:140px;">Amount</th>
                </tr>
              </thead>
              <tbody>
                \(rows)
              </tbody>
            </table>
          </div>
        </div>
        """
    }

    private static func totalsHTML(sub: String, taxAmount: Double, tax: String, tot: String) -> String {
        let taxRow = taxAmount > 0
            ? "<div class=\"total-row\"><div class=\"label\">Tax</div><div class=\"value\">\(esc(tax))</div></div>"
            : ""

        return """
        <div class="bottom-grid">
          <div class="stack"></div>
          <div class="totals-card">
            <div class="total-row">
              <div class="label">Subtotal</div>
              <div class="value">\(esc(sub))</div>
            </div>
            \(taxRow)
            <div class="divider"></div>
            <div class="grand-total">
              <div class="grand-total-top">Total</div>
              <div class="grand-total-amount">\(esc(tot))</div>
            </div>
          </div>
        </div>
        """
    }

    private static func notesHTML(invoice: InvoiceModel) -> String {
        let notes = invoice.additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty else { return "" }
        return """
        <div class="notes-section">
          <div class="notes-title">Additional Notes</div>
          <div class="notes-text">\(esc(notes))</div>
        </div>
        """
    }

    // MARK: - Full HTML Document

    private static func fullDocument(pagesHTML: String, theme: InvoiceColorTheme) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Invoice</title>
        <style>
          :root {
            --accent: \(theme.accentColor);
            --accent-dark: \(theme.titleColor);
            --accent-soft: \(theme.accentSoftColor);
            --border: \(theme.borderColor);
            --text: #1f2937;
            --muted: #6b7280;
            --bg: #f3f4f6;
            --line: #e5e7eb;
            --white: #ffffff;
          }

          /* Force background colors in print / PDF export */
          *, *::before, *::after {
            -webkit-print-color-adjust: exact !important;
            print-color-adjust: exact !important;
          }

          * { box-sizing: border-box; }

          html, body {
            margin: 0; padding: 0;
            background: var(--bg);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            color: var(--text);
          }

          @page { size: A4; margin: 0; }

          body { padding: 18px; }

          /* ── Page container ─────────────────────────────────────── */

          .page {
            width: 210mm;
            min-height: 297mm;
            margin: 0 auto 24px auto;
            background: var(--white);
            box-shadow: 0 12px 30px rgba(0,0,0,0.08);
            position: relative;
            overflow: hidden;
            page-break-after: always;
            break-after: page;
          }
          .page:last-child {
            page-break-after: auto;
            break-after: auto;
            margin-bottom: 0;
          }

          /* ── Decorative elements (repeated on every page) ─────── */

          .top-accent {
            width: 100%; height: 14px;
            background: linear-gradient(90deg, var(--accent-dark), var(--accent));
            position: relative; z-index: 3;
          }

          .page::before {
            content: "";
            position: absolute;
            top: -55mm; right: -35mm;
            width: 120mm; height: 90mm;
            background: linear-gradient(135deg, var(--accent), var(--accent-soft));
            opacity: 0.18;
            transform: rotate(8deg);
            clip-path: polygon(18% 0%, 100% 0%, 100% 82%, 0% 28%);
            pointer-events: none;
          }

          .page::after {
            content: "";
            position: absolute;
            bottom: -45mm; left: -30mm;
            width: 110mm; height: 80mm;
            background: linear-gradient(135deg, var(--accent-soft), var(--accent));
            opacity: 0.16;
            transform: rotate(-8deg);
            clip-path: polygon(0 18%, 86% 0, 100% 100%, 14% 84%);
            pointer-events: none;
          }

          .corner-line-top {
            position: absolute;
            top: 14px; right: -8mm;
            width: 120mm; height: 28mm;
            border-top: 10px solid rgba(203, 213, 225, 0.75);
            border-left: 10px solid transparent;
            transform: rotate(4deg);
            z-index: 1; pointer-events: none;
          }

          .corner-line-bottom {
            position: absolute;
            bottom: 6mm; left: -10mm;
            width: 120mm; height: 28mm;
            border-bottom: 10px solid rgba(203, 213, 225, 0.72);
            border-right: 10px solid transparent;
            transform: rotate(4deg);
            z-index: 1; pointer-events: none;
          }

          /* ── Inner content area ──────────────────────────────── */

          .inner {
            position: relative;
            z-index: 2;
            padding: 18mm 18mm 6mm 18mm;
          }

          /* ── Hero (header) section ────────────────────────────── */

          .hero {
            display: grid;
            grid-template-columns: 1.2fr 0.8fr;
            gap: 16mm;
            align-items: start;
            margin-bottom: 14mm;
          }

          .left-head { min-width: 0; }

          .business-name {
            font-size: 17px; font-weight: 800;
            margin-bottom: 16px; color: #111827;
          }

          .invoice-title {
            font-family: Georgia, "Times New Roman", serif;
            font-size: 42px; line-height: 1; font-weight: 700;
            letter-spacing: 0.02em;
            margin: 0 0 16px 0;
            color: #111827;
            text-transform: uppercase;
          }

          .from-lines {
            font-size: 13px; line-height: 1.7;
            color: #4b5563; white-space: pre-line;
          }

          .right-head { text-align: right; padding-top: 4px; }

          .meta-row {
            display: flex; justify-content: space-between;
            gap: 14px; margin-bottom: 8px; font-size: 13px;
          }

          .meta-label {
            color: var(--accent-dark); font-weight: 800;
            text-transform: uppercase; letter-spacing: 0.08em;
          }

          .meta-value {
            color: #111827; font-weight: 700; text-align: right;
          }

          /* ── Bill-to section ──────────────────────────────────── */

          .bill-to-section { margin-bottom: 14mm; }

          .section-label {
            font-size: 11px; font-weight: 900;
            text-transform: uppercase; letter-spacing: 0.14em;
            color: #111827; margin-bottom: 10px;
          }

          .client-card {
            border: 1px solid var(--line);
            border-radius: 18px;
            padding: 18px 20px;
            background: linear-gradient(135deg, #ffffff, rgba(249,250,251,0.98));
            box-shadow: inset 0 1px 0 rgba(255,255,255,0.85);
          }

          .client-name {
            font-size: 16px; font-weight: 800;
            margin-bottom: 8px; color: #111827;
          }

          .client-lines {
            font-size: 13px; line-height: 1.65;
            color: #4b5563; white-space: pre-line;
          }

          /* ── Items table ─────────────────────────────────────── */

          .items-wrap { margin-bottom: 6mm; }

          .table-shell {
            border: 1px solid var(--line);
            border-radius: 18px;
            overflow: hidden;
            background: white;
          }

          table { width: 100%; border-collapse: collapse; }

          thead th {
            background: linear-gradient(90deg, var(--accent-dark), var(--accent));
            color: white;
            font-family: Georgia, "Times New Roman", serif;
            font-size: 12px; font-weight: 700;
            letter-spacing: 0.06em; text-transform: uppercase;
            padding: 14px 14px; text-align: left;
            border-right: 1px solid rgba(255,255,255,0.18);
          }
          thead th:last-child { border-right: none; }
          thead th.num, tbody td.num { text-align: right; }

          tbody td {
            padding: 14px 14px;
            border-bottom: 1px solid var(--line);
            vertical-align: top; font-size: 13px;
            background: white;
          }
          tbody tr:last-child td { border-bottom: none; }
          tbody td + td { border-left: 1px solid #f0f2f5; }

          .item-title {
            font-size: 14px; font-weight: 800;
            margin-bottom: 4px; color: #111827;
          }

          .item-desc {
            font-size: 12.5px; color: var(--muted);
            line-height: 1.55; white-space: pre-line;
          }

          /* ── Totals grid (compact) ───────────────────────────── */

          .bottom-grid {
            display: grid;
            grid-template-columns: 1fr 78mm;
            gap: 14mm;
            align-items: start;
          }

          .stack { display: flex; flex-direction: column; gap: 12px; }

          .totals-card {
            border: 1px solid var(--line);
            border-radius: 14px;
            padding: 10px 16px;
            background: linear-gradient(180deg, #ffffff, #fbfcfe);
            box-shadow: 0 8px 24px rgba(17, 24, 39, 0.04);
          }

          .total-row {
            display: flex; justify-content: space-between;
            align-items: center; gap: 14px;
            padding: 3px 0; font-size: 13px;
          }
          .total-row .label { color: #4b5563; }
          .total-row .value {
            color: #111827; font-weight: 800;
            text-align: right; white-space: nowrap;
          }

          .divider {
            height: 1px; background: var(--line);
            margin: 4px 0 4px 0;
          }

          .grand-total {
            border: 2px solid var(--border);
            border-radius: 12px; overflow: hidden;
            background: linear-gradient(135deg, rgba(255,255,255,0.8), rgba(255,255,255,0.35)), var(--accent-soft);
          }
          .grand-total-top {
            padding: 6px 12px 2px 12px;
            font-size: 11px; font-weight: 900;
            text-transform: uppercase; letter-spacing: 0.14em;
            color: var(--accent-dark);
          }
          .grand-total-amount {
            padding: 0 12px 6px 12px;
            font-size: 28px; line-height: 1.1; font-weight: 900;
            color: var(--accent-dark); word-break: break-word;
          }

          /* ── Notes section ───────────────────────────────────── */

          .notes-section {
            margin-top: 24px; padding-top: 12px;
            page-break-inside: avoid; break-inside: avoid;
          }
          .notes-title {
            font-size: 12px; font-weight: 600; color: #666;
            margin-bottom: 6px; text-transform: uppercase;
            letter-spacing: 0.5px;
          }
          .notes-text {
            font-size: 13px; color: #222;
            line-height: 1.5; white-space: pre-wrap;
          }

          /* ── Page number ─────────────────────────────────────── */

          .page-number {
            position: absolute;
            bottom: 14mm; right: 18mm;
            font-size: 10px; font-weight: 600;
            color: #545352;
            letter-spacing: 0.04em;
            z-index: 4;
            pointer-events: none;
          }

          /* ── Continuation page tweaks ────────────────────────── */

          .page.continuation .items-wrap:first-child,
          .page.continuation .bottom-grid:first-child,
          .page.continuation .notes-section:first-child {
            margin-top: 0; padding-top: 0;
          }

          /* ── Print / PDF export ──────────────────────────────── */

          @media print {
            body { padding: 0; background: #ffffff; }
            .page {
              margin: 0;
              box-shadow: none;
              height: 297mm;
              overflow: hidden;
            }
          }
        </style>
        </head>
        <body>
        \(pagesHTML)
        </body>
        </html>
        """
    }

    // MARK: - Helpers

    private static func esc(_ t: String) -> String {
        t.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func escBr(_ t: String) -> String {
        let normalized = t.replacingOccurrences(of: "\r\n", with: "\n")
                          .replacingOccurrences(of: "\r", with: "\n")
        return esc(normalized).replacingOccurrences(of: "\n", with: "<br>")
    }

    private static func cur(_ amount: Double, _ code: String) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        f.currencyCode = code.isEmpty ? "USD" : code
        return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}
