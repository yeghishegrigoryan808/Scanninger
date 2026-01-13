//
//  MainTabView.swift
//  Scanninger
//
//  Created by Yeghishe Grigoryan on 13.01.26.
//

import SwiftUI
import SwiftData

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
    
    @Relationship(deleteRule: .cascade) var items: [LineItemModel]?
    
    init(number: String, clientName: String, statusRaw: String, issueDate: Date, dueDate: Date, taxPercent: Double, createdAt: Date, items: [LineItemModel]? = nil) {
        self.number = number
        self.clientName = clientName
        self.statusRaw = statusRaw
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.taxPercent = taxPercent
        self.createdAt = createdAt
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
    
    let nextInvoiceNumber: String
    
    @State private var clientName = ""
    @State private var invoiceNumber = ""
    @State private var issueDate = Date()
    @State private var dueDate = Date()
    @State private var lineItems: [LineItemData] = [LineItemData(title: "", qty: 1, price: 0.0)]
    @State private var taxPercent: Double = 0.0
    
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
        }
    }
    
    private var isValid: Bool {
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
            Text("Invoice Details")
                .font(.title2)
                .padding()
            
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Invoice Number", value: invoice.number)
                DetailRow(label: "Client Name", value: invoice.clientName)
                DetailRow(label: "Total Amount", value: formattedAmount)
                DetailRow(label: "Status", value: invoice.status.rawValue)
                DetailRow(label: "Issue Date", value: formattedIssueDate)
                DetailRow(label: "Due Date", value: formattedDueDate)
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle("Invoice")
        .navigationBarTitleDisplayMode(.inline)
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

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Settings")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    MainTabView()
}
