import Toybox.WatchUi;
import Toybox.Lang;

class ChatThreadMenu extends WatchUi.Menu2 {
    private var _targetId as String;
    private var _targetName as String;

    function initialize(targetId as String, targetName as String) {
        Menu2.initialize({ :title => targetName });
        _targetId = targetId;
        _targetName = targetName;

        // Quick Actions at top of thread
        addItem(new WatchUi.MenuItem("Antworten", "Tastatur öffnen", "ACT_REPLY", null));
        addItem(new WatchUi.MenuItem("Schnellantwort", "Aus Liste wählen", "ACT_CANNED", null));
        addItem(new WatchUi.MenuItem("Standort senden", "GPS übertragen", "ACT_POS", null));

        // Thread Message History
        var msgs = ChatHistoryManager.getMessagesForTarget(targetId);
        if (msgs.size() == 0) {
            addItem(new WatchUi.MenuItem("Keine Nachrichten", "Noch kein Funkverkehr", "MSG_NONE", null));
        } else {
            // Show from newest to oldest
            for (var i = msgs.size() - 1; i >= 0; i--) {
                var m = msgs[i];
                var sender = m[:sender] as String;
                var text = m[:text] as String;
                var isOut = m[:isOutgoing] as Boolean;
                var time = m[:time] as Number;
                var timeStr = ChatHistoryManager.formatTimeAgo(time);

                var author = isOut ? "Ich (" + timeStr + ")" : sender + " (" + timeStr + ")";
                addItem(new WatchUi.MenuItem(author, text, "MSG_ITEM_" + i, null));
            }
        }
    }
}

class ChatThreadDelegate extends WatchUi.Menu2InputDelegate {
    private var _targetId as String;
    private var _targetName as String;

    function initialize(targetId as String, targetName as String) {
        Menu2InputDelegate.initialize();
        _targetId = targetId;
        _targetName = targetName;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var bleMgr = getBleManager();
        var chIdx = ContactManager.selectedChannelIdx;

        if (id.equals("ACT_REPLY")) {
            KeyboardHelper.openKeyboard("");
        } else if (id.equals("ACT_CANNED")) {
            WatchUi.pushView(new CannedMessageMenu(), new CannedMessageDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("ACT_POS")) {
            var ok = bleMgr.sendCurrentPosition(chIdx);
            WatchUi.showToast(ok ? "Standort gesendet" : "Nicht verbunden", null);
        } else if (id.find("MSG_ITEM_") == 0) {
            // Show full message in Toast or open Action Menu
            WatchUi.showToast(item.getSubLabel(), null);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
