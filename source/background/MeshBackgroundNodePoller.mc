import Toybox.Background;
import Toybox.BluetoothLowEnergy;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Notifications;
import Toybox.StringUtil;
import Toybox.System;
import Toybox.Time;

(:background)
class MeshBackgroundNodePoller {
    private static const POLL_TIMEOUT_MS as Number = 12000;
    private static const MAX_BACKGROUND_MESSAGES as Number = 5;
    private static const BATTERY_POLL_INTERVAL_SECS as Number = 3600;

    private var _owner as MeshBackgroundDelegate;
    private var _delegate as MeshBackgroundBleDelegate;
    private var _serviceUuid as BluetoothLowEnergy.Uuid;
    private var _rxUuid as BluetoothLowEnergy.Uuid;
    private var _txUuid as BluetoothLowEnergy.Uuid;
    private var _device as BluetoothLowEnergy.Device? = null;
    private var _rxCharacteristic as BluetoothLowEnergy.Characteristic? = null;
    private var _txCharacteristic as BluetoothLowEnergy.Characteristic? = null;
    private var _fragmentBuffer as ByteArray? = null;
    private var _deadlineAt as Number = 0;
    private var _finished as Boolean = false;
    private var _isScanning as Boolean = false;
    private var _connectedToNode as Boolean = false;
    private var _awaitingBattery as Boolean = false;
    private var _polledBatteryPercent as Number? = null;
    private var _messageCount as Number = 0;
    private var _lastSender as String? = null;
    private var _lastMessage as String? = null;
    private var _lastNotificationTitle as String? = null;
    private var _targetIds as Array<String> = [] as Array<String>;

    function initialize(owner as MeshBackgroundDelegate) {
        _owner = owner;
        _delegate = new MeshBackgroundBleDelegate(self);
        _serviceUuid = BluetoothLowEnergy.stringToUuid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
        _rxUuid = BluetoothLowEnergy.stringToUuid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
        _txUuid = BluetoothLowEnergy.stringToUuid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
    }

    public function start() as Void {
        try {
            BluetoothLowEnergy.setDelegate(_delegate);
            BluetoothLowEnergy.registerProfile({
                :uuid => _serviceUuid,
                :characteristics => [
                    { :uuid => _rxUuid },
                    { :uuid => _txUuid, :descriptors => [ BluetoothLowEnergy.cccdUuid() ] }
                ]
            });
            startDeadline();
            startScan();
        } catch (e) {
            System.println("Background poll: BLE setup failed: " + e.getErrorMessage());
            finish();
        }
    }

    private function startDeadline() as Void {
        _deadlineAt = Time.now().value() + (POLL_TIMEOUT_MS / 1000);
    }

    private function expired() as Boolean {
        return Time.now().value() >= _deadlineAt;
    }

    private function startScan() as Void {
        try {
            _isScanning = true;
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
            System.println("Background poll: scanning for Mesh node");
        } catch (e) {
            System.println("Background poll: scan start failed: " + e.getErrorMessage());
            finish();
        }
    }

    private function stopScan() as Void {
        if (!_isScanning) {
            return;
        }
        _isScanning = false;
        try {
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
        } catch (e) {
            System.println("Background poll: scan stop notice: " + e.getErrorMessage());
        }
    }

    public function onScanResults(scanResults as BluetoothLowEnergy.Iterator) as Void {
        if (_finished) {
            return;
        }
        if (expired()) {
            System.println("Background poll: deadline reached while scanning");
            finish();
            return;
        }
        try {
            for (var result = scanResults.next(); result != null; result = scanResults.next()) {
                var scanResult = result as BluetoothLowEnergy.ScanResult;
                if (!advertisesMeshService(scanResult)) {
                    continue;
                }
                stopScan();
                System.println("Background poll: Mesh node found, starting connection");
                var dev = BluetoothLowEnergy.pairDevice(scanResult);
                if (dev == null) {
                    System.println("Background poll: node connection was not started");
                    finish();
                } else {
                    _device = dev;
                }
                return;
            }
        } catch (e) {
            System.println("Background poll: scan result handling failed: " + e.getErrorMessage());
            finish();
        }
    }

