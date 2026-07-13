import SwiftUI
import UIKit

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// MARK: - Primary button

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(Theme.accentGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled && !isLoading ? 1 : 0.5)
        }
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Refresh toolbar button

/// A toolbar refresh button that spins while loading and re-fetches on tap.
struct RefreshButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            if isLoading {
                ProgressView().tint(Theme.accentCyan)
            } else {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(Theme.accentGradient)
                    .fontWeight(.semibold)
            }
        }
        .disabled(isLoading)
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage).font(.caption2) }
                Text(title).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .white : Theme.textSecondary)
            .background {
                if isSelected {
                    Capsule().fill(Theme.accentGradient)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().strokeBorder(Theme.cardStroke, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = Theme.accentCyan

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentGradient)
                .padding(.bottom, 4)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Error state

struct ErrorStateView: View {
    let error: APIError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: error.symbol)
                .font(.system(size: 44))
                .foregroundStyle(Theme.expired)
            Text("error.title".loc)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(error.errorDescription ?? "")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Haptics.tap(); retry()
            } label: {
                Label("common.retry".loc, systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .foregroundStyle(Theme.textPrimary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Skeleton loader

struct SkeletonBlock: View {
    var height: CGFloat = 72
    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(height: height)
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.12), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .offset(x: shimmer ? 220 : -220)
                .mask(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
    }
}

struct SkeletonList: View {
    var count: Int = 5
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in SkeletonBlock() }
        }
        .padding(.horizontal)
    }
}

// MARK: - Toast

struct ToastData: Equatable {
    let message: String
    var symbol: String = "checkmark.circle.fill"
}

struct ToastView: View {
    let toast: ToastData
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.symbol)
                .foregroundStyle(Theme.accentGradient)
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}

/// Attaches a transient toast that auto-dismisses.
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastData?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast {
                ToastView(toast: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Haptics.success()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(Theme.spring) { self.toast = nil }
                        }
                    }
            }
        }
        .animation(Theme.spring, value: toast)
    }
}

extension View {
    func toast(_ toast: Binding<ToastData?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Screen background

struct ScreenBackground: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            // Subtle accent glows
            Circle()
                .fill(Theme.accentIndigo.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 120)
                .offset(x: -140, y: -260)
            Circle()
                .fill(Theme.accentCyan.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 120)
                .offset(x: 160, y: 320)
        }
    }
}
