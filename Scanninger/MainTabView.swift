//
//  MainTabView.swift
//  Scanninger
//
//  Created by Yeghishe Grigoryan on 13.01.26.
//

import SwiftUI
import SwiftData
import UIKit
import PDFKit
import PhotosUI
import Charts
import WebKit

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
            
            BusinessProfilesView()
                .tabItem {
                    Label("My Business", systemImage: "building.2")
                }
            
            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar")
                }
            
            ProfileView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

// MARK: - Shared empty state

/// Consistent icon + title + subtitle for list tabs (Invoices, Clients, My Business, Reports).
private struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.secondary.opacity(0.9))
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

// MARK: - Floating add (FAB)

private struct FloatingAddButton: View {
    let action: () -> Void
    @State private var appeared = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.blue))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(FloatingAddButtonPressStyle())
        .scaleEffect(appeared ? 1 : 0.88)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.28), value: appeared)
        .onAppear { appeared = true }
        .accessibilityIdentifier("fab.add")
    }
}

private struct FloatingAddButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Profile form multi-line address

/// UIKit-backed growing multiline address; see `GrowingTextView`.
private struct ProfileFormAddressEditor: View {
    let placeholder: String
    @Binding var text: String

    @State private var fieldHeight: CGFloat = 36

    var body: some View {
        GrowingTextView(text: $text, placeholder: placeholder, measuredHeight: $fieldHeight)
            .frame(height: fieldHeight)
    }
}

// MARK: - Invoice form additional notes (multiline)

/// Same `GrowingTextView` stack as profile Address: true newlines, paste preserves breaks, height grows with content.
/// Taller min height than Address so the long placeholder can wrap without clipping.
private struct InvoiceAdditionalNotesEditor: View {
    @Binding var text: String

    /// ~3 body lines + `GrowingTextView` vertical insets — enough for the full placeholder on typical widths.
    private static let notesMinHeight: CGFloat = 96

    @State private var fieldHeight: CGFloat = notesMinHeight

    private let placeholder = "Add payment details, bank info, or other notes"

    var body: some View {
        GrowingTextView(text: $text, placeholder: placeholder, minHeight: Self.notesMinHeight, maxHeight: 320, measuredHeight: $fieldHeight)
            .frame(height: fieldHeight)
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
    var id: UUID
    var name: String
    var address: String
    var phone: String
    var email: String
    var taxId: String
    var isArchived: Bool
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var logoData: Data?
    
    init(id: UUID = UUID(), name: String, address: String, phone: String, email: String, taxId: String = "", isArchived: Bool = false, archivedAt: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), logoData: Data? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.phone = phone
        self.email = email
        self.taxId = taxId
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.logoData = logoData
    }
}

// MARK: - Client Model
@Model
final class ClientModel {
    var id: UUID
    var name: String
    var address: String
    var phone: String
    var email: String
    var taxId: String
    var logoData: Data?
    var isArchived: Bool
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), name: String, address: String = "", phone: String = "", email: String = "", taxId: String = "", logoData: Data? = nil, isArchived: Bool = false, archivedAt: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.address = address
        self.phone = phone
        self.email = email
        self.taxId = taxId
        self.logoData = logoData
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Invoice Model
@Model
final class InvoiceModel {
    var id: UUID
    var number: String
    var clientName: String
    var statusRaw: String
    var issueDate: Date
    var dueDate: Date
    var taxPercent: Double
    var currencyCode: String
    var createdAt: Date
    var updatedAt: Date
    var paidAt: Date?
    var periodStart: Date?
    var periodEnd: Date?
    var businessProfileId: UUID?
    var clientProfileId: UUID?
    
    // Design preferences (optional for migration compatibility)
    var templateRaw: String?
    var themeRaw: String?
    
    /// Optional free-text shown on forms only until PDF integration (e.g. payment / bank instructions).
    var additionalNotes: String
    
    // Client snapshot fields (stored on invoice)
    var clientAddress: String
    var clientPhone: String
    var clientEmail: String
    var clientTaxId: String
    
    // Business snapshot fields (stored on invoice)
    var businessName: String
    var businessAddress: String
    var businessPhone: String
    var businessEmail: String
    var businessTaxId: String
    var businessLogoData: Data?
    
    // Optional relationship (no annotations - manually managed)
    var businessProfile: BusinessProfileModel?
    var clientRef: ClientModel?
    
    @Relationship(deleteRule: .cascade) var items: [LineItemModel]?
    
    init(id: UUID = UUID(), number: String, clientName: String, statusRaw: String, issueDate: Date, dueDate: Date, taxPercent: Double, createdAt: Date, updatedAt: Date = Date(), businessProfileId: UUID? = nil, clientProfileId: UUID? = nil, business: BusinessProfileModel? = nil, items: [LineItemModel]? = nil, paidAt: Date? = nil, currencyCode: String = "USD", clientAddress: String = "", clientPhone: String = "", clientEmail: String = "", clientTaxId: String = "", businessName: String = "", businessAddress: String = "", businessPhone: String = "", businessEmail: String = "", businessTaxId: String = "", businessLogoData: Data? = nil, periodStart: Date? = nil, periodEnd: Date? = nil, templateRaw: String? = nil, themeRaw: String? = nil, additionalNotes: String = "") {
        self.id = id
        self.number = number
        self.clientName = clientName
        self.statusRaw = statusRaw
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.taxPercent = taxPercent
        self.currencyCode = currencyCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.businessProfileId = businessProfileId
        self.clientProfileId = clientProfileId
        self.businessProfile = business
        self.items = items
        self.paidAt = paidAt
        self.clientAddress = clientAddress
        self.clientPhone = clientPhone
        self.clientEmail = clientEmail
        self.clientTaxId = clientTaxId
        self.businessName = businessName
        self.businessAddress = businessAddress
        self.businessPhone = businessPhone
        self.businessEmail = businessEmail
        self.businessTaxId = businessTaxId
        self.businessLogoData = businessLogoData
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.templateRaw = templateRaw
        self.themeRaw = themeRaw
        self.additionalNotes = additionalNotes
    }
    
