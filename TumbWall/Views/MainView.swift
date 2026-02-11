import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = DownloadViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("TumbWall Downloader")
                .font(.largeTitle)
                .padding(.top)
            
            // Inputs
            Form {
                Section(header: Text("Configuration")) {
                    TextField("Blog Name or URL (e.g. nasa.tumblr.com)", text: $viewModel.blogUrl)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Min Resolution", selection: $viewModel.selectedResolution) {
                        ForEach(MinResolution.allCases) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    
                    if viewModel.selectedResolution == .custom {
                        HStack(spacing: 12) {
                            TextField("Min Width (px)", text: $viewModel.customWidth)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Text("×")
                                .foregroundColor(.secondary)
                            
                            TextField("Min Height (px)", text: $viewModel.customHeight)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    HStack {
                        Text(viewModel.destinationURL?.path ?? "No folder selected")
                            .truncationMode(.middle)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Select Folder") {
                            selectFolder()
                        }
                    }
                }
            }
            .padding()
            
            // Actions & Progress
            HStack {
                if viewModel.isDownloading {
                    Button("Stop Download") {
                        viewModel.stopDownload()
                    }
                    .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button("Start Download") {
                        if viewModel.destinationURL == nil {
                            selectFolder()
                        } else {
                            viewModel.startDownload()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canStartDownload)
                }
            }
            
            if viewModel.isDownloading || viewModel.progress > 0 {
                VStack(alignment: .leading) {
                    if viewModel.isDownloading && viewModel.progress == 0 {
                        ProgressView()
                            .progressViewStyle(.linear)
                    } else {
                        ProgressView(value: viewModel.progress)
                    }
                    Text(viewModel.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            // Logs Console
            VStack(alignment: .leading) {
                Text("Logs")
                    .font(.headline)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.logs) { log in
                            HStack {
                                Text(dateFormatter.string(from: log.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                
                                Text(log.message)
                                    .font(.caption)
                                    .foregroundColor(color(for: log.type))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            viewModel.destinationURL = panel.url
        }
    }
    
    private func color(for type: DownloadViewModel.LogEntry.LogType) -> Color {
        switch type {
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f
    }
}
