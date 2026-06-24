package app.anar.android.ui

import android.app.Application
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import app.anar.android.core.*
import app.anar.android.store.ProfileStore
import app.anar.android.vpn.AnarVpnService
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class MainViewModel(app: Application) : AndroidViewModel(app) {
    private val store = ProfileStore(app)

    var profiles by mutableStateOf(store.data.profiles.toList())
        private set
    var selectedId by mutableStateOf(store.selected?.id)
        private set
    var settings by mutableStateOf(store.data.settings)
        private set

    var downSpeed by mutableStateOf(0L); private set
    var upSpeed by mutableStateOf(0L); private set

    val selected: ProxyProfile? get() = profiles.firstOrNull { it.id == selectedId } ?: profiles.firstOrNull()

    fun select(id: String) { store.select(id); selectedId = id }

    fun importLinks(raw: String): Int {
        val one = runCatching { LinkParser.parse(raw) }.getOrNull()
        val list = if (one != null) listOf(one) else LinkParser.parseMany(raw)
        if (list.isNotEmpty()) {
            store.add(list); profiles = store.data.profiles.toList(); selectedId = store.selected?.id
        }
        return list.size
    }

    fun delete(id: String) { store.delete(id); profiles = store.data.profiles.toList(); selectedId = store.selected?.id }

    fun updateSettings(s: AppSettings) { settings = s; store.data.settings = s; store.saveSettings() }

    fun buildConfig(): String? {
        val p = selected ?: return null
        if (!p.isValid) return null
        return SingboxConfig.generate(p, settings)
    }

    fun startStatsLoop() {
        viewModelScope.launch {
            var lastUp = 0L; var lastDown = 0L
            while (true) {
                if (AnarVpnService.running.value) {
                    val t = fetchTotals(settings.clashApiPort)
                    if (t != null) {
                        upSpeed = (t.first - lastUp).coerceAtLeast(0)
                        downSpeed = (t.second - lastDown).coerceAtLeast(0)
                        lastUp = t.first; lastDown = t.second
                    }
                } else { upSpeed = 0; downSpeed = 0; lastUp = 0; lastDown = 0 }
                delay(1000)
            }
        }
    }

    private fun fetchTotals(port: Int): Pair<Long, Long>? = runCatching {
        val c = URL("http://127.0.0.1:$port/connections").openConnection() as HttpURLConnection
        c.connectTimeout = 800; c.readTimeout = 800
        val body = c.inputStream.bufferedReader().readText(); c.disconnect()
        val o = JSONObject(body)
        o.optLong("uploadTotal") to o.optLong("downloadTotal")
    }.getOrNull()
}

class MainActivity : ComponentActivity() {
    private val vm: MainViewModel by viewModels()

    private val vpnPermission = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        if (it.resultCode == RESULT_OK) reallyStart()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        vm.startStatsLoop()
        setContent { AnarTheme { AnarScreen(vm, onConnectToggle = ::toggleVpn) } }
    }

    private fun toggleVpn() {
        if (AnarVpnService.running.value) {
            startService(Intent(this, AnarVpnService::class.java).setAction(AnarVpnService.ACTION_STOP))
            return
        }
        val intent = VpnService.prepare(this)
        if (intent != null) vpnPermission.launch(intent) else reallyStart()
    }

    private fun reallyStart() {
        val config = vm.buildConfig() ?: return
        startService(
            Intent(this, AnarVpnService::class.java)
                .setAction(AnarVpnService.ACTION_START)
                .putExtra(AnarVpnService.EXTRA_CONFIG, config)
        )
    }
}
