import AppKit

@MainActor
final class SidebarToolbarDelegate: NSObject, NSToolbarDelegate {
  nonisolated static let identifier = NSToolbarItem.Identifier("USBDisplay.SidebarToggle")
  private let item = NSToolbarItem(itemIdentifier: identifier)
  let toolbar = NSToolbar(identifier: "USBDisplay.WindowToolbar")
  var toggle: (() -> Void)?
  private var sidebarIsVisible: Bool?

  override init() {
    super.init()
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.displayMode = .iconOnly
    toolbar.showsBaselineSeparator = false
    toolbar.delegate = self
    item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: nil)
    item.target = self
    item.action = #selector(toggleSidebar)
    item.isNavigational = true
  }

  @objc private func toggleSidebar() { toggle?() }

  func update(visible: Bool) {
    guard sidebarIsVisible != visible else { return }
    sidebarIsVisible = visible
    let label = visible ? "Hide Sidebar" : "Show Sidebar"
    item.label = label
    item.paletteLabel = label
    item.toolTip = label
  }

  nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
  { [Self.identifier] }
  nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
  { [Self.identifier] }
  nonisolated func toolbar(
    _ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    MainActor.assumeIsolated { identifier == Self.identifier ? item : nil }
  }
}
