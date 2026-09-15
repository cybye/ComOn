import Toybox.WatchUi;
import Toybox.Lang;

class NodeSimulatorMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Node-Simulator" });

        var bleMgr = getBleManager();
        var connSub = bleMgr.isConnected ? "Aktiv (" + bleMgr.deviceName + ")" : "Getrennt";
        var echoSub = bleMgr.echoModeEnabled ? "Status: AN" : "Status: AUS";

        addItem(new WatchUi.MenuItem("Nachricht simulieren", "Team: Wo seid ihr?", "SIM_MSG", null));
        addItem(new WatchUi.MenuItem("SOS Notruf einspeisen", "Notfall Broadcast", "SIM_SOS", null));
        addItem(new WatchUi.MenuItem("Neue Kontakte lernen", "OTA Discovery (+3)", "SIM_DISCOVER", null));
        addItem(new WatchUi.MenuItem("Echo / Loopback", echoSub, "SIM_ECHO", null));
        addItem(new WatchUi.MenuItem("Verbindung umschalten", connSub, "SIM_CONN", null));
    }
}

class NodeSimulatorDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var bleMgr = getBleManager();

        if (id.equals("SIM_MSG")) {
            bleMgr.simulateIncomingMessage("Florian", "Team Alpha: Wo seid ihr?");
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast("Nachricht empfangen!", null);
        } else if (id.equals("SIM_SOS")) {
            bleMgr.simulateIncomingMessage("SOS Florian", "Notfall 47.4925N 11.0955E");
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast("Notruf empfangen!", null);
        } else if (id.equals("SIM_DISCOVER")) {
            ContactManager.addChannel(3, "Kanal: Bergwacht");
            ContactManager.addContact("NODE_FLORIAN", "Florian (Node-4A)");
            ContactManager.addContact("NODE_BASECAMP", "HQ Basecamp (Node-01)");
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.showToast("+3 Ziele hinzugefuegt", null);
        } else if (id.equals("SIM_ECHO")) {
            bleMgr.echoModeEnabled = !bleMgr.echoModeEnabled;
            item.setSubLabel(bleMgr.echoModeEnabled ? "Status: AN" : "Status: AUS");
            WatchUi.showToast(bleMgr.echoModeEnabled ? "Echo: AN (Antwort nach 1.2s)" : "Echo: AUS", null);
        } else if (id.equals("SIM_CONN")) {
            if (bleMgr.isConnected) {
                bleMgr.simulateDisconnect();
                item.setSubLabel("Getrennt");
                WatchUi.showToast("Node getrennt", null);
            } else {
                bleMgr.simulateConnect("MeshCore-Sim");
                item.setSubLabel("Aktiv (MeshCore-Sim)");
                WatchUi.showToast("Verbunden: MeshCore-Sim", null);
            }
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
