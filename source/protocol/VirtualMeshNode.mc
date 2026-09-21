import Toybox.Lang;
import Toybox.Time;
import Toybox.System;
import Toybox.StringUtil;
import Toybox.Application.Storage;
import Toybox.Timer;

class VirtualMeshNode {
    private static var _instance as VirtualMeshNode? = null;

    public var isBleConnected as Boolean = false;
    public var echoMode as Boolean = true; // Enabled by default
    public var batteryMv as Number = 3940;
    public var batteryPercent as Number = 84;
    public var loraRssi as Number = -76;
    public var loraSnr as Number = 8;
    public var nodeTime as Number = 0;

    private var _inbox as Array<Dictionary> = [] as Array<Dictionary>;
    private var _contacts as Array<Dictionary> = [] as Array<Dictionary>;
    private var _channels as Array<Dictionary> = [] as Array<Dictionary>;
    private var _notifyCallback as Method?;

    public static function getInstance() as VirtualMeshNode {
        if (_instance == null) {
            _instance = new VirtualMeshNode();
        }
        return _instance as VirtualMeshNode;
    }

    function initialize() {
        var now = Time.now().value();
        nodeTime = now;

        // Default initial channels on the node
        _channels = [
            { :idx => 0, :name => "#public" },
            { :idx => 1, :name => "#notruf" },
            { :idx => 2, :name => "#team" }
        ];

        // Default initial contacts on the node
        _contacts = [
            { :id => "NODE_BASE",  :name => "Basisstation", :lastSeen => now - 600, :snr => 9 },
            { :id => "NODE_FLO",   :name => "Florian",      :lastSeen => now - 120, :snr => 6 },
            { :id => "NODE_COMP1", :name => "Begleiter 1",  :lastSeen => now - 40,  :snr => 8 },
            { :id => "NODE_BERG",  :name => "Bergwacht",    :lastSeen => now - 900, :snr => 4 }
        ];
    }

    public function setNotifyCallback(callback as Method?) as Void {
        _notifyCallback = callback;
    }

    //! Handle incoming RX bytes from watch over virtual BLE
    public function onRxData(bytes as ByteArray) as Void {
        if (bytes == null || bytes.size() == 0) {
            return;
        }

        var cmd = bytes[0] as Number;

        if (cmd == MeshProtocol.CMD_APP_START) {
            handleAppStart();
        } else if (cmd == MeshProtocol.CMD_DEVICE_QUERY) {
            deliverNotify([MeshProtocol.RESP_CODE_DEVICE_INFO, 13, 50, 8]);
        } else if (cmd == MeshProtocol.CMD_SEND_CHANNEL_TXT_MSG) {
            handleSendChannelMessage(bytes);
        } else if (cmd == MeshProtocol.CMD_SEND_TXT_MSG) {
            handleSendDirectMessage(bytes);
        } else if (cmd == MeshProtocol.CMD_SYNC_NEXT_MESSAGE) {
            handleSyncNextMessage();
        } else if (cmd == MeshProtocol.CMD_GET_CHANNEL) {
            handleGetChannel(bytes);
        } else if (cmd == MeshProtocol.CMD_GET_CONTACTS) {
            handleGetContacts(bytes);
        } else if (cmd == MeshProtocol.CMD_SET_DEVICE_TIME) {
            handleSetDeviceTime(bytes);
        } else if (cmd == MeshProtocol.CMD_GET_BATTERY_AND_STORAGE) {
            handleGetBattery();
        } else if (cmd == MeshProtocol.CMD_GET_STATS) {
            handleGetStats(bytes);
        } else {
            // Default OK
            deliverNotify([MeshProtocol.RESP_CODE_OK]);
        }
    }

    private function handleAppStart() as Void {
        var response = [] as Array<Number>;
        response.add(MeshProtocol.RESP_CODE_SELF_INFO);
        for (var index = 1; index < 58; index++) { response.add(0); }
        var nameBytes = "Virtual-Node".toUtf8Array();
        for (var nameIndex = 0; nameIndex < nameBytes.size(); nameIndex++) { response.add(nameBytes[nameIndex]); }
        deliverNotify(response);
    }

