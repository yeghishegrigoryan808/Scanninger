import Foundation

// MARK: - Classic Paginated Invoice Engine
//
// Replicates the exact visual design of the Classic template (invoice_template_classic_03)
// but renders multiple pages using the same deterministic pagination approach as
// PaginationTestInvoiceEngine and ElegantPaginatedInvoiceEngine.
//
// Pagination behaviour (matches the other paginated templates):
//   • Header (top-row + parties) appears ONLY on the first page
//   • Continuation pages have NO header — only items / totals / notes
//   • Table header repeats on every page that contains item rows
//   • Totals appear only on the last page
//   • Page numbers appear bottom-right on every page

enum ClassicPaginatedInvoiceEngine {

    // MARK: - Page Metrics (derived from Classic template CSS values)

    private enum M {
        static let pageHeightMm: Double = 297.0
        static let safetyMm: Double = 3.0

        /// Real reserved footer block height (page number lives here).
        static let footerHeightMm: Double = 12.0

        /// Extra clearance required below an item row before accepting it on the current page.
        static let rowFitBufferMm: Double = 3.0

        static let notesFitBufferMm: Double = 0.0
        static let trailingFitSlackMm: Double = 24.0
        static let continuationRowFitSlackMm: Double = 6.0
        static let continuationRowGuardMm: Double = 8.0

        /// Recovery for first-page header/parties overestimation when placing the first table block.
        static let firstPageTableStartSlackMm: Double = 14.0

        /// Moderately conservative CSS-px → mm conversion (same as elegant paginated).
        static let pxMm: Double = 25.4 / 90.0

        /// `.inner` padding — top 18mm, bottom 20mm.
        /// The subtle accent bar (5px) is position:absolute so it does NOT reduce flow space.
        static let innerPaddingTopMm: Double = 18.0
        static let innerPaddingBottomMm: Double = 20.0

        /// Usable content height inside `.page-inner` per page.
        static var usableHeight: Double {
            pageHeightMm - innerPaddingTopMm - innerPaddingBottomMm - footerHeightMm - safetyMm
        }

        // -- Top row (invoice title + invoice box) ----------------------------
        // invoice-title: 42px
        static var titleMm: Double { 42.0 * pxMm }
        // top-row CSS margin-bottom
        static let topRowGapMm: Double = 14.0
        // invoice-box row: min-height 38px + 2px border = 40px per row
        static var invoiceBoxRowMm: Double { 40.0 * pxMm }
        // invoice-box top/bottom border chrome: 2+2 = 4px
        static var invoiceBoxBorderMm: Double { 4.0 * pxMm }

        // -- Party row (From + Billed To) -------------------------------------
        // party-label 14px + mb10, party-name 16px + mb8
        static var partyChromeMm: Double { (14.0 + 10.0 + 16.0 + 8.0) * pxMm }
        // party-lines: 13px font, line-height 1.6
        static var partyLineMm: Double { 13.0 * 1.6 * pxMm }
        // party-row margin-bottom
        static let partyRowGapMm: Double = 12.0
        // -- Items table ------------------------------------------------------
        // thead th: padding 10+10 = 20px chrome + font ~13px
        static var tableHeaderMm: Double { (20.0 + 13.0) * pxMm }
        // tbody td: padding + 2px borders; title vs detail lines split (matches .item-title / .item-desc).
        static var itemRowChromeMm: Double { 33.0 * pxMm }
        static var titleLineMm: Double { 13.0 * 1.25 * pxMm }
        static var detailLineMm: Double { 12.5 * 1.55 * pxMm }
        static var bodyLineMm: Double { titleLineMm }

        // -- Totals table -----------------------------------------------------
        // Gap before totals = items-wrap margin-bottom
        static let totalsGapMm: Double = 6.0
        // totals-table: 3 rows × (8+13+8+2)px + grand row (8+18+8+2)px
        static var totalsContentMm: Double {
            let normalRow = 31.0 * pxMm    // padding 8+8, font 13, border 2
            let grandRow  = 36.0 * pxMm    // padding 8+8, font 18, border 2
            return 2.0 * normalRow + grandRow + 4.0 * pxMm // extra border chrome
        }

