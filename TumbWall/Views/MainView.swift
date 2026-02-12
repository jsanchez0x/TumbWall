import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = DownloadViewModel()
    @State private var sidebarSelection: SidebarItem? = .download
    
    enum SidebarItem: Int, CaseIterable, Identifiable {
        case download
        case settings
        case about
        
        var id: Int { rawValue }
        
        var title: String {
            switch self {
            case .download: return "Download"
            case .settings: return "Settings"
            case .about: return "About"
            }
        }
        
        var icon: String {
            switch self {
            case .download: return "arrow.down.circle"
            case .settings: return "gear"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List(selection: $sidebarSelection) {
                Section("TumbWall") {
                    ForEach(SidebarItem.allCases) { item in
                        NavigationLink(destination: view(for: item), tag: item, selection: $sidebarSelection) {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            
            // Default View
            view(for: .download)
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if viewModel.isDownloading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
    }
    
    @ViewBuilder
    private func view(for item: SidebarItem?) -> some View {
        switch item {
        case .download, nil:
            DownloadView(viewModel: viewModel)
        case .settings:
            SettingsView()
        case .about:
            Text("TumbWall v1.0\nCreated by Antigravity")
                .multilineTextAlignment(.center)
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Download View Content
struct DownloadView: View {
    @ObservedObject var viewModel: DownloadViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Configuration Area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    Text("New Download")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    GroupBox(label: Label("Source", systemImage: "network")) {
                        VStack(alignment: .leading) {
                            TextField("Tumblr Blog URL (e.g., nasa.tumblr.com)", text: $viewModel.blogUrl)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("The crawler will scan for pages automatically.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(5)
                    }
                    
                    GroupBox(label: Label("Criteria", systemImage: "slider.horizontal.3")) {
                        HStack(alignment: .top, spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("Min Resolution")
                                    .font(.subheadline)
                                Picker("", selection: $viewModel.selectedResolution) {
                                    ForEach(MinResolution.allCases) { res in
                                        Text(res.rawValue).tag(res)
                                    }
                                }
                                .labelsHidden()
                            }
                            
                            if viewModel.selectedResolution == .custom {
                                VStack(alignment: .leading) {
                                    Text("Dimensions")
                                        .font(.subheadline)
                                    HStack {
                                        TextField("W", text: $viewModel.customWidth)
                                            .frame(width: 60)
                                            .textFieldStyle(.roundedBorder)
                                        Text("x")
                                        TextField("H", text: $viewModel.customHeight)
                                            .frame(width: 60)
                                            .textFieldStyle(.roundedBorder)
                                        Text("px")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(5)
                    }
                    
                    GroupBox(label: Label("Destination", systemImage: "folder")) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(viewModel.destinationURL?.path ?? "Select a folder...")
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundColor(viewModel.destinationURL == nil ? .secondary : .primary)
                            
                            Spacer()
                            
                            Button("Browse...") {
                                selectFolder()
                            }
                        }
                        .padding(5)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Console / Logs Area
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Activity Log")
                        .font(.headline)
                    Spacer()
                    if viewModel.isDownloading {
                        Text(viewModel.statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 5)
                
                LogConsoleView(logs: viewModel.logs)
                    .background(Color(NSColor.textBackgroundColor))
            }
            .frame(height: 250)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Footer Action
            HStack {
                VStack(alignment: .leading) {
                    if viewModel.isDownloading || viewModel.progress > 0 {
                        ProgressView(value: viewModel.progress)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 200)
                    }
                }
                
                Spacer()
                
                if viewModel.isDownloading {
                    Button(action: { viewModel.stopDownload() }) {
                        Label("Stop", systemImage: "stop.circle.fill")
                    }
                    .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button(action: {
                        if viewModel.destinationURL == nil {
                            selectFolder()
                        } else {
                            viewModel.startDownload()
                        }
                    }) {
                        Label("Start Download", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canStartDownload)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .background(Material.bar)
        }
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
}

struct LogConsoleView: View {
    let logs: [DownloadViewModel.LogEntry]
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(logs) { log in
                    HStack(alignment: .top, spacing: 8) {
                        Text(dateFormatter.string(from: log.timestamp))
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        
                        Text(log.message)
                            .font(.caption)
                            .foregroundColor(color(for: log.type))
                            .textSelection(.enabled)
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                }
            }
            .listStyle(.plain)
            .onChange(of: logs.count) { _ in
                if let first = logs.first {
                    withAnimation {
                        proxy.scrollTo(first.id, anchor: .top)
                    }
                }
            }
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
        f.dateFormat = "HH:mm:ss"
        return f
    }
}
