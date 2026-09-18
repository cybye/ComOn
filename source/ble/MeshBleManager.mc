import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;
import Toybox.StringUtil;
import Toybox.Application.Storage;
import Toybox.WatchUi;

class MeshBleManager {
    public var nusServiceUuid as BluetoothLowEnergy.Uuid?;
    public var nusRxUuid      as BluetoothLowEnergy.Uuid?;
    public var nusTxUuid      as BluetoothLowEnergy.Uuid?;

    public var isConnected as Boolean = false;
    public var isScanning as Boolean = false;
    public var isSimulated as Boolean = false;
    public var isSyncing as Boolean = false;
    public var deviceName as String = "Mesh Node";
    public var lastReceivedMessage as String = "Bereit zum Empfang";
    public var lastSender as String = "Mesh";
    public var onMessageCallback as (Method(sender as String, text as String, tid as String) as Void)? = null;

    // Virtual Node Twin
    public var virtualNode as VirtualMeshNode;

    // Signal & Network Quality Metrics
    public var loraRssi as Number? = -84; // in dBm
    public var loraSnr as Number? = 6;    // in dB
    public var peerCount as Number = 3;   // Active nodes in mesh
    public var nodeBatteryPercent as Number? = null;
    public var nodeBatteryMv as Number? = null;

    // Staged Sync State Machine & Spool Queue
    private var _syncStage as Number = 0; // 0=Idle, 1=Inbox, 2=Time, 3=Channels, 4=Contacts, 5=Battery
    private var _syncedMessagesCount as Number = 0;
    private var _isFullSync as Boolean = false;
    private var _spoolQueue as Array<Dictionary> = [] as Array<Dictionary>;
    private var _pauseScanUntil as Number = 0;

