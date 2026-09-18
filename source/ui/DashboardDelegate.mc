import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class DashboardDelegate extends WatchUi.BehaviorDelegate {
    private var _view as DashboardView;
    private var _lastBackTime as Number = 0;

    function initialize(view as DashboardView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    public function openActiveChatThread() as Void {
        var tid = ContactManager.isContactTarget ? ("CT_" + ContactManager.selectedContactId) : ("CH_" + ContactManager.selectedChannelIdx);
        var label = ContactManager.getTargetDisplayName();
        var view = new ChatThreadView(tid, label);
        WatchUi.pushView(view, new ChatThreadDelegate(view), WatchUi.SLIDE_LEFT);
    }

    //! 2 O'CLOCK BUTTON (START / SELECT)
    function onSelect() as Boolean {
        if (_view.pageIndex == 1) {
            // On Telemetry page: START sends position directly!
            sendPositionDirect();
        } else if (_view.pageIndex == 2) {
            // On SOS page: START launches SOS emergency view!
            var sos = new SosView();
            WatchUi.pushView(sos, new SosDelegate(sos), WatchUi.SLIDE_UP);
        } else {
            // On Chat page: START opens active chat thread directly!
            openActiveChatThread();
        }
        return true;
    }

    //! 4 O'CLOCK BUTTON (BACK / LAP)
    function onBack() as Boolean {
        if (_view.pageIndex == 2) {
            // On SOS page: Return to Telemetry
            _view.pageIndex = 1;
            WatchUi.requestUpdate();
            return true;
        } else if (_view.pageIndex == 1) {
            // On Telemetry page: Return to Chat
            _view.pageIndex = 0;
            WatchUi.requestUpdate();
            return true;
        }
        // On Chat page: Standard Garmin exit
        return false;
    }

    //! 7 O'CLOCK BUTTON (DOWN) / Swipe Up -> Go to Data / SOS page
    function onNextPage() as Boolean {
        if (_view.pageIndex == 0) {
            _view.pageIndex = 1;
            WatchUi.requestUpdate();
            return true;
        } else if (_view.pageIndex == 1) {
            _view.pageIndex = 2;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    //! 9 O'CLOCK BUTTON (UP) / Swipe Down -> Go to previous page
    function onPreviousPage() as Boolean {
        if (_view.pageIndex == 2) {
            _view.pageIndex = 1;
            WatchUi.requestUpdate();
            return true;
        } else if (_view.pageIndex == 1) {
            _view.pageIndex = 0;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    //! MENU BUTTON
    function onMenu() as Boolean {
        openMainMenu();
        return true;
    }

    //! Explicit key handler
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN) {
            return onNextPage();
        } else if (key == WatchUi.KEY_UP) {
            return onPreviousPage();
        } else if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            return onSelect();
        } else if (key == WatchUi.KEY_MENU) {
            return onMenu();
        }
        return false;
    }

    //! Touchscreen Tap handler
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (_view.pageIndex == 0) {
            var coords = clickEvent.getCoordinates();
            var tx = coords[0];
            var ty = coords[1];

            // 1. Target Badge tap at top (e.g. [#public] / [Florian]) -> Open Chats Menu
            if (ty >= 45 && ty <= 100 && tx >= 100 && tx <= 354) {
                WatchUi.pushView(new ChatsMenu(), new ChatsDelegate(), WatchUi.SLIDE_LEFT);
                return true;
            }

            // 2. Message card bounds: x: 35..420, y: 125..355 -> Open Chat Thread directly
            if (tx >= 35 && tx <= 420 && ty >= 125 && ty <= 355) {
                openActiveChatThread();
                return true;
            }
        } else if (_view.pageIndex == 2) {
            var coords = clickEvent.getCoordinates();
            var ty = coords[1];
            // SOS Card bounds: ty = 100..310 -> Launch SOS
            if (ty >= 100 && ty <= 310) {
                var sos = new SosView();
                WatchUi.pushView(sos, new SosDelegate(sos), WatchUi.SLIDE_UP);
                return true;
            }
        }
        return false;
    }

    //! Touchscreen Swipe handler
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        if (_view.pageIndex == 0) {
            if (swipeEvent.getDirection() == WatchUi.SWIPE_LEFT) {
                openActiveChatThread();
                return true;
            }
        } else if (_view.pageIndex == 1) {
            if (swipeEvent.getDirection() == WatchUi.SWIPE_RIGHT) {
                _view.pageIndex = 0;
                WatchUi.requestUpdate();
                return true;
            }
        } else if (_view.pageIndex == 2) {
            if (swipeEvent.getDirection() == WatchUi.SWIPE_RIGHT) {
                _view.pageIndex = 1;
                WatchUi.requestUpdate();
                return true;
            }
        }
        return false;
    }

    public function sendPositionDirect() as Void {
        var bleMgr = getBleManager();
        var chIdx = ContactManager.selectedChannelIdx;
        var success = bleMgr.sendCurrentPosition(chIdx);
        
        var msg = success ? I18n.get(Rez.Strings.ToastPositionSent) : I18n.get(Rez.Strings.ToastNotConnected);
        WatchUi.showToast(msg, null);
    }

    private function openMainMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => I18n.get(Rez.Strings.MenuTitle) });

        // 1. Chats (with active target, threads & unread status)
        var targetLabel = I18n.format(Rez.Strings.MenuActiveTarget, [ ContactManager.getTargetDisplayName() ]);
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuChats), targetLabel, "MENU_CHATS", null));

        // 2. SOS Emergency
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuSos), I18n.get(Rez.Strings.MenuSosSub), "MENU_SOS", null));

        // 3. Settings Submenu (Tastatur, BLE freigeben, Simulator)
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuSettings), I18n.get(Rez.Strings.MenuSettingsSub), "MENU_SETTINGS", null));

        // 4. Exit
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuExit), null, "MENU_EXIT", null));

        WatchUi.pushView(menu, new MainMenuDelegate(), WatchUi.SLIDE_LEFT);
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var bleMgr = getBleManager();
        var chIdx = ContactManager.selectedChannelIdx;

        if (id.equals("MENU_REPLY")) {
            var lastSender = bleMgr.lastSender;
            if (!lastSender.equals("Mesh") && !lastSender.equals("Node (Echo)")) {
                ContactManager.selectContact(lastSender, lastSender);
            }
            WatchUi.pushView(new CannedMessageMenu(), new CannedMessageDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("MENU_CHATS")) {
            WatchUi.pushView(new ChatsMenu(), new ChatsDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("MENU_MSG")) {
            WatchUi.pushView(new CannedMessageMenu(), new CannedMessageDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("MENU_POS")) {
            var ok = bleMgr.sendCurrentPosition(chIdx);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast(ok ? I18n.get(Rez.Strings.ToastPositionSent) : I18n.get(Rez.Strings.ToastNotConnected), null);
        } else if (id.equals("MENU_SOS")) {
            var sos = new SosView();
            WatchUi.pushView(sos, new SosDelegate(sos), WatchUi.SLIDE_UP);
        } else if (id.equals("MENU_SETTINGS")) {
            WatchUi.pushView(new SettingsMenu(), new SettingsDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("MENU_EXIT")) {
            System.exit();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
