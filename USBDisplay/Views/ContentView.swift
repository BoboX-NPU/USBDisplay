import SwiftUI

struct ContentView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationSplitView(columnVisibility: columnVisibility) {
      SidebarView(model: model)
    } detail: {
      DisplayCanvasView(model: model)
    }
    .navigationSplitViewStyle(.balanced)
    .navigationTitle("USB Display")
    .toolbar {
      ToolbarItem(placement: .principal) {
        ConnectionStatusView(status: model.status)
      }

      if #available(macOS 26, *) {
        ToolbarSpacer(.fixed, placement: .primaryAction)
      }

      ToolbarItem(placement: .primaryAction) {
        CaptureQualityMenu(model: model)
      }

      ToolbarItem(placement: .primaryAction) {
        Button(action: model.requestFullScreenToggle) {
          Label("Enter Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
        }
        .labelStyle(.iconOnly)
        .help("Enter Full Screen")
      }
    }
    .toolbar(model.isFullScreen ? .hidden : .visible, for: .windowToolbar)
    .onAppear {
      model.start()
      model.registerActivity()
    }
    .onDisappear {
      model.stop()
    }
  }

  private var columnVisibility: Binding<NavigationSplitViewVisibility> {
    Binding(
      get: { model.columnVisibility },
      set: { visibility in
        model.setColumnVisibility(visibility)
      }
    )
  }
}
