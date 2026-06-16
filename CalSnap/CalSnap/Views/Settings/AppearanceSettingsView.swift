import SwiftUI
import UIKit

/// Full appearance customization: theme mode, accent colour, background style,
/// glass amount and app icon. Edits a local draft with a live preview and
/// commits everything on Done.
struct AppearanceSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AppThemeMode = .system
    @State private var accentID = "blue"
    @State private var customColor: Color = Color(hex: 0x2E9CFF)
    @State private var bgID = BackgroundStyle.aurora.rawValue
    @State private var glass = 0.6
    @State private var iconID = "default"
    @State private var photo: UIImage?
    @State private var showPhotoPicker = false
    @State private var suppressColorChange = false

    private var accent: AccentPreset {
        accentID == "custom" ? AccentPreset.custom(customColor) : AccentPreset.by(id: accentID)
    }
    private var bg: BackgroundStyle { BackgroundStyle(rawValue: bgID) ?? .aurora }
    private var accentGradient: LinearGradient {
        LinearGradient(colors: [accent.brandSoft, accent.brand, accent.brandDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    preview
                    themeSection
                    accentSection
                    backgroundSection
                    glassSection
                    iconSection
                    Color.clear.frame(height: 16)
                }
                .padding(Theme.Space.md)
            }
            .background(Theme.background(scheme).ignoresSafeArea())
            .navigationTitle("appearance.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.apply") { commit() }.bold()
                }
            }
            .onAppear { load() }
            .sheet(isPresented: $showPhotoPicker) {
                LibraryPicker { media in
                    if case let .image(img) = media {
                        photo = img
                        bgID = BackgroundStyle.photo.rawValue
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: Live preview

    private var preview: some View {
        ZStack {
            previewBackground
            VStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 10)
                    Circle().trim(from: 0, to: 0.65)
                        .stroke(accentGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("1,820").font(Theme.Font.mono(22)).foregroundStyle(.white)
                }
                .frame(width: 96, height: 96)
                Text("appearance.preview")
                    .font(Theme.Font.caption(12))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(22)
            .background(previewGlass)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .padding(.horizontal, 40)
        }
        .frame(height: 210)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private var previewBackground: some View {
        ZStack {
            (bg == .black ? Color.black : Color(hex: 0x0B0E14))
            if bg == .mesh {
                MeshBackground(scheme: .dark, accent: accent)
            }
            if bg == .photo, let img = photo {
                Image(uiImage: img).resizable().scaledToFill()
                    .overlay(Color.black.opacity(0.35))
            }
            if bg == .graphite {
                LinearGradient(colors: [Color(hex: 0x141A26), Color(hex: 0x0B0E14)],
                               startPoint: .top, endPoint: .bottom)
            }
            let k: Double = bg == .vivid ? 1.4
                : (bg == .black ? 0.5 : ((bg == .graphite || bg == .photo) ? 0 : 1))
            if k > 0 {
                Circle().fill(accent.brand).frame(width: 200).blur(radius: 55)
                    .opacity(0.6 * k).offset(x: -70, y: -50)
                Circle().fill(accent.aurora[2]).frame(width: 170).blur(radius: 55)
                    .opacity(0.5 * k).offset(x: 80, y: 60)
                Circle().fill(accent.aurora[0]).frame(width: 150).blur(radius: 55)
                    .opacity(0.4 * k).offset(x: 60, y: -60)
            }
        }
    }

    private var previewGlass: some View {
        let solid = (1 - glass) * 0.9
        return ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(Color(hex: 0x14181F).opacity(solid))
            Rectangle().fill(LinearGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                startPoint: .top, endPoint: .bottom))
        }
    }

    // MARK: Sections

    private var themeSection: some View {
        section("appearance.mode") {
            HStack(spacing: 8) {
                ForEach(AppThemeMode.allCases) { m in
                    chip(text: LocalizedStringKey(m.titleKey), selected: mode == m) {
                        mode = m
                    }
                }
            }
        }
    }

    private var accentSection: some View {
        section("appearance.accent") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 12)], spacing: 12) {
                ForEach(AccentPreset.presets) { preset in
                    Button {
                        Haptics.tap(); accentID = preset.id
                    } label: {
                        Circle()
                            .fill(LinearGradient(colors: [preset.brandSoft, preset.brandDeep],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 46, height: 46)
                            .overlay(Circle().strokeBorder(.white,
                                lineWidth: accentID == preset.id ? 3 : 0))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                            .shadow(color: preset.brand.opacity(0.5), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Custom colour — a real, clearly tappable ColorPicker.
            HStack(spacing: 12) {
                Circle()
                    .fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                                          center: .center))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                Text("appearance.customColor")
                    .font(Theme.Font.body(15))
                    .foregroundStyle(Theme.textPrimary(scheme))
                if accentID == "custom" {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(accent.brand)
                }
                Spacer()
                ColorPicker("", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
            }
            .padding(.top, 6)
            .onChange(of: customColor) { _, _ in
                if suppressColorChange { return }
                accentID = "custom"
            }
        }
    }

    private var backgroundSection: some View {
        section("appearance.background") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(BackgroundStyle.allCases) { style in
                    chip(text: LocalizedStringKey(bgName(style)), selected: bgID == style.rawValue) {
                        bgID = style.rawValue
                        if style == .photo && photo == nil { showPhotoPicker = true }
                    }
                }
            }
            if bgID == BackgroundStyle.photo.rawValue {
                Button {
                    Haptics.tap(); showPhotoPicker = true
                } label: {
                    Label(photo == nil ? "appearance.choosePhoto" : "appearance.changePhoto",
                          systemImage: "photo.on.rectangle")
                        .font(Theme.Font.caption(13))
                        .foregroundStyle(Theme.Palette.brand)
                }
                .padding(.top, 4)
            }
        }
    }

    private var glassSection: some View {
        section("appearance.glass") {
            HStack(spacing: 12) {
                Image(systemName: "square.fill").foregroundStyle(Theme.textSecondary(scheme))
                Slider(value: $glass, in: 0...1)
                    .tint(accent.brand)
                Image(systemName: "square.on.square.dashed").foregroundStyle(Theme.textSecondary(scheme))
            }
        }
    }

    private var iconSection: some View {
        section("appearance.icon") {
            HStack(spacing: 14) {
                ForEach(AppIconOption.all) { option in
                    Button {
                        Haptics.tap(); iconID = option.id
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: option.colors,
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 54, height: 54)
                                .overlay(
                                    Circle().stroke(.white, lineWidth: 4)
                                        .frame(width: 26, height: 26))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white, lineWidth: iconID == option.id ? 3 : 0))
                            Text(option.name)
                                .font(Theme.Font.caption(10))
                                .foregroundStyle(Theme.textSecondary(scheme))
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Building blocks

    private func section<C: View>(_ title: LocalizedStringKey,
                                  @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.Font.title(16))
                .foregroundStyle(Theme.textPrimary(scheme))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func chip(text: LocalizedStringKey, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            Text(text)
                .font(Theme.Font.caption(13))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(selected ? .white : Theme.textSecondary(scheme))
                .background(Capsule().fill(selected ? AnyShapeStyle(accentGradient)
                                                    : AnyShapeStyle(Theme.chipFill(scheme))))
                .overlay(Capsule().strokeBorder(Theme.glassBorder(scheme),
                                                lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private func bgName(_ s: BackgroundStyle) -> String {
        switch s {
        case .mesh:     return "bg.mesh"
        case .aurora:   return "bg.aurora"
        case .black:    return "bg.black"
        case .graphite: return "bg.graphite"
        case .vivid:    return "bg.vivid"
        case .photo:    return "bg.photo"
        }
    }

    // MARK: Load / commit

    private func load() {
        suppressColorChange = true
        mode = appState.themeMode
        accentID = appState.accentID
        customColor = Color(hex: appState.customAccentHex)
        bgID = appState.backgroundID
        glass = appState.glass
        iconID = AppIconManager.currentID
        photo = AppearanceStore.loadBackgroundPhoto()
        DispatchQueue.main.async { suppressColorChange = false }
    }

    private func commit() {
        // Capture drafts, dismiss first, THEN apply. Applying bumps
        // appearanceVersion which rebuilds the tree via .id — doing that while
        // this sheet is still open breaks SwiftUI's sheet presentation.
        let m = mode, a = accentID, customHex = customColor.hexValue
        let b = bgID, g = glass, ic = iconID, pic = photo
        Haptics.success()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            appState.themeMode = m
            if a == "custom" { appState.customAccentHex = customHex }
            appState.accentID = a
            appState.glass = g
            if b == BackgroundStyle.photo.rawValue {
                appState.setBackgroundPhoto(pic)
            }
            appState.backgroundID = b
            AppIconManager.set(ic == "default" ? nil : ic)
        }
    }
}
