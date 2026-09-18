import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Application.Storage;

class SettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => I18n.get(Rez.Strings.SettingsTitle) });

        var currentKeyMode = KeyboardHelper.getModeName(KeyboardHelper.getKeyboardMode());
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingKeyboardType), currentKeyMode, "SET_KEYBOARD", null));
        
        // Background check interval
        var bgInt = Storage.getValue("bgInterval");
        if (bgInt == null) { bgInt = 300; }
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingBgCheck), getBgIntervalLabel(bgInt as Number), "SET_BG_INTERVAL", null));

        // Wardriving FIT Logging
        var fitLog = Storage.getValue("fitLoggingEnabled");
        if (fitLog == null) { fitLog = true; }
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingWardriving), (fitLog == true) ? I18n.get(Rez.Strings.SettingActiveOn) : I18n.get(Rez.Strings.SettingInactiveOff), "SET_WARDRIVING", null));

        // Telemetry format
        var telFmt = Storage.getValue("telemetryFormat");
        if (telFmt == null) { telFmt = 0; }
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingTelemetryFmt), (telFmt == 0) ? I18n.get(Rez.Strings.SettingFmtBinary) : I18n.get(Rez.Strings.SettingFmtText), "SET_TEL_FORMAT", null));

        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingPairNode), I18n.get(Rez.Strings.SettingPairNodeSub), "SET_PAIR", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingSyncNode), I18n.get(Rez.Strings.SettingSyncNodeSub), "SET_SYNC", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingReleaseNode), I18n.get(Rez.Strings.SettingReleaseNodeSub), "SET_RELEASE", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingVirtualNode), I18n.get(Rez.Strings.SettingVirtualNodeSub), "SET_SIM", null));
    }

    public static function getBgIntervalLabel(secs as Number) as String {
        if (secs == 300) { return I18n.get(Rez.Strings.SettingInterval5Min); }
        if (secs == 900) { return I18n.get(Rez.Strings.SettingInterval15Min); }
        if (secs == 1800) { return I18n.get(Rez.Strings.SettingInterval30Min); }
        if (secs == 3600) { return I18n.get(Rez.Strings.SettingInterval1Hour); }
        if (secs == 0) { return I18n.get(Rez.Strings.SettingIntervalDisabled); }
        return secs.toString() + "s";
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var bleMgr = getBleManager();

        if (id.equals("SET_KEYBOARD")) {
            WatchUi.pushView(new KeyboardSettingsMenu(), new KeyboardSettingsDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("SET_BG_INTERVAL")) {
            var cur = Storage.getValue("bgInterval");
            if (cur == null) { cur = 300; }
            var nextSecs = 300;
            if (cur == 300) { nextSecs = 900; }
            else if (cur == 900) { nextSecs = 1800; }
            else if (cur == 1800) { nextSecs = 3600; }
            else if (cur == 3600) { nextSecs = 0; }
            else { nextSecs = 300; }
            Storage.setValue("bgInterval", nextSecs);
            item.setSubLabel(SettingsMenu.getBgIntervalLabel(nextSecs));
            WatchUi.requestUpdate();
        } else if (id.equals("SET_WARDRIVING")) {
            var curFit = Storage.getValue("fitLoggingEnabled");
            if (curFit == null) { curFit = true; }
            var nextFit = !(curFit as Boolean);
            Storage.setValue("fitLoggingEnabled", nextFit);
            item.setSubLabel(nextFit ? I18n.get(Rez.Strings.SettingActiveOn) : I18n.get(Rez.Strings.SettingInactiveOff));
            WatchUi.requestUpdate();
        } else if (id.equals("SET_TEL_FORMAT")) {
            var curFmt = Storage.getValue("telemetryFormat");
            if (curFmt == null) { curFmt = 0; }
            var nextFmt = ((curFmt as Number) == 0) ? 1 : 0;
            Storage.setValue("telemetryFormat", nextFmt);
            item.setSubLabel((nextFmt == 0) ? I18n.get(Rez.Strings.SettingFmtBinary) : I18n.get(Rez.Strings.SettingFmtText));
            WatchUi.requestUpdate();
        } else if (id.equals("SET_PAIR")) {
            bleMgr.resumeScan();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast(I18n.get(Rez.Strings.StatusScanning), null);
        } else if (id.equals("SET_SYNC")) {
            bleMgr.resumeScan();
            bleMgr.forceFullSync();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast(I18n.get(Rez.Strings.ToastSyncStarted), null);
        } else if (id.equals("SET_RELEASE")) {
            bleMgr.releaseNode(180);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast(I18n.get(Rez.Strings.ToastNodeReleased), null);
        } else if (id.equals("SET_SIM")) {
            WatchUi.pushView(new NodeSimulatorMenu(), new NodeSimulatorDelegate(), WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() as Void {
        System.println("SettingsDelegate: onBack");
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
