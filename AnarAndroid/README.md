# Anar for Android

نسخه‌ی اندروید کلاینت Anar — کلاینت چندپروتکلی روی هسته‌ی **sing-box** با
**VpnService** (حالت TUN واقعی). اندروید برخلاف iOS هیچ محدودیتی برای اپ VPN نداره.

## پروتکل‌ها
VMess · VLESS (+REALITY) · Trojan · Shadowsocks · Hysteria2 · TUIC · WireGuard
و خواندن لینک‌های `vmess|vless|trojan|ss|hysteria2|tuic://` و **Subscription**.

> منطق پارس لینک و تولید کانفیگ، پورت همون نسخه‌ی مک است و خروجی sing-box آن با
> اجرای واقعی هسته (v1.12.4) اعتبارسنجی شده.

---

## معماری

```
Compose UI ── MainViewModel ── ProfileStore (JSON)
                  │
                  ├─ SingboxConfig.generate()  → کانفیگ JSON
                  ▼
        AnarVpnService (VpnService)
                  │ libbox.PlatformInterface (openTun/protect/…)
                  ▼
        sing-box core (libbox.aar, v1.12.4)  → TUN
```

هسته‌ی sing-box داخل پروسه‌ی اپ از طریق **libbox** اجرا می‌شود؛ TUN را از
`VpnService` می‌گیرد (بدون subprocess، بدون root).

---

## ساخت

### پیش‌نیازها
- **Android Studio** (جدید)
- **Android SDK + NDK** — در Android Studio: SDK Manager → SDK Tools → NDK (Side by side)
- **Go** 1.23+  (برای ساخت هسته)

### مراحل
```bash
cd AnarAndroid

# 1) هسته‌ی sing-box را به libbox.aar بساز (نیاز به NDK).
#    اول مسیر SDK/NDK را تنظیم کن، مثلاً روی مک:
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$(ls "$ANDROID_HOME/ndk" | tail -1)"
./Scripts/build-libbox.sh

# 2) پروژه را در Android Studio باز کن (پوشه‌ی AnarAndroid)، بگذار Gradle sync شود.
# 3) گوشی را وصل کن (USB debugging) و ▶ Run بزن.
```

اولین اجرا، اندروید برای VPN اجازه می‌خواهد — Allow بزن.

---

## وضعیت و نکات صادقانه

- این **اولین نسخه‌ی دستگاه‌-تست‌نشده** از بخش VpnService/libbox است. منطق اصلی
  (UI، پارس، تولید کانفیگ) محکم است، ولی یکپارچه‌سازی libbox ممکن است روی دستگاه
  نیاز به چند دور اصلاح داشته باشد — لاگ‌ها را از دکمه‌ی **Logs** بفرست.
- ساخت `libbox.aar` به NDK نیاز دارد؛ سنگین‌ترین بخش راه‌اندازی همین است.
- آمار سرعت از طریق Clash API داخلی هسته (۱۲۷.۰.۰.۱:۹۰۹۰) خوانده می‌شود.

## ساختار
```
AnarAndroid/
├── Scripts/build-libbox.sh         # ساخت libbox.aar (sing-box v1.12.4)
└── app/src/main/java/app/anar/android/
    ├── core/   Models · LinkParser · SingboxConfig   (پورت از نسخه‌ی مک)
    ├── vpn/    AnarVpnService (VpnService + libbox.PlatformInterface)
    ├── store/  ProfileStore (JSON)
    └── ui/     MainActivity · AnarScreen (Compose)
```
