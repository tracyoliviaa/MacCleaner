import SwiftUI

struct DuplicateFinderView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = DuplicateFinderViewModel()
    @State private var pendingGroup: DuplicateGroup?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Duplicate Finder", subtitle: "Choose a folder, compare matching file sizes, then hash candidates.")

            FullDiskAccessNotice()

            HStack {
                Button("Choose Folder", systemImage: "folder") { viewModel.chooseFolder() }
                Button("Home", systemImage: "house") { viewModel.resetToHomeFolder() }
                Button("Scan", systemImage: "magnifyingglass") { viewModel.scan() }
                    .disabled(viewModel.selectedFolder == nil || viewModel.isScanning || viewModel.isCleaning)
                Button(settings.moveToTrash ? "Trash All Extras" : "Delete All Extras", systemImage: settings.moveToTrash ? "trash" : "xmark.bin") { pendingGroup = nil; showTrashAllAlert = true }
                    .disabled(viewModel.duplicateFileCount == 0 || viewModel.isScanning || viewModel.isCleaning)
                if viewModel.isScanning || viewModel.isCleaning { ProgressView().controlSize(.small) }
                Spacer()
                Text("Extras: \(viewModel.duplicateFileCount)").foregroundStyle(.secondary)
                Text("Can Remove: \(Formatters.fileSize(viewModel.recoverableSize))").foregroundStyle(.secondary)
            }

            if let selectedFolder = viewModel.selectedFolder {
                Text(selectedFolder.path).font(.callout).foregroundStyle(.secondary).lineLimit(1)
            }

            if viewModel.isCleaning {
                ProgressView(value: viewModel.progress)
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }

            if viewModel.groups.isEmpty, !viewModel.isScanning {
                EmptyStateView(text: "Click Scan to look for duplicates")
                    .frame(minHeight: 280)
            } else {
                List(viewModel.groups) { group in
                    Section {
                        ForEach(Array(group.files.enumerated()), id: \.element.id) { index, file in
                            HStack {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(file.name)
                                        if index == 0 {
                                            Text("Kept")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Text(file.path).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Formatters.fileSize(file.size)).foregroundStyle(.secondary)
                                Button("Reveal", systemImage: "finder") { viewModel.reveal(file) }
                            }
                        }
                    } header: {
                        HStack {
                            Text("\(group.files.count) matching files")
                            Text("Can remove \(Formatters.fileSize(group.recoverableSize))")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button(settings.moveToTrash ? "Trash Extras" : "Delete Extras", systemImage: settings.moveToTrash ? "trash" : "xmark.bin") { pendingGroup = group }
                                .disabled(viewModel.isCleaning)
                        }
                    }
                }
            }
        }
        .padding(28)
        .alert(settings.moveToTrash ? "Trash duplicate extras?" : "Permanently delete duplicate extras?", isPresented: Binding(
            get: { pendingGroup != nil },
            set: { if !$0 { pendingGroup = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingGroup = nil }
            Button(settings.moveToTrash ? "Move Extras to Trash" : "Delete Extras Forever", role: .destructive) {
                if let pendingGroup {
                    viewModel.cleanDuplicates(in: pendingGroup, mode: settings.moveToTrash ? .trash : .permanent)
                }
                pendingGroup = nil
            }
        } message: {
            Text("The first file in the group will be kept.")
        }
        .alert(settings.moveToTrash ? "Trash all duplicate extras?" : "Permanently delete all duplicate extras?", isPresented: $showTrashAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button(settings.moveToTrash ? "Move All Extras to Trash" : "Delete All Extras Forever", role: .destructive) {
                viewModel.cleanAllDuplicateExtras(mode: settings.moveToTrash ? .trash : .permanent)
            }
        } message: {
            Text(settings.moveToTrash ? "MacCleaner will keep the first file in each group and move the rest to Trash." : "This cannot be undone. The first file in each group will be kept.")
        }
    }

    @State private var showTrashAllAlert = false
}
