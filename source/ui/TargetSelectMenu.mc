import Toybox.WatchUi;
import Toybox.Lang;

class TargetSelectMenu {
    public static function create() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({ :title => I18n.get(Rez.Strings.TargetSelectTitle) });

        var activeBadge = I18n.get(Rez.Strings.ActiveBadge);

        // Channels
        var channels = ContactManager.getChannels();
        for (var i = 0; i < channels.size(); i++) {
            var ch = channels[i];
            var isSel = (!ContactManager.isContactTarget && ContactManager.selectedChannelIdx == (ch[:idx] as Number));
            menu.addItem(new WatchUi.MenuItem(ch[:name] as String, isSel ? activeBadge : null, "CH_" + ch[:idx], null));
        }

        // Contacts (Client nodes only, max 40 to avoid Menu2 watchdog timeout)
        var contacts = ContactManager.getClientContacts();
        var maxCt = 40;
        var totalCt = contacts.size();
        var countToShow = (totalCt > maxCt) ? maxCt : totalCt;
        for (var j = 0; j < countToShow; j++) {
            var c = contacts[j];
            var isSel = (ContactManager.isContactTarget && ContactManager.selectedContactId != null && ContactManager.selectedContactId.equals(c[:id]));
            menu.addItem(new WatchUi.MenuItem(c[:name] as String, isSel ? activeBadge : null, "CT_" + c[:id], null));
        }

        if (totalCt > maxCt) {
            var moreText = I18n.format(Rez.Strings.MoreContacts, [ (totalCt - maxCt) ]);
            menu.addItem(new WatchUi.MenuItem(moreText, null, "MORE_INFO", null));
        }

        return menu;
    }
}

class TargetSelectDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var label = item.getLabel();

        if (id.equals("MORE_INFO")) {
            return;
        }

        if (id.find("CH_") == 0) {
            var chIdx = id.substring(3, id.length()).toNumber();
            ContactManager.selectChannel(chIdx, label);
        } else if (id.find("CT_") == 0) {
            var ctId = id.substring(3, id.length());
            ContactManager.selectContact(ctId, label);
        }

        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.showToast(I18n.format(Rez.Strings.TargetSelectedToast, [ label ]), null);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
