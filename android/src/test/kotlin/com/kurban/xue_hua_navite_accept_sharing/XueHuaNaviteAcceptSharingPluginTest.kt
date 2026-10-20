package com.kurban.xue_hua_navite_accept_sharing

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals

internal class XueHuaNaviteAcceptSharingPluginTest {
    @Test
    fun getInitialSharing_returnsCachedPayloadAndClearResetsIt() {
        val plugin = XueHuaNaviteAcceptSharingPlugin()
        val samplePayload = mapOf(
            "items" to listOf(
                mapOf(
                    "type" to "text",
                    "content" to "Hello Shared World",
                    "mimeType" to "text/plain"
                )
            ),
            "text" to "Hello Shared World",
            "subject" to "Greeting"
        )
        plugin.initialPayload = samplePayload

        val getResult = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("getInitialSharing", null), getResult)
        Mockito.verify(getResult).success(samplePayload)

        val clearResult = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("clearInitialSharing", null), clearResult)
        Mockito.verify(clearResult).success(null)
        assertEquals(null, plugin.initialPayload)
    }

    @Test
    fun buildTextItem_distinguishesUrlAndText() {
        val plugin = XueHuaNaviteAcceptSharingPlugin()

        val urlItem = plugin.buildTextItem("https://flutter.dev", "Flutter")
        assertEquals("url", urlItem["type"])
        assertEquals("text/uri-list", urlItem["mimeType"])

        val textItem = plugin.buildTextItem("Plain text message", null)
        assertEquals("text", textItem["type"])
        assertEquals("text/plain", textItem["mimeType"])
    }
}
