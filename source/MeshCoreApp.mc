import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.BluetoothLowEnergy;
import Toybox.Background;
import Toybox.Time;
import Toybox.Application.Storage;
import Toybox.System;

class MeshCoreApp extends Application.AppBase {
    private var _bleManager as MeshBleManager? = null;
    private var _bleDelegate as MeshBleDelegate? = null;

    (:background)
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    private function initForeground() as Void {
        if (_bleManager == null) {
            _bleManager = new MeshBleManager();
            _bleDelegate = new MeshBleDelegate(_bleManager as MeshBleManager);
        }
        if (_bleDelegate != null && _bleManager != null) {
            BluetoothLowEnergy.setDelegate(_bleDelegate as MeshBleDelegate);
            (_bleManager as MeshBleManager).registerProfile();
            (_bleManager as MeshBleManager).startScan();
            (_bleManager as MeshBleManager).onMessageCallback = method(:onAppMessageReceived);
            (_bleManager as MeshBleManager).positionProvider = method(:getFormattedPosition);
            (_bleManager as MeshBleManager).sosProvider = method(:getFormattedSos);
        }
        TelemetryProvider.getInstance().startTracking();
        MeshNotificationManager.getInstance().register();
    }

    public function getFormattedPosition() as String {
        return TelemetryProvider.getInstance().getFormattedPosition();
    }

    public function getFormattedSos() as String {
        return TelemetryProvider.getInstance().getFormattedSos();
    }

    public function onAppMessageReceived(sender as String, text as String, tid as String) as Void {
        MeshNotificationManager.getInstance().showIncomingMessage(sender, text, tid);
    }

    function onStop(state as Dictionary?) as Void {
        if (!(Toybox has :WatchUi) || _bleManager == null) {
            return;
        }

        TelemetryProvider.getInstance().stopTracking();
        (_bleManager as MeshBleManager).stopScan();

        // Schedule background message check according to configured interval
        var intervalSecs = Storage.getValue("bgInterval");
        if (intervalSecs == null) {
            intervalSecs = 300; // Default: 5 min
        }

        if ((intervalSecs as Number) > 0) {
            try {
                Background.registerForTemporalEvent(new Time.Duration(intervalSecs as Number));
                System.println("MeshCoreApp: registered temporal event for " + intervalSecs + "s");
            } catch (e) {
                System.println("MeshCoreApp: registerForTemporalEvent error: " + e.getErrorMessage());
            }
        } else {
            try {
                Background.deleteTemporalEvent();
                System.println("MeshCoreApp: background checks disabled");
            } catch (e) {
                // ignore
            }
        }
    }

    (:background)
    public function getServiceDelegate() as [ System.ServiceDelegate ] {
        return [ new MeshBackgroundDelegate() ];
    }

    (:background)
    public function onBackgroundData(data as Application.PropertyValueType) as Void {
        System.println("MeshCoreApp: onBackgroundData callback: " + data);
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        initForeground();
        var view = new DashboardView();
        return [ view, new DashboardDelegate(view) ];
    }

    public function getBleManager() as MeshBleManager {
        return _bleManager as MeshBleManager;
    }
}

function getApp() as MeshCoreApp {
    return Application.getApp() as MeshCoreApp;
}

function getBleManager() as MeshBleManager {
    return (Application.getApp() as MeshCoreApp).getBleManager();
}
