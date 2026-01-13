//
//  MainTabView.swift
//  Scanninger
//
//  Created by Yeghishe Grigoryan on 13.01.26.
//

import SwiftUI
import SwiftData
import UIKit

struct MainTabView: View {
    var body: some View {
        TabView {
            InvoicesView()
                .tabItem {
                    Label("Invoices", systemImage: "doc.text")
                }
            
            ClientsView()
                .tabItem {
                    Label("Clients", systemImage: "person.2")
                }
            
            ItemsView()
                .tabItem {
                    Label("Items", systemImage: "list.bullet")
                }
            
            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// MARK: - Invoice Status Enum
enum InvoiceStatus: String, CaseIterable {
    case draft = "Draft"
    case sent = "Sent"
    case paid = "Paid"
    case overdue = "Overdue"
}

// MARK: - Business Profile Model
@Model
final class BusinessProfileModel {
    var name: String
    var address: String
    var phone: String
    var email: String
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, address: String, phone: String, email: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.name = name
        self.address = address
        self.phone = phone
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Invoice Model
@Model
final class InvoiceModel {
    var number: String
    var clientName: String
    var statusRaw: String
    var issueDate: Date
    var dueDate: Date
    var taxPercent: Double
    var createdAt: Date
    
    var business: BusinessProfileModel?
    
    @Relationship(deleteRule: .cascade) var items: [LineItemModel]?
    
    init(number: String, clientName: String, statusRaw: String, issueDate: Date, dueDate: Date, taxPercent: Double, createdAt: Date, business: BusinessProfileModel? = nil, items: [LineItemModel]? = nil) {
        self.number = number
        self.clientName = clientName
        self.statusRaw = statusRaw
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.taxPercent = taxPercent
        self.createdAt = createdAt
        self.business = business
        self.items = items
    }
    
    var status: InvoiceStatus {
        get {
            InvoiceStatus(rawValue: statusRaw) ?? .draft
        }
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    var subtotal: Double {
        (items ?? []).reduce(0) { $0 + $1.total }
    }
    
    var total: Double {
        subtotal + (subtotal * (taxPercent / 100.0))
    }
}

// MARK: - Line Item Model
@Model
final class LineItemModel {
    var title: String
    var qty: Int
    var price: Double
    
    init(title: String, qty: Int, price: Double) {
        self.title = title
        self.qty = qty
        self.price = price
    }
    
    var total: Double {
        Double(qty) * price
    }
}

// MARK: - InvoicesView
struct InvoicesView: View {
    @Query(sort: \InvoiceModel.issueDate, order: .reverse) private var allInvoices: [InvoiceModel]
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchText = ""
    @State private var selectedStatus: InvoiceStatus? = nil
    @State private var showCreateInvoice = false
    @State private var selectedInvoice: InvoiceModel?
    
    private var filteredInvoices: [InvoiceModel] {
        var filtered = allInvoices
        
        // Filter by status
        if let selectedStatus = selectedStatus {
            filtered = filtered.filter { $0.status == selectedStatus }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { invoice in
                invoice.clientName.localizedCaseInsensitiveContains(searchText) ||
                invoice.number.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Status filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterButton(
                            title: "All",
                            isSelected: selectedStatus == nil
                        ) {
                            selectedStatus = nil
                        }
                        
                        ForEach(InvoiceStatus.allCases, id: \.self) { status in
                            FilterButton(
                                title: status.rawValue,
                                isSelected: selectedStatus == status
                            ) {
                                selectedStatus = status
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                
                // Invoices list
                List(filteredInvoices) { invoice in
                    NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                        InvoiceRow(invoice: invoice)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Invoices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateInvoice = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateInvoice) {
                CreateInvoiceView(
                    nextInvoiceNumber: generateNextInvoiceNumber()
                )
            }
        }
    }
    
    private func generateNextInvoiceNumber() -> String {
        let maxNumber = allInvoices.compactMap { invoice -> Int? in
            let components = invoice.number.components(separatedBy: "-")
            if components.count == 2, let number = Int(components[1]) {
                return number
            }
            return nil
        }.max() ?? 0
        
        let nextNumber = maxNumber + 1
        return String(format: "INV-%04d", nextNumber)
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search invoices...", text: $text)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .cornerRadius(20)
        }
    }
}

// MARK: - Invoice Row
struct InvoiceRow: View {
    let invoice: InvoiceModel
    
    private var statusColor: Color {
        switch invoice.status {
        case .draft: return .gray
        case .sent: return .blue
        case .paid: return .green
        case .overdue: return .red
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: invoice.issueDate)
    }
    
    private var formattedAmount: String {
        String(format: "$%.2f", invoice.total)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.number)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(invoice.clientName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(invoice.status.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Create Invoice View
struct CreateInvoiceView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessProfileModel.name) private var businessProfiles: [BusinessProfileModel]
    
    let nextInvoiceNumber: String
    
    @State private var selectedBusiness: BusinessProfileModel?
    @State private var clientName = ""
    @State private var invoiceNumber = ""
    @State private var issueDate = Date()
    @State private var dueDate = Date()
    @State private var lineItems: [LineItemData] = [LineItemData(title: "", qty: 1, price: 0.0)]
    @State private var taxPercent: Double = 0.0
    @State private var showCreateBusinessProfile = false
    
    private var subtotal: Double {
        lineItems.reduce(0) { $0 + (Double($1.qty) * $1.price) }
    }
    
    private var taxAmount: Double {
        subtotal * (taxPercent / 100.0)
    }
    
    private var total: Double {
        subtotal + taxAmount
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Business") {
                    if businessProfiles.isEmpty {
                        VStack(spacing: 12) {
                            Text("No business profiles found. Please create one to continue.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Add Business Profile") {
                                showCreateBusinessProfile = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        Picker("Business Profile", selection: $selectedBusiness) {
                            Text("Select Business").tag(nil as BusinessProfileModel?)
                            ForEach(businessProfiles) { profile in
                                Text(profile.name).tag(profile as BusinessProfileModel?)
                            }
                        }
                    }
                }
                
                Section("Invoice Information") {
                    TextField("Client Name", text: $clientName)
                    TextField("Invoice Number", text: $invoiceNumber)
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
                
                Section("Line Items") {
                    ForEach($lineItems) { $item in
                        LineItemRow(item: $item)
                    }
                    
                    Button(action: {
                        lineItems.append(LineItemData(title: "", qty: 1, price: 0.0))
                    }) {
                        Label("Add Item", systemImage: "plus.circle")
                    }
                }
                
                Section("Totals") {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(String(format: "$%.2f", subtotal))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Tax %")
                        Spacer()
                        TextField("0.0", value: $taxPercent, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "$%.2f", total))
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("New Invoice")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveInvoice()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                invoiceNumber = nextInvoiceNumber
            }
            .sheet(isPresented: $showCreateBusinessProfile) {
                CreateBusinessProfileView()
            }
        }
    }
    
    private var isValid: Bool {
        selectedBusiness != nil &&
        !clientName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !invoiceNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        lineItems.contains { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty && $0.qty > 0 && $0.price > 0 }
    }
    
    private func saveInvoice() {
        let lineItemModels = lineItems.map { item in
            LineItemModel(title: item.title, qty: item.qty, price: item.price)
        }
        
        let invoice = InvoiceModel(
            number: invoiceNumber,
            clientName: clientName,
            statusRaw: InvoiceStatus.draft.rawValue,
            issueDate: issueDate,
            dueDate: dueDate,
            taxPercent: taxPercent,
            createdAt: Date(),
            business: selectedBusiness,
            items: lineItemModels
        )
        
        modelContext.insert(invoice)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save invoice: \(error)")
        }
    }
}

// MARK: - Line Item Data (temporary struct for form)
struct LineItemData: Identifiable {
    let id = UUID()
    var title: String
    var qty: Int
    var price: Double
}

// MARK: - Line Item Row
struct LineItemRow: View {
    @Binding var item: LineItemData
    
    private var itemTotal: Double {
        Double(item.qty) * item.price
    }
    
    var body: some View {
        VStack(spacing: 8) {
            TextField("Description", text: $item.title)
            
            HStack {
                Text("Qty:")
                    .foregroundColor(.secondary)
                TextField("1", value: $item.qty, format: .number)
                    .keyboardType(.numberPad)
                    .frame(width: 60)
                
                Spacer()
                
                Text("Price:")
                    .foregroundColor(.secondary)
                TextField("0.00", value: $item.price, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
            
            HStack {
                Spacer()
                Text("Total: \(String(format: "$%.2f", itemTotal))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Invoice Detail View
struct InvoiceDetailView: View {
    let invoice: InvoiceModel
    
    @State private var shareItem: ShareItem?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    private var formattedIssueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: invoice.issueDate)
    }
    
    private var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: invoice.dueDate)
    }
    
    private var formattedAmount: String {
        String(format: "$%.2f", invoice.total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Business Profile Section
            VStack(alignment: .leading, spacing: 8) {
                if let business = invoice.business {
                    Text(business.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !business.email.isEmpty {
                        Text(business.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if !business.phone.isEmpty {
                        Text(business.phone)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No business selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
            
            Text("Invoice Details")
                .font(.title2)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Invoice Number", value: invoice.number)
                DetailRow(label: "Client Name", value: invoice.clientName)
                DetailRow(label: "Total Amount", value: formattedAmount)
                DetailRow(label: "Status", value: invoice.status.rawValue)
                DetailRow(label: "Issue Date", value: formattedIssueDate)
                DetailRow(label: "Due Date", value: formattedDueDate)
            }
            .padding()
            
            // Share PDF Button
            Button(action: {
                sharePDF()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share PDF")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
        }
        .navigationTitle("Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func sharePDF() {
        do {
            let url = try generateInvoicePDF(invoice: invoice)
            
            // Verify file exists and has content
            guard FileManager.default.fileExists(atPath: url.path) else {
                errorMessage = "PDF file was not created"
                showErrorAlert = true
                return
            }
            
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            if fileSize == 0 {
                errorMessage = "PDF file is empty"
                showErrorAlert = true
                return
            }
            
            shareItem = ShareItem(url: url)
        } catch {
            errorMessage = "Failed to generate PDF: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - PDF Generation
func generateInvoicePDF(invoice: InvoiceModel) throws -> URL {
    let pageSize = CGSize(width: 612, height: 792) // US Letter size
    let margin: CGFloat = 50
    let contentWidth = pageSize.width - (margin * 2)
    
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
    
    let fileName = "Invoice_\(invoice.number.replacingOccurrences(of: " ", with: "_")).pdf"
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    
    let data = renderer.pdfData { context in
        context.beginPage()
        
        var yPosition: CGFloat = margin
        
        // Helper function to draw text
        func drawText(_ text: String, at point: CGPoint, font: UIFont, alignment: NSTextAlignment = .left, width: CGFloat = contentWidth) {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
            
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let textRect = CGRect(x: point.x, y: point.y, width: width, height: font.lineHeight * 2)
            attributedString.draw(in: textRect)
        }
        
        // Top section: Business info (left) and "INVOICE" (right)
        if let business = invoice.business {
            drawText(business.name, at: CGPoint(x: margin, y: yPosition), font: .boldSystemFont(ofSize: 18))
            if !business.address.isEmpty {
                drawText(business.address, at: CGPoint(x: margin, y: yPosition + 22), font: .systemFont(ofSize: 12))
            }
            if !business.phone.isEmpty {
                drawText(business.phone, at: CGPoint(x: margin, y: yPosition + 38), font: .systemFont(ofSize: 12))
            }
            if !business.email.isEmpty {
                drawText(business.email, at: CGPoint(x: margin, y: yPosition + 54), font: .systemFont(ofSize: 12))
            }
        }
        
        drawText("INVOICE", at: CGPoint(x: margin, y: yPosition), font: .boldSystemFont(ofSize: 24), alignment: .right)
        yPosition += 80
        
        // Invoice details
        let detailFont = UIFont.systemFont(ofSize: 12)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        drawText("Invoice Number: \(invoice.number)", at: CGPoint(x: margin, y: yPosition), font: detailFont)
        yPosition += 20
        
        drawText("Issue Date: \(dateFormatter.string(from: invoice.issueDate))", at: CGPoint(x: margin, y: yPosition), font: detailFont)
        yPosition += 20
        
        drawText("Due Date: \(dateFormatter.string(from: invoice.dueDate))", at: CGPoint(x: margin, y: yPosition), font: detailFont)
        yPosition += 30
        
        // Bill To section
        drawText("Bill To:", at: CGPoint(x: margin, y: yPosition), font: .boldSystemFont(ofSize: 14))
        yPosition += 20
        drawText(invoice.clientName, at: CGPoint(x: margin, y: yPosition), font: detailFont)
        yPosition += 40
        
        // Items table header
        let headerFont = UIFont.boldSystemFont(ofSize: 12)
        let itemColumnWidth = contentWidth * 0.4
        let qtyColumnWidth = contentWidth * 0.15
        let priceColumnWidth = contentWidth * 0.2
        let totalColumnWidth = contentWidth * 0.25
        
        drawText("Item", at: CGPoint(x: margin, y: yPosition), font: headerFont, width: itemColumnWidth)
        drawText("Qty", at: CGPoint(x: margin + itemColumnWidth, y: yPosition), font: headerFont, width: qtyColumnWidth)
        drawText("Price", at: CGPoint(x: margin + itemColumnWidth + qtyColumnWidth, y: yPosition), font: headerFont, width: priceColumnWidth)
        drawText("Total", at: CGPoint(x: margin + itemColumnWidth + qtyColumnWidth + priceColumnWidth, y: yPosition), font: headerFont, width: totalColumnWidth)
        yPosition += 25
        
        // Draw line under header
        context.cgContext.move(to: CGPoint(x: margin, y: yPosition))
        context.cgContext.addLine(to: CGPoint(x: margin + contentWidth, y: yPosition))
        context.cgContext.strokePath()
        yPosition += 10
        
        // Items list
        let items = invoice.items ?? []
        for item in items {
            let itemTotal = Double(item.qty) * item.price
            drawText(item.title, at: CGPoint(x: margin, y: yPosition), font: detailFont, width: itemColumnWidth)
            drawText("\(item.qty)", at: CGPoint(x: margin + itemColumnWidth, y: yPosition), font: detailFont, width: qtyColumnWidth)
            drawText(String(format: "$%.2f", item.price), at: CGPoint(x: margin + itemColumnWidth + qtyColumnWidth, y: yPosition), font: detailFont, width: priceColumnWidth)
            drawText(String(format: "$%.2f", itemTotal), at: CGPoint(x: margin + itemColumnWidth + qtyColumnWidth + priceColumnWidth, y: yPosition), font: detailFont, width: totalColumnWidth)
            yPosition += 20
        }
        
        yPosition += 20
        
        // Totals section
        let totalsY = yPosition
        let totalsStartX = margin + itemColumnWidth + qtyColumnWidth
        let totalsWidth = priceColumnWidth + totalColumnWidth
        let labelWidth = totalsWidth * 0.6
        let valueWidth = totalsWidth * 0.4
        
        drawText("Subtotal:", at: CGPoint(x: totalsStartX, y: totalsY), font: detailFont, alignment: .right, width: labelWidth)
        drawText(String(format: "$%.2f", invoice.subtotal), at: CGPoint(x: totalsStartX + labelWidth, y: totalsY), font: detailFont, alignment: .right, width: valueWidth)
        yPosition += 20
        
        drawText("Tax (\(String(format: "%.1f", invoice.taxPercent))%):", at: CGPoint(x: totalsStartX, y: yPosition), font: detailFont, alignment: .right, width: labelWidth)
        let taxAmount = invoice.subtotal * (invoice.taxPercent / 100.0)
        drawText(String(format: "$%.2f", taxAmount), at: CGPoint(x: totalsStartX + labelWidth, y: yPosition), font: detailFont, alignment: .right, width: valueWidth)
        yPosition += 20
        
        drawText("Total:", at: CGPoint(x: totalsStartX, y: yPosition), font: .boldSystemFont(ofSize: 14), alignment: .right, width: labelWidth)
        drawText(String(format: "$%.2f", invoice.total), at: CGPoint(x: totalsStartX + labelWidth, y: yPosition), font: .boldSystemFont(ofSize: 14), alignment: .right, width: valueWidth)
        yPosition += 30
        
        // Status
        drawText("Status: \(invoice.status.rawValue)", at: CGPoint(x: margin, y: yPosition), font: .boldSystemFont(ofSize: 12))
    }
    
    // Remove existing file if it exists
    if FileManager.default.fileExists(atPath: fileURL.path) {
        try FileManager.default.removeItem(at: fileURL)
    }
    
    try data.write(to: fileURL, options: .atomic)
    
    // Verify the file was written successfully and has content
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        throw NSError(domain: "PDFGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to write PDF file"])
    }
    
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
    guard fileSize > 0 else {
        throw NSError(domain: "PDFGeneration", code: 2, userInfo: [NSLocalizedDescriptionKey: "PDF file is empty"])
    }
    
    return fileURL
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Configure for iPad
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}


// MARK: - Create Business Profile View
struct CreateBusinessProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var email = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Business Information") {
                    TextField("Business Name", text: $name)
                    TextField("Address", text: $address)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("New Business Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBusinessProfile()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveBusinessProfile() {
        let business = BusinessProfileModel(
            name: name,
            address: address,
            phone: phone,
            email: email,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        modelContext.insert(business)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save business profile: \(error)")
        }
    }
}

// MARK: - Edit Business Profile View
struct EditBusinessProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let business: BusinessProfileModel
    
    @State private var name: String
    @State private var address: String
    @State private var phone: String
    @State private var email: String
    
    init(business: BusinessProfileModel) {
        self.business = business
        _name = State(initialValue: business.name)
        _address = State(initialValue: business.address)
        _phone = State(initialValue: business.phone)
        _email = State(initialValue: business.email)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Business Information") {
                    TextField("Business Name", text: $name)
                    TextField("Address", text: $address)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Edit Business Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBusinessProfile()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveBusinessProfile() {
        business.name = name
        business.address = address
        business.phone = phone
        business.email = email
        business.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save business profile: \(error)")
        }
    }
}

struct ClientsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Clients")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Clients")
        }
    }
}

struct ItemsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Items")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Items")
        }
    }
}

struct ReportsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Reports")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Reports")
        }
    }
}

// MARK: - Business Profiles View (replaces Settings)
struct SettingsView: View {
    @Query(sort: \BusinessProfileModel.name) private var businessProfiles: [BusinessProfileModel]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showCreateBusinessProfile = false
    @State private var selectedBusiness: BusinessProfileModel?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(businessProfiles) { profile in
                    NavigationLink(destination: EditBusinessProfileView(business: profile)) {
                        BusinessProfileRow(profile: profile)
                    }
                }
                .onDelete(perform: deleteBusinessProfiles)
            }
            .navigationTitle("Business Profiles")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateBusinessProfile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateBusinessProfile) {
                CreateBusinessProfileView()
            }
        }
    }
    
    private func deleteBusinessProfiles(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(businessProfiles[index])
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete business profile: \(error)")
        }
    }
}

// MARK: - Business Profile Row
struct BusinessProfileRow: View {
    let profile: BusinessProfileModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            if !profile.email.isEmpty {
                Text(profile.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if !profile.phone.isEmpty {
                Text(profile.phone)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MainTabView()
}