    private function advertisesMeshService(scanResult as BluetoothLowEnergy.ScanResult) as Boolean {
        var serviceUuids = scanResult.getServiceUuids();
        for (var uuid = serviceUuids.next(); uuid != null; uuid = serviceUuids.next()) {
            if (uuid.equals(_serviceUuid)) {
                return true;
            }
        }
        return false;
    }

    public function onConnectedStateChanged(device as BluetoothLowEnergy.Device, state as BluetoothLowEnergy.ConnectionState) as Void {
        if (_finished) {
            return;
        }
        if (state == BluetoothLowEnergy.CONNECTION_STATE_DISCONNECTED) {
            System.println("Background poll: disconnected from node");
            finish();
            return;
        }
        if (state != BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            return;
        }
        stopScan();
        _device = device;
        if (expired()) {
            System.println("Background poll: deadline reached before connection");
            finish();
            return;
        }
        try {
            var service = device.getService(_serviceUuid);
            if (service == null) {
                System.println("Background poll: NUS service unavailable");
                finish();
                return;
            }
            _rxCharacteristic = service.getCharacteristic(_rxUuid);
            _txCharacteristic = service.getCharacteristic(_txUuid);
            if (_rxCharacteristic == null || _txCharacteristic == null) {
                System.println("Background poll: NUS characteristics unavailable");
                finish();
                return;
            }
            var cccd = (_txCharacteristic as BluetoothLowEnergy.Characteristic).getDescriptor(BluetoothLowEnergy.cccdUuid());
            if (cccd == null) {
                System.println("Background poll: notification descriptor unavailable");
                finish();
                return;
            }
            cccd.requestWrite([0x01, 0x00]b);
        } catch (e) {
            System.println("Background poll: characteristic setup failed: " + e.getErrorMessage());
            finish();
        }
    }

    public function onDescriptorWrite(descriptor as BluetoothLowEnergy.Descriptor, status as BluetoothLowEnergy.Status) as Void {
        if (_finished) {
            return;
        }
        if (expired()) {
            System.println("Background poll: deadline reached before inbox request");
            finish();
            return;
        }
        if (status == 18 || status == 19) {
            System.println("Background poll: CCCD waiting for link encryption (status=" + status + ")");
            return;
        }
        if (status != BluetoothLowEnergy.STATUS_SUCCESS) {
            System.println("Background poll: notification subscription failed: " + status);
            finish();
            return;
        }
        _connectedToNode = true;
        startDataSync();
    }

    private function startDataSync() as Void {
        var now = Time.now().value();
        var lastBatt = Storage.getValue(StorageKeys.LAST_BG_BATTERY_POLL_TIME);
        var due = (lastBatt == null) || (!(lastBatt instanceof Number)) || ((now - (lastBatt as Number)) >= BATTERY_POLL_INTERVAL_SECS);
        if (due) {
            requestBattery();
        } else {
            requestNextMessage();
        }
    }

    private function requestBattery() as Void {
        if (_rxCharacteristic == null) {
            finish();
            return;
        }
        if (expired()) {
            System.println("Background poll: deadline reached before battery request");
            finish();
            return;
        }
        _awaitingBattery = true;
        try {
            _rxCharacteristic.requestWrite([MeshFrameParser.CMD_GET_BATTERY_AND_STORAGE]b, { :writeType => BluetoothLowEnergy.WRITE_TYPE_DEFAULT });
            System.println("Background poll: requested node battery");
        } catch (e) {
            System.println("Background poll: battery request failed: " + e.getErrorMessage());
            _awaitingBattery = false;
            requestNextMessage();
        }
    }

    public function onCharacteristicWrite(characteristic as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status) as Void {
        if (!_finished && status != BluetoothLowEnergy.STATUS_SUCCESS) {
            System.println("Background poll: inbox request write failed: " + status);
            finish();
        }
    }

    public function onEncryptionStatus(device as BluetoothLowEnergy.Device, status as BluetoothLowEnergy.Status) as Void {
        if (_finished) {
            return;
        }
        if (status == BluetoothLowEnergy.STATUS_SUCCESS) {
            System.println("Background poll: encryption established");
            if (!_connectedToNode && _txCharacteristic != null) {
                var cccd = (_txCharacteristic as BluetoothLowEnergy.Characteristic).getDescriptor(BluetoothLowEnergy.cccdUuid());
                if (cccd != null) {
                    cccd.requestWrite([0x01, 0x00]b);
                }
            }
        } else {
            System.println("Background poll: encryption failed: " + status);
            finish();
        }
    }

