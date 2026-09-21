import Toybox.WatchUi;
import Toybox.Lang;

class MessageActionMenu {
    public static function create(sender as String) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({ :title => sender });

        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.ActionReplyKeyboard), I18n.get(Rez.Strings.ActionReplyKeyboardSub), "ACT_REPLY_KEY", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.ActionReplyCanned), I18n.get(Rez.Strings.ActionReplyCannedSub), "ACT_REPLY_CANNED", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.ActionSendLocation), I18n.get(Rez.Strings.ActionSendLocationSub), "ACT_REPLY_POS", null));

        if (!sender.equals("Mesh") && !sender.equals("Node (Echo)")) {
            menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.ActionDirectMsg), I18n.format(Rez.Strings.ActionDirectMsgSub, [ sender ]), "ACT_SWITCH_DM", null));
        }

        return menu;
    }
}

class MessageActionDelegate extends WatchUi.Menu2InputDelegate {
    private var _sender as String;

    function initialize(sender as String) {
        _sender = sender;
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("ACT_REPLY_KEY")) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            KeyboardHelper.openKeyboard("");
        } else if (id.equals("ACT_REPLY_CANNED")) {
            WatchUi.pushView(CannedMessageMenu.create(), new CannedMessageDelegate(null), WatchUi.SLIDE_LEFT);
        } else if (id.equals("ACT_REPLY_POS")) {
            var sent = getBleManager().sendCurrentPosition(ContactManager.selectedChannelIdx);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast(sent ? I18n.get(Rez.Strings.ToastPositionSent) : I18n.get(Rez.Strings.ToastNotConnected), null);
        } else if (id.equals("ACT_SWITCH_DM")) {
            ContactManager.selectContact(_sender, _sender);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
    }

    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
