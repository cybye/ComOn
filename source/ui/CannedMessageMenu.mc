import Toybox.WatchUi;
import Toybox.Lang;

class CannedMessageMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => I18n.get(Rez.Strings.ReplyTitle) });

        // Position at the very top of message list
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuCustomMsg), I18n.get(Rez.Strings.MenuCustomMsgSub), "MSG_CUSTOM", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuSendPosition), I18n.get(Rez.Strings.MenuSendPositionSub), "MSG_POS", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedOk), I18n.get(Rez.Strings.CannedOkSub), "MSG_OK", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedAtTarget), I18n.get(Rez.Strings.CannedOkSub), "MSG_DEST", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedDelay15), I18n.get(Rez.Strings.CannedDelay15Sub), "MSG_DEL15", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedDelay30), I18n.get(Rez.Strings.CannedDelay30Sub), "MSG_DEL30", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedNeedHelp), I18n.get(Rez.Strings.CannedNeedHelpSub), "MSG_HELP", null));
        addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.CannedRadioCheck), I18n.get(Rez.Strings.CannedRadioCheckSub), "MSG_TEST", null));
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
            WatchUi.showToast(ok ? I18n.format(Rez.Strings.ToastSent, [ text ]) : I18n.get(Rez.Strings.ToastNotConnected), null);
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
            textToSend = I18n.get(Rez.Strings.ToastPosition);
        } else {
            ok = bleMgr.sendChannelText(chIdx, textToSend);
        }

        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.showToast(ok ? I18n.format(Rez.Strings.ToastSent, [ textToSend ]) : I18n.get(Rez.Strings.ToastNotConnected), null);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

