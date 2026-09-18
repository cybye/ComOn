import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Activity;
import Toybox.FitContributor;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;

class MeshCoreDataField extends WatchUi.DataField {
    private var _rssiField as FitContributor.Field?;
    private var _snrField as FitContributor.Field?;
    private var _peersField as FitContributor.Field?;
    private var _batField as FitContributor.Field?;

    private var _fitLoggingEnabled as Boolean = true;
    private var _lastRssiText as String = "Offline";
    private var _lastBeaconText as String = "Wartet";
    private var _lastTargetText as String = "Kanal 0";

    function initialize() {
        DataField.initialize();

        var logSetting = Storage.getValue("fitLoggingEnabled");
        if (logSetting != null) {
            _fitLoggingEnabled = logSetting as Boolean;
        }

        // Initialize FitContributor Developer Fields for MeshMapper / Wardriving
        if (_fitLoggingEnabled) {
            try {
                _rssiField = createField("lora_rssi", 0, FitContributor.DATA_TYPE_SINT8, { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "dBm" });
                _snrField  = createField("lora_snr", 1, FitContributor.DATA_TYPE_SINT8, { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "dB" });
                _peersField = createField("mesh_nodes", 2, FitContributor.DATA_TYPE_UINT8, { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "nodes" });
                _batField  = createField("mesh_bat", 3, FitContributor.DATA_TYPE_UINT8, { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "%" });
                System.println("MeshCoreDataField: FitContributor fields initialized successfully");
            } catch (e) {
                System.println("MeshCoreDataField: FitContributor init notice: " + e.getErrorMessage());
            }
        }
    }

    //! Periodic execution (1 Hz) during activity recording
    function compute(info as Activity.Info) as Void {
        var bleMgr = getDataFieldBleManager();

        // 1. Update Telemetry Collector
        var agg = TelemetryAggregator.getInstance();
        agg.updateFromActivity(info);

        // 2. Evaluate Smart Beaconing & Dispatch
        var disp = TelemetryDispatcher.getInstance();
        disp.tick(bleMgr);

        // 3. Update FitContributor Records (Wardriving)
        if (_fitLoggingEnabled && bleMgr.isConnected) {
            var rssi = bleMgr.loraRssi;
            var snr = bleMgr.loraSnr;
            var peers = bleMgr.peerCount;

            if (_rssiField != null && rssi != null) {
                _rssiField.setData(rssi);
            }
            if (_snrField != null && snr != null) {
                _snrField.setData(snr);
            }
            if (_peersField != null) {
                _peersField.setData(peers);
            }
        }

        // 4. Update cached UI strings
        if (bleMgr.isConnected && bleMgr.loraRssi != null) {
            var snrStr = (bleMgr.loraSnr != null && bleMgr.loraSnr > 0) ? ("+" + bleMgr.loraSnr) : (bleMgr.loraSnr != null ? bleMgr.loraSnr.toString() : "-");
            _lastRssiText = bleMgr.loraRssi.toString() + " dBm (" + snrStr + " dB)";
        } else {
            _lastRssiText = bleMgr.isConnected ? I18n.get(Rez.Strings.StatusConnected) : I18n.get(Rez.Strings.StatusScanning);
        }

        var statStr = agg.isStationary ? I18n.get(Rez.Strings.TelemetryStationary) : "";
        if (disp.lastSendStatus.equals("Bereit") || disp.lastSendStatus.equals("Ready")) {
            _lastBeaconText = I18n.format(Rez.Strings.TelemetryReady, [ disp.secondsSinceLastSend ]) + statStr;
        } else {
            _lastBeaconText = disp.lastSendStatus + " (" + disp.secondsSinceLastSend + "s)" + statStr;
        }

        _lastTargetText = ContactManager.getTargetDisplayName();
    }

    //! Render high-contrast visual display on the Garmin watch face
    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;

        // Background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var bleMgr = getDataFieldBleManager();
        var fontXtiny = Graphics.FONT_XTINY;
        var fontH = dc.getFontHeight(fontXtiny);

        // 1. TOP HEADER: Status Dot + Connection Status
        var statusColor = Graphics.COLOR_RED;
        var statusText = I18n.get(Rez.Strings.StatusDisconnected);
        if (bleMgr.isConnected) {
            statusColor = Graphics.COLOR_GREEN;
            statusText = (bleMgr.deviceName != null && bleMgr.deviceName.length() > 0) ? bleMgr.deviceName : I18n.get(Rez.Strings.StatusConnected);
        } else if (bleMgr.isScanning) {
            statusColor = Graphics.COLOR_YELLOW;
            statusText = I18n.get(Rez.Strings.StatusScanning);
        }

