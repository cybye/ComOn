import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class ChatThreadDelegate extends WatchUi.InputDelegate {
    private var _view as ChatThreadView;

    function initialize(view as ChatThreadView) {
        InputDelegate.initialize();
        _view = view;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        System.println("ChatThreadDelegate: onKey key=" + key);
        if (key == WatchUi.KEY_ESC) {
            System.println("ChatThreadDelegate: ESC pressed -> popView");
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        } else if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            // Hardware START / ENTER button opens canned reply menu as requested
            System.println("ChatThread: Hardware START button pressed -> opening CannedMessageMenu");
            WatchUi.pushView(CannedMessageMenu.createForTarget(_view.targetId, _view.targetName), new CannedMessageDelegate(_view.targetId), WatchUi.SLIDE_LEFT);
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            _view.scrollDown();
            return true;
        } else if (key == WatchUi.KEY_UP) {
            _view.scrollUp();
            return true;
        }
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var tx = coords[0];
        var ty = coords[1];
        System.println("ChatThread: onTap at [" + tx + ", " + ty + "]");

        // Top header tap -> Open Node Settings
        if (ty <= 60) {
            System.println("ChatThread: Header tapped -> opening NodeSettingsMenu");
            getBleManager().suspendDiscoveryForUi();
            WatchUi.pushView(new NodeSettingsMenu(), new SettingsDelegate(), WatchUi.SLIDE_UP);
            return true;
        }

        // Bottom [Message / Nachricht] pill button bounds
        if (ty >= 365 && tx >= 60 && tx <= 394) {
            System.println("ChatThread: Message pill button clicked -> opening keyboard");
            KeyboardHelper.openKeyboardForTarget("", _view.targetId);
            return true;
        }

        // Tap in upper/middle area: if tapped top half, scroll up; bottom half, scroll down
        if (ty > 60 && ty < 215) {
            _view.scrollUp();
            return true;
        } else if (ty >= 215 && ty < 365) {
            _view.scrollDown();
            return true;
        }
        return false;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            _view.scrollDown();
            return true;
        } else if (dir == WatchUi.SWIPE_DOWN) {
            _view.scrollUp();
            return true;
        } else if (dir == WatchUi.SWIPE_RIGHT) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }
}
