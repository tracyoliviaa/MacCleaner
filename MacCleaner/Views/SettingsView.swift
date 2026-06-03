import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var newExclusion = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "Settings", subtitle: "Tune scanning, cleanup behavior, and ignored paths.")

            FullDiskAccessNotice()

            Toggle("Move cleanup items to Trash", isOn: $settings.moveToTrash)
            Toggle("Auto-scan on launch", isOn: $settings.autoScanOnLaunch)

            VStack(alignment: .leading) {
                Text("Large file threshold: \(Int(settings.largeFileThresholdMB)) MB")
                Slider(value: $settings.largeFileThresholdMB, in: 10...500, step: 5)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Exclusions").font(.headline)
                HStack {
                    TextField("/path/to/ignore", text: $newExclusion)
                    Button("Add", systemImage: "plus") {
                        settings.addExclusion(newExclusion)
                        newExclusion = ""
                    }
                    Button("Choose Folder", systemImage: "folder") {
                        chooseExclusionFolder()
                    }
                }

                List {
                    ForEach(settings.exclusions, id: \.self) { path in
                        HStack {
                            Text(path)
                            Spacer()
                            Button("Remove", systemImage: "minus.circle") {
                                settings.exclusions.removeAll { $0 == path }
                            }
                        }
                    }
                }
                .frame(minHeight: 180)
            }

            Spacer()
        }
        .padding(28)
    }

    private func chooseExclusionFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.addExclusion(url.path)
        }
    }
}
