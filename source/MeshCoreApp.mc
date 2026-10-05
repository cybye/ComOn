import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.BluetoothLowEnergy;
import Toybox.Background;
import Toybox.Time;
import Toybox.Application.Storage;
import Toybox.System;
import Toybox.Sensor;

(:background)
class MeshCoreApp extends Application.AppBase {
    private var _bleManager as MeshBleManager? = null;
    private var _bleDelegate as MeshBleDelegate? = null;
    private var _launchAction as String? = null;
    private var _heartbeatTimer as SoftTimer? = null;

    (:background)
    function initialize() {
        AppBase.initialize();
    }

    (:background)
    function onStart(state as Dictionary?) as Void {
        if (state != null && state.hasKey(:launchedFromNotification)) {
            var action = state.get(:launchedFromNotification);
            if (action instanceof String) {
                _launchAction = action as String;
            }
        }
    }

    private function initForeground() as Void {
        Storage.setValue(StorageKeys.NOTIF_INCOMING_BATCH, I18n.get(Rez.Strings.NotifIncomingBatch));
        Storage.setValue(StorageKeys.NOTIF_INCOMING_MSG, I18n.get(Rez.Strings.NotifIncomingMsg));
        Storage.setValue(StorageKeys.NOTIF_OPEN_CHAT, I18n.get(Rez.Strings.NotifActionOpenChat));
        Storage.setValue(StorageKeys.NOTIF_OPEN_CHATS, I18n.get(Rez.Strings.NotifActionOpenChats));
        Storage.setValue(StorageKeys.NOTIF_REPLY, I18n.get(Rez.Strings.NotifActionReply));
        Storage.setValue(StorageKeys.NOTIF_POSITION, I18n.get(Rez.Strings.NotifActionPosition));
        Storage.setValue(StorageKeys.NOTIF_OK, I18n.get(Rez.Strings.NotifActionOk));
        ContactManager.loadFromStorage();
        ContactManager.ensureBackgroundIdentityCaches();
        ChatHistoryManager.reloadFromStorage();
        // Register notification handler before BLE setup so that action buttons
        // are never stripped from notifications that arrive during early connect
        // (i.e. before ChatsListView.onShow() has had a chance to call register()).
        MeshNotificationManager.getInstance().register();
        if (_bleManager == null) {
            _bleManager = new MeshBleManager();
            _bleDelegate = new MeshBleDelegate(_bleManager as MeshBleManager);
        }
        if (_bleDelegate != null && _bleManager != null) {
            BluetoothLowEnergy.setDelegate(_bleDelegate as MeshBleDelegate);
            (_bleManager as MeshBleManager).registerProfile();
            (_bleManager as MeshBleManager).connectLatestOrScan();
            (_bleManager as MeshBleManager).onMessageCallback = method(:onAppMessageReceived);
            (_bleManager as MeshBleManager).positionProvider = method(:getFormattedPosition);
            (_bleManager as MeshBleManager).sosProvider = method(:getFormattedSos);
            MeshCoreEngine.getInstance().setOnMessageListener(method(:onAppMessageReceived));
        }
        TelemetryProvider.getInstance().startTracking();
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
        if (_heartbeatTimer != null) {
            _heartbeatTimer.stop();
            _heartbeatTimer = null;
        }
        Storage.deleteValue(StorageKeys.FOREGROUND_ACTIVE);
        Storage.deleteValue(StorageKeys.FOREGROUND_ACTIVE_AT);
        if (!(Toybox has :WatchUi) || _bleManager == null) {
            return;
        }

        TelemetryProvider.getInstance().stopTracking();
        (_bleManager as MeshBleManager).releaseNode(0, false);

        // Schedule background message check according to configured interval
        var intervalSecs = Storage.getValue(StorageKeys.BG_INTERVAL);
        if (intervalSecs == null) {
            intervalSecs = 300; // Default: 5 min
        }
        // Fresh start for the unreachable-node backoff after a foreground session
        Storage.deleteValue(StorageKeys.BG_FAIL_STREAK);

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
        System.println("MeshCoreApp: creating background service delegate");
        return [ new MeshBackgroundDelegate() ];
    }

    (:background)
    public function onBackgroundData(data as Application.PropertyValueType) as Void {
        System.println("MeshCoreApp: onBackgroundData callback: " + data);
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        Storage.setValue(StorageKeys.FOREGROUND_ACTIVE, true);
        onForegroundHeartbeat();
        if (_heartbeatTimer == null) {
            _heartbeatTimer = new SoftTimer();
            _heartbeatTimer.start(method(:onForegroundHeartbeat), 60000, true);
        }
        initForeground();
        if (_launchAction != null) {
            // Handled from ChatsListView.onShow once the view stack exists
            MeshNotificationManager.getInstance().setPendingLaunchAction(_launchAction as String);
            _launchAction = null;
        }
        var view = new ChatsListView();
        var engine = MeshCoreEngine.getInstance();
        engine.setOnChannelsChangedListener(view.method(:markDirty));
        engine.setOnContactsChangedListener(view.method(:markDirty));
        engine.setOnStatusChangedListener(view.method(:onEngineStatusChanged));
        return [ view, new ChatsListDelegate(view) ];
    }

    public function onForegroundHeartbeat() as Void {
        Storage.setValue(StorageKeys.FOREGROUND_ACTIVE_AT, Time.now().value());
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
