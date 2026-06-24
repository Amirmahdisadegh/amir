# WhiteDNS for macOS

نسخه‌ی **مک** کلاینت DNS-tunneling وایت‌دی‌ان‌اس — معادل اپ اندروید
[WhiteDNS-Android](https://github.com/WhiteDNS/WhiteDNS-Android)، ساخته‌شده با
SwiftUI به‌صورت یک اپ **منو-بار**.

برخلاف iOS، روی مک نیازی به اکانت پولی Apple Developer و NetworkExtension نیست:
اپ هسته‌ی Go ـیِ [StormDNS](https://github.com/nullroute1970/StormDNS) را مثل
نسخه‌ی اندروید به‌صورت یک **پروسه‌ی جداگانه** اجرا می‌کند، یک SOCKS5 محلی باز
می‌کند، و آن را در **System Settings → Network → Proxies** به‌صورت پروکسی سیستمی
ست می‌کند تا کل ترافیک از تونل عبور کند.

---

## معماری

```
┌──────────────────────────────┐
│  WhiteDNS.app (SwiftUI)       │
│  • مدیریت پروفایل/ریزالور     │
│  • رندر client_config.toml    │
│  • کنترل پروکسی سیستمی        │
└───────────────┬──────────────┘
                │ اجرا با  -config / -resolvers
                ▼
┌──────────────────────────────┐
│  stormdns (هسته‌ی Go)          │  ← SOCKS5 روی 127.0.0.1:18000
└──────────────────────────────┘
```

| نسخه اندروید | معادل مک |
|---|---|
| Jetpack Compose | SwiftUI |
| `ProcessBuilder` برای اجرای هسته | `Foundation.Process` |
| حالت VPN (`VpnService`) | پروکسی SOCKS سیستمی (`networksetup`) |
| `stormdns://` import/export | `ProfileLink.swift` (هم‌فرمت اندروید) |

---

## پیش‌نیازها

- macOS 14+
- [Go](https://go.dev/dl/) 1.25+  ← برای ساخت هسته
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Xcode command-line tools (برای `lipo` و باینری یونیورسال): `xcode-select --install`

---

## ساخت و اجرا

```bash
cd WhiteDNSMac

# 1) هسته‌ی StormDNS را برای مک بساز (یونیورسال arm64 + x86_64).
#    خروجی در WhiteDNS/Resources/stormdns قرار می‌گیرد.
./Scripts/build-core.sh

# 2) پروژه‌ی Xcode را بساز.
xcodegen generate

# 3) باز کن و Run بزن.
open WhiteDNS.xcodeproj
```

> اگر قبلاً StormDNS را کلون کرده‌ای، می‌توانی از همان استفاده کنی:
> `STORMDNS_SRC=/path/to/StormDNS ./Scripts/build-core.sh`

اپ بعد از اجرا در **نوار منوی بالای صفحه** (آیکن سپر) ظاهر می‌شود.

---

## استفاده

1. روی آیکن منو-بار کلیک کن → **Open WhiteDNS…**.
2. در تب **Servers** یک پروفایل اضافه کن:
   - **Import** و چسباندن لینک `stormdns://`، یا
   - **Add** و وارد کردن دستی domain / encryption key / encryption method.
3. در تب **Resolvers** در صورت نیاز ریزالورها را ویرایش کن (پیش‌فرض: ریزالورهای عمومی).
4. از منو-بار یا تب **Connection** دکمه‌ی **Connect** را بزن.
5. هنگام اتصال، یک‌بار رمز مک پرسیده می‌شود (برای ست‌کردن پروکسی سیستمی).
6. وضعیت، سرعت آپلود/دانلود و لاگ‌ها در پنجره قابل مشاهده‌اند.

با **Disconnect**، پروکسی سیستمی خاموش و هسته متوقف می‌شود.

---

## نکات

- **بدون پروکسی سیستمی:** اگر در Settings گزینه‌ی «Manage system SOCKS proxy» را
  خاموش کنی، اپ فقط SOCKS5 را روی `127.0.0.1:18000` بالا می‌آورد و خودت می‌توانی
  دستی به مرورگر/اپ بدهی.
- **هشدار Gatekeeper:** چون اپ بدون امضای رسمی ساخته می‌شود، اولین بار باید از
  مسیر System Settings → Privacy & Security اجازه‌ی اجرا بدهی (یا با کلیک راست →
  Open). همین برای هسته‌ی `stormdns` هم ممکن است لازم شود (حذف قرنطینه:
  `xattr -dr com.apple.quarantine WhiteDNS.app`).
- **بدون App Sandbox:** اپ عمداً sandbox ندارد، چون هم باید پروسه‌ی هسته را اجرا
  کند و هم پروکسی سیستمی را تغییر دهد.

---

## ساختار پروژه

```
WhiteDNSMac/
├── project.yml                 # تعریف پروژه برای XcodeGen
├── Scripts/build-core.sh       # ساخت باینری یونیورسال مک از سورس StormDNS
└── WhiteDNS/
    ├── App/WhiteDNSApp.swift    # ورودی، MenuBarExtra + پنجره، هندل stormdns://
    ├── Models/
    │   ├── Models.swift         # ServerProfile / ResolverProfile / AppSettings
    │   └── ProfileLink.swift    # پارس/ساخت لینک stormdns:// (هم‌فرمت اندروید)
    ├── Core/
    │   ├── ConfigRenderer.swift # رندر client_config.toml + فایل ریزالور
    │   ├── StormDnsProcess.swift # اجرای هسته و خواندن stdout
    │   ├── SystemProxy.swift     # روشن/خاموش‌کردن پروکسی SOCKS سیستمی
    │   ├── PortProbe.swift       # تشخیص آماده‌بودن لیسنر SOCKS
    │   ├── TrafficStats.swift    # استخراج آمار ترافیک از لاگ
    │   ├── LogStore.swift        # بافر لاگ
    │   └── TunnelController.swift # ارکستراسیون اتصال/قطع
    ├── Store/ProfileStore.swift  # ذخیره‌سازی JSON پروفایل‌ها و تنظیمات
    └── Views/                    # MenuBar + تب‌های Connection/Servers/Resolvers/Logs/Settings
```

## لایسنس

هسته‌ی StormDNS تحت لایسنس MIT است. این اپ یک کلاینت مستقل برای آن هسته است.
