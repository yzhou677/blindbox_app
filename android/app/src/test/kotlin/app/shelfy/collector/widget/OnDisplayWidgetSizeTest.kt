package app.shelfy.collector.widget

import org.junit.Assert.assertEquals
import org.junit.Test

class OnDisplayWidgetSizeTest {
    @Test fun mapsSmallTwoByTwo() {
        assertEquals(OnDisplayWidgetSize.SMALL, OnDisplayWidgetSizeMapper.fromDp(110, 110))
    }

    @Test fun mapsMediumFourByTwo() {
        assertEquals(OnDisplayWidgetSize.MEDIUM, OnDisplayWidgetSizeMapper.fromDp(250, 110))
    }

    @Test fun mapsLargeFourByFour() {
        assertEquals(OnDisplayWidgetSize.LARGE, OnDisplayWidgetSizeMapper.fromDp(250, 250))
    }
}