        var topY = 34;
        var textWidth = dc.getTextWidthInPixels(statusText, fontXtiny);
        var dotX = cx - (textWidth / 2) - 12;

        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, topY + 13, 5);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 4, topY, fontXtiny, statusText, Graphics.TEXT_JUSTIFY_CENTER);

        // Target Channel / Contact Badge: Identical cyan style directly below status
        var targetY = 64;
        dc.setColor(0x00d4ff, Graphics.COLOR_TRANSPARENT); // Cyan Accent
        dc.drawText(cx, targetY, fontXtiny, "[" + ContactManager.getTargetDisplayName() + "]", Graphics.TEXT_JUSTIFY_CENTER);

        // 2. PROMINENT CHAT / MESSAGE CARD: Exactly identical position & proportions to Watch App
        var cardW = (width * 0.81).toNumber();
        var cardH = 216;
        var cardX = cx - (cardW / 2);
        var cardY = 136;

        // Card container
        dc.setColor(0x12151f, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cardX, cardY, cardW, cardH, 14);
        dc.setColor(0x28324a, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cardX, cardY, cardW, cardH, 14);

        // Message Sender & Preview inside Card
        var senderName = bleMgr.lastSender;
        var hasCustomSender = (senderName != null && senderName.length() > 0 && !senderName.equals("Mesh"));

        if (hasCustomSender) {
            var senderTitle = senderName;
            var maxSenderW = cardW - 44;
            if (dc.getTextWidthInPixels(senderTitle, fontXtiny) > maxSenderW) {
                while (dc.getTextWidthInPixels(senderTitle + "...", fontXtiny) > maxSenderW && senderTitle.length() > 3) {
                    senderTitle = senderTitle.substring(0, senderTitle.length() - 1);
                }
                senderTitle += "...";
            }

            var headerY = cardY + 10;
            dc.setColor(0xff9500, Graphics.COLOR_TRANSPARENT); // Garmin Orange Accent
            dc.drawText(cx, headerY, fontXtiny, senderTitle + ":", Graphics.TEXT_JUSTIFY_CENTER);

            // Subtle separator line
            var sepY = headerY + fontH + 4;
            dc.setColor(0x222a3a, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cardX + 20, sepY, cardX + cardW - 20, sepY);

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
        } else {
            // When no custom sender, center cleanly without redundant header or line
            var msgText = bleMgr.lastReceivedMessage;
            if (msgText == null || msgText.length() == 0 || msgText.equals("Bereit zum Empfang")) {
                msgText = I18n.get(Rez.Strings.ReadyToReceive);
            }
            var maxTextWidth = cardW - 32;
            var lineSpacing = 4;
            var lineHeight = fontH + lineSpacing;
            var lines = wrapText(dc, msgText, fontXtiny, maxTextWidth, 4);
            var totalTextH = (lines.size() > 0) ? ((lines.size() - 1) * lineHeight + fontH) : 0;
            var startY = cardY + ((cardH - totalTextH) / 2);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            for (var j = 0; j < lines.size(); j++) {
                dc.drawText(cx, startY + (j * lineHeight), fontXtiny, lines[j], Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // 3. IDENTICAL STATUS FOOTER WITH VECTOR SYMBOLS: [Bat-Icon] 84% | -76 dBm | [Mesh-Icon] 5
        var bat = 0;
        var batText = "--%";
        if (bleMgr.isConnected) {
            if (bleMgr.nodeBatteryPercent != null) {
                bat = bleMgr.nodeBatteryPercent as Number;
                batText = bat.toString() + "%";
            } else if (bleMgr.isSimulated) {
                bat = bleMgr.virtualNode.batteryPercent;
                batText = bat.toString() + "%";
            }
        }
        var divText = " | ";

        var loraText = I18n.get(Rez.Strings.TelemetryOff);
        var loraColor = 0x666666;
        var nodeText = "0";
        var nodeColor = 0x666666;

        if (bleMgr.isConnected) {
            if (bleMgr.loraRssi != null) {
                var rssi = bleMgr.loraRssi as Number;
                loraText = rssi.toString() + " dBm";
                if (rssi >= -90) {
                    loraColor = 0x00e676; // Bright Green
                } else if (rssi >= -105) {
                    loraColor = 0xffea00; // Yellow
                } else {
                    loraColor = 0xff5555; // Red
                }
            } else {
                loraText = I18n.get(Rez.Strings.TelemetryOk);
                loraColor = 0x00e676;
            }
            nodeText = bleMgr.peerCount.toString();
            nodeColor = 0x00d4ff; // Cyan
        }

        var iconBatW = 20;
        var gapIconText = 4;
        var iconNodeW = 13;

        var wBatText = dc.getTextWidthInPixels(batText, fontXtiny);
        var wDiv = dc.getTextWidthInPixels(divText, fontXtiny);
        var wLora = dc.getTextWidthInPixels(loraText, fontXtiny);
        var wNodeText = dc.getTextWidthInPixels(nodeText, fontXtiny);

        var totalStatusW = iconBatW + gapIconText + wBatText + wDiv + wLora + wDiv + iconNodeW + gapIconText + wNodeText;
        var curX = cx - (totalStatusW / 2);
        var statusY = 372;
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

        // 4. BEACON / TELEMETRIE STATUS (DataField-spezifisch)
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 404, fontXtiny, _lastBeaconText, Graphics.TEXT_JUSTIFY_CENTER);
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

    private function wrapText(dc as Graphics.Dc, text as String, font as Graphics.FontDefinition, maxWidth as Number, maxLines as Number) as Array<String> {
        var lines = [] as Array<String>;
        var words = [] as Array<String>;
        var startIdx = 0;
        for (var i = 0; i < text.length(); i++) {
            if (text.substring(i, i + 1).equals(" ")) {
                if (i > startIdx) {
                    words.add(text.substring(startIdx, i));
                }
                startIdx = i + 1;
            }
        }
        if (startIdx < text.length()) {
            words.add(text.substring(startIdx, text.length()));
        }

        var currentLine = "";
        for (var w = 0; w < words.size(); w++) {
            var word = words[w];
            var testLine = (currentLine.length() == 0) ? word : (currentLine + " " + word);
            if (dc.getTextWidthInPixels(testLine, font) <= maxWidth) {
                currentLine = testLine;
            } else {
                if (currentLine.length() > 0) {
                    lines.add(currentLine);
                    currentLine = "";
                    if (lines.size() >= maxLines) {
                        break;
                    }
                }
                currentLine = word;
            }
        }
        if (currentLine.length() > 0 && lines.size() < maxLines) {
            lines.add(currentLine);
        }
        return lines;
    }
}