    var status: InvoiceStatus {
        get {
            InvoiceStatus(rawValue: statusRaw) ?? .draft
        }
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    var isPaid: Bool {
        paidAt != nil
    }
    
    var statusText: String {
        isPaid ? "Paid" : "Unpaid"
    }
    
    // Helper properties to get business info (use only snapshot fields, no fallback to avoid crashes)
    var displayBusinessName: String {
        businessName
    }
    
    var displayBusinessAddress: String {
        businessAddress
    }
    
    var displayBusinessPhone: String {
        businessPhone
    }
    
    var displayBusinessEmail: String {
        businessEmail
    }
    
    var displayBusinessTaxId: String {
        businessTaxId
    }
    
    var displayBusinessLogoData: Data? {
        businessLogoData
    }
    
    var selectedTemplate: PDFTemplate {
        get {
            guard let raw = templateRaw, !raw.isEmpty else {
                return .professional
            }
            if let template = PDFTemplate(rawValue: raw) {
                return template
            }
            // Migration: renamed paginated-only templates (old stored raw values)
            switch raw {
            case "Pagination Test": return .professional
            case "Elegant Pro": return .elegant
            case "Classic Pro": return .classic
            default: return .professional
            }
        }
        set {
            templateRaw = newValue.rawValue
        }
    }
    
    var selectedTheme: InvoiceColorTheme {
        get {
            guard let raw = themeRaw, let theme = InvoiceColorTheme(rawValue: raw) else {
                return .ocean
            }
            return theme
        }
        set {
            themeRaw = newValue.rawValue
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
    var details: String
    var unit: String
    /// Zero-based position in the invoice line list (user-visible order). Do not rely on relationship array order.
    var sortOrder: Int
    
    init(title: String, qty: Int, price: Double, details: String = "", unit: String = "pcs", sortOrder: Int = 0) {
        self.title = title
        self.qty = qty
        self.price = price
        self.details = details
        self.unit = unit
        self.sortOrder = sortOrder
    }
    
    var total: Double {
        Double(qty) * price
    }
}

extension LineItemModel {
    /// Stable ordering for display, PDF, and edit load: primary `sortOrder`, then `persistentModelID` for legacy ties.
    static func sortedLineItems(_ items: [LineItemModel]?) -> [LineItemModel] {
        guard let items, !items.isEmpty else { return [] }
        return items.sorted { a, b in
            if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }
            return String(describing: a.persistentModelID) < String(describing: b.persistentModelID)
        }
    }
}

// MARK: - Currency Formatting Helper
func formatCurrency(_ amount: Double, currencyCode: String) -> String {
    let code = currencyCode.isEmpty ? "USD" : currencyCode
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
}

func formatPeriodRange(start: Date, end: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM yyyy"
    return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
}

func normalizedBusinessName(_ name: String) -> String {
    name
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
        .lowercased()
}

/// Normalizes client profile names for duplicate checks (same rules as `normalizedBusinessName`).
func normalizedClientName(_ name: String) -> String {
    normalizedBusinessName(name)
}

/// Whether another **active** business already uses the same normalized name (`excludingBusinessId` = row being edited).
func hasConflictingActiveBusinessName(
    rawName: String,
    among profiles: [BusinessProfileModel],
    excludingBusinessId: UUID? = nil
) -> Bool {
    let normalized = normalizedBusinessName(rawName)
    guard !normalized.isEmpty else { return false }
    return profiles.contains { profile in
        guard !profile.isArchived else { return false }
        if let exclude = excludingBusinessId, profile.id == exclude { return false }
        return normalizedBusinessName(profile.name) == normalized
    }
}

/// Whether another **active** client already uses the same normalized name (`excludingClientId` = row being edited).
func hasConflictingActiveClientName(
    rawName: String,
    among clients: [ClientModel],
    excludingClientId: UUID? = nil
) -> Bool {
    let normalized = normalizedClientName(rawName)
    guard !normalized.isEmpty else { return false }
    return clients.contains { client in
        guard !client.isArchived else { return false }
        if let exclude = excludingClientId, client.id == exclude { return false }
        return normalizedClientName(client.name) == normalized
    }
}

/// Normalizes invoice snapshot business names for report grouping (same rules as `normalizedBusinessName`).
func normalizedReportBusinessName(_ name: String) -> String {
    normalizedBusinessName(name)
}

/// Deterministic title-style label for Reports UI from the grouping key (not raw invoice snapshots).
func displayBusinessName(from normalizedKey: String) -> String {
    if normalizedKey.isEmpty {
        return "Unknown business"
    }
    return normalizedKey.capitalized
}

// MARK: - Report scope (invoice snapshot / history)

/// One row in the Reports business picker, derived only from stored invoices.
struct ReportBusinessGroup: Identifiable, Hashable {
    /// Case-insensitive, whitespace-normalized key from `invoice.businessName`.
    let normalizedKey: String
    /// Stable display label derived from `normalizedKey` via `displayBusinessName(from:)`.
    let displayName: String
    
    var id: String { normalizedKey.isEmpty ? "__report_empty_business__" : normalizedKey }
}

enum ReportScope: Hashable {
    case overall
    case business(normalizedKey: String, displayName: String)
}

/// Builds business report groups from invoice snapshot names only (ignores active/archived profiles).
func makeReportBusinessGroups(from invoices: [InvoiceModel]) -> [ReportBusinessGroup] {
    guard !invoices.isEmpty else { return [] }
    let grouped = Dictionary(grouping: invoices) { normalizedReportBusinessName($0.businessName) }
    return grouped.map { normalizedKey, _ in
        let displayName = displayBusinessName(from: normalizedKey)
        return ReportBusinessGroup(normalizedKey: normalizedKey, displayName: displayName)
    }
    .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
}

// MARK: - Invoice Duplication Helper
func duplicateInvoice(_ invoice: InvoiceModel, modelContext: ModelContext, allInvoices: [InvoiceModel]) -> InvoiceModel {
    // Generate next invoice number
    let maxNumber = allInvoices.compactMap { inv -> Int? in
        let components = inv.number.components(separatedBy: "-")
        if components.count == 2, let number = Int(components[1]) {
            return number
        }
        return nil
    }.max() ?? 0
    
    let nextNumber = maxNumber + 1
    let newInvoiceNumber = String(format: "INV-%04d", nextNumber)
    
    // Deep copy line items (preserve user order via sortOrder)
    let newLineItems = LineItemModel.sortedLineItems(invoice.items).enumerated().map { index, item in
        LineItemModel(
            title: item.title,
            qty: item.qty,
            price: item.price,
            details: item.details,
            unit: item.unit,
            sortOrder: index
        )
    }
    
    // Create new invoice with all snapshot fields
        let newInvoice = InvoiceModel(
            number: newInvoiceNumber,
            clientName: invoice.clientName,
            statusRaw: "Unpaid",
            issueDate: invoice.issueDate,
            dueDate: invoice.dueDate,
            taxPercent: invoice.taxPercent,
            createdAt: Date(),
            updatedAt: Date(),
            businessProfileId: invoice.businessProfileId,
            clientProfileId: invoice.clientProfileId,
            business: invoice.businessProfile,
            items: newLineItems,
            paidAt: nil,
            currencyCode: invoice.currencyCode,
            clientAddress: invoice.clientAddress,
            clientPhone: invoice.clientPhone,
            clientEmail: invoice.clientEmail,
            clientTaxId: invoice.clientTaxId,
            businessName: invoice.businessName,
            businessAddress: invoice.businessAddress,
            businessPhone: invoice.businessPhone,
            businessEmail: invoice.businessEmail,
            businessTaxId: invoice.businessTaxId,
            businessLogoData: invoice.businessLogoData,
            periodStart: invoice.periodStart,
            periodEnd: invoice.periodEnd,
            templateRaw: invoice.templateRaw,
            themeRaw: invoice.themeRaw,
            additionalNotes: invoice.additionalNotes
        )
    
    // Set relationships
    newInvoice.businessProfile = invoice.businessProfile
    newInvoice.clientRef = invoice.clientRef
    
    // Insert into context
    modelContext.insert(newInvoice)
    
    do {
        try modelContext.save()
    } catch {
        print("Failed to save duplicated invoice: \(error)")
    }
    
    return newInvoice
}

// MARK: - InvoicesView
struct InvoicesView: View {
    @Query(sort: \InvoiceModel.issueDate, order: .reverse) private var allInvoices: [InvoiceModel]
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchText = ""
    @State private var selectedFilter: String? = nil // "Unpaid" or "Paid" or nil for All
    @State private var showCreateInvoice = false
    @State private var selectedInvoice: InvoiceModel?
    @State private var invoiceToDelete: InvoiceModel?
    @State private var showDeleteConfirmation = false
    @State private var invoiceToEdit: InvoiceModel?
    @State private var showEditInvoice = false
    @State private var invoiceToDuplicate: InvoiceModel?
    @State private var isSelectionMode = false
    @State private var selectedInvoiceIDs = Set<PersistentIdentifier>()
    @State private var showBulkDeleteConfirmation = false
    
    private var filteredInvoices: [InvoiceModel] {
        var filtered = allInvoices
        
        // Filter by paid status
        if let selectedFilter = selectedFilter {
            if selectedFilter == "Paid" {
                filtered = filtered.filter { $0.isPaid }
            } else if selectedFilter == "Unpaid" {
                filtered = filtered.filter { !$0.isPaid }
            }
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
            ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search invoices...")
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, allInvoices.isEmpty ? 16 : 0)
                
                // Status filter (only when there is at least one invoice)
                if !allInvoices.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterButton(
                                title: "All",
                                isSelected: selectedFilter == nil
                            ) {
                                selectedFilter = nil
                            }
                            
                            FilterButton(
                                title: "Unpaid",
                                isSelected: selectedFilter == "Unpaid"
                            ) {
                                selectedFilter = selectedFilter == "Unpaid" ? nil : "Unpaid"
                            }
                            
                            FilterButton(
                                title: "Paid",
                                isSelected: selectedFilter == "Paid"
                            ) {
                                selectedFilter = selectedFilter == "Paid" ? nil : "Paid"
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                }
                
                // Invoices list
                if filteredInvoices.isEmpty {
                    Group {
                        Spacer(minLength: 0)
                        EmptyStateView(
                            icon: "doc.text",
                            title: "No invoices yet",
                            subtitle: "Tap + to add one"
                        )
                        .transition(.opacity)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                    )
                } else {
                    VStack(spacing: 0) {
                        List {
                            ForEach(filteredInvoices, id: \.persistentModelID) { invoice in
                                if isSelectionMode {
                                    HStack {
                                        Image(systemName: selectedInvoiceIDs.contains(invoice.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedInvoiceIDs.contains(invoice.persistentModelID) ? .blue : .gray)
                                            .font(.title3)
                                        
                                        InvoiceRow(invoice: invoice)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if selectedInvoiceIDs.contains(invoice.persistentModelID) {
                                            selectedInvoiceIDs.remove(invoice.persistentModelID)
                                        } else {
                                            selectedInvoiceIDs.insert(invoice.persistentModelID)
                                        }
                                    }
                                } else {
                                    NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                                        InvoiceRow(invoice: invoice)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button {
                                            invoiceToDuplicate = invoice
                                        } label: {
                                            Label("Duplicate", systemImage: "doc.on.doc")
                                        }
                                        
                                        Button {
                                            invoiceToDelete = invoice
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollDismissesKeyboard(.interactively)
                        
                        if isSelectionMode && !selectedInvoiceIDs.isEmpty {
                            Button {
                                showBulkDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Selected (\(selectedInvoiceIDs.count))")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                        }
                    }
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.25), value: filteredInvoices.isEmpty)

            if !isSelectionMode {
                FloatingAddButton {
                    showCreateInvoice = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 12)
            }
            }
            .navigationTitle("Invoices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isSelectionMode {
                            Button("Cancel") {
                                isSelectionMode = false
                                selectedInvoiceIDs.removeAll()
                            }
                        } else {
                            Button("Select") {
                                isSelectionMode = true
                            }
                        }
                        
                        if !isSelectionMode {
                            Button {
                                showCreateInvoice = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateInvoice) {
                CreateInvoiceView()
            }
            .sheet(item: $invoiceToDuplicate) { template in
                CreateInvoiceView(template: template)
            }
            .sheet(isPresented: $showEditInvoice) {
                if let invoice = invoiceToEdit {
                    EditInvoiceView(invoice: invoice)
                }
            }
            .alert("Delete?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    invoiceToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let invoice = invoiceToDelete {
                        deleteInvoice(invoice)
                    }
                    invoiceToDelete = nil
                }
            } message: {
                Text("This cannot be undone.")
            }
            .alert("Delete selected invoices?", isPresented: $showBulkDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    // Do nothing
                }
                Button("Delete", role: .destructive) {
                    deleteSelectedInvoices()
                }
            } message: {
                Text("This cannot be undone.")
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
    
    private func deleteInvoice(_ invoice: InvoiceModel) {
        modelContext.delete(invoice)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete invoice: \(error)")
        }
    }
    
    private func deleteSelectedInvoices() {
        let invoicesToDelete = filteredInvoices.filter { selectedInvoiceIDs.contains($0.persistentModelID) }
        
        for invoice in invoicesToDelete {
            modelContext.delete(invoice)
        }
        
        do {
            try modelContext.save()
            isSelectionMode = false
            selectedInvoiceIDs.removeAll()
        } catch {
            print("Failed to delete invoices: \(error)")
        }
    }
    
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    init(text: Binding<String>, placeholder: String = "Search...") {
        self._text = text
        self.placeholder = placeholder
    }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
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
        invoice.isPaid ? .green : .orange
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: invoice.issueDate)
    }
    
    private var formattedAmount: String {
        formatCurrency(invoice.total, currencyCode: invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode)
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
                
                Text(invoice.statusText)
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

// MARK: - Period Picker View
struct PeriodPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var periodStart: Date?
    @Binding var periodEnd: Date?
    
    @State private var startDate: Date
    @State private var endDate: Date
    
    init(periodStart: Binding<Date?>, periodEnd: Binding<Date?>) {
        self._periodStart = periodStart
        self._periodEnd = periodEnd
        let start = periodStart.wrappedValue ?? Date()
        let end = periodEnd.wrappedValue ?? Date()
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end >= start ? end : start)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Start Date") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                }
                
                Section("End Date") {
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                        .onChange(of: startDate) { oldValue, newValue in
                            if endDate < newValue {
                                endDate = newValue
                            }
                        }
                }
            }
            .navigationTitle("Invoice Period")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        periodStart = startDate
                        periodEnd = endDate >= startDate ? endDate : startDate
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Create Invoice View
struct CreateInvoiceView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessProfileModel.name) private var businessProfiles: [BusinessProfileModel]
    @Query(sort: \ClientModel.name) private var clients: [ClientModel]
    @Query(sort: \InvoiceModel.issueDate, order: .reverse) private var allInvoices: [InvoiceModel]
    
    let template: InvoiceModel?
    
    @State private var selectedBusiness: BusinessProfileModel?
    @State private var useManualEntry = false
    @State private var manualBusinessName = ""
    @State private var manualBusinessAddress = ""
    @State private var manualBusinessPhone = ""
    @State private var manualBusinessEmail = ""
    @State private var selectedClient: ClientModel?
    @State private var clientName = ""
    @State private var clientAddress = ""
    @State private var clientPhone = ""
    @State private var clientEmail = ""
    @State private var clientTaxId = ""
    @State private var invoiceNumber = ""
    @State private var currencyCode = "USD"
    @State private var issueDate = Date()
    @State private var dueDate = Date()
    @State private var periodStart: Date?
    @State private var periodEnd: Date?
    @State private var showPeriodPicker = false
    @State private var lineItems: [LineItemData] = [LineItemData()]
    @State private var taxPercent: Double = 0.0
    @State private var additionalNotes = ""
    @State private var showCreateBusinessProfile = false
    @State private var showCreateClient = false
    @State private var itemIndexToDelete: Int?
    @State private var showDeleteItemAlert = false
    @FocusState private var focusedLineItemTitleId: UUID?
    
    private var activeBusinessProfiles: [BusinessProfileModel] {
        businessProfiles.filter { !$0.isArchived }
    }
    
    private var activeClients: [ClientModel] {
        clients.filter { !$0.isArchived }
    }
    
    init(template: InvoiceModel? = nil) {
        self.template = template
    }
    
    private let currencies: [(code: String, symbol: String)] = [
        ("USD", "$"),
        ("EUR", "€"),
        ("GBP", "£"),
        ("RUB", "₽"),
        ("AMD", "֏")
    ]
    
    private var subtotal: Double {
        guard !lineItems.isEmpty else { return 0 }
        return lineItems.reduce(0) { $0 + (Double($1.qty) * $1.price) }
    }
    
    private var taxAmount: Double {
        subtotal * (taxPercent / 100.0)
    }
    
    private var total: Double {
        subtotal + taxAmount
    }
    
    /// Appends without animating list insertion, then performs a single `scrollTo`; focus runs after the scroll animation so the keyboard does not fight the scroll.
    private func addLineItem(_ newItem: LineItemData, scrollProxy: ScrollViewProxy) {
        let targetId = newItem.id
        var insertTransaction = Transaction()
        insertTransaction.disablesAnimations = true
        withTransaction(insertTransaction) {
            lineItems.append(newItem)
        }
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                let scrollDuration: TimeInterval = 0.32
                withAnimation(.easeInOut(duration: scrollDuration)) {
                    scrollProxy.scrollTo(targetId, anchor: .bottom)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + scrollDuration + 0.04) {
                    focusedLineItemTitleId = targetId
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                Section("Business") {
                    if activeBusinessProfiles.isEmpty {
                        VStack(spacing: 12) {
                            Text("No business profiles found. Please create one to continue.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        Picker("Business Profile", selection: $selectedBusiness) {
                            Text("Select Business").tag(nil as BusinessProfileModel?)
                            ForEach(activeBusinessProfiles) { profile in
                                Text(profile.name).tag(profile as BusinessProfileModel?)
                            }
                        }
                    }
                    
                    Button("Add Business Profile") {
                        showCreateBusinessProfile = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Section("Client") {
                    if activeClients.isEmpty {
                        VStack(spacing: 12) {
                            Text("No clients found. Please create one to continue.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        Picker("Client", selection: $selectedClient) {
                            Text("Select Client").tag(nil as ClientModel?)
                            ForEach(activeClients) { client in
                                Text(client.name).tag(client as ClientModel?)
                            }
                        }
                    }
                    
                    Button("Add Client") {
                        showCreateClient = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Section("Invoice Information") {
                    TextField("Invoice Number", text: $invoiceNumber)
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(currencies, id: \.code) { currency in
                            Text("\(currency.code) (\(currency.symbol))").tag(currency.code)
                        }
                    }
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    
                    Button {
                        showPeriodPicker = true
                    } label: {
                        HStack {
                            Text("Invoice Period (optional)")
                            Spacer()
                            if let start = periodStart, let end = periodEnd {
                                Text(formatPeriodRange(start: start, end: end))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Not set")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Line Items") {
                    ForEach(Array(lineItems.enumerated()), id: \.element.id) { index, item in
                        if index < lineItems.count {
                            LineItemRow(
                                focusedTitleItemId: $focusedLineItemTitleId,
                                item: Binding(
                                    get: { lineItems[index] },
                                    set: { lineItems[index] = $0 }
                                ),
                                currencyCode: currencyCode,
                                canDelete: lineItems.count > 1,
                                onDelete: {
                                    if lineItems.count > 1 {
                                        itemIndexToDelete = index
                                        showDeleteItemAlert = true
                                    }
                                }
                            )
                            .id(item.id)
                        }
                    }
                    
                    Menu {
                        Button {
                            addLineItem(LineItemData(title: "", qty: 1, price: 0.0, unit: "pcs"), scrollProxy: proxy)
                        } label: {
                            Label("Product (pcs)", systemImage: "cube")
                        }
                        
                        Button {
                            addLineItem(LineItemData(title: "", qty: 1, price: 0.0, unit: "hours"), scrollProxy: proxy)
                        } label: {
                            Label("Service (hours)", systemImage: "clock")
                        }
                        
                        Button {
                            addLineItem(LineItemData(title: "", qty: 1, price: 0.0, unit: "days"), scrollProxy: proxy)
                        } label: {
                            Label("Service (days)", systemImage: "calendar")
                        }
                        
                        Button {
                            addLineItem(LineItemData(title: "", qty: 1, price: 0.0, unit: "project"), scrollProxy: proxy)
                        } label: {
                            Label("Fixed fee (project)", systemImage: "doc.text")
                        }
                        
                        Button {
                            addLineItem(LineItemData(title: "", qty: 1, price: 0.0, unit: ""), scrollProxy: proxy)
                        } label: {
                            Label("Custom", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Label("Add Item", systemImage: "plus.circle")
                    }
                }
                
                Section("Additional Notes") {
                    InvoiceAdditionalNotesEditor(text: $additionalNotes)
                }
                
                Section("Totals") {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(formatCurrency(subtotal, currencyCode: currencyCode))
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
                        Text(formatCurrency(total, currencyCode: currencyCode))
                            .fontWeight(.semibold)
                    }
                }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
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
                // Prefill from template if provided
                if let template = template {
                    selectedBusiness = activeBusinessProfiles.first(where: { $0.id == template.businessProfileId })
                    selectedClient = activeClients.first(where: { $0.id == template.clientProfileId })
                    invoiceNumber = "" // Will be auto-generated on Save
                    currencyCode = template.currencyCode.isEmpty ? "USD" : template.currencyCode
                    issueDate = template.issueDate
                    dueDate = template.dueDate
                    periodStart = template.periodStart
                    periodEnd = template.periodEnd
                    taxPercent = template.taxPercent
                    additionalNotes = template.additionalNotes
                    
                    // Copy line items
                    if let items = template.items, !items.isEmpty {
                        lineItems = LineItemModel.sortedLineItems(items).map { item in
                            LineItemData(
                                title: item.title,
                                qty: item.qty,
                                price: item.price,
                                details: item.details,
                                unit: item.unit.isEmpty ? "pcs" : item.unit
                            )
                        }
                    } else {
                        lineItems = [LineItemData()]
                    }
                } else {
                    // Ensure lineItems always has at least one item
                    if lineItems.isEmpty {
                        lineItems = [LineItemData()]
                    }
                }
            }
            .sheet(isPresented: $showCreateBusinessProfile) {
                CreateBusinessProfileView { newProfile in
                    selectedBusiness = newProfile
                }
            }
            .sheet(isPresented: $showCreateClient) {
                CreateClientView { newClient in
                    selectedClient = newClient
                }
            }
            .sheet(isPresented: $showPeriodPicker) {
                PeriodPickerView(periodStart: $periodStart, periodEnd: $periodEnd)
            }
            .alert("Delete item?", isPresented: $showDeleteItemAlert) {
                Button("Cancel", role: .cancel) {
                    itemIndexToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let index = itemIndexToDelete, index < lineItems.count {
                        lineItems.remove(at: index)
                    }
                    itemIndexToDelete = nil
                }
            } message: {
                Text("Are you sure you want to remove this item?")
            }
        }
    }
    
    private var isValid: Bool {
        let hasBusiness = useManualEntry ? !manualBusinessName.trimmingCharacters(in: .whitespaces).isEmpty : selectedBusiness != nil
        let hasClient = selectedClient != nil
        let allItemsHaveNames = lineItems.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasValidItem = lineItems.contains { $0.qty > 0 }
        return hasBusiness &&
        hasClient &&
        allItemsHaveNames &&
        hasValidItem
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
    
    private func saveInvoice() {
        // Generate invoice number only when saving
        let finalInvoiceNumber = invoiceNumber.trimmingCharacters(in: .whitespaces).isEmpty ? generateNextInvoiceNumber() : invoiceNumber
        
        let lineItemModels = lineItems.enumerated().map { index, item in
            LineItemModel(title: item.title, qty: item.qty, price: item.price, details: item.details, unit: item.unit, sortOrder: index)
        }
        
        var finalBusinessProfile: BusinessProfileModel?
        var snapshotName = ""
        var snapshotAddress = ""
        var snapshotPhone = ""
        var snapshotEmail = ""
        var snapshotTaxId = ""
        var snapshotLogoData: Data? = nil
        
        if useManualEntry {
            // Create new business profile from manual entry
            let newProfile = BusinessProfileModel(
                name: manualBusinessName,
                address: manualBusinessAddress,
                phone: manualBusinessPhone,
                email: manualBusinessEmail
            )
            modelContext.insert(newProfile)
            finalBusinessProfile = newProfile
            
            // Copy to snapshot
            snapshotName = manualBusinessName
            snapshotAddress = manualBusinessAddress
            snapshotPhone = manualBusinessPhone
            snapshotEmail = manualBusinessEmail
            snapshotTaxId = ""
        } else if let selected = selectedBusiness {
            // Use selected profile - copy to snapshot
            finalBusinessProfile = selected
            snapshotName = selected.name
            snapshotAddress = selected.address
            snapshotPhone = selected.phone
            snapshotEmail = selected.email
            snapshotTaxId = selected.taxId
            snapshotLogoData = selected.logoData
        }
        
        // Handle client selection
        var finalClient: ClientModel?
        var clientSnapshotName = ""
        var clientSnapshotAddress = ""
        var clientSnapshotPhone = ""
        var clientSnapshotEmail = ""
        var clientSnapshotTaxId = ""
        
        if let selected = selectedClient {
            // Use selected client - copy to snapshot
            finalClient = selected
            clientSnapshotName = selected.name
            clientSnapshotAddress = selected.address
            clientSnapshotPhone = selected.phone
            clientSnapshotEmail = selected.email
            clientSnapshotTaxId = selected.taxId
        }
        
        let invoice = InvoiceModel(
            number: finalInvoiceNumber,
            clientName: clientSnapshotName,
            statusRaw: "Unpaid",
            issueDate: issueDate,
            dueDate: dueDate,
            taxPercent: taxPercent,
            createdAt: Date(),
            updatedAt: Date(),
            businessProfileId: finalBusinessProfile?.id,
            clientProfileId: finalClient?.id,
            business: finalBusinessProfile,
            items: lineItemModels,
            paidAt: nil,
            currencyCode: currencyCode,
            periodStart: periodStart,
            periodEnd: periodEnd,
            templateRaw: nil,
            themeRaw: nil
        )
        
        // Assign snapshot fields
        invoice.clientRef = finalClient
        invoice.clientProfileId = finalClient?.id
        invoice.clientAddress = clientSnapshotAddress
        invoice.clientPhone = clientSnapshotPhone
        invoice.clientEmail = clientSnapshotEmail
        invoice.clientTaxId = clientSnapshotTaxId
        invoice.businessProfile = finalBusinessProfile
        invoice.businessProfileId = finalBusinessProfile?.id
        invoice.businessName = snapshotName
        invoice.businessAddress = snapshotAddress
        invoice.businessPhone = snapshotPhone
        invoice.businessEmail = snapshotEmail
        invoice.businessTaxId = snapshotTaxId
        invoice.businessLogoData = snapshotLogoData
        invoice.additionalNotes = additionalNotes
        
        modelContext.insert(invoice)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save invoice: \(error)")
        }
    }
}

// MARK: - Edit Invoice View
struct EditInvoiceView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessProfileModel.name) private var businessProfiles: [BusinessProfileModel]
    @Query(sort: \ClientModel.name) private var clients: [ClientModel]
    
    let invoice: InvoiceModel
    
    @State private var selectedBusiness: BusinessProfileModel?
    @State private var selectedClient: ClientModel?
    @State private var clientName = ""
    @State private var clientAddress = ""
    @State private var clientPhone = ""
    @State private var clientEmail = ""
    @State private var clientTaxId = ""
    @State private var invoiceNumber = ""
    @State private var currencyCode = "USD"
    @State private var issueDate = Date()
    @State private var dueDate = Date()
    @State private var periodStart: Date?
    @State private var periodEnd: Date?
    @State private var showPeriodPicker = false
    @State private var lineItems: [LineItemData] = []
    @State private var taxPercent: Double = 0.0
    @State private var additionalNotes = ""
    @State private var showCreateBusinessProfile = false
    @State private var showCreateClient = false
    @State private var itemIndexToDelete: Int?
    @State private var showDeleteItemAlert = false
    @FocusState private var focusedLineItemTitleId: UUID?
    
    private var activeBusinessProfiles: [BusinessProfileModel] {
        businessProfiles.filter { !$0.isArchived }
    }
    
    private var activeClients: [ClientModel] {
        clients.filter { !$0.isArchived }
    }
    
    private let currencies: [(code: String, symbol: String)] = [
        ("USD", "$"),
        ("EUR", "€"),
        ("GBP", "£"),
        ("RUB", "₽"),
        ("AMD", "֏")
    ]
    
    private var subtotal: Double {
        lineItems.reduce(0) { $0 + (Double($1.qty) * $1.price) }
    }
    
    private var taxAmount: Double {
        subtotal * (taxPercent / 100.0)
    }
    
    private var total: Double {
        subtotal + taxAmount
    }
    
    private func addLineItem(_ newItem: LineItemData, scrollProxy: ScrollViewProxy) {
        let targetId = newItem.id
        var insertTransaction = Transaction()
        insertTransaction.disablesAnimations = true
        withTransaction(insertTransaction) {
            lineItems.append(newItem)
        }
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                let scrollDuration: TimeInterval = 0.32
                withAnimation(.easeInOut(duration: scrollDuration)) {
                    scrollProxy.scrollTo(targetId, anchor: .bottom)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + scrollDuration + 0.04) {
                    focusedLineItemTitleId = targetId
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                Section("Business") {
                    if activeBusinessProfiles.isEmpty {
                        VStack(spacing: 12) {
                            Text("No business profiles found. Please create one to continue.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        Picker("Business Profile", selection: $selectedBusiness) {
                            Text("Select Business").tag(nil as BusinessProfileModel?)
                            ForEach(activeBusinessProfiles) { profile in
                                Text(profile.name).tag(profile as BusinessProfileModel?)
                            }
                        }
                    }
                    
                    Button("Add Business Profile") {
                        showCreateBusinessProfile = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Section("Client") {
                    if activeClients.isEmpty {
                        VStack(spacing: 12) {
                            Text("No clients found. Please create one to continue.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        Picker("Client", selection: $selectedClient) {
                            Text("Select Client").tag(nil as ClientModel?)
                            ForEach(activeClients) { client in
                                Text(client.name).tag(client as ClientModel?)
                            }
                        }
                    }
                    
                    Button("Add Client") {
                        showCreateClient = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Section("Invoice Information") {
                    TextField("Invoice Number", text: $invoiceNumber)
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(currencies, id: \.code) { currency in
                            Text("\(currency.code) (\(currency.symbol))").tag(currency.code)
                        }
                    }
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    
                    Button {
                        showPeriodPicker = true
                    } label: {
                        HStack {
                            Text("Invoice Period (optional)")
                            Spacer()
                            if let start = periodStart, let end = periodEnd {
                                Text(formatPeriodRange(start: start, end: end))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Not set")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Line Items") {
                    ForEach(Array(lineItems.enumerated()), id: \.element.id) { index, item in
                        LineItemRow(
                            focusedTitleItemId: $focusedLineItemTitleId,
                            item: Binding(
                                get: { lineItems[index] },
                                set: { lineItems[index] = $0 }
                            ),
                            currencyCode: currencyCode,
                            canDelete: lineItems.count > 1,
                            onDelete: {
                                itemIndexToDelete = index
                                showDeleteItemAlert = true
                            }
                        )
                        .id(item.id)
                    }
                    
                    Menu {
                        Button {
                            addLineItem(LineItemData(title: "", qty: 1, price: 0.0, unit: "pcs"), scrollProxy: proxy)
                        } label: {
                            Label("Product (pcs)", systemImage: "cube")
                        }
                        
                        Button {
                            addLineItem(LineItemData(title: "", qty: 1, price: 0.0, unit: "hours"), scrollProxy: proxy)
                        } label: {
                            Label("Service (hours)", systemImage: "clock")
                        }
                        
                        Button {
                            addLineItem(LineItemData(title: "", qty: 1, price: 0.0, unit: "days"), scrollProxy: proxy)
                        } label: {
                            Label("Service (days)", systemImage: "calendar")
                        }
                        
                        Button {
                            addLineItem(LineItemData(title: "", qty: 1, price: 0.0, unit: "project"), scrollProxy: proxy)
                        } label: {
                            Label("Fixed fee (project)", systemImage: "doc.text")
                        }
                        
                        Button {
                            addLineItem(LineItemData(title: "", qty: 1, price: 0.0, unit: ""), scrollProxy: proxy)
                        } label: {
                            Label("Custom", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Label("Add Item", systemImage: "plus.circle")
                    }
                }
                
                Section("Additional Notes") {
                    InvoiceAdditionalNotesEditor(text: $additionalNotes)
                }
                
                Section("Totals") {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(formatCurrency(subtotal, currencyCode: currencyCode))
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
                        Text(formatCurrency(total, currencyCode: currencyCode))
                            .fontWeight(.semibold)
                    }
                }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Edit Invoice")
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
                loadInvoiceData()
            }
            .sheet(isPresented: $showCreateBusinessProfile) {
                CreateBusinessProfileView { newProfile in
                    selectedBusiness = newProfile
                }
            }
            .sheet(isPresented: $showCreateClient) {
                CreateClientView { newClient in
                    selectedClient = newClient
                }
            }
            .sheet(isPresented: $showPeriodPicker) {
                PeriodPickerView(periodStart: $periodStart, periodEnd: $periodEnd)
            }
            .alert("Delete item?", isPresented: $showDeleteItemAlert) {
                Button("Cancel", role: .cancel) {
                    itemIndexToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let index = itemIndexToDelete, index < lineItems.count {
                        lineItems.remove(at: index)
                    }
                    itemIndexToDelete = nil
                }
            } message: {
                Text("Are you sure you want to remove this item?")
            }
        }
    }
    
    private var isValid: Bool {
        let allItemsHaveNames = lineItems.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasValidItem = lineItems.contains { $0.qty > 0 }
        return selectedBusiness != nil &&
        selectedClient != nil &&
        !invoiceNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        allItemsHaveNames &&
        hasValidItem
    }
    
    private func loadInvoiceData() {
        selectedBusiness = activeBusinessProfiles.first(where: { $0.id == invoice.businessProfileId })
        
        // Load client data
        selectedClient = activeClients.first(where: { $0.id == invoice.clientProfileId })
        
        invoiceNumber = invoice.number
        currencyCode = invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode
        issueDate = invoice.issueDate
        dueDate = invoice.dueDate
        periodStart = invoice.periodStart
        periodEnd = invoice.periodEnd
        taxPercent = invoice.taxPercent
        additionalNotes = invoice.additionalNotes
        
        // Load line items (explicit sortOrder — relationship array order is not guaranteed)
        if let items = invoice.items, !items.isEmpty {
            lineItems = LineItemModel.sortedLineItems(items).map { item in
                LineItemData(title: item.title, qty: item.qty, price: item.price, details: item.details, unit: item.unit.isEmpty ? "pcs" : item.unit)
            }
        } else {
            lineItems = [LineItemData()]
        }
    }
    
    private func saveInvoice() {
        // Delete old line items
        if let oldItems = invoice.items {
            for item in oldItems {
                modelContext.delete(item)
            }
        }
        
        // Create new line items (rewrite sortOrder from current editor order)
        let newLineItems = lineItems.enumerated().map { index, item in
            LineItemModel(title: item.title, qty: item.qty, price: item.price, details: item.details, unit: item.unit, sortOrder: index)
        }
        
        // Update business properties
        if let selected = selectedBusiness {
            invoice.businessProfile = selected
            invoice.businessProfileId = selected.id
            // Update snapshot fields
            invoice.businessName = selected.name
            invoice.businessAddress = selected.address
            invoice.businessPhone = selected.phone
            invoice.businessEmail = selected.email
            invoice.businessTaxId = selected.taxId
            invoice.businessLogoData = selected.logoData
        } else {
            invoice.businessProfile = nil
            invoice.businessProfileId = nil
        }
        
        // Handle client selection
        if let selected = selectedClient {
            // Use selected client - copy to snapshot
            invoice.clientRef = selected
            invoice.clientProfileId = selected.id
            invoice.clientName = selected.name
            invoice.clientAddress = selected.address
            invoice.clientPhone = selected.phone
            invoice.clientEmail = selected.email
            invoice.clientTaxId = selected.taxId
        } else {
            invoice.clientRef = nil
            invoice.clientProfileId = nil
        }
        
        invoice.number = invoiceNumber
        invoice.currencyCode = currencyCode
        invoice.issueDate = issueDate
        invoice.dueDate = dueDate
        invoice.periodStart = periodStart
        invoice.periodEnd = periodEnd
        invoice.taxPercent = taxPercent
        invoice.items = newLineItems
        invoice.additionalNotes = additionalNotes
        invoice.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to update invoice: \(error)")
        }
    }
}

// MARK: - Line Item Data (temporary struct for form)
struct LineItemData: Identifiable {
    let id = UUID()
    var title: String
    var qty: Int
    var price: Double
    var details: String
    var unit: String
    
    init(title: String = "", qty: Int = 1, price: Double = 0.0, details: String = "", unit: String = "pcs") {
        self.title = title
        self.qty = qty
        self.price = price
        self.details = details
        self.unit = unit
    }
}

// MARK: - Line Item Row
struct LineItemRow: View {
    @FocusState.Binding var focusedTitleItemId: UUID?
    @Binding var item: LineItemData
    var currencyCode: String
    var canDelete: Bool
    var onDelete: () -> Void
    
    private var itemTotal: Double {
        Double(item.qty) * item.price
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Item title
            TextField("Item name", text: $item.title)
                .focused($focusedTitleItemId, equals: item.id)
                .onChange(of: item.title) { oldValue, newValue in
                    if newValue.count > 50 {
                        item.title = String(newValue.prefix(50))
                    }
                }
            
            // Row 2: Qty, Unit, Rate in columns
            HStack(alignment: .top, spacing: 16) {
                // Column A: Qty
                VStack(alignment: .leading, spacing: 4) {
                    Text("Qty")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                    TextField("1", value: $item.qty, format: .number)
                        .keyboardType(.numberPad)
                }
                .frame(maxWidth: .infinity)
                
                // Column B: Unit
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                    TextField("pcs", text: $item.unit)
                }
                .frame(maxWidth: .infinity)
                
                // Column C: Rate
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                    TextField("0.00", value: $item.price, format: .number)
                        .keyboardType(.decimalPad)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Row 3: Details
            TextField("Details (optional)", text: $item.details, axis: .vertical)
                .lineLimit(2...4)
                .onChange(of: item.details) { oldValue, newValue in
                    if newValue.count > 150 {
                        item.details = String(newValue.prefix(150))
                    }
                }
            
            // Row 4: Total and Delete
            HStack {
                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                Spacer()
                Text("Total: \(formatCurrency(itemTotal, currencyCode: currencyCode))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Invoice Detail View
struct InvoiceDetailView: View {
    let invoice: InvoiceModel
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InvoiceModel.issueDate, order: .reverse) private var allInvoices: [InvoiceModel]
    
    @State private var shareItem: ShareItem?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var showEditInvoice = false
    @State private var invoiceToEdit: InvoiceModel?
    @State private var showTemplateSelection = false
    @State private var pdfURL: URL?
    
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
        formatCurrency(invoice.total, currencyCode: invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Business Profile Section
                VStack(alignment: .leading, spacing: 8) {
                    if !invoice.displayBusinessName.isEmpty {
                        Text(invoice.displayBusinessName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if !invoice.displayBusinessEmail.isEmpty {
                            Text(invoice.displayBusinessEmail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else if !invoice.displayBusinessPhone.isEmpty {
                            Text(invoice.displayBusinessPhone)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if !invoice.displayBusinessTaxId.isEmpty {
                            Text("Tax ID: \(invoice.displayBusinessTaxId)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No business information")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                
                VStack {
                    Text("Invoice Details")
                        .font(.headline)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Invoice Number", value: invoice.number)
                        DetailRow(label: "Client Name", value: invoice.clientName)
                        DetailRow(label: "Total Amount", value: formattedAmount)
                        DetailRow(label: "Status", value: invoice.statusText)
                        DetailRow(label: "Issue Date", value: formattedIssueDate)
                        DetailRow(label: "Due Date", value: formattedDueDate)
                        DetailRow(label: "Paid Date", value: invoice.isPaid && invoice.paidAt != nil ? formatPaidDate(invoice.paidAt!) : "—")
                    }
                    .padding()
                }
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding()
                    
                VStack(alignment: .leading, spacing: 10) {
                    Text("Actions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        Button {
                            togglePaidStatus()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(invoice.isPaid ? .orange : .green)
                                    .frame(width: 20)
                                Text(invoice.isPaid ? "Mark as Unpaid" : "Mark as Paid")
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        
                        Divider()
                            .padding(.leading, 46)
                        
                        Button {
                            showTemplateSelection = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text("Export PDF")
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                //                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        
                        Divider()
                            .padding(.leading, 46)
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .frame(width: 20)
                                Text("Delete Invoice")
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .navigationTitle("Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            let duplicated = duplicateInvoice(invoice, modelContext: modelContext, allInvoices: allInvoices)
                            invoiceToEdit = duplicated
                            showEditInvoice = true
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            showEditInvoice = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showEditInvoice) {
                if let invoiceToEdit = invoiceToEdit {
                    EditInvoiceView(invoice: invoiceToEdit)
                } else {
                    EditInvoiceView(invoice: invoice)
                }
            }
            .sheet(isPresented: $showTemplateSelection) {
                InvoiceDesignPickerView(invoice: invoice)
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Invoice", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteInvoice()
                }
            } message: {
                Text("Are you sure you want to delete this invoice? This action cannot be undone.")
            }
        }
    }
    
    private func formatPaidDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    private func togglePaidStatus() {
        if invoice.isPaid {
            // Mark as unpaid
            invoice.paidAt = nil
        } else {
            // Mark as paid
            invoice.paidAt = Date()
        }
        invoice.updatedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to update invoice: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    private func deleteInvoice() {
        modelContext.delete(invoice)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to delete invoice: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    private func createPDF(with template: PDFTemplate) {
        do {
            let url = try generateInvoicePDF(invoice: invoice, template: template)
            
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
            
            pdfURL = url
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

// MARK: - PDF Template
/// All three templates are HTML engines with full multi-page pagination.
enum PDFTemplate: String, CaseIterable {
    /// Paginated layout (formerly "Pagination Test").
    case professional = "Professional"
    /// Paginated elegant layout (formerly "Elegant Pro").
    case elegant = "Elegant"
    /// Paginated classic layout (formerly "Classic Pro").
    case classic = "Classic"
}

// MARK: - Invoice Color Theme
enum InvoiceColorTheme: String, CaseIterable, Identifiable {
    case ocean = "Ocean"
    case forest = "Forest"
    case sunset = "Sunset"
    case slate = "Slate"
    case amethyst = "Amethyst"
    
    var id: String { rawValue }
    
    var accentColor: String {
        switch self {
        case .ocean: return "#4da6c9"
        case .forest: return "#2d8659"
        case .sunset: return "#e67e22"
        case .slate: return "#5a6c7d"
        case .amethyst: return "#9b59b6"
        }
    }
    
    var accentSoftColor: String {
        switch self {
        case .ocean: return "#e5f2f7"
        case .forest: return "#e8f5e9"
        case .sunset: return "#fef3e7"
        case .slate: return "#f0f2f4"
        case .amethyst: return "#f4e6f9"
        }
    }
    
    var titleColor: String {
        switch self {
        case .ocean: return "#2c5f7a"
        case .forest: return "#1e5d3a"
        case .sunset: return "#b85a1a"
        case .slate: return "#3d4a56"
        case .amethyst: return "#7d4a9e"
        }
    }
    
    var borderColor: String {
        switch self {
        case .ocean: return "#c8e0eb"
        case .forest: return "#c4d9c9"
        case .sunset: return "#f5d4b3"
        case .slate: return "#d0d5da"
        case .amethyst: return "#e1c4f0"
        }
    }
    
    var displayName: String { rawValue }
}

// MARK: - PDF Preview Item
struct PDFPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Invoice Design Picker View
struct InvoiceDesignPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    let invoice: InvoiceModel
    
    @State private var selectedTemplate: PDFTemplate
    @State private var selectedTheme: InvoiceColorTheme
    @State private var previewHTML: String?
    @State private var isGeneratingPreview = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showPreview = false
    @State private var previewPDFURL: URL?
    init(invoice: InvoiceModel) {
        self.invoice = invoice
        // Default to HTML template if old/invalid template is selected
        let template: PDFTemplate
        if PDFTemplate.allCases.contains(invoice.selectedTemplate) {
            template = invoice.selectedTemplate
        } else {
            template = .professional
        }
        _selectedTemplate = State(initialValue: template)
        _selectedTheme = State(initialValue: invoice.selectedTheme)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Live Preview Section
                if let html = previewHTML {
                    InvoicePreviewWithPageIndicator(html: html)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    ProgressView("Generating preview...")
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: .infinity)
                        .background(Color(.systemGray5))
                }
                
                Divider()
                
                VStack(spacing: 10) {
                    // Template Selection Row (HTML templates)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Layout")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // Show supported HTML templates
                                ForEach(PDFTemplate.allCases, id: \.self) { template in
                                    TemplateOptionCard(
                                        title: template.rawValue,
                                        isSelected: selectedTemplate == template,
                                        onTap: {
                                            selectedTemplate = template
                                            updatePreview()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Theme Selection Row
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color Theme")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(InvoiceColorTheme.allCases) { theme in
                                    ThemeOptionCard(
                                        theme: theme,
                                        isSelected: selectedTheme == theme,
                                        onTap: {
                                            selectedTheme = theme
                                            updatePreview()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Bottom Actions
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("Continue") {
                            saveAndContinue()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    .padding(.top, 2)
                }
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Design Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Ensure template is a valid HTML template
                if !PDFTemplate.allCases.contains(selectedTemplate) {
                    selectedTemplate = .professional
                }
                updatePreview()
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showPreview) {
                if let html = previewHTML {
                    HTMLInvoicePreviewSheet(
                        html: html,
                        invoice: invoice,
                        isGeneratingPDF: .constant(false),
                        onBack: {
                            showPreview = false
                        }
                    )
                } else if let url = previewPDFURL {
                    PDFPreviewView(pdfURL: url, onBack: {
                        showPreview = false
                    })
                }
            }
        }
    }
    
    private func updatePreview() {
        // Only HTML templates are supported
        guard PDFTemplate.allCases.contains(selectedTemplate) else {
            previewHTML = nil
            return
        }
        
        isGeneratingPreview = true
        DispatchQueue.main.async {
            let html = HTMLInvoiceRenderer.renderInvoice(invoice, theme: selectedTheme, template: selectedTemplate)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                previewHTML = html
            }
            isGeneratingPreview = false
        }
    }
    
    private func saveAndContinue() {
        // Save selections to invoice (HTML template)
        invoice.selectedTemplate = selectedTemplate
        invoice.selectedTheme = selectedTheme
        
        // Generate HTML preview
        let html = HTMLInvoiceRenderer.renderInvoice(invoice, theme: selectedTheme, template: selectedTemplate)
        previewHTML = html
        previewPDFURL = nil
        showPreview = true
    }
}

// MARK: - Template Option Card
struct TemplateOptionCard: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            .frame(width: 92, height: 62)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Option Card
struct ThemeOptionCard: View {
    let theme: InvoiceColorTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Color swatch
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: theme.accentColor) ?? .blue)
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(Color(hex: theme.accentSoftColor) ?? .gray)
                        .frame(width: 14, height: 14)
                }
                
                Text(theme.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            .frame(width: 92, height: 62)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Invoice Preview Pager
//
// Native SwiftUI TabView pager. Each page is rendered in its own WKWebView that
// shows only the Nth .page div. TabView(.page) provides real snap paging, and
// SwiftUI tracks the current page index natively — no HTML scroll hacks.

struct InvoicePreviewWithPageIndicator: View {
    let html: String
    @State private var currentPage = 0
    @State private var pageCount = 1

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor(red: 232/255, green: 232/255, blue: 237/255, alpha: 1))
                .ignoresSafeArea()

            if pageCount > 0 {
                TabView(selection: $currentPage) {
                    ForEach(0..<pageCount, id: \.self) { idx in
                        SinglePagePreview(html: html, pageIndex: idx, onPageCount: { count in
                            if count > 0 { pageCount = count }
                        })
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            if pageCount > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { i in
                        Circle()
                            .fill(Color.primary.opacity(i == currentPage ? 0.55 : 0.18))
                            .frame(width: 7, height: 7)
                            .onTapGesture { withAnimation { currentPage = i } }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 10)
            }
        }
        .onChange(of: html) { _, _ in
            currentPage = 0
            pageCount = 1
        }
    }
}

// MARK: - Single Page Preview (one WKWebView showing only page N)

private struct SinglePagePreview: UIViewRepresentable {
    let html: String
    let pageIndex: Int
    let onPageCount: (Int) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        let bg = UIColor(red: 232/255, green: 232/255, blue: 237/255, alpha: 1)
        webView.isOpaque = true
        webView.backgroundColor = bg
        webView.scrollView.backgroundColor = bg
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.isUserInteractionEnabled = false
        webView.alpha = 0
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let prepared = Self.buildPreviewHTML(from: html, showPageIndex: pageIndex)
        if context.coordinator.lastKey != prepared {
            context.coordinator.lastKey = prepared
            context.coordinator.onPageCount = onPageCount
            context.coordinator.prepareForNewLoad(webView: webView)
            webView.loadHTMLString(prepared, baseURL: Bundle.main.bundleURL)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Builds preview HTML with the target page index baked in.
    /// A DOMContentLoaded script hides all .page divs except the target,
    /// measures it, and scales it centered. Because the index is embedded in
    /// the HTML itself, each WKWebView is fully self-contained — no post-load
    /// JS coordination needed.
    static func buildPreviewHTML(from content: String, showPageIndex: Int) -> String {
        var s = content.replacingOccurrences(
            of: #"<meta[^>]*name=["']viewport["'][^>]*>"#,
            with: "",
            options: .regularExpression
        )

        let professionalPolish: String
        if s.contains("invoice-document") {
            professionalPolish = """
            <style id="__pv_pro">
            .page { padding: 0 !important; background: #ffffff !important; }
            .page .invoice { padding: 20mm !important; border-radius: 0 !important; box-shadow: none !important; min-height: 297mm; }
            </style>
            """
        } else {
            professionalPolish = ""
        }

        let inject = """
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style id="__pv">
        * { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
        html, body { margin: 0; padding: 0; overflow: hidden; background: #e8e8ed !important; width: 100%; height: 100%; }
        .invoice-document { display: contents !important; }
        .page { display: none !important; }
        .page.__pv_active { display: block !important; }
        @media print {
            .invoice-document { display: block !important; }
            .page { display: block !important; }
            body { background: white !important; }
        }
        </style>
        \(professionalPolish)
        <script>
        var __pvTarget = \(showPageIndex);
        document.addEventListener('DOMContentLoaded', function() {
            var pages = document.querySelectorAll('.page');
            var n = pages.length;
            if (!n) return;
            var t = Math.min(__pvTarget, n - 1);
            pages[t].classList.add('__pv_active');
            window.__pvPageCount = n;
        });
        </script>
        """

        if s.range(of: "</head>", options: .caseInsensitive) != nil {
            s = s.replacingOccurrences(of: "</head>", with: "\(inject)\n</head>", options: .caseInsensitive)
        } else {
            s = "\(inject)\n\(s)"
        }
        return s
    }

    /// Post-load JS: measure the visible page, scale it, center it in viewport.
    private static let scaleScript = """
    (function() {
        var p = document.querySelector('.page.__pv_active');
        var n = window.__pvPageCount || document.querySelectorAll('.page').length;
        if (!p) return JSON.stringify({ok:false, reason:'no-active-page', pages:n});

        p.style.margin = '0';
        p.style.boxShadow = 'none';
        var pw = p.offsetWidth;
        var ph = p.offsetHeight;
        if (!pw || !ph) return JSON.stringify({ok:false, reason:'no-size', pw:pw, ph:ph, pages:n});

        var vw = window.innerWidth || 390;
        var vh = window.innerHeight || 700;
        var hPad = 20, vPad = 14;
        var scaleX = (vw - hPad * 2) / pw;
        var scaleY = (vh - vPad * 2) / ph;
        var scale = Math.min(scaleX, scaleY);
        if (!isFinite(scale) || scale <= 0) scale = 0.25;
        if (scale > 1) scale = 1;

        var fw = Math.round(pw * scale);
        var fh = Math.round(ph * scale);
        var ox = Math.round((vw - fw) / 2);
        var oy = Math.round((vh - fh) / 2);

        var frame = document.getElementById('__pv_frame');
        if (!frame) {
            frame = document.createElement('div');
            frame.id = '__pv_frame';
            frame.style.cssText = 'position:absolute;overflow:hidden;border-radius:4px;box-shadow:0 2px 20px rgba(0,0,0,0.12);background:#fff;';
            document.body.appendChild(frame);
        }
        frame.style.left = ox + 'px';
        frame.style.top = oy + 'px';
        frame.style.width = fw + 'px';
        frame.style.height = fh + 'px';

        p.style.position = 'absolute';
        p.style.top = '0';
        p.style.left = '0';
        p.style.width = pw + 'px';
        p.style.height = ph + 'px';
        p.style.transform = 'scale(' + scale + ')';
        p.style.transformOrigin = 'top left';
        p.style.overflow = 'hidden';

        if (p.parentNode !== frame) {
            frame.innerHTML = '';
            frame.appendChild(p);
        }

        return JSON.stringify({ok:true, pages:n, scale:scale});
    })();
    """

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastKey: String?
        var onPageCount: ((Int) -> Void)?
        private var loadGeneration: UInt64 = 0
        private var outstandingGens: [UInt64] = []

        func prepareForNewLoad(webView: WKWebView) {
            loadGeneration += 1
            outstandingGens.append(loadGeneration)
            UIView.performWithoutAnimation { webView.alpha = 0 }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !outstandingGens.isEmpty else { return }
            let gen = outstandingGens.removeFirst()

            webView.evaluateJavaScript(SinglePagePreview.scaleScript) { [weak self] result, _ in
                self?.parseResult(result)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    webView.evaluateJavaScript(SinglePagePreview.scaleScript) { [weak self] result2, _ in
                        self?.parseResult(result2)
                        DispatchQueue.main.async {
                            guard gen == self?.loadGeneration else { return }
                            UIView.animate(withDuration: 0.12) { webView.alpha = 1 }
                        }
                    }
                }
            }
        }

        private func parseResult(_ result: Any?) {
            guard let str = result as? String,
                  let data = str.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pages = json["pages"] as? Int else { return }
            DispatchQueue.main.async { self.onPageCount?(pages) }
        }

        private func handleFail(webView: WKWebView, error: Error) {
            if (error as NSError).code == NSURLErrorCancelled {
                if !outstandingGens.isEmpty { outstandingGens.removeFirst() }
                return
            }
            if !outstandingGens.isEmpty { outstandingGens.removeFirst() }
            DispatchQueue.main.async { webView.alpha = 1 }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleFail(webView: webView, error: error)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleFail(webView: webView, error: error)
        }
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Template Selection View
struct TemplateSelectionView: View {
    @Environment(\.dismiss) var dismiss
    let invoice: InvoiceModel
    
    @State private var selectedTemplate: PDFTemplate?
    @State private var pdfURL: URL?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var htmlContent: String?
    @State private var isGeneratingPDF = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let htmlContent = htmlContent {
                    // HTML Preview
                    HTMLInvoicePreviewSheet(
                        html: htmlContent,
                        invoice: invoice,
                        isGeneratingPDF: $isGeneratingPDF,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                self.htmlContent = nil
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                } else if let pdfURL = pdfURL {
                    PDFPreviewView(pdfURL: pdfURL, onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.pdfURL = nil
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(PDFTemplate.allCases, id: \.self) { template in
                                TemplateCard(
                                    template: template,
                                    isSelected: selectedTemplate == template,
                                    onTap: {
                                        selectedTemplate = template
                                        generatePDF(for: template)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    .navigationTitle("Select Template")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Close") {
                                dismiss()
                            }
                        }
                    }
                    .alert("Error", isPresented: $showErrorAlert) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text(errorMessage)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
        }
    }
    
    private func generatePDF(for template: PDFTemplate) {
        let html = HTMLInvoiceRenderer.renderInvoice(invoice, theme: invoice.selectedTheme, template: template)
        print("✅ HTML rendered, showing preview")
        withAnimation(.easeInOut(duration: 0.25)) {
            htmlContent = html
        }
    }
}

// MARK: - Template Card
struct TemplateCard: View {
    let template: PDFTemplate
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Template preview thumbnail
                TemplatePreview(template: template)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                // Template name
                Text(template.rawValue)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Preview
struct TemplatePreview: View {
    let template: PDFTemplate
    
    var body: some View {
        VStack(spacing: 0) {
            switch template {
            case .professional:
                HTMLPreview()
            case .elegant:
                HTMLPreview()
            case .classic:
                ClassicPreview()
            }
        }
        .padding(8)
    }
}

// MARK: - Classic Preview
struct ClassicPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 8)
                Spacer()
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 8)
            }
            
            Spacer()
                .frame(height: 6)
            
            // Title
            Rectangle()
                .fill(Color.primary.opacity(0.8))
                .frame(height: 6)
                .frame(maxWidth: .infinity)
            
            Spacer()
                .frame(height: 4)
            
            // Lines
            ForEach(0..<3) { _ in
                HStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 50, height: 3)
                    Spacer()
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 30, height: 3)
                }
                Spacer()
                    .frame(height: 3)
            }
            
            Spacer()
            
            // Footer line
            Rectangle()
                .fill(Color.primary.opacity(0.6))
                .frame(height: 4)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Modern Preview
struct ModernPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Large header
            Rectangle()
                .fill(Color.blue.opacity(0.7))
                .frame(height: 20)
                .frame(maxWidth: .infinity)
            
            Spacer()
                .frame(height: 8)
            
            // Title with accent
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 3, height: 12)
                Rectangle()
                    .fill(Color.primary.opacity(0.7))
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)
            }
            
            Spacer()
                .frame(height: 6)
            
            // Grid-like content
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }
            }
            
            Spacer()
            
            // Bottom accent
            Rectangle()
                .fill(Color.blue.opacity(0.5))
                .frame(height: 3)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Minimal Preview
struct MinimalPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Minimal header
            Rectangle()
                .fill(Color.primary.opacity(0.3))
                .frame(height: 4)
                .frame(maxWidth: .infinity)
            
            Spacer()
                .frame(height: 12)
            
            // Simple title
            Rectangle()
                .fill(Color.primary.opacity(0.5))
                .frame(height: 4)
                .frame(maxWidth: 120)
            
            Spacer()
                .frame(height: 8)
            
            // Minimal lines
            ForEach(0..<4) { _ in
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                Spacer()
                    .frame(height: 4)
            }
            
            Spacer()
            
            // Subtle divider
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - HTML Preview
struct HTMLPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // HTML-style header
            HStack {
                Rectangle()
                    .fill(Color(red: 0.3, green: 0.65, blue: 0.79))
                    .frame(width: 50, height: 8)
                Spacer()
            }
            
            Spacer()
                .frame(height: 6)
            
            // Title
            Rectangle()
                .fill(Color.primary.opacity(0.9))
                .frame(height: 6)
                .frame(maxWidth: 100)
            
            Spacer()
                .frame(height: 8)
            
            // Grid-style items
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color(red: 0.3, green: 0.65, blue: 0.79).opacity(0.3))
                        .frame(width: 40, height: 3)
                    Spacer()
                    Rectangle()
                        .fill(Color(red: 0.3, green: 0.65, blue: 0.79).opacity(0.3))
                        .frame(width: 20, height: 3)
                }
                ForEach(0..<3) { _ in
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 40, height: 2)
                        Spacer()
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 20, height: 2)
                    }
                }
            }
            
            Spacer()
            
            // Total section
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color(red: 0.3, green: 0.65, blue: 0.79))
                    .frame(width: 50, height: 4)
            }
        }
    }
}

// MARK: - PDF Preview View
struct PDFPreviewView: View {
    let pdfURL: URL
    let onBack: () -> Void
    @State private var shareItem: ShareItem?
    
    var body: some View {
        PDFKitView(url: pdfURL)
            .navigationTitle("PDF Preview")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        onBack()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        shareItem = ShareItem(url: pdfURL)
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
    }
}

// MARK: - PDFKit View Wrapper
struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // No updates needed
    }
}

// MARK: - PDF Generation
func generateInvoicePDF(invoice: InvoiceModel, template: PDFTemplate) throws -> URL {
    let pageSize = CGSize(width: 612, height: 792) // US Letter size
    let margin: CGFloat = 50
    let contentWidth = pageSize.width - (margin * 2)
    
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
    
    let fileName = "Invoice_\(invoice.number.replacingOccurrences(of: " ", with: "_")).pdf"
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    
    // Handle HTML templates separately - uses HTML renderer instead of UIGraphicsPDFRenderer
    switch template {
    case .professional, .elegant, .classic:
        // Render HTML and generate PDF from it
        let html = HTMLInvoiceRenderer.renderInvoice(invoice, theme: invoice.selectedTheme, template: template)
        
        // Use semaphore to wait for async PDF generation
        // Note: This is a synchronous wrapper for the async generatePDFFromHTML function
        let semaphore = DispatchSemaphore(value: 0)
        var resultURL: URL?
        var resultError: Error?
        
        // Run PDF generation on a background queue to avoid blocking
        Task.detached {
            do {
                let url = try await generatePDFFromHTML(html, invoiceNumber: invoice.number)
                resultURL = url
                semaphore.signal()
            } catch {
                resultError = error
                semaphore.signal()
            }
        }
        
        // Wait for PDF generation to complete (with timeout)
        let timeout = semaphore.wait(timeout: .now() + 30)
        
        if timeout == .timedOut {
            throw NSError(domain: "PDFGeneration", code: 4, userInfo: [NSLocalizedDescriptionKey: "PDF generation timed out"])
        }
        
        if let error = resultError {
            throw error
        }
        
        guard let url = resultURL else {
            throw NSError(domain: "PDFGeneration", code: 5, userInfo: [NSLocalizedDescriptionKey: "PDF generation returned nil URL"])
        }
        
        return url
    }
    
    // Template-specific styling for classic/modern/minimal (HTML handled above)
    let headerFontSize: CGFloat
    let titleFontSize: CGFloat
    let bodyFontSize: CGFloat
    let spacing: CGFloat
    
    // This code path should never be reached for HTML templates
    // as they are handled earlier in the function. This switch is exhaustive for the enum.
    switch template {
    case .professional, .elegant, .classic:
        // HTML templates should have been handled above
        fatalError("HTML templates should have been handled earlier in the function")
    }
    
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
        var businessInfoX: CGFloat = margin
        var businessInfoY: CGFloat = yPosition
        var headerHeight: CGFloat = 0
        
        // Draw "INVOICE" title at top right
        drawText("INVOICE", at: CGPoint(x: margin, y: yPosition), font: .boldSystemFont(ofSize: titleFontSize), alignment: .right)
        
        // Use snapshot fields first, then fallback to businessProfile
        let businessName = invoice.displayBusinessName
        let businessAddress = invoice.displayBusinessAddress
        let businessPhone = invoice.displayBusinessPhone
        let businessEmail = invoice.displayBusinessEmail
        let businessTaxId = invoice.displayBusinessTaxId
        let businessLogoData = invoice.displayBusinessLogoData
        
        if !businessName.isEmpty {
            let lineHeight = headerFontSize + 4
            var logoHeight: CGFloat = 0
            
            // Draw logo if exists
            if let logoData = businessLogoData, let logoImage = UIImage(data: logoData) {
                let maxLogoSize: CGFloat = 80
                let aspectRatio = logoImage.size.width / logoImage.size.height
                let logoWidth: CGFloat
                let logoHeightCalculated: CGFloat
                
                if aspectRatio > 1 {
                    // Landscape
                    logoWidth = maxLogoSize
                    logoHeightCalculated = maxLogoSize / aspectRatio
                } else {
                    // Portrait or square
                    logoWidth = maxLogoSize * aspectRatio
                    logoHeightCalculated = maxLogoSize
                }
                
                logoHeight = logoHeightCalculated
                let logoRect = CGRect(x: margin, y: yPosition, width: logoWidth, height: logoHeight)
                logoImage.draw(in: logoRect)
                
                // Position business info next to logo
                businessInfoX = margin + logoWidth + 15
                businessInfoY = yPosition
            }
            
            // Calculate text height
            var textLines = 1 // business name
            if !businessAddress.isEmpty { textLines += 1 }
            if !businessPhone.isEmpty { textLines += 1 }
            if !businessEmail.isEmpty { textLines += 1 }
            if !businessTaxId.isEmpty { textLines += 1 }
            let textHeight = headerFontSize + CGFloat(textLines - 1) * lineHeight
            
            // Draw business info
            drawText(businessName, at: CGPoint(x: businessInfoX, y: businessInfoY), font: .boldSystemFont(ofSize: headerFontSize), width: contentWidth - (businessInfoX - margin))
            if !businessAddress.isEmpty {
                drawText(businessAddress, at: CGPoint(x: businessInfoX, y: businessInfoY + lineHeight), font: .systemFont(ofSize: bodyFontSize), width: contentWidth - (businessInfoX - margin))
            }
            if !businessPhone.isEmpty {
                drawText(businessPhone, at: CGPoint(x: businessInfoX, y: businessInfoY + lineHeight * 2), font: .systemFont(ofSize: bodyFontSize), width: contentWidth - (businessInfoX - margin))
            }
            var currentLine = 0
            if !businessAddress.isEmpty {
                currentLine += 1
            }
            if !businessPhone.isEmpty {
                currentLine += 1
            }
            if !businessEmail.isEmpty {
                currentLine += 1
                drawText(businessEmail, at: CGPoint(x: businessInfoX, y: businessInfoY + lineHeight * CGFloat(currentLine)), font: .systemFont(ofSize: bodyFontSize), width: contentWidth - (businessInfoX - margin))
            }
            if !businessTaxId.isEmpty {
                currentLine += 1
                drawText("Tax ID: \(businessTaxId)", at: CGPoint(x: businessInfoX, y: businessInfoY + lineHeight * CGFloat(currentLine)), font: .systemFont(ofSize: bodyFontSize), width: contentWidth - (businessInfoX - margin))
            }
            
            headerHeight = max(logoHeight, textHeight)
        }
        
        yPosition += headerHeight + spacing
        
        // Invoice details
        let detailFont = UIFont.systemFont(ofSize: bodyFontSize)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        drawText("Invoice Number: \(invoice.number)", at: CGPoint(x: margin, y: yPosition), font: detailFont)
        yPosition += spacing
        
        drawText("Issue Date: \(dateFormatter.string(from: invoice.issueDate))", at: CGPoint(x: margin, y: yPosition), font: detailFont)
        yPosition += spacing
        
        drawText("Due Date: \(dateFormatter.string(from: invoice.dueDate))", at: CGPoint(x: margin, y: yPosition), font: detailFont)
        yPosition += spacing
        
        if let periodStart = invoice.periodStart, let periodEnd = invoice.periodEnd {
            drawText("Period: \(formatPeriodRange(start: periodStart, end: periodEnd))", at: CGPoint(x: margin, y: yPosition), font: detailFont)
            yPosition += spacing
        }
        
        yPosition += spacing * 0.5
        
        // Bill To section
        drawText("Bill To:", at: CGPoint(x: margin, y: yPosition), font: .boldSystemFont(ofSize: bodyFontSize + 2))
        yPosition += spacing
        drawText(invoice.clientName, at: CGPoint(x: margin, y: yPosition), font: detailFont)
        yPosition += spacing * 2
        
        // Items table header
        let headerFont = UIFont.boldSystemFont(ofSize: bodyFontSize)
        let itemColumnWidth = contentWidth * 0.4
        let qtyColumnWidth = contentWidth * 0.15
        let priceColumnWidth = contentWidth * 0.2
        let totalColumnWidth = contentWidth * 0.25
        
        drawText("Item", at: CGPoint(x: margin, y: yPosition), font: headerFont, width: itemColumnWidth)
        drawText("Qty", at: CGPoint(x: margin + itemColumnWidth, y: yPosition), font: headerFont, width: qtyColumnWidth)
        drawText("Price", at: CGPoint(x: margin + itemColumnWidth + qtyColumnWidth, y: yPosition), font: headerFont, width: priceColumnWidth)
        drawText("Total", at: CGPoint(x: margin + itemColumnWidth + qtyColumnWidth + priceColumnWidth, y: yPosition), font: headerFont, width: totalColumnWidth)
        yPosition += spacing + 5
        
        // Draw line under header
        context.cgContext.move(to: CGPoint(x: margin, y: yPosition))
        context.cgContext.addLine(to: CGPoint(x: margin + contentWidth, y: yPosition))
        context.cgContext.strokePath()
        yPosition += 10
        
        // Items list
        let currencyCode = invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode
        let items = LineItemModel.sortedLineItems(invoice.items)
        for item in items {
            let itemTotal = Double(item.qty) * item.price
            let qtyText = item.unit.isEmpty ? "\(item.qty)" : "\(item.qty) \(item.unit)"
            drawText(item.title, at: CGPoint(x: margin, y: yPosition), font: detailFont, width: itemColumnWidth)
            drawText(qtyText, at: CGPoint(x: margin + itemColumnWidth, y: yPosition), font: detailFont, width: qtyColumnWidth)
            drawText(formatCurrency(item.price, currencyCode: currencyCode), at: CGPoint(x: margin + itemColumnWidth + qtyColumnWidth, y: yPosition), font: detailFont, width: priceColumnWidth)
            drawText(formatCurrency(itemTotal, currencyCode: currencyCode), at: CGPoint(x: margin + itemColumnWidth + qtyColumnWidth + priceColumnWidth, y: yPosition), font: detailFont, width: totalColumnWidth)
            yPosition += spacing
            
            // Draw details if available
            if !item.details.isEmpty {
                drawText(item.details, at: CGPoint(x: margin, y: yPosition), font: .systemFont(ofSize: bodyFontSize - 2), width: itemColumnWidth)
                yPosition += spacing * 0.7
            }
        }
        
        yPosition += spacing
        
        // Totals section
        let totalsY = yPosition
        let totalsStartX = margin + itemColumnWidth + qtyColumnWidth
        let totalsWidth = priceColumnWidth + totalColumnWidth
        let labelWidth = totalsWidth * 0.6
        let valueWidth = totalsWidth * 0.4
        
        drawText("Subtotal:", at: CGPoint(x: totalsStartX, y: totalsY), font: detailFont, alignment: .right, width: labelWidth)
        drawText(formatCurrency(invoice.subtotal, currencyCode: currencyCode), at: CGPoint(x: totalsStartX + labelWidth, y: totalsY), font: detailFont, alignment: .right, width: valueWidth)
        yPosition += spacing
        
        drawText("Tax (\(String(format: "%.1f", invoice.taxPercent))%):", at: CGPoint(x: totalsStartX, y: yPosition), font: detailFont, alignment: .right, width: labelWidth)
        let taxAmount = invoice.subtotal * (invoice.taxPercent / 100.0)
        drawText(formatCurrency(taxAmount, currencyCode: currencyCode), at: CGPoint(x: totalsStartX + labelWidth, y: yPosition), font: detailFont, alignment: .right, width: valueWidth)
        yPosition += spacing
        
        drawText("Total:", at: CGPoint(x: totalsStartX, y: yPosition), font: .boldSystemFont(ofSize: bodyFontSize + 2), alignment: .right, width: labelWidth)
        drawText(formatCurrency(invoice.total, currencyCode: currencyCode), at: CGPoint(x: totalsStartX + labelWidth, y: yPosition), font: .boldSystemFont(ofSize: bodyFontSize + 2), alignment: .right, width: valueWidth)
        yPosition += spacing * 1.5
        
        // Status
        drawText("Status: \(invoice.statusText)", at: CGPoint(x: margin, y: yPosition), font: .boldSystemFont(ofSize: bodyFontSize))
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

// MARK: - HTML Invoice Preview Sheet
struct HTMLInvoicePreviewSheet: View {
    let html: String
    let invoice: InvoiceModel
    @Binding var isGeneratingPDF: Bool
    let onBack: () -> Void
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationStack {
            ZStack {
                InvoicePreviewWithPageIndicator(html: html)
                    .ignoresSafeArea(edges: .bottom)

                if isGeneratingPDF {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    ProgressView("Generating PDF...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Invoice Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        onBack()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export PDF") {
                        exportPDF()
                    }
                    .disabled(isGeneratingPDF)
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    private func exportPDF() {
        isGeneratingPDF = true

        Task {
            do {
                let url = try await generatePDFFromHTML(html, invoiceNumber: invoice.number)
                await MainActor.run {
                    isGeneratingPDF = false
                    shareItem = ShareItem(url: url)
                }
            } catch {
                await MainActor.run {
                    isGeneratingPDF = false
                    errorMessage = "Failed to generate PDF: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
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


// MARK: - Logo Preview View
struct LogoPreviewView: View {
    let logoData: Data?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let logoData = logoData, let uiImage = UIImage(data: logoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
            }
            .navigationTitle("Logo Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Create Business Profile View
struct CreateBusinessProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessProfileModel.name) private var businessProfiles: [BusinessProfileModel]
    
    var onSave: ((BusinessProfileModel) -> Void)?
    
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var taxId = ""
    @State private var logoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showLogoPreview = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    /// Hides duplicate UI after a passed save so `@Query` (which includes the new row) cannot flash a false duplicate.
    @State private var suppressDuplicateNameFeedback = false
    
    init(onSave: ((BusinessProfileModel) -> Void)? = nil) {
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Logo") {
                    if let logoData = logoData, let uiImage = UIImage(data: logoData) {
                        HStack {
                            Button {
                                showLogoPreview = true
                            } label: {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Button("Remove Logo") {
                                self.logoData = nil
                                selectedPhoto = nil
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose Logo", systemImage: "photo")
                    }
                    .onChange(of: selectedPhoto) { oldValue, newValue in
                        Task {
                            if let newValue = newValue {
                                if let data = try? await newValue.loadTransferable(type: Data.self) {
                                    if let uiImage = UIImage(data: data) {
                                        logoData = uiImage.jpegData(compressionQuality: 0.8)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("Business Information") {
                    TextField("Business Name", text: $name)
                    ProfileFormAddressEditor(placeholder: "Address", text: $address)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Tax ID (optional)", text: $taxId)
                    
                    if isDuplicateName {
                        Text("An active business profile with this name already exists.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .onChange(of: name) { _, _ in
                suppressDuplicateNameFeedback = false
            }
            .navigationTitle("New Business Profile")
            .sheet(isPresented: $showLogoPreview) {
                LogoPreviewView(logoData: logoData)
            }
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
            .alert("Validation", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    private var isDuplicateName: Bool {
        if suppressDuplicateNameFeedback { return false }
        return hasConflictingActiveBusinessName(rawName: name, among: businessProfiles, excludingBusinessId: nil)
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isDuplicateName
    }
    
    private func saveBusinessProfile() {
        let conflict = hasConflictingActiveBusinessName(rawName: name, among: businessProfiles, excludingBusinessId: nil)
        if conflict {
            suppressDuplicateNameFeedback = false
            validationMessage = "Please choose a different business name. Active business names must be unique."
            showValidationAlert = true
            return
        }
        
        suppressDuplicateNameFeedback = true
        
        let business = BusinessProfileModel(
            name: name,
            address: address,
            phone: phone,
            email: email,
            taxId: taxId,
            createdAt: Date(),
            updatedAt: Date(),
            logoData: logoData
        )
        
        modelContext.insert(business)
        
        do {
            try modelContext.save()
            onSave?(business)
            dismiss()
        } catch {
            suppressDuplicateNameFeedback = false
            print("Failed to save business profile: \(error)")
        }
    }
}

// MARK: - Edit Business Profile View
struct EditBusinessProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessProfileModel.name) private var businessProfiles: [BusinessProfileModel]
    
    let business: BusinessProfileModel
    
    @State private var name: String
    @State private var address: String
    @State private var phone: String
    @State private var email: String
    @State private var taxId: String
    @State private var logoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showLogoPreview = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var suppressDuplicateNameFeedback = false
    
    init(business: BusinessProfileModel) {
        self.business = business
        _name = State(initialValue: business.name)
        _address = State(initialValue: business.address)
        _phone = State(initialValue: business.phone)
        _email = State(initialValue: business.email)
        _taxId = State(initialValue: business.taxId)
        _logoData = State(initialValue: business.logoData)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Logo") {
                    if let logoData = logoData, let uiImage = UIImage(data: logoData) {
                        HStack {
                            Button {
                                showLogoPreview = true
                            } label: {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Button("Remove Logo") {
                                self.logoData = nil
                                selectedPhoto = nil
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose Logo", systemImage: "photo")
                    }
                    .onChange(of: selectedPhoto) { oldValue, newValue in
                        Task {
                            if let newValue = newValue {
                                if let data = try? await newValue.loadTransferable(type: Data.self) {
                                    if let uiImage = UIImage(data: data) {
                                        logoData = uiImage.jpegData(compressionQuality: 0.8)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("Business Information") {
                    TextField("Business Name", text: $name)
                    ProfileFormAddressEditor(placeholder: "Address", text: $address)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Tax ID (optional)", text: $taxId)
                    
                    if isDuplicateName {
                        Text("An active business profile with this name already exists.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .onChange(of: name) { _, _ in
                suppressDuplicateNameFeedback = false
            }
            .navigationTitle("Edit Business Profile")
            .sheet(isPresented: $showLogoPreview) {
                LogoPreviewView(logoData: logoData)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBusinessProfile()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Validation", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    private var isDuplicateName: Bool {
        if suppressDuplicateNameFeedback { return false }
        return hasConflictingActiveBusinessName(
            rawName: name,
            among: businessProfiles,
            excludingBusinessId: business.id
        )
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isDuplicateName
    }
    
    private func saveBusinessProfile() {
        let conflict = hasConflictingActiveBusinessName(
            rawName: name,
            among: businessProfiles,
            excludingBusinessId: business.id
        )
        if conflict {
            suppressDuplicateNameFeedback = false
            validationMessage = "Please choose a different business name. Active business names must be unique."
            showValidationAlert = true
            return
        }
        
        suppressDuplicateNameFeedback = true
        
        business.name = name
        business.address = address
        business.phone = phone
        business.email = email
        business.taxId = taxId
        business.logoData = logoData
        business.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            suppressDuplicateNameFeedback = false
            print("Failed to save business profile: \(error)")
        }
    }
}

// MARK: - Create Client View
struct CreateClientView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClientModel.name) private var clients: [ClientModel]
    
    var onSave: ((ClientModel) -> Void)?
    
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var taxId = ""
    @State private var logoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showLogoPreview = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var suppressDuplicateNameFeedback = false
    
    private var isDuplicateName: Bool {
        if suppressDuplicateNameFeedback { return false }
        return hasConflictingActiveClientName(rawName: name, among: clients, excludingClientId: nil)
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isDuplicateName
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Logo") {
                    if let logoData = logoData, let uiImage = UIImage(data: logoData) {
                        HStack {
                            Button {
                                showLogoPreview = true
                            } label: {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Button("Remove Logo") {
                                self.logoData = nil
                                selectedPhoto = nil
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose Logo", systemImage: "photo")
                    }
                    .onChange(of: selectedPhoto) { oldValue, newValue in
                        Task {
                            if let newValue = newValue {
                                if let data = try? await newValue.loadTransferable(type: Data.self) {
                                    if let uiImage = UIImage(data: data) {
                                        logoData = uiImage.jpegData(compressionQuality: 0.8)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("Client Information") {
                    TextField("Name", text: $name)
                    ProfileFormAddressEditor(placeholder: "Address (optional)", text: $address)
                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Tax ID (optional)", text: $taxId)
                    
                    if isDuplicateName {
                        Text("An active client with this name already exists.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .onChange(of: name) { _, _ in
                suppressDuplicateNameFeedback = false
            }
            .navigationTitle("New Client")
            .sheet(isPresented: $showLogoPreview) {
                LogoPreviewView(logoData: logoData)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveClient()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Validation", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    private func saveClient() {
        let conflict = hasConflictingActiveClientName(rawName: name, among: clients, excludingClientId: nil)
        if conflict {
            suppressDuplicateNameFeedback = false
            validationMessage = "Please choose a different client name. Active client names must be unique."
            showValidationAlert = true
            return
        }
        
        suppressDuplicateNameFeedback = true
        
        let client = ClientModel(
            name: name,
            address: address,
            phone: phone,
            email: email,
            taxId: taxId,
            logoData: logoData
        )
        
        modelContext.insert(client)
        
        do {
            try modelContext.save()
            onSave?(client)
            dismiss()
        } catch {
            suppressDuplicateNameFeedback = false
            print("Failed to save client: \(error)")
        }
    }
}

// MARK: - Edit Client View
struct EditClientView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClientModel.name) private var clients: [ClientModel]
    
    let client: ClientModel
    
    @State private var name: String
    @State private var address: String
    @State private var phone: String
    @State private var email: String
    @State private var taxId: String
    @State private var logoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showLogoPreview = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var suppressDuplicateNameFeedback = false
    
    init(client: ClientModel) {
        self.client = client
        _name = State(initialValue: client.name)
        _address = State(initialValue: client.address)
        _phone = State(initialValue: client.phone)
        _email = State(initialValue: client.email)
        _taxId = State(initialValue: client.taxId)
        _logoData = State(initialValue: client.logoData)
    }
    
    private var isDuplicateName: Bool {
        if suppressDuplicateNameFeedback { return false }
        return hasConflictingActiveClientName(
            rawName: name,
            among: clients,
            excludingClientId: client.id
        )
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isDuplicateName
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Logo") {
                    if let logoData = logoData, let uiImage = UIImage(data: logoData) {
                        HStack {
                            Button {
                                showLogoPreview = true
                            } label: {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Button("Remove Logo") {
                                self.logoData = nil
                                selectedPhoto = nil
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose Logo", systemImage: "photo")
                    }
                    .onChange(of: selectedPhoto) { oldValue, newValue in
                        Task {
                            if let newValue = newValue {
                                if let data = try? await newValue.loadTransferable(type: Data.self) {
                                    if let uiImage = UIImage(data: data) {
                                        logoData = uiImage.jpegData(compressionQuality: 0.8)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("Client Information") {
                    TextField("Name", text: $name)
                    ProfileFormAddressEditor(placeholder: "Address (optional)", text: $address)
                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Tax ID (optional)", text: $taxId)
                    
                    if isDuplicateName {
                        Text("An active client with this name already exists.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .onChange(of: name) { _, _ in
                suppressDuplicateNameFeedback = false
            }
            .navigationTitle("Edit Client")
            .sheet(isPresented: $showLogoPreview) {
                LogoPreviewView(logoData: logoData)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveClient()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Validation", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    private func saveClient() {
        let conflict = hasConflictingActiveClientName(
            rawName: name,
            among: clients,
            excludingClientId: client.id
        )
        if conflict {
            suppressDuplicateNameFeedback = false
            validationMessage = "Please choose a different client name. Active client names must be unique."
            showValidationAlert = true
            return
        }
        
        suppressDuplicateNameFeedback = true
        
        client.name = name
        client.address = address
        client.phone = phone
        client.email = email
        client.taxId = taxId
        client.logoData = logoData
        client.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            suppressDuplicateNameFeedback = false
            print("Failed to save client: \(error)")
        }
    }
}

struct ClientsView: View {
    @Query(sort: \ClientModel.name) private var clients: [ClientModel]
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchText = ""
    @State private var showCreateClient = false
    @State private var selectedClient: ClientModel?
    @State private var clientToDelete: ClientModel?
    @State private var showDeleteConfirmation = false
    @State private var isSelectionMode = false
    @State private var selectedClientIDs = Set<PersistentIdentifier>()
    @State private var showBulkDeleteConfirmation = false
    
    private var activeClients: [ClientModel] {
        clients.filter { !$0.isArchived }
    }
    
    private var filteredClients: [ClientModel] {
        if searchText.isEmpty {
            return activeClients
        }
        return activeClients.filter { client in
            client.name.localizedCaseInsensitiveContains(searchText) ||
            client.email.localizedCaseInsensitiveContains(searchText) ||
            client.phone.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search clients...")
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Clients list
                if filteredClients.isEmpty {
                    Group {
                        Spacer(minLength: 0)
                        EmptyStateView(
                            icon: "person.2",
                            title: searchText.isEmpty ? "No clients yet" : "No results",
                            subtitle: searchText.isEmpty ? "Tap + to add one" : "Try adjusting your search"
                        )
                        .transition(.opacity)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                    )
                } else {
                    VStack(spacing: 0) {
                        List {
                            ForEach(filteredClients, id: \.persistentModelID) { client in
                                if isSelectionMode {
                                    HStack {
                                        Image(systemName: selectedClientIDs.contains(client.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedClientIDs.contains(client.persistentModelID) ? .blue : .gray)
                                            .font(.title3)
                                        
                                        ClientRow(client: client)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if selectedClientIDs.contains(client.persistentModelID) {
                                            selectedClientIDs.remove(client.persistentModelID)
                                        } else {
                                            selectedClientIDs.insert(client.persistentModelID)
                                        }
                                    }
                                } else {
                                    NavigationLink(destination: EditClientView(client: client)) {
                                        ClientRow(client: client)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            clientToDelete = client
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Archive", systemImage: "archivebox")
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollDismissesKeyboard(.interactively)
                        
                        if isSelectionMode && !selectedClientIDs.isEmpty {
                            Button {
                                showBulkDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "archivebox")
                                    Text("Archive Selected (\(selectedClientIDs.count))")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                        }
                    }
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.25), value: filteredClients.isEmpty)

            if !isSelectionMode {
                FloatingAddButton {
                    showCreateClient = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 12)
            }
            }
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isSelectionMode {
                            Button("Cancel") {
                                isSelectionMode = false
                                selectedClientIDs.removeAll()
                            }
                        } else {
                            Button("Select") {
                                isSelectionMode = true
                            }
                        }
                        
                        if !isSelectionMode {
                            Button {
                                showCreateClient = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateClient) {
                CreateClientView()
            }
            .alert("Archive?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    clientToDelete = nil
                }
                Button("Archive", role: .destructive) {
                    if let client = clientToDelete {
                        deleteClient(client)
                    }
                    clientToDelete = nil
                }
            } message: {
                Text("This client will be archived and hidden from active lists.")
            }
            .alert("Archive selected?", isPresented: $showBulkDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    // Do nothing
                }
                Button("Archive", role: .destructive) {
                    deleteSelectedClients()
                }
            } message: {
                Text("Selected clients will be archived and hidden from active lists.")
            }
        }
    }
    
    private func deleteClient(_ client: ClientModel) {
        withAnimation {
            client.isArchived = true
            client.archivedAt = Date()
            client.updatedAt = Date()
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete client: \(error)")
        }
    }
    
    private func deleteSelectedClients() {
        let clientsToDelete = filteredClients.filter { selectedClientIDs.contains($0.persistentModelID) }
        
        withAnimation {
            for client in clientsToDelete {
                client.isArchived = true
                client.archivedAt = Date()
                client.updatedAt = Date()
            }
        }
        
        do {
            try modelContext.save()
            isSelectionMode = false
            selectedClientIDs.removeAll()
        } catch {
            print("Failed to delete clients: \(error)")
        }
    }
}

// MARK: - Client Row
struct ClientRow: View {
    let client: ClientModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo thumbnail
            Group {
                if let logoData = client.logoData, let uiImage = UIImage(data: logoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Client info
            VStack(alignment: .leading, spacing: 4) {
                Text(client.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !client.email.isEmpty {
                    Text(client.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if !client.phone.isEmpty {
                    Text(client.phone)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ItemsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("No items yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Items")
        }
    }
}

// MARK: - Equal Height Preference Key
struct CardHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ReportsView: View {
    @Query(sort: \InvoiceModel.issueDate, order: .reverse) private var allInvoices: [InvoiceModel]
    
    @State private var selectedPeriod: ReportPeriod = .thisMonth
    @State private var showCustomRangePicker = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var reportScope: ReportScope = .overall
    @State private var selectedClient: String?
    @State private var showClientInvoices = false
    @State private var showPaidInvoices = false
    @State private var showUnpaidInvoices = false
    @State private var cardHeight: CGFloat = 0
    
    /// Business rows in the report picker: derived only from invoices in storage (snapshot names).
    private var reportBusinessGroups: [ReportBusinessGroup] {
        makeReportBusinessGroups(from: allInvoices)
    }
    
    /// Changes when invoice set affects which normalized business keys exist (display is derived from keys).
    private var reportBusinessGroupingSignature: String {
        reportBusinessGroups
            .map(\.normalizedKey)
            .sorted()
            .joined(separator: "§")
    }
    
    enum ReportPeriod {
        case thisMonth
        case lastMonth
        case customRange
    }
    
    private var periodStart: Date {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return calendar.dateInterval(of: .month, for: lastMonth)?.start ?? Date()
        case .customRange:
            return customStartDate
        }
    }
    
    private var periodEnd: Date {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: Date())?.end ?? Date()
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return calendar.dateInterval(of: .month, for: lastMonth)?.end ?? Date()
        case .customRange:
            return customEndDate
        }
    }
    
    private func filteredInvoices(for period: (start: Date, end: Date)) -> [InvoiceModel] {
        var filtered = allInvoices.filter { invoice in
            invoice.issueDate >= period.start && invoice.issueDate <= period.end
        }
        
        if case .business(let normalizedKey, _) = reportScope {
            filtered = filtered.filter { invoice in
                normalizedReportBusinessName(invoice.businessName) == normalizedKey
            }
        }
        
        return filtered
    }
    
    private func pruneReportScopeIfNeeded() {
        guard case .business(let key, _) = reportScope else { return }
        let validKeys = Set(reportBusinessGroups.map(\.normalizedKey))
        if !validKeys.contains(key) {
            reportScope = .overall
        }
    }
    
    /// Keeps stored `displayName` aligned with `displayBusinessName(from:)` (e.g. after app updates).
    private func syncReportScopeDisplayNameIfNeeded() {
        guard case .business(let key, let currentDisplay) = reportScope else { return }
        let expected = displayBusinessName(from: key)
        if currentDisplay != expected {
            reportScope = .business(normalizedKey: key, displayName: expected)
        }
    }
    
    private func isReportScopeMatchingBusiness(normalizedKey: String) -> Bool {
        if case .business(let k, _) = reportScope { return k == normalizedKey }
        return false
    }
    
    private func invoiceTotal(_ invoice: InvoiceModel) -> Double {
        invoice.total
    }
    
    private func formatMoney(_ amount: Double, currencyCode: String) -> String {
        formatCurrency(amount, currencyCode: currencyCode)
    }
    
    private func currencySymbol(for code: String) -> String {
        switch code {
        case "RUB": return "₽"
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        case "AMD": return "֏"
        default: return code
        }
    }
    
    private func formatMoneyWithSymbol(_ amount: Double, currencyCode: String) -> String {
        let code = currencyCode.isEmpty ? "USD" : currencyCode
        let symbol = currencySymbol(for: code)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        formatter.usesGroupingSeparator = true
        
        if let formatted = formatter.string(from: NSNumber(value: amount)) {
            return "\(symbol)\(formatted)"
        }
        return "\(symbol)\(String(format: "%.2f", amount))"
    }
    
    private var currentPeriodInvoices: [InvoiceModel] {
        filteredInvoices(for: (start: periodStart, end: periodEnd))
    }
    
    private var totalRevenue: Double {
        currentPeriodInvoices.reduce(0) { $0 + invoiceTotal($1) }
    }
    
    private var paidRevenue: Double {
        currentPeriodInvoices.filter { $0.paidAt != nil }.reduce(0) { $0 + invoiceTotal($1) }
    }
    
    private var unpaidRevenue: Double {
        currentPeriodInvoices.filter { $0.paidAt == nil }.reduce(0) { $0 + invoiceTotal($1) }
    }
    
    private var paidCount: Int {
        currentPeriodInvoices.filter { $0.paidAt != nil }.count
    }
    
    private var unpaidCount: Int {
        currentPeriodInvoices.filter { $0.paidAt == nil }.count
    }
    
    private var revenueByClient: [(name: String, total: Double, count: Int)] {
        let grouped = Dictionary(grouping: currentPeriodInvoices) { $0.clientName }
        return grouped.map { (name, invoices) in
            let total = invoices.reduce(0.0) { $0 + invoiceTotal($1) }
            return (name: name, total: total, count: invoices.count)
        }
        .sorted { $0.total > $1.total }
    }
    
    private var monthlyRevenueData: [(month: String, revenue: Double)] {
        let calendar = Calendar.current
        var data: [(month: String, revenue: Double)] = []
        
        for i in 0..<6 {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: Date()),
                  let monthStart = calendar.dateInterval(of: .month, for: monthDate)?.start,
                  let monthEnd = calendar.dateInterval(of: .month, for: monthDate)?.end else {
                continue
            }
            
            let monthInvoices = filteredInvoices(for: (start: monthStart, end: monthEnd))
            let revenue = monthInvoices.reduce(0.0) { $0 + invoiceTotal($1) }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            let monthName = formatter.string(from: monthDate)
            
            data.append((month: monthName, revenue: revenue))
        }
        
        return data.reversed()
    }
    
    private var primaryCurrencyCode: String {
        let currencies = Set(currentPeriodInvoices.map { $0.currencyCode.isEmpty ? "USD" : $0.currencyCode })
        return currencies.count == 1 ? currencies.first ?? "USD" : "USD"
    }
    
    private var hasMixedCurrencies: Bool {
        let currencies = Set(currentPeriodInvoices.map { $0.currencyCode.isEmpty ? "USD" : $0.currencyCode })
        return currencies.count > 1
    }
    
    private var revenueByCurrency: [(currencyCode: String, total: Double)] {
        let grouped = Dictionary(grouping: currentPeriodInvoices) { invoice in
            invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode
        }
        return grouped.map { (currency, invoices) in
            let total = invoices.reduce(0.0) { $0 + invoiceTotal($1) }
            return (currencyCode: currency, total: total)
        }.sorted { $0.currencyCode < $1.currencyCode }
    }
    
    private var paidRevenueByCurrency: [(currencyCode: String, total: Double)] {
        let paidInvoices = currentPeriodInvoices.filter { $0.paidAt != nil }
        let grouped = Dictionary(grouping: paidInvoices) { invoice in
            invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode
        }
        return grouped.map { (currency, invoices) in
            let total = invoices.reduce(0.0) { $0 + invoiceTotal($1) }
            return (currencyCode: currency, total: total)
        }.sorted { $0.currencyCode < $1.currencyCode }
    }
    
    private var unpaidRevenueByCurrency: [(currencyCode: String, total: Double)] {
        let unpaidInvoices = currentPeriodInvoices.filter { $0.paidAt == nil }
        let grouped = Dictionary(grouping: unpaidInvoices) { invoice in
            invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode
        }
        return grouped.map { (currency, invoices) in
            let total = invoices.reduce(0.0) { $0 + invoiceTotal($1) }
            return (currencyCode: currency, total: total)
        }.sorted { $0.currencyCode < $1.currencyCode }
    }
    
    private var revenueByClientWithCurrency: [(name: String, totals: [(currencyCode: String, total: Double)], count: Int)] {
        let grouped = Dictionary(grouping: currentPeriodInvoices) { $0.clientName }
        return grouped.map { (name, invoices) in
            let currencyGrouped = Dictionary(grouping: invoices) { invoice in
                invoice.currencyCode.isEmpty ? "USD" : invoice.currencyCode
            }
            let totals = currencyGrouped.map { (currency, invs) in
                let total = invs.reduce(0.0) { $0 + invoiceTotal($1) }
                return (currencyCode: currency, total: total)
            }.sorted { $0.currencyCode < $1.currencyCode }
            return (name: name, totals: totals, count: invoices.count)
        }
        .sorted { 
            let total1 = $0.totals.reduce(0.0) { $0 + $1.total }
            let total2 = $1.totals.reduce(0.0) { $0 + $1.total }
            return total1 > total2
        }
    }
    
    private var reportScopeMenuLabel: String {
        switch reportScope {
        case .overall:
            return "Overall"
        case .business(let normalizedKey, _):
            return displayBusinessName(from: normalizedKey)
        }
    }
    
    private var isOverallScopeSelected: Bool {
        if case .overall = reportScope { return true }
        return false
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if allInvoices.isEmpty {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        EmptyStateView(
                            icon: "chart.bar",
                            title: "No reports yet",
                            subtitle: "Create invoices to see reports"
                        )
                        .transition(.opacity)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Reports")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Menu {
                                Button {
                                    reportScope = .overall
                                } label: {
                                    Label("Overall", systemImage: isOverallScopeSelected ? "checkmark" : "")
                                }
                                
                                ForEach(reportBusinessGroups) { group in
                                    Button {
                                        reportScope = .business(normalizedKey: group.normalizedKey, displayName: group.displayName)
                                    } label: {
                                        Label(group.displayName, systemImage: isReportScopeMatchingBusiness(normalizedKey: group.normalizedKey) ? "checkmark" : "")
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.subheadline)
                                    Text(reportScopeMenuLabel)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 4)
                        
                        // Period Selector
                        VStack(spacing: 16) {
                            Picker("Period", selection: $selectedPeriod) {
                                Text("This Month").tag(ReportPeriod.thisMonth)
                                Text("Last Month").tag(ReportPeriod.lastMonth)
                                Text("Custom Range").tag(ReportPeriod.customRange)
                            }
                            .pickerStyle(.segmented)
                            
                            if selectedPeriod == .customRange {
                                Button {
                                    showCustomRangePicker = true
                                } label: {
                                    HStack {
                                        Text("\(formatDate(customStartDate)) - \(formatDate(customEndDate))")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "calendar")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 2)
                        
                        // Mixed currencies note
                        if hasMixedCurrencies {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Invoices use multiple currencies, so totals are shown separately.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                        }
                        
                        if currentPeriodInvoices.isEmpty {
                            EmptyStateView(
                                icon: "chart.bar",
                                title: "No data for selected period",
                                subtitle: "Try a different period"
                            )
                            .transition(.opacity)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 28)
                            .padding(.bottom, 20)
                        } else {
                            // A) Revenue Overview
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(.blue)
                                    Text("Revenue Overview")
                                        .font(.headline)
                                }
                                
                                if hasMixedCurrencies {
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Total Revenue by Currency
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Total Revenue")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            VStack(alignment: .leading, spacing: 6) {
                                                ForEach(revenueByCurrency, id: \.currencyCode) { item in
                                                    Text(formatMoneyWithSymbol(item.total, currencyCode: item.currencyCode))
                                                        .font(.system(size: 24, weight: .bold))
                                                        .foregroundColor(.primary)
                                                }
                                            }
                                        }
                                        
                                        HStack(alignment: .top, spacing: 16) {
                                            // Paid Revenue by Currency
                                            VStack(alignment: .leading, spacing: 12) {
                                                HStack {
                                                    Image(systemName: "checkmark.circle")
                                                        .foregroundColor(.green)
                                                        .font(.caption)
                                                    Text("Paid")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                if paidRevenueByCurrency.isEmpty {
                                                    Text("No paid invoices")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                } else {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        ForEach(paidRevenueByCurrency, id: \.currencyCode) { item in
                                                            Text(formatMoneyWithSymbol(item.total, currencyCode: item.currencyCode))
                                                                .font(.title3)
                                                                .fontWeight(.semibold)
                                                                .foregroundColor(.primary)
                                                        }
                                                    }
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                            .background(
                                                GeometryReader { geometry in
                                                    Color.clear.preference(
                                                        key: CardHeightPreferenceKey.self,
                                                        value: geometry.size.height
                                                    )
                                                }
                                            )
                                            .frame(height: cardHeight > 0 ? cardHeight : nil, alignment: .topLeading)
                                            
                                            // Unpaid Revenue by Currency
                                            VStack(alignment: .leading, spacing: 12) {
                                                HStack {
                                                    Image(systemName: "exclamationmark.circle")
                                                        .foregroundColor(.orange)
                                                        .font(.caption)
                                                    Text("Unpaid")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                if unpaidRevenueByCurrency.isEmpty {
                                                    Text("No unpaid invoices")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                } else {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        ForEach(unpaidRevenueByCurrency, id: \.currencyCode) { item in
                                                            Text(formatMoneyWithSymbol(item.total, currencyCode: item.currencyCode))
                                                                .font(.title3)
                                                                .fontWeight(.semibold)
                                                                .foregroundColor(.primary)
                                                        }
                                                    }
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                            .background(
                                                GeometryReader { geometry in
                                                    Color.clear.preference(
                                                        key: CardHeightPreferenceKey.self,
                                                        value: geometry.size.height
                                                    )
                                                }
                                            )
                                            .frame(height: cardHeight > 0 ? cardHeight : nil, alignment: .topLeading)
                                        }
                                        .onPreferenceChange(CardHeightPreferenceKey.self) { height in
                                            cardHeight = height
                                        }
                                    }
                                } else {
                                    VStack(spacing: 16) {
                                        // Total Revenue
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Total Revenue")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(formatMoney(totalRevenue, currencyCode: primaryCurrencyCode))
                                                .font(.system(size: 32, weight: .bold))
                                                .foregroundColor(.primary)
                                        }
                                        
                                        HStack(spacing: 12) {
                                            // Paid Revenue
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Image(systemName: "checkmark.circle")
                                                        .foregroundColor(.green)
                                                        .font(.caption)
                                                    Text("Paid")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                Text(formatMoney(paidRevenue, currencyCode: primaryCurrencyCode))
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                            
                                            // Unpaid Revenue
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Image(systemName: "exclamationmark.circle")
                                                        .foregroundColor(.orange)
                                                        .font(.caption)
                                                    Text("Unpaid")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                Text(formatMoney(unpaidRevenue, currencyCode: primaryCurrencyCode))
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            .padding(.horizontal)
                            
                            // B) Paid vs Unpaid Summary
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Summary")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 12) {
                                    // Paid
                                    Button {
                                        showPaidInvoices = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.title2)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Paid Invoices")
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                if hasMixedCurrencies {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("\(paidCount) invoices")
                                                            .font(.subheadline)
                                                            .foregroundColor(.secondary)
                                                        ForEach(paidRevenueByCurrency, id: \.currencyCode) { item in
                                                            Text(formatMoney(item.total, currencyCode: item.currencyCode))
                                                                .font(.subheadline)
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                } else {
                                                    Text("\(paidCount) invoices • \(formatMoney(paidRevenue, currencyCode: primaryCurrencyCode))")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Unpaid
                                    Button {
                                        showUnpaidInvoices = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .foregroundColor(.orange)
                                                .font(.title2)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Unpaid Invoices")
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                if hasMixedCurrencies {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("\(unpaidCount) invoices")
                                                            .font(.subheadline)
                                                            .foregroundColor(.secondary)
                                                        ForEach(unpaidRevenueByCurrency, id: \.currencyCode) { item in
                                                            Text(formatMoney(item.total, currencyCode: item.currencyCode))
                                                                .font(.subheadline)
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                } else {
                                                    Text("\(unpaidCount) invoices • \(formatMoney(unpaidRevenue, currencyCode: primaryCurrencyCode))")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal)
                            }
                            
                            // C) Revenue by Client
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "person.2")
                                        .foregroundColor(.blue)
                                    Text("Revenue by Client")
                                        .font(.headline)
                                }
                                
                                if revenueByClientWithCurrency.isEmpty {
                                    Text("No client data")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding()
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(revenueByClientWithCurrency, id: \.name) { clientData in
                                            Button {
                                                selectedClient = clientData.name
                                                showClientInvoices = true
                                            } label: {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(clientData.name)
                                                            .font(.headline)
                                                            .foregroundColor(.primary)
                                                        Text("\(clientData.count) invoice\(clientData.count == 1 ? "" : "s")")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    Spacer()
                                                    VStack(alignment: .trailing, spacing: 4) {
                                                        if hasMixedCurrencies {
                                                            ForEach(clientData.totals, id: \.currencyCode) { item in
                                                                Text(formatMoney(item.total, currencyCode: item.currencyCode))
                                                                    .font(.headline)
                                                                    .foregroundColor(.primary)
                                                            }
                                                        } else {
                                                            let total = clientData.totals.reduce(0.0) { $0 + $1.total }
                                                            Text(formatMoney(total, currencyCode: primaryCurrencyCode))
                                                                .font(.headline)
                                                                .foregroundColor(.primary)
                                                        }
                                                    }
                                                    Image(systemName: "chevron.right")
                                                        .foregroundColor(.secondary)
                                                        .font(.caption)
                                                }
                                                .padding()
                                                .background(Color(.systemGray6))
                                                .cornerRadius(12)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            .padding(.horizontal)
                            
                            // D) Monthly Revenue Trend
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Monthly Revenue Trend")
                                        .font(.headline)
                                    Text("Last 6 months")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if hasMixedCurrencies {
                                    VStack(spacing: 12) {
                                        HStack {
                                            Image(systemName: "info.circle")
                                                .foregroundColor(.secondary)
                                            Text("Monthly revenue chart is unavailable for mixed currencies.")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                } else {
                                    Chart {
                                        ForEach(Array(monthlyRevenueData.enumerated()), id: \.offset) { index, data in
                                            BarMark(
                                                x: .value("Month", data.month),
                                                y: .value("Revenue", data.revenue)
                                            )
                                            .foregroundStyle(.blue)
                                        }
                                    }
                                    .frame(height: 200)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    }
                }
            }
            }
            .animation(.easeInOut(duration: 0.25), value: allInvoices.isEmpty)
            .animation(.easeInOut(duration: 0.25), value: currentPeriodInvoices.isEmpty)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: reportBusinessGroupingSignature) { _, _ in
                pruneReportScopeIfNeeded()
                syncReportScopeDisplayNameIfNeeded()
            }
            .sheet(isPresented: $showCustomRangePicker) {
                CustomRangePickerView(startDate: $customStartDate, endDate: $customEndDate)
            }
            .sheet(isPresented: $showClientInvoices) {
                if let clientName = selectedClient {
                    FilteredInvoicesView(
                        invoices: currentPeriodInvoices.filter { $0.clientName == clientName },
                        title: clientName
                    )
                }
            }
            .sheet(isPresented: $showPaidInvoices) {
                FilteredInvoicesView(
                    invoices: currentPeriodInvoices.filter { $0.paidAt != nil },
                    title: "Paid Invoices"
                )
            }
            .sheet(isPresented: $showUnpaidInvoices) {
                FilteredInvoicesView(
                    invoices: currentPeriodInvoices.filter { $0.paidAt == nil },
                    title: "Unpaid Invoices"
                )
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Custom Range Picker View
struct CustomRangePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Start Date") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                }
                
                Section("End Date") {
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                        .onChange(of: startDate) { oldValue, newValue in
                            if endDate < newValue {
                                endDate = newValue
                            }
                        }
                }
            }
            .navigationTitle("Custom Range")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Filtered Invoices View
struct FilteredInvoicesView: View {
    let invoices: [InvoiceModel]
    let title: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            if invoices.isEmpty {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    EmptyStateView(icon: "doc.text", title: "No invoices", subtitle: nil)
                        .transition(.opacity)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: invoices.isEmpty)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            } else {
                List {
                    ForEach(invoices) { invoice in
                        NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                            InvoiceRow(invoice: invoice)
                        }
                    }
                }
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: MyProfileView()) {
                        Label("My Profile", systemImage: "person.crop.circle")
                    }
                }

                Section("App") {
                    NavigationLink(destination: LanguageSettingsView()) {
                        Label("Language", systemImage: "globe")
                    }
                    
                    Picker("Appearance", systemImage: "paintbrush", selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }
                
                Section("Legal") {
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    
                    NavigationLink(destination: TermsOfUseView()) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                }
                
                Section("Account") {
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Log out")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .preferredColorScheme(appearanceMode == "system" ? nil : (appearanceMode == "light" ? .light : .dark))
            .alert("Log out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log out", role: .destructive) {
                    PaywallReset.logout()
                }
            } message: {
                Text("You’ll return to sign in. Your saved Apple profile stays on this device.")
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Version \(version) (\(build))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

// MARK: - Business Profiles View
struct BusinessProfilesView: View {
    @Query(sort: \BusinessProfileModel.name) private var businessProfiles: [BusinessProfileModel]
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchText = ""
    @State private var showCreateBusinessProfile = false
    @State private var selectedBusiness: BusinessProfileModel?
    @State private var businessToDelete: BusinessProfileModel?
    @State private var showDeleteConfirmation = false
    @State private var isSelectionMode = false
    @State private var selectedBusinessIDs = Set<PersistentIdentifier>()
    @State private var showBulkDeleteConfirmation = false
    
    private var activeBusinessProfiles: [BusinessProfileModel] {
        businessProfiles.filter { !$0.isArchived }
    }
    
    private var filteredBusinessProfiles: [BusinessProfileModel] {
        if searchText.isEmpty {
            return activeBusinessProfiles
        }
        return activeBusinessProfiles.filter { profile in
            profile.name.localizedCaseInsensitiveContains(searchText) ||
            profile.email.localizedCaseInsensitiveContains(searchText) ||
            profile.phone.localizedCaseInsensitiveContains(searchText) ||
            profile.taxId.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search businesses...")
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Business profiles list
                if filteredBusinessProfiles.isEmpty {
                    Group {
                        Spacer(minLength: 0)
                        EmptyStateView(
                            icon: "building.2",
                            title: searchText.isEmpty ? "No businesses yet" : "No results",
                            subtitle: searchText.isEmpty ? "Tap + to add one" : "Try adjusting your search"
                        )
                        .transition(.opacity)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                    )
                } else {
                    VStack(spacing: 0) {
                        List {
                            ForEach(filteredBusinessProfiles, id: \.persistentModelID) { profile in
                                if isSelectionMode {
                                    HStack {
                                        Image(systemName: selectedBusinessIDs.contains(profile.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedBusinessIDs.contains(profile.persistentModelID) ? .blue : .gray)
                                            .font(.title3)
                                        
                                        BusinessProfileRow(profile: profile)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if selectedBusinessIDs.contains(profile.persistentModelID) {
                                            selectedBusinessIDs.remove(profile.persistentModelID)
                                        } else {
                                            selectedBusinessIDs.insert(profile.persistentModelID)
                                        }
                                    }
                                } else {
                                    NavigationLink(destination: EditBusinessProfileView(business: profile)) {
                                        BusinessProfileRow(profile: profile)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            businessToDelete = profile
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Archive", systemImage: "archivebox")
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollDismissesKeyboard(.interactively)
                        
                        if isSelectionMode && !selectedBusinessIDs.isEmpty {
                            Button {
                                showBulkDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "archivebox")
                                    Text("Archive Selected (\(selectedBusinessIDs.count))")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                        }
                    }
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.25), value: filteredBusinessProfiles.isEmpty)

            if !isSelectionMode {
                FloatingAddButton {
                    showCreateBusinessProfile = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 12)
            }
            }
            .navigationTitle("My Business")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isSelectionMode {
                            Button("Cancel") {
                                isSelectionMode = false
                                selectedBusinessIDs.removeAll()
                            }
                        } else {
                            Button("Select") {
                                isSelectionMode = true
                            }
                        }
                        
                        if !isSelectionMode {
                            Button {
                                showCreateBusinessProfile = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateBusinessProfile) {
                CreateBusinessProfileView()
            }
            .alert("Archive?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    businessToDelete = nil
                }
                Button("Archive", role: .destructive) {
                    if let business = businessToDelete {
                        deleteBusinessProfile(business)
                    }
                    businessToDelete = nil
                }
            } message: {
                Text("This business will be archived and hidden from active lists.")
            }
            .alert("Archive selected?", isPresented: $showBulkDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    // Do nothing
                }
                Button("Archive", role: .destructive) {
                    deleteSelectedBusinessProfiles()
                }
            } message: {
                Text("Selected businesses will be archived and hidden from active lists.")
            }
        }
    }
    
    private func deleteBusinessProfile(_ business: BusinessProfileModel) {
        withAnimation {
            business.isArchived = true
            business.archivedAt = Date()
            business.updatedAt = Date()
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete business profile: \(error)")
        }
    }
    
    private func deleteSelectedBusinessProfiles() {
        let businessesToDelete = filteredBusinessProfiles.filter { selectedBusinessIDs.contains($0.persistentModelID) }
        
        withAnimation {
            for business in businessesToDelete {
                business.isArchived = true
                business.archivedAt = Date()
                business.updatedAt = Date()
            }
        }
        
        do {
            try modelContext.save()
            isSelectionMode = false
            selectedBusinessIDs.removeAll()
        } catch {
            print("Failed to delete business profiles: \(error)")
        }
    }
}

// MARK: - Business Profile Row
struct BusinessProfileRow: View {
    let profile: BusinessProfileModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo thumbnail
            Group {
                if let logoData = profile.logoData, let uiImage = UIImage(data: logoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "building.2.crop.circle")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Business info
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
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Language Settings View
struct LanguageSettingsView: View {
    var body: some View {
        VStack {
            Text("Language settings coming soon")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .padding(.horizontal)
                
                Text("""
                This is a placeholder privacy policy. In a real application, this would contain detailed information about:
                
                • How we collect and use your data
                • Data storage and security measures
                • Your rights regarding your personal information
                • Third-party services we may use
                • Contact information for privacy concerns
                
                This application stores invoice and business profile data locally on your device using SwiftData. No data is transmitted to external servers without your explicit consent.
                """)
                .font(.body)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms of Use View
struct TermsOfUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Use")
                    .font(.title)
                    .padding(.horizontal)
                
                Text("""
                This is a placeholder terms of use document. In a real application, this would contain:
                
                • Acceptance of terms
                • Description of the service
                • User responsibilities and obligations
                • Intellectual property rights
                • Limitation of liability
                • Dispute resolution procedures
                • Changes to terms
                
                By using this application, you agree to use it responsibly and in accordance with applicable laws and regulations.
                """)
                .font(.body)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MainTabView()
}
