import Toybox.Application.Storage;
import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;

class MeshSensorDelegate extends Sensor.SensorDelegate {
    private static const STORAGE_SCAN_RESULT as String = "cfg_mesh_sensor_scan_result";

    private var _bleDelegate as MeshSensorBleDelegate;
    private var _sensor as Sensor.SensorInfo? = null;
    private var _scanResult as BluetoothLowEnergy.ScanResult? = null;

    function initialize() {
        SensorDelegate.initialize();
        _bleDelegate = new MeshSensorBleDelegate(self);
        BluetoothLowEnergy.setDelegate(_bleDelegate);
        var serviceUuid = BluetoothLowEnergy.stringToUuid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
        var rxUuid = BluetoothLowEnergy.stringToUuid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
        var txUuid = BluetoothLowEnergy.stringToUuid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
        BluetoothLowEnergy.registerProfile({
            :uuid => serviceUuid,
            :characteristics => [
                { :uuid => rxUuid },
                { :uuid => txUuid, :descriptors => [ BluetoothLowEnergy.cccdUuid() ] }
            ]
        });
    }

    public function pairingRequired() as Boolean {
        return Storage.getValue(STORAGE_SCAN_RESULT) == null;
    }

    public function onScan() as Boolean {
        try {
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
            System.println("Native pairing: scan started");
            return true;
        } catch (e) {
            System.println("Native pairing: scan failed: " + e.getErrorMessage());
            return false;
        }
    }

    public function onPair(sensor as Sensor.SensorInfo) as Boolean {
        var data = sensor.data;
        if (data == null) {
            return false;
        }
        var scanResult = data[:bleScanResult] as BluetoothLowEnergy.ScanResult?;
        if (scanResult == null) {
            return false;
        }
        _sensor = sensor;
        _scanResult = scanResult;
        try {
            var device = BluetoothLowEnergy.pairDevice(scanResult);
            System.println("Native pairing: pairDevice returned " + (device != null));
            return device != null;
        } catch (e) {
            System.println("Native pairing: pairDevice failed: " + e.getErrorMessage());
            return false;
        }
    }

    public function onUnpair(sensor as Sensor.SensorInfo) as Boolean {
        Storage.deleteValue(STORAGE_SCAN_RESULT);
        Sensor.notifyUnpairComplete(sensor);
        _sensor = null;
        _scanResult = null;
        return true;
    }

    public function reportScanResult(scanResult as BluetoothLowEnergy.ScanResult) as Void {
        var sensor = new Sensor.SensorInfo();
        var name = scanResult.getDeviceName();
        sensor.name = (name != null) ? name : "MeshCore Node";
        sensor.technology = Sensor.SENSOR_TECHNOLOGY_BLE;
        sensor.type = Sensor.SENSOR_GENERIC;
        sensor.data = { :bleScanResult => scanResult };
        sensor.partNumber = 0;
        sensor.manufacturerId = 0;
        Sensor.notifyNewSensor(sensor, true);
        Sensor.notifyScanComplete();
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
    }

    public function reportConnection(device as BluetoothLowEnergy.Device, state as BluetoothLowEnergy.ConnectionState) as Void {
        System.println("Native pairing: connection state=" + state);
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED && _sensor != null && _scanResult != null) {
            Storage.setValue(STORAGE_SCAN_RESULT, _scanResult);
            try {
                if (device has :isBonded && device has :requestBond && !device.isBonded()) {
                    device.requestBond();
                    System.println("Native pairing: requested persistent bond");
                }
            } catch (e) {
                System.println("Native pairing: bond request failed: " + e.getErrorMessage());
            }
            Sensor.notifyPairComplete(_sensor);
        }
    }

    public static function getStoredScanResult() as BluetoothLowEnergy.ScanResult? {
        return Storage.getValue(STORAGE_SCAN_RESULT) as BluetoothLowEnergy.ScanResult?;
    }

    public static function clearStoredScanResult() as Void {
        Storage.deleteValue(STORAGE_SCAN_RESULT);
    }
}

class MeshSensorBleDelegate extends BluetoothLowEnergy.BleDelegate {
    private var _owner as MeshSensorDelegate;
    private var _serviceUuid as BluetoothLowEnergy.Uuid;

    function initialize(owner as MeshSensorDelegate) {
        BleDelegate.initialize();
        _owner = owner;
        _serviceUuid = BluetoothLowEnergy.stringToUuid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
    }

    public function onScanResults(scanResults as BluetoothLowEnergy.Iterator) as Void {
        for (var result = scanResults.next(); result != null; result = scanResults.next()) {
            var scanResult = result as BluetoothLowEnergy.ScanResult;
            var serviceUuids = scanResult.getServiceUuids();
            for (var uuid = serviceUuids.next(); uuid != null; uuid = serviceUuids.next()) {
                if (uuid.equals(_serviceUuid)) {
                    _owner.reportScanResult(scanResult);
                    return;
                }
            }
        }
    }

    public function onConnectedStateChanged(device as BluetoothLowEnergy.Device, state as BluetoothLowEnergy.ConnectionState) as Void {
        _owner.reportConnection(device, state);
    }
}
