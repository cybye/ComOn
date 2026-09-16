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
    public var isSyncing as Boolean = false;
    public var deviceName as String = "MeshCore";
    public var lastReceivedMessage as String = "Bereit zum Empfang";
    public var lastSender as String = "Mesh";

    // Virtual Node Twin
    public var virtualNode as VirtualMeshNode;

    // Signal & Network Quality Metrics
    public var loraRssi as Number? = -84; // in dBm
    public var loraSnr as Number? = 6;    // in dB
    public var peerCount as Number = 3;   // Active nodes in mesh

    // Staged Sync State Machine & Spool Queue
    private var _syncStage as Number = 0; // 0=Idle, 1=Inbox, 2=Time, 3=ContactsDelta, 4=Battery
    private var _syncedMessagesCount as Number = 0;
    private var _spoolQueue as Array<Dictionary> = [] as Array<Dictionary>;

    private var _device as BluetoothLowEnergy.Device?;
    private var _rxCharacteristic as BluetoothLowEnergy.Characteristic?;
    private var _txCharacteristic as BluetoothLowEnergy.Characteristic?;

    public function getDevice() as BluetoothLowEnergy.Device? {
        return _device;
    }

    function initialize() {
        virtualNode    = VirtualMeshNode.getInstance();
        nusServiceUuid = BluetoothLowEnergy.stringToUuid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
        nusRxUuid      = BluetoothLowEnergy.stringToUuid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
        nusTxUuid      = BluetoothLowEnergy.stringToUuid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

        virtualNode.setNotifyCallback(method(:onVirtualNotify));
    }

    public function onVirtualNotify(bytes as Array<Number>) as Void {
        procCharacteristicChanged(null, bytes as ByteArray);
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
        if (isSimulated) {
            return;
        }
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
            startSessionSync();
        } else {
            isConnected = false;
            isSyncing = false;
            _syncStage = 0;
            _device = null;
            _rxCharacteristic = null;
            _txCharacteristic = null;
            loraRssi = null;
            loraSnr = null;
            peerCount = 0;
            if (!isSimulated) {
                startScan();
            }
        }
    }

    //! Start the staged session sync (Inbox-First, Time, Delta-Contacts, Battery)
    public function startSessionSync() as Void {
        isSyncing = true;
        _syncStage = 1; // Stage 1: Inbox First!
        _syncedMessagesCount = 0;
        sendRaw(MeshProtocol.encodeSyncNextMessage());
        WatchUi.requestUpdate();
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

    public function procCharacteristicChanged(characteristic as BluetoothLowEnergy.Characteristic?, value as ByteArray) as Void {
        if (value == null || value.size() == 0) {
            return;
        }

        var firstByte = value[0] as Number;

        // 1. Binary Response Codes
        if (firstByte == MeshProtocol.RESP_CODE_OK) {
            if (_syncStage == 1) {
                // Inbox is now drained -> proceed to Stage 2: Time Sync
                _syncStage = 2;
                sendRaw(MeshProtocol.encodeSetDeviceTime(Time.now().value()));
            } else if (_syncStage == 2) {
                // Time sync acknowledged -> proceed to Stage 3: Contacts Delta Sync
                _syncStage = 3;
                sendRaw(MeshProtocol.encodeGetContactsSince(ContactManager.getLastContactSyncTime()));
            } else if (_syncStage == 4) {
                // Battery & stats response
                if (value.size() >= 4) {
                    var batMv = value[1] | (value[2] << 8);
                    System.println("Node battery: " + batMv + " mV");
                }
                // Sync completed!
                finishSessionSync();
            }
            return;
        } else if (firstByte == MeshProtocol.RESP_CODE_CONTACT) {
            // Parse binary contact record
            parseBinaryContact(value);
            return;
        } else if (firstByte == MeshProtocol.RESP_CODE_END_OF_CONTACTS) {
            // Contact delta sync complete -> proceed to Stage 4: Battery & Storage
            ContactManager.setLastContactSyncTime(Time.now().value());
            _syncStage = 4;
            sendRaw(MeshProtocol.encodeGetBattery());
            return;
        } else if (firstByte == MeshProtocol.RESP_CODE_SENT) {
            return;
        } else if (firstByte == MeshProtocol.PUSH_CODE_MSG_WAITING) {
            // Radio signaled incoming message waiting in buffer -> pull it
            sendRaw(MeshProtocol.encodeSyncNextMessage());
            return;
        }

        // 2. Incoming Text Message (UTF-8)
        var arr = [] as Array<Number>;
        for (var i = 0; i < value.size(); i++) {
            arr.add(value[i]);
        }
        var rawText = StringUtil.utf8ArrayToString(arr);

        // Parse "Sender: MessageText"
        var s = "Mesh";
        var mText = rawText;
        var colonIdx = rawText.find(": ");
        if (colonIdx != null && colonIdx > 0) {
            s = rawText.substring(0, colonIdx);
            mText = rawText.substring(colonIdx + 2, rawText.length());
        }

        lastReceivedMessage = mText;
        lastSender = s;

        // Save to Chat History
        var tid = ContactManager.isContactTarget ? ("CT_" + ContactManager.selectedContactId) : ("CH_" + ContactManager.selectedChannelIdx);
        ChatHistoryManager.addMessage(tid, lastSender, mText, false);

        // Only pop full screen notification if not in silent bulk sync
        if (!isSyncing) {
            MeshNotificationManager.getInstance().showIncomingMessage(lastSender, mText, tid);
        }

        if (isSyncing && _syncStage == 1) {
            _syncedMessagesCount++;
            // Fetch next message in inbox queue
            sendRaw(MeshProtocol.encodeSyncNextMessage());
        }

        WatchUi.requestUpdate();
    }

    private function parseBinaryContact(value as ByteArray) as Void {
        try {
            if (value.size() >= 4) {
                var idLen = value[1] as Number;
                if (value.size() >= 2 + idLen + 1) {
                    var idBytes = [] as Array<Number>;
                    for (var i = 2; i < 2 + idLen; i++) { idBytes.add(value[i]); }
                    var idStr = StringUtil.utf8ArrayToString(idBytes);

                    var nameLenIdx = 2 + idLen;
                    var nameLen = value[nameLenIdx] as Number;
                    if (value.size() >= nameLenIdx + 1 + nameLen) {
                        var nameBytes = [] as Array<Number>;
                        for (var j = nameLenIdx + 1; j < nameLenIdx + 1 + nameLen; j++) { nameBytes.add(value[j]); }
                        var nameStr = StringUtil.utf8ArrayToString(nameBytes);
                        ContactManager.addContact(idStr, nameStr);
                    }
                }
            }
        } catch (e) {
            System.println("parseBinaryContact notice");
        }
    }

    private function finishSessionSync() as Void {
        isSyncing = false;
        _syncStage = 0;
        flushSpoolQueue();
        if (_syncedMessagesCount > 0) {
            WatchUi.showToast("[" + _syncedMessagesCount + " Nachrichten empfangen]", null);
        }
        WatchUi.requestUpdate();
    }

    public function flushSpoolQueue() as Void {
        if (_spoolQueue.size() > 0 && isConnected) {
            var sentCount = _spoolQueue.size();
            for (var i = 0; i < _spoolQueue.size(); i++) {
                var item = _spoolQueue[i];
                var ch = item[:ch] as Number;
                var txt = item[:text] as String;
                var payload = MeshProtocol.encodeChannelMessage(ch, txt);
                sendRaw(payload);
            }
            _spoolQueue = [] as Array<Dictionary>;
            WatchUi.showToast(sentCount.toString() + " wartende Nachricht(en) gesendet", null);
        }
    }

    public function procCharacteristicWrite(characteristic as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status) as Void {
    }

    public function procDescriptorWrite(descriptor as BluetoothLowEnergy.Descriptor, status as BluetoothLowEnergy.Status) as Void {
    }

    public function sendRaw(bytes as ByteArray) as Boolean {
        if (isSimulated) {
            virtualNode.onRxData(bytes);
            return true;
        }
        if (isConnected && _rxCharacteristic != null) {
            try {
                _rxCharacteristic.requestWrite(bytes, { :writeType => BluetoothLowEnergy.WRITE_TYPE_DEFAULT });
                return true;
            } catch (e) {
                System.println("BLE write error");
            }
        }
        return false;
    }

    public function sendChannelText(channelIdx as Number, text as String) as Boolean {
        var tid = ContactManager.isContactTarget ? ("CT_" + ContactManager.selectedContactId) : ("CH_" + channelIdx);

        // Store & Forward: If disconnected, queue message instead of dropping it
        if (!isConnected) {
            _spoolQueue.add({ :ch => channelIdx, :text => text, :tid => tid });
            ChatHistoryManager.addMessage(tid, "Ich", text + " [Wartet auf Node]", true);
            WatchUi.showToast("In Warteschlange: Sendet bei Verbindung", null);
            startScan();
            return true;
        }

        ChatHistoryManager.addMessage(tid, "Ich", text, true);
        var payload = MeshProtocol.encodeChannelMessage(channelIdx, text);
        var res = sendRaw(payload);
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
    // VIRTUAL MESHCORE NODE SIMULATION METHODS
    // -----------------------------------------------------------------
    public function simulateConnect(simDeviceName as String) as Void {
        isSimulated = true;
        isConnected = true;
        isScanning = false;
        deviceName = simDeviceName;
        virtualNode.isBleConnected = true;
        loraRssi = virtualNode.loraRssi;
        loraSnr = virtualNode.loraSnr;
        peerCount = ContactManager.getContacts().size();
        WatchUi.requestUpdate();

        // Start real binary session sync with virtual node
        startSessionSync();
    }

    public function simulateDisconnect() as Void {
        isConnected = false;
        isSyncing = false;
        virtualNode.isBleConnected = false;
        deviceName = "MeshCore";
        loraRssi = null;
        loraSnr = null;
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
