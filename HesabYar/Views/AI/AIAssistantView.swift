import SwiftUI
import SwiftData

struct AIAssistantView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var expenses: [Expense]
    @State private var aiViewModel = AIViewModel()
    @State private var showingSettings = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modeBar

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if aiViewModel.messages.isEmpty { welcomeSection }

                            ForEach(aiViewModel.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 80)
                    }
                    .onChange(of: aiViewModel.messages.count) {
                        if let last = aiViewModel.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                inputArea
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(settings.t("AI Assistant", "دستیار هوشمند"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !aiViewModel.messages.isEmpty {
                        Button(settings.t("Clear", "پاک کردن")) {
                            aiViewModel.clearChat()
                        }
                        .foregroundStyle(.red)
                        .font(.subheadline)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                AIKeysView(viewModel: aiViewModel)
            }
        }
    }

    // MARK: - Mode Bar

    private var modeBar: some View {
        HStack(spacing: 12) {
            Button {
                aiViewModel.isOnlineMode.toggle()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(aiViewModel.isOnlineMode && aiViewModel.hasApiKey ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(aiViewModel.isOnlineMode && aiViewModel.hasApiKey
                         ? "\(settings.t("Online", "آنلاین")) · \(aiViewModel.provider.shortName)"
                         : aiViewModel.isOnlineMode && !aiViewModel.hasApiKey
                           ? settings.t("Needs API Key", "نیاز به API Key")
                           : settings.t("Offline Mode", "آفلاین"))
                        .font(.caption).fontWeight(.medium)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }

            Spacer()

            if !aiViewModel.hasApiKey {
                Button { showingSettings = true } label: {
                    Text(settings.t("Set API Key", "تنظیم API Key"))
                        .font(.caption)
                        .foregroundStyle(settings.theme.primary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Welcome

    private var welcomeSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 56))
                    .foregroundStyle(settings.theme.primary)

                VStack(spacing: 6) {
                    Text(settings.t("HesabYar AI", "دستیار مالی حسابیار"))
                        .font(.title3).fontWeight(.bold)
                    Text(aiViewModel.isOnlineMode && aiViewModel.hasApiKey
                         ? settings.t("Connected to \(aiViewModel.provider.shortName)", "متصل به \(aiViewModel.provider.shortName)")
                         : settings.t("Offline mode — no internet needed", "حالت آفلاین — بدون نیاز به اینترنت"))
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text(settings.t("Suggested:", "سوالات پیشنهادی:"))
                    .font(.caption).foregroundStyle(.secondary).padding(.leading, 4)

                ForEach(aiViewModel.suggestedQuestions, id: \.self) { question in
                    Button {
                        aiViewModel.inputText = question
                        Task { await aiViewModel.sendMessage(expenses: expenses) }
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.fill")
                                .font(.caption).foregroundStyle(settings.theme.primary)
                            Text(question).font(.subheadline).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField(settings.t("Type a message...", "پیامت رو بنویس..."),
                          text: Binding(
                              get: { aiViewModel.inputText },
                              set: { aiViewModel.inputText = $0 }
                          ),
                          axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($isInputFocused)

                Button {
                    Task { await aiViewModel.sendMessage(expenses: expenses) }
                } label: {
                    Image(systemName: aiViewModel.isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(aiViewModel.inputText.isEmpty ? .secondary : settings.theme.primary)
                }
                .disabled(aiViewModel.inputText.isEmpty || aiViewModel.isLoading)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    @Environment(AppSettings.self) private var settings
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 50) }

            if !message.isUser {
                ZStack {
                    Circle().fill(settings.theme.primary.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: "brain").font(.caption).foregroundStyle(settings.theme.primary)
                }
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if message.isLoading {
                    TypingIndicator()
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Text(message.content)
                        .font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(message.isUser ? settings.theme.primary : Color(.secondarySystemBackground))
                        .foregroundStyle(message.isUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                Text(message.timestamp.shortFormatted)
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if message.isUser {
                ZStack {
                    Circle().fill(settings.theme.primary).frame(width: 32, height: 32)
                    Image(systemName: "person.fill").font(.caption).foregroundStyle(.white)
                }
            }

            if !message.isUser { Spacer(minLength: 50) }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { idx in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(idx) * 0.15),
                               value: animating)
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - AI Keys View

struct AIKeysView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let viewModel: AIViewModel

    @State private var selectedProvider: AIProvider = .claude
    @State private var claudeKey = ""
    @State private var openAIKey = ""
    @State private var geminiKey = ""
    @State private var showKey = false

    private var currentKey: Binding<String> {
        switch selectedProvider {
        case .claude: return Binding(get: { claudeKey }, set: { claudeKey = $0 })
        case .openai: return Binding(get: { openAIKey }, set: { openAIKey = $0 })
        case .gemini: return Binding(get: { geminiKey }, set: { geminiKey = $0 })
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Provider Picker
                Section(settings.t("AI Provider", "ارائه‌دهنده AI")) {
                    Picker(settings.t("Provider", "ارائه‌دهنده"),
                           selection: Binding(
                               get: { selectedProvider },
                               set: { selectedProvider = $0 }
                           )) {
                        ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                            Label(provider.displayName, systemImage: provider.icon).tag(provider)
                        }
                    }
                    .pickerStyle(.inline)
                }

                // API Key Input
                Section {
                    HStack {
                        if showKey {
                            TextField(selectedProvider.apiKeyPlaceholder, text: currentKey)
                                .autocapitalization(.none).autocorrectionDisabled()
                        } else {
                            SecureField(selectedProvider.apiKeyPlaceholder, text: currentKey)
                                .autocapitalization(.none).autocorrectionDisabled()
                        }
                        Button { showKey.toggle() } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(selectedProvider.apiKeyLabel)
                } footer: {
                    Text(settings.t("Your API key is stored locally on your device only.",
                                    "کلید API فقط روی دستگاه شما ذخیره می‌شه."))
                }

                // Status
                Section(settings.t("Status", "وضعیت")) {
                    HStack {
                        Label("Claude", systemImage: "brain")
                        Spacer()
                        Image(systemName: claudeKey.isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(claudeKey.isEmpty ? .red : .green)
                    }
                    HStack {
                        Label("ChatGPT", systemImage: "bubble.left.and.bubble.right.fill")
                        Spacer()
                        Image(systemName: openAIKey.isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(openAIKey.isEmpty ? .red : .green)
                    }
                    HStack {
                        Label("Gemini", systemImage: "sparkles")
                        Spacer()
                        Image(systemName: geminiKey.isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(geminiKey.isEmpty ? .red : .green)
                    }
                }

                Section {
                    Button(settings.t("Clear All Keys", "پاک کردن همه کلیدها"), role: .destructive) {
                        claudeKey = ""
                        openAIKey = ""
                        geminiKey = ""
                    }
                }
            }
            .navigationTitle(settings.t("AI Settings", "تنظیمات AI"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("Cancel", "انصراف")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("Save", "ذخیره")) {
                        viewModel.claudeAPIKey = claudeKey
                        viewModel.openAIKey = openAIKey
                        viewModel.geminiKey = geminiKey
                        viewModel.provider = selectedProvider
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedProvider = viewModel.provider
                claudeKey = viewModel.claudeAPIKey
                openAIKey = viewModel.openAIKey
                geminiKey = viewModel.geminiKey
            }
        }
    }
}
