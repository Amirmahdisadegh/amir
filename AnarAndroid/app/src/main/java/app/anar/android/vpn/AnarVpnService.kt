package app.anar.android.vpn

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.VpnService
import android.os.ParcelFileDescriptor
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import libbox.BoxService
import libbox.InterfaceUpdateListener
import libbox.Libbox
import libbox.NetworkInterfaceIterator
import libbox.PlatformInterface
import libbox.SetupOptions
import libbox.StringIterator
import libbox.TunOptions
import libbox.WIFIState
import java.net.NetworkInterface

/**
 * Runs the sing-box core (v1.12.x libbox) inside an Android VpnService.
 * Implements libbox.PlatformInterface so the core can open the TUN device
 * through VpnService and protect its own sockets.
 *
 * NOTE: This is the first device-tested cut of the VPN integration. Some
 * platform callbacks are intentionally minimal and may need tuning per device.
 */
class AnarVpnService : VpnService(), PlatformInterface {

    companion object {
        const val ACTION_START = "app.anar.START"
        const val ACTION_STOP = "app.anar.STOP"
        const val EXTRA_CONFIG = "config"

        private val _running = MutableStateFlow(false)
        val running: StateFlow<Boolean> = _running

        private val _error = MutableStateFlow<String?>(null)
        val error: StateFlow<String?> = _error

        private val _log = MutableStateFlow<List<String>>(emptyList())
        val log: StateFlow<List<String>> = _log

        fun appendLog(line: String) {
            val cur = _log.value
            _log.value = (cur + line).takeLast(800)
        }
    }

    private var box: BoxService? = null
    private var tunFd: ParcelFileDescriptor? = null
    private var connectivity: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopService()
            return START_NOT_STICKY
        }
        val config = intent?.getStringExtra(EXTRA_CONFIG)
        if (config.isNullOrEmpty()) {
            stopService(); return START_NOT_STICKY
        }
        startService(config)
        return START_STICKY
    }

    private fun startService(config: String) {
        Thread {
            try {
                _error.value = null
                val base = filesDir.absolutePath
                Libbox.setup(SetupOptions().apply {
                    basePath = base
                    workingPath = "$base/work"
                    tempPath = "$base/tmp"
                })
                val service = Libbox.newService(config, this)
                service.start()
                box = service
                _running.value = true
                appendLog(">>> Connected")
            } catch (t: Throwable) {
                _error.value = t.message ?: "Failed to start"
                appendLog("!!! ${t.message}")
                stopService()
            }
        }.start()
    }

    private fun stopService() {
        try { box?.close() } catch (_: Throwable) {}
        box = null
        try { tunFd?.close() } catch (_: Throwable) {}
        tunFd = null
        _running.value = false
        stopSelf()
    }

    override fun onDestroy() {
        stopService()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopService()
        super.onRevoke()
    }

    // MARK: - libbox.PlatformInterface

    override fun openTun(options: TunOptions): Int {
        val builder = Builder()
        builder.setSession("Anar")
        builder.setMtu(options.getMTU())

        addPrefixes(options.getInet4Address()) { addr, len -> builder.addAddress(addr, len) }
        addPrefixes(options.getInet6Address()) { addr, len -> builder.addAddress(addr, len) }

        if (options.getAutoRoute()) {
            builder.addRoute("0.0.0.0", 0)
            builder.addRoute("::", 0)
        }

        try {
            val dns = options.getDNSServerAddress()
            val value = dns?.getValue() ?: ""
            if (value.isNotEmpty()) builder.addDnsServer(value)
        } catch (_: Throwable) {}

        applyPackages(options.getIncludePackage(), allow = true, builder)
        applyPackages(options.getExcludePackage(), allow = false, builder)

        val pfd = builder.establish() ?: throw IllegalStateException("VpnService.establish() returned null")
        tunFd = pfd
        return pfd.fd
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        protect(fd)
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun writeLog(message: String) {
        appendLog(message)
    }

    override fun useProcFS(): Boolean = false

    override fun localDNSTransport(): libbox.LocalDNSTransport? = null

    override fun findConnectionOwner(
        ipProtocol: Int, sourceAddress: String, sourcePort: Int,
        destinationAddress: String, destinationPort: Int
    ): Int = throw UnsupportedOperationException("not supported")

    override fun packageNameByUid(uid: Int): String {
        val names = packageManager.getPackagesForUid(uid)
        if (names.isNullOrEmpty()) throw IllegalStateException("unknown uid")
        return names[0]
    }

    // gomobile lowercases only the leading rune: UIDByPackageName -> uIDByPackageName
    override fun uIDByPackageName(packageName: String): Int =
        packageManager.getPackageUid(packageName, 0)

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        connectivity = cm
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = update(network, listener)
            override fun onLinkPropertiesChanged(network: Network, lp: android.net.LinkProperties) {
                update(network, listener)
            }
        }
        networkCallback = cb
        cm.registerDefaultNetworkCallback(cb)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        networkCallback?.let { connectivity?.unregisterNetworkCallback(it) }
        networkCallback = null
    }

    private fun update(network: Network, listener: InterfaceUpdateListener) {
        val lp = connectivity?.getLinkProperties(network)
        val name = lp?.interfaceName ?: return
        val index = runCatching { NetworkInterface.getByName(name)?.index ?: -1 }.getOrDefault(-1)
        runCatching { listener.updateDefaultInterface(name, index, false, false) }
    }

    override fun getInterfaces(): NetworkInterfaceIterator =
        throw UnsupportedOperationException("not supported")

    override fun underNetworkExtension(): Boolean = false
    override fun includeAllNetworks(): Boolean = false
    override fun readWIFIState(): WIFIState? = null
    override fun systemCertificates(): StringIterator? = null
    override fun clearDNSCache() {}
    override fun sendNotification(notification: libbox.Notification) {}

    // MARK: - helpers

    private inline fun addPrefixes(iter: libbox.RoutePrefixIterator?, add: (String, Int) -> Unit) {
        iter ?: return
        while (iter.hasNext()) {
            val p = iter.next()
            add(p.address(), p.prefix())
        }
    }

    private fun applyPackages(iter: StringIterator?, allow: Boolean, builder: Builder) {
        iter ?: return
        while (iter.hasNext()) {
            val pkg = iter.next()
            runCatching {
                if (allow) builder.addAllowedApplication(pkg) else builder.addDisallowedApplication(pkg)
            }
        }
    }
}
