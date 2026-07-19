package app.shelfy.collector.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import app.shelfy.collector.MainActivity
import app.shelfy.collector.R
import java.io.File

internal data class OnDisplayThirdStat(
    val value: String,
    val label: String,
    val isMasterComplete: Boolean,
)

internal fun onDisplayThirdStat(series: OnDisplaySeries): OnDisplayThirdStat {
    if (series.isMasterComplete) {
        return OnDisplayThirdStat(
            value = "Master",
            label = "Complete",
            isMasterComplete = true,
        )
    }
    return OnDisplayThirdStat(
        value = (series.ownedFigureCount - series.regularOwned).coerceAtLeast(0).toString(),
        label = "Secrets",
        isMasterComplete = false,
    )
}

class OnDisplayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Log.d(TAG, "onUpdate widgetIds=${ids.joinToString()}")
        ids.forEach { update(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        Log.d(TAG, "onAppWidgetOptionsChanged widgetId=$appWidgetId")
        update(context, manager, appWidgetId)
    }

    companion object {
        private const val TAG = "OnDisplayWidget"

        fun savePayloadsAndUpdate(context: Context, payloads: String) {
            OnDisplayWidgetStore.save(context, payloads)
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, OnDisplayWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            Log.d(TAG, "payload export received; updating widgetCount=${ids.size}")
            ids.forEach { update(context, manager, it) }
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val series = OnDisplayWidgetStore.selectForToday(context)
            if (series == null) {
                Log.d(TAG, "binding empty model widgetId=$id")
                val empty = RemoteViews(context.packageName, R.layout.on_display_widget_empty)
                empty.setOnClickPendingIntent(R.id.widget_root, navigationIntent(context, "add", id))
                manager.updateAppWidget(id, empty)
                Log.d(TAG, "updateAppWidget called widgetId=$id populated=false")
                return
            }

            val options = manager.getAppWidgetOptions(id)
            Log.d(TAG, "binding populated model widgetId=$id seriesId=${series.seriesId}")
            val size = OnDisplayWidgetSizeMapper.fromDp(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH),
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT),
            )
            val layout = when (size) {
                OnDisplayWidgetSize.SMALL -> R.layout.on_display_widget_small
                OnDisplayWidgetSize.MEDIUM -> R.layout.on_display_widget_medium
                OnDisplayWidgetSize.LARGE -> R.layout.on_display_widget_large
            }
            val views = RemoteViews(context.packageName, layout)
            if (size == OnDisplayWidgetSize.SMALL) {
                val primary = series.ipName.ifBlank { series.seriesName }
                views.setTextViewText(R.id.widget_series_name, primary)
                val secondary = if (primary == series.seriesName) "" else series.seriesName
                views.setTextViewText(R.id.widget_meta, secondary)
                views.setViewVisibility(
                    R.id.widget_meta,
                    if (secondary.isEmpty()) View.GONE else View.VISIBLE,
                )
            } else {
                val primary = if (size == OnDisplayWidgetSize.LARGE) {
                    series.ipName.ifBlank { series.seriesName }
                } else {
                    series.seriesName
                }
                val secondary = if (
                    size == OnDisplayWidgetSize.LARGE && primary != series.seriesName
                ) {
                    series.seriesName
                } else if (size == OnDisplayWidgetSize.LARGE) {
                    ""
                } else {
                    series.ipName
                }
                views.setTextViewText(R.id.widget_series_name, primary)
                val brand = series.brand.takeIf {
                    it.isNotBlank() && it != series.ipName
                }.orEmpty()
                views.setTextViewText(R.id.widget_meta, secondary)
                views.setViewVisibility(
                    R.id.widget_meta,
                    if (secondary.isEmpty()) View.GONE else View.VISIBLE,
                )
                views.setTextViewText(R.id.widget_brand, brand)
                views.setViewVisibility(
                    R.id.widget_brand,
                    if (brand.isEmpty()) View.GONE else View.VISIBLE,
                )
            }
            val completionPercent = if (series.regularTotal <= 0) {
                0
            } else {
                ((series.regularOwned * 100.0) / series.regularTotal).toInt().coerceIn(0, 100)
            }
            val progressLabel = when {
                size == OnDisplayWidgetSize.LARGE -> "$completionPercent%"
                series.ownedFigureCount == 0 -> "Just started"
                else -> "$completionPercent%"
            }
            views.setTextViewText(
                R.id.widget_progress,
                progressLabel,
            )
            val showOwned = series.ownedFigureCount > 0 || size == OnDisplayWidgetSize.LARGE
            val figureLabel = if (size == OnDisplayWidgetSize.LARGE) {
                series.ownedFigureCount.toString()
            } else if (series.ownedFigureCount == 1) {
                "1 Figure"
            } else {
                "${series.ownedFigureCount} Figures"
            }
            views.setTextViewText(R.id.widget_owned, figureLabel)
            views.setViewVisibility(R.id.widget_owned, if (showOwned) View.VISIBLE else View.GONE)
            val completionBadge = when {
                series.isMasterComplete -> "Master Complete"
                series.isComplete -> "Complete"
                else -> ""
            }
            if (size == OnDisplayWidgetSize.LARGE) {
                views.setProgressBar(
                    R.id.widget_progress_ring,
                    100,
                    completionPercent,
                    false,
                )
                val thirdStat = onDisplayThirdStat(series)
                views.setImageViewResource(
                    R.id.widget_third_icon,
                    if (thirdStat.isMasterComplete) {
                        R.drawable.on_display_widget_crown
                    } else {
                        R.drawable.on_display_widget_secret
                    },
                )
                views.setTextViewText(R.id.widget_third_value, thirdStat.value)
                views.setTextViewText(R.id.widget_third_label, thirdStat.label)
                views.setViewVisibility(
                    R.id.widget_zero_status,
                    if (series.ownedFigureCount == 0) View.VISIBLE else View.GONE,
                )
            } else {
                views.setTextViewText(R.id.widget_master, completionBadge)
                views.setViewVisibility(
                    R.id.widget_master,
                    if (size != OnDisplayWidgetSize.SMALL && completionBadge.isNotEmpty()) {
                        View.VISIBLE
                    } else {
                        View.GONE
                    },
                )
            }
            val cover = File(series.localCoverPath)
            if (cover.isFile) {
                views.setImageViewBitmap(R.id.widget_cover, BitmapFactory.decodeFile(cover.path))
            } else {
                views.setImageViewResource(R.id.widget_cover, R.drawable.on_display_widget_placeholder)
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                navigationIntent(context, "series:${series.seriesId}", id),
            )
            manager.updateAppWidget(id, views)
            Log.d(TAG, "updateAppWidget called widgetId=$id populated=true")
        }

        private fun navigationIntent(context: Context, target: String, widgetId: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "app.shelfy.collector.ON_DISPLAY.$target"
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(MainActivity.EXTRA_WIDGET_NAVIGATION, target)
            }
            return PendingIntent.getActivity(
                context,
                widgetId * 31 + target.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }

}
