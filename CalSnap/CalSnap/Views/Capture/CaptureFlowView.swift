import SwiftUI
import UIKit
import SwiftData

struct CaptureFlowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var vm = CaptureViewModel()
    @State private var showCameraPhoto = false
    @State private var showCameraVideo = false
    @State private var showLibrary = false

    var body: some View {
        ZStack {
            AuroraBackground()

            switch vm.phase {
            case .choosing:  chooser
            case .analyzing: AnalyzingView(image: vm.previewImage)
            case .review:    AnalysisResultView(vm: vm, onSave: save)
            case .failed(let message): failure(message)
            }
        }
        .sheet(isPresented: $showCameraPhoto) {
            CameraPicker(mode: .photo) { handle($0) }.ignoresSafeArea()
        }
        .sheet(isPresented: $showCameraVideo) {
            CameraPicker(mode: .video) { handle($0) }.ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            LibraryPicker { handle($0) }.ignoresSafeArea()
        }
    }

    // MARK: Chooser

    private var chooser: some View {
        VStack(spacing: Theme.Space.lg) {
            HStack {
                Text("capture.title")
                    .font(Theme.Font.display(26))
                    .foregroundStyle(Theme.textPrimary(scheme))
                Spacer()
                CloseButton { dismiss() }
            }

            Text("capture.subtitle")
                .font(Theme.Font.body(15))
                .foregroundStyle(Theme.textSecondary(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Optional hint
            HintField(text: $vm.hint)

            VStack(spacing: 12) {
                CaptureOption(icon: "camera.fill", title: "capture.photo",
                              subtitle: "capture.photo.sub", gradient: Theme.energyGradient) {
                    showCameraPhoto = true
                }
                CaptureOption(icon: "video.fill", title: "capture.video",
                              subtitle: "capture.video.sub", gradient: Theme.calorieGradient) {
                    showCameraVideo = true
                }
                CaptureOption(icon: "photo.on.rectangle.angled", title: "capture.library",
                              subtitle: "capture.library.sub",
                              gradient: LinearGradient(colors: [Theme.Palette.protein, Theme.Palette.fat],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing)) {
                    showLibrary = true
                }
            }

            if !appState.hasAPIKey {
                Label("capture.noKey", systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Font.caption(12))
                    .foregroundStyle(Theme.Palette.warning)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
        }
        .padding(Theme.Space.md)
        .padding(.top, 12)
    }

    // MARK: Failure

    private func failure(_ message: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Palette.danger)
            Text("capture.failed")
                .font(Theme.Font.title(20))
                .foregroundStyle(Theme.textPrimary(scheme))
            Text(message)
                .font(Theme.Font.body(13))
                .foregroundStyle(Theme.textSecondary(scheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button("action.retry") { vm.phase = .choosing }
                .buttonStyle(PrimaryButtonStyle())
            Button("action.cancel") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.Space.md)
    }

    // MARK: Actions

    private func handle(_ media: PickedMedia) {
        vm.set(media: media)
        Task { await vm.analyze(apiKey: appState.apiKey) }
    }

    private func save() {
        let entry = vm.makeEntry()
        context.insert(entry)
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

// MARK: - Pieces

struct CaptureOption: View {
    @Environment(\.colorScheme) private var scheme
    var icon: String
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    var gradient: LinearGradient
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(gradient)
                        .frame(width: 54, height: 54)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Font.title(17))
                        .foregroundStyle(Theme.textPrimary(scheme))
                    Text(subtitle)
                        .font(Theme.Font.caption(12))
                        .foregroundStyle(Theme.textSecondary(scheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textSecondary(scheme))
            }
            .cardSurface(padding: 14)
        }
        .buttonStyle(.plain)
    }
}

struct HintField: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .foregroundStyle(Theme.Palette.brand)
            TextField("capture.hint", text: $text)
                .font(Theme.Font.body(15))
                .foregroundStyle(Theme.textPrimary(scheme))
        }
        .cardSurface(padding: 14, radius: Theme.Radius.md)
    }
}

struct CloseButton: View {
    @Environment(\.colorScheme) private var scheme
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textSecondary(scheme))
                .frame(width: 36, height: 36)
                .background(Theme.surface(scheme), in: Circle())
        }
    }
}

// MARK: - Analyzing animation

struct AnalyzingView: View {
    @Environment(\.colorScheme) private var scheme
    var image: UIImage?
    @State private var pulse = false

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .fill(Theme.energyGradient.opacity(0.2))
                        .frame(width: 220, height: 220)
                }
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.energyGradient, lineWidth: 3)
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulse ? 1.06 : 0.98)
                    .opacity(pulse ? 0.3 : 1)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
            }
            VStack(spacing: 8) {
                ProgressView().tint(Theme.Palette.brand)
                Text("analyzing.title")
                    .font(Theme.Font.title(19))
                    .foregroundStyle(Theme.textPrimary(scheme))
                Text("analyzing.subtitle")
                    .font(Theme.Font.body(13))
                    .foregroundStyle(Theme.textSecondary(scheme))
            }
            Spacer()
        }
        .padding()
        .onAppear { pulse = true }
    }
}
