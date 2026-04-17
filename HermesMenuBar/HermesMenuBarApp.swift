import SwiftUI
import AppKit

@main
struct HermesMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var chatViewModel: ChatViewModel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 延迟初始化 ViewModel
        chatViewModel = ChatViewModel()
        
        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: "Hermes Chat")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // 创建弹出窗口
        if let viewModel = chatViewModel {
            popover = NSPopover()
            popover?.contentSize = NSSize(width: 1040, height: 760)
            popover?.behavior = .semitransient
            popover?.animates = true
            let hostingController = NSHostingController(rootView: ChatView(viewModel: viewModel))
            hostingController.view.appearance = NSAppearance(named: .darkAqua)
            popover?.contentViewController = hostingController
        }
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover?.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
