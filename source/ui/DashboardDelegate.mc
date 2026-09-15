import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class DashboardDelegate extends WatchUi.BehaviorDelegate {
    private var _view as DashboardView;

    function initialize(view as DashboardView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    //! START button or Tap
    function onSelect() as Boolean {
        if (_view.pageIndex == 1) {
            // On Telemetry page: START sends position directly!
            sendPositionDirect();
        } else {
            // On Chat page: START opens main menu
            openMainMenu();
        }
        return true;
    }

    //! DOWN button / Swipe Up: Switch to Telemetry Screen
    function onNextPage() as Boolean {
        if (_view.pageIndex == 0) {
            _view.pageIndex = 1;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    //! UP button / Swipe Down: Switch to Chat Screen
    function onPreviousPage() as Boolean {
        if (_view.pageIndex == 1) {
            _view.pageIndex = 0;
            WatchUi.requestUpdate();
            return true;
        } else {
            // Shortcut on Chat Screen: Send Position immediately
            sendPositionDirect();
            return true;
        }
    }

    public function sendPositionDirect() as Void {
        var bleMgr = getBleManager();
        var chIdx = ContactManager.selectedChannelIdx;
        var success = bleMgr.sendCurrentPosition(chIdx);
        
        var msg = success ? "Position gesendet" : "Nicht verbunden!";
        WatchUi.showToast(msg, null);
    }

    private function openMainMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => "MeshCore" });
        menu.addItem(new WatchUi.MenuItem("Position senden", null, "MENU_POS", null));
        menu.addItem(new WatchUi.MenuItem("Nachricht senden", null, "MENU_MSG", null));
        menu.addItem(new WatchUi.MenuItem("Ziel wählen", ContactManager.getTargetDisplayName(), "MENU_TARGET", null));
        menu.addItem(new WatchUi.MenuItem("SOS Notruf", "Notfall Broadcast", "MENU_SOS", null));
        menu.addItem(new WatchUi.MenuItem("Node koppeln", "Bluetooth Suche", "MENU_PAIR", null));

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

        if (id.equals("MENU_POS")) {
            var ok = bleMgr.sendCurrentPosition(chIdx);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast(ok ? "Position gesendet" : "Nicht verbunden", null);
        } else if (id.equals("MENU_MSG")) {
            WatchUi.pushView(new CannedMessageMenu(), new CannedMessageDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("MENU_TARGET")) {
            WatchUi.pushView(new TargetSelectMenu(), new TargetSelectDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("MENU_SOS")) {
            WatchUi.pushView(new SosView(), new SosDelegate(), WatchUi.SLIDE_UP);
        } else if (id.equals("MENU_PAIR")) {
            bleMgr.startScan();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast("Suche Node...", null);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