    private function handleSendChannelMessage(bytes as ByteArray) as Void {
        var channelIdx = (bytes.size() > 2) ? bytes[2] : 0;
        
        // Extract text
        var text = "";
        if (bytes.size() > 7) {
            var textBytes = [] as Array<Number>;
            for (var i = 7; i < bytes.size(); i++) {
                textBytes.add(bytes[i]);
            }
            text = StringUtil.utf8ArrayToString(textBytes);
        }

        System.println("VirtualNode RX Channel " + channelIdx + ": " + text);

        // Respond with RESP_CODE_SENT (Single check ✓)
        deliverNotify([MeshProtocol.RESP_CODE_SENT, 0x00]);

        // Schedule PushSendConfirmed (0x82) after 400ms (Double check ✓✓)
        if (_meshSendConfirmTimer == null) {
            _meshSendConfirmTimer = new Timer.Timer();
        }
        _meshSendConfirmTimer.start(method(:onMeshSendConfirmedTrigger), 400, false);

        // If echo mode active, simulate remote response
        if (echoMode && text.length() > 0) {
            scheduleEchoReply(text, channelIdx);
        }
    }

    private function handleSendDirectMessage(bytes as ByteArray) as Void {
        // [CMD_SEND_TXT_MSG(1), txt_type(1), attempt(1), timestamp(4), pubkey_prefix(6), text...]
        var text = "";
        if (bytes.size() > 13) {
            var textBytes = [] as Array<Number>;
            for (var i = 13; i < bytes.size(); i++) {
                textBytes.add(bytes[i]);
            }
            text = StringUtil.utf8ArrayToString(textBytes);
        }

        var pubkeyHex = "";
        for (var p = 7; p < 13 && p < bytes.size(); p++) {
            var b = bytes[p] & 0xFF;
            pubkeyHex += b.format("%02X");
        }

        System.println("VirtualNode RX DM to " + pubkeyHex + ": " + text);

        // Respond with RESP_CODE_SENT (Single check ✓)
        deliverNotify([MeshProtocol.RESP_CODE_SENT, 0x00]);

        // Schedule PushSendConfirmed (0x82) after 400ms (Double check ✓✓)
        if (_meshSendConfirmTimer == null) {
            _meshSendConfirmTimer = new Timer.Timer();
        }
        _meshSendConfirmTimer.start(method(:onMeshSendConfirmedTrigger), 400, false);
    }

    public function onMeshSendConfirmedTrigger() as Void {
        deliverNotify([0x82, 0x00]);
    }

    private function handleSyncNextMessage() as Void {
        if (_inbox.size() > 0) {
            // Pop oldest message
            var msg = _inbox[0];
            var newInbox = [] as Array<Dictionary>;
            for (var i = 1; i < _inbox.size(); i++) {
                newInbox.add(_inbox[i]);
            }
            _inbox = newInbox;

            var sender = msg[:sender] as String;
            var text = msg[:text] as String;

            var frame = [MeshProtocol.RESP_CODE_CHANNEL_MSG, msg[:channelIdx], 0xFF, 0] as Array<Number>;
            var timestamp = msg[:time] as Number;
            frame.add(timestamp & 0xFF);
            frame.add((timestamp >> 8) & 0xFF);
            frame.add((timestamp >> 16) & 0xFF);
            frame.add((timestamp >> 24) & 0xFF);
            var textBytes = (sender + ": " + text).toUtf8Array();
            for (var textIndex = 0; textIndex < textBytes.size(); textIndex++) { frame.add(textBytes[textIndex]); }
            deliverNotify(frame);
        } else {
            deliverNotify([MeshProtocol.RESP_CODE_NO_MORE_MESSAGES]);
        }
    }

