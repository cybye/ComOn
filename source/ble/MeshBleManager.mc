import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;
import Toybox.StringUtil;
import Toybox.Application.Storage;
import Toybox.Timer;
import Toybox.WatchUi;

class MeshBleManager {
    public var nusServiceUuid as BluetoothLowEnergy.Uuid?;
    public var nusRxUuid      as BluetoothLowEnergy.Uuid?;
    public var nusTxUuid      as BluetoothLowEnergy.Uuid?;

    public var isConnected as Boolean = false;
    public var isScanning as Boolean = false;
    public var isSimulated as Boolean = false;
    public var deviceName as String = "MeshCore";
    public var lastReceivedMessage as String = "Bereit zum Empfang";
    public var lastSender as String = "Mesh";

    // Signal & Network Quality Metrics
    public var loraRssi as Number? = -84; // in dBm
    public var loraSnr as Number? = 6;    // in dB
    public var peerCount as Number = 3;   // Active nodes in mesh

    public var echoModeEnabled as Boolean = false;
    private var _echoTimer as Timer.Timer?;
    private var _pendingEchoText as String = "";

    private var _device as BluetoothLowEnergy.Device?;
    private var _rxCharacteristic as BluetoothLowEnergy.Characteristic?;
    private var _txCharacteristic as BluetoothLowEnergy.Characteristic?;

    public function getDevice() as BluetoothLowEnergy.Device? {
        return _device;
    }

    function initialize() {
        nusServiceUuid = BluetoothLowEnergy.stringToUuid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
        nusRxUuid      = BluetoothLowEnergy.stringToUuid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
        nusTxUuid      = BluetoothLowEnergy.stringToUuid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
    }

    public function registerProfile() as Void {
        try {
            var profileDef = {
                :uuid => nusServiceUuid,
                :characteristics => [
                    {
                        :uuid => nusRxUuid
                    },
                    {
                        :uuid => nusTxUuid,
                        :descriptors => [BluetoothLowEnergy.cccdUuid()]
                    }
                ]
            };
            BluetoothLowEnergy.registerProfile(profileDef);
        } catch (e) {
            System.println("BLE RegisterProfile notice: Profile already registered or limit reached");
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
                if (nusServiceUuid != null && u.equals(nusServiceUuid)) {
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
            if (loraRssi == null) {
                loraRssi = -84;
                loraSnr = 6;
                peerCount = ContactManager.getContacts().size();
            }
        } else {
            isConnected = false;
            _device = null;
            _rxCharacteristic = null;
            _txCharacteristic = null;
            loraRssi = null;
            loraSnr = null;
            peerCount = 0;
            startScan();
        }
    }

    private function setupCharacteristics(device as BluetoothLowEnergy.Device) as Void {
        if (nusServiceUuid == null || nusRxUuid == null || nusTxUuid == null) {
            return;
        }
        var service = device.getService(nusServiceUuid);
        if (service != null) {
            _rxCharacteristic = service.getCharacteristic(nusRxUuid);
            _txCharacteristic = service.getCharacteristic(nusTxUuid);
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
                System.println("BLE write error");
                e.printStackTrace();
            }
        }
        return false;
    }

    public function sendChannelText(channelIdx as Number, text as String) as Boolean {
        var payload = MeshProtocol.encodeChannelMessage(channelIdx, text);
        var res = sendRaw(payload);
        if (echoModeEnabled || isSimulated) {
            triggerEchoReply(text);
            return true;
        }
        return res;
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

    // -----------------------------------------------------------------
    // SIMULATION & TEST BENCH METHODS
    // -----------------------------------------------------------------
    public function simulateConnect(simDeviceName as String) as Void {
        isSimulated = true;
        isConnected = true;
        isScanning = false;
        deviceName = simDeviceName;
        loraRssi = -84;
        loraSnr = 6;
        peerCount = 3;
        WatchUi.requestUpdate();
    }

    public function simulateDisconnect() as Void {
        isSimulated = false;
        isConnected = false;
        deviceName = "MeshCore";
        loraRssi = null;
        loraSnr = null;
        peerCount = 0;
        WatchUi.requestUpdate();
    }

    public function cycleSimulatedSignal() as Void {
        if (!isConnected) {
            simulateConnect("MeshCore-Sim");
            return;
        }
        if (loraRssi == null || loraRssi < -110) {
            loraRssi = -72;
            loraSnr = 8;
            peerCount = 4;
        } else if (loraRssi > -80) {
            loraRssi = -94;
            loraSnr = 2;
            peerCount = 3;
        } else {
            loraRssi = -118;
            loraSnr = -8;
            peerCount = 1;
        }
        WatchUi.requestUpdate();
    }

    public function getSignalStatusString() as String {
        if (!isConnected || loraRssi == null) {
            return "Offline";
        }
        var snrStr = (loraSnr != null && loraSnr > 0) ? ("+" + loraSnr.toString()) : ((loraSnr != null) ? loraSnr.toString() : "-");
        return loraRssi.toString() + " dBm (SNR " + snrStr + ")";
    }

    public function simulateIncomingMessage(sender as String, message as String) as Void {
        lastReceivedMessage = message;
        lastSender = sender;
        MeshNotificationManager.getInstance().showIncomingMessage(sender, message);
        WatchUi.requestUpdate();
    }

    public function triggerEchoReply(text as String) as Void {
        _pendingEchoText = text;
        if (_echoTimer == null) {
            _echoTimer = new Timer.Timer();
        }
        _echoTimer.start(method(:onEchoTimerExpired), 1200, false);
    }

    public function onEchoTimerExpired() as Void {
        simulateIncomingMessage("Node (Echo)", "ACK: " + _pendingEchoText);
    }
}
