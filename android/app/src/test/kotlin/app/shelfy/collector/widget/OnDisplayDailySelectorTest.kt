package app.shelfy.collector.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

class OnDisplayDailySelectorTest {
    private fun series(id: String) = OnDisplaySeries(id, id, "", "", "", 1, 1, 2, false, false)

    @Test fun emptyCandidatesProduceEmptyState() {
        assertNull(OnDisplayDailySelector.select(emptyList(), epochDay = 20_000))
    }

    @Test fun selectionIsStableForTheDayAndIndependentOfInputOrder() {
        val first = OnDisplayDailySelector.select(
            listOf(series("b"), series("a"), series("c")),
            epochDay = 20_000,
        )
        val second = OnDisplayDailySelector.select(
            listOf(series("c"), series("b"), series("a")),
            epochDay = 20_000,
        )
        assertEquals(first?.seriesId, second?.seriesId)
    }

    @Test fun everySeriesIsDisplayedBeforeTheRotationRepeats() {
        val candidates = listOf(series("c"), series("a"), series("b"))

        assertEquals("a", OnDisplayDailySelector.select(candidates, epochDay = 0)?.seriesId)
        assertEquals("b", OnDisplayDailySelector.select(candidates, epochDay = 1)?.seriesId)
        assertEquals("c", OnDisplayDailySelector.select(candidates, epochDay = 2)?.seriesId)
        assertEquals("a", OnDisplayDailySelector.select(candidates, epochDay = 3)?.seriesId)
    }

    @Test fun consecutiveDaysDoNotRepeatWithAStableCandidateSet() {
        val candidates = listOf(series("a"), series("b"), series("c"))
        val today = OnDisplayDailySelector.select(candidates, epochDay = 20_000)
        val tomorrow = OnDisplayDailySelector.select(candidates, epochDay = 20_001)

        assertNotEquals(today?.seriesId, tomorrow?.seriesId)
    }

    @Test fun addingASeriesRecalculatesTodaysIndexFromCurrentCandidates() {
        val beforeAdd = OnDisplayDailySelector.select(
            listOf(series("a"), series("b")),
            epochDay = 2,
        )
        val afterAdd = OnDisplayDailySelector.select(
            listOf(series("a"), series("b"), series("c")),
            epochDay = 2,
        )

        assertEquals("a", beforeAdd?.seriesId)
        assertEquals("c", afterAdd?.seriesId)
    }

    @Test fun deletingTheSelectedSeriesRecalculatesTodaysIndex() {
        val beforeDelete = OnDisplayDailySelector.select(
            listOf(series("a"), series("b"), series("c")),
            epochDay = 1,
        )
        val afterDelete = OnDisplayDailySelector.select(
            listOf(series("a"), series("c")),
            epochDay = 1,
        )

        assertEquals("b", beforeDelete?.seriesId)
        assertEquals("c", afterDelete?.seriesId)
    }
}