    private function handleGetChannel(bytes as ByteArray) as Void {
        var channelIndex = (bytes.size() > 1) ? (bytes[1] as Number) : 0;
        if (channelIndex >= _channels.size()) {
            deliverNotify([MeshProtocol.RESP_CODE_ERR, 2]);
            return;
        }
        var channel = _channels[channelIndex];
        var response = [MeshProtocol.RESP_CODE_CHANNEL_INFO, channelIndex] as Array<Number>;
        var nameBytes = (channel[:name] as String).toUtf8Array();
        for (var nameIndex = 0; nameIndex < 32; nameIndex++) {
            response.add((nameIndex < nameBytes.size()) ? nameBytes[nameIndex] : 0);
        }
        for (var secretIndex = 0; secretIndex < 16; secretIndex++) { response.add(0); }
        deliverNotify(response);
    }

    private function handleGetContacts(bytes as ByteArray) as Void {
        var sinceTime = 0;
        if (bytes.size() >= 5) {
            sinceTime = bytes[1] | (bytes[2] << 8) | (bytes[3] << 16) | (bytes[4] << 24);
        }

        // 1. Send RESP_CODE_CONTACTS_START
        var frames = [] as Array;
        frames.add([MeshProtocol.RESP_CODE_CONTACTS_START]);

        // 2. Stream contacts that match sinceTime
        for (var i = 0; i < _contacts.size(); i++) {
            var c = _contacts[i];
            var lastSeen = c[:lastSeen] as Number;
            if (sinceTime == 0 || lastSeen >= sinceTime) {
                var nameBytes = (c[:name] as String).toUtf8Array();
                var idBytes = (c[:id] as String).toUtf8Array();
                var frame = [
                    MeshProtocol.RESP_CODE_CONTACT,
                    idBytes.size()
                ] as Array<Number>;
                for (var idI = 0; idI < idBytes.size(); idI++) { frame.add(idBytes[idI]); }
                frame.add(nameBytes.size());
                for (var nI = 0; nI < nameBytes.size(); nI++) { frame.add(nameBytes[nI]); }
                frames.add(frame);
            }
        }

        // 3. Send RESP_CODE_END_OF_CONTACTS
        frames.add([MeshProtocol.RESP_CODE_END_OF_CONTACTS]);

        // Deliver frames
        for (var f = 0; f < frames.size(); f++) {
            deliverNotify(frames[f]);
        }
    }

    private function handleSetDeviceTime(bytes as ByteArray) as Void {
        if (bytes.size() >= 5) {
            nodeTime = bytes[1] | (bytes[2] << 8) | (bytes[3] << 16) | (bytes[4] << 24);
            System.println("VirtualNode: Clock synchronized to " + nodeTime);
        }
        deliverNotify([MeshProtocol.RESP_CODE_OK]);
    }

    private function handleGetBattery() as Void {
        var payload = [
            MeshProtocol.RESP_CODE_BATT_AND_STORAGE,
            (batteryMv & 0xFF),
            ((batteryMv >> 8) & 0xFF),
            0, 0, 0, 0, 0, 0, 0, 0
        ] as Array<Number>;
        deliverNotify(payload);
    }

    private function handleGetStats(bytes as ByteArray) as Void {
        var statsType = (bytes.size() > 1) ? (bytes[1] as Number) : 0;
        if (statsType == MeshProtocol.STATS_TYPE_RADIO) {
            deliverNotify([MeshProtocol.RESP_CODE_STATS, MeshProtocol.STATS_TYPE_RADIO, 0, 0, loraRssi & 0xFF, (loraSnr * 4) & 0xFF, 0, 0, 0, 0, 0, 0, 0, 0]);
        } else {
            deliverNotify([MeshProtocol.RESP_CODE_STATS, statsType, batteryMv & 0xFF, (batteryMv >> 8) & 0xFF, 0, 0, 0, 0, 0, 0, 0]);
        }
    }

