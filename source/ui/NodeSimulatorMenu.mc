import Toybox.WatchUi;
import Toybox.Lang;

class NodeSimulatorMenu {
    public static function create() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({ :title => I18n.get(Rez.Strings.SimMenuTitle) });

        var bleMgr = getBleManager();
        var vNode = bleMgr.virtualNode;
        var connSub = bleMgr.isConnected ? I18n.format(Rez.Strings.SimStatusActive, [ bleMgr.deviceName ]) : I18n.get(Rez.Strings.SimStatusDisconnected);
        var echoSub = vNode.echoMode ? I18n.get(Rez.Strings.SimStatusOn) : I18n.get(Rez.Strings.SimStatusOff);
        var bufCount = vNode.getPendingInboxCount();
        var bufSub = I18n.format(Rez.Strings.SimBufferSub, [ bufCount ]);

        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SimVirtualBle), connSub, "SIM_CONN", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SimBufferMsgs), bufSub, "SIM_BUFFER", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SimInjectMsg), "Florian: Wegpunkt 3...", "SIM_MSG", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SimInjectSos), "Notfall Broadcast", "SIM_SOS", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SimInjectContact), "Bergwacht Team 2", "SIM_DISCOVER", null));
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SimEchoToggle), echoSub, "SIM_ECHO", null));
        var sigSub = bleMgr.isConnected ? I18n.format(Rez.Strings.SimStatusOnSignal, [ bleMgr.getSignalStatusString() ]) : I18n.get(Rez.Strings.SimStatusOffline);
        menu.addItem(new WatchUi.MenuItem(I18n.get(Rez.Strings.SimCycleSignal), sigSub, "SIM_SIGNAL", null));

        return menu;
    }
}

class NodeSimulatorDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var bleManager = getBleManager();
        var node = bleManager.virtualNode;
        if (id.equals("SIM_CONN")) {
            if (bleManager.isConnected) { bleManager.simulateDisconnect(); }
            else { bleManager.simulateConnect("Virtual-Node"); }
        } else if (id.equals("SIM_BUFFER")) {
            node.fillInboxWithMissedMessages();
        } else if (id.equals("SIM_MSG")) {
            node.injectMessage("Florian", "Bin 200m hinter dir am Steig.", 0);
        } else if (id.equals("SIM_SOS")) {
            node.injectMessage("SOS Florian", "Notfall! 47.4925N 11.0955E", 1);
        } else if (id.equals("SIM_DISCOVER")) {
            node.injectContact("Bergwacht Team 2", "NODE_BW2");
        } else if (id.equals("SIM_ECHO")) {
            node.echoMode = !node.echoMode;
        } else if (id.equals("SIM_SIGNAL")) {
            bleManager.cycleSimulatedSignal();
        }
        WatchUi.requestUpdate();
    }

    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
