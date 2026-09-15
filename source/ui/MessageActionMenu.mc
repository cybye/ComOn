import Toybox.WatchUi;
import Toybox.Lang;

class MessageActionMenu extends WatchUi.Menu2 {
    function initialize(sender as String) {
        Menu2.initialize({ :title => sender });

        addItem(new WatchUi.MenuItem("Antworten (Tastatur)", "Freitext schreiben", "ACT_REPLY_KEY", null));
        addItem(new WatchUi.MenuItem("Schnellantwort", "Aus Liste waehlen", "ACT_REPLY_CANNED", null));
        addItem(new WatchUi.MenuItem("Standort senden", "GPS zuruecksenden", "ACT_REPLY_POS", null));

        if (!sender.equals("Mesh") && !sender.equals("Node (Echo)")) {
            addItem(new WatchUi.MenuItem("1:1 Direktnachricht", "Ziel auf " + sender + " setzen", "ACT_SWITCH_DM", null));
        }
    }
}

class MessageActionDelegate extends WatchUi.Menu2InputDelegate {
    private var _sender as String;

    function initialize(sender as String) {
        Menu2InputDelegate.initialize();
        _sender = sender;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var bleMgr = getBleManager();
        var chIdx = ContactManager.selectedChannelIdx;

        if (id.equals("ACT_REPLY_KEY")) {
            if (!_sender.equals("Mesh") && !_sender.equals("Node (Echo)")) {
                ContactManager.selectContact(_sender, _sender);
            }
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            KeyboardHelper.openKeyboard("");
        } else if (id.equals("ACT_REPLY_CANNED")) {
            WatchUi.pushView(new CannedMessageMenu(), new CannedMessageDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("ACT_REPLY_POS")) {
            var ok = bleMgr.sendCurrentPosition(chIdx);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast(ok ? "Standort gesendet" : "Nicht verbunden", null);
        } else if (id.equals("ACT_SWITCH_DM")) {
            ContactManager.selectContact(_sender, _sender);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast("Ziel: " + _sender, null);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
