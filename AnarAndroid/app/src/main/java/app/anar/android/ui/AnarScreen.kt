@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.anar.android.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.anar.android.core.AppSettings
import app.anar.android.vpn.AnarVpnService

@Composable
fun AnarTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = darkColorScheme(), content = content)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnarScreen(vm: MainViewModel, onConnectToggle: () -> Unit) {
    val running by AnarVpnService.running.collectAsState()
    val error by AnarVpnService.error.collectAsState()
    var showAdd by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }
    var showLogs by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Anar") },
                actions = {
                    TextButton(onClick = { showLogs = true }) { Text("Logs") }
                    IconButton(onClick = { showSettings = true }) { Icon(Icons.Default.Settings, "Settings") }
                    IconButton(onClick = { showAdd = true }) { Icon(Icons.Default.Add, "Add") }
                }
            )
        }
    ) { pad ->
        Column(Modifier.padding(pad).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            ConnectCard(
                running = running,
                serverName = vm.selected?.name ?: "No server",
                down = vm.downSpeed, up = vm.upSpeed,
                enabled = vm.selected?.isValid == true,
                onToggle = onConnectToggle
            )
            error?.let {
                Text("⚠️ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
            Text("Servers", style = MaterialTheme.typography.titleMedium)
            if (vm.profiles.isEmpty()) {
                Text("No servers yet. Tap + to add a link or subscription.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(vm.profiles, key = { it.id }) { p ->
                        ServerRow(
                            name = p.name.ifEmpty { p.server },
                            subtitle = p.subtitle,
                            selected = p.id == vm.selectedId,
                            onClick = { vm.select(p.id) },
                            onDelete = { vm.delete(p.id) }
                        )
                    }
                }
            }
        }
    }

    if (showAdd) AddDialog(onDismiss = { showAdd = false }, onImport = { vm.importLinks(it) })
    if (showSettings) SettingsDialog(vm.settings, onDismiss = { showSettings = false }) { vm.updateSettings(it) }
    if (showLogs) LogsDialog(onDismiss = { showLogs = false })
}

@Composable
private fun ConnectCard(running: Boolean, serverName: String, down: Long, up: Long,
                        enabled: Boolean, onToggle: () -> Unit) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.fillMaxWidth().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(if (running) "Connected" else "Disconnected",
                style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold,
                color = if (running) Color(0xFF34C759) else MaterialTheme.colorScheme.onSurfaceVariant)
            Text(serverName, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (running) {
                Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                    Text("↓ ${formatRate(down)}", color = Color(0xFF34C759))
                    Text("↑ ${formatRate(up)}", color = Color(0xFF0A84FF))
                }
            }
            Button(onClick = onToggle, enabled = enabled, modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (running) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary)) {
                Text(if (running) "Disconnect" else "Connect")
            }
        }
    }
}

@Composable
private fun ServerRow(name: String, subtitle: String, selected: Boolean,
                      onClick: () -> Unit, onDelete: () -> Unit) {
    Card(Modifier.fillMaxWidth(), onClick = onClick,
        colors = CardDefaults.cardColors(
            containerColor = if (selected) MaterialTheme.colorScheme.primaryContainer
            else MaterialTheme.colorScheme.surfaceVariant)) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(name, fontWeight = FontWeight.Medium)
                Text(subtitle, style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            IconButton(onClick = onDelete) { Icon(Icons.Default.Delete, "Delete") }
        }
    }
}

@Composable
private fun AddDialog(onDismiss: () -> Unit, onImport: (String) -> Int) {
    var text by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add servers") },
        text = {
            Column {
                Text("Paste vmess:// vless:// trojan:// ss:// hysteria2:// tuic:// links, or a subscription body.",
                    style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(text, { text = it }, Modifier.fillMaxWidth().height(140.dp),
                    placeholder = { Text("vless://…") })
            }
        },
        confirmButton = { TextButton(onClick = { onImport(text); onDismiss() }) { Text("Import") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

@Composable
private fun SettingsDialog(current: AppSettings, onDismiss: () -> Unit, onSave: (AppSettings) -> Unit) {
    var dns by remember { mutableStateOf(current.dnsServer) }
    var bypass by remember { mutableStateOf(current.bypassPrivate) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Settings") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(dns, { dns = it }, label = { Text("DNS server") }, modifier = Modifier.fillMaxWidth())
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(bypass, { bypass = it }); Text("Bypass private / LAN")
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(current.copy(dnsServer = dns, bypassPrivate = bypass)); onDismiss() }) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

@Composable
private fun LogsDialog(onDismiss: () -> Unit) {
    val log by AnarVpnService.log.collectAsState()
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Logs") },
        text = {
            Column(Modifier.height(380.dp).verticalScroll(rememberScrollState())) {
                Text(log.joinToString("\n"), fontFamily = FontFamily.Monospace,
                    style = MaterialTheme.typography.bodySmall)
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Close") } }
    )
}

private fun formatRate(bytes: Long): String {
    val units = listOf("B/s", "KB/s", "MB/s", "GB/s")
    var v = bytes.toDouble(); var i = 0
    while (v >= 1024 && i < units.size - 1) { v /= 1024; i++ }
    return if (i == 0) "${v.toInt()} ${units[i]}" else String.format("%.1f %s", v, units[i])
}
