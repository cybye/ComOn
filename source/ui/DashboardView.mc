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

        drawRadialNavigation(dc);
    }

    // -----------------------------------------------------------------
    // SCREEN 1: CHAT & DASHBOARD (Truly Centered)
    // -----------------------------------------------------------------
    private function drawMessagePage(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        var bleMgr = getBleManager();
        var tlm = TelemetryProvider.getInstance();

        var fontXtiny = Graphics.FONT_SYSTEM_XTINY;
        var fontTiny  = Graphics.FONT_SYSTEM_TINY;

        // 1. Top Header: Status
        var statusColor = Graphics.COLOR_RED;
        var statusText = "Getrennt";
        if (bleMgr.isConnected) {
            statusColor = Graphics.COLOR_GREEN;
            statusText = bleMgr.deviceName;
        } else if (bleMgr.isScanning) {
            statusColor = Graphics.COLOR_YELLOW;
            statusText = "Suche Node...";
        }

        var topY = 34;
        var textWidth = dc.getTextWidthInPixels(statusText, fontXtiny);
        var dotX = cx - (textWidth / 2) - 12;

        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, topY + 9, 5);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 4, topY, fontXtiny, statusText, Graphics.TEXT_JUSTIFY_CENTER);

        // Target Channel / Contact Badge
        var targetY = 62;
        dc.setColor(0x00d4ff, Graphics.COLOR_TRANSPARENT); // Cyan
        dc.drawText(cx, targetY, fontXtiny, "[" + ContactManager.getTargetDisplayName() + "]", Graphics.TEXT_JUSTIFY_CENTER);

        // 2. TRUE CENTER: Message Card (Centered at cy = 227)
        var cardW = (w * 0.76).toNumber();
        var cardH = 145;
        var cardX = cx - (cardW / 2);
        var cardY = cy - (cardH / 2); // Exactly centered vertically!

        dc.setColor(0x12151f, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cardX, cardY, cardW, cardH, 14);
        dc.setColor(0x28324a, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cardX, cardY, cardW, cardH, 14);

        // Header inside card
        dc.setColor(0xff9500, Graphics.COLOR_TRANSPARENT); // Orange
        dc.drawText(cx, cardY + 14, fontXtiny, "LETZTE NACHRICHT", Graphics.TEXT_JUSTIFY_CENTER);

        // Main message text
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cardY + 50, fontTiny, bleMgr.lastReceivedMessage, Graphics.TEXT_JUSTIFY_CENTER);

        // Sender
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cardY + 105, fontXtiny, "Absender: " + bleMgr.lastSender, Graphics.TEXT_JUSTIFY_CENTER);

        // 3. Subtle bottom summary line
        var bat = tlm.getBatteryPercent().toNumber();
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 52, fontXtiny, "Akku: " + bat + "%", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // -----------------------------------------------------------------
    // SCREEN 2: TELEMETRIE & SENSOREN (Truly Centered Grid)
    // -----------------------------------------------------------------
    private function drawTelemetryPage(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        var tlm = TelemetryProvider.getInstance();

        var fontXtiny = Graphics.FONT_SYSTEM_XTINY;
        var fontTiny  = Graphics.FONT_SYSTEM_TINY;

        // Title
        dc.setColor(0x00d4ff, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 40, fontXtiny, "TELEMETRIE", Graphics.TEXT_JUSTIFY_CENTER);

        // Grid 2x2 Boxes (Centered vertically at cy = 227)
        var boxW = 140;
        var boxH = 75;
        var gap = 12;
        var box1X = cx - boxW - (gap / 2);
        var box2X = cx + (gap / 2);
        
        var totalGridH = (boxH * 2) + gap;
        var row1Y = cy - (totalGridH / 2) + 6; // ~153px
        var row2Y = row1Y + boxH + gap;       // ~240px

        // Box 1: HRF
        drawTelemetryBox(dc, box1X, row1Y, boxW, boxH, "HRF", 0x1f1111);
        var hr = tlm.getHeartRate();
        var hrStr = (hr != null) ? hr.toString() + " bpm" : "-- bpm";
        dc.setColor(0xff3b30, Graphics.COLOR_TRANSPARENT);
        dc.drawText(box1X + (boxW/2), row1Y + 34, fontTiny, hrStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Box 2: GPS
        var gpsBg = tlm.hasGpsFix ? 0x112211 : 0x1a1a1a;
        drawTelemetryBox(dc, box2X, row1Y, boxW, boxH, "GPS", gpsBg);
        var gpsText = tlm.hasGpsFix ? "FIX OK" : "SUCHE...";
        var gpsColor = tlm.hasGpsFix ? Graphics.COLOR_GREEN : Graphics.COLOR_ORANGE;
        dc.setColor(gpsColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(box2X + (boxW/2), row1Y + 34, fontTiny, gpsText, Graphics.TEXT_JUSTIFY_CENTER);

        // Box 3: SCHRITTE
        drawTelemetryBox(dc, box1X, row2Y, boxW, boxH, "SCHRITTE", 0x14161c);
        var steps = tlm.getSteps();
        var stepsStr = (steps != null) ? steps.toString() : "0";
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(box1X + (boxW/2), row2Y + 34, fontTiny, stepsStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Box 4: BATT
        drawTelemetryBox(dc, box2X, row2Y, boxW, boxH, "BATT", 0x14161c);
        var batStr = tlm.getBatteryPercent().format("%.0f") + "%";
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(box2X + (boxW/2), row2Y + 34, fontTiny, batStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // -----------------------------------------------------------------
    // RADIAL NAVIGATION LABELS (Along curved bezel at 2 and 4 o'clock)
    // -----------------------------------------------------------------
    private function drawRadialNavigation(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var r = (w / 2) - 4; // Right on the outer perimeter

        var fontXtiny = Graphics.FONT_SYSTEM_XTINY;

        // -------------------------------------------------------------
        // BUTTON AT 2 O'CLOCK (START / SELECT)
        // -------------------------------------------------------------
        var btn2Label = (pageIndex == 0) ? "MENÜ" : "POS";
        var btn2Color = (pageIndex == 0) ? 0x3882e0 : 0x27ae60; // Blue for Menu, Green for Pos

        // Draw curved accent arc on the perimeter (approx 20 deg arc at 2 o'clock / -30 deg)
        dc.setColor(btn2Color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 350, 310);
        dc.setPenWidth(1);

        // Draw small label hugging the circular boundary
        // Position at ~2 o'clock: x ~ 430, y ~ 125
        dc.setColor(btn2Color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 24, 116, fontXtiny, btn2Label, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.fillCircle(w - 14, 126, 3); // Subtle tick indicator

        // -------------------------------------------------------------
        // BUTTON AT 4 O'CLOCK (DATA / CHAT / DOWN)
        // -------------------------------------------------------------
        var btn4Label = (pageIndex == 0) ? "DATA" : "CHAT";
        var btn4Color = (pageIndex == 0) ? 0x00d4ff : 0xff9500; // Cyan for Data, Orange for Chat

        // Draw curved accent arc on the perimeter (approx 20 deg arc at 4 o'clock / +30 deg)
        dc.setColor(btn4Color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 50, 10);
        dc.setPenWidth(1);

        // Draw small label hugging the circular boundary
        // Position at ~4 o'clock: x ~ 430, y ~ 305
        dc.setColor(btn4Color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 24, 305, fontXtiny, btn4Label, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.fillCircle(w - 14, 315, 3); // Subtle tick indicator
    }

    private function drawTelemetryBox(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, title as String, bgColor as Number) as Void {
        dc.setColor(bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 8);
        dc.setColor(0x282c38, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, h, 8);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + (w/2), y + 8, Graphics.FONT_SYSTEM_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
