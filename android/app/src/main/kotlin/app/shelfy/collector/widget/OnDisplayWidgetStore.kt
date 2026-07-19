package app.shelfy.collector.widget

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

data class OnDisplaySeries(
    val seriesId: String,
    val seriesName: String,
    val ipName: String,
    val brand: String,
    val localCoverPath: String,
    val ownedFigureCount: Int,
    val regularOwned: Int,
    val regularTotal: Int,
    val isComplete: Boolean,
    val isMasterComplete: Boolean,
)

object OnDisplayWidgetStore {
    private const val PREFS = "on_display_widget"
    private const val PAYLOADS = "payloads"
    private const val UPDATED_AT = "payload_updated_at"
    private const val TAG = "OnDisplayWidget"

    fun save(context: Context, json: String) {
        val candidates = parse(json)
        val updatedAt = System.currentTimeMillis()
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(PAYLOADS, json)
            .putLong(UPDATED_AT, updatedAt)
            .apply()
        Log.d(TAG, "payload saved=true candidateCount=${candidates.size} updatedAt=$updatedAt")
    }

    fun selectForToday(context: Context, today: LocalDate = LocalDate.now()): OnDisplaySeries? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val rawPayload = prefs.getString(PAYLOADS, null)
        val candidates = parse(rawPayload ?: "[]")
        Log.d(
            TAG,
            "payload loaded=${rawPayload != null} candidateCount=${candidates.size} " +
                "updatedAt=${prefs.getLong(UPDATED_AT, 0L)}",
        )
        if (candidates.isEmpty()) {
            return null
        }

        val selected = OnDisplayDailySelector.select(
            candidates = candidates,
            epochDay = today.toEpochDay(),
        ) ?: return null
        Log.d(TAG, "selected seriesId=${selected.seriesId} seriesName=${selected.seriesName}")
        return selected
    }

    internal fun parse(json: String): List<OnDisplaySeries> = try {
        val array = JSONArray(json)
        buildList {
            for (index in 0 until array.length()) {
                val item = array.getJSONObject(index)
                add(item.toSeries())
            }
        }.sortedBy { it.seriesId }
    } catch (_: Exception) {
        emptyList()
    }

    private fun JSONObject.toSeries() = OnDisplaySeries(
        seriesId = getString("seriesId"),
        seriesName = getString("seriesName"),
        ipName = optString("ipName"),
        brand = optString("brand"),
        localCoverPath = optString("localCoverPath"),
        ownedFigureCount = getInt("ownedFigureCount"),
        regularOwned = getInt("regularOwned"),
        regularTotal = getInt("regularTotal"),
        isComplete = getBoolean("isComplete"),
        isMasterComplete = getBoolean("isMasterComplete"),
    )
}

object OnDisplayDailySelector {
    fun select(
        candidates: List<OnDisplaySeries>,
        epochDay: Long,
    ): OnDisplaySeries? {
        if (candidates.isEmpty()) return null
        val sorted = candidates.sortedBy { it.seriesId }
        val index = Math.floorMod(epochDay, sorted.size.toLong()).toInt()
        return sorted[index]
    }
}