    private function requestNextMessage() as Void {
        if (_rxCharacteristic == null) {
            finish();
            return;
        }
        if (expired()) {
            System.println("Background poll: deadline reached during inbox sync");
            finish();
            return;
        }
        try {
            _rxCharacteristic.requestWrite([MeshFrameParser.CMD_SYNC_NEXT_MESSAGE]b, { :writeType => BluetoothLowEnergy.WRITE_TYPE_DEFAULT });
        } catch (e) {
            System.println("Background poll: inbox request failed: " + e.getErrorMessage());
            finish();
        }
    }

    public function onCharacteristicChanged(characteristic as BluetoothLowEnergy.Characteristic, value as ByteArray) as Void {
        if (_finished || value == null || value.size() == 0) {
            return;
        }
        if (expired()) {
            System.println("Background poll: deadline reached while receiving data");
            finish();
            return;
        }
        if (_fragmentBuffer != null) {
            var firstByte = value[0] as Number;
            if (MeshFrameParser.isControlFrame(firstByte)) {
                finishFragment();
            } else {
                (_fragmentBuffer as ByteArray).addAll(value);
                if (value.size() < 20) {
                    finishFragment();
                }
                return;
            }
        }
        if (value.size() == 20 && MeshFrameParser.isMessageFrame(value[0] as Number)) {
            _fragmentBuffer = []b;
            (_fragmentBuffer as ByteArray).addAll(value);
            return;
        }
        processFrame(value);
    }

    private function finishFragment() as Void {
        var frame = _fragmentBuffer;
        _fragmentBuffer = null;
        if (frame != null) {
            processFrame(frame as ByteArray);
        }
    }

    private function processFrame(value as ByteArray) as Void {
        var code = value[0] as Number;
        if (_awaitingBattery) {
            _awaitingBattery = false;
            if (code == MeshFrameParser.RESP_CODE_BATT_AND_STORAGE) {
                storeBattery(value);
            } else if (code == MeshFrameParser.RESP_CODE_ERR) {
                System.println("Background poll: battery query returned err");
            }
            requestNextMessage();
            return;
        }

        if (code == MeshFrameParser.RESP_CODE_NO_MORE_MESSAGES || code == MeshFrameParser.RESP_CODE_ERR) {
            finish();
            return;
        }
        if (code == MeshFrameParser.RESP_CODE_CONTACT_MSG || code == MeshFrameParser.RESP_CODE_CONTACT_MSG_V3) {
            storeDirectMessage(value);
            requestFollowingMessage();
            return;
        }
        if (code == MeshFrameParser.RESP_CODE_CHANNEL_MSG || code == MeshFrameParser.RESP_CODE_CHANNEL_MSG_V3) {
            storeChannelMessage(value);
            requestFollowingMessage();
            return;
        }
        if (code == MeshFrameParser.PUSH_CODE_MSG_WAITING) {
            requestNextMessage();
            return;
        }
        if (code >= 0x80) {
            return;
        }
        System.println("Background poll: unexpected frame " + code);
        finish();
    }

    private function requestFollowingMessage() as Void {
        if (_messageCount >= MAX_BACKGROUND_MESSAGES) {
            System.println("Background poll: inbox batch limit reached");
            finish();
            return;
        }
        requestNextMessage();
    }

    private function storeChannelMessage(value as ByteArray) as Void {
        var parsed = MeshFrameParser.parseChannelMessage(value);
        if (parsed == null) {
            return;
        }
        var channelIndex = parsed[:channelIdx] as Number;
        var channelName = resolveChannelName(channelIndex);
        var sender = parsed[:sender] as String;
        var message = parsed[:text] as String;
        storeMessage("CH_" + channelIndex.format("%d"), sender, message, channelName + ": " + sender);
    }

    private function storeDirectMessage(value as ByteArray) as Void {
        var parsed = MeshFrameParser.parseDirectMessage(value);
        if (parsed == null) {
            return;
        }
        var senderId = parsed[:senderHex] as String;
        var sender = resolveContactName(senderId);
        var text = parsed[:text] as String;
        storeMessage("CT_" + senderId, sender, text, "@" + sender);
    }

