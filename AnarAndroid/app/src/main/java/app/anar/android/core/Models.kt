package app.anar.android.core

import java.util.UUID

enum class ProxyType {
    VMESS, VLESS, TROJAN, SHADOWSOCKS, HYSTERIA2, TUIC, WIREGUARD, SOCKS, HTTP;

    val display: String
        get() = when (this) {
            VMESS -> "VMess"
            VLESS -> "VLESS"
            TROJAN -> "Trojan"
            SHADOWSOCKS -> "Shadowsocks"
            HYSTERIA2 -> "Hysteria2"
            TUIC -> "TUIC"
            WIREGUARD -> "WireGuard"
            SOCKS -> "SOCKS"
            HTTP -> "HTTP"
        }
}

/** Superset of fields across all supported protocols. */
data class ProxyProfile(
    var id: String = UUID.randomUUID().toString(),
    var name: String = "",
    var type: ProxyType = ProxyType.VLESS,
    var server: String = "",
    var port: Int = 443,

    // Credentials
    var uuid: String = "",
    var password: String = "",
    var method: String = "",
    var alterId: Int = 0,
    var encryption: String = "auto",
    var flow: String = "",

    // Transport
    var network: String = "tcp",
    var path: String = "",
    var hostHeader: String = "",

    // TLS
    var tls: Boolean = false,
    var sni: String = "",
    var alpn: List<String> = emptyList(),
    var insecure: Boolean = false,
    var fingerprint: String = "",

    // REALITY
    var reality: Boolean = false,
    var publicKey: String = "",
    var shortId: String = "",

    // WireGuard
    var privateKey: String = "",
    var peerPublicKey: String = "",
    var preSharedKey: String = "",
    var localAddresses: List<String> = emptyList(),
    var reserved: List<Int> = emptyList(),

    // Hysteria2 / TUIC extras
    var obfs: String = "",
    var obfsPassword: String = "",
    var congestionControl: String = "",
    var udpRelayMode: String = "",
) {
    val subtitle: String get() = "${type.display} · $server:$port"

    val isValid: Boolean
        get() {
            if (server.isEmpty() || port <= 0) return false
            return when (type) {
                ProxyType.VMESS, ProxyType.VLESS, ProxyType.TUIC -> uuid.isNotEmpty()
                ProxyType.TROJAN, ProxyType.HYSTERIA2 -> password.isNotEmpty()
                ProxyType.SHADOWSOCKS -> password.isNotEmpty() && method.isNotEmpty()
                ProxyType.WIREGUARD -> privateKey.isNotEmpty() && peerPublicKey.isNotEmpty()
                ProxyType.SOCKS, ProxyType.HTTP -> true
            }
        }
}

data class AppSettings(
    var logLevel: String = "info",
    var bypassPrivate: Boolean = true,
    var dnsServer: String = "tls://8.8.8.8",
    var clashApiPort: Int = 9090,
)

data class AnarData(
    var profiles: MutableList<ProxyProfile> = mutableListOf(),
    var selectedId: String? = null,
    var settings: AppSettings = AppSettings(),
)
