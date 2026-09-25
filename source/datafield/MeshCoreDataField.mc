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
    private var _lastTargetText as String = "#public";
    private var _dataPointsCaptured as Number = 0;
    private var _timerState as Number = 0; // 0=Stopped/Off, 1=Recording, 2=Paused
    private var _reconnectTick as Number = 0;

    function initialize() {
        DataField.initialize();
        System.println("MeshCoreDataField: initialize() started");
        _lastTargetText = ContactManager.getActivityTelemetryTargetName();

        var logSetting = Storage.getValue("fitLoggingEnabled");
        if (logSetting != null && (logSetting instanceof Boolean)) {
            _fitLoggingEnabled = logSetting as Boolean;
        } else {
            _fitLoggingEnabled = true;
        }
        System.println("MeshCoreDataField: fitLoggingEnabled=" + _fitLoggingEnabled);

        // Initialize FitContributor Developer Fields for MeshMapper / Wardriving
        if (_fitLoggingEnabled) {
            try {
                _rssiField = createField("lora_rssi", 0, FitContributor.DATA_TYPE_FLOAT, { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "dBm" });
                _snrField  = createField("lora_snr", 1, FitContributor.DATA_TYPE_FLOAT, { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "dB" });
                _peersField = createField("mesh_nodes", 2, FitContributor.DATA_TYPE_FLOAT, { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "nodes" });
                _batField  = createField("mesh_bat", 3, FitContributor.DATA_TYPE_FLOAT, { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "%" });

                if (_rssiField != null) { _rssiField.setData(0.0); }
                if (_snrField != null)  { _snrField.setData(0.0); }
                if (_peersField != null) { _peersField.setData(0.0); }
                if (_batField != null)  { _batField.setData(0.0); }

                Storage.setValue("dbg_fit_init", "ok");
                System.println("MeshCoreDataField: FitContributor fields initialized successfully (4 record float)");
            } catch (e) {
                Storage.setValue("dbg_fit_init", "err: " + e.getErrorMessage());
                System.println("MeshCoreDataField: FitContributor init EXCEPTION: " + e.getErrorMessage());
            }
        } else {
            Storage.setValue("dbg_fit_init", "disabled");
            System.println("MeshCoreDataField: FitContributor is disabled via Storage setting");
        }
    }

    public function onTimerStart() as Void {
        System.println("MeshCoreDataField: onTimerStart() event received from OS");
        _timerState = 1;
        TelemetryDispatcher.getInstance().triggerImmediateBeacon();
    }

    public function onTimerStop() as Void {
        System.println("MeshCoreDataField: onTimerStop() event received from OS");
        _timerState = 0;
    }

    public function onTimerPause() as Void {
        System.println("MeshCoreDataField: onTimerPause() event received from OS");
        _timerState = 2;
    }

    public function onTimerResume() as Void {
        System.println("MeshCoreDataField: onTimerResume() event received from OS");
        _timerState = 1;
    }

    public function onTimerReset() as Void {
        System.println("MeshCoreDataField: onTimerReset() event received from OS");
        _timerState = 0;
    }

    //! Periodic execution (1 Hz) during activity recording
    function compute(info as Activity.Info) as Void {
        if (info != null && (info has :timerState) && info.timerState != null) {
            if (info.timerState == Activity.TIMER_STATE_ON) {
                _timerState = 1;
            } else if (info.timerState == Activity.TIMER_STATE_PAUSED) {
                _timerState = 2;
            } else if (info.timerState == Activity.TIMER_STATE_STOPPED || info.timerState == Activity.TIMER_STATE_OFF) {
                _timerState = 0;
            }
        }

        var bleMgr = getDataFieldBleManager();

        _reconnectTick++;
        if (!bleMgr.isConnected && !bleMgr.isScanning && (_reconnectTick % 5 == 0)) {
            bleMgr.connectLatestOrScan();
        }

        // Periodically refresh node battery & radio stats during activity (every 30s)
        if (bleMgr.isConnected && !bleMgr.isSyncing && (_reconnectTick % 30 == 0)) {
            bleMgr.requestNodeBattery();
        }

        // 1. Update Telemetry Collector
        var agg = TelemetryAggregator.getInstance();
        agg.updateFromActivity(info);

        // 2. Evaluate Smart Beaconing & Dispatch
        var disp = TelemetryDispatcher.getInstance();
        disp.tick(bleMgr);

        // 3. Update FitContributor Records (Wardriving)
        if (_fitLoggingEnabled) {
            var isConn = bleMgr.isConnected;
            var rssi = isConn ? bleMgr.loraRssi : null;
            var snr = isConn ? bleMgr.loraSnr : null;
            var peers = isConn ? bleMgr.peerCount : 0;
            var bat = isConn ? bleMgr.nodeBatteryPercent : null;

            try {
                if (_rssiField != null) {
                    _rssiField.setData((rssi != null) ? (rssi as Number).toFloat() : 0.0);
                }
                if (_snrField != null) {
                    _snrField.setData((snr != null) ? (snr as Number).toFloat() : 0.0);
                }
                if (_peersField != null) {
                    _peersField.setData((peers as Number).toFloat());
                }
                if (_batField != null) {
                    _batField.setData((bat != null) ? (bat as Number).toFloat() : 0.0);
                }
            } catch (e) {
                System.println("MeshCoreDataField: setData exception: " + e.getErrorMessage());
            }

            if (isConn) {
                _dataPointsCaptured++;
            }
        }

        if (_dataPointsCaptured % 10 == 0) {
            System.println("MeshCoreDataField: compute() tick, captured=" + _dataPointsCaptured + ", isConn=" + bleMgr.isConnected);
        }

        // 4. Update cached telemetry target name
        _lastTargetText = ContactManager.getActivityTelemetryTargetName();
    }

    private var _isCompact as Boolean = false;

    function onLayout(dc as Graphics.Dc) as Void {
        DisplayProfile.init(dc);
        _isCompact = (dc.getHeight() < DisplayProfile.scale(180));
    }

    //! Render high-contrast visual display on the Garmin watch face
    function onUpdate(dc as Graphics.Dc) as Void {
        DisplayProfile.init(dc);
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        _isCompact = (height < DisplayProfile.scale(180));

        // Background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var bleMgr = getDataFieldBleManager();
        var disp = TelemetryDispatcher.getInstance();
        var agg = TelemetryAggregator.getInstance();

        var fontXtiny = Graphics.FONT_XTINY;
        var fontTiny = Graphics.FONT_TINY;
        var hXtiny = dc.getFontHeight(fontXtiny);
        var hTiny = dc.getFontHeight(fontTiny);

        // Technical Vital readings (Battery, RSSI)
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

        var loraText = I18n.get(Rez.Strings.TelemetryOff);
        var loraColor = 0x666666;
        var nodeText = "0";
        var nodeColor = 0x666666;

        if (bleMgr.isConnected) {
            if (bleMgr.loraRssi != null) {
                var rssi = bleMgr.loraRssi as Number;
                loraText = rssi.toString() + "dBm";
                if (rssi >= -90) {
                    loraColor = DisplayTheme.accent();
                } else if (rssi >= -105) {
                    loraColor = 0xffea00;
                } else {
                    loraColor = 0xff5555;
                }
            } else {
                loraText = I18n.get(Rez.Strings.TelemetryOk);
                loraColor = DisplayTheme.accent();
            }
            nodeText = bleMgr.peerCount.toString();
            nodeColor = 0x00d4ff;
        }

        // -------------------------------------------------------------
        // COMPACT WORKOUT LAYOUT (< 180px height e.g. 2-field, 3-field)
        // -------------------------------------------------------------
        if (_isCompact) {
            var isTargetActive = ContactManager.hasActivityTelemetryTarget();
            var mainText = isTargetActive ? ("TX: " + _lastTargetText) : I18n.get(Rez.Strings.DfStatusStandby);
            var mainColor = isTargetActive ? DisplayTheme.accent() : DisplayTheme.muted();

            dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (height * 0.28).toNumber(), fontTiny, mainText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            var subText = batText + " | " + loraText + " | " + _dataPointsCaptured + "pts";
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (height * 0.72).toNumber(), fontXtiny, subText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // -------------------------------------------------------------
        // FULL SCREEN 5-TIER LAYOUT
        // -------------------------------------------------------------
        // 1. TOP HEADER: Status Dot + Node Name
        var statusColor = Graphics.COLOR_RED;
        var statusText = I18n.get(Rez.Strings.StatusDisconnected);
        if (bleMgr.isConnected) {
            statusColor = DisplayTheme.accent();
            statusText = (bleMgr.deviceName != null && bleMgr.deviceName.length() > 0) ? bleMgr.deviceName : I18n.get(Rez.Strings.StatusConnected);
        } else if (bleMgr.isScanning) {
            statusColor = Graphics.COLOR_YELLOW;
            statusText = I18n.get(Rez.Strings.StatusScanning);
        }

        var headerY = (height * 0.08).toNumber();
        var textWidth = dc.getTextWidthInPixels(statusText, fontXtiny);
        var dotX = cx - (textWidth / 2) - DisplayProfile.scale(10);

        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, headerY + (hXtiny / 2), DisplayProfile.scale(4));

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + DisplayProfile.scale(4), headerY, fontXtiny, statusText, Graphics.TEXT_JUSTIFY_CENTER);

        // 2. SECTION 1: RECORDING / FIT LOGGING STATUS
        var recY = headerY + hXtiny + DisplayProfile.scale(14);
        var recSubY = recY + hTiny + DisplayProfile.scale(2);
        var recTitle = I18n.get(Rez.Strings.DfStatusStandby);
        var recTitleColor = DisplayTheme.muted();
        var recSub = I18n.get(Rez.Strings.DfSubReady);
        var recSubColor = DisplayTheme.muted();

        if (_fitLoggingEnabled) {
            if (_timerState == 1) {
                recTitle = I18n.get(Rez.Strings.DfStatusRecording);
                recTitleColor = DisplayTheme.accent();
                recSub = I18n.format(Rez.Strings.DfSubPointsCaptured, [ _dataPointsCaptured ]);
                recSubColor = DisplayTheme.accent();
            } else if (_timerState == 2) {
                recTitle = I18n.get(Rez.Strings.DfStatusPaused);
                recTitleColor = 0xffea00;
                recSub = I18n.get(Rez.Strings.DfSubActivityPaused);
                recSubColor = DisplayTheme.muted();
            }
        }

        if (_timerState == 1 && _fitLoggingEnabled) {
            var recTw = dc.getTextWidthInPixels(recTitle, fontTiny);
            dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - (recTw / 2) - DisplayProfile.scale(10), recY + (hTiny / 2), DisplayProfile.scale(4));
        }
        dc.setColor(recTitleColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, recY, fontTiny, recTitle, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(recSubColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, recSubY, fontXtiny, recSub, Graphics.TEXT_JUSTIFY_CENTER);

        // 3. SECTION 2: MESH TRANSMISSION (TX) STATUS
        var isTargetActive = ContactManager.hasActivityTelemetryTarget();
        var txY = recSubY + hXtiny + DisplayProfile.scale(14);
        var txSubY = txY + hTiny + DisplayProfile.scale(2);

        var txTitle = I18n.get(Rez.Strings.DfStatusTxOff);
        var txTitleColor = 0xff9100;
        var txSub = I18n.get(Rez.Strings.DfSubFitLogOnly);
        var txSubColor = DisplayTheme.muted();

        if (isTargetActive) {
            var isRecent = (disp.secondsSinceLastSend < 20 && (disp.lastSendStatus.find("Aktivit") != null || disp.lastSendStatus.find("vor") != null || disp.lastSendStatus.find("ago") != null));
            txTitle = "TX: " + _lastTargetText;
            txTitleColor = isRecent ? DisplayTheme.accent() : 0x00d4ff;
            if (isRecent) {
                txSub = I18n.format(Rez.Strings.DfSubSentAgo, [ disp.secondsSinceLastSend ]);
                txSubColor = DisplayTheme.accent();
            } else {
                txSub = disp.lastSendStatus + " (" + disp.secondsSinceLastSend + "s)";
                txSubColor = DisplayTheme.muted();
            }
        }

        dc.setColor(txTitleColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, txY, fontTiny, txTitle, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(txSubColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, txSubY, fontXtiny, txSub, Graphics.TEXT_JUSTIFY_CENTER);

        // 4. SUBTLE DIVIDER & SECONDARY VOLUME INFO
        var divY = txSubY + hXtiny + DisplayProfile.scale(12);
        var volY = divY + DisplayProfile.scale(6);
        var divArm = DisplayProfile.scale(90);
        dc.setColor(DisplayTheme.divider(), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - divArm, divY, cx + divArm, divY);

        var volStr = I18n.format(Rez.Strings.DfVolumeStats, [ _dataPointsCaptured, disp.totalPacketsSent ]);
        dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, volY, fontXtiny, volStr, Graphics.TEXT_JUSTIFY_CENTER);

        // 5. TECHNICAL VITAL FOOTER
        var divText = " | ";
        var iconBatW = DisplayProfile.scale(18);
        var gapIconText = DisplayProfile.scale(4);
        var iconNodeW = DisplayProfile.scale(12);

        var wBatText = dc.getTextWidthInPixels(batText, fontXtiny);
        var wDiv = dc.getTextWidthInPixels(divText, fontXtiny);
        var wLora = dc.getTextWidthInPixels(loraText, fontXtiny);
        var wNodeText = dc.getTextWidthInPixels(nodeText, fontXtiny);

        var totalStatusW = iconBatW + gapIconText + wBatText + wDiv + wLora + wDiv + iconNodeW + gapIconText + wNodeText;
        var curX = cx - (totalStatusW / 2);
        var statusY = volY + hXtiny + DisplayProfile.scale(14);
        var iconY = statusY + ((hXtiny - DisplayProfile.scale(10)) / 2);

        // Draw Battery Icon & %
        drawBatteryIcon(dc, curX, iconY, bat);
        curX += iconBatW + gapIconText;
        dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(curX, statusY, fontXtiny, batText, Graphics.TEXT_JUSTIFY_LEFT);
        curX += wBatText;

        // Draw Div 1
        dc.setColor(DisplayTheme.divider(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(curX, statusY, fontXtiny, divText, Graphics.TEXT_JUSTIFY_LEFT);
        curX += wDiv;

        // Draw LoRa RSSI
        dc.setColor(loraColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(curX, statusY, fontXtiny, loraText, Graphics.TEXT_JUSTIFY_LEFT);
        curX += wLora;

        // Draw Div 2
        dc.setColor(DisplayTheme.divider(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(curX, statusY, fontXtiny, divText, Graphics.TEXT_JUSTIFY_LEFT);
        curX += wDiv;

        // Draw Mesh Nodes Icon & Count
        drawMeshNodesIcon(dc, curX, iconY, nodeColor);
        curX += iconNodeW + gapIconText;
        dc.setColor(nodeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(curX, statusY, fontXtiny, nodeText, Graphics.TEXT_JUSTIFY_LEFT);

        // 6. GPS STATUS INDICATOR
        var gpsY = statusY + hXtiny + DisplayProfile.scale(12);
        if (agg.hasGpsFix) {
            dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, gpsY, fontXtiny, I18n.get(Rez.Strings.DfGpsFixOk), Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, gpsY, fontXtiny, I18n.get(Rez.Strings.DfGpsSearching), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawBatteryIcon(dc as Graphics.Dc, x as Number, y as Number, percent as Number) as Void {
        var bw = DisplayProfile.scale(18);
        var bh = DisplayProfile.scale(10);
        
        // Battery outer border
        dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, bw, bh, 2);
        // Battery terminal bump
        dc.fillRectangle(x + bw, y + DisplayProfile.scale(3), DisplayProfile.scale(2), DisplayProfile.scale(4));

        // Fill bar based on percentage
        var maxInner = bw - DisplayProfile.scale(4);
        var fillW = (maxInner * percent / 100).toNumber();
        if (fillW > maxInner) { fillW = maxInner; }
        if (fillW < 1 && percent > 0) { fillW = 1; }

        var fillColor = DisplayTheme.accent();
        if (percent <= 20) {
            fillColor = 0xff5555;
        } else if (percent <= 40) {
            fillColor = 0xffea00;
        }

        dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
        if (fillW > 0) {
            dc.fillRectangle(x + DisplayProfile.scale(2), y + DisplayProfile.scale(2), fillW, bh - DisplayProfile.scale(4));
        }
    }

    private function drawMeshNodesIcon(dc as Graphics.Dc, x as Number, y as Number, color as Number) as Void {
        var p6 = DisplayProfile.scale(6);
        var p1 = DisplayProfile.scale(1);
        var p9 = DisplayProfile.scale(9);
        var p11 = DisplayProfile.scale(11);

        dc.setColor(DisplayTheme.divider(), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + p6, y + p1, x + p1, y + p9);
        dc.drawLine(x + p6, y + p1, x + p11, y + p9);
        dc.drawLine(x + p1, y + p9, x + p11, y + p9);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + p6, y + p1, DisplayProfile.scale(2));
        dc.fillCircle(x + p1, y + p9, DisplayProfile.scale(2));
        dc.fillCircle(x + p11, y + p9, DisplayProfile.scale(2));
    }
}
