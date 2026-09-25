import Toybox.WatchUi;
import Toybox.Lang;

class CannedMessageMenu {
    public static function create() as WatchUi.Menu2 {
        return createForTarget(null, null);
    }

    public static function createForTarget(targetId as String?, targetName as String?) as WatchUi.Menu2 {
        var target = (targetName != null) ? targetName : ContactManager.getTargetDisplayName();
        var menuTitle = I18n.get(Rez.Strings.ReplyTitle);
        if (target != null && target.length() > 0) {
            menuTitle = menuTitle + " (" + target + ")";
        }
        var menu = new WatchUi.Menu2({ :title => menuTitle });

        // Position at the very top of message list
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuCustomMsg), I18n.get(Rez.Strings.MenuCustomMsgSub), "MSG_CUSTOM", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuSendPosition), I18n.get(Rez.Strings.MenuSendPositionSub), "MSG_POS", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedOk), I18n.get(Rez.Strings.CannedOkSub), "MSG_OK", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedAtTarget), I18n.get(Rez.Strings.CannedOkSub), "MSG_DEST", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedDelay15), I18n.get(Rez.Strings.CannedDelay15Sub), "MSG_DEL15", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedDelay30), I18n.get(Rez.Strings.CannedDelay30Sub), "MSG_DEL30", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedNeedHelp), I18n.get(Rez.Strings.CannedNeedHelpSub), "MSG_HELP", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedRadioCheck), I18n.get(Rez.Strings.CannedRadioCheckSub), "MSG_TEST", null));

        return menu;
    }
}

class CannedMessageDelegate extends WatchUi.Menu2InputDelegate {
    private var _targetId as String?;

    function initialize(targetId as String?) {
        Menu2InputDelegate.initialize();
        _targetId = targetId;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("MSG_CUSTOM")) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            KeyboardHelper.openKeyboardForTarget("", _targetId);
            return;
        }
        var text = item.getLabel();
        var sent = false;
        if (id.equals("MSG_POS")) {
            sent = (_targetId != null) ? getBleManager().sendCurrentPositionToConversation(_targetId as String) : getBleManager().sendCurrentPosition(ContactManager.selectedChannelIdx);
            text = I18n.get(Rez.Strings.ToastPosition);
        } else {
            sent = (_targetId != null) ? getBleManager().sendTextToConversation(_targetId as String, text) : getBleManager().sendChannelText(ContactManager.selectedChannelIdx, text);
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        if (!sent) {
            WatchUi.showToast(I18n.get(Rez.Strings.ToastNotConnected), null);
        }
    }

    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class CustomTextPickerDelegate extends WatchUi.TextPickerDelegate {
    private var _targetId as String?;

    function initialize(targetId as String?) {
        TextPickerDelegate.initialize();
        _targetId = targetId;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        if (text != null && text.length() > 0) {
            var bleMgr = getBleManager();
            var ok = (_targetId != null) ? bleMgr.sendTextToConversation(_targetId as String, text) : bleMgr.sendChannelText(ContactManager.selectedChannelIdx, text);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            if (!ok) {
                WatchUi.showToast(I18n.get(Rez.Strings.ToastNotConnected), null);
            }
        }
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