    private function resolveChannelName(channelIndex as Number) as String {
        var channelId = channelIndex.format("%d");
        try {
            var stored = Storage.getValue(StorageKeys.BG_CHANNEL_NAME_PREFIX + channelId);
            if (stored instanceof String) {
                var channelName = stored as String;
                if (channelName.length() > 0) {
                    return channelName;
                }
            }
        } catch (e) {
            System.println("Background poll: channel name lookup failed");
        }
        return "#" + channelId;
    }

    private function resolveContactName(senderId as String) as String {
        try {
            var stored = Storage.getValue(StorageKeys.BG_CONTACT_NAME_PREFIX + senderId);
            if (stored instanceof String) {
                var contactName = stored as String;
                if (contactName.length() > 0) {
                    return contactName;
                }
            }
        } catch (e) {
            System.println("Background poll: contact name lookup failed");
        }
        return senderId;
    }

    private function storeMessage(targetId as String, sender as String, text as String, notificationTitle as String) as Void {
        MeshBackgroundInboxStore.addIncomingMessage(targetId, sender, text);
        _messageCount += 1;
        _lastSender = sender;
        _lastMessage = text;
        _lastNotificationTitle = notificationTitle;
        var knownTarget = false;
        for (var index = 0; index < _targetIds.size(); index++) {
            if (_targetIds[index].equals(targetId)) {
                knownTarget = true;
                break;
            }
        }
        if (!knownTarget) {
            _targetIds.add(targetId);
        }
    }

    private function storeBattery(value as ByteArray) as Void {
        var parsed = MeshFrameParser.parseBattery(value);
        if (parsed == null) {
            return;
        }
        var mv = parsed[:mv] as Number;
        var percent = parsed[:percent] as Number;
        var now = Time.now().value();
        Storage.setValue(StorageKeys.LAST_BG_BATTERY_POLL_TIME, now);
        Storage.setValue(StorageKeys.CACHED_NODE_BATTERY_MV, mv);
        Storage.setValue(StorageKeys.CACHED_NODE_BATTERY_PERCENT, percent);
        Storage.setValue(StorageKeys.CACHED_NODE_BATTERY_TIME, now);
        _polledBatteryPercent = percent;
        System.println("Background poll: node battery updated: " + mv + " mV (" + percent + "%)");
    }

    private function finish() as Void {
        if (_finished) {
            return;
        }
        _finished = true;
        if (_fragmentBuffer != null) {
            var pending = _fragmentBuffer;
            _fragmentBuffer = null;
            processFrame(pending as ByteArray);
        }
        stopScan();
        if (_device != null) {
            try {
                BluetoothLowEnergy.unpairDevice(_device as BluetoothLowEnergy.Device);
            } catch (e) {
                // ignore
            }
            _device = null;
        }
        _owner.onPollComplete(_messageCount, _lastSender, _lastMessage, _lastNotificationTitle, _connectedToNode, _targetIds, _polledBatteryPercent);
    }
}

(:background)
class MeshBackgroundBleDelegate extends BluetoothLowEnergy.BleDelegate {
    private var _poller as MeshBackgroundNodePoller;

    function initialize(poller as MeshBackgroundNodePoller) {
        BleDelegate.initialize();
        _poller = poller;
    }

    function onScanResults(scanResults as BluetoothLowEnergy.Iterator) as Void {
        _poller.onScanResults(scanResults);
    }

    function onConnectedStateChanged(device as BluetoothLowEnergy.Device, state as BluetoothLowEnergy.ConnectionState) as Void {
        _poller.onConnectedStateChanged(device, state);
    }

    function onCharacteristicChanged(characteristic as BluetoothLowEnergy.Characteristic, value as ByteArray) as Void {
        _poller.onCharacteristicChanged(characteristic, value);
    }

    function onDescriptorWrite(descriptor as BluetoothLowEnergy.Descriptor, status as BluetoothLowEnergy.Status) as Void {
        _poller.onDescriptorWrite(descriptor, status);
    }

    function onCharacteristicWrite(characteristic as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status) as Void {
        _poller.onCharacteristicWrite(characteristic, status);
    }

    function onEncryptionStatus(device as BluetoothLowEnergy.Device, status as BluetoothLowEnergy.Status) as Void {
        _poller.onEncryptionStatus(device, status);
    }
}