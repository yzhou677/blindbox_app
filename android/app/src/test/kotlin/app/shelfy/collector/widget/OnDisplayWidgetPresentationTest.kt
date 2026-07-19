package app.shelfy.collector.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OnDisplayWidgetPresentationTest {
    @Test fun thirdStatShowsOwnedSecretCountByDefault() {
        val stat = onDisplayThirdStat(series(owned = 11, regularOwned = 9))

        assertEquals("2", stat.value)
        assertEquals("Secrets", stat.label)
        assertFalse(stat.isMasterComplete)
    }

    @Test fun thirdStatUsesMasterPresentationWhenMasterComplete() {
        val stat = onDisplayThirdStat(
            series(owned = 12, regularOwned = 11, isMasterComplete = true),
        )

        assertEquals("Master", stat.value)
        assertEquals("Complete", stat.label)
        assertTrue(stat.isMasterComplete)
    }

    @Test fun secretCountCannotBecomeNegative() {
        val stat = onDisplayThirdStat(series(owned = 0, regularOwned = 1))

        assertEquals("0", stat.value)
    }

    private fun series(
        owned: Int,
        regularOwned: Int,
        isMasterComplete: Boolean = false,
    ) = OnDisplaySeries(
        seriesId = "series",
        seriesName = "Series",
        ipName = "IP",
        brand = "Brand",
        localCoverPath = "",
        ownedFigureCount = owned,
        regularOwned = regularOwned,
        regularTotal = 12,
        isComplete = false,
        isMasterComplete = isMasterComplete,
    )
}
