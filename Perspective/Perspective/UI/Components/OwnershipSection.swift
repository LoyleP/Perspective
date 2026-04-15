import SwiftUI

struct OwnershipSection: View {

    let sources: [Source]

    @State private var selectedOwnerNotes: String?
    @State private var showOwnerNotes = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Qui possède ces médias ?")
                .font(.headline)

            ForEach(ownerGroups.keys.sorted(), id: \.self) { ownerName in
                if let srcs = ownerGroups[ownerName] {
                    ownerRow(ownerName: ownerName, sources: srcs)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sheet(isPresented: $showOwnerNotes) {
            if let notes = selectedOwnerNotes {
                ownerNotesSheet(notes)
            }
        }
    }

    private var ownerGroups: [String: [Source]] {
        let withOwner = sources.filter { $0.ownerName != nil }
        return Dictionary(grouping: withOwner) { $0.ownerName! }
    }

    @ViewBuilder
    private func ownerRow(ownerName: String, sources: [Source]) -> some View {
        let outlets = sources
            .map { $0.name }
            .reduce(into: [String]()) { acc, name in
                if !acc.contains(name) { acc.append(name) }
            }
        let notes = sources.compactMap { $0.ownerNotes }.first

        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ownerName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(outlets.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let notes {
                Button {
                    selectedOwnerNotes = notes
                    showOwnerNotes = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func ownerNotesSheet(_ notes: String) -> some View {
        NavigationStack {
            ScrollView {
                Text(notes)
                    .font(.body)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Propriété des médias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { showOwnerNotes = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
