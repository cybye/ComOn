import Toybox.WatchUi;
import Toybox.Lang;

class ChatsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => I18n.get(Rez.Strings.ChatsTitle) });

        var activeBadge = I18n.get(Rez.Strings.ActiveBadge);
        var activeItem = null;
        var otherItems = [] as Array<WatchUi.MenuItem>;

        // 1. Group Channels
        var channels = ContactManager.getChannels();
        for (var i = 0; i < channels.size(); i++) {
            var ch = channels[i];
            var idx = ch[:idx] as Number;
            var name = ch[:name] as String;
            var tid = "CH_" + idx;

            var isActive = (!ContactManager.isContactTarget && ContactManager.selectedChannelIdx == idx);
            var unread = ChatHistoryManager.getUnreadCountForTarget(tid);
            var lastMsg = ChatHistoryManager.getLastMessageForTarget(tid);

            var sub = "";
            if (unread > 0) {
                sub += I18n.format(Rez.Strings.NewBadge, [ unread ]) + " ";
            }
            if (isActive) {
                sub += activeBadge + " ";
            }

            if (lastMsg != null) {
                var s = lastMsg[:sender] as String;
                var txt = lastMsg[:text] as String;
                sub += s + ": " + txt;
            }

            var subVal = (sub.length() > 0) ? sub : null;
            var item = new WatchUi.MenuItem(name, subVal, tid, null);
            if (isActive) {
                activeItem = item;
            } else {
                otherItems.add(item);
            }
        }

        // 2. Direct Contacts (1:1 DMs)
        var contacts = ContactManager.getContacts();
        for (var j = 0; j < contacts.size(); j++) {
            var c = contacts[j];
            var cid = c[:id] as String;
            var cname = c[:name] as String;
            var tid = "CT_" + cid;

            var isActive = (ContactManager.isContactTarget && ContactManager.selectedContactId != null && ContactManager.selectedContactId.equals(cid));
            var unread = ChatHistoryManager.getUnreadCountForTarget(tid);
            var lastMsg = ChatHistoryManager.getLastMessageForTarget(tid);

            var sub = "";
            if (unread > 0) {
                sub += I18n.format(Rez.Strings.NewBadge, [ unread ]) + " ";
            }
            if (isActive) {
                sub += activeBadge + " ";
            }

            if (lastMsg != null) {
                var s = lastMsg[:sender] as String;
                var txt = lastMsg[:text] as String;
                sub += s + ": " + txt;
            }

            var subValCt = (sub.length() > 0) ? sub : null;
            var item = new WatchUi.MenuItem(cname, subValCt, tid, null);
            if (isActive) {
                activeItem = item;
            } else {
                otherItems.add(item);
            }
        }

        // Active chat is placed first at the top
        if (activeItem != null) {
            addItem(activeItem);
        }
        for (var k = 0; k < otherItems.size(); k++) {
            addItem(otherItems[k]);
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

        // Open graphical Chat-Thread View
        var view = new ChatThreadView(id, label);
        WatchUi.pushView(view, new ChatThreadDelegate(view), WatchUi.SLIDE_LEFT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
