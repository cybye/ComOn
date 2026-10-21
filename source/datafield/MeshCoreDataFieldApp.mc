import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.BluetoothLowEnergy;
import Toybox.Application.Storage;
import Toybox.Sensor;

class MeshCoreDataFieldApp extends Application.AppBase {
    private var _bleManager as MeshBleManager;
    private var _bleDelegate as MeshBleDelegate;

    function initialize() {
        AppBase.initialize();
        ContactManager.setIsDataFieldMode(true);
        ContactManager.loadFromStorage();
        _bleManager = new MeshBleManager();
        _bleManager.setIsDataField(true);
        _bleDelegate = new MeshBleDelegate(_bleManager);
    }

    function onStart(state as Dictionary?) as Void {
        BluetoothLowEnergy.setDelegate(_bleDelegate);
        _bleManager.registerProfile();
        
        // Auto-connect to virtual node if enabled in test mode
        var simEnabled = Storage.getValue("sim_virtualNodeEnabled");
        if (simEnabled == true) {
            _bleManager.simulateConnect("Virtual-Node");
        } else {
            _bleManager.connectLatestOrScan();
        }
    }

    function onStop(state as Dictionary?) as Void {
        _bleManager.stopScan();
        _bleManager.releaseNode(0, false);
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new MeshCoreDataField() ];
    }

    public function getBleManager() as MeshBleManager {
        return _bleManager;
    }

    public function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return [ new DataFieldSettingsMenu(), new DataFieldSettingsDelegate() ];
    }
}

function getDataFieldApp() as MeshCoreDataFieldApp {
    return Application.getApp() as MeshCoreDataFieldApp;
}

function getDataFieldBleManager() as MeshBleManager {
    return (Application.getApp() as MeshCoreDataFieldApp).getBleManager();
}

//! On-Device Settings Menu for Data Field: Channel Selection & FIT Logging
class DataFieldSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => I18n.get(Rez.Strings.DataFieldMenuTitle) });

        var activeBadge = I18n.get(Rez.Strings.ActiveBadge);

        // 1. LoRa Beacon Target: Disable TX
        var hasTarget = ContactManager.hasActivityTelemetryTarget();
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.DfMenuTxOff), !hasTarget ? activeBadge : null, "TARGET_NONE", null));

        // 2. Channels from ContactManager
        var channels = ContactManager.getChannels();
        for (var i = 0; i < channels.size(); i++) {
            var ch = channels[i];
            var label = ch[:name] as String;
            var isSel = (hasTarget && !ContactManager.isActivityTelemetryContactTarget() && ContactManager.getActivityTelemetryChannelIdx() == (ch[:idx] as Number));
            addItem(new WatchUi.MenuItem(label, isSel ? activeBadge : null, "CH_" + ch[:idx], null));
        }

        // 3. FIT Logging toggle (dedicated to DataField sandbox)
        var fitLog = Storage.getValue("fitLoggingEnabled") != false;
        var fitSub = I18n.get(fitLog ? Rez.Strings.SettingActiveOn : Rez.Strings.SettingInactiveOff);
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SettingWardriving), fitSub, "FIT_TOGGLE", null));

        // 4. Simulator toggle
        var simEnabled = Storage.getValue("sim_virtualNodeEnabled") == true;
        var simSub = I18n.get(simEnabled ? Rez.Strings.SettingEnabled : Rez.Strings.SettingDisabled);
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.DfMenuSimulator), simSub, "SIM_TOGGLE", null));
    }
}

class DataFieldSettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("SIM_TOGGLE")) {
            var enabled = Storage.getValue("sim_virtualNodeEnabled") == true;
            Storage.setValue("sim_virtualNodeEnabled", !enabled);
            var stateStr = I18n.get(!enabled ? Rez.Strings.SettingEnabled : Rez.Strings.SettingDisabled);
            WatchUi.showToast(I18n.format(Rez.Strings.DfSimulatorToggleToast, [ stateStr ]), null);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }
        if (id.equals("FIT_TOGGLE")) {
            var fitEnabled = Storage.getValue("fitLoggingEnabled") != false;
            Storage.setValue("fitLoggingEnabled", !fitEnabled);
            var fitState = I18n.get(!fitEnabled ? Rez.Strings.SettingActiveOn : Rez.Strings.SettingInactiveOff);
            item.setSubLabel(fitState);
            WatchUi.requestUpdate();
            return;
        }
        if (id.equals("TARGET_NONE")) {
            ContactManager.disableActivityTelemetryTarget();
            WatchUi.showToast(I18n.get(Rez.Strings.DfToastTxOff), null);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }
        if (id.find("CH_") == 0) {
            var chIdx = id.substring(3, id.length()).toNumber();
            ContactManager.selectActivityTelemetryChannel(chIdx, item.getLabel());
            TelemetryDispatcher.getInstance().triggerImmediateBeacon();
            WatchUi.showToast(I18n.format(Rez.Strings.TargetActiveToast, [ item.getLabel() ]), null);
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
