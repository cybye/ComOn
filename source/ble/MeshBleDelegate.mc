import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;

class MeshBleDelegate extends BluetoothLowEnergy.BleDelegate {
    private var _manager as MeshBleManager;

    function initialize(manager as MeshBleManager) {
        BleDelegate.initialize();
        _manager = manager;
    }

    function onScanResults(scanResults as BluetoothLowEnergy.Iterator) as Void {
        _manager.procScanResults(scanResults);
    }

    function onConnectedStateChanged(device as BluetoothLowEnergy.Device, state as BluetoothLowEnergy.ConnectionState) as Void {
        _manager.procConnectedStateChanged(device, state);
    }

    function onCharacteristicChanged(characteristic as BluetoothLowEnergy.Characteristic, value as ByteArray) as Void {
        _manager.procCharacteristicChanged(characteristic, value);
    }

    function onCharacteristicWrite(characteristic as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status) as Void {
        _manager.procCharacteristicWrite(characteristic, status);
    }

    function onDescriptorWrite(descriptor as BluetoothLowEnergy.Descriptor, status as BluetoothLowEnergy.Status) as Void {
        _manager.procDescriptorWrite(descriptor, status);
    }
}
