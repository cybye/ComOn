import Toybox.Lang;
import Toybox.Time;
import Toybox.System;
import Toybox.Timer;
import Toybox.StringUtil;

class VirtualMeshNode {
    private static var _instance as VirtualMeshNode? = null;

    public var isBleConnected as Boolean = false;
    public var echoMode as Boolean = false;
    public var batteryMv as Number = 3940;
    public var batteryPercent as Number = 84;
    public var loraRssi as Number = -82;
    public var loraSnr as Number = 7;
    public var nodeTime as Number = 0;

    private var _inbox as Array<Dictionary> = [] as Array<Dictionary>;
    private var _contacts as Array<Dictionary> = [] as Array<Dictionary>;
    private var _notifyCallback as Method?;
    private var _echoTimer as Timer.Timer?;
    private var _asyncTimer as Timer.Timer?;
    private var _pendingNotifyData as Array<Number>?;

    public static function getInstance() as VirtualMeshNode {
        if (_instance == null) {
            _instance = new VirtualMeshNode();
        }
        return _instance as VirtualMeshNode;
    }

    function initialize() {
        var now = Time.now().value();
        nodeTime = now;

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
            // Handshake response: OK, protocol version 1.0
            sendNotifyAsync([MeshProtocol.RESP_CODE_OK, 0x01, 0x00]);
        } else if (cmd == MeshProtocol.CMD_SEND_CHANNEL_TXT_MSG) {
            handleSendChannelMessage(bytes);
        } else if (cmd == MeshProtocol.CMD_SYNC_NEXT_MESSAGE) {
            handleSyncNextMessage();
        } else if (cmd == MeshProtocol.CMD_GET_CONTACTS) {
            handleGetContacts(bytes);
        } else if (cmd == MeshProtocol.CMD_SET_DEVICE_TIME) {
            handleSetDeviceTime(bytes);
        } else if (cmd == MeshProtocol.CMD_GET_BATTERY_AND_STORAGE) {
            handleGetBattery();
        } else {
            // Default OK
            sendNotifyAsync([MeshProtocol.RESP_CODE_OK]);
        }
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

        // Respond with RESP_CODE_SENT
        sendNotifyAsync([MeshProtocol.RESP_CODE_SENT, 0x00]);

        // If echo mode active, simulate remote response
        if (echoMode && text.length() > 0) {
            scheduleEchoReply(text, channelIdx);
        }
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

            // Transmit as formatted incoming string over virtual NUS: "Sender: Text"
            var fullStr = sender + ": " + text;
            sendNotifyAsync(fullStr.toUtf8Array());
        } else {
            // Queue empty -> return RESP_CODE_OK
            var resp = [] as Array<Number>;
            resp.add(MeshProtocol.RESP_CODE_OK);
            resp.add(0);
            sendNotifyAsync(resp);
        }
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
        sendNotifyAsync([MeshProtocol.RESP_CODE_OK]);
    }

    private function handleGetBattery() as Void {
        var payload = [
            MeshProtocol.RESP_CODE_OK,
            (batteryMv & 0xFF),
            ((batteryMv >> 8) & 0xFF),
            batteryPercent
        ] as Array<Number>;
        sendNotifyAsync(payload);
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
            sendNotifyAsync(fullStr.toUtf8Array());
        } else {
            System.println("VirtualNode: Buffered offline message from " + sender);
        }
    }

    //! Fill inbox with 3 realistic messages to test catch-up sync
    public function fillInboxWithMissedMessages() as Void {
        injectMessage("Florian", "Wegpunkt 3 erreicht. Weiter Richtung Grat.", 0);
        injectMessage("Bergwacht", "Wetterbericht: Ab 15 Uhr Gewitterrisiko im Tal.", 1);
        injectMessage("Basisstation", "Relais-Node Wendelstein aktiv auf Kanal 0.", 0);
    }

    public function injectContact(name as String, id as String) as Void {
        _contacts.add({
            :name => name,
            :id => id,
            :lastSeen => Time.now().value(),
            :snr => 8
        });
        if (isBleConnected) {
            sendNotifyAsync([MeshProtocol.PUSH_CODE_MSG_WAITING]);
        }
    }

    public function getPendingInboxCount() as Number {
        return _inbox.size();
    }

    private function scheduleEchoReply(originalText as String, channelIdx as Number) as Void {
        _echoTimer = new Timer.Timer();
        _echoTimer.start(method(:onEchoTimerTrigger), 1500, false);
    }

    public function onEchoTimerTrigger() as Void {
        injectMessage("Node (Echo)", "Empfangen: " + Time.now().value(), 0);
    }

    private function sendNotifyAsync(data as Array<Number>) as Void {
        _pendingNotifyData = data;
        _asyncTimer = new Timer.Timer();
        _asyncTimer.start(method(:onAsyncTimerTrigger), 25, false); // 25ms realistic BLE latency
    }

    public function onAsyncTimerTrigger() as Void {
        if (_pendingNotifyData != null) {
            deliverNotify(_pendingNotifyData as Array<Number>);
            _pendingNotifyData = null;
        }
    }

    private function deliverNotify(data as Array<Number>) as Void {
        if (_notifyCallback != null && isBleConnected) {
            try {
                _notifyCallback.invoke(data);
            } catch (e) {
                System.println("VirtualNode notify error: " + e.getErrorMessage());
            }
        }
    }
}
