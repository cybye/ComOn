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

    //! 2 O'CLOCK BUTTON (START / SELECT)
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

    //! 4 O'CLOCK BUTTON (BACK / LAP)
    function onBack() as Boolean {
        if (_view.pageIndex == 1) {
            // On Telemetry page: Return to Chat
            _view.pageIndex = 0;
            WatchUi.requestUpdate();
            return true;
        }
        // On Chat page: Standard Garmin exit
        return false;
    }

    //! 7 O'CLOCK BUTTON (DOWN) / Swipe Up -> Go to Data page
    function onNextPage() as Boolean {
        if (_view.pageIndex == 0) {
            _view.pageIndex = 1;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    //! 9 O'CLOCK BUTTON (UP) / Swipe Down -> Go to Chat page
    function onPreviousPage() as Boolean {
        if (_view.pageIndex == 1) {
            _view.pageIndex = 0;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
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
        }
        return false;
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
        menu.addItem(new WatchUi.MenuItem("Node-Simulator", "Test-Bench", "MENU_SIM", null));
        menu.addItem(new WatchUi.MenuItem("Node koppeln", "Bluetooth Suche", "MENU_PAIR", null));
        menu.addItem(new WatchUi.MenuItem("App beenden", null, "MENU_EXIT", null));

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
        } else if (id.equals("MENU_SIM")) {
            WatchUi.pushView(new NodeSimulatorMenu(), new NodeSimulatorDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("MENU_PAIR")) {
            bleMgr.startScan();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast("Suche Node...", null);
        } else if (id.equals("MENU_EXIT")) {
            System.exit();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
