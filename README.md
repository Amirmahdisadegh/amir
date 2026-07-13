# PanelPilot

A premium, native **iOS 17+** SwiftUI client for managing a [3x-ui (MHSanaei)](https://github.com/MHSanaei/3x-ui) panel over its HTTP API — inbounds, clients, live server stats, and one-tap VLESS/Reality sharing with QR codes.

<p align="center"><em>Dashboard · Inbounds · Clients · Settings — dark, glassy, fully localized (English + فارسی with RTL).</em></p>

---

## Features

| Area | What it does |
|------|--------------|
| 🔐 **Secure login** | Form-encoded `/login`, session-cookie persistence, transparent re-login on 401 / HTML login page. Credentials stored in the **iOS Keychain**. Optional **Face ID / Touch ID** app lock. |
| 📊 **Dashboard** | `POST /server/status` — CPU, RAM, disk gauges, Xray state, uptime, live up/down speed, connections, and a **Swift Charts** throughput graph. Aggregate totals (clients, online now, inbounds, traffic). |
| 📥 **Inbounds** | `GET /panel/api/inbounds/list` — protocol, port, enable state, up/down traffic, client & online counts. |
| 👤 **Clients** | Per-inbound & global lists with traffic ring, expiry, online/expired status dot. Add / edit / delete / reset traffic / enable-disable. Swipe actions + confirmations + haptics. |
| 🔗 **Share** | Builds a **VLESS/Reality** (or VMess) URI from the inbound's `streamSettings` (pbk, sni, sid, fp, flow) + client UUID + server address, rendered as text **and a local CoreImage QR code**. Copy or share sheet. |
| 🔎 **Search & filters** | Search by name; filters for **online**, **expiring soon (<3 days)**, **over 80% traffic**, and **disabled**; per-inbound scoping. |
| 💾 **Local-first** | All data cached with **SwiftData** — the app opens instantly offline with a "last updated" timestamp and refreshes in the background. Pull-to-refresh everywhere. |
| 🎨 **Premium UI** | Deep `#0B0F1A` background, `ultraThinMaterial` glass cards, indigo→cyan accent gradient, SF Symbols, spring animations, skeleton loaders, polished empty/error states with retry. |
| 🌐 **Localization** | Full **English + Persian (فارسی)** with correct **RTL** layout and **Persian digit** formatting. Follows system language by default, switchable in Settings. |
| 🧪 **Mock mode** | A built-in demo mode with fake data powers SwiftUI previews and lets you explore the app with no server. |

## Panel connection

The setup screen is **pre-filled** with the owner's panel (editable, and changeable later in Settings):

- **Base URL:** `https://panel.amber-thicket.online:54321/OVm5ec2vkyVvBr5fY3/`
- **Username / Password:** entered on first launch, then stored in the Keychain.

An **"Allow insecure TLS"** toggle (custom `URLSessionDelegate`) is available for panels with self-signed certificates.

## Architecture

**MVVM, no third-party dependencies.**

```
PanelPilot/
├── App/                 PanelPilotApp (SwiftData container) · RootView (setup/lock/tabs)
├── Models/              APIModels (·{success,msg,obj}· envelope, Inbound, Client,
│                        ClientStat, StreamSettings/Reality, ServerStatus)
│                        CacheModels (SwiftData) · CacheEncoders · PanelConfig
├── Networking/          APIClient (single actor: cookies, auth, transparent retry)
│                        KeychainStore · InsecureTLSDelegate · APIError
├── Services/            ConnectionURIBuilder · QRCodeGenerator · BiometricAuth · MockData
├── ViewModels/          AppState · DataStore (local-first cache) · PreviewSupport
├── Views/               Dashboard · Inbounds · Clients · Settings · Setup · Components
├── Theme/               Design tokens (colors, gradients, spring)
├── Utilities/           Formatters (bytes/speed/dates/Persian digits) · LocalizationManager
└── Resources/           en.lproj · fa.lproj  (Localizable.strings)
```

Key design notes:

- **Single `APIClient` actor** owns the `URLSession`, session cookie, credentials, and retry/re-login. Every panel response decodes the generic `{ success, msg, obj }` envelope.
- The panel returns **`settings`, `streamSettings`, and `clientStats` as nested JSON strings** — these are decoded with a secondary pass (`InboundSettings`, `StreamSettings`, `RealitySettings`).
- **`DataStore`** is the local-first layer: it hydrates from SwiftData on launch, then refreshes and mirrors results back into the store, keeping a rolling throughput history for the chart.

## Build & run

Requirements: **macOS 14+, Xcode 15+, iOS 17+ target.**

This repo ships the sources plus an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec (`project.yml`).

```bash
brew install xcodegen        # if not already installed
cd amir
xcodegen generate            # creates PanelPilot.xcodeproj
open PanelPilot.xcodeproj
```

Then in Xcode:

1. Select the **PanelPilot** target and set your Signing Team (or leave signing off for the Simulator).
2. Choose an iPhone simulator or device.
3. **▶ Run.** On first launch, confirm/enter the panel credentials on the setup screen.

> Prefer to explore without a server? Enable **Settings → Demo mode** (or run any SwiftUI preview) to see the full UI with mock data.

## API endpoints used

| Purpose | Method & path |
|---|---|
| Login | `POST /login` (form: `username`, `password`) |
| Inbounds | `GET /panel/api/inbounds/list` |
| Online clients | `POST /panel/api/inbounds/onlines` |
| Server status | `POST /server/status` |
| Add client | `POST /panel/api/inbounds/addClient` |
| Update client | `POST /panel/api/inbounds/updateClient/{uuid}` |
| Delete client | `POST /panel/api/inbounds/{inboundId}/delClient/{uuid}` |
| Reset traffic | `POST /panel/api/inbounds/{inboundId}/resetClientTraffic/{email}` |

## Privacy

Credentials never leave the device except to authenticate with your own panel; they are held in the Keychain and, optionally, gated behind biometric unlock. No analytics, no third-party SDKs.
