import SwiftUI
import SwiftData

struct AIAssistantView: View {
    @Query private var expenses: [Expense]
    @State private var aiViewModel = AIViewModel()
    @State private var showingSettings = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode & status bar
                modeBar

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message
                            if aiViewModel.messages.isEmpty {
                                welcomeSection
                            }

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
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input area
                inputArea
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("دستیار هوشمند")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !aiViewModel.messages.isEmpty {
                        Button("پاک کردن") {
                            aiViewModel.clearChat()
                        }
                        .foregroundColor(.red)
                        .font(.subheadline)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                AISettingsView(apiKey: Binding(
                    get: { aiViewModel.claudeAPIKey },
                    set: { aiViewModel.claudeAPIKey = $0 }
                ))
            }
        }
    }

    // MARK: - Mode Bar

    private var modeBar: some View {
        HStack(spacing: 12) {
            // Online/Offline toggle
            Button {
                aiViewModel.isOnlineMode.toggle()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(aiViewModel.isOnlineMode && aiViewModel.hasApiKey ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(aiViewModel.isOnlineMode && aiViewModel.hasApiKey ? "آنلاین (Claude AI)" :
                         aiViewModel.isOnlineMode && !aiViewModel.hasApiKey ? "نیاز به API Key" : "آفلاین")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }

            Spacer()

            if !aiViewModel.hasApiKey {
                Button {
                    showingSettings = true
                } label: {
                    Text("تنظیم API Key")
                        .font(.caption)
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Welcome

    private var welcomeSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 56))
                    .foregroundColor(.appPrimary)

                VStack(spacing: 6) {
                    Text("دستیار مالی حسابیار")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text(aiViewModel.isOnlineMode && aiViewModel.hasApiKey
                         ? "در حال اتصال به Claude AI - پاسخ‌های دقیق‌تر و هوشمندتر"
                         : "حالت آفلاین - بدون نیاز به اینترنت")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 24)

            // Suggested questions
            VStack(alignment: .leading, spacing: 8) {
                Text("سوالات پیشنهادی:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)

                ForEach(aiViewModel.suggestedQuestions, id: \.self) { question in
                    Button {
                        aiViewModel.inputText = question
                        Task { await aiViewModel.sendMessage(expenses: expenses) }
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.fill")
                                .font(.caption)
                                .foregroundColor(.appPrimary)
                            Text(question)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.left")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
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
                TextField("پیامت رو بنویس...", text: Binding(
                    get: { aiViewModel.inputText },
                    set: { aiViewModel.inputText = $0 }
                ), axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($isInputFocused)
                    .onSubmit {
                        Task { await aiViewModel.sendMessage(expenses: expenses) }
                    }

                Button {
                    Task { await aiViewModel.sendMessage(expenses: expenses) }
                } label: {
                    Image(systemName: aiViewModel.isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(aiViewModel.inputText.isEmpty ? .secondary : .appPrimary)
                }
                .disabled(aiViewModel.inputText.isEmpty || aiViewModel.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 50) }

            if !message.isUser {
                ZStack {
                    Circle().fill(Color.appPrimary.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: "brain").font(.caption).foregroundColor(.appPrimary)
                }
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if message.isLoading {
                    TypingIndicator()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Text(message.content)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.isUser ? Color.appPrimary : Color(.secondarySystemBackground))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Text(message.timestamp.farsiShort)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.isUser {
                ZStack {
                    Circle().fill(Color.appPrimary).frame(width: 32, height: 32)
                    Image(systemName: "person.fill").font(.caption).foregroundColor(.white)
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
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(idx) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - AI Settings Sheet

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var apiKey: String
    @State private var tempKey = ""
    @State private var showKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if showKey {
                                TextField("sk-ant-...", text: $tempKey)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("sk-ant-...", text: $tempKey)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            }
                            Button {
                                showKey.toggle()
                            } label: {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text("کلید API رو از console.anthropic.com بگیر")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Claude API Key")
                } footer: {
                    Text("این کلید فقط روی دستگاه شما ذخیره می‌شه و هرگز ارسال نمی‌شه.")
                }

                Section {
                    Button("پاک کردن کلید", role: .destructive) {
                        tempKey = ""
                    }
                }
            }
            .navigationTitle("تنظیمات AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("انصراف") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ذخیره") {
                        apiKey = tempKey
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { tempKey = apiKey }
        }
    }
}
