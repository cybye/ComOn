import Toybox.WatchUi;
import Toybox.Lang;

class SettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Einstellungen" });

        var currentKeyMode = KeyboardHelper.getModeName(KeyboardHelper.getKeyboardMode());
        addItem(new WatchUi.MenuItem("Tastatur-Typ", currentKeyMode, "SET_KEYBOARD", null));
        addItem(new WatchUi.MenuItem("Node koppeln", "Bluetooth Suche", "SET_PAIR", null));
        addItem(new WatchUi.MenuItem("Node-Simulator", "Test-Bench", "SET_SIM", null));
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
        } else if (id.equals("SET_PAIR")) {
            bleMgr.startScan();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast("Suche Node...", null);
        } else if (id.equals("SET_SIM")) {
            WatchUi.pushView(new NodeSimulatorMenu(), new NodeSimulatorDelegate(), WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
