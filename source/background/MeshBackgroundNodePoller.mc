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
    private static const CMD_SYNC_NEXT_MESSAGE as Number = 10;
    private static const RESP_CODE_ERR as Number = 1;
    private static const RESP_CODE_CONTACT_MSG as Number = 7;
    private static const RESP_CODE_CHANNEL_MSG as Number = 8;
    private static const RESP_CODE_NO_MORE_MESSAGES as Number = 10;
    private static const RESP_CODE_CONTACT_MSG_V3 as Number = 16;
    private static const RESP_CODE_CHANNEL_MSG_V3 as Number = 17;
    private static const PUSH_CODE_MSG_WAITING as Number = 0x83;

    private var _owner as MeshBackgroundDelegate;
    private var _delegate as MeshBackgroundBleDelegate;
    private var _serviceUuid as BluetoothLowEnergy.Uuid;
    private var _rxUuid as BluetoothLowEnergy.Uuid;
    private var _txUuid as BluetoothLowEnergy.Uuid;
    private var _rxCharacteristic as BluetoothLowEnergy.Characteristic? = null;
    private var _fragmentBuffer as ByteArray? = null;
    private var _deadlineAt as Number = 0;
    private var _finished as Boolean = false;
    private var _isScanning as Boolean = false;
    private var _connectedToNode as Boolean = false;
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
            connectBondedNode();
        } catch (e) {
            System.println("Background poll: BLE setup failed: " + e.getErrorMessage());
            finish();
        }
    }

    private function connectBondedNode() as Void {
        try {
            var bondedDevices = BluetoothLowEnergy.getBondedDevices();
            var bonded = bondedDevices.next();
            if (bonded == null) {
                System.println("Background poll: no bonded Mesh node available");
                finish();
                return;
            }
            if (BluetoothLowEnergy.pairDevice(bonded as BluetoothLowEnergy.ScanResult) == null) {
                System.println("Background poll: bonded-node connection was not started");
                finish();
                return;
            }
            System.println("Background poll: connecting bonded Mesh node");
        } catch (e) {
            System.println("Background poll: bonded-node connection failed: " + e.getErrorMessage());
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
                if (BluetoothLowEnergy.pairDevice(scanResult) == null) {
                    System.println("Background poll: node connection was not started");
                    finish();
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
        if (_finished || state != BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            return;
        }
        stopScan();
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
            var txCharacteristic = service.getCharacteristic(_txUuid);
            if (_rxCharacteristic == null || txCharacteristic == null) {
                System.println("Background poll: NUS characteristics unavailable");
                finish();
                return;
            }
            var cccd = txCharacteristic.getDescriptor(BluetoothLowEnergy.cccdUuid());
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
        if (status != BluetoothLowEnergy.STATUS_SUCCESS) {
            System.println("Background poll: notification subscription failed: " + status);
            finish();
            return;
        }
        _connectedToNode = true;
        requestNextMessage();
    }

    public function onCharacteristicWrite(characteristic as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status) as Void {
        if (!_finished && status != BluetoothLowEnergy.STATUS_SUCCESS) {
            System.println("Background poll: inbox request write failed: " + status);
            finish();
        }
    }

    public function onEncryptionStatus(device as BluetoothLowEnergy.Device, status as BluetoothLowEnergy.Status) as Void {
        if (!_finished && status != BluetoothLowEnergy.STATUS_SUCCESS) {
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
            _rxCharacteristic.requestWrite([CMD_SYNC_NEXT_MESSAGE]b, { :writeType => BluetoothLowEnergy.WRITE_TYPE_DEFAULT });
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
            (_fragmentBuffer as ByteArray).addAll(value);
            if (value.size() < 20) {
                finishFragment();
            }
            return;
        }
        if (value.size() == 20 && isMessageFrame(value[0] as Number)) {
            _fragmentBuffer = []b;
            (_fragmentBuffer as ByteArray).addAll(value);
            return;
        }
        processFrame(value);
    }

    private function isMessageFrame(code as Number) as Boolean {
         return code == RESP_CODE_CONTACT_MSG ||
             code == RESP_CODE_CHANNEL_MSG ||
             code == RESP_CODE_CONTACT_MSG_V3 ||
             code == RESP_CODE_CHANNEL_MSG_V3;
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
        if (code == RESP_CODE_NO_MORE_MESSAGES || code == RESP_CODE_ERR) {
            finish();
            return;
        }
        if (code == RESP_CODE_CONTACT_MSG || code == RESP_CODE_CONTACT_MSG_V3) {
            storeDirectMessage(value);
            requestFollowingMessage();
            return;
        }
        if (code == RESP_CODE_CHANNEL_MSG || code == RESP_CODE_CHANNEL_MSG_V3) {
            storeChannelMessage(value);
            requestFollowingMessage();
            return;
        }
        if (code == PUSH_CODE_MSG_WAITING) {
            requestNextMessage();
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
        var offset = (value[0] == RESP_CODE_CHANNEL_MSG_V3) ? 4 : 1;
        var textOffset = offset + 7;
        if (value.size() <= textOffset) {
            return;
        }
        var text = decodeText(value, textOffset);
        if (text == null || text.length() == 0) {
            return;
        }
        var channelIndex = value[offset] as Number;
        var channelName = resolveChannelName(channelIndex);
        var sender = "Mesh";
        var message = text;
        var separator = text.find(": ");
        if (separator != null && separator > 0) {
            sender = text.substring(0, separator);
            message = text.substring(separator + 2, text.length());
        }
        storeMessage("CH_" + channelIndex.format("%d"), sender, message, channelName + ": " + sender);
    }

    private function storeDirectMessage(value as ByteArray) as Void {
        var pubkeyOffset = (value[0] == RESP_CODE_CONTACT_MSG_V3) ? 4 : 1;
        var textOffset = pubkeyOffset + 12;
        if (value.size() <= textOffset) {
            return;
        }
        var senderId = "";
        for (var index = pubkeyOffset; index < pubkeyOffset + 6; index++) {
            senderId += (value[index] & 0xFF).format("%02X");
        }
        var sender = resolveContactName(senderId);
        var text = decodeText(value, textOffset);
        if (text != null && text.length() > 0) {
            storeMessage("CT_" + senderId, sender, text, "@" + sender);
        }
    }

    private function resolveChannelName(channelIndex as Number) as String {
        var channelId = channelIndex.format("%d");
        try {
            var stored = Storage.getValue("cfg_bg_channel_name_" + channelId);
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
            var stored = Storage.getValue("cfg_bg_contact_name_" + senderId);
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

    private function decodeText(value as ByteArray, offset as Number) as String? {
        var textBytes = [] as Array<Number>;
        for (var index = offset; index < value.size(); index++) {
            textBytes.add(value[index]);
        }
        try {
            return StringUtil.utf8ArrayToString(textBytes);
        } catch (e) {
            System.println("Background poll: invalid message text");
            return null;
        }
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

    private function finish() as Void {
        if (_finished) {
            return;
        }
        _finished = true;
        stopScan();
        _owner.onPollComplete(_messageCount, _lastSender, _lastMessage, _lastNotificationTitle, _connectedToNode, _targetIds);
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