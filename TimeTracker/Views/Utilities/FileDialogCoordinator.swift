import AppKit
import UniformTypeIdentifiers

@MainActor
enum FileDialogCoordinator {
    static func showSavePanel(
        title: String,
        fileName: String,
        allowedContentTypes: [UTType] = [.json],
        level: NSWindow.Level = .floating,
        completion: @escaping (URL) -> Void
    ) {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = fileName
        panel.allowedContentTypes = allowedContentTypes
        panel.level = level
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            completion(url)
        }
    }

    static func showOpenPanel(
        title: String,
        canChooseFiles: Bool = true,
        canChooseDirectories: Bool = false,
        canCreateDirectories: Bool = false,
        allowedContentTypes: [UTType]? = nil,
        directoryURL: URL? = nil,
        prompt: String? = nil,
        level: NSWindow.Level = .floating,
        completion: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = canChooseFiles
        panel.canChooseDirectories = canChooseDirectories
        panel.canCreateDirectories = canCreateDirectories
        panel.allowsMultipleSelection = false
        if let types = allowedContentTypes {
            panel.allowedContentTypes = types
        }
        if let dir = directoryURL {
            panel.directoryURL = dir
        }
        if let prompt = prompt {
            panel.prompt = prompt
        }
        panel.level = level
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            completion(url)
        }
    }
}
