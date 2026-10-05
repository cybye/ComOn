import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

class MeshCoreEngine {
    private static var _instance as MeshCoreEngine? = null;

    // Callbacks / Event Listeners
    private var _onMessageCallback as (Method(sender as String, text as String, targetId as String) as Void)? = null;
    private var _onChannelsChangedCallback as (Method() as Void)? = null;
    private var _onContactsChangedCallback as (Method() as Void)? = null;
    private var _onStatusChangedCallback as (Method(isConnected as Boolean, batPct as Number?, rssi as Number?, snr as Number?) as Void)? = null;
    private var _onSyncCompleteCallback as (Method(contactCount as Number, channelCount as Number) as Void)? = null;

    // Transport sender reference
    private var _transportSender as (Method(bytes as ByteArray) as Boolean)? = null;

    // Staged Session Sync Machine State
    // Stages: 0=Idle, 1=Battery, 2=Time, 3=RadioStats, 4=Channels, 5=Contacts, 6=Inbox
    private var _syncStage as Number = 0;
    private var _channelSyncIdx as Number = 0;
    private var _syncedMessagesCount as Number = 0;
    private var _isFullSync as Boolean = false;
    private var _isFastSync as Boolean = false;

    // Bounded Inbox Poll Machine State
    private var _isInboxPolling as Boolean = false;
    private var _inboxPollCount as Number = 0;
    private static const MAX_INBOX_POLL_MESSAGES as Number = 5;

    // Cached node metrics
    public var isConnected as Boolean = false;
    public var nodeBatteryPercent as Number? = null;
    public var nodeBatteryMv as Number? = null;
    public var loraRssi as Number? = null;
    public var loraSnr as Number? = null;

    public static function getInstance() as MeshCoreEngine {
        if (_instance == null) {
            _instance = new MeshCoreEngine();
        }
        return _instance as MeshCoreEngine;
    }

    function initialize() {
    }

    //! Configure transport sender callback (e.g. method(:sendRaw) from BleManager or Poller)
    public function setTransportSender(sender as (Method(bytes as ByteArray) as Boolean)?) as Void {
        _transportSender = sender;
    }

    //! Set event observer for incoming live or synced chat messages
    public function setOnMessageListener(callback as (Method(sender as String, text as String, targetId as String) as Void)?) as Void {
        _onMessageCallback = callback;
    }

    //! Set event observer for channel updates
    public function setOnChannelsChangedListener(callback as (Method() as Void)?) as Void {
        _onChannelsChangedCallback = callback;
    }

    //! Set event observer for contact updates
    public function setOnContactsChangedListener(callback as (Method() as Void)?) as Void {
        _onContactsChangedCallback = callback;
    }

    //! Set event observer for connection, battery or signal changes
    public function setOnStatusChangedListener(callback as (Method(isConnected as Boolean, batPct as Number?, rssi as Number?, snr as Number?) as Void)?) as Void {
        _onStatusChangedCallback = callback;
    }

    //! Set event observer for session sync completion
    public function setOnSyncCompleteListener(callback as (Method(contactCount as Number, channelCount as Number) as Void)?) as Void {
        _onSyncCompleteCallback = callback;
    }

    private function notifyStatusChanged() as Void {
        if (_onStatusChangedCallback != null) {
            _onStatusChangedCallback.invoke(isConnected, nodeBatteryPercent, loraRssi, loraSnr);
        }
    }

    public function setConnected(connected as Boolean) as Void {
        isConnected = connected;
        if (!connected) {
            _syncStage = 0;
            _isInboxPolling = false;
            loraRssi = null;
            loraSnr = null;
        }
        notifyStatusChanged();
    }

    public function sendRaw(bytes as ByteArray) as Boolean {
        if (_transportSender != null) {
            return _transportSender.invoke(bytes);
        }
        return false;
    }

