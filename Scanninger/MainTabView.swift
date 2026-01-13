//
//  MainTabView.swift
//  Scanninger
//
//  Created by Yeghishe Grigoryan on 13.01.26.
//

import SwiftUI

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

// MARK: - Invoice Model
struct Invoice: Identifiable, Hashable {
    let id = UUID()
    let number: String
    let clientName: String
    let totalAmount: Double
    let status: InvoiceStatus
    let date: Date
    
    enum InvoiceStatus: String, CaseIterable {
        case draft = "Draft"
        case sent = "Sent"
        case paid = "Paid"
        case overdue = "Overdue"
    }
}

// MARK: - Line Item Model
struct LineItem: Identifiable {
    let id = UUID()
    var description: String
    var quantity: Int
    var price: Double
    
    var total: Double {
        Double(quantity) * price
    }
}

// MARK: - InvoicesView
struct InvoicesView: View {
    @State private var searchText = ""
    @State private var selectedStatus: Invoice.InvoiceStatus? = nil
    @State private var showCreateInvoice = false
    @State private var selectedInvoice: Invoice?
    
    // Invoices stored in state
    @State private var invoices: [Invoice] = [
        Invoice(number: "INV-0001", clientName: "Acme Corp", totalAmount: 1200.00, status: .paid, date: Date().addingTimeInterval(-86400 * 5)),
        Invoice(number: "INV-0002", clientName: "Tech Solutions", totalAmount: 850.50, status: .sent, date: Date().addingTimeInterval(-86400 * 3)),
        Invoice(number: "INV-0003", clientName: "Global Industries", totalAmount: 2450.75, status: .draft, date: Date().addingTimeInterval(-86400 * 1)),
        Invoice(number: "INV-0004", clientName: "Digital Services", totalAmount: 650.00, status: .overdue, date: Date().addingTimeInterval(-86400 * 10)),
        Invoice(number: "INV-0005", clientName: "Acme Corp", totalAmount: 320.25, status: .paid, date: Date().addingTimeInterval(-86400 * 7)),
        Invoice(number: "INV-0006", clientName: "Startup Inc", totalAmount: 1500.00, status: .sent, date: Date().addingTimeInterval(-86400 * 2)),
        Invoice(number: "INV-0007", clientName: "Tech Solutions", totalAmount: 980.00, status: .draft, date: Date())
    ]
    
    private var filteredInvoices: [Invoice] {
        var filtered = invoices
        
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
                        
                        ForEach(Invoice.InvoiceStatus.allCases, id: \.self) { status in
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
                    InvoiceRow(invoice: invoice)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedInvoice = invoice
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
                    nextInvoiceNumber: generateNextInvoiceNumber(),
                    onSave: { invoice in
                        invoices.append(invoice)
                    }
                )
            }
            .navigationDestination(item: $selectedInvoice) { invoice in
                InvoiceDetailView(invoice: invoice)
            }
        }
    }
    
    private func generateNextInvoiceNumber() -> String {
        let maxNumber = invoices.compactMap { invoice -> Int? in
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
    let invoice: Invoice
    
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
        return formatter.string(from: invoice.date)
    }
    
    private var formattedAmount: String {
        String(format: "$%.2f", invoice.totalAmount)
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
    
    let nextInvoiceNumber: String
    let onSave: (Invoice) -> Void
    
    @State private var clientName = ""
    @State private var invoiceNumber = ""
    @State private var issueDate = Date()
    @State private var dueDate = Date()
    @State private var lineItems: [LineItem] = [LineItem(description: "", quantity: 1, price: 0.0)]
    @State private var taxPercent: Double = 0.0
    
    private var subtotal: Double {
        lineItems.reduce(0) { $0 + $1.total }
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
                        lineItems.append(LineItem(description: "", quantity: 1, price: 0.0))
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
        lineItems.contains { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty && $0.quantity > 0 && $0.price > 0 }
    }
    
    private func saveInvoice() {
        let invoice = Invoice(
            number: invoiceNumber,
            clientName: clientName,
            totalAmount: total,
            status: .draft,
            date: issueDate
        )
        onSave(invoice)
        dismiss()
    }
}

// MARK: - Line Item Row
struct LineItemRow: View {
    @Binding var item: LineItem
    
    var body: some View {
        VStack(spacing: 8) {
            TextField("Description", text: $item.description)
            
            HStack {
                Text("Qty:")
                    .foregroundColor(.secondary)
                TextField("1", value: $item.quantity, format: .number)
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
                Text("Total: \(String(format: "$%.2f", item.total))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Invoice Detail View
struct InvoiceDetailView: View {
    let invoice: Invoice
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: invoice.date)
    }
    
    private var formattedAmount: String {
        String(format: "$%.2f", invoice.totalAmount)
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
                DetailRow(label: "Date", value: formattedDate)
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
