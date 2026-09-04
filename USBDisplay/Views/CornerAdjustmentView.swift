import SwiftUI

@MainActor
struct CornerAdjustmentView: View {
  let device: DisplayDevice
  let aspectRatio: Double?
  @Bindable var preferences: CornerRadiusPreferences

  @Environment(\.dismiss) private var dismiss
  @State private var mode: CornerAdjustmentMode
  @State private var customFraction: Double

  init(
    device: DisplayDevice,
    aspectRatio: Double?,
    preferences: CornerRadiusPreferences
  ) {
    self.device = device
    self.aspectRatio = aspectRatio
    self.preferences = preferences

    let automaticFraction = DisplayCornerProfileResolver.automaticFraction(
      for: device,
      aspectRatio: aspectRatio
    )
    let override = preferences.overrideFraction(for: device.id)
    _mode = State(initialValue: override == nil ? .automatic : .custom)
    _customFraction = State(initialValue: override ?? automaticFraction)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Adjust Screen Corners")
          .font(.title2.weight(.semibold))
        Text(device.name)
          .foregroundStyle(.secondary)
      }

      cornerPreview

      Picker("Corner Radius", selection: $mode) {
        ForEach(CornerAdjustmentMode.allCases) { mode in
          Text(mode.label).tag(mode)
        }
      }
      .pickerStyle(.segmented)

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(mode == .automatic ? "Automatic Radius" : "Custom Radius")
          Spacer()
          Text(resolvedFraction, format: .percent.precision(.fractionLength(1)))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }

        Slider(
          value: $customFraction,
          in: 0...DisplayCornerProfileResolver.maximumFraction,
          step: 0.005
        )
        .disabled(mode == .automatic)
      }

      HStack {
        Button("Reset to Automatic") {
          mode = .automatic
        }
        .disabled(mode == .automatic)

        Spacer()

        Button("Done") {
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(22)
    .frame(width: 360)
    .onChange(of: mode) { _, newMode in
      switch newMode {
      case .automatic:
        preferences.resetOverride(for: device.id)
        customFraction = automaticFraction
      case .custom:
        preferences.setOverrideFraction(customFraction, for: device.id)
      }
    }
    .onChange(of: customFraction) { _, fraction in
      guard mode == .custom else { return }
      preferences.setOverrideFraction(fraction, for: device.id)
    }
  }

  private var cornerPreview: some View {
    GeometryReader { geometry in
      let shortSide = min(geometry.size.width, geometry.size.height)
      let radius = DisplayCornerProfileResolver.cornerRadius(
        shortSide: shortSide,
        fraction: resolvedFraction
      )

      RoundedRectangle(cornerRadius: radius, style: .continuous)
        .fill(
          LinearGradient(
            colors: [.blue, .indigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay {
          Image(systemName: device.kind == .iPad ? "ipad" : "iphone")
            .font(.system(size: 34, weight: .light))
            .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .aspectRatio(previewAspectRatio, contentMode: .fit)
    .frame(maxWidth: .infinity)
    .frame(height: 150)
  }

  private var automaticFraction: Double {
    DisplayCornerProfileResolver.automaticFraction(
      for: device,
      aspectRatio: aspectRatio
    )
  }

  private var resolvedFraction: Double {
    mode == .automatic ? automaticFraction : customFraction
  }

  private var previewAspectRatio: Double {
    if let longAspect = DisplayCornerProfileResolver.normalizedLongAspect(aspectRatio) {
      return 1 / longAspect
    }
    return device.kind == .iPad ? 3.0 / 4.0 : 9.0 / 19.5
  }
}

private enum CornerAdjustmentMode: String, CaseIterable, Identifiable {
  case automatic
  case custom

  var id: String { rawValue }

  var label: String {
    switch self {
    case .automatic:
      "Automatic"
    case .custom:
      "Custom"
    }
  }
}
