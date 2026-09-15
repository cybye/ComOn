import Toybox.WatchUi;
import Toybox.Lang;

class TargetSelectMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Ziel wählen" });

        // Channels
        var channels = ContactManager.getChannels();
        for (var i = 0; i < channels.size(); i++) {
            var ch = channels[i];
            addItem(new WatchUi.MenuItem(ch[:name] as String, "Kanal", "CH_" + ch[:idx], null));
        }

        // Contacts
        var contacts = ContactManager.getContacts();
        for (var j = 0; j < contacts.size(); j++) {
            var c = contacts[j];
            addItem(new WatchUi.MenuItem(c[:name] as String, "Kontakt", "CT_" + c[:id], null));
        }
    }
}

class TargetSelectDelegate extends WatchUi.Menu2InputDelegate {
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

        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.showToast("Ziel: " + label, null);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