    public function forceFullSync() as Void {
        _isFullSync = true;
        ContactManager.resetSyncTime();
        if (isConnected) {
            startSessionSync();
        } else if (!isSimulated) {
            startScan();
        }
    }

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
        var now = Time.now().value();
        if (now < _pauseScanUntil) {
            System.println("BLE scan paused for " + (_pauseScanUntil - now) + "s (Freigabe aktiv)");
            return;
        }
        if (!isScanning && !isConnected) {
            isScanning = true;
            try {
                BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
            } catch (e) {
                System.println("setScanState notice: " + e.getErrorMessage());
                isScanning = false;
            }
        }
    }

    public function resumeScan() as Void {
        _pauseScanUntil = 0;
        startScan();
    }

    public function releaseNode(pauseSeconds as Number) as Void {
        _pauseScanUntil = Time.now().value() + pauseSeconds;
        stopScan();

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
        try {
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
                        try {
                            var dev = BluetoothLowEnergy.pairDevice(res);
                            if (dev != null) {
                                _device = dev;
                            }
                        } catch (e) {
                            System.println("BLE pairDevice notice: " + e.getErrorMessage());
                            // If already paired, retrieve device from getPairedDevices
                            var pairedIter = BluetoothLowEnergy.getPairedDevices();
                            if (pairedIter != null) {
                                var p = pairedIter.next();
                                if (p != null) {
                                    _device = p as BluetoothLowEnergy.Device;
                                }
                            }
                            if (_device != null) {
                                procConnectedStateChanged(_device, BluetoothLowEnergy.CONNECTION_STATE_CONNECTED);
                            }
                        }
                        return;
                    }
                }
            }
        } catch (outerEx) {
            System.println("procScanResults outer notice: " + outerEx.getErrorMessage());
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

            // Node-Binding: Check if node changed
            var nodeChanged = ContactManager.checkNodeBinding(deviceName);
            if (nodeChanged) {
                _isFullSync = true;
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

    //! Start the staged session sync (Inbox-First, Time, Channels, Contacts, Battery)
    public function startSessionSync() as Void {
        isSyncing = true;
        _syncStage = 1; // Stage 1: Inbox First!
        _syncedMessagesCount = 0;

        if (_isFullSync || ContactManager.getLastContactSyncTime() == 0) {
            _isFullSync = true;
            ContactManager.startFullSync();
        }

        sendRaw(MeshProtocol.encodeSyncNextMessage());
        if (WatchUi has :requestUpdate) {
            WatchUi.requestUpdate();
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
                // Time sync acknowledged -> proceed to Stage 3: Channels Sync
                _syncStage = 3;
                sendRaw(MeshProtocol.encodeGetChannels());
            } else if (_syncStage == 5) {
                // Battery & stats response
                if (value.size() >= 4) {
                    nodeBatteryMv = value[1] | (value[2] << 8);
                    nodeBatteryPercent = value[3] as Number;
                    System.println("Node battery: " + nodeBatteryMv + " mV (" + nodeBatteryPercent + "%)");
                }
                // Sync completed!
                finishSessionSync();
            }
            return;
        } else if (firstByte == MeshProtocol.RESP_CODE_ERR) {
            if (_syncStage == 3) {
                // Node does not support channel query -> skip to Stage 4 Contacts
                System.println("Node returned ERR for channel query -> proceed to contacts");
                _syncStage = 4;
                var since = (_isFullSync || ContactManager.getLastContactSyncTime() == 0) ? 0 : ContactManager.getLastContactSyncTime();
                sendRaw(MeshProtocol.encodeGetContactsSince(since));
            } else if (_syncStage == 4) {
                // Skip to Stage 5 Battery
                _syncStage = 5;
                sendRaw(MeshProtocol.encodeGetBattery());
            }
            return;
        } else if (firstByte == MeshProtocol.RESP_CODE_CHANNELS_START) {
            return;
        } else if (firstByte == MeshProtocol.RESP_CODE_CHANNEL) {
            parseBinaryChannel(value);
            return;
        } else if (firstByte == MeshProtocol.RESP_CODE_END_OF_CHANNELS) {
            // Channels sync complete -> proceed to Stage 4: Contacts
            _syncStage = 4;
            var since = (_isFullSync || ContactManager.getLastContactSyncTime() == 0) ? 0 : ContactManager.getLastContactSyncTime();
            sendRaw(MeshProtocol.encodeGetContactsSince(since));
            return;
        } else if (firstByte == MeshProtocol.RESP_CODE_CONTACTS_START) {
            return;
        } else if (firstByte == MeshProtocol.RESP_CODE_CONTACT) {
            // Parse binary contact record
            parseBinaryContact(value);
            return;
        } else if (firstByte == MeshProtocol.RESP_CODE_END_OF_CONTACTS) {
            // Contact sync complete -> proceed to Stage 5: Battery & Storage
            ContactManager.setLastContactSyncTime(Time.now().value());
            _syncStage = 5;
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

        if (isSimulated) {
            loraRssi = virtualNode.loraRssi;
            loraSnr = virtualNode.loraSnr;
        }

        // Save to Chat History
        var tid = ContactManager.isContactTarget ? ("CT_" + ContactManager.selectedContactId) : ("CH_" + ContactManager.selectedChannelIdx);
        ChatHistoryManager.addMessage(tid, lastSender, mText, false);

        System.println("BLE RX: sender=" + lastSender + " isSyncing=" + isSyncing + " mText=" + mText);

        // Notify listener if not in silent bulk sync
        if (!isSyncing && onMessageCallback != null) {
            try {
                onMessageCallback.invoke(lastSender, mText, tid);
            } catch (e) {
                System.println("onMessageCallback error: " + e.getErrorMessage());
            }
        }

        if (isSyncing && _syncStage == 1) {
            _syncedMessagesCount++;
            // Fetch next message in inbox queue
            sendRaw(MeshProtocol.encodeSyncNextMessage());
        }

        WatchUi.requestUpdate();
    }

    private function parseBinaryChannel(value as ByteArray) as Void {
        try {
            if (value.size() >= 3) {
                var chIdx = value[1] as Number;
                var nameLen = value[2] as Number;
                if (value.size() >= 3 + nameLen) {
                    var nameBytes = [] as Array<Number>;
                    for (var i = 3; i < 3 + nameLen; i++) {
                        nameBytes.add(value[i]);
                    }
                    var nameStr = StringUtil.utf8ArrayToString(nameBytes);
                    if (_isFullSync) {
                        ContactManager.addSyncChannel(chIdx, nameStr);
                    } else {
                        ContactManager.addChannel(chIdx, nameStr);
                    }
                }
            }
        } catch (e) {
            System.println("parseBinaryChannel notice: " + e.getErrorMessage());
        }
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
                        if (_isFullSync) {
                            ContactManager.addSyncContact(idStr, nameStr);
                        } else {
                            ContactManager.addContact(idStr, nameStr);
                        }
                    }
                }
            }
        } catch (e) {
            System.println("parseBinaryContact notice: " + e.getErrorMessage());
        }
    }

    private function finishSessionSync() as Void {
        if (_isFullSync) {
            ContactManager.commitFullSync();
            _isFullSync = false;
        }
        isSyncing = false;
        _syncStage = 0;
        flushSpoolQueue();
        peerCount = ContactManager.getContacts().size();
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
                var ch = item[:ch] as Number;
                var txt = item[:text] as String;
                var payload = MeshProtocol.encodeChannelMessage(ch, txt);
                sendRaw(payload);
            }
            _spoolQueue = [] as Array<Dictionary>;
            if (WatchUi has :showToast) {
                WatchUi.showToast(sentCount.toString() + " wartende Nachricht(en) gesendet", null);
            }
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
            if (WatchUi has :showToast) {
                WatchUi.showToast("In Warteschlange: Sendet bei Verbindung", null);
            }
            startScan();
            return true;
        }

        ChatHistoryManager.addMessage(tid, "Ich", text, true);
        var payload = MeshProtocol.encodeChannelMessage(channelIdx, text);
        var res = sendRaw(payload);
        return res;
    }

    public var positionProvider as (Method() as String)? = null;
    public var sosProvider as (Method() as String)? = null;

    //! Universal Position Send
    public function sendCurrentPosition(channelIdx as Number) as Boolean {
        var posStr = (positionProvider != null) ? positionProvider.invoke() : "NO_GPS";
        return sendChannelText(channelIdx, posStr);
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
