import Toybox.WatchUi;
import Toybox.Lang;

class ChatsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Chats" });

        // 1. Group Channels
        var channels = ContactManager.getChannels();
        for (var i = 0; i < channels.size(); i++) {
            var ch = channels[i];
            var idx = ch[:idx] as Number;
            var name = ch[:name] as String;
            var tid = "CH_" + idx;

            var isActive = (!ContactManager.isContactTarget && ContactManager.selectedChannelIdx == idx);
            var lastMsg = ChatHistoryManager.getLastMessageForTarget(tid);

            var sub = "";
            if (lastMsg != null) {
                var prefix = isActive ? "✔ " : "";
                var s = lastMsg[:sender] as String;
                var txt = lastMsg[:text] as String;
                sub = prefix + s + ": " + txt;
            } else {
                sub = isActive ? "✔ Aktiv (Kanal)" : "Kanal";
            }

            addItem(new WatchUi.MenuItem(name, sub, tid, null));
        }

        // 2. Direct Contacts (1:1 DMs)
        var contacts = ContactManager.getContacts();
        for (var j = 0; j < contacts.size(); j++) {
            var c = contacts[j];
            var cid = c[:id] as String;
            var cname = c[:name] as String;
            var tid = "CT_" + cid;

            var isActive = (ContactManager.isContactTarget && ContactManager.selectedContactId != null && ContactManager.selectedContactId.equals(cid));
            var lastMsg = ChatHistoryManager.getLastMessageForTarget(tid);

            var sub = "";
            if (lastMsg != null) {
                var prefix = isActive ? "✔ " : "";
                var s = lastMsg[:sender] as String;
                var txt = lastMsg[:text] as String;
                sub = prefix + s + ": " + txt;
            } else {
                sub = isActive ? "✔ Aktiv (1:1)" : "1:1 Kontakt";
            }

            addItem(new WatchUi.MenuItem(cname, sub, tid, null));
        }
    }
}

class ChatsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var label = item.getLabel();

        if (id.find("CH_") == 0) {
            var chIdx = id.substring(3, id.length()).toNumber();
            ContactManager.selectChannel(chIdx, label);
        } else if (id.find("CT_") == 0) {
            var ctId = id.substring(3, id.length());
            ContactManager.selectContact(ctId, label);
        }

        // Open Chat-Thread for this channel / contact
        WatchUi.pushView(new ChatThreadMenu(id, label), new ChatThreadDelegate(id, label), WatchUi.SLIDE_LEFT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
