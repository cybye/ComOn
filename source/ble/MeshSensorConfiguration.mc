import Toybox.Sensor;
import Toybox.WatchUi;

class MeshSensorConfigurationView extends WatchUi.CheckboxMenu {
    function initialize() {
        CheckboxMenu.initialize({ :title => "MeshCore Node" });
        addItem(new WatchUi.CheckboxMenuItem("Use with Mesh Companion", null, "MESH_ENABLED", true, null));
    }
}

class MeshSensorConfigurationDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onDone() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
