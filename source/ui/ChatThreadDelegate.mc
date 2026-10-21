import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class ChatThreadDelegate extends WatchUi.BehaviorDelegate {
    private var _view as ChatThreadView;
    private var _replyMenuPending as Boolean = false;
    private var _replyMenuRequestedAt as Number = 0;
    private var _backPending as Boolean = false;
    private var _backRequestedAt as Number = 0;

    function initialize(view as ChatThreadView) {
        BehaviorDelegate.initialize();
        _view = view;
        _view.onReturnToChat = method(:onReturnToChat);
    }

    public function onReturnToChat() as Void {
        _replyMenuPending = false;
        _backPending = false;
    }

    function onSelect() as Boolean {
        openReplyMenu("select_button");
        return true;
    }

    function onBack() as Boolean {
        popChatView();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollUp();
        return true;
    }

    function onNextPage() as Boolean {
        _view.scrollDown();
        return true;
    }

    private function openReplyMenu(source as String) as Void {
        var now = System.getTimer();
        if (_replyMenuPending && (now - _replyMenuRequestedAt) < 1000) {
            return;
        }
        _replyMenuPending = true;
        _replyMenuRequestedAt = now;
        System.println("ChatThread: opening CannedMessageMenu from " + source);
        WatchUi.pushView(CannedMessageMenu.createForTarget(_view.targetId, _view.targetName), new CannedMessageDelegate(_view.targetId), WatchUi.SLIDE_IMMEDIATE);
    }

    private function popChatView() as Void {
        var now = System.getTimer();
        if (_backPending && (now - _backRequestedAt) < 1500) {
            return;
        }
        _backPending = true;
        _backRequestedAt = now;
        System.println("ChatThread: Back -> popView");
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        System.println("ChatThreadDelegate: onKey key=" + key);
        if (key == WatchUi.KEY_ESC) {
            popChatView();
            return true;
        } else if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            openReplyMenu("key");
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
        if (ty <= _view.getHeaderTapLimit()) {
            System.println("ChatThread: Header tapped -> opening NodeSettingsMenu");
            getBleManager().suspendDiscoveryForUi();
            WatchUi.pushView(new NodeSettingsMenu(), new SettingsDelegate(), WatchUi.SLIDE_UP);
            return true;
        }

        // Bottom [Message / Nachricht] pill button bounds -> opens standard replies menu
        if (_view.isPillTapped(tx, ty)) {
            openReplyMenu("tap");
            return true;
        }

        // Tap in upper/middle area: if tapped top half, scroll up; bottom half, scroll down
        var headerLim = _view.getHeaderTapLimit();
        var halfY = DisplayProfile.screenH / 2;
        if (ty > headerLim && ty < halfY) {
            _view.scrollUp();
            return true;
        } else if (ty >= halfY) {
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
            popChatView();
            return true;
        }
        return false;
    }
}
