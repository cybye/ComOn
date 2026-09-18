import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.BluetoothLowEnergy;
import Toybox.Application.Storage;

class MeshCoreDataFieldApp extends Application.AppBase {
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
        
        // Auto-connect to virtual node if enabled in test mode
        var simEnabled = Storage.getValue("sim_virtualNodeEnabled");
        if (simEnabled == null || simEnabled == true) {
            _bleManager.simulateConnect("Virtual-Node");
        } else {
            _bleManager.startScan();
        }
    }

    function onStop(state as Dictionary?) as Void {
        _bleManager.stopScan();
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

//! On-Device Settings Menu for Data Field: Channel and Contact Selection
class DataFieldSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => I18n.get(Rez.Strings.DataFieldMenuTitle) });

        var activeBadge = I18n.get(Rez.Strings.ActiveBadge);

        // Channels from unified ContactManager
        var channels = ContactManager.getChannels();
        for (var i = 0; i < channels.size(); i++) {
            var ch = channels[i];
            var label = ch[:name] as String;
            var isSel = (!ContactManager.isContactTarget && ContactManager.selectedChannelIdx == (ch[:idx] as Number));
            addItem(new WatchUi.MenuItem(label, isSel ? activeBadge : null, "CH_" + ch[:idx], null));
        }

        // Dynamic mesh contacts
        var contacts = ContactManager.getContacts();
        for (var j = 0; j < contacts.size(); j++) {
            var c = contacts[j];
            var cId = c[:id] as String;
            var cName = c[:name] as String;
            var isSel = (ContactManager.isContactTarget && ContactManager.selectedContactId != null && ContactManager.selectedContactId.equals(cId));
            addItem(new WatchUi.MenuItem(cName, isSel ? activeBadge : null, "CT_" + cId, null));
        }
    }
}

class DataFieldSettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.find("CH_") == 0) {
            var chIdx = id.substring(3, id.length()).toNumber();
            ContactManager.selectChannel(chIdx, item.getLabel());
            WatchUi.showToast(I18n.format(Rez.Strings.TargetActiveToast, [ item.getLabel() ]), null);
        } else if (id.find("CT_") == 0) {
            var cId = id.substring(3, id.length());
            ContactManager.selectContact(cId, item.getLabel());
            WatchUi.showToast(I18n.format(Rez.Strings.TargetActiveToast, [ item.getLabel() ]), null);
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
