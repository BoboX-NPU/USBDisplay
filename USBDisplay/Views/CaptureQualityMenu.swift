import SwiftUI

struct CaptureQualityMenu: View {
  @Bindable var model: AppModel

  var body: some View {
    Menu {
      Picker("Capture Quality", selection: selection) {
        ForEach(CaptureQuality.allCases) { quality in
          Text(quality.title)
            .tag(quality)
        }
      }
      .pickerStyle(.inline)
    } label: {
      Label("Capture Quality: \(model.captureQuality.title)", systemImage: "video.badge.hd")
    }
    .labelStyle(.iconOnly)
    .help("Capture Quality: \(model.captureQuality.title)")
    .accessibilityLabel("Capture Quality")
    .accessibilityValue(model.captureQuality.title)
  }

  private var selection: Binding<CaptureQuality> {
    Binding(
      get: { model.captureQuality },
      set: { model.setCaptureQuality($0) }
    )
  }
}
