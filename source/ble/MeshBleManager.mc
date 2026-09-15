import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;
import Toybox.StringUtil;
import Toybox.Application.Storage;

class MeshBleManager {
    public const NUS_SERVICE_UUID = BluetoothLowEnergy.stringToUuid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
    public const NUS_RX_UUID      = BluetoothLowEnergy.stringToUuid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
    public const NUS_TX_UUID      = BluetoothLowEnergy.stringToUuid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

    private const _nusProfileDef = {
        :uuid => NUS_SERVICE_UUID,
        :characteristics => [
            {
                :uuid => NUS_RX_UUID
            },
            {
                :uuid => NUS_TX_UUID,
                :descriptors => [BluetoothLowEnergy.cccdUuid()]
            }
        ]
    };

    public var isConnected as Boolean = false;
    public var isScanning as Boolean = false;
    public var deviceName as String = "MeshCore";
    public var lastReceivedMessage as String = "Bereit zum Empfang";
    public var lastSender as String = "Mesh";

    private var _device as BluetoothLowEnergy.Device?;
    private var _rxCharacteristic as BluetoothLowEnergy.Characteristic?;
    private var _txCharacteristic as BluetoothLowEnergy.Characteristic?;

    public function getDevice() as BluetoothLowEnergy.Device? {
        return _device;
    }

    function initialize() {
    }

    public function registerProfile() as Void {
        try {
            BluetoothLowEnergy.registerProfile(_nusProfileDef);
        } catch (e) {
            System.println("BLE RegisterProfile error: " + e.getErrorMessage());
        }
    }

    public function startScan() as Void {
        if (!isScanning && !isConnected) {
            isScanning = true;
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
        }
    }

    public function stopScan() as Void {
        if (isScanning) {
            isScanning = false;
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
        }
    }

    public function procScanResults(scanResults as BluetoothLowEnergy.Iterator) as Void {
        for (var result = scanResults.next(); result != null; result = scanResults.next()) {
            var res = result as BluetoothLowEnergy.ScanResult;
            var iter = res.getServiceUuids();
            for (var u = iter.next(); u != null; u = iter.next()) {
                if (u.equals(NUS_SERVICE_UUID)) {
                    stopScan();
                    var name = res.getDeviceName();
                    if (name != null) {
                        deviceName = name;
                    }
                    BluetoothLowEnergy.pairDevice(res);
                    return;
                }
            }
        }
    }

    public function procConnectedStateChanged(device as BluetoothLowEnergy.Device, state as BluetoothLowEnergy.ConnectionState) as Void {
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            isConnected = true;
            _device = device;
            setupCharacteristics(device);
        } else {
            isConnected = false;
            _device = null;
            _rxCharacteristic = null;
            _txCharacteristic = null;
            startScan();
        }
    }

    private function setupCharacteristics(device as BluetoothLowEnergy.Device) as Void {
        var service = device.getService(NUS_SERVICE_UUID);
        if (service != null) {
            _rxCharacteristic = service.getCharacteristic(NUS_RX_UUID);
            _txCharacteristic = service.getCharacteristic(NUS_TX_UUID);
            if (_txCharacteristic != null) {
                var cccd = _txCharacteristic.getDescriptor(BluetoothLowEnergy.cccdUuid());
                if (cccd != null) {
                    var enableNotification = [0x01, 0x00] as ByteArray;
                    cccd.requestWrite(enableNotification);
                }
            }
        }
    }

    public function procCharacteristicChanged(characteristic as BluetoothLowEnergy.Characteristic, value as ByteArray) as Void {
        if (value != null && value.size() > 0) {
            var arr = [] as Array<Number>;
            for (var i = 0; i < value.size(); i++) {
                arr.add(value[i]);
            }
            var msgText = StringUtil.utf8ArrayToString(arr);
            lastReceivedMessage = msgText;
            lastSender = "Mesh";

            // Show interactive notification via Toybox.Notifications
            MeshNotificationManager.getInstance().showIncomingMessage(lastSender, msgText);
        }
    }

    public function procCharacteristicWrite(characteristic as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status) as Void {
        // Callback on write complete
    }

    public function procDescriptorWrite(descriptor as BluetoothLowEnergy.Descriptor, status as BluetoothLowEnergy.Status) as Void {
        // Callback on CCCD write complete
    }

    public function sendRaw(bytes as ByteArray) as Boolean {
        if (isConnected && _rxCharacteristic != null) {
            try {
                _rxCharacteristic.requestWrite(bytes, { :writeType => BluetoothLowEnergy.WRITE_TYPE_DEFAULT });
                return true;
            } catch (e) {
                System.println("BLE write error: " + e.getErrorMessage());
            }
        }
        return false;
    }

    public function sendChannelText(channelIdx as Number, text as String) as Boolean {
        var payload = MeshProtocol.encodeChannelMessage(channelIdx, text);
        return sendRaw(payload);
    }

    //! Universal Position Send
    public function sendCurrentPosition(channelIdx as Number) as Boolean {
        var posStr = TelemetryProvider.getInstance().getFormattedPosition();
        return sendChannelText(channelIdx, posStr);
    }

    //! SOS Emergency Send
    public function sendSosEmergency(channelIdx as Number) as Boolean {
        var sosStr = TelemetryProvider.getInstance().getFormattedSos();
        return sendChannelText(channelIdx, sosStr);
    }
}
