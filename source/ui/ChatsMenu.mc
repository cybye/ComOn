import Toybox.WatchUi;
import Toybox.Lang;

class ChatsMenu {
    public static function create() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({ :title => I18n.get(Rez.Strings.ChatsTitle) });

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

        // 2. Direct Contacts (only active chats with history or active selection)
        var contacts = ContactManager.getClientContacts();
        for (var j = 0; j < contacts.size(); j++) {
            var c = contacts[j];
            var cid = c[:id] as String;
            var cname = c[:name] as String;
            var tid = "CT_" + cid;

            var isActive = (ContactManager.isContactTarget && ContactManager.selectedContactId != null && ContactManager.selectedContactId.equals(cid));
            var hasMsgs = ChatHistoryManager.hasMessagesForTarget(tid);

            // Only instantiate menu items for contacts with active conversations
            if (!isActive && !hasMsgs) {
                continue;
            }

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

        // Add action item to select from all client contacts if desired
        var clientCount = ContactManager.getClientContactsCount();
        if (clientCount > 0) {
            var subText = I18n.format(Rez.Strings.ActionNewChatSub, [ clientCount ]);
            otherItems.add(new WatchUi.MenuItem(I18n.get(Rez.Strings.ActionNewChat), subText, "OPEN_CONTACTS_PICKER", null));
        }

        // Active chat is placed first at the top
        if (activeItem != null) {
            menu.addItem(activeItem);
        }
        for (var k = 0; k < otherItems.size(); k++) {
            menu.addItem(otherItems[k]);
        }
        if (activeItem == null && otherItems.size() == 0) {
            menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.NoChats), null, "NO_CHATS", null));
        }

        return menu;
    }
}

class ChatsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var label = item.getLabel();
        if (id.equals("NO_CHATS")) {
            return;
        } else if (id.equals("OPEN_CONTACTS_PICKER")) {
            WatchUi.pushView(TargetSelectMenu.create(), new TargetSelectDelegate(), WatchUi.SLIDE_LEFT);
            return;
        } else if (id.find("CH_") == 0) {
            ContactManager.selectChannel(id.substring(3, id.length()).toNumber(), label);
        } else if (id.find("CT_") == 0) {
            ContactManager.selectContact(id.substring(3, id.length()), label);
        }
        var view = new ChatThreadView(id, label);
        WatchUi.pushView(view, new ChatThreadDelegate(view), WatchUi.SLIDE_LEFT);
    }

    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
