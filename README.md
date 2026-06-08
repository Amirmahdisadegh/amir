# حسابیار — دستیار مالی هوشمند برای iPhone

## ویژگی‌ها

| قابلیت | توضیح |
|--------|-------|
| 📷 اسکن فیش | عکس از فیش بگیر — مبلغ، فروشگاه و تاریخ خودکار استخراج می‌شه |
| 🤖 هوش مصنوعی آفلاین | دسته‌بندی خودکار بدون اینترنت با Apple Vision |
| 🌐 Claude AI آنلاین | تحلیل عمیق‌تر با Claude از Anthropic |
| 📊 گزارش‌های بصری | نمودار میله‌ای، دایره‌ای و خطی با Swift Charts |
| 💰 مدیریت بدهی | ثبت قرض‌ها، یادآوری سررسید، تسویه |
| 🎯 بودجه‌بندی | بودجه ماهانه per category + هشدار تجاوز |
| 💬 دستیار گفتگو | سوال بپرس به فارسی — جواب بگیر |
| 📤 خروجی | CSV و PDF برای خروجی گزارش |

## راه‌اندازی در Xcode

### پیش‌نیازها
- macOS 14+
- Xcode 15+
- iOS 17+ (target device)

### نصب XcodeGen
```bash
brew install xcodegen
```

### ساخت پروژه Xcode
```bash
git clone <repo-url>
cd amir
xcodegen generate
open HesabYar.xcodeproj
```

### اجرا
1. پروژه را در Xcode باز کن
2. Target را به دستگاه iPhone تنظیم کن
3. در `Signing & Capabilities` → Team را تنظیم کن
4. ▶ Run

## استفاده از Claude AI آنلاین (اختیاری)

1. به [console.anthropic.com](https://console.anthropic.com) برو
2. یک API Key بساز
3. در اپ: تنظیمات → Claude API Key → وارد کن

## ساختار پروژه

```
HesabYar/
├── App/
│   ├── HesabYarApp.swift      # Entry point
│   └── ContentView.swift      # Tab navigator
├── Models/
│   ├── Expense.swift          # SwiftData model + categories
│   ├── Debt.swift             # Debt model
│   └── Budget.swift           # Budget model + insights
├── Views/
│   ├── Dashboard/             # خانه با نمودار و خلاصه
│   ├── Expenses/              # لیست و افزودن هزینه
│   ├── Scanner/               # اسکن فیش با OCR
│   ├── Reports/               # گزارش‌های تفصیلی
│   ├── Debts/                 # مدیریت بدهی
│   ├── Budget/                # بودجه‌بندی
│   ├── AI/                    # دستیار هوشمند
│   └── Settings/              # تنظیمات
├── ViewModels/
│   ├── ExpenseViewModel.swift  # Business logic هزینه‌ها
│   └── AIViewModel.swift       # مدیریت چت AI
├── Services/
│   ├── OCRService.swift        # Apple Vision OCR (آفلاین)
│   ├── AIService.swift         # Claude API + آفلاین
│   └── ExportService.swift     # CSV & PDF
└── Extensions/
    └── Extensions.swift        # Helpers
```

## فناوری‌ها

- **SwiftUI** — رابط کاربری
- **SwiftData** — ذخیره‌سازی محلی
- **Vision** — OCR آفلاین (اسکن فیش)
- **Swift Charts** — نمودارهای بصری
- **Anthropic Claude API** — هوش مصنوعی آنلاین
- **PDFKit** — خروجی PDF
