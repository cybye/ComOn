import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;
import Toybox.StringUtil;
import Toybox.Application.Storage;
import Toybox.WatchUi;
import Toybox.Timer;

class MeshBleManager {
    public var nusServiceUuid as BluetoothLowEnergy.Uuid?;
    public var nusRxUuid      as BluetoothLowEnergy.Uuid?;
    public var nusTxUuid      as BluetoothLowEnergy.Uuid?;

    public var isConnected as Boolean = false;
    public var isScanning as Boolean = false;
    public var isSimulated as Boolean = false;
    public var isSyncing as Boolean = false;
    public var deviceName as String = "Mesh Node";
    public var lastReceivedMessage as String = "";
    public var lastSender as String = "Mesh";
    public var onMessageCallback as (Method(sender as String, text as String, tid as String) as Void)? = null;

    // Virtual Node Twin
    public var virtualNode as VirtualMeshNode;

    // Signal & Network Quality Metrics
    public var loraRssi as Number? = null; // in dBm
    public var loraSnr as Number? = null;  // in dB
    public var peerCount as Number = 0;    // Connected companion nodes
    public var nodeBatteryPercent as Number? = null;
    public var nodeBatteryMv as Number? = null;

    // Staged Sync State Machine & Spool Queue
    private var _syncStage as Number = 0; // 0=Idle, 1=Battery, 2=Time, 3=RadioStats, 4=Channels, 5=Contacts, 6=Inbox
    private var _channelSyncIdx as Number = 0;
    private var _syncedMessagesCount as Number = 0;
    private var _isFullSync as Boolean = false;
    private var _isFastSync as Boolean = false;
    private var _spoolQueue as Array<Dictionary> = [] as Array<Dictionary>;
    private var _pauseScanUntil as Number = 0;
    private var _syncTimeoutTimer as Timer.Timer? = null;
    private var _inboxPollTimeoutTimer as Timer.Timer? = null;
    private var _telemetryPollTimer as Timer.Timer? = null;
    private var _scanTimeoutTimer as Timer.Timer? = null;
    private var _reconnectTimer as Timer.Timer? = null;
    private var _pairResetTimer as Timer.Timer? = null;
    private var _pairTimeoutTimer as Timer.Timer? = null;
    private var _rxFragmentTimer as Timer.Timer? = null;
    private var _rxFragmentBuffer as ByteArray? = null;
    private var _isPairing as Boolean = false;
    private var _isResettingPairing as Boolean = false;
    private var _pairResetAttempts as Number = 0;
    private var _resumeScanAfterUi as Boolean = false;
    private var _scanResultLogCount as Number = 0;
    private var _ignoredFragmentLogCount as Number = 0;
    private var _notificationsReady as Boolean = false;
    private var _isInboxPolling as Boolean = false;
    private var _inboxPollCount as Number = 0;
    private static const MAX_INBOX_POLL_MESSAGES as Number = 5;
    private var _txQueue as Array<ByteArray> = [] as Array<ByteArray>;
    private var _isWriting as Boolean = false;
    private var _txTimeoutTimer as Timer.Timer? = null;
    private var _cccdRetryTimer as Timer.Timer? = null;
    private var _cccdRetryCount as Number = 0;

    private var _isDataField as Boolean = false;

    public function setIsDataField(val as Boolean) as Void {
        _isDataField = val;
    }

    public function isDataField() as Boolean {
        return _isDataField;
    }

    //! Safe Timer constructor: DataField apps do not have permission for Toybox.Timer
    private function safeTimer() as Timer.Timer? {
        if (_isDataField) {
            return null;
        }
        var app = Application.getApp();
        if (app != null && (app has :getSettingsView)) {
            _isDataField = true;
            return null;
        }
        try {
            return new Timer.Timer();
        } catch (e) {
            return null;
        }
    }

    public function forceFullSync() as Void {
        _isFullSync = true;
        ContactManager.resetForFullNodeSync();
        if (isConnected) {
            startSessionSync();
        } else if (!isSimulated) {
            connectLatestOrScan();
        }
    }

    private var _device as BluetoothLowEnergy.Device?;
    private var _rxCharacteristic as BluetoothLowEnergy.Characteristic?;
    private var _txCharacteristic as BluetoothLowEnergy.Characteristic?;

    public function getDevice() as BluetoothLowEnergy.Device? {
        return _device;
    }

    function initialize() {
        var app = Application.getApp();
        if (app != null && (app has :getSettingsView)) {
            _isDataField = true;
        }
        virtualNode    = VirtualMeshNode.getInstance();
        nusServiceUuid = BluetoothLowEnergy.stringToUuid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
        nusRxUuid      = BluetoothLowEnergy.stringToUuid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
        nusTxUuid      = BluetoothLowEnergy.stringToUuid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

        virtualNode.setNotifyCallback(method(:onVirtualNotify));

        if (!_isDataField) {
            try {
                var cachedPct = Storage.getValue("cached_node_battery_percent");
                if (cachedPct instanceof Number) {
                    nodeBatteryPercent = cachedPct as Number;
                }
                var cachedMv = Storage.getValue("cached_node_battery_mv");
                if (cachedMv instanceof Number) {
                    nodeBatteryMv = cachedMv as Number;
                }
            } catch (e) {
                // ignore
            }
        }
    }