        // -- Notes ------------------------------------------------------------
        static var notesSamePageChromeMm: Double { 36.0 * pxMm }
        static var notesNewPageChromeMm: Double  { 12.0 * pxMm }
        static var notesLineMm: Double { 13.0 * 1.5 * pxMm }

        static let notesCharsPerLine: Double = 104.0
        static let charsPerLine: Double = 52.0
    }

    // MARK: - Public API

    static func render(invoice: InvoiceModel, theme: InvoiceColorTheme) -> String {
        let result = paginate(invoice: invoice)
        return buildHTML(result: result, invoice: invoice, theme: theme)
    }

    // MARK: - Pagination (same algorithm as the other paginated templates)

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
                print("[ClassicPag] COMMIT pg\(wkIdx): hdr=\(wkHeader) parties=\(wkParties) items=\(wkItems.count) totals=\(wkTotals) notes=\(wkNotes) y=\(f(currentY))")
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
            wkHeader  = false
            wkParties = false
            wkItems   = []
            wkTotals  = false
            wkNotes   = false
            currentY  = 0
            print("[ClassicPag] NEW pg\(wkIdx) currentY=0")
        }

        // ── 1. Header ──
        currentY += headerH
        print("[ClassicPag] pg\(wkIdx) HEADER h=\(f(headerH)) y=\(f(currentY))")

        // ── 2. Parties (first page only) ──
        wkParties = true
        currentY += partiesH
        print("[ClassicPag] pg\(wkIdx) PARTIES h=\(f(partiesH)) y=\(f(currentY))")

        // ── 3. Items ──
        let thH = M.tableHeaderMm

        for (i, item) in allItems.enumerated() {
            let rowH = estimateItemRowHeight(item: item)
            let firstOnPage = wkItems.isEmpty
            let need = firstOnPage ? (thH + rowH) : rowH

            let isContinuationPage = !wkFirst && !wkHeader && !wkParties
            let rowSlack = isContinuationPage ? M.continuationRowFitSlackMm : 0.0
            let rowGuard = isContinuationPage ? M.continuationRowGuardMm : 0.0
            let firstPageStartSlack = (wkFirst && firstOnPage) ? M.firstPageTableStartSlackMm : 0.0

            if currentY + need + M.rowFitBufferMm <= limit + rowSlack + firstPageStartSlack - rowGuard {
                if firstOnPage {
                    currentY += thH
                    print("[ClassicPag] pg\(wkIdx) TBL_HDR h=\(f(thH)) y=\(f(currentY))")
                }
                wkItems.append(item)
                currentY += rowH
                print("[ClassicPag] pg\(wkIdx) ITEM[\(i)] h=\(f(rowH)) y=\(f(currentY)) fit=YES")
            } else {
                print("[ClassicPag] pg\(wkIdx) ITEM[\(i)] need=\(f(need + M.rowFitBufferMm)) avail=\(f(limit + rowSlack + firstPageStartSlack - rowGuard - currentY)) slack=\(f(rowSlack)) firstPageStartSlack=\(f(firstPageStartSlack)) guard=\(f(rowGuard)) → new page")
                nextPage()
                currentY += thH
                print("[ClassicPag] pg\(wkIdx) TBL_HDR h=\(f(thH)) y=\(f(currentY))")
                wkItems.append(item)
                currentY += rowH
                print("[ClassicPag] pg\(wkIdx) ITEM[\(i)] h=\(f(rowH)) y=\(f(currentY))")
            }
        }

        // ── 4. Totals ──
        let totalsWithGap = M.totalsGapMm + M.totalsContentMm
        let totalsAlone   = M.totalsContentMm
        let trailingSlack = (wkHeader || wkParties || !wkItems.isEmpty) ? M.trailingFitSlackMm : 0.0

        print("[ClassicPag] pg\(wkIdx) TOTALS? need=\(f(totalsWithGap)) avail=\(f(limit + trailingSlack - currentY)) slack=\(f(trailingSlack))")
        if currentY + totalsWithGap <= limit + trailingSlack {
            wkTotals  = true
            currentY += totalsWithGap
            print("[ClassicPag] pg\(wkIdx) TOTALS fit=YES y=\(f(currentY))")
        } else {
            print("[ClassicPag] pg\(wkIdx) TOTALS fit=NO → new page")
            nextPage()
            wkTotals  = true
            currentY += totalsAlone
            print("[ClassicPag] pg\(wkIdx) TOTALS h=\(f(totalsAlone)) y=\(f(currentY))")
        }

        // ── 5. Notes ──
        if hasNotes {
            let notesSame  = estimateNotesHeight(invoice.additionalNotes, isFirstChild: false)
            let notesAlone = estimateNotesHeight(invoice.additionalNotes, isFirstChild: true)
            let notesNeed  = notesSame + M.notesFitBufferMm
            let notesSlack = (wkHeader || wkParties || !wkItems.isEmpty) ? M.trailingFitSlackMm : 0.0

            print("[ClassicPag] pg\(wkIdx) NOTES? need=\(f(notesNeed)) avail=\(f(limit + notesSlack - currentY)) slack=\(f(notesSlack))")
            if currentY + notesNeed <= limit + notesSlack {
                wkNotes   = true
                currentY += notesSame
                print("[ClassicPag] pg\(wkIdx) NOTES fit=YES y=\(f(currentY))")
            } else {
                print("[ClassicPag] pg\(wkIdx) NOTES fit=NO → new page")
                nextPage()
                wkNotes   = true
                currentY += notesAlone
                print("[ClassicPag] pg\(wkIdx) NOTES h=\(f(notesAlone)) y=\(f(currentY))")
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

        print("[ClassicPag] RESULT: \(pages.count) page(s), usable=\(f(limit))mm")
        for (i, pg) in pages.enumerated() {
            print("[ClassicPag]   pg\(i): hdr=\(pg.showHeader) parties=\(pg.showParties) items=\(pg.itemRows.count) totals=\(pg.showTotals) notes=\(pg.showNotes) first=\(pg.isFirstPage) last=\(pg.isLastPage)")
        }
        return PaginationTestResult(pages: pages)
    }

    // MARK: - Height Estimates

    private static func estimateHeaderHeight(invoice: InvoiceModel) -> Double {
        // The top-row is a CSS grid: left = invoice title, right = invoice-box.
        // Height = max(title, box) + margin-bottom.
        let titleH = M.titleMm
        let boxRows: Double = (invoice.periodStart != nil && invoice.periodEnd != nil) ? 3.0 : 2.0
        let boxH = boxRows * M.invoiceBoxRowMm + M.invoiceBoxBorderMm
        return max(titleH, boxH) + M.topRowGapMm
    }

    private static func estimatePartiesHeight(invoice: InvoiceModel) -> Double {
        let fromLines = estimatedLines(invoice.businessAddress, minimum: 0)
            + estimatedLines(invoice.businessEmail, minimum: 0)
            + estimatedLines(invoice.businessPhone, minimum: 0)
            + estimatedLines(invoice.businessTaxId, minimum: 0)
        let leftH = M.partyChromeMm + fromLines * M.partyLineMm

        let clientLines = estimatedLines(invoice.clientAddress, minimum: 0)
            + estimatedLines(invoice.clientEmail, minimum: 0)
            + estimatedLines(invoice.clientPhone, minimum: 0)
            + estimatedLines(invoice.clientTaxId, minimum: 0)
        let rightH = M.partyChromeMm + clientLines * M.partyLineMm

        return max(leftH, rightH) + M.partyRowGapMm
    }

    private static func estimateItemRowHeight(item: LineItemModel) -> Double {
        let titleLines = estimatedLines(item.title, minimum: 1)
        let detailLines = estimatedLines(item.details, minimum: 0)
        return M.itemRowChromeMm
            + titleLines * M.titleLineMm
            + detailLines * M.detailLineMm
    }

    private static func estimateNotesHeight(_ notes: String, isFirstChild: Bool) -> Double {
        let lines  = estimatedNotesLines(notes, minimum: 1)
        let chrome = isFirstChild ? M.notesNewPageChromeMm : M.notesSamePageChromeMm
        return chrome + lines * M.notesLineMm
    }

    private static func estimatedNotesLines(_ text: String, minimum: Double) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return minimum }
        return max(minimum, trimmed.components(separatedBy: "\n").reduce(0.0) { sum, line in
            sum + max(1, ceil(Double(max(line.count, 1)) / M.notesCharsPerLine))
        })
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
                sections += topRowHTML(invoice: invoice, invoiceDate: invoiceDate)
            }
            if page.showParties {
                sections += partyRowHTML(invoice: invoice)
            }
            if !page.itemRows.isEmpty {
                sections += itemsTableHTML(items: page.itemRows, cc: cc)
            }
            if page.showTotals {
                sections += totalsHTML(sub: sub, taxAmount: taxAmount, tax: tax, tot: tot, theme: theme)
            }
            if page.showNotes {
                sections += notesHTML(invoice: invoice)
            }

            let cls = page.isFirstPage ? "page" : "page continuation"
            let pageNum = page.pageIndex + 1
            return """
            <div class="\(cls)">
              <div class="subtle-accent"></div>
              <div class="page-inner">
                <div class="inner">\(sections)</div>
              </div>
              <div class="page-footer">Page \(pageNum) of \(totalPages)</div>
            </div>
            """
        }.joined(separator: "\n")

        return fullDocument(pagesHTML: pagesHTML, theme: theme)
    }

    // MARK: - Section Builders

    private static func topRowHTML(invoice: InvoiceModel, invoiceDate: String) -> String {
        var periodRow = ""
        if let s = invoice.periodStart, let e = invoice.periodEnd {
            let pf = DateFormatter(); pf.dateFormat = "MMM d, yyyy"
            periodRow = """
            <div class="row-divider"></div>
            <div class="label-cell">Period</div>
            <div class="value-cell">\(esc("\(pf.string(from: s)) – \(pf.string(from: e))"))</div>
            """
        }

        return """
        <div class="top-row">
          <div>
            <h1 class="invoice-title">Invoice</h1>
          </div>
          <div class="invoice-box">
            <div class="label-cell">Invoice No.</div>
            <div class="value-cell">\(esc(invoice.number))</div>
            <div class="row-divider"></div>
            <div class="label-cell">Date</div>
            <div class="value-cell">\(esc(invoiceDate))</div>
            \(periodRow)
          </div>
        </div>
        """
    }

    private static func partyRowHTML(invoice: InvoiceModel) -> String {
        return """
        <div class="party-row">
          <div class="party-section">
            <div class="party-label">From :</div>
            <div class="party-name">\(esc(invoice.businessName))</div>
            <div class="party-lines">\(buildContactLines(
                address: invoice.businessAddress,
                email: invoice.businessEmail,
                phone: invoice.businessPhone,
                taxId: invoice.businessTaxId
            ))</div>
          </div>
          <div class="party-section">
            <div class="party-label">Billed To :</div>
            <div class="party-name">\(esc(invoice.clientName))</div>
            <div class="party-lines">\(buildContactLines(
                address: invoice.clientAddress,
                email: invoice.clientEmail,
                phone: invoice.clientPhone,
                taxId: invoice.clientTaxId
            ))</div>
          </div>
        </div>
        """
    }

    private static func buildContactLines(address: String, email: String, phone: String, taxId: String) -> String {
        var parts: [String] = []
        let addr = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr.isEmpty { parts.append(escBr(addr)) }
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !e.isEmpty { parts.append(esc(e)) }
        let p = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { parts.append(esc(p)) }
        let t = taxId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { parts.append("Tax ID: \(esc(t))") }
        return parts.map { "<div class=\"party-line\">\($0)</div>" }.joined(separator: "\n")
    }

    private static func itemsTableHTML(items: [LineItemModel], cc: String) -> String {
        let rows = items.map { item -> String in
            var descCell = "<div class=\"item-title\">\(esc(item.title))</div>"
            let desc = item.details.trimmingCharacters(in: .whitespacesAndNewlines)
            if !desc.isEmpty {
                descCell += "<div class=\"item-desc\">\(esc(desc))</div>"
            }
            return """
            <tr>
              <td>\(descCell)</td>
              <td class="num">\(cur(item.price, cc))</td>
              <td class="num">\(item.qty) \(esc(item.unit))</td>
              <td class="num">\(cur(item.total, cc))</td>
            </tr>
            """
        }.joined(separator: "\n")

        return """
        <div class="items-wrap">
          <table class="invoice-table">
            <thead>
              <tr>
                <th class="col-description">Description</th>
                <th class="col-rate">Unit Price</th>
                <th class="col-qty">Qty.</th>
                <th class="col-amount">Amount</th>
              </tr>
            </thead>
            <tbody>
              \(rows)
            </tbody>
          </table>
        </div>
        """
    }

    private static func totalsHTML(sub: String, taxAmount: Double, tax: String, tot: String, theme: InvoiceColorTheme) -> String {
        let taxRow = taxAmount > 0
            ? "<tr><td class=\"label\">Tax</td><td class=\"value\">\(esc(tax))</td></tr>"
            : ""

        return """
        <div class="totals-wrap">
          <table class="totals-table">
            <tbody>
              <tr>
                <td class="label">Sub Total</td>
                <td class="value">\(esc(sub))</td>
              </tr>
              \(taxRow)
              <tr>
                <td class="label grand-label">Total Amount</td>
                <td class="value grand-value">\(esc(tot))</td>
              </tr>
            </tbody>
          </table>
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
            --ink: #1f2937;
            --muted: #6b7280;
            --paper: #ffffff;
            --line: #2f2f2f;
            --soft-line: #cfcfcf;
            --sheet-bg: #efefef;
          }

          /* Force background colors in print / PDF export */
          *, *::before, *::after {
            -webkit-print-color-adjust: exact !important;
            print-color-adjust: exact !important;
          }

          * { box-sizing: border-box; }

          html, body {
            margin: 0; padding: 0;
            background: var(--sheet-bg);
            font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
            color: var(--ink);
          }

          @page { size: A4; margin: 0; }

          body { padding: 20px; }

          /* ── Page container ─────────────────────────────────── */

          .page {
            width: 210mm;
            height: 297mm;
            margin: 0 auto 24px auto;
            background: var(--paper);
            box-shadow: 0 10px 30px rgba(0,0,0,0.08);
            position: relative;
            overflow: hidden;
            border: 1px solid #d9d9d9;
            display: flex;
            flex-direction: column;
            page-break-after: always;
            break-after: page;
          }
          .page:last-child {
            page-break-after: auto;
            break-after: auto;
            margin-bottom: 0;
          }

          /* ── Decorative accent ──────────────────────────────── */

          .subtle-accent {
            position: absolute;
            top: 0; left: 0;
            width: 100%; height: 5px;
            background: linear-gradient(90deg, var(--accent-dark), var(--accent), var(--accent-soft));
            opacity: 0.85;
            z-index: 3;
          }

          /* ── Page-inner (flex child that holds content) ───────── */

          .page-inner {
            flex: 1;
            overflow: hidden;
            position: relative;
            z-index: 2;
          }

          /* ── Page-footer (reserved footer block for page number) ── */

          .page-footer {
            flex-shrink: 0;
            height: \(String(format: "%.0fmm", M.footerHeightMm));
            display: flex;
            align-items: center;
            justify-content: flex-end;
            padding: 0 18mm;
            font-size: 12px;
            font-weight: 600;
            color: #a1a09d;
            letter-spacing: 0.04em;
            z-index: 4;
          }

          /* ── Inner content area ─────────────────────────────── */

          .inner {
            padding: 18mm 16mm 20mm 16mm;
          }

          /* ── Top row (title + invoice box) ──────────────────── */

          .top-row {
            display: grid;
            grid-template-columns: 1fr 90mm;
            gap: 14mm;
            align-items: start;
            margin-bottom: 14mm;
          }

          .invoice-title {
            font-size: 42px;
            line-height: 1;
            letter-spacing: 0.02em;
            font-weight: 300;
            text-transform: uppercase;
            color: #111111;
            margin: 0;
          }

          .invoice-box {
            border: 2px solid var(--line);
            display: grid;
            grid-template-columns: 35% 65%;
          }

          .invoice-box .label-cell,
          .invoice-box .value-cell {
            min-height: 38px;
            display: flex;
            align-items: center;
            padding: 8px 10px;
            font-size: 13px;
          }

          .invoice-box .label-cell {
            border-right: 2px solid var(--line);
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            justify-content: flex-start;
            text-align: left;
          }

          .invoice-box .value-cell {
            justify-content: flex-start;
            font-weight: 600;
            white-space: normal;
            overflow-wrap: break-word;
            word-break: break-word;
          }

          .invoice-box .row-divider {
            grid-column: 1 / -1;
            height: 0;
            border-top: 2px solid var(--line);
          }

          /* ── Party row (From + Billed To) ───────────────────── */

          .party-row {
            display: grid;
            grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
            gap: 14mm;
            margin-bottom: 12mm;
            align-items: start;
          }

          .party-section {
            min-width: 0;
            max-width: 100%;
            min-height: 80px;
          }

          .party-label {
            font-size: 14px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            margin-bottom: 10px;
            color: #111111;
          }

          .party-name {
            font-size: 16px;
            font-weight: 800;
            margin-bottom: 8px;
            max-width: 100%;
            overflow-wrap: break-word;
            word-break: break-word;
          }

          .party-lines {
            display: flex;
            flex-direction: column;
            gap: 0.35em;
            font-size: 13px;
            line-height: 1.6;
            color: #374151;
            min-width: 0;
            max-width: 100%;
          }

          .party-line {
            display: block;
            width: 100%;
            max-width: 100%;
            overflow-wrap: break-word;
            word-break: break-word;
          }

          /* ── Items table ────────────────────────────────────── */

          .items-wrap {
            margin-bottom: 6mm;
          }

          table.invoice-table {
            width: 100%;
            border-collapse: collapse;
            table-layout: fixed;
            border: 2px solid var(--line);
          }

          table.invoice-table th,
          table.invoice-table td {
            border: 2px solid var(--line);
            vertical-align: top;
          }

          table.invoice-table th {
            padding: 10px 8px;
            font-size: 13px;
            font-weight: 700;
            text-align: center;
            background: linear-gradient(180deg, rgba(0,0,0,0.02), rgba(0,0,0,0));
          }

          table.invoice-table td {
            padding: 10px 8px;
            font-size: 13px;
          }

          .col-description { width: 48%; }
          .col-rate { width: 16%; }
          .col-qty { width: 16%; }
          .col-amount { width: 20%; }

          .item-title {
            font-weight: 800;
            margin-bottom: 4px;
            color: #111111;
            line-height: 1.25;
          }

          .item-desc {
            display: block;
            font-size: 12.5px;
            line-height: 1.55;
            color: var(--muted);
            white-space: pre-line;
            overflow-wrap: break-word;
            word-break: break-word;
          }

          table.invoice-table td:first-child {
            min-width: 0;
          }

          .num {
            text-align: right;
            white-space: nowrap;
          }

          /* ── Totals table ───────────────────────────────────── */

          .totals-wrap {
            display: flex;
            justify-content: flex-end;
          }

          .totals-table {
            width: 86mm;
            border-collapse: collapse;
            border: 2px solid var(--line);
          }

          .totals-table td {
            border: 2px solid var(--line);
            padding: 8px 10px;
            font-size: 13px;
          }

          .totals-table .label {
            text-align: center;
            font-weight: 700;
          }

          .totals-table .value {
            text-align: right;
            font-weight: 700;
            white-space: nowrap;
          }

          .totals-table .grand-label {
            font-size: 15px;
            font-weight: 800;
          }

          .totals-table .grand-value {
            font-size: 18px;
            font-weight: 900;
            color: var(--accent-dark);
            background: linear-gradient(90deg, rgba(0,0,0,0.01), rgba(0,0,0,0));
          }

          /* ── Notes section ──────────────────────────────────── */

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

          /* ── Continuation page tweaks ───────────────────────── */

          .page.continuation .items-wrap:first-child,
          .page.continuation .totals-wrap:first-child,
          .page.continuation .notes-section:first-child {
            margin-top: 0; padding-top: 0;
          }

          /* ── Print / PDF export ─────────────────────────────── */

          @media print {
            body { padding: 0; background: #ffffff; }
            .page {
              margin: 0;
              box-shadow: none;
              border: none;
              height: 297mm;
              overflow: hidden;
              display: flex;
              flex-direction: column;
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
