import Toybox.WatchUi;
import Toybox.Lang;

class NodeSimulatorMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Node-Simulator" });

        var bleMgr = getBleManager();
        var vNode = bleMgr.virtualNode;
        var connSub = bleMgr.isConnected ? "Aktiv (" + bleMgr.deviceName + ")" : "Getrennt";
        var echoSub = vNode.echoMode ? "Status: AN" : "Status: AUS";
        var bufCount = vNode.getPendingInboxCount();
        var bufSub = bufCount.toString() + " Nachricht(en) im Puffer";

        addItem(new WatchUi.MenuItem("Virtuelle Node BLE", connSub, "SIM_CONN", null));
        addItem(new WatchUi.MenuItem("3 Offline-Nachrichten puffern", bufSub, "SIM_BUFFER", null));
        addItem(new WatchUi.MenuItem("Funkspruch einspeisen", "Florian: Wegpunkt 3...", "SIM_MSG", null));
        addItem(new WatchUi.MenuItem("SOS Notruf einspeisen", "Notfall Broadcast", "SIM_SOS", null));
        addItem(new WatchUi.MenuItem("Neuer Kontakt (Delta)", "Bergwacht Team 2", "SIM_DISCOVER", null));
        addItem(new WatchUi.MenuItem("Echo / Auto-Reply", echoSub, "SIM_ECHO", null));
        var sigSub = bleMgr.isConnected ? ("Status: AN (" + bleMgr.getSignalStatusString() + ")") : "Getrennt (Offline)";
        addItem(new WatchUi.MenuItem("Signal durchschalten", sigSub, "SIM_SIGNAL", null));
    }
}

class NodeSimulatorDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var bleMgr = getBleManager();
        var vNode = bleMgr.virtualNode;

        if (id.equals("SIM_CONN")) {
            if (bleMgr.isConnected) {
                bleMgr.simulateDisconnect();
                item.setSubLabel("Getrennt");
                WatchUi.showToast("Virtuelle Node getrennt", null);
            } else {
                bleMgr.simulateConnect("Virtual-Node");
                item.setSubLabel("Aktiv (Virtual-Node)");
                WatchUi.showToast("Verbunden: Virtual-Node", null);
            }
        } else if (id.equals("SIM_BUFFER")) {
            vNode.fillInboxWithMissedMessages();
            item.setSubLabel(vNode.getPendingInboxCount().toString() + " Nachricht(en) im Puffer");
            WatchUi.showToast("3 Nachrichten gepuffert!", null);
        } else if (id.equals("SIM_MSG")) {
            vNode.injectMessage("Florian", "Bin 200m hinter dir am Steig.", 0);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast("Funkspruch gesendet", null);
        } else if (id.equals("SIM_SOS")) {
            vNode.injectMessage("SOS Florian", "Notfall! 47.4925N 11.0955E", 1);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast("Notruf eingespeist!", null);
        } else if (id.equals("SIM_DISCOVER")) {
            vNode.injectContact("Bergwacht Team 2", "NODE_BW2");
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast("Neuer Kontakt aktiv", null);
        } else if (id.equals("SIM_ECHO")) {
            vNode.echoMode = !vNode.echoMode;
            item.setSubLabel(vNode.echoMode ? "Status: AN" : "Status: AUS");
            WatchUi.showToast(vNode.echoMode ? "Echo: AN (Antwort nach 1.5s)" : "Echo: AUS", null);
        } else if (id.equals("SIM_SIGNAL")) {
            bleMgr.cycleSimulatedSignal();
            var sigStr = bleMgr.getSignalStatusString();
            item.setSubLabel("Status: AN (" + sigStr + ")");
            WatchUi.showToast("Signal: " + sigStr, null);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
