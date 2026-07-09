# OKX RTM Scanner — اسکنر و ربات معاملاتی نیمه‌خودکار

اسکن خودکار جفت‌ارزهای OKX، تشخیص ستاپ‌های **RTM** (الگوهای **FTR** و
**Flag Limit**)، ارسال **Alert تلگرام**، و در حالت پیشرفته اجرای خودکار سفارش
با محدودیت‌های ریسک **غیرقابل غیرفعال‌سازی**. همراه با ماژول **Backtest** روی
دیتای تاریخی OKX.

> ⚠️ این ابزار آموزشی/کمکی است، نه توصیهٔ مالی. با **Demo Trading** و
> **Mode 1** شروع کنید و فقط بعد از چند هفته تست موفق سراغ اجرای خودکار بروید.

---

## معماری

```
okx-scanner/
├── main.py                     # نقطه ورود: scan | backtest | universe
├── config.example.yaml         # تنظیمات (کپی به config.yaml)
├── .env.example                # رمزها: توکن تلگرام + کلید OKX (کپی به .env)
├── requirements.txt
└── okx_scanner/
    ├── config.py               # بارگذاری تایپ‌دار config + .env
    ├── indicators.py           # ATR، سویینگ‌ها، متریک کندل
    ├── signals.py              # دیتاکلاس Signal و Zone
    ├── data/exchange.py        # اتصال async به OKX با ccxt (+ proxy/CA محیط)
    ├── rtm/
    │   ├── structure.py        # Base candle، BOS، ساخت zone و سیگنال
    │   ├── ftr.py              # تشخیص FTR (Failure To Return)
    │   └── flag_limit.py       # تشخیص Flag Limit
    ├── scanner.py              # حلقه اسکن چند‌کوین/چند‌تایم‌فریم
    ├── risk.py                 # مدیریت ریسک (غیرقابل غیرفعال‌سازی)
    ├── notifier.py             # Alert تلگرام (aiogram) + cooldown
    ├── executor.py             # اجرای سفارش (Mode 2)
    └── backtest.py             # موتور بک‌تست + آمار
```

---

## نصب

```bash
cd okx-scanner
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cp config.example.yaml config.yaml     # تنظیمات را ویرایش کنید
cp .env.example .env                    # رمزها را وارد کنید
```

---

## اجرا

```bash
# لیست کوین‌هایی که اسکن می‌شوند (بر اساس حجم)
python main.py universe

# اسکن + Alert (Mode یا live طبق config.yaml)
python main.py scan

# بک‌تست روی دیتای تاریخی OKX
python main.py backtest
```

---

## حالت‌ها (Modes)

| Mode | مقدار `mode` در config | رفتار |
|------|------------------------|-------|
| **1 — پیش‌فرض** | `scan` | فقط اسکن + Alert تلگرام. معامله را **دستی** خودتان می‌زنید. نیازی به کلید API نیست. |
| **2 — پیشرفته** | `live` | اجرای خودکار سفارش با تمام محدودیت‌های ریسک فعال. نیازمند کلید OKX در `.env`. |

**شروع کار همیشه با `mode: scan` و `sandbox: true` (Demo Trading).**

---

## منطق اسکن (RTM)

برای هر کوین و هر تایم‌فریم:

1. **Base candle** — گروهی از کندل‌های کوچک‌بدنه (نسبت بدنه/رنج ≤ آستانه) به‌عنوان مبدأ ناحیه عرضه/تقاضا.
2. **Break of Structure (BOS)** — بسته‌شدن کندل فراتر از آخرین سویینگ معتبر، با شرط اندازهٔ لِگ ≥ `min_leg_atr_mult × ATR`.
3. **FTR** — بعد از BOS، آخرین Base که در سمت درست سطح شکسته‌شده باقی مانده (بازنگشته) = ناحیهٔ ورود ادامه‌دهنده.
4. **Flag Limit** — Base ای که دقیقاً روی سطح شکسته‌شده (در محدودهٔ تلورانس ATR) نشسته است.
5. **فیلترهای کیفیت**: تازگی ناحیه، فاصلهٔ قیمت تا ناحیه (بر حسب ATR)، حداقل Risk/Reward، تأیید حجم کندل، و confluence چند‌تایم‌فریمی.

