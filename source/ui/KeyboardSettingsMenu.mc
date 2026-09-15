import Toybox.WatchUi;
import Toybox.Lang;

class KeyboardSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Tastatur-Typ" });

        var currentMode = KeyboardHelper.getKeyboardMode();

        addItem(new WatchUi.MenuItem(
            "QWERTY (Touch)", 
            (currentMode == KeyboardHelper.MODE_QWERTY) ? "Aktiv (Englisch)" : "Englisch", 
            "SET_KEY_QWERTY", 
            null
        ));
        addItem(new WatchUi.MenuItem(
            "QWERTZ (Touch)", 
            (currentMode == KeyboardHelper.MODE_QWERTZ) ? "Aktiv (Deutsch)" : "Deutsch", 
            "SET_KEY_QWERTZ", 
            null
        ));
        addItem(new WatchUi.MenuItem(
            "Nativ (Garmin)", 
            (currentMode == KeyboardHelper.MODE_NATIVE) ? "Aktiv (Scrollrad)" : "Scrollrad", 
            "SET_KEY_NATIVE", 
            null
        ));
    }
}

class KeyboardSettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var mode = KeyboardHelper.MODE_QWERTY;

        if (id.equals("SET_KEY_QWERTZ")) {
            mode = KeyboardHelper.MODE_QWERTZ;
        } else if (id.equals("SET_KEY_NATIVE")) {
            mode = KeyboardHelper.MODE_NATIVE;
        }

        KeyboardHelper.setKeyboardMode(mode);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.showToast("Tastatur: " + KeyboardHelper.getModeName(mode), null);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
