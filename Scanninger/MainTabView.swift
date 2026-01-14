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
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
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
    var logoData: Data?
    
    init(name: String, address: String, phone: String, email: String, createdAt: Date = Date(), updatedAt: Date = Date(), logoData: Data? = nil) {
        self.name = name
        self.address = address
        self.phone = phone
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.logoData = logoData
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
    var paidAt: Date?
    
    // Business snapshot fields (stored on invoice)
    var businessName: String
    var businessAddress: String
    var businessPhone: String
    var businessEmail: String
    var businessLogoData: Data?
    
    // Optional relationship (no annotations - manually managed)
    var businessProfile: BusinessProfileModel?
    
    @Relationship(deleteRule: .cascade) var items: [LineItemModel]?
    
    init(number: String, clientName: String, statusRaw: String, issueDate: Date, dueDate: Date, taxPercent: Double, createdAt: Date, business: BusinessProfileModel? = nil, items: [LineItemModel]? = nil, paidAt: Date? = nil, businessName: String = "", businessAddress: String = "", businessPhone: String = "", businessEmail: String = "", businessLogoData: Data? = nil) {
        self.number = number
        self.clientName = clientName
        self.statusRaw = statusRaw
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.taxPercent = taxPercent
        self.createdAt = createdAt
        self.businessProfile = business
        self.items = items
        self.paidAt = paidAt
        self.businessName = businessName
        self.businessAddress = businessAddress
        self.businessPhone = businessPhone
        self.businessEmail = businessEmail
        self.businessLogoData = businessLogoData
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
    
    var displayBusinessLogoData: Data? {
        businessLogoData
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
    @State private var selectedFilter: String? = nil // "Unpaid" or "Paid" or nil for All
    @State private var showCreateInvoice = false
    @State private var selectedInvoice: InvoiceModel?
    
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
                
                // Invoices list
                List {
                    ForEach(filteredInvoices) { invoice in
                        NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                            InvoiceRow(invoice: invoice)
                        }
                    }
                    .onDelete(perform: deleteInvoices)
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
    
    private func deleteInvoices(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredInvoices[index])
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete invoice: \(error)")
        }
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
        invoice.isPaid ? .green : .orange
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

// MARK: - Create Invoice View
struct CreateInvoiceView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessProfileModel.name) private var businessProfiles: [BusinessProfileModel]
    
    let nextInvoiceNumber: String
    
    @State private var selectedBusiness: BusinessProfileModel?
    @State private var useManualEntry = false
    @State private var manualBusinessName = ""
    @State private var manualBusinessAddress = ""
    @State private var manualBusinessPhone = ""
    @State private var manualBusinessEmail = ""
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
                    
                    Button("Add Business Profile") {
                        showCreateBusinessProfile = true
                    }
                    .buttonStyle(.bordered)
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
                CreateBusinessProfileView { newProfile in
                    selectedBusiness = newProfile
                }
            }
        }
    }
    
    private var isValid: Bool {
        let hasBusiness = useManualEntry ? !manualBusinessName.trimmingCharacters(in: .whitespaces).isEmpty : selectedBusiness != nil
        return hasBusiness &&
        !clientName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !invoiceNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        lineItems.contains { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty && $0.qty > 0 && $0.price > 0 }
    }
    
    private func saveInvoice() {
        let lineItemModels = lineItems.map { item in
            LineItemModel(title: item.title, qty: item.qty, price: item.price)
        }
        
        var finalBusinessProfile: BusinessProfileModel?
        var snapshotName = ""
        var snapshotAddress = ""
        var snapshotPhone = ""
        var snapshotEmail = ""
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
        } else if let selected = selectedBusiness {
            // Use selected profile - copy to snapshot
            finalBusinessProfile = selected
            snapshotName = selected.name
            snapshotAddress = selected.address
            snapshotPhone = selected.phone
            snapshotEmail = selected.email
            snapshotLogoData = selected.logoData
        }
        
        let invoice = InvoiceModel(
            number: invoiceNumber,
            clientName: clientName,
            statusRaw: "Unpaid",
            issueDate: issueDate,
            dueDate: dueDate,
            taxPercent: taxPercent,
            createdAt: Date(),
            business: finalBusinessProfile,
            items: lineItemModels,
            paidAt: nil
        )
        
        // Assign snapshot fields and businessProfile
        invoice.businessProfile = finalBusinessProfile
        invoice.businessName = snapshotName
        invoice.businessAddress = snapshotAddress
        invoice.businessPhone = snapshotPhone
        invoice.businessEmail = snapshotEmail
        invoice.businessLogoData = snapshotLogoData
        
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
    
    let invoice: InvoiceModel
    
    @State private var selectedBusiness: BusinessProfileModel?
    @State private var clientName = ""
    @State private var invoiceNumber = ""
    @State private var issueDate = Date()
    @State private var dueDate = Date()
    @State private var lineItems: [LineItemData] = []
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
                    
                    Button("Add Business Profile") {
                        showCreateBusinessProfile = true
                    }
                    .buttonStyle(.bordered)
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
        }
    }
    
    private var isValid: Bool {
        selectedBusiness != nil &&
        !clientName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !invoiceNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        lineItems.contains { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty && $0.qty > 0 && $0.price > 0 }
    }
    
    private func loadInvoiceData() {
        selectedBusiness = invoice.businessProfile
        clientName = invoice.clientName
        invoiceNumber = invoice.number
        issueDate = invoice.issueDate
        dueDate = invoice.dueDate
        taxPercent = invoice.taxPercent
        
        // Load line items
        if let items = invoice.items {
            lineItems = items.map { item in
                LineItemData(title: item.title, qty: item.qty, price: item.price)
            }
        } else {
            lineItems = [LineItemData(title: "", qty: 1, price: 0.0)]
        }
    }
    
    private func saveInvoice() {
        // Delete old line items
        if let oldItems = invoice.items {
            for item in oldItems {
                modelContext.delete(item)
            }
        }
        
        // Create new line items
        let newLineItems = lineItems.map { item in
            LineItemModel(title: item.title, qty: item.qty, price: item.price)
        }
        
        // Update invoice properties
        if let selected = selectedBusiness {
            invoice.businessProfile = selected
            // Update snapshot fields
            invoice.businessName = selected.name
            invoice.businessAddress = selected.address
            invoice.businessPhone = selected.phone
            invoice.businessEmail = selected.email
            invoice.businessLogoData = selected.logoData
        }
        invoice.clientName = clientName
        invoice.number = invoiceNumber
        invoice.issueDate = issueDate
        invoice.dueDate = dueDate
        invoice.taxPercent = taxPercent
        invoice.items = newLineItems
        
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
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var shareItem: ShareItem?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var showEditInvoice = false
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
        String(format: "$%.2f", invoice.total)
    }
    
    var body: some View {
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
            
            Text("Invoice Details")
                .font(.title2)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Invoice Number", value: invoice.number)
                DetailRow(label: "Client Name", value: invoice.clientName)
                DetailRow(label: "Total Amount", value: formattedAmount)
                DetailRow(label: "Status", value: invoice.statusText)
                DetailRow(label: "Issue Date", value: formattedIssueDate)
                DetailRow(label: "Due Date", value: formattedDueDate)
                if invoice.isPaid, let paidAt = invoice.paidAt {
                    DetailRow(label: "Paid on", value: formatPaidDate(paidAt))
                }
            }
            .padding()
            
            // Mark as Paid/Unpaid Button
            Button(action: {
                togglePaidStatus()
            }) {
                HStack {
                    Image(systemName: invoice.isPaid ? "xmark.circle" : "checkmark.circle")
                    Text(invoice.isPaid ? "Mark as Unpaid" : "Mark as Paid")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(invoice.isPaid ? Color.orange : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Create PDF Button
            Button(action: {
                showTemplateSelection = true
            }) {
                HStack {
                    Image(systemName: "doc.fill")
                    Text("Create PDF")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Delete Invoice Button
            Button(action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Invoice")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
        }
        .navigationTitle("Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showEditInvoice = true
                }
            }
        }
        .sheet(isPresented: $showEditInvoice) {
            EditInvoiceView(invoice: invoice)
        }
        .sheet(isPresented: $showTemplateSelection) {
            TemplateSelectionView(invoice: invoice) { template in
                createPDF(with: template)
            }
        }
        .sheet(item: Binding(
            get: { pdfURL.map { PDFPreviewItem(url: $0) } },
            set: { pdfURL = $0?.url }
        )) { item in
            PDFPreviewView(pdfURL: item.url)
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
enum PDFTemplate: String, CaseIterable {
    case classic = "Classic"
    case modern = "Modern"
    case minimal = "Minimal"
}

// MARK: - PDF Preview Item
struct PDFPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Template Selection View
struct TemplateSelectionView: View {
    @Environment(\.dismiss) var dismiss
    let invoice: InvoiceModel
    let onSelect: (PDFTemplate) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(PDFTemplate.allCases, id: \.self) { template in
                    Button(action: {
                        onSelect(template)
                        dismiss()
                    }) {
                        HStack {
                            Text(template.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Select Template")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - PDF Preview View
struct PDFPreviewView: View {
    let pdfURL: URL
    @Environment(\.dismiss) var dismiss
    @State private var shareItem: ShareItem?
    
    var body: some View {
        NavigationStack {
            PDFKitView(url: pdfURL)
                .navigationTitle("PDF Preview")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
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
    
    // Template-specific styling
    let headerFontSize: CGFloat
    let titleFontSize: CGFloat
    let bodyFontSize: CGFloat
    let spacing: CGFloat
    
    switch template {
    case .classic:
        headerFontSize = 20
        titleFontSize = 28
        bodyFontSize = 12
        spacing = 20
    case .modern:
        headerFontSize = 16
        titleFontSize = 32
        bodyFontSize = 11
        spacing = 16
    case .minimal:
        headerFontSize = 14
        titleFontSize = 20
        bodyFontSize = 10
        spacing = 12
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
            let textHeight = headerFontSize + CGFloat(textLines - 1) * lineHeight
            
            // Draw business info
            drawText(businessName, at: CGPoint(x: businessInfoX, y: businessInfoY), font: .boldSystemFont(ofSize: headerFontSize), width: contentWidth - (businessInfoX - margin))
            if !businessAddress.isEmpty {
                drawText(businessAddress, at: CGPoint(x: businessInfoX, y: businessInfoY + lineHeight), font: .systemFont(ofSize: bodyFontSize), width: contentWidth - (businessInfoX - margin))
            }
            if !businessPhone.isEmpty {
                drawText(businessPhone, at: CGPoint(x: businessInfoX, y: businessInfoY + lineHeight * 2), font: .systemFont(ofSize: bodyFontSize), width: contentWidth - (businessInfoX - margin))
            }
            if !businessEmail.isEmpty {
                drawText(businessEmail, at: CGPoint(x: businessInfoX, y: businessInfoY + lineHeight * 3), font: .systemFont(ofSize: bodyFontSize), width: contentWidth - (businessInfoX - margin))
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
        yPosition += spacing * 1.5
        
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
        let items = invoice.items ?? []
        for item in items {
            let itemTotal = Double(item.qty) * item.price
            drawText(item.title, at: CGPoint(x: margin, y: yPosition), font: detailFont, width: itemColumnWidth)
            drawText("\(item.qty)", at: CGPoint(x: margin + itemColumnWidth, y: yPosition), font: detailFont, width: qtyColumnWidth)
            drawText(String(format: "$%.2f", item.price), at: CGPoint(x: margin + itemColumnWidth + qtyColumnWidth, y: yPosition), font: detailFont, width: priceColumnWidth)
            drawText(String(format: "$%.2f", itemTotal), at: CGPoint(x: margin + itemColumnWidth + qtyColumnWidth + priceColumnWidth, y: yPosition), font: detailFont, width: totalColumnWidth)
            yPosition += spacing
        }
        
        yPosition += spacing
        
        // Totals section
        let totalsY = yPosition
        let totalsStartX = margin + itemColumnWidth + qtyColumnWidth
        let totalsWidth = priceColumnWidth + totalColumnWidth
        let labelWidth = totalsWidth * 0.6
        let valueWidth = totalsWidth * 0.4
        
        drawText("Subtotal:", at: CGPoint(x: totalsStartX, y: totalsY), font: detailFont, alignment: .right, width: labelWidth)
        drawText(String(format: "$%.2f", invoice.subtotal), at: CGPoint(x: totalsStartX + labelWidth, y: totalsY), font: detailFont, alignment: .right, width: valueWidth)
        yPosition += spacing
        
        drawText("Tax (\(String(format: "%.1f", invoice.taxPercent))%):", at: CGPoint(x: totalsStartX, y: yPosition), font: detailFont, alignment: .right, width: labelWidth)
        let taxAmount = invoice.subtotal * (invoice.taxPercent / 100.0)
        drawText(String(format: "$%.2f", taxAmount), at: CGPoint(x: totalsStartX + labelWidth, y: yPosition), font: detailFont, alignment: .right, width: valueWidth)
        yPosition += spacing
        
        drawText("Total:", at: CGPoint(x: totalsStartX, y: yPosition), font: .boldSystemFont(ofSize: bodyFontSize + 2), alignment: .right, width: labelWidth)
        drawText(String(format: "$%.2f", invoice.total), at: CGPoint(x: totalsStartX + labelWidth, y: yPosition), font: .boldSystemFont(ofSize: bodyFontSize + 2), alignment: .right, width: valueWidth)
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
    
    var onSave: ((BusinessProfileModel) -> Void)?
    
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var logoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    
    init(onSave: ((BusinessProfileModel) -> Void)? = nil) {
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Logo") {
                    if let logoData = logoData, let uiImage = UIImage(data: logoData) {
                        HStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                            
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
            updatedAt: Date(),
            logoData: logoData
        )
        
        modelContext.insert(business)
        
        do {
            try modelContext.save()
            onSave?(business)
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
    @State private var logoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    
    init(business: BusinessProfileModel) {
        self.business = business
        _name = State(initialValue: business.name)
        _address = State(initialValue: business.address)
        _phone = State(initialValue: business.phone)
        _email = State(initialValue: business.email)
        _logoData = State(initialValue: business.logoData)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Logo") {
                    if let logoData = logoData, let uiImage = UIImage(data: logoData) {
                        HStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                            
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
        business.logoData = logoData
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

// MARK: - Profile View
struct ProfileView: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Business") {
                    NavigationLink(destination: BusinessProfilesView()) {
                        Label("Business Profiles", systemImage: "building.2")
                    }
                }
                
                Section("App") {
                    NavigationLink(destination: LanguageSettingsView()) {
                        Label("Language", systemImage: "globe")
                    }
                    
                    Picker("Appearance", selection: $appearanceMode) {
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
            .navigationTitle("Profile")
            .preferredColorScheme(appearanceMode == "system" ? nil : (appearanceMode == "light" ? .light : .dark))
            .alert("Logout", isPresented: $showLogoutAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Logout coming soon")
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
    
    @State private var showCreateBusinessProfile = false
    @State private var selectedBusiness: BusinessProfileModel?
    
    var body: some View {
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
    
    private func deleteBusinessProfiles(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let businessToDelete = businessProfiles[index]
                
                // Find all invoices referencing this business profile and set businessProfile to nil
                let descriptor = FetchDescriptor<InvoiceModel>()
                if let allInvoices = try? modelContext.fetch(descriptor) {
                    for invoice in allInvoices {
                        if invoice.businessProfile == businessToDelete {
                            invoice.businessProfile = nil
                        }
                    }
                }
                
                modelContext.delete(businessToDelete)
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
