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
        if (bleMgr.isSyncing) {
            statusColor = 0x00d4ff; // Cyan
            statusText = "Sync mit Node...";
        } else if (bleMgr.isConnected) {
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

        // 2. ENLARGED MESSAGE CARD: Moved lower and expanded for maximum text lines
        var cardW = (w * 0.81).toNumber();
        var cardH = 216;
        var cardX = cx - (cardW / 2);
        var cardY = 136; // Positioned lower to balance screen and maximize height

        dc.setColor(0x12151f, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cardX, cardY, cardW, cardH, 14);
        dc.setColor(0x28324a, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cardX, cardY, cardW, cardH, 14);

        var fontH = dc.getFontHeight(fontXtiny);

        // Header inside card: Replaces "LETZTE NACHRICHT" with actual Sender name
        var senderTitle = bleMgr.lastSender;
        if (senderTitle == null || senderTitle.length() == 0 || senderTitle.equals("Mesh")) {
            if (bleMgr.lastReceivedMessage.equals("Bereit zum Empfang")) {
                senderTitle = "BEREIT ZUM EMPFANG";
            } else {
                senderTitle = "NACHRICHT";
            }
        }
        
        // Truncate senderTitle if too wide for the card
        var maxSenderW = cardW - 44;
        if (dc.getTextWidthInPixels(senderTitle, fontXtiny) > maxSenderW) {
            while (dc.getTextWidthInPixels(senderTitle + "...", fontXtiny) > maxSenderW && senderTitle.length() > 3) {
                senderTitle = senderTitle.substring(0, senderTitle.length() - 1);
            }
            senderTitle += "...";
        }

        var headerY = cardY + 10;
        dc.setColor(0xff9500, Graphics.COLOR_TRANSPARENT); // Garmin Orange Accent
        dc.drawText(cx, headerY, fontXtiny, senderTitle, Graphics.TEXT_JUSTIFY_CENTER);

        // Subtle separator line
        var sepY = headerY + fontH + 4;
        dc.setColor(0x222a3a, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cardX + 20, sepY, cardX + cardW - 20, sepY);

        // Multi-line message text: Full height used (no bottom sender footer needed)
        var maxTextWidth = cardW - 32;
        var lineSpacing = 4;
        var lineHeight = fontH + lineSpacing;
        
        var msgTop = sepY + 6;
        var msgBottom = cardY + cardH - 10;
        var availableH = msgBottom - msgTop;
        var maxLines = (availableH / lineHeight).toNumber();
        if (maxLines < 1) { maxLines = 1; }

        var lines = wrapText(dc, bleMgr.lastReceivedMessage, fontXtiny, maxTextWidth, maxLines);
        var totalTextH = (lines.size() > 0) ? ((lines.size() - 1) * lineHeight + fontH) : 0;
        var startY = msgTop + ((availableH - totalTextH) / 2);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(cx, startY + (i * lineHeight), fontXtiny, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // 3. Compact status footer with vector symbols: [Bat-Icon] 85% | -84 dBm | [Mesh-Icon] 3
        var bat = tlm.getBatteryPercent().toNumber();
        var batText = bat.toString() + "%";
        var divText = " | ";

        var loraText = "Offline";
        var loraColor = 0x666666;
        var nodeText = "0";
        var nodeColor = 0x666666;

        if (bleMgr.isConnected) {
            if (bleMgr.loraRssi != null) {
                var rssi = bleMgr.loraRssi as Number;
                loraText = rssi.toString() + " dBm";
                if (rssi >= -90) {
                    loraColor = 0x00e676; // Bright Green (Exzellent / Stark)
                } else if (rssi >= -105) {
                    loraColor = 0xffea00; // Bright Yellow (Mittel)
                } else {
                    loraColor = 0xff5555; // Red/Orange (Schwach)
                }
            } else {
                loraText = "OK";
                loraColor = 0x00e676;
            }
            nodeText = bleMgr.peerCount.toString();
            nodeColor = 0x00d4ff; // Cyan
        }

        var iconBatW = 20; // 18 + 2 terminal
        var gapIconText = 4;
        var iconNodeW = 13;

        var wBatText = dc.getTextWidthInPixels(batText, fontXtiny);
        var wDiv = dc.getTextWidthInPixels(divText, fontXtiny);
        var wLora = dc.getTextWidthInPixels(loraText, fontXtiny);
        var wNodeText = dc.getTextWidthInPixels(nodeText, fontXtiny);

        var totalStatusW = iconBatW + gapIconText + wBatText + wDiv + wLora + wDiv + iconNodeW + gapIconText + wNodeText;
        var curX = cx - (totalStatusW / 2);
        var statusY = h - 78;
        var iconY = statusY + ((fontH - 10) / 2);

        // Draw Battery Icon & %
        drawBatteryIcon(dc, curX, iconY, bat);
        curX += iconBatW + gapIconText;
        dc.setColor(0xaaaaaa, Graphics.COLOR_TRANSPARENT);
        dc.drawText(curX, statusY, fontXtiny, batText, Graphics.TEXT_JUSTIFY_LEFT);
        curX += wBatText;

        // Draw Div 1
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(curX, statusY, fontXtiny, divText, Graphics.TEXT_JUSTIFY_LEFT);
        curX += wDiv;

        // Draw LoRa RSSI
        dc.setColor(loraColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(curX, statusY, fontXtiny, loraText, Graphics.TEXT_JUSTIFY_LEFT);
        curX += wLora;

        // Draw Div 2
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(curX, statusY, fontXtiny, divText, Graphics.TEXT_JUSTIFY_LEFT);
        curX += wDiv;

        // Draw Mesh Nodes Icon & Count
        drawMeshNodesIcon(dc, curX, iconY, nodeColor);
        curX += iconNodeW + gapIconText;
        dc.setColor(nodeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(curX, statusY, fontXtiny, nodeText, Graphics.TEXT_JUSTIFY_LEFT);
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

    private function drawBatteryIcon(dc as Graphics.Dc, x as Number, y as Number, percent as Number) as Void {
        var bw = 18;
        var bh = 10;
        
        // Battery outer border
        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, bw, bh, 2);
        // Battery terminal bump
        dc.fillRectangle(x + bw, y + 3, 2, 4);

        // Fill bar based on percentage
        var fillW = ((bw - 4) * percent / 100).toNumber();
        if (fillW > (bw - 4)) { fillW = bw - 4; }
        if (fillW < 1 && percent > 0) { fillW = 1; }

        var fillColor = 0x00e676; // Green
        if (percent <= 20) {
            fillColor = 0xff5555; // Red
        } else if (percent <= 40) {
            fillColor = 0xffea00; // Yellow
        }

        dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 2, y + 2, fillW, bh - 4);
    }

    private function drawMeshNodesIcon(dc as Graphics.Dc, x as Number, y as Number, color as Number) as Void {
        // 3 connected mesh nodes (triangle topology graph)
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + 6, y + 1, x + 1, y + 9);
        dc.drawLine(x + 6, y + 1, x + 11, y + 9);
        dc.drawLine(x + 1, y + 9, x + 11, y + 9);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 6, y + 1, 2);
        dc.fillCircle(x + 1, y + 9, 2);
        dc.fillCircle(x + 11, y + 9, 2);
    }
}
