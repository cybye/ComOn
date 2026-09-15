import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.System;

class DashboardView extends WatchUi.View {
    private var _timer as Timer.Timer?;
    public var pageIndex as Number = 0; // 0 = Chat / Dashboard, 1 = Telemetrie Detail

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTimer() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (pageIndex == 0) {
            drawMessagePage(dc);
        } else {
            drawTelemetryPage(dc);
        }

        drawPageIndicators(dc);
    }

    // -----------------------------------------------------------------
    // SCREEN 1: CHAT & DASHBOARD
    // -----------------------------------------------------------------
    private function drawMessagePage(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var bleMgr = getBleManager();

        var fontXtiny = Graphics.FONT_SYSTEM_XTINY;
        var fontTiny  = Graphics.FONT_SYSTEM_TINY;
        var fontMed   = Graphics.FONT_SYSTEM_MEDIUM;

        // 1. Status Bar
        var statusColor = Graphics.COLOR_RED;
        var statusText = "Getrennt";
        if (bleMgr.isConnected) {
            statusColor = Graphics.COLOR_GREEN;
            statusText = bleMgr.deviceName;
        } else if (bleMgr.isScanning) {
            statusColor = Graphics.COLOR_YELLOW;
            statusText = "Suche Node...";
        }

        var topY = 40;
        var textWidth = dc.getTextWidthInPixels(statusText, fontTiny);
        var dotX = cx - (textWidth / 2) - 14;

        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, topY + 12, 6);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 4, topY, fontTiny, statusText, Graphics.TEXT_JUSTIFY_CENTER);

        // Target Channel / Contact Badge
        var targetY = topY + 32;
        dc.setColor(0x00d4ff, Graphics.COLOR_TRANSPARENT); // Cyan
        dc.drawText(cx, targetY, fontXtiny, "[" + ContactManager.getTargetDisplayName() + "]", Graphics.TEXT_JUSTIFY_CENTER);

        // Divider
        dc.setColor(0x282828, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(70, 115, w - 70, 115);

        // 2. Large Message Card
        var cardW = (w * 0.84).toNumber();
        var cardH = 135;
        var cardX = cx - (cardW / 2);
        var cardY = 130;

        dc.setColor(0x12151f, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cardX, cardY, cardW, cardH, 12);
        dc.setColor(0x28324a, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cardX, cardY, cardW, cardH, 12);

        // Header inside card
        dc.setColor(0xff9500, Graphics.COLOR_TRANSPARENT); // Orange
        dc.drawText(cx, cardY + 10, fontXtiny, "LETZTE NACHRICHT", Graphics.TEXT_JUSTIFY_CENTER);

        // Main message text (large & readable)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cardY + 40, fontTiny, bleMgr.lastReceivedMessage, Graphics.TEXT_JUSTIFY_CENTER);

        // Sender
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cardY + 95, fontXtiny, "Absender: " + bleMgr.lastSender, Graphics.TEXT_JUSTIFY_CENTER);

        // 3. Action Buttons
        var btnY = 300;
        var pillW = 210;
        var pillH = 38;
        var pillX = cx - (pillW / 2);

        dc.setColor(0x16325c, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(pillX, btnY, pillW, pillH, 10);
        dc.setColor(0x3882e0, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(pillX, btnY, pillW, pillH, 10);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, btnY + 8, fontXtiny, "START: Menü", Graphics.TEXT_JUSTIFY_CENTER);

        // Page scroll hint
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 355, fontXtiny, "DOWN: Telemetrie  v", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // -----------------------------------------------------------------
    // SCREEN 2: TELEMETRIE & SENSOREN
    // -----------------------------------------------------------------
    private function drawTelemetryPage(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var tlm = TelemetryProvider.getInstance();

        var fontXtiny = Graphics.FONT_SYSTEM_XTINY;
        var fontTiny  = Graphics.FONT_SYSTEM_TINY;
        var fontSmall = Graphics.FONT_SYSTEM_SMALL;
        var fontMed   = Graphics.FONT_SYSTEM_MEDIUM;

        // Title
        dc.setColor(0x00d4ff, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 38, fontXtiny, "TELEMETRIE & SENSOREN", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x282828, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(70, 68, w - 70, 68);

        // Grid 2x2 Boxes
        var boxW = 150;
        var boxH = 80;
        var box1X = cx - boxW - 8;
        var box2X = cx + 8;
        var row1Y = 82;
        var row2Y = 175;

        // Box 1: Puls / HR
        drawTelemetryBox(dc, box1X, row1Y, boxW, boxH, "HERZFREQUENZ", 0x221111);
        var hr = tlm.getHeartRate();
        var hrStr = (hr != null) ? hr.toString() : "--";
        dc.setColor(0xff3b30, Graphics.COLOR_TRANSPARENT);
        dc.drawText(box1X + (boxW/2), row1Y + 26, fontMed, hrStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(box1X + (boxW/2), row1Y + 55, fontXtiny, "bpm", Graphics.TEXT_JUSTIFY_CENTER);

        // Box 2: GPS
        var gpsBg = tlm.hasGpsFix ? 0x112211 : 0x1a1a1a;
        drawTelemetryBox(dc, box2X, row1Y, boxW, boxH, "GPS SIGNAL", gpsBg);
        var gpsStatus = tlm.hasGpsFix ? "FIX OK" : "SUCHE";
        var gpsColor = tlm.hasGpsFix ? Graphics.COLOR_GREEN : Graphics.COLOR_ORANGE;
        dc.setColor(gpsColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(box2X + (boxW/2), row1Y + 28, fontSmall, gpsStatus, Graphics.TEXT_JUSTIFY_CENTER);
        var altStr = (tlm.currentAlt != null) ? tlm.currentAlt.format("%.0f") + " m" : "-- m";
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(box2X + (boxW/2), row1Y + 55, fontXtiny, altStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Box 3: Schritte
        drawTelemetryBox(dc, box1X, row2Y, boxW, boxH, "SCHRITTE", 0x1a1a1a);
        var steps = tlm.getSteps();
        var stepsStr = (steps != null) ? steps.toString() : "0";
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(box1X + (boxW/2), row2Y + 28, fontSmall, stepsStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Box 4: Batterie
        drawTelemetryBox(dc, box2X, row2Y, boxW, boxH, "BATTERIE", 0x1a1a1a);
        var bat = tlm.getBatteryPercent().toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(box2X + (boxW/2), row2Y + 28, fontSmall, bat + "%", Graphics.TEXT_JUSTIFY_CENTER);

        // 4. Action Button: Position senden
        var btnY = 280;
        var pillW = 230;
        var pillH = 38;
        var pillX = cx - (pillW / 2);

        dc.setColor(0x0f4228, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(pillX, btnY, pillW, pillH, 10);
        dc.setColor(0x27ae60, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(pillX, btnY, pillW, pillH, 10);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, btnY + 8, fontXtiny, "START: Position senden", Graphics.TEXT_JUSTIFY_CENTER);

        // Page scroll hint
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 340, fontXtiny, "^  UP: Chat / Nachrichten", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawTelemetryBox(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, title as String, bgColor as Number) as Void {
        dc.setColor(bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 8);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, h, 8);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + (w/2), y + 6, Graphics.FONT_SYSTEM_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Page indicator dots on the right edge
    private function drawPageIndicators(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var cy = dc.getHeight() / 2;
        var dotX = w - 18;

        // Dot 1
        dc.setColor((pageIndex == 0) ? 0x00d4ff : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, cy - 8, 4);

        // Dot 2
        dc.setColor((pageIndex == 1) ? 0x00d4ff : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, cy + 8, 4);
    }
}