    public function onVirtualNotify(bytes as Array<Number>) as Void {
        var payload = []b;
        payload.addAll(bytes);
        procCharacteristicChanged(null, payload);
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
            System.println("BLE profile registered");
        } catch (e) {
            System.println("BLE RegisterProfile notice: Profile already registered or limit reached");
        }
    }

    public function startScan() as Void {
        if (isSimulated) {
            return;
        }
        var now = Time.now().value();
        if (now < _pauseScanUntil) {
            System.println("BLE scan paused for " + (_pauseScanUntil - now) + "s (Freigabe aktiv)");
            return;
        }
        if (!isScanning && !isConnected && !_isPairing && !_isResettingPairing) {
            isScanning = true;
            _scanResultLogCount = 0;
            try {
                BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
                if (_scanTimeoutTimer == null) {
                    _scanTimeoutTimer = safeTimer();
                }
                if (_scanTimeoutTimer != null) {
                    _scanTimeoutTimer.start(method(:onScanTimeout), 15000, false);
                }
                System.println("BLE scan started");
            } catch (e) {
                System.println("setScanState notice: " + e.getErrorMessage());
                isScanning = false;
            }
        }
    }

    public function onScanTimeout() as Void {
        if (isScanning && !isConnected) {
            System.println("BLE scan timeout after 15s -> stopping scan");
            stopScan();
            scheduleReconnect(2000);
        }
    }

    public function resumeScan() as Void {
        _pauseScanUntil = 0;
        connectLatestOrScan();
    }

    public function suspendDiscoveryForUi() as Void {
        _resumeScanAfterUi = isScanning || (!isConnected && !_isPairing && !_isResettingPairing);
        if (isScanning) {
            System.println("BLE scan suspended for UI");
            stopScan();
        }
    }

    public function isPairingInProgress() as Boolean {
        return _isPairing;
    }

    public function resumeDiscoveryAfterUi() as Void {
        if (!_resumeScanAfterUi) {
            return;
        }
        _resumeScanAfterUi = false;
        System.println("BLE scan resuming after UI");
        scheduleReconnect(300);
    }

    public function connectLatestOrScan() as Void {
        if (isSimulated || isConnected || isScanning) {
            return;
        }
        try {
            var pairedDevices = BluetoothLowEnergy.getPairedDevices();
            var paired = pairedDevices.next();
            if (paired != null) {
                var device = paired as BluetoothLowEnergy.Device;
                if (device.isConnected()) {
                    System.println("BLE adopting connected paired node");
                    procConnectedStateChanged(device, BluetoothLowEnergy.CONNECTION_STATE_CONNECTED);
                    return;
                }
            }
        } catch (e) {
            System.println("BLE paired-device lookup notice: " + e.getErrorMessage());
        }

        System.println("BLE starting scan for MeshCore node");
        startScan();
    }


    private function scheduleReconnect(delayMs as Number) as Void {
        if (_reconnectTimer == null) {
            _reconnectTimer = safeTimer();
        } else {
            _reconnectTimer.stop();
        }
        if (_reconnectTimer != null) {
            _reconnectTimer.start(method(:onReconnectTimer), delayMs, false);
        }
    }

    public function onReconnectTimer() as Void {
        _reconnectTimer = null;
        connectLatestOrScan();
    }

    private function cancelPairAttempt() as Void {
        if (_pairTimeoutTimer != null) {
            _pairTimeoutTimer.stop();
            _pairTimeoutTimer = null;
        }
        clearTxQueue();
        if (_device != null) {
            try {
                BluetoothLowEnergy.unpairDevice(_device as BluetoothLowEnergy.Device);
            } catch (e) {
                System.println("BLE cancel pair notice: " + e.getErrorMessage());
            }
        }
        _device = null;
        _isPairing = false;
    }

    public function onPairTimeout() as Void {
        _pairTimeoutTimer = null;
        if (!_isPairing || isConnected) {
            return;
        }
        System.println("BLE pair timeout -> cancelling attempt & restarting scan");
        cancelPairAttempt();
        startScan();
    }

    private function resetStalePairing() as Void {
        _isResettingPairing = true;
        _isPairing = false;
        _pairResetAttempts = 0;
        stopScan();
        unpairAllDevices();
        schedulePairResetCheck();
    }

    private function unpairAllDevices() as Void {
        try {
            var pairedDevices = BluetoothLowEnergy.getPairedDevices();
            for (var paired = pairedDevices.next(); paired != null; paired = pairedDevices.next()) {
                BluetoothLowEnergy.unpairDevice(paired as BluetoothLowEnergy.Device);
            }
        } catch (e) {
            System.println("BLE unpair notice: " + e.getErrorMessage());
        }
    }

    private function schedulePairResetCheck() as Void {
        if (_pairResetTimer == null) {
            _pairResetTimer = safeTimer();
        } else {
            _pairResetTimer.stop();
        }
        if (_pairResetTimer != null) {
            _pairResetTimer.start(method(:onPairResetCheck), 1000, false);
        }
    }

    public function onPairResetCheck() as Void {
        _pairResetTimer = null;
        var hasPairedDevice = false;
        try {
            hasPairedDevice = BluetoothLowEnergy.getPairedDevices().next() != null;
        } catch (e) {
            System.println("BLE pair-reset check notice: " + e.getErrorMessage());
        }
        if (hasPairedDevice && _pairResetAttempts < 3) {
            _pairResetAttempts++;
            unpairAllDevices();
            schedulePairResetCheck();
            return;
        }
        _isResettingPairing = false;
        if (hasPairedDevice) {
            System.println("BLE stale pairing could not be cleared");
            return;
        }
        System.println("BLE stale pairing cleared -> scanning");
        startScan();
    }

    public function releaseNode(pauseSeconds as Number) as Void {
        _pauseScanUntil = Time.now().value() + pauseSeconds;
        stopScan();
        stopPeriodicTelemetryTimer();
        clearFragmentBuffer();
        clearTxQueue();
        _isPairing = false;
        _isResettingPairing = false;
        if (_reconnectTimer != null) {
            _reconnectTimer.stop();
            _reconnectTimer = null;
        }
        if (_pairResetTimer != null) {
            _pairResetTimer.stop();
            _pairResetTimer = null;
        }
        if (_pairTimeoutTimer != null) {
            _pairTimeoutTimer.stop();
            _pairTimeoutTimer = null;
        }
        if (_cccdRetryTimer != null) {
            _cccdRetryTimer.stop();
            _cccdRetryTimer = null;
        }
        _cccdRetryCount = 0;

        if (isSimulated) {
            simulateDisconnect();
        } else {
            if (_device != null) {
                try {
                    BluetoothLowEnergy.unpairDevice(_device);
                } catch (e) {
                    System.println("unpairDevice notice: " + e.getErrorMessage());
                }
            }
            isConnected = false;
            clearFragmentBuffer();
            isSyncing = false;
            _syncStage = 0;
            _device = null;
            _rxCharacteristic = null;
            _txCharacteristic = null;
            loraRssi = null;
            loraSnr = null;
            peerCount = 0;
        }

        if (WatchUi has :requestUpdate) {
            WatchUi.requestUpdate();
        }
    }

    public function stopScan() as Void {
        if (_scanTimeoutTimer != null) {
            _scanTimeoutTimer.stop();
            _scanTimeoutTimer = null;
        }
        if (isScanning) {
            isScanning = false;
            try {
                BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
            } catch (e) {
                System.println("setScanState off notice: " + e.getErrorMessage());
            }
        }
    }

    public function procScanResults(scanResults as BluetoothLowEnergy.Iterator) as Void {
        if (isConnected || !isScanning) {
            stopScan();
            return;
        }
        try {
            for (var result = scanResults.next(); result != null; result = scanResults.next()) {
                var res = result as BluetoothLowEnergy.ScanResult;
                var name = res.getDeviceName();
                var matchedService = false;
                var iter = res.getServiceUuids();
                for (var u = iter.next(); u != null; u = iter.next()) {
                    if (nusServiceUuid != null && u.equals(nusServiceUuid)) {
                        matchedService = true;
                        stopScan();
                        _isPairing = true;
                        if (name != null) {
                            deviceName = name;
                        }
                        System.println("BLE MeshCore advertisement matched: " + ((name != null) ? name : "<unnamed>"));
                        try {
                            var dev = BluetoothLowEnergy.pairDevice(res);
                            if (dev != null) {
                                _device = dev;
                                System.println("BLE pairDevice started");
                                _pairTimeoutTimer = safeTimer();
                                if (_pairTimeoutTimer != null) {
                                    _pairTimeoutTimer.start(method(:onPairTimeout), 10000, false);
                                }
                            } else {
                                _isPairing = false;
                                System.println("BLE pairDevice returned null");
                                scheduleReconnect(1500);
                            }
                        } catch (e) {
                            System.println("BLE pairDevice notice: " + e.getErrorMessage());
                            _isPairing = false;
                            var pairedIter = BluetoothLowEnergy.getPairedDevices();
                            if (pairedIter != null) {
                                var p = pairedIter.next();
                                if (p != null) {
                                    _device = p as BluetoothLowEnergy.Device;
                                }
                            }
                            if (_device != null) {
                                procConnectedStateChanged(_device, BluetoothLowEnergy.CONNECTION_STATE_CONNECTED);
                            } else {
                                scheduleReconnect(2000);
                            }
                        }
                        return;
                    }
                }
                if (!matchedService && _scanResultLogCount < 8) {
                    _scanResultLogCount++;
                    System.println("BLE advertisement ignored: " + ((name != null) ? name : "<unnamed>") + " (NUS UUID absent)");
                }
            }
        } catch (outerEx) {
            System.println("procScanResults outer notice: " + outerEx.getErrorMessage());
        }
    }

    public function procConnectedStateChanged(device as BluetoothLowEnergy.Device?, state as BluetoothLowEnergy.ConnectionState) as Void {
        try {
            System.println("BLE onConnectedStateChanged: state=" + state + " (0=disconnected, 1=connected)");
            if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
                if (device == null) {
                    System.println("BLE onConnectedStateChanged: connected device is null, ignoring");
                    return;
                }
                _isPairing = false;
                _isResettingPairing = false;
                if (_pairTimeoutTimer != null) {
                    _pairTimeoutTimer.stop();
                    _pairTimeoutTimer = null;
                }
                if (_reconnectTimer != null) {
                    _reconnectTimer.stop();
                    _reconnectTimer = null;
                }
                isConnected = true;
                _ignoredFragmentLogCount = 0;
                stopScan();
                _device = device;
                _notificationsReady = false;
                setupCharacteristics(device);
                if (!isConnected) {
                    if (WatchUi has :requestUpdate) {
                        WatchUi.requestUpdate();
                    }
                    return;
                }
                // Node-Binding: Check if node changed
                var nodeChanged = ContactManager.checkNodeBinding(deviceName);
                if (nodeChanged) {
                    _isFullSync = true;
                }

                if (_notificationsReady) {
                    startSessionSync();
                }
            } else {
                if (_syncTimeoutTimer != null) {
                    _syncTimeoutTimer.stop();
                    _syncTimeoutTimer = null;
                }
                stopPeriodicTelemetryTimer();
                clearTxQueue();
                if (_cccdRetryTimer != null) {
                    _cccdRetryTimer.stop();
                    _cccdRetryTimer = null;
                }
                _cccdRetryCount = 0;
                isConnected = false;
                _isPairing = false;
                isSyncing = false;
                finishInboxPoll();
                _notificationsReady = false;
                _syncStage = 0;
                _device = null;
                _rxCharacteristic = null;
                _txCharacteristic = null;
                loraRssi = null;
                loraSnr = null;
                peerCount = 0;
                if (!isSimulated && !_isResettingPairing && Time.now().value() >= _pauseScanUntil) {
                    scheduleReconnect(750);
                }
            }

            if (WatchUi has :requestUpdate) {
                WatchUi.requestUpdate();
            }
        } catch (ex) {
            System.println("BLE procConnectedStateChanged notice: " + ex.getErrorMessage());
        }
    }

    private function clearFragmentBuffer() as Void {
        if (_rxFragmentTimer != null) {
            _rxFragmentTimer.stop();
            _rxFragmentTimer = null;
        }
        _rxFragmentBuffer = null;
    }

    public function procEncryptionStatus(device as BluetoothLowEnergy.Device, status as BluetoothLowEnergy.Status) as Void {
        System.println("BLE encryption status=" + status);
    }

    //! Start the staged session sync using the current MeshCore companion protocol.
    public function startSessionSync() as Void {
        if (!isConnected || !_notificationsReady || isSyncing) {
            return;
        }
        isSyncing = true;
        _syncedMessagesCount = 0;
        _channelSyncIdx = 0;

        var requiresFullSync = _isFullSync || ContactManager.getLastContactSyncTime() == 0;
        _isFastSync = !requiresFullSync;
        if (requiresFullSync) {
            _isFullSync = true;
            ContactManager.startFullSync();
            _syncStage = 1;
            System.println("BLE starting full session sync (stage 1: query battery)");
        } else {
            // Cached metadata is still valid. Fetch battery, then pull messages without
            // waiting for the full channel/contact exchange.
            _syncStage = 1;
            System.println("BLE starting fast session sync: battery and inbox messages");
        }

        if (_syncTimeoutTimer == null) {
            _syncTimeoutTimer = safeTimer();
        }
        if (_syncTimeoutTimer != null) {
            _syncTimeoutTimer.start(method(:onSyncTimeout), requiresFullSync ? 15000 : 8000, false);
        }
        sendRaw(MeshProtocol.encodeGetBattery());
        if (WatchUi has :requestUpdate) {
            WatchUi.requestUpdate();
        }
    }

    public function onSyncTimeout() as Void {
        if (isSyncing) {
            System.println("BLE Sync timeout: Node did not complete all stages within 15s -> finalizing sync");
            finishSessionSync();
        }
    }

    //! Pull a small inbox batch without starting the full contacts/channel sync.
    public function pollInboxMessages() as Void {
        if (_isDataField || !isConnected || (!_notificationsReady && !isSimulated) || isSyncing || _isInboxPolling) {
            return;
        }
        _isInboxPolling = true;
        _inboxPollCount = 0;
        if (_inboxPollTimeoutTimer == null) {
            _inboxPollTimeoutTimer = safeTimer();
        } else {
            _inboxPollTimeoutTimer.stop();
        }
        if (_inboxPollTimeoutTimer != null) {
            _inboxPollTimeoutTimer.start(method(:onInboxPollTimeout), 5000, false);
        }
        System.println("BLE inbox poll: requesting pending messages");
        if (!sendRaw(MeshProtocol.encodeSyncNextMessage())) {
            finishInboxPoll();
        }
    }

    public function onInboxPollTimeout() as Void {
        if (_isInboxPolling) {
            System.println("BLE inbox poll: timed out");
            finishInboxPoll();
        }
    }

    private function finishInboxPoll() as Void {
        _isInboxPolling = false;
        _inboxPollCount = 0;
        if (_inboxPollTimeoutTimer != null) {
            _inboxPollTimeoutTimer.stop();
            _inboxPollTimeoutTimer = null;
        }
    }

    private function setupCharacteristics(device as BluetoothLowEnergy.Device?) as Void {
        if (device == null) {
            System.println("BLE setupCharacteristics: device is null");
            return;
        }
        if (!(device has :getService)) {
            System.println("BLE setupCharacteristics: device does not support getService");
            return;
        }
        if (nusServiceUuid == null || nusRxUuid == null || nusTxUuid == null) {
            return;
        }
        try {
            var service = device.getService(nusServiceUuid as BluetoothLowEnergy.Uuid);
            if (service != null && (service has :getCharacteristic)) {
                _rxCharacteristic = service.getCharacteristic(nusRxUuid as BluetoothLowEnergy.Uuid);
                _txCharacteristic = service.getCharacteristic(nusTxUuid as BluetoothLowEnergy.Uuid);
                System.println("BLE setupCharacteristics: rx=" + (_rxCharacteristic != null) + " tx=" + (_txCharacteristic != null));
                _cccdRetryCount = 0;
                requestCccdWrite();
            } else {
                System.println("BLE setupCharacteristics: NUS service not found on device");
            }
        } catch (e) {
            _rxCharacteristic = null;
            _txCharacteristic = null;
            _notificationsReady = false;
            isConnected = false;
            System.println("BLE characteristic discovery failed: " + e.getErrorMessage());
            scheduleReconnect(1000);
        }
    }

    public function requestCccdDelayed(delayMs as Number) as Void {
        if (_cccdRetryTimer != null) {
            _cccdRetryTimer.stop();
        } else {
            _cccdRetryTimer = safeTimer();
        }
        if (_cccdRetryTimer != null) {
            _cccdRetryTimer.start(method(:onCccdTimerFire), delayMs, false);
        }
    }

    public function onCccdTimerFire() as Void {
        _cccdRetryTimer = null;
        requestCccdWrite();
    }

    public function requestCccdWrite() as Boolean {
        if (!isConnected || _txCharacteristic == null) {
            return false;
        }
        try {
            if (_txCharacteristic has :getDescriptor) {
                var cccd = _txCharacteristic.getDescriptor(BluetoothLowEnergy.cccdUuid());
                if (cccd != null && (cccd has :requestWrite)) {
                    var enableNotification = [0x01, 0x00]b;
                    cccd.requestWrite(enableNotification);
                    System.println("BLE CCCD notification write requested (attempt=" + (_cccdRetryCount + 1) + ")");
                    return true;
                }
            }
        } catch (e) {
            System.println("BLE CCCD requestWrite exception: " + e.getErrorMessage());
        }
        return false;
    }

    public function procCharacteristicChanged(characteristic as BluetoothLowEnergy.Characteristic?, value as ByteArray) as Void {
        if (value == null || value.size() == 0) {
            return;
        }

        if (_rxFragmentBuffer != null) {
            (_rxFragmentBuffer as ByteArray).addAll(value);
            if (value.size() < 20) {
                finishFragmentedFrame();
            } else {
                scheduleFragmentTimeout();
            }
            return;
        }

        var firstByte = value[0] as Number;
        if (value.size() == 20 && isFragmentablePacket(firstByte)) {
            _rxFragmentBuffer = []b;
            (_rxFragmentBuffer as ByteArray).addAll(value);
            scheduleFragmentTimeout();
            return;
        }

        processCharacteristicFrame(value);
    }

    private function isFragmentablePacket(packetType as Number) as Boolean {
        return packetType == MeshProtocol.RESP_CODE_CONTACT_MSG ||
               packetType == MeshProtocol.RESP_CODE_CHANNEL_MSG ||
               packetType == MeshProtocol.RESP_CODE_CONTACT_MSG_V3 ||
               packetType == MeshProtocol.RESP_CODE_CHANNEL_MSG_V3 ||
               packetType == MeshProtocol.RESP_CODE_CONTACT ||
               packetType == MeshProtocol.RESP_CODE_CHANNEL_INFO ||
               packetType >= 0x80;
    }

    private function scheduleFragmentTimeout() as Void {
        if (_rxFragmentTimer == null) {
            _rxFragmentTimer = safeTimer();
        } else {
            _rxFragmentTimer.stop();
        }
        if (_rxFragmentTimer != null) {
            _rxFragmentTimer.start(method(:onFragmentTimeout), 120, false);
        }
    }

    public function onFragmentTimeout() as Void {
        _rxFragmentTimer = null;
        finishFragmentedFrame();
    }

    private function finishFragmentedFrame() as Void {
        if (_rxFragmentTimer != null) {
            _rxFragmentTimer.stop();
            _rxFragmentTimer = null;
        }
        var completeFrame = _rxFragmentBuffer;
        _rxFragmentBuffer = null;
        if (completeFrame != null) {
            System.println("BLE reassembled frame: first=" + completeFrame[0] + " size=" + completeFrame.size());
            processCharacteristicFrame(completeFrame as ByteArray);
        }
    }

    private function processCharacteristicFrame(value as ByteArray) as Void {
        var firstByte = value[0] as Number;

        // 1. Battery & Storage response (Stage 1 or periodic/manual query)
        if (firstByte == MeshProtocol.RESP_CODE_BATT_AND_STORAGE) {
            parseBattery(value);
            if (_syncStage == 1) {
                if (_isFastSync) {
                    _syncStage = 3;
                    System.println("BLE fast session sync stage 3: radio stats query");
                    sendRaw(MeshProtocol.encodeGetStats(MeshProtocol.STATS_TYPE_RADIO));
                } else {
                    _syncStage = 2;
                    System.println("BLE session sync stage 2: set device time");
                    sendRaw(MeshProtocol.encodeSetDeviceTime(Time.now().value()));
                }
            } else if (_syncStage == 0 && isConnected) {
                // Periodic 60s poll: chain radio stats query immediately
                sendRaw(MeshProtocol.encodeGetStats(MeshProtocol.STATS_TYPE_RADIO));
            }
            return;
        }

        // 2. Stage 1 error fallback (if node doesn't support battery query)
        if (_syncStage == 1 && firstByte == MeshProtocol.RESP_CODE_ERR) {
            if (_isFastSync) {
                _syncStage = 3;
                System.println("BLE fast session sync: battery unavailable, querying radio stats");
                sendRaw(MeshProtocol.encodeGetStats(MeshProtocol.STATS_TYPE_RADIO));
            } else {
                System.println("BLE battery query returned err -> falling back to device time");
                _syncStage = 2;
                sendRaw(MeshProtocol.encodeSetDeviceTime(Time.now().value()));
            }
            return;
        }

        // 3. Stage 2 response (device time set OK or ERR -> advance to stage 3 radio stats)
        if (_syncStage == 2 && (firstByte == MeshProtocol.RESP_CODE_OK || firstByte == MeshProtocol.RESP_CODE_ERR)) {
            _syncStage = 3;
            System.println("BLE session sync stage 3: radio stats query");
            sendRaw(MeshProtocol.encodeGetStats(MeshProtocol.STATS_TYPE_RADIO));
            return;
        }

        // 4. Device Stats response (Radio stats or Core stats)
        if (firstByte == MeshProtocol.RESP_CODE_STATS) {
            if (value.size() >= 2 && value[1] == MeshProtocol.STATS_TYPE_RADIO) {
                parseRadioStats(value);
            } else if (value.size() >= 4 && value[1] == MeshProtocol.STATS_TYPE_CORE) {
                parseCoreStats(value);
            }
            if (_syncStage == 3) {
                if (_isFastSync) {
                    if (_isDataField) {
                        System.println("BLE DataField fast sync complete (skipping inbox messages)");
                        finishSessionSync();
                    } else {
                        _syncStage = 6;
                        System.println("BLE fast session sync stage 6: inbox messages");
                        sendRaw(MeshProtocol.encodeSyncNextMessage());
                    }
                } else {
                    _syncStage = 4;
                    _channelSyncIdx = 0;
                    System.println("BLE session sync stage 4: query channels (0..7)");
                    sendRaw(MeshProtocol.encodeGetChannel(0));
                }
            } else if (_syncStage == 0 && isConnected) {
                // Periodic poll: also check inbox messages (watch app only)
                if (!_isDataField) {
                    pollInboxMessages();
                }
            }
            return;
        }

        // 5. Stage 3 error fallback (if radio stats query returned error)
        if (_syncStage == 3 && firstByte == MeshProtocol.RESP_CODE_ERR) {
            if (_isFastSync) {
                if (_isDataField) {
                    finishSessionSync();
                } else {
                    _syncStage = 6;
                    System.println("BLE radio stats query returned err -> continuing fast sync stage 6 (inbox)");
                    sendRaw(MeshProtocol.encodeSyncNextMessage());
                }
            } else {
                _syncStage = 4;
                _channelSyncIdx = 0;
                System.println("BLE radio stats query returned err -> continuing to stage 4 (channels)");
                sendRaw(MeshProtocol.encodeGetChannel(0));
            }
            return;
        }

        // 6. Stage 4: Channels query responses
        if (_syncStage == 4) {
            if (firstByte == MeshProtocol.RESP_CODE_CHANNEL_INFO) {
                parseBinaryChannel(value);
                _channelSyncIdx++;
                if (_channelSyncIdx < 8) {
                    sendRaw(MeshProtocol.encodeGetChannel(_channelSyncIdx));
                } else {
                    advanceToContactsStage();
                }
                return;
            } else if (firstByte == MeshProtocol.RESP_CODE_ERR || firstByte == MeshProtocol.RESP_CODE_OK) {
                // Empty channel slot or error -> advance to next channel slot
                _channelSyncIdx++;
                if (_channelSyncIdx < 8) {
                    sendRaw(MeshProtocol.encodeGetChannel(_channelSyncIdx));
                } else {
                    advanceToContactsStage();
                }
                return;
            }
        }

        // 7. Stage 5: Contacts query responses
        if (_syncStage == 5) {
            if (firstByte == MeshProtocol.RESP_CODE_CONTACTS_START) {
                System.println("BLE contacts stream start");
                return;
            } else if (firstByte == MeshProtocol.RESP_CODE_CONTACT) {
                parseBinaryContact(value);
                return;
            } else if (firstByte == MeshProtocol.RESP_CODE_END_OF_CONTACTS || firstByte == MeshProtocol.RESP_CODE_ERR) {
                ContactManager.setLastContactSyncTime(Time.now().value());
                if (_isDataField) {
                    System.println("BLE DataField full sync complete (" + ContactManager.getContacts().size() + " contacts) -> skipping inbox");
                    finishSessionSync();
                    return;
                }
                System.println("BLE contacts sync complete (" + ContactManager.getContacts().size() + " contacts) -> stage 6: inbox messages");
                _syncStage = 6;
                sendRaw(MeshProtocol.encodeSyncNextMessage());
                return;
            }
        }

        // 8. Stage 6: Message inbox sync
        if (_syncStage == 6 && (firstByte == MeshProtocol.RESP_CODE_CONTACT_MSG || firstByte == MeshProtocol.RESP_CODE_CHANNEL_MSG || firstByte == MeshProtocol.RESP_CODE_CONTACT_MSG_V3 || firstByte == MeshProtocol.RESP_CODE_CHANNEL_MSG_V3)) {
            _syncedMessagesCount++;
            if (firstByte == MeshProtocol.RESP_CODE_CHANNEL_MSG || firstByte == MeshProtocol.RESP_CODE_CHANNEL_MSG_V3) {
                parseChannelMessage(value, false);
            } else if (firstByte == MeshProtocol.RESP_CODE_CONTACT_MSG || firstByte == MeshProtocol.RESP_CODE_CONTACT_MSG_V3) {
                parseDirectMessage(value, false);
            }
            sendRaw(MeshProtocol.encodeSyncNextMessage());
            return;
        }

        // 9. Stage 6: Message inbox complete (RESP_CODE_NO_MORE_MESSAGES = 10 OR RESP_CODE_ERR = 1)
        if (_syncStage == 6 && (firstByte == MeshProtocol.RESP_CODE_NO_MORE_MESSAGES || firstByte == MeshProtocol.RESP_CODE_ERR)) {
            System.println("BLE session sync complete: " + _syncedMessagesCount + " messages synced");
            finishSessionSync();
            return;
        }

        // 10. Activity data field inbox polling: drain a bounded message batch.
        if (_isInboxPolling && (firstByte == MeshProtocol.RESP_CODE_CONTACT_MSG || firstByte == MeshProtocol.RESP_CODE_CHANNEL_MSG || firstByte == MeshProtocol.RESP_CODE_CONTACT_MSG_V3 || firstByte == MeshProtocol.RESP_CODE_CHANNEL_MSG_V3)) {
            _inboxPollCount++;
            if (firstByte == MeshProtocol.RESP_CODE_CHANNEL_MSG || firstByte == MeshProtocol.RESP_CODE_CHANNEL_MSG_V3) {
                parseChannelMessage(value, true);
            } else {
                parseDirectMessage(value, true);
            }
            if (_inboxPollCount < MAX_INBOX_POLL_MESSAGES) {
                sendRaw(MeshProtocol.encodeSyncNextMessage());
            } else {
                System.println("BLE inbox poll: reached batch limit");
                finishInboxPoll();
            }
            return;
        }
        if (_isInboxPolling && (firstByte == MeshProtocol.RESP_CODE_NO_MORE_MESSAGES || firstByte == MeshProtocol.RESP_CODE_ERR)) {
            System.println("BLE inbox poll: complete (" + _inboxPollCount + " messages)");
            finishInboxPoll();
            return;
        }

        // 11. General push & status codes
        if (firstByte == MeshProtocol.RESP_CODE_SENT) {
            System.println("BLE RESP_CODE_SENT (0x06): node accepted outgoing message");
            ChatHistoryManager.advanceOutgoingStatus(ChatHistoryManager.STATUS_QUEUED, ChatHistoryManager.STATUS_SENT_NODE);
            ChatHistoryManager.updateLastOutgoingStatus(ChatHistoryManager.STATUS_SENT_NODE);
            WatchUi.requestUpdate();
            return;
        }
        if (firstByte == MeshProtocol.RESP_CODE_ERR) {
            var errCode = (value.size() > 1) ? value[1] : 0;
            System.println("BLE RESP_CODE_ERR (0x01): node rejected command with err=" + errCode);
            if (WatchUi has :showToast) {
                var errStr = I18n.format(Rez.Strings.ErrSendRejected, [ errCode ]);
                if (errCode == 2) {
                    errStr = I18n.get(Rez.Strings.ErrRecipientUnreachable);
                }
                WatchUi.showToast(errStr, null);
            }
            return;
        }
        if (firstByte == MeshProtocol.PUSH_CODE_MSG_WAITING) {
            // Radio signaled incoming message waiting in buffer -> pull it (Watch App only)
            if (!_isDataField) {
                sendRaw(MeshProtocol.encodeSyncNextMessage());
            }
            return;
        }

        // 11. Standard MeshCore asynchronous push notifications (Advert, PathUpdated, SendConfirmed, LogRxData)
        if (firstByte == 0x82 /* PushSendConfirmed */) {
            System.println("BLE PushSendConfirmed (0x82): message broadcast on LoRa mesh");
            if (!ChatHistoryManager.advanceOutgoingStatus(ChatHistoryManager.STATUS_SENT_NODE, ChatHistoryManager.STATUS_CONFIRMED_MESH)) {
                ChatHistoryManager.updateLastOutgoingStatus(ChatHistoryManager.STATUS_CONFIRMED_MESH);
            }
            WatchUi.requestUpdate();
            return;
        }
        if (firstByte == 0x80 /* PushAdvert */ || firstByte == 0x81 /* PushPathUpdated */ || firstByte == 0x88 /* PushLogRxData */) {
            return;
        }

        // 12. Live incoming channel / contact updates while idle (_syncStage == 0)
        if (firstByte == MeshProtocol.RESP_CODE_CHANNEL_INFO) {
            parseBinaryChannel(value);
            WatchUi.requestUpdate();
            return;
        }
        if (firstByte == MeshProtocol.RESP_CODE_CONTACT || firstByte == 0x8A /* PushNewAdvert */) {
            parseBinaryContact(value);
            peerCount = ContactManager.getContacts().size();
            WatchUi.requestUpdate();
            return;
        }

        // 13. Live incoming channel message while idle (_syncStage == 0)
        if (firstByte == MeshProtocol.RESP_CODE_CHANNEL_MSG || firstByte == MeshProtocol.RESP_CODE_CHANNEL_MSG_V3) {
            parseChannelMessage(value, true);
            return;
        }

        // 14. Live incoming direct message while idle (_syncStage == 0)
        // RESP_CODE_CONTACT_MSG (7): [code(1), pubkey_prefix(6), path_len(1), txt_type(1), timestamp(4), text...]
        // RESP_CODE_CONTACT_MSG_V3 (16): [code(1), snr(1), reserved(2), pubkey_prefix(6), path_len(1), txt_type(1), timestamp(4), text...]
        if (firstByte == MeshProtocol.RESP_CODE_CONTACT_MSG || firstByte == MeshProtocol.RESP_CODE_CONTACT_MSG_V3) {
            parseDirectMessage(value, true);
            return;
        }

        // 11. Unknown / unexpected frame logging
        if (_ignoredFragmentLogCount < 3) {
            _ignoredFragmentLogCount++;
            System.println("BLE ignored frame: first=" + firstByte + " size=" + value.size());
            if (_ignoredFragmentLogCount == 3) {
                System.println("BLE further frame logs suppressed");
            }
        }
    }

    private function parseChannelMessage(value as ByteArray, notify as Boolean) as Void {
        var isV3 = value[0] == MeshProtocol.RESP_CODE_CHANNEL_MSG_V3;
        var offset = isV3 ? 4 : 1;
        var textOffset = offset + 7;
        if (value.size() <= textOffset) {
            return;
        }

        var channelIndex = value[offset] as Number;
        if (isV3) {
            var snr = value[1] as Number;
            if (snr > 127) { snr -= 256; }
            loraSnr = (snr / 4).toNumber();
        }

        var textBytes = [] as Array<Number>;
        for (var index = textOffset; index < value.size(); index++) {
            textBytes.add(value[index]);
        }

        try {
            var text = StringUtil.utf8ArrayToString(textBytes);
            if (text == null || text.length() == 0) {
                return;
            }
            var sender = "Mesh";
            var messageText = text;
            var separator = text.find(": ");
            if (separator != null && separator > 0) {
                sender = text.substring(0, separator);
                messageText = text.substring(separator + 2, text.length());
            }
            var targetId = "CH_" + channelIndex;
            lastSender = sender;
            lastReceivedMessage = messageText;
            ChatHistoryManager.addIncomingMessage(targetId, sender, messageText);
            if (notify && onMessageCallback != null) {
                onMessageCallback.invoke(sender, messageText, targetId);
            }
            WatchUi.requestUpdate();
        } catch (e) {
            System.println("BLE channel message parse notice: " + e.getErrorMessage());
        }
    }

    //! Parse an incoming direct message frame (RESP_CODE_CONTACT_MSG = 7 or V3 = 16)
    //! Frame layout v1 (first=7):  [code(1), pubkey_prefix(6), path_len(1), txt_type(1), timestamp(4), text...]
    //! Frame layout v3 (first=16): [code(1), snr(1), reserved(2), pubkey_prefix(6), path_len(1), txt_type(1), timestamp(4), text...]
    private function parseDirectMessage(value as ByteArray, notify as Boolean) as Void {
        try {
            var isV3 = (value[0] == MeshProtocol.RESP_CODE_CONTACT_MSG_V3);
            // v1: pubkey starts at offset 1; v3: pubkey starts at offset 4 (after snr + 2 reserved)
            var pubkeyOffset = isV3 ? 4 : 1;
            var textOffset   = pubkeyOffset + 6 + 1 + 1 + 4; // pubkey(6) + path_len(1) + txt_type(1) + timestamp(4)

            if (value.size() <= textOffset) {
                System.println("BLE parseDirectMessage: frame too short (" + value.size() + " bytes), dropping");
                return;
            }

            // Update SNR from v3 header if present
            if (isV3) {
                var snr = value[1] as Number;
                if (snr > 127) { snr -= 256; }
                loraSnr = (snr / 4).toNumber();
            }

            // Build hex string of sender pubkey prefix (6 bytes)
            var senderHex = "";
            for (var k = pubkeyOffset; k < pubkeyOffset + 6 && k < value.size(); k++) {
                var b = value[k] & 0xFF;
                senderHex += b.format("%02X");
            }

            // Resolve sender name from ContactManager (case-insensitive prefix match)
            var sender = senderHex;
            var ct = ContactManager.getContactById(senderHex);
            if (ct != null) {
                var n = ct[:name];
                if (n != null && (n as String).length() > 0) {
                    sender = n as String;
                }
            }

            // Extract text bytes
            var textBytes = [] as Array<Number>;
            for (var i = textOffset; i < value.size(); i++) {
                textBytes.add(value[i]);
            }
            var text = StringUtil.utf8ArrayToString(textBytes);
            if (text == null || text.length() == 0) {
                System.println("BLE parseDirectMessage: empty text from " + senderHex);
                return;
            }

            // targetId: use sender's contact ID so the message lands in the right DM thread
            var targetId = "CT_" + senderHex;
            lastSender = sender;
            lastReceivedMessage = text;
            System.println("BLE parseDirectMessage: DM from " + sender + " (" + senderHex + "): " + text);
            ChatHistoryManager.addIncomingMessage(targetId, sender, text);
            if (notify && onMessageCallback != null) {
                onMessageCallback.invoke(sender, text, targetId);
            }
            WatchUi.requestUpdate();
        } catch (e) {
            System.println("BLE parseDirectMessage notice: " + e.getErrorMessage());
        }
    }

    public function startPeriodicTelemetryTimer() as Void {
        if (_telemetryPollTimer == null) {
            _telemetryPollTimer = safeTimer();
        } else {
            _telemetryPollTimer.stop();
        }
        if (_telemetryPollTimer != null) {
            _telemetryPollTimer.start(method(:onPeriodicTelemetryPoll), 60000, true);
            System.println("BLE: 60s periodic telemetry poll timer started");
        }
    }

    public function stopPeriodicTelemetryTimer() as Void {
        if (_telemetryPollTimer != null) {
            _telemetryPollTimer.stop();
            _telemetryPollTimer = null;
            System.println("BLE: periodic telemetry poll timer stopped");
        }
    }

    public function onPeriodicTelemetryPoll() as Void {
        if (isConnected && !isSyncing && _syncStage == 0) {
            System.println("BLE: Periodic 60s poll: querying battery & radio stats");
            sendRaw(MeshProtocol.encodeGetBattery());
        }
    }

    public function requestNodeBattery() as Void {
        if (isConnected) {
            sendRaw(MeshProtocol.encodeGetBattery());
        }
    }

    private function parseBattery(value as ByteArray) as Void {
        if (value.size() < 3) {
            return;
        }
        var mv = (value[1] as Number) | ((value[2] as Number) << 8);
        nodeBatteryMv = mv;
        var percent = 0;
        if (mv > 5000) {
            // 2S battery pack (6.6V - 8.4V)
            percent = (((mv - 6600) * 100) / 1800).toNumber();
        } else {
            // 1S LiPo pack (3.3V - 4.2V)
            percent = (((mv - 3300) * 100) / 900).toNumber();
        }
        if (percent < 0) { percent = 0; }
        if (percent > 100) { percent = 100; }
        nodeBatteryPercent = percent;
        System.println("Node battery: " + nodeBatteryMv + " mV (estimated " + nodeBatteryPercent + "%)");
        if (!_isDataField) {
            try {
                Storage.setValue("cached_node_battery_mv", mv);
                Storage.setValue("cached_node_battery_percent", percent);
                Storage.setValue("cached_node_battery_time", Time.now().value());
                if (percent > 20) {
                    Storage.deleteValue("cfg_bg_low_battery_notified");
                }
            } catch (e) {
                // ignore
            }
        }
        if (WatchUi has :requestUpdate) {
            WatchUi.requestUpdate();
        }
    }

    private function parseCoreStats(value as ByteArray) as Void {
        if (value.size() >= 4) {
            var mv = (value[2] as Number) | ((value[3] as Number) << 8);
            if (mv > 2000 && mv < 9000) {
                nodeBatteryMv = mv;
                var percent = 0;
                if (mv > 5000) {
                    percent = (((mv - 6600) * 100) / 1800).toNumber();
                } else {
                    percent = (((mv - 3300) * 100) / 900).toNumber();
                }
                if (percent < 0) { percent = 0; }
                if (percent > 100) { percent = 100; }
                nodeBatteryPercent = percent;
                System.println("Node battery (from core stats): " + nodeBatteryMv + " mV (" + nodeBatteryPercent + "%)");
                if (!_isDataField) {
                    try {
                        Storage.setValue("cached_node_battery_mv", mv);
                        Storage.setValue("cached_node_battery_percent", percent);
                        Storage.setValue("cached_node_battery_time", Time.now().value());
                        if (percent > 20) {
                            Storage.deleteValue("cfg_bg_low_battery_notified");
                        }
                    } catch (e) {
                        // ignore
                    }
                }
                if (WatchUi has :requestUpdate) {
                    WatchUi.requestUpdate();
                }
            }
        }
    }

    private function parseRadioStats(value as ByteArray) as Void {
        if (value.size() < 6 || value[1] != MeshProtocol.STATS_TYPE_RADIO) {
            return;
        }
        var rssi = value[4] as Number;
        var snr = value[5] as Number;
        if (rssi > 127) { rssi -= 256; }
        if (snr > 127) { snr -= 256; }
        loraRssi = rssi;
        loraSnr = (snr / 4).toNumber();
        System.println("Node radio stats: RSSI=" + loraRssi + " dBm SNR=" + loraSnr + " dB");
        if (WatchUi has :requestUpdate) {
            WatchUi.requestUpdate();
        }
    }

    private function advanceToContactsStage() as Void {
        _syncStage = 5;
        System.println("BLE session sync stage 5: query contacts");
        var since = (_isFullSync || ContactManager.getLastContactSyncTime() == 0) ? 0 : ContactManager.getLastContactSyncTime();
        sendRaw(MeshProtocol.encodeGetContactsSince(since));
    }

    private function parseBinaryChannel(value as ByteArray) as Void {
        try {
            if (value.size() >= 2) {
                var chIdx = value[1] as Number;
                var nameBytes = [] as Array<Number>;
                for (var i = 2; i < 34 && i < value.size() && value[i] != 0; i++) {
                    nameBytes.add(value[i]);
                }
                var nameStr = StringUtil.utf8ArrayToString(nameBytes);
                if (nameStr == null || nameStr.length() == 0) {
                    if (chIdx == 0) {
                        nameStr = "public";
                    } else {
                        return; // Empty channel slot
                    }
                }
                System.println("BLE parsed channel " + chIdx + ": " + nameStr);
                if (_isFullSync) {
                    ContactManager.addSyncChannel(chIdx, nameStr);
                } else {
                    ContactManager.addChannel(chIdx, nameStr);
                }
            }
        } catch (e) {
            System.println("parseBinaryChannel notice: " + e.getErrorMessage());
        }
    }

    private function parseBinaryContact(value as ByteArray) as Void {
        try {
            if (value.size() >= 132) {
                // Official MeshCore Hardware format (148 bytes total):
                // Byte 0: 0x03 (RESP_CODE_CONTACT)
                // Bytes 1..32: 32-byte Public Key
                // Bytes 33..99: adv_type, flags, out_path_len, out_path (64 bytes)
                // Bytes 100..131: adv_name (32 bytes null-terminated UTF-8)
                var idHex = "";
                for (var k = 1; k <= 6 && k < value.size(); k++) {
                    var b = value[k] & 0xFF;
                    idHex += b.format("%02X");
                }

                var advType = (value.size() > 33) ? (value[33] as Number) : 1;

                var nameBytes = [] as Array<Number>;
                for (var n = 100; n < 132 && n < value.size() && value[n] != 0; n++) {
                    nameBytes.add(value[n]);
                }
                var nameStr = StringUtil.utf8ArrayToString(nameBytes);
                if (nameStr == null || nameStr.length() == 0) {
                    nameStr = "Node " + idHex;
                }

                System.println("BLE parsed contact (HW): id=" + idHex + " name=" + nameStr + " advType=" + advType);
                if (_isFullSync) {
                    ContactManager.addSyncContact(idHex, nameStr, advType);
                } else {
                    ContactManager.addContact(idHex, nameStr, advType);
                }
            } else if (value.size() >= 4) {
                // Compact / Simulator format:
                // [3, idLen, idBytes..., nameLen, nameBytes...]
                var idLen = value[1] as Number;
                if (value.size() >= 2 + idLen + 1) {
                    var idBytes = [] as Array<Number>;
                    for (var i = 2; i < 2 + idLen; i++) { idBytes.add(value[i]); }
                    var idStr = StringUtil.utf8ArrayToString(idBytes);

                    var nameLenIdx = 2 + idLen;
                    var nameLen = value[nameLenIdx] as Number;
                    if (value.size() >= nameLenIdx + 1 + nameLen) {
                        var nameBytes2 = [] as Array<Number>;
                        for (var j = nameLenIdx + 1; j < nameLenIdx + 1 + nameLen; j++) { nameBytes2.add(value[j]); }
                        var nameStr2 = StringUtil.utf8ArrayToString(nameBytes2);
                        System.println("BLE parsed contact (compact): id=" + idStr + " name=" + nameStr2);
                        if (_isFullSync) {
                            ContactManager.addSyncContact(idStr, nameStr2, 1);
                        } else {
                            ContactManager.addContact(idStr, nameStr2, 1);
                        }
                    }
                }
            }
        } catch (e) {
            System.println("parseBinaryContact notice: " + e.getErrorMessage());
        }
    }

    private function finishSessionSync() as Void {
        if (_syncTimeoutTimer != null) {
            _syncTimeoutTimer.stop();
        }
        var refreshRadioStats = _isFastSync && isConnected;
        if (_isFullSync) {
            ContactManager.commitFullSync();
            _isFullSync = false;
        }
        _isFastSync = false;
        isSyncing = false;
        _syncStage = 0;
        flushSpoolQueue();
        peerCount = ContactManager.getContacts().size();
        startPeriodicTelemetryTimer();
        if (refreshRadioStats) {
            System.println("BLE fast session sync: requesting radio stats");
            sendRaw(MeshProtocol.encodeGetStats(MeshProtocol.STATS_TYPE_RADIO));
        }
        if (WatchUi has :showToast) {
            var msg = I18n.format(Rez.Strings.ToastSyncComplete, [ ContactManager.getContacts().size(), ContactManager.getChannels().size() ]);
            WatchUi.showToast(msg, null);
        }
        if (WatchUi has :requestUpdate) {
            WatchUi.requestUpdate();
        }
    }

    public function flushSpoolQueue() as Void {
        if (_spoolQueue.size() > 0 && isConnected) {
            var sentCount = _spoolQueue.size();
            for (var i = 0; i < _spoolQueue.size(); i++) {
                var item = _spoolQueue[i];
                var txt = item[:text] as String;
                var isCt = (item.hasKey(:isContact) && item[:isContact] != null) ? (item[:isContact] as Boolean) : false;
                var payload = null;
                if (isCt && item[:targetId] != null) {
                    payload = MeshProtocol.encodeContactMessage(item[:targetId] as String, txt);
                } else {
                    var ch = (item[:ch] != null) ? (item[:ch] as Number) : 0;
                    payload = MeshProtocol.encodeChannelMessage(ch, txt);
                }
                if (payload != null) {
                    sendRaw(payload);
                }
            }
            _spoolQueue = [] as Array<Dictionary>;
            if (WatchUi has :showToast) {
                WatchUi.showToast(I18n.format(Rez.Strings.ToastPendingSent, [ sentCount ]), null);
            }
        }
    }

    public function procCharacteristicWrite(characteristic as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status) as Void {
        if (_txTimeoutTimer != null) {
            _txTimeoutTimer.stop();
            _txTimeoutTimer = null;
        }
        if (status != BluetoothLowEnergy.STATUS_SUCCESS) {
            System.println("BLE Characteristic write failed with status: " + status);
            clearTxQueue();
        } else {
            _isWriting = false;
            sendNextTxChunk();
        }
    }

    public function procDescriptorWrite(descriptor as BluetoothLowEnergy.Descriptor, status as BluetoothLowEnergy.Status) as Void {
        if (status == BluetoothLowEnergy.STATUS_SUCCESS) {
            _notificationsReady = true;
            _cccdRetryCount = 0;
            System.println("BLE CCCD write successful");
            if (isConnected && isSyncing == false) {
                startSessionSync();
            }
        } else {
            _notificationsReady = false;
            System.println("BLE CCCD write failed with status: " + status);
            // Status 18: STATUS_GATT_INSUFFICIENT_AUTHENTICATION
            // Link encryption/bonding may still be establishing. Retry up to 3 times before giving up.
            if ((status == 18 || status == 19) && _cccdRetryCount < 3 && isConnected) {
                _cccdRetryCount++;
                var retryDelay = _cccdRetryCount * 350; // 350ms, 700ms, 1050ms
                System.println("BLE CCCD Status " + status + " (Insufficient Auth): retrying in " + retryDelay + "ms (retry " + _cccdRetryCount + "/3)");
                requestCccdDelayed(retryDelay);
            } else {
                System.println("BLE CCCD write failed permanently (status=" + status + ") - aborting session sync");
            }
        }
    }

    //! Send raw bytes over BLE NUS RX with 20-byte chunking and FIFO queueing
    //! Note: Garmin CIQ BLE does not support Long Writes (> 20 bytes). Frames exceeding 20 bytes
    //! must be segmented into <=20-byte chunks to prevent InvalidRequestException.
    public function sendRaw(bytes as ByteArray) as Boolean {
        if (isSimulated) {
            virtualNode.onRxData(bytes);
            return true;
        }
        if (!isConnected || _rxCharacteristic == null) {
            return false;
        }

        var total = bytes.size();
        if (total == 0) {
            return true;
        }

        var offset = 0;
        while (offset < total) {
            var chunkSize = total - offset;
            if (chunkSize > 20) {
                chunkSize = 20;
            }
            var chunk = []b;
            for (var c = 0; c < chunkSize; c++) {
                chunk.add(bytes[offset + c]);
            }
            _txQueue.add(chunk);
            offset += chunkSize;
        }

        if (!_isWriting) {
            sendNextTxChunk();
        }
        return true;
    }

    private function sendNextTxChunk() as Void {
        if (!isConnected || _rxCharacteristic == null) {
            clearTxQueue();
            return;
        }

        if (_txQueue.size() == 0) {
            _isWriting = false;
            if (_txTimeoutTimer != null) {
                _txTimeoutTimer.stop();
                _txTimeoutTimer = null;
            }
            return;
        }

        _isWriting = true;
        var frame = _txQueue[0];
        var newQueue = [] as Array<ByteArray>;
        for (var i = 1; i < _txQueue.size(); i++) {
            newQueue.add(_txQueue[i]);
        }
        _txQueue = newQueue;

        if (_txTimeoutTimer == null) {
            _txTimeoutTimer = safeTimer();
        } else {
            _txTimeoutTimer.stop();
        }
        if (_txTimeoutTimer != null) {
            _txTimeoutTimer.start(method(:onTxTimeout), 2000, false);
        }

        try {
            _rxCharacteristic.requestWrite(frame, { :writeType => BluetoothLowEnergy.WRITE_TYPE_DEFAULT });
        } catch (e) {
            System.println("BLE write error: " + e.getErrorMessage());
            clearTxQueue();
        }
    }

    public function onTxTimeout() as Void {
        if (_isWriting) {
            System.println("BLE TX timeout: attempting next frame");
            _isWriting = false;
            sendNextTxChunk();
        }
    }

    private function clearTxQueue() as Void {
        _txQueue = [] as Array<ByteArray>;
        _isWriting = false;
        if (_txTimeoutTimer != null) {
            _txTimeoutTimer.stop();
            _txTimeoutTimer = null;
        }
    }

    public function sendChannelText(channelIdx as Number, text as String) as Boolean {
        var targetId = ContactManager.isContactTarget ? ContactManager.selectedContactId : null;
        return sendTextToTarget(channelIdx, targetId, text);
    }

    //! Send text to an explicit destination without depending on the active UI chat.
    public function sendTextToTarget(channelIdx as Number, targetId as String?, text as String) as Boolean {
        var isContact = targetId != null;
        var tid = isContact ? ("CT_" + targetId) : ("CH_" + channelIdx);
        var meSender = I18n.get(Rez.Strings.SenderMe);

        // Store & Forward: If disconnected, queue message instead of dropping it
        if (!isConnected) {
            _spoolQueue.add({
                :isContact => isContact,
                :targetId => targetId,
                :ch => channelIdx,
                :text => text,
                :tid => tid
            });
            ChatHistoryManager.addMessageWithStatus(tid, meSender, text, true, ChatHistoryManager.STATUS_QUEUED);
            if (WatchUi has :showToast) {
                WatchUi.showToast("In Warteschlange: Sendet bei Verbindung", null);
            }
            startScan();
            return true;
        }

        ChatHistoryManager.addMessageWithStatus(tid, meSender, text, true, ChatHistoryManager.STATUS_QUEUED);
        var payload = null;
        if (isContact && targetId != null) {
            System.println("BLE sending direct message to contact " + targetId + ": " + text);
            payload = MeshProtocol.encodeContactMessage(targetId, text);
        } else {
            System.println("BLE sending channel message to channel " + channelIdx + ": " + text);
            payload = MeshProtocol.encodeChannelMessage(channelIdx, text);
        }
        var res = (payload != null) ? sendRaw(payload) : false;
        return res;
    }

    //! Send to the conversation displayed by a chat view, independent of global selection state.
    public function sendTextToConversation(targetId as String, text as String) as Boolean {
        if (targetId.find("CT_") == 0) {
            return sendTextToTarget(0, targetId.substring(3, targetId.length()), text);
        }
        if (targetId.find("CH_") == 0) {
            return sendTextToTarget(targetId.substring(3, targetId.length()).toNumber(), null, text);
        }
        return false;
    }

    public var positionProvider as (Method() as String)? = null;
    public var sosProvider as (Method() as String)? = null;

    //! Universal Position Send
    public function sendCurrentPosition(channelIdx as Number) as Boolean {
        var posStr = (positionProvider != null) ? positionProvider.invoke() : "NO_GPS";
        return sendChannelText(channelIdx, posStr);
    }

    public function sendCurrentPositionToConversation(targetId as String) as Boolean {
        var posStr = (positionProvider != null) ? positionProvider.invoke() : "NO_GPS";
        return sendTextToConversation(targetId, posStr);
    }

    //! SOS Emergency Send
    public function sendSosEmergency(channelIdx as Number) as Boolean {
        var sosStr = (sosProvider != null) ? sosProvider.invoke() : "[SOS] NOTRUF";
        return sendChannelText(channelIdx, sosStr);
    }

    // -----------------------------------------------------------------
    // VIRTUAL MESHCORE NODE SIMULATION METHODS
    // -----------------------------------------------------------------
    public function simulateConnect(simDeviceName as String) as Void {
        isSimulated = true;
        isConnected = true;
        isScanning = false;
        _notificationsReady = true;
        deviceName = simDeviceName;
        virtualNode.isBleConnected = true;
        loraRssi = virtualNode.loraRssi;
        loraSnr = virtualNode.loraSnr;
        nodeBatteryPercent = virtualNode.batteryPercent;
        nodeBatteryMv = virtualNode.batteryMv;
        peerCount = ContactManager.getContacts().size();
        WatchUi.requestUpdate();

        // Node-Binding: Check if node changed
        var nodeChanged = ContactManager.checkNodeBinding(simDeviceName);
        if (nodeChanged) {
            _isFullSync = true;
        }

        // Start real binary session sync with virtual node
        startSessionSync();
    }

    public function simulateDisconnect() as Void {
        stopPeriodicTelemetryTimer();
        isConnected = false;
        isSyncing = false;
        virtualNode.isBleConnected = false;
        deviceName = "Mesh Node";
        loraRssi = null;
        loraSnr = null;
        nodeBatteryPercent = null;
        nodeBatteryMv = null;
        peerCount = 0;
        WatchUi.requestUpdate();
    }

    public function cycleSimulatedSignal() as Void {
        if (!isConnected) {
            simulateConnect("Virtual-Node");
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

    //! Inject an incoming message into the virtual node
    public function simulateIncomingMessage(sender as String, message as String) as Void {
        virtualNode.injectMessage(sender, message, 0);
    }
}
