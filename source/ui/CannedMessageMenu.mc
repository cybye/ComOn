import Toybox.WatchUi;
import Toybox.Lang;

class CannedMessageMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Antworten" });

        // Position at the very top of message list
        addItem(new WatchUi.MenuItem("Freitext schreiben...", "Tastatur", "MSG_CUSTOM", null));
        addItem(new WatchUi.MenuItem("Position senden", "GPS + Vitaldaten", "MSG_POS", null));
        addItem(new WatchUi.MenuItem("Alles OK", "Status", "MSG_OK", null));
        addItem(new WatchUi.MenuItem("Am Treffpunkt", "Status", "MSG_DEST", null));
        addItem(new WatchUi.MenuItem("Verzögerung 15 min", "Zeit", "MSG_DEL15", null));
        addItem(new WatchUi.MenuItem("Verzögerung 30 min", "Zeit", "MSG_DEL30", null));
        addItem(new WatchUi.MenuItem("Brauche Hilfe", "Dringend", "MSG_HELP", null));
        addItem(new WatchUi.MenuItem("Funktest", "Test", "MSG_TEST", null));
    }
}

class CustomTextPickerDelegate extends WatchUi.TextPickerDelegate {
    function initialize() {
        TextPickerDelegate.initialize();
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        if (text != null && text.length() > 0) {
            var bleMgr = getBleManager();
            var chIdx = ContactManager.selectedChannelIdx;
            var ok = bleMgr.sendChannelText(chIdx, text);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast(ok ? "Gesendet: " + text : "Nicht verbunden", null);
        }
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

class CannedMessageDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var bleMgr = getBleManager();
        var chIdx = ContactManager.selectedChannelIdx;

        if (id.equals("MSG_CUSTOM")) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            KeyboardHelper.openKeyboard("");
            return;
        }

        var textToSend = item.getLabel();
        var ok = false;

        if (id.equals("MSG_POS")) {
            ok = bleMgr.sendCurrentPosition(chIdx);
            textToSend = "Position";
        } else {
            ok = bleMgr.sendChannelText(chIdx, textToSend);
        }

        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.showToast(ok ? textToSend + " gesendet" : "Nicht verbunden", null);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

