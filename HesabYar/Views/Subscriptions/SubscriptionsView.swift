import SwiftUI
import SwiftData
import Charts

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var subscriptions: [SubscriptionRecord]
    @State private var showingAdd = false
    @State private var selectedSub: SubscriptionRecord? = nil
    @State private var selectedCategory: KnownService.ServiceCategory? = nil
    @State private var showingServiceBrowser = false

    private var activeSubs: [SubscriptionRecord] { subscriptions.filter { $0.isActive } }
    private var totalMonthly: Double { activeSubs.reduce(0) { $0 + $1.monthlyEquivalent } }
    private var totalYearly: Double { totalMonthly * 12 }
    private var upcomingRenewals: [SubscriptionRecord] {
        activeSubs.filter { $0.daysUntilRenewal <= 7 }.sorted { $0.daysUntilRenewal < $1.daysUntilRenewal }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(colors: [Color(hex: "#0f0c29") ?? .black,
                                        Color(hex: "#302b63") ?? .indigo,
                                        Color(hex: "#24243e") ?? .purple],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header summary card
                        summaryCard

                        // Upcoming renewals
                        if !upcomingRenewals.isEmpty {
                            upcomingSection
                        }

                        // Category filter
                        categoryFilter

                        // Subscriptions list by category
                        subscriptionsSection

                        // Cost chart
                        if activeSubs.count > 1 {
                            costChartSection
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("اشتراک‌ها")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingServiceBrowser = true
                        } label: {
                            Label("از سرویس‌های شناخته‌شده", systemImage: "square.grid.2x2")
                        }
                        Button {
                            showingAdd = true
                        } label: {
                            Label("اشتراک دستی", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { AddSubscriptionView() }
            .sheet(isPresented: $showingServiceBrowser) { ServiceBrowserView() }
            .sheet(item: $selectedSub) { sub in AddSubscriptionView(editing: sub) }
        }
    }

    // MARK: - Summary Card (Glass style)

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("هزینه ماهانه")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(totalMonthly.formattedAsCurrency)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("سالانه")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(totalYearly.formattedCompact)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            Divider().background(Color.white.opacity(0.2))

            HStack(spacing: 0) {
                summaryStatItem(label: "فعال", value: "\(activeSubs.count)", icon: "checkmark.circle.fill", color: .green)
                Divider().frame(height: 36).background(Color.white.opacity(0.2))
                summaryStatItem(label: "تمدید نزدیک", value: "\(upcomingRenewals.count)", icon: "clock.fill", color: .orange)
                Divider().frame(height: 36).background(Color.white.opacity(0.2))
                summaryStatItem(label: "روزانه", value: (totalMonthly / 30).formattedCompact, icon: "calendar", color: .cyan)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }

    private func summaryStatItem(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color).font(.caption)
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Upcoming Renewals

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("تمدید نزدیک", systemImage: "bell.badge.fill")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(upcomingRenewals.prefix(3), id: \.id) { sub in
                UpcomingRenewalRow(sub: sub)
                    .onTapGesture { selectedSub = sub }
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, label: "همه")
                ForEach(KnownService.ServiceCategory.allCases, id: \.rawValue) { cat in
                    categoryChip(cat, label: cat.rawValue)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func categoryChip(_ cat: KnownService.ServiceCategory?, label: String) -> some View {
        Button {
            selectedCategory = cat
        } label: {
            HStack(spacing: 4) {
                if let cat { Image(systemName: cat.icon).font(.caption2) }
                Text(label).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selectedCategory == cat ? Color.white : Color.white.opacity(0.12))
            .foregroundColor(selectedCategory == cat ? .black : .white)
            .clipShape(Capsule())
        }
    }

    // MARK: - Subscriptions by Category

    private var subscriptionsSection: some View {
        Group {
            if activeSubs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "creditcard.trianglebadge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.4))
                    Text("هنوز اشتراکی ثبت نشده")
                        .foregroundColor(.white.opacity(0.6))
                    Button("افزودن اول اشتراک") { showingServiceBrowser = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredSubs, id: \.id) { sub in
                        SubscriptionCard(sub: sub)
                            .onTapGesture { selectedSub = sub }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { modelContext.delete(sub) } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                                Button { sub.isActive.toggle() } label: {
                                    Label(sub.isActive ? "غیرفعال" : "فعال", systemImage: sub.isActive ? "pause.circle" : "play.circle")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Cost Chart

    private var costChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("توزیع هزینه‌ها")
                .font(.headline)
                .foregroundColor(.white)

            let catData = categoryTotals()
            Chart(catData, id: \.0) { item in
                SectorMark(angle: .value("", item.1), innerRadius: .ratio(0.55), angularInset: 2)
                    .foregroundStyle(item.2)
                    .cornerRadius(4)
            }
            .frame(height: 180)

            VStack(spacing: 6) {
                ForEach(catData, id: \.0) { item in
                    HStack {
                        Circle().fill(item.2).frame(width: 8, height: 8)
                        Text(item.0).font(.caption).foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text(item.1.formattedCompact).font(.caption).fontWeight(.medium).foregroundColor(.white)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Computed

    private var filteredSubs: [SubscriptionRecord] {
        guard let cat = selectedCategory else { return activeSubs.sorted { $0.monthlyEquivalent > $1.monthlyEquivalent } }
        return activeSubs.filter { $0.knownService?.category == cat }.sorted { $0.monthlyEquivalent > $1.monthlyEquivalent }
    }

    private func categoryTotals() -> [(String, Double, Color)] {
        var catMap: [String: (Double, Color)] = [:]
        for sub in activeSubs {
            let catName = sub.knownService?.category.rawValue ?? "سایر"
            let color = sub.knownService?.category.color ?? .gray
            catMap[catName, default: (0, color)].0 += sub.monthlyEquivalent
        }
        return catMap.map { ($0.key, $0.value.0, $0.value.1) }.sorted { $0.1 > $1.1 }
    }
}

// MARK: - Subscription Card

struct SubscriptionCard: View {
    let sub: SubscriptionRecord

    var body: some View {
        HStack(spacing: 14) {
            // Service logo
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(sub.serviceColor.gradient)
                    .frame(width: 52, height: 52)
                Image(systemName: sub.serviceIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(sub.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text(sub.billingCycle.shortLabel)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.15))
                        .foregroundColor(.white.opacity(0.8))
                        .clipShape(Capsule())
                    if sub.isRenewalSoon {
                        Text(sub.daysUntilRenewal == 0 ? "امروز!" : "\(sub.daysUntilRenewal) روز")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.3))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    } else {
                        Text(sub.nextRenewalDate.farsiShort)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(sub.amount.formattedCompact)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("ماهانه: \(sub.monthlyEquivalent.formattedCompact)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(sub.isRenewalSoon ? Color.orange.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Upcoming Renewal Row

struct UpcomingRenewalRow: View {
    let sub: SubscriptionRecord

    var urgencyColor: Color {
        if sub.daysUntilRenewal <= 1 { return .red }
        if sub.daysUntilRenewal <= 3 { return .orange }
        return .yellow
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(sub.serviceColor.opacity(0.8))
                    .frame(width: 40, height: 40)
                Image(systemName: sub.serviceIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(sub.displayName).font(.subheadline).fontWeight(.medium).foregroundColor(.white)
                Text(sub.daysUntilRenewal == 0 ? "امروز تمدید میشه!" :
                     "\(sub.daysUntilRenewal) روز دیگه").font(.caption).foregroundColor(urgencyColor)
            }
            Spacer()
            Text(sub.amount.formattedCompact)
                .font(.subheadline).fontWeight(.bold).foregroundColor(.white)

            Circle().fill(urgencyColor).frame(width: 8, height: 8)
        }
        .padding(12)
        .background(urgencyColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(urgencyColor.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Service Browser

struct ServiceBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCat: KnownService.ServiceCategory? = nil
    @State private var search = ""
    @State private var selectedService: KnownService? = nil

    private var filtered: [KnownService] {
        var list = KnownService.all
        if let cat = selectedCat { list = list.filter { $0.category == cat } }
        if !search.isEmpty { list = list.filter { $0.name.localizedCaseInsensitiveContains(search) } }
        return list
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "همه", isSelected: selectedCat == nil) { selectedCat = nil }
                        ForEach(KnownService.ServiceCategory.allCases, id: \.rawValue) { cat in
                            FilterChip(icon: cat.icon, title: cat.rawValue, isSelected: selectedCat == cat, color: cat.color) {
                                selectedCat = selectedCat == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(filtered) { service in
                        ServiceTile(service: service) {
                            selectedService = service
                        }
                    }
                }
                .padding(16)
            }
            .searchable(text: $search, prompt: "جستجوی سرویس...")
            .navigationTitle("سرویس‌ها")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("بستن") { dismiss() } }
            }
            .sheet(item: $selectedService) { service in
                AddSubscriptionView(knownService: service)
            }
        }
    }
}

struct ServiceTile: View {
    let service: KnownService
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(service.color.gradient)
                        .frame(width: 60, height: 60)
                    Image(systemName: service.sfSymbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(service.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Add/Edit Subscription

struct AddSubscriptionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editing: SubscriptionRecord? = nil
    var knownService: KnownService? = nil

    @State private var serviceName = ""
    @State private var customName = ""
    @State private var amountText = ""
    @State private var billingCycle: BillingCycle = .monthly
    @State private var startDate = Date()
    @State private var notifyBefore = 3
    @State private var paymentMethod = "کارت بانکی"
    @State private var notes = ""
    @State private var autoRenew = true
    @State private var isTrial = false
    @State private var serviceId = ""

    var isValid: Bool { !serviceName.isEmpty && (Double(amountText) ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                // Service logo preview
                if let svc = KnownService.find(id: serviceId) ?? knownService {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20).fill(svc.color.gradient).frame(width: 72, height: 72)
                                    Image(systemName: svc.sfSymbol).font(.system(size: 32, weight: .semibold)).foregroundColor(.white)
                                }
                                Text(svc.name).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }.padding(.vertical, 4)
                    }
                }

                Section("اطلاعات") {
                    HStack {
                        Image(systemName: "tag.fill").foregroundColor(.secondary).frame(width: 24)
                        TextField("نام سرویس", text: $serviceName)
                    }
                    HStack {
                        Image(systemName: "pencil").foregroundColor(.secondary).frame(width: 24)
                        TextField("نام دلخواه (اختیاری)", text: $customName)
                    }
                    HStack {
                        Image(systemName: "banknote.fill").foregroundColor(.secondary).frame(width: 24)
                        TextField("مبلغ", text: $amountText).keyboardType(.decimalPad)
                        Text("تومان").foregroundColor(.secondary)
                    }
                }

                Section("دوره تمدید") {
                    Picker("دوره", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases, id: \.rawValue) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    DatePicker("تاریخ شروع", selection: $startDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "fa_IR"))
                    Toggle("تمدید خودکار", isOn: $autoRenew)
                    Toggle("دوره آزمایشی", isOn: $isTrial)
                }

                Section("یادآوری") {
                    Stepper("\(notifyBefore) روز قبل از تمدید", value: $notifyBefore, in: 1...14)
                    Text("نوتیفیکیشن \(notifyBefore) روز قبل از تمدید ارسال میشه")
                        .font(.caption).foregroundColor(.secondary)
                }

                Section("روش پرداخت") {
                    Picker("", selection: $paymentMethod) {
                        ForEach(["کارت بانکی", "نقدی", "کیف پول", "ارز دیجیتال"], id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }.pickerStyle(.segmented)
                }

                Section("یادداشت") {
                    TextField("توضیحات...", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle(editing != nil ? "ویرایش اشتراک" : "اشتراک جدید")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("انصراف") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing != nil ? "ذخیره" : "افزودن") { save(); dismiss() }
                        .fontWeight(.semibold).disabled(!isValid)
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        if let svc = knownService {
            serviceId = svc.id
            serviceName = svc.name
        }
        guard let e = editing else { return }
        serviceId = e.serviceId
        serviceName = e.serviceName
        customName = e.customName
        amountText = "\(Int(e.amount))"
        billingCycle = e.billingCycle
        startDate = e.startDate
        notifyBefore = e.notifyBeforeDays
        paymentMethod = e.paymentMethod
        notes = e.notes
        autoRenew = e.autoRenew
        isTrial = e.isTrial
    }

    private func save() {
        let amount = Double(amountText) ?? 0
        if let e = editing {
            e.serviceId = serviceId
            e.serviceName = serviceName
            e.customName = customName
            e.amount = amount
            e.billingCycle = billingCycle
            e.startDate = startDate
            e.notifyBeforeDays = notifyBefore
            e.paymentMethod = paymentMethod
            e.notes = notes
            e.autoRenew = autoRenew
            e.isTrial = isTrial
            NotificationService.shared.scheduleSubscriptionReminder(for: e)
        } else {
            let sub = SubscriptionRecord(
                serviceId: serviceId, serviceName: serviceName, customName: customName,
                amount: amount, billingCycle: billingCycle, startDate: startDate,
                notifyBeforeDays: notifyBefore, paymentMethod: paymentMethod, autoRenew: autoRenew
            )
            sub.notes = notes
            sub.isTrial = isTrial
            modelContext.insert(sub)
            NotificationService.shared.scheduleSubscriptionReminder(for: sub)
        }
    }
}
