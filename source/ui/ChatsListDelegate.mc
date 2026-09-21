import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class ChatsListDelegate extends WatchUi.BehaviorDelegate {
    private var _view as ChatsListView;
    private var _lastBackTime as Number = 0;

    function initialize(view as ChatsListView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    //! 2 O'CLOCK BUTTON (START / SELECT)
    function onSelect() as Boolean {
        var item = _view.getSelectedItem();
        if (item == null) {
            System.println("ChatsListDelegate: onSelect - no item selected");
            return true;
        }

        if (item.hasKey(:isAction) && (item[:isAction] as Boolean) == true) {
            System.println("ChatsListDelegate: Action card selected -> opening TargetSelectMenu");
            getBleManager().suspendDiscoveryForUi();
            WatchUi.pushView(TargetSelectMenu.create(), new TargetSelectDelegate(), WatchUi.SLIDE_LEFT);
            return true;
        }

        var tid = item[:tid] as String;
        var title = item[:title] as String;
        var isChannel = item[:isChannel] as Boolean;

        if (isChannel) {
            ContactManager.selectChannel(item[:idx] as Number, title);
        } else {
            ContactManager.selectContact(item[:cid] as String, title);
        }

        System.println("ChatsListDelegate: onSelect -> opening ChatThreadView for " + title + " (" + tid + ")");
        var view = new ChatThreadView(tid, title);
        WatchUi.pushView(view, new ChatThreadDelegate(view), WatchUi.SLIDE_LEFT);
        return true;
    }

    //! 4 O'CLOCK BUTTON (BACK / LAP)
    function onBack() as Boolean {
        var now = System.getTimer();
        if ((now - _lastBackTime) < 2500) {
            System.println("ChatsListDelegate: BACK confirmed -> Exiting app");
            return false;
        }
        _lastBackTime = now;
        System.println("ChatsListDelegate: BACK pressed once -> showing exit toast");
        WatchUi.showToast(I18n.get(Rez.Strings.ToastPressBackAgainToExit), null);
        return true;
    }

    //! 7 O'CLOCK BUTTON (DOWN)
    function onNextPage() as Boolean {
        _view.nextItem();
        return true;
    }

    //! 9 O'CLOCK BUTTON (UP - short press)
    function onPreviousPage() as Boolean {
        _view.previousItem();
        return true;
    }

    //! 9 O'CLOCK BUTTON (MENU / UP - long press)
    function onMenu() as Boolean {
        System.println("ChatsListDelegate: onMenu called");
        openMainMenu();
        return true;
    }

    //! Touchscreen Tap handler
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var tx = coords[0];
        var ty = coords[1];
        System.println("ChatsListDelegate: onTap [" + tx + ", " + ty + "]");

        // Option A Crown Header tap (top area: y <= 110)
        // Directly opens Node Settings / Node Info Menu!
        if (ty <= 110) {
            System.println("ChatsListDelegate: Crown header tapped -> opening NodeSettingsMenu");
            getBleManager().suspendDiscoveryForUi();
            WatchUi.pushView(new NodeSettingsMenu(), new SettingsDelegate(), WatchUi.SLIDE_UP);
            return true;
        }

        // Left bezel edge tap (9 o'clock) -> Open Main Menu
        if (tx <= 85 && ty >= 170 && ty <= 285) {
            System.println("ChatsListDelegate: 9 o'clock bezel edge tapped -> opening Main Menu");
            openMainMenu();
            return true;
        }

        // Chat Card Tap
        var tappedIdx = _view.getCardIndexAt(tx, ty);
        if (tappedIdx >= 0) {
            System.println("ChatsListDelegate: Card " + tappedIdx + " tapped -> selecting and opening");
            _view.selectIndex(tappedIdx);
            return onSelect();
        }

        return false;
    }

    //! Touchscreen Swipe handler
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            _view.nextItem();
            return true;
        } else if (dir == WatchUi.SWIPE_DOWN) {
            _view.previousItem();
            return true;
        } else if (dir == WatchUi.SWIPE_LEFT) {
            return onSelect();
        }
        return false;
    }

    private function openMainMenu() as Void {
        if (getBleManager().isPairingInProgress()) {
            WatchUi.showToast(I18n.get(Rez.Strings.StatusConnecting), null);
            return;
        }
        getBleManager().suspendDiscoveryForUi();
        var menu = new WatchUi.Menu2({ :title => I18n.get(Rez.Strings.MenuTitle) });
        var targetLabel = I18n.format(Rez.Strings.MenuActiveTarget, [ ContactManager.getTargetDisplayName() ]);
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuChats), targetLabel, "MENU_CHATS", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuSos), I18n.get(Rez.Strings.MenuSosSub), "MENU_SOS", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuSettings), I18n.get(Rez.Strings.MenuSettingsSub), "MENU_SETTINGS", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.MenuExit), null, "MENU_EXIT", null));
        WatchUi.pushView(menu, new MainMenuDelegate(), WatchUi.SLIDE_LEFT);
    }
}
