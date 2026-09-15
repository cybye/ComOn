import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.System;

class DashboardView extends WatchUi.View {
    private var _timer as Timer.Timer?;
    private var _vectorFont as Graphics.VectorFont?;
    public var pageIndex as Number = 0; // 0 = Chat / Dashboard, 1 = Telemetrie Detail

    function initialize() {
        View.initialize();
        if (Graphics has :getVectorFont) {
            _vectorFont = Graphics.getVectorFont({
                :face => "RobotoRegular",
                :size => 22
            });
        }
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

        drawNavigationIndicators(dc);
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

        // 2. ENLARGED MESSAGE CARD: Moved slightly higher and expanded downward
        var cardW = (w * 0.82).toNumber();
        var cardH = 196;
        var cardX = cx - (cardW / 2);
        var cardY = 124; // Starts higher to leave plenty of room inside

        dc.setColor(0x12151f, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cardX, cardY, cardW, cardH, 14);
        dc.setColor(0x28324a, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cardX, cardY, cardW, cardH, 14);

        // Header inside card
        dc.setColor(0xff9500, Graphics.COLOR_TRANSPARENT); // Orange
        dc.drawText(cx, cardY + 10, fontXtiny, "LETZTE NACHRICHT", Graphics.TEXT_JUSTIFY_CENTER);

        // Subtle separator line
        dc.setColor(0x222a3a, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cardX + 20, cardY + 32, cardX + cardW - 20, cardY + 32);

        // Multi-line message text with dynamic wrapping and generous line spacing
        var maxTextWidth = cardW - 36;
        var lines = wrapText(dc, bleMgr.lastReceivedMessage, fontXtiny, maxTextWidth, 4);
        var fontH = dc.getFontHeight(fontXtiny);
        var lineSpacing = 8;
        var lineHeight = fontH + lineSpacing;
        var totalTextH = (lines.size() > 0) ? ((lines.size() - 1) * lineHeight + fontH) : 0;
        var availableH = cardH - 74; // Space between separator (y+34) and footer (cardH-34)
        var startY = cardY + 36 + ((availableH - totalTextH) / 2);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(cx, startY + (i * lineHeight), fontXtiny, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Sender footer (just sender name, without 'Absender:')
        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cardY + cardH - 24, fontXtiny, bleMgr.lastSender, Graphics.TEXT_JUSTIFY_CENTER);

        // 3. Subtle bottom summary line (positioned higher to leave room for bottom nav)
        var bat = tlm.getBatteryPercent().toNumber();
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 85, fontXtiny, "Batt: " + bat + "%", Graphics.TEXT_JUSTIFY_CENTER);
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
        var gpsFont = tlm.hasGpsFix ? fontTiny : fontXtiny;
        dc.setColor(gpsColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(box2X + (boxW/2), row1Y + 36, gpsFont, gpsText, Graphics.TEXT_JUSTIFY_CENTER);

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
    // NAVIGATION INDICATORS (Standard Garmin triangles + 2 o'clock START cue)
    // -----------------------------------------------------------------
    private function drawNavigationIndicators(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var r = (w / 2) - 4;

        var fontXtiny = Graphics.FONT_SYSTEM_XTINY;

        // -------------------------------------------------------------
        // 1. STANDARD GARMIN PAGE NAVIGATION TRIANGLES (No text)
        // -------------------------------------------------------------
        var triW = 12;
        var triH = 7;
        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);

        if (pageIndex == 0) {
            // Main page: Down triangle at bottom center
            var triY = h - 28;
            dc.fillPolygon([
                [cx - (triW / 2), triY],
                [cx + (triW / 2), triY],
                [cx, triY + triH]
            ]);
        } else {
            // Data page: Up triangle at top center
            var triY = 18;
            dc.fillPolygon([
                [cx - (triW / 2), triY + triH],
                [cx + (triW / 2), triY + triH],
                [cx, triY]
            ]);
        }

        // -------------------------------------------------------------
        // 2. BUTTON AT 2 O'CLOCK (START / SELECT)
        // -------------------------------------------------------------
        var btnLabel = (pageIndex == 0) ? "MENÜ" : "POS";
        var accentColor = 0xff9500; // Consistent Garmin Fenix Orange Accent

        // Curved accent arc at 2 o'clock (centered at 30 deg: from 45 deg to 15 deg CLOCKWISE)
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 45, 15);
        dc.setPenWidth(1);

        // Draw radial text at 2 o'clock (30 degrees)
        if (_vectorFont != null && (dc has :drawRadialText)) {
            dc.drawRadialText(
                cx,
                cy,
                _vectorFont,
                btnLabel,
                Graphics.TEXT_JUSTIFY_CENTER,
                30,
                r - 18,
                Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE
            );
        } else {
            // Fallback if vector font not supported
            dc.drawText(w - 28, 110, fontXtiny, btnLabel, Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    private function drawTelemetryBox(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, title as String, bgColor as Number) as Void {
        dc.setColor(bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 8);
        dc.setColor(0x282c38, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, h, 8);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + (w/2), y + 8, Graphics.FONT_SYSTEM_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function wrapText(dc as Graphics.Dc, text as String, font as Graphics.FontDefinition, maxWidth as Number, maxLines as Number) as Array<String> {
        var lines = [] as Array<String>;
        if (text == null || text.length() == 0) {
            return lines;
        }

        var words = [] as Array<String>;
        var currentWord = "";
        for (var i = 0; i < text.length(); i++) {
            var ch = text.substring(i, i + 1);
            if (ch.equals(" ") || ch.equals("\n")) {
                if (currentWord.length() > 0) {
                    words.add(currentWord);
                    currentWord = "";
                }
            } else {
                currentWord += ch;
            }
        }
        if (currentWord.length() > 0) {
            words.add(currentWord);
        }

        var currentLine = "";
        for (var wIdx = 0; wIdx < words.size(); wIdx++) {
            var word = words[wIdx];
            var testLine = (currentLine.length() == 0) ? word : (currentLine + " " + word);
            var testWidth = dc.getTextWidthInPixels(testLine, font);

            if (testWidth <= maxWidth) {
                currentLine = testLine;
            } else {
                if (currentLine.length() > 0) {
                    lines.add(currentLine);
                    if (lines.size() >= maxLines) {
                        currentLine = "";
                        break;
                    }
                }
                if (dc.getTextWidthInPixels(word, font) > maxWidth) {
                    var subWord = "";
                    for (var c = 0; c < word.length(); c++) {
                        var charStr = word.substring(c, c + 1);
                        if (dc.getTextWidthInPixels(subWord + charStr, font) <= maxWidth) {
                            subWord += charStr;
                        } else {
                            lines.add(subWord);
                            subWord = charStr;
                            if (lines.size() >= maxLines) {
                                break;
                            }
                        }
                    }
                    currentLine = subWord;
                } else {
                    currentLine = word;
                }
            }
        }

        if (currentLine.length() > 0 && lines.size() < maxLines) {
            lines.add(currentLine);
        }

        if (lines.size() == maxLines && words.size() > lines.size()) {
            var lastIdx = lines.size() - 1;
            var lastLine = lines[lastIdx];
            if (dc.getTextWidthInPixels(lastLine + "...", font) <= maxWidth) {
                lines[lastIdx] = lastLine + "...";
            }
        }

        return lines;
    }
}
