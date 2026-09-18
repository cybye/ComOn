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
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        } else if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            // Hardware START / ENTER button opens canned reply menu as requested
            System.println("ChatThread: Hardware START button pressed -> opening CannedMessageMenu");
            WatchUi.pushView(new CannedMessageMenu(), new CannedMessageDelegate(), WatchUi.SLIDE_LEFT);
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

        // Bottom green [Reply / Antworten] touch button bounds
        // Button is drawn at y: 376..420, x: 122..332 on 454x454 screen.
        // Generous bounds ensure reliable hit detection for any tap in the button area.
        if (ty >= 355 && tx >= 60 && tx <= 394) {
            System.println("ChatThread: Green Reply button clicked -> opening keyboard directly");
            KeyboardHelper.openKeyboard("");
            return true;
        }

        // Tap in upper/middle area: if tapped top half, scroll up; bottom half, scroll down
        if (ty >= 20 && ty < 195) {
            _view.scrollUp();
            return true;
        } else if (ty >= 195 && ty < 355) {
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