خروجی هر سیگنال: نوع ستاپ، سطح ورود، **SL**، **TP**، Risk/Reward و یک **Score** کیفیت (۰–۱۰۰) برای اولویت‌بندی.

> **توجه صادقانه:** RTM یک روش پرایس‌اکشن دیسکرشنری است؛ این پیاده‌سازی یک
> «تقریب قطعی و قابل‌تنظیم» است، نه بازتولید دقیق دید معامله‌گر انسانی.
> حساسیت کاملاً با پارامترهای بخش `rtm` در config کنترل می‌شود.

---

## الزامات ریسک (غیرقابل غیرفعال‌سازی)

همهٔ این قوانین در `okx_scanner/risk.py` همیشه در حالت live اعمال می‌شوند:

1. **Position Size خودکار** = درصد ثابت ریسک (۱–۲٪) × سرمایه، تقسیم بر فاصلهٔ SL (که کف آن `atr_sl_mult × ATR` است).
2. **Stop Loss اجباری** روی هر سفارش — پلنِ بدون SL رد می‌شود و سفارش ارسال نمی‌شود.
3. **سقف تعداد معاملات همزمان** (`max_open_positions`) برای کل حساب، نه هر کوین.
4. **Daily Loss Limit** — با رسیدن به `daily_loss_limit_pct` ضرر روزانه، ربات کاملاً متوقف می‌شود (وضعیت در `state/risk_state.json` ذخیره می‌شود تا restart شمارنده را صفر نکند).
5. **سقف اهرم** (`max_leverage`) — سایز در صورت نیاز کوچک می‌شود تا از این حد عبور نکند.

---

## Backtest

```bash
python main.py backtest
```

- شبیه‌سازی event-driven بدون look-ahead: در هر کندل بسته‌شده، همان detectorهای زنده روی پنجرهٔ قابل‌مشاهده اجرا می‌شوند.
- ورود به‌صورت Limit روی سطح سیگنال؛ در صورت لمس قیمت، fill و سپس پایش SL/TP کندل‌به‌کندل (در تلاقی SL/TP در یک کندل، محافظه‌کارانه SL اول فرض می‌شود).
- خروجی: **Win Rate، Profit Factor، Avg R:R، Expectancy، Max Drawdown، Return%**.

کوین‌ها/تایم‌فریم/بازهٔ تست در بخش `backtest` تنظیم می‌شوند.

---

## نکات امنیتی (مهم)

کلید API اجرای سفارش را در پنل OKX این‌گونه بسازید:

- **Permission: فقط Trade** — «Withdrawal» حتماً **غیرفعال**.
- **IP Whitelist**: فقط IP سرور شما → `206.245.166.128`.
- ابتدا کلیدِ **Demo Trading** بسازید و هفته‌ها تست کنید.
- رمزها فقط در `.env` (که در `.gitignore` است)؛ هرگز commit نشوند.

---

## تست

```bash
pip install pytest
pytest -q        # تست‌های indicators، RTM و risk (بدون نیاز به شبکه)
```

---

## پشت پروکسی / CA سفارشی

`OkxData` به‌صورت خودکار `HTTPS_PROXY` و CA سفارشی (`SSL_CERT_FILE` /
`REQUESTS_CA_BUNDLE`) را از محیط می‌خواند، تا اجرا پشت پروکسی سازمانی بدون
تغییر کد ممکن باشد.

> اگر شبکهٔ شما دسترسی خروجی به `okx.com` را مسدود کند (egress policy)، اتصال
> زنده ممکن نیست؛ در این حالت ابزار روی سروری با اجازهٔ دسترسی به OKX اجرا شود.