    //! Start session sync sequence
    public function startSync(isFull as Boolean) as Void {
        _isFullSync = isFull;
        _isFastSync = !isFull;
        _syncedMessagesCount = 0;
        _channelSyncIdx = 0;
        _syncStage = 1;
        System.println("MeshCoreEngine: starting " + (_isFullSync ? "full" : "fast") + " sync");
        sendRaw(MeshProtocol.encodeGetBattery());
    }

    public function isSyncing() as Boolean {
        return _syncStage != 0;
    }

    public function isInboxPolling() as Boolean {
        return _isInboxPolling;
    }

    //! Poll inbox batch
    public function pollInbox() as Void {
        if (!isConnected || isSyncing() || _isInboxPolling) {
            return;
        }
        _isInboxPolling = true;
        _inboxPollCount = 0;
        System.println("MeshCoreEngine: polling inbox messages");
        if (!sendRaw(MeshProtocol.encodeSyncNextMessage())) {
            _isInboxPolling = false;
        }
    }

    //! Process an incoming raw byte frame from the transport
    public function onFrameReceived(value as ByteArray) as Void {
        if (value == null || value.size() == 0) {
            return;
        }
        var firstByte = value[0] as Number;

        // 1. Battery & Storage response (Stage 1 or periodic query)
        if (firstByte == MeshFrameParser.RESP_CODE_BATT_AND_STORAGE) {
            var batt = MeshFrameParser.parseBattery(value);
            if (batt != null) {
                nodeBatteryMv = batt[:mv] as Number;
                nodeBatteryPercent = batt[:percent] as Number;
                notifyStatusChanged();
            }
            if (_syncStage == 1) {
                if (_isFastSync) {
                    _syncStage = 3;
                    sendRaw(MeshProtocol.encodeGetStats(MeshProtocol.STATS_TYPE_RADIO));
                } else {
                    _syncStage = 2;
                    sendRaw(MeshProtocol.encodeSetDeviceTime(Time.now().value()));
                }
            } else if (_syncStage == 0 && isConnected) {
                sendRaw(MeshProtocol.encodeGetStats(MeshProtocol.STATS_TYPE_RADIO));
            }
            return;
        }

        // 2. Stage 1 error fallback
        if (_syncStage == 1 && firstByte == MeshFrameParser.RESP_CODE_ERR) {
            if (_isFastSync) {
                _syncStage = 3;
                sendRaw(MeshProtocol.encodeGetStats(MeshProtocol.STATS_TYPE_RADIO));
            } else {
                _syncStage = 2;
                sendRaw(MeshProtocol.encodeSetDeviceTime(Time.now().value()));
            }
            return;
        }

        // 3. Stage 2 response (device time set OK or ERR -> advance to stage 3 radio stats)
        if (_syncStage == 2 && (firstByte == MeshFrameParser.RESP_CODE_OK || firstByte == MeshFrameParser.RESP_CODE_ERR)) {
            _syncStage = 3;
            sendRaw(MeshProtocol.encodeGetStats(MeshProtocol.STATS_TYPE_RADIO));
            return;
        }

        // 4. Device Stats response (Radio stats or Core stats)
        if (firstByte == MeshFrameParser.RESP_CODE_STATS) {
            if (value.size() >= 6 && value[1] == MeshProtocol.STATS_TYPE_RADIO) {
                var rssiVal = value[4] as Number;
                if (rssiVal > 127) { rssiVal -= 256; }
                loraRssi = rssiVal;
                var snrVal = value[5] as Number;
                if (snrVal > 127) { snrVal -= 256; }
                loraSnr = (snrVal / 4).toNumber();
                notifyStatusChanged();
            }
            if (_syncStage == 3) {
                if (_isFastSync) {
                    _syncStage = 6;
                    sendRaw(MeshProtocol.encodeSyncNextMessage());
                } else {
                    _syncStage = 4;
                    _channelSyncIdx = 0;
                    sendRaw(MeshProtocol.encodeGetChannel(0));
                }
            } else if (_syncStage == 0 && isConnected) {
                pollInbox();
            }
            return;
        }

        // 5. Stage 3 error fallback
        if (_syncStage == 3 && firstByte == MeshFrameParser.RESP_CODE_ERR) {
            if (_isFastSync) {
                _syncStage = 6;
                sendRaw(MeshProtocol.encodeSyncNextMessage());
            } else {
                _syncStage = 4;
                _channelSyncIdx = 0;
                sendRaw(MeshProtocol.encodeGetChannel(0));
            }
            return;
        }

        // 6. Stage 4: Channels query responses
        if (_syncStage == 4) {
            if (firstByte == MeshFrameParser.RESP_CODE_CHANNEL_INFO) {
                handleChannelFrame(value);
                _channelSyncIdx++;
                if (_channelSyncIdx < 8) {
                    sendRaw(MeshProtocol.encodeGetChannel(_channelSyncIdx));
                } else {
                    advanceToContactsStage();
                }
                return;
            } else if (firstByte == MeshFrameParser.RESP_CODE_ERR || firstByte == MeshFrameParser.RESP_CODE_OK) {
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
            if (firstByte == MeshFrameParser.RESP_CODE_CONTACTS_START) {
                return;
            } else if (firstByte == MeshFrameParser.RESP_CODE_CONTACT) {
                handleContactFrame(value);
                return;
            } else if (firstByte == MeshFrameParser.RESP_CODE_END_OF_CONTACTS || firstByte == MeshFrameParser.RESP_CODE_ERR) {
                ContactManager.markSyncContactsComplete();
                ContactManager.setLastContactSyncTime(Time.now().value());
                _syncStage = 6;
                sendRaw(MeshProtocol.encodeSyncNextMessage());
                return;
            }
        }

        // 8. Stage 6: Message inbox sync
        if (_syncStage == 6 && MeshFrameParser.isMessageFrame(firstByte)) {
            _syncedMessagesCount++;
            handleIncomingMessageFrame(value, false);
            sendRaw(MeshProtocol.encodeSyncNextMessage());
            return;
        }

        // 9. Stage 6: Message inbox complete
        if (_syncStage == 6 && (firstByte == MeshFrameParser.RESP_CODE_NO_MORE_MESSAGES || firstByte == MeshFrameParser.RESP_CODE_ERR)) {
            finishSync();
            return;
        }

        // 10. Inbox Polling responses
        if (_isInboxPolling && MeshFrameParser.isMessageFrame(firstByte)) {
            _inboxPollCount++;
            handleIncomingMessageFrame(value, true);
            if (_inboxPollCount < MAX_INBOX_POLL_MESSAGES) {
                sendRaw(MeshProtocol.encodeSyncNextMessage());
            } else {
                _isInboxPolling = false;
            }
            return;
        }
        if (_isInboxPolling && (firstByte == MeshFrameParser.RESP_CODE_NO_MORE_MESSAGES || firstByte == MeshFrameParser.RESP_CODE_ERR)) {
            _isInboxPolling = false;
            return;
        }

        // 11. Push message waiting notification from radio
        if (firstByte == MeshFrameParser.PUSH_CODE_MSG_WAITING) {
            sendRaw(MeshProtocol.encodeSyncNextMessage());
            return;
        }

        // 12. Live incoming channel / contact updates while idle
        if (firstByte == MeshFrameParser.RESP_CODE_CHANNEL_INFO) {
            handleChannelFrame(value);
            return;
        }
        if (firstByte == MeshFrameParser.RESP_CODE_CONTACT || firstByte == MeshFrameParser.PUSH_CODE_NEW_ADVERT) {
            handleContactFrame(value);
            return;
        }

        // 13. Live incoming message while idle
        if (MeshFrameParser.isMessageFrame(firstByte)) {
            handleIncomingMessageFrame(value, true);
            return;
        }
    }

    private function advanceToContactsStage() as Void {
        _syncStage = 5;
        if (_isFullSync) {
            sendRaw(MeshProtocol.encodeGetContacts());
        } else {
            var lastSync = ContactManager.getLastContactSyncTime();
            sendRaw(MeshProtocol.encodeGetContactsSince(lastSync));
        }
    }

    private function finishSync() as Void {
        if (_isFullSync) {
            ContactManager.commitFullSync();
            _isFullSync = false;
        }
        _isFastSync = false;
        _syncStage = 0;
        if (_onSyncCompleteCallback != null) {
            _onSyncCompleteCallback.invoke(ContactManager.getContacts().size(), ContactManager.getChannels().size());
        }
    }

    private function handleChannelFrame(value as ByteArray) as Void {
        try {
            var parsed = MeshFrameParser.parseBinaryChannel(value);
            if (parsed != null) {
                var idx = parsed[:channelIdx] as Number;
                var name = parsed[:name] as String;
                if (_isFullSync) {
                    ContactManager.addSyncChannel(idx, name);
                } else {
                    ContactManager.addChannel(idx, name);
                }
                if (_onChannelsChangedCallback != null) {
                    _onChannelsChangedCallback.invoke();
                }
            }
        } catch (e) {
            System.println("MeshCoreEngine handleChannelFrame notice: " + e.getErrorMessage());
        }
    }

    private function handleContactFrame(value as ByteArray) as Void {
        try {
            var parsed = MeshFrameParser.parseBinaryContact(value);
            if (parsed != null) {
                var id = parsed[:id] as String;
                var name = parsed[:name] as String;
                var advType = parsed[:advType] as Number;
                if (_isFullSync) {
                    ContactManager.addSyncContact(id, name, advType);
                } else {
                    ContactManager.addContact(id, name, advType);
                }
                if (_onContactsChangedCallback != null) {
                    _onContactsChangedCallback.invoke();
                }
            }
        } catch (e) {
            System.println("MeshCoreEngine handleContactFrame notice: " + e.getErrorMessage());
        }
    }

    private function handleIncomingMessageFrame(value as ByteArray, notify as Boolean) as Void {
        var code = value[0] as Number;
        if (code == MeshFrameParser.RESP_CODE_CHANNEL_MSG || code == MeshFrameParser.RESP_CODE_CHANNEL_MSG_V3) {
            var parsedCh = MeshFrameParser.parseChannelMessage(value);
            if (parsedCh != null) {
                if (parsedCh.hasKey(:snr) && parsedCh[:snr] != null) {
                    loraSnr = parsedCh[:snr] as Number;
                    notifyStatusChanged();
                }
                var targetId = "CH_" + (parsedCh[:channelIdx] as Number);
                var sender = parsedCh[:sender] as String;
                var text = parsedCh[:text] as String;
                ChatHistoryManager.addIncomingMessage(targetId, sender, text);
                if (notify && _onMessageCallback != null) {
                    _onMessageCallback.invoke(sender, text, targetId);
                }
            }
        } else if (code == MeshFrameParser.RESP_CODE_CONTACT_MSG || code == MeshFrameParser.RESP_CODE_CONTACT_MSG_V3) {
            var parsedCt = MeshFrameParser.parseDirectMessage(value);
            if (parsedCt != null) {
                if (parsedCt.hasKey(:snr) && parsedCt[:snr] != null) {
                    loraSnr = parsedCt[:snr] as Number;
                    notifyStatusChanged();
                }
                var senderHex = parsedCt[:senderHex] as String;
                var targetId = "CT_" + senderHex;
                var sender = senderHex;
                var ct = ContactManager.getContactById(senderHex);
                if (ct != null && ct[:name] != null) {
                    sender = ct[:name] as String;
                }
                var text = parsedCt[:text] as String;
                ChatHistoryManager.addIncomingMessage(targetId, sender, text);
                if (notify && _onMessageCallback != null) {
                    _onMessageCallback.invoke(sender, text, targetId);
                }
            }
        }
    }
}
