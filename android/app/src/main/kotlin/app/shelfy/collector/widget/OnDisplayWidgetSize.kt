package app.shelfy.collector.widget

enum class OnDisplayWidgetSize { SMALL, MEDIUM, LARGE }

object OnDisplayWidgetSizeMapper {
    fun fromDp(minWidth: Int, minHeight: Int): OnDisplayWidgetSize = when {
        minWidth >= 250 && minHeight >= 250 -> OnDisplayWidgetSize.LARGE
        minWidth >= 250 -> OnDisplayWidgetSize.MEDIUM
        else -> OnDisplayWidgetSize.SMALL
    }
}
