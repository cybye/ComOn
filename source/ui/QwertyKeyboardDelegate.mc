import Toybox.WatchUi;
import Toybox.Attention;
import Toybox.Lang;

class QwertyKeyboardDelegate extends WatchUi.BehaviorDelegate {
    private var _view as QwertyKeyboardView;
    private var _targetId as String?;

    function initialize(view as QwertyKeyboardView, targetId as String?) {
        BehaviorDelegate.initialize();
        _view = view;
        _targetId = targetId;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            sendCurrentText();
            return true;
        } else if (key == WatchUi.KEY_ESC) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var tx = coords[0];
        var ty = coords[1];

        var keys = _view.keys;
        for (var i = 0; i < keys.size(); i++) {
            var k = keys[i];
            var kx = k[:x];
            var ky = k[:y];
            var kw = k[:w];
            var kh = k[:h];

            if (tx >= kx && tx <= (kx + kw) && ty >= ky && ty <= (ky + kh)) {
                // Haptic feedback on tap
                if (Attention has :vibrate) {
                    var vibe = [ new Attention.VibeProfile(40, 25) ];
                    Attention.vibrate(vibe);
                }

                var id = k[:id] as String;
                _view.activeKeyId = id;

                if (id.find("CHAR_") == 0) {
                    var val = k[:val] as String;
                    _view.currentText += val;
                    if (_view.isShift) {
                        _view.isShift = false;
                        _view.buildKeyLayout();
                    }
                } else if (id.equals("SPACE")) {
                    _view.currentText += " ";
                } else if (id.equals("BACKSPACE")) {
                    if (_view.currentText.length() > 0) {
                        _view.currentText = _view.currentText.substring(0, _view.currentText.length() - 1);
                    }
                } else if (id.equals("TOGGLE_SHIFT")) {
                    _view.isShift = !_view.isShift;
                    _view.buildKeyLayout();
                } else if (id.equals("TOGGLE_MODE")) {
                    _view.isSymbols = !_view.isSymbols;
                    _view.buildKeyLayout();
                } else if (id.equals("SEND")) {
                    sendCurrentText();
                    return true;
                }

                WatchUi.requestUpdate();
                return true;
            }
        }
        return false;
    }

    private function sendCurrentText() as Void {
        if (_view.currentText.length() > 0) {
            var bleMgr = getBleManager();
            var ok = (_targetId != null) ? bleMgr.sendTextToConversation(_targetId as String, _view.currentText) : bleMgr.sendChannelText(ContactManager.selectedChannelIdx, _view.currentText);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            if (!ok) {
                WatchUi.showToast(I18n.get(Rez.Strings.ToastNotConnected), null);
            }
        } else {
            WatchUi.showToast(I18n.get(Rez.Strings.NoMessages), null);
        }
    }
}
