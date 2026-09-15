import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.BluetoothLowEnergy;

class MeshCoreApp extends Application.AppBase {
    private var _bleManager as MeshBleManager;
    private var _bleDelegate as MeshBleDelegate;

    function initialize() {
        AppBase.initialize();
        _bleManager = new MeshBleManager();
        _bleDelegate = new MeshBleDelegate(_bleManager);
    }

    function onStart(state as Dictionary?) as Void {
        BluetoothLowEnergy.setDelegate(_bleDelegate);
        _bleManager.registerProfile();
        _bleManager.startScan();
        TelemetryProvider.getInstance().startTracking();
        MeshNotificationManager.getInstance().register();
    }

    function onStop(state as Dictionary?) as Void {
        TelemetryProvider.getInstance().stopTracking();
        _bleManager.stopScan();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new DashboardView();
        return [ view, new DashboardDelegate(view) ];
    }

    public function getBleManager() as MeshBleManager {
        return _bleManager;
    }
}

function getApp() as MeshCoreApp {
    return Application.getApp() as MeshCoreApp;
}

function getBleManager() as MeshBleManager {
    return (Application.getApp() as MeshCoreApp).getBleManager();
}
