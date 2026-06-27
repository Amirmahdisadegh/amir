# Anar — کلاینت پروکسی حرفه‌ای برای macOS

اپ منو-بار مک با SwiftUI که از پروتکل‌های اصلی پشتیبانی می‌کند، روی هسته‌ی
[**sing-box**](https://github.com/SagerNet/sing-box) (همان موتوری که NekoBox و
کلاینت‌های حرفه‌ای استفاده می‌کنند). برخلاف iOS، روی مک به اکانت پولی Apple
Developer نیازی نیست.

## پروتکل‌های پشتیبانی‌شده

VMess · VLESS (+REALITY) · Trojan · Shadowsocks · Hysteria2 · TUIC · WireGuard

و خواندن لینک‌های: `vmess://` · `vless://` · `trojan://` · `ss://` ·
`hysteria2://` · `tuic://` · `wireguard://` — تکی، چندتایی، یا از روی
**Subscription URL**.

## دو حالت اتصال

| حالت | توضیح | رمز لازم؟ |
|------|-------|-----------|
| **TUN (VPN کامل)** | کل ترافیک سیستم از تونل رد می‌شود | بله، یک‌بار موقع اتصال |
| **System Proxy** | پروکسی SOCKS/HTTP سیستمی، سبک‌تر | خیر |

آمار زنده‌ی سرعت/حجم و تست پینگ از طریق **Clash API** داخلی هسته نمایش داده می‌شود.

---

## ساخت و اجرا

### پیش‌نیازها
- macOS 14+ و Xcode 15+
- [Go](https://go.dev/dl/) 1.24+ (برای ساخت هسته‌ها)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Xcode command-line tools: `xcode-select --install`

### مراحل
```bash
cd Anar

# 1) هسته‌ها (sing-box + stormdns) را برای مک بساز — یونیورسال arm64+x86_64.
#    sing-box چند ماژول Go دانلود می‌کند؛ کمی طول می‌کشد.
./Scripts/build-cores.sh

# 2) پروژه‌ی Xcode را بساز و باز کن.
xcodegen generate
open Anar.xcodeproj
```
در Xcode دکمه‌ی ▶ (یا `Cmd+R`) را بزن. اپ در **نوار منوی بالای صفحه** ظاهر می‌شود
(بدون پنجره و بدون آیکن Dock — این طبیعی است).

---

## استفاده

1. روی آیکن منو-بار → **Open Anar…**.
2. دکمه‌ی **+** → لینک‌ها را پیست کن یا Subscription URL بده.
3. سروری را از لیست انتخاب کن.
4. در **Settings** حالت اتصال (TUN یا Proxy) را انتخاب کن.
5. **Connect**. در حالت TUN یک‌بار رمز مک پرسیده می‌شود.

---

## نکته‌های مهم

- **حالت TUN به root نیاز دارد** (برای ساختن دستگاه utun). اپ هسته‌ی sing-box را
  با یک پرامپت رمز ادمین اجرا می‌کند. این روی مک کاملاً مجاز و بدون اکانت پولی است.
  (نسخه‌ی فعلی موقع اتصال/قطع رمز می‌پرسد؛ نصب یک helper دائمی برای حذف این
  پرامپت‌ها قدم بعدی است.)
- **Gatekeeper:** چون اپ امضای رسمی ندارد، بار اول از System Settings → Privacy &
  Security اجازه‌ی اجرا بده. برای حذف قرنطینه:
  `xattr -dr com.apple.quarantine Anar.app`
- **بدون App Sandbox** ساخته شده، چون باید هسته را اجرا و شبکه را پیکربندی کند.

---

## ساختار

```
Anar/
├── project.yml                  # XcodeGen
├── Scripts/build-cores.sh       # ساخت یونیورسال sing-box + stormdns
└── Anar/
    ├── App/AnarApp.swift         # MenuBarExtra + پنجره + هندل لینک
    ├── Models/
    │   ├── ProxyProfile.swift     # مدل سرور (همه‌ی پروتکل‌ها)
    │   └── AppSettings.swift       # تنظیمات + مدل ذخیره‌سازی
    ├── Core/
    │   ├── LinkParser.swift        # پارس vmess/vless/trojan/ss/hysteria2/tuic/wg
    │   ├── SingboxConfig.swift     # تولید کانفیگ sing-box (v1.13)
    │   ├── CoreProcess.swift       # اجرای هسته (proxy=child / tun=root)
    │   ├── SystemProxy.swift       # پروکسی سیستمی مک
    │   ├── ClashAPI.swift          # آمار زنده و تست پینگ
    │   ├── ConnectionManager.swift # ارکستراسیون اتصال
    │   └── LogStore.swift
    ├── Store/ProfileStore.swift    # ذخیره‌سازی JSON
    └── Views/                      # MenuBar + پنجره‌ی اصلی + شیت‌ها
```

## لایسنس
sing-box و stormdns هرکدام لایسنس خودشان را دارند. Anar یک رابط مستقل روی آن‌هاست.
