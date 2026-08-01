//
//  HistoryView.swift
//  Typeless
//
//  Compact single-column history list.
//

import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared
    @State private var query = ""
    @State private var expandedID: RecordingEntry.ID?
    @State private var copiedID: RecordingEntry.ID?

    private var filtered: [RecordingEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.entries }
        return store.entries.filter {
            $0.transcript.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !store.entries.isEmpty {
                    Button("Clear", role: .destructive) {
                        store.clear()
                        expandedID = nil
                    }
                    .controlSize(.mini)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            if filtered.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(store.entries.isEmpty ? "No history yet" : "No matches")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { entry in
                        entryRow(entry)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            let e = filtered[i]
                            store.delete(e)
                            if expandedID == e.id { expandedID = nil }
                        }
                    }
                }
                .listStyle(.inset)
                .controlSize(.small)
            }
        }
        .frame(width: 380, height: 360)
    }

    @ViewBuilder
    private func entryRow(_ entry: RecordingEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(formatDuration(entry.duration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button {
                    copy(entry)
                } label: {
                    Image(systemName: copiedID == entry.id ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Copy")
            }

            Text(entry.transcript)
                .font(.system(size: 12))
                .lineLimit(expandedID == entry.id ? nil : 2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        expandedID = expandedID == entry.id ? nil : entry.id
                    }
                }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Copy") { copy(entry) }
            Button("Delete", role: .destructive) {
                store.delete(entry)
                if expandedID == entry.id { expandedID = nil }
            }
        }
    }

    private func copy(_ entry: RecordingEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.transcript, forType: .string)
        copiedID = entry.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedID == entry.id { copiedID = nil }
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
