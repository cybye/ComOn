import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Application.Storage;
import Toybox.System;

class SettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => I18n.get(Rez.Strings.SettingsTitle) });

        // Background check interval (defensive)
        var bgInt = 300;
        try {
            var rawBg = Storage.getValue("bgInterval");
            if (rawBg != null && (rawBg instanceof Number)) {
                bgInt = rawBg;
            }
        } catch (e) {
            System.println("SettingsMenu: error reading bgInterval");
        }
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingBgCheck), getBgIntervalLabel(bgInt), "SET_BG_INTERVAL", null));

        // Pause background checks during sleep window / Do Not Disturb (default on)
        var quietOn = Storage.getValue(StorageKeys.BG_QUIET_MODE) != false;
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingBgQuiet), quietOn ? I18n.get(Rez.Strings.SettingActiveOn) : I18n.get(Rez.Strings.SettingInactiveOff), "SET_BG_QUIET", null));

        // Telemetry format (defensive)
        var telFmt = 0;
        try {
            var rawFmt = Storage.getValue("telemetryFormat");
            if (rawFmt != null && (rawFmt instanceof Number)) {
                telFmt = rawFmt;
            }
        } catch (e) {
            System.println("SettingsMenu: error reading telemetryFormat");
        }
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingTelemetryFmt), (telFmt == 0) ? I18n.get(Rez.Strings.SettingFmtBinary) : I18n.get(Rez.Strings.SettingFmtText), "SET_TEL_FORMAT", null));

        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingNodeMenu), I18n.get(Rez.Strings.SettingNodeMenuSub), "SET_NODE_MENU", null));
    }

    public static function getBgIntervalLabel(secs as Object?) as String {
        if (secs != null && (secs instanceof Number)) {
            if (secs == 300) { return I18n.get(Rez.Strings.SettingInterval5Min); }
            if (secs == 900) { return I18n.get(Rez.Strings.SettingInterval15Min); }
            if (secs == 1800) { return I18n.get(Rez.Strings.SettingInterval30Min); }
            if (secs == 3600) { return I18n.get(Rez.Strings.SettingInterval1Hour); }
            if (secs == 0) { return I18n.get(Rez.Strings.SettingIntervalDisabled); }
            return secs.toString() + "s";
        }
        return I18n.get(Rez.Strings.SettingInterval5Min);
    }
}

class NodeSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => I18n.get(Rez.Strings.SettingNodeMenu) });

        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingPairNode), I18n.get(Rez.Strings.SettingPairNodeSub), "SET_PAIR", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingSyncNode), I18n.get(Rez.Strings.SettingSyncNodeSub), "SET_SYNC", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingReleaseNode), I18n.get(Rez.Strings.SettingReleaseNodeSub), "SET_RELEASE", null));
        var probeEnabled = Storage.getValue("cfg_bg_scheduler_probe") == true;
        var probeSub = I18n.get(probeEnabled ? Rez.Strings.SettingBgProbeOn : Rez.Strings.SettingBgProbeOff);
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingBgProbe), probeSub, "SET_BG_PROBE", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingBgDiag), getBackgroundRunLabel(), "SET_BG_DIAG", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingVirtualNode), I18n.get(Rez.Strings.SettingVirtualNodeSub), "SET_SIM", null));
    }

    private function getBackgroundRunLabel() as String {
        var latest = MeshBackgroundDiagnostics.getLatest();
        if (latest == null || !latest.hasKey("outcome") || latest["outcome"] == null) {
            return I18n.get(Rez.Strings.SettingBgNoRun);
        }
        var outcome = latest["outcome"] as String;
        var messages = (latest.hasKey("messages") && latest["messages"] != null) ? (latest["messages"] as Number) : 0;
        return (outcome.equals("messages")) ? I18n.format(Rez.Strings.SettingBgMessages, [ messages ]) : outcome;
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var bleManager = getBleManager();
        if (id.equals("SET_NODE_MENU")) {
            WatchUi.pushView(new NodeSettingsMenu(), new SettingsDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("SET_BG_INTERVAL")) {
            var current = Storage.getValue("bgInterval");
            if (!(current instanceof Number)) { current = 300; }
            var next = 300;
            if (current == 300) { next = 900; }
            else if (current == 900) { next = 1800; }
            else if (current == 1800) { next = 3600; }
            else if (current == 3600) { next = 0; }
            Storage.setValue("bgInterval", next);
            item.setSubLabel(SettingsMenu.getBgIntervalLabel(next));
            WatchUi.requestUpdate();
        } else if (id.equals("SET_BG_QUIET")) {
            var nextQuiet = !(Storage.getValue(StorageKeys.BG_QUIET_MODE) != false);
            Storage.setValue(StorageKeys.BG_QUIET_MODE, nextQuiet);
            item.setSubLabel(nextQuiet ? I18n.get(Rez.Strings.SettingActiveOn) : I18n.get(Rez.Strings.SettingInactiveOff));
            WatchUi.requestUpdate();
        } else if (id.equals("SET_TEL_FORMAT")) {
            var format = Storage.getValue("telemetryFormat");
            if (!(format instanceof Number)) { format = 0; }
            var nextFormat = ((format as Number) == 0) ? 1 : 0;
            Storage.setValue("telemetryFormat", nextFormat);
            item.setSubLabel((nextFormat == 0) ? I18n.get(Rez.Strings.SettingFmtBinary) : I18n.get(Rez.Strings.SettingFmtText));
            WatchUi.requestUpdate();
        } else if (id.equals("SET_PAIR")) {
            bleManager.resumeScan();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast(I18n.get(Rez.Strings.StatusScanning), null);
        } else if (id.equals("SET_SYNC")) {
            bleManager.forceFullSync();
            WatchUi.showToast(I18n.get(Rez.Strings.ToastSyncStarted), null);
        } else if (id.equals("SET_RELEASE")) {
            bleManager.releaseNode(180, true);
            WatchUi.showToast(I18n.get(Rez.Strings.ToastNodeReleased), null);
        } else if (id.equals("SET_BG_PROBE")) {
            var enabledProbe = Storage.getValue("cfg_bg_scheduler_probe") == true;
            var nextProbe = !enabledProbe;
            Storage.setValue("cfg_bg_scheduler_probe", nextProbe);
            item.setSubLabel(nextProbe ? "5 min scheduler probe on" : "5 min scheduler probe off");
            WatchUi.requestUpdate();
        } else if (id.equals("SET_BG_DIAG")) {
            var latest = MeshBackgroundDiagnostics.getLatest();
            if (latest == null || !latest.hasKey("outcome")) {
                WatchUi.showToast("No background run recorded", null);
            } else {
                var outcome = latest["outcome"] as String;
                var state = (latest.hasKey("state") && latest["state"] != null) ? (latest["state"] as String) : "unknown";
                var detail = "";
                var startedAt = latest.hasKey("startedAt") ? latest["startedAt"] : null;
                var endedAt = latest.hasKey("endedAt") ? latest["endedAt"] : null;
                if (startedAt instanceof Number && endedAt instanceof Number) {
                    detail = " " + ((endedAt as Number) - (startedAt as Number)) + "s";
                }
                var streak = Storage.getValue(StorageKeys.BG_FAIL_STREAK);
                if (streak instanceof Number && (streak as Number) > 0) {
                    detail += " fail x" + streak;
                }
                WatchUi.showToast("Background: " + outcome + " (" + state + ")" + detail, null);
            }
        } else if (id.equals("SET_SIM")) {
            WatchUi.pushView(NodeSimulatorMenu.create(), new NodeSimulatorDelegate(), WatchUi.SLIDE_LEFT);
        }
    }

}