    //! Inject an incoming message into the node's LoRa radio receiver
    public function injectMessage(sender as String, text as String, channelIdx as Number) as Void {
        var entry = {
            :sender => sender,
            :text => text,
            :channelIdx => channelIdx,
            :time => Time.now().value()
        };
        _inbox.add(entry);

        if (isBleConnected) {
            // If watch is connected, push notification byte PUSH_CODE_MSG_WAITING or deliver message
            var fullStr = sender + ": " + text;
            deliverNotify(fullStr.toUtf8Array());
        } else {
            System.println("VirtualNode: Buffered offline message from " + sender);
            try {
                Storage.setValue("sim_pendingMsgCount", _inbox.size());
                Storage.setValue("sim_lastPendingSender", sender);
                Storage.setValue("sim_lastPendingMsg", text);
            } catch (e) {
                // ignore
            }
        }
    }

    //! Fill inbox with 3 realistic messages to test catch-up sync
    public function fillInboxWithMissedMessages() as Void {
        var now = Time.now().value();
        _inbox.add({ :sender => "Florian", :text => "Wegpunkt 3 erreicht. Weiter Richtung Grat.", :channelIdx => 0, :time => now - 300 });
        _inbox.add({ :sender => "Bergwacht", :text => "Wetterbericht: Ab 15 Uhr Gewitterrisiko im Tal.", :channelIdx => 1, :time => now - 180 });
        _inbox.add({ :sender => "Basisstation", :text => "Relais-Node Wendelstein aktiv auf Kanal 0.", :channelIdx => 0, :time => now - 60 });
        System.println("VirtualNode: 3 messages buffered in offline inbox (total: " + _inbox.size() + ")");

        try {
            Storage.setValue("sim_pendingMsgCount", _inbox.size());
            Storage.setValue("sim_lastPendingSender", "Florian");
            Storage.setValue("sim_lastPendingMsg", "Wegpunkt 3 erreicht. Weiter Richtung Grat.");
        } catch (e) {
            // ignore
        }

        if (isBleConnected) {
            deliverNotify([MeshProtocol.PUSH_CODE_MSG_WAITING]);
        }
    }

    public function injectContact(name as String, id as String) as Void {
        _contacts.add({
            :name => name,
            :id => id,
            :lastSeen => Time.now().value(),
            :snr => 8
        });
        if (isBleConnected) {
            deliverNotify([MeshProtocol.PUSH_CODE_MSG_WAITING]);
        }
    }

    public function getPendingInboxCount() as Number {
        return _inbox.size();
    }

    private var _meshSendConfirmTimer as Timer.Timer? = null;
    private var _echoTimer as Timer.Timer? = null;
    private var _pendingEchoText as String = "";
    private var _pendingEchoChannel as Number = 0;

    private function scheduleEchoReply(originalText as String, channelIdx as Number) as Void {
        _pendingEchoText = (originalText.length() > 0) ? ("Echo: " + originalText) : "Empfang OK";
        _pendingEchoChannel = channelIdx;

        if (_echoTimer == null) {
            _echoTimer = new Timer.Timer();
        }
        _echoTimer.start(method(:onEchoTimerTrigger), 1200, false);
    }

    public function onEchoTimerTrigger() as Void {
        var nowVal = Time.now().value();
        loraRssi = -74 - (nowVal % 9);
        loraSnr = 6 + ((nowVal / 2) % 4);

        injectMessage("Echo", _pendingEchoText, _pendingEchoChannel);
    }

    private var _deliveryQueue as Array<Array<Number>> = [] as Array<Array<Number>>;
    private var _isDelivering as Boolean = false;

    private function deliverNotify(data as Array<Number>) as Void {
        if (_notifyCallback == null || !isBleConnected) {
            return;
        }

        _deliveryQueue.add(data);

        // If already delivering, return immediately to unwind the call stack!
        if (_isDelivering) {
            return;
        }

        _isDelivering = true;
        while (_deliveryQueue.size() > 0 && isBleConnected) {
            var item = _deliveryQueue[0];
            var newQueue = [] as Array<Array<Number>>;
            for (var i = 1; i < _deliveryQueue.size(); i++) {
                newQueue.add(_deliveryQueue[i]);
            }
            _deliveryQueue = newQueue;

            try {
                _notifyCallback.invoke(item);
            } catch (e) {
                System.println("VirtualNode notify error: " + e.getErrorMessage());
            }
        }
        _isDelivering = false;
    }
}
