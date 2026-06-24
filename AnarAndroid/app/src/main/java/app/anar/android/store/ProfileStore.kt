package app.anar.android.store

import android.content.Context
import app.anar.android.core.AnarData
import app.anar.android.core.ProxyProfile
import com.google.gson.Gson
import java.io.File

/** JSON-file backed storage for profiles + settings. */
class ProfileStore(context: Context) {

    private val gson = Gson()
    private val file = File(context.filesDir, "anar_store.json")
    var data: AnarData = load()
        private set

    private fun load(): AnarData =
        runCatching { gson.fromJson(file.readText(), AnarData::class.java) }
            .getOrNull() ?: AnarData()

    private fun save() {
        runCatching { file.writeText(gson.toJson(data)) }
    }

    val selected: ProxyProfile?
        get() = data.profiles.firstOrNull { it.id == data.selectedId } ?: data.profiles.firstOrNull()

    fun select(id: String) { data.selectedId = id; save() }

    fun add(profiles: List<ProxyProfile>) {
        data.profiles.addAll(profiles)
        if (data.selectedId == null) data.selectedId = data.profiles.firstOrNull()?.id
        save()
    }

    fun delete(id: String) {
        data.profiles.removeAll { it.id == id }
        if (data.selectedId == id) data.selectedId = data.profiles.firstOrNull()?.id
        save()
    }

    fun saveSettings() = save()
}
