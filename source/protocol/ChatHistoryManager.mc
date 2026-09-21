import Toybox.Lang;
import Toybox.Time;
import Toybox.Application.Storage;

class ChatHistoryManager {
    private static const STORAGE_KEY as String = "cfg_chat_history";
    private static const MAX_HISTORY as Number = 40;

    private static var _messages as Array<Dictionary> = [] as Array<Dictionary>;
    private static var _initialized as Boolean = false;

    public static const STATUS_QUEUED as Number         = 0; // Waiting in spool or awaiting node response
    public static const STATUS_SENT_NODE as Number      = 1; // Node acknowledged receipt via BLE (Single check ✓)
    public static const STATUS_CONFIRMED_MESH as Number = 2; // Node confirmed radio mesh broadcast via LoRa (Double check ✓✓)

    public static function initializeHistory() as Void {
        if (_initialized) {
            return;
        }
        _initialized = true;

        try {
            var stored = Storage.getValue(STORAGE_KEY);
            if (stored != null && (stored instanceof Array)) {
                var list = stored as Array<Dictionary>;
                var loaded = [] as Array<Dictionary>;
                for (var i = 0; i < list.size(); i++) {
                    var it = list[i];
                    var isOut = (it["isOutgoing"] != null) ? (it["isOutgoing"] as Boolean) : false;
                    var storedRead = it["isRead"];
                    var isRead = (storedRead instanceof Boolean) ? (storedRead as Boolean) : isOut;
                    var st = it["status"];
                    if (st == null) {
                        st = isOut ? STATUS_CONFIRMED_MESH : 0;
                    }
                    loaded.add({
                        :targetId => it["targetId"],
                        :sender => it["sender"],
                        :text => it["text"],
                        :isOutgoing => isOut,
                        :time => it["time"],
                        :isRead => isRead,
                        :status => st
                    });
                }
                _messages = loaded;
            }
        } catch (e) {
            _messages = [] as Array<Dictionary>;
        }
    }

    public static function clearHistory() as Void {
        _messages = [] as Array<Dictionary>;
        try {
            Storage.deleteValue(STORAGE_KEY);
        } catch (e) {
            // ignore
        }
    }

    public static function addMessage(targetId as String, sender as String, text as String, isOutgoing as Boolean) as Void {
        addMessageFull(targetId, sender, text, isOutgoing, null, isOutgoing ? true : false, isOutgoing ? STATUS_SENT_NODE : 0);
    }

    public static function addIncomingMessage(targetId as String, sender as String, text as String) as Void {
        addMessageFull(targetId, sender, text, false, null, false, 0);
    }

    public static function addMessageWithStatus(targetId as String, sender as String, text as String, isOutgoing as Boolean, status as Number) as Void {
        addMessageFull(targetId, sender, text, isOutgoing, null, isOutgoing ? true : false, status);
    }

    public static function addMessageWithTime(targetId as String, sender as String, text as String, isOutgoing as Boolean, customTime as Number?, isRead as Boolean?) as Void {
        addMessageFull(targetId, sender, text, isOutgoing, customTime, isRead, isOutgoing ? STATUS_CONFIRMED_MESH : 0);
    }

    public static function addMessageFull(targetId as String, sender as String, text as String, isOutgoing as Boolean, customTime as Number?, isRead as Boolean?, status as Number?) as Void {
        initializeHistory();

        var t = (customTime != null) ? customTime : Time.now().value();
        var readStatus = (isRead != null) ? isRead : (isOutgoing ? true : false);
        var msgStatus = (status != null) ? status : (isOutgoing ? STATUS_SENT_NODE : 0);

        var msg = {
            :targetId => targetId,
            :sender => sender,
            :text => text,
            :isOutgoing => isOutgoing,
            :time => t,
            :isRead => readStatus,
            :status => msgStatus
        };

        _messages.add(msg);

        while (_messages.size() > MAX_HISTORY) {
            _messages.remove(_messages[0]);
        }

        persistMessages();
    }

    private static function persistMessages() as Void {
        try {
            var serialized = [] as Array<Dictionary>;
            for (var mIdx = 0; mIdx < _messages.size(); mIdx++) {
                var m = _messages[mIdx];
                serialized.add({
                    "targetId" => m[:targetId],
                    "sender" => m[:sender],
                    "text" => m[:text],
                    "isOutgoing" => m[:isOutgoing],
                    "time" => m[:time],
                    "isRead" => m[:isRead],
                    "status" => (m.hasKey(:status) && m[:status] != null) ? m[:status] : 0
                });
            }
            Storage.setValue(STORAGE_KEY, serialized);
        } catch (e) {
            // ignore
        }
    }

    public static function getMessagesForTarget(targetId as String) as Array<Dictionary> {
        initializeHistory();
        var result = [] as Array<Dictionary>;

        for (var i = 0; i < _messages.size(); i++) {
            var m = _messages[i];
            var tid = m[:targetId] as String;
            if (tid.equals(targetId)) {
                result.add(m);
            }
        }
        return result;
    }

    public static function hasMessagesForTarget(targetId as String) as Boolean {
        initializeHistory();
        for (var i = 0; i < _messages.size(); i++) {
            var m = _messages[i];
            var tid = m[:targetId] as String;
            if (tid.equals(targetId)) {
                return true;
            }
        }
        return false;
    }

    public static function getLastMessageForTarget(targetId as String) as Dictionary? {
        initializeHistory();
        for (var i = _messages.size() - 1; i >= 0; i--) {
            var m = _messages[i];
            var tid = m[:targetId] as String;
            if (tid.equals(targetId)) {
                return m;
            }
        }
        return null;
    }

    public static function getUnreadCountForTarget(targetId as String) as Number {
        initializeHistory();
        var count = 0;
        for (var i = 0; i < _messages.size(); i++) {
            var m = _messages[i];
            var tid = m[:targetId] as String;
            var isOut = m[:isOutgoing] as Boolean;
            var isRead = (m.hasKey(:isRead) && m[:isRead] == true);
            if (tid.equals(targetId) && !isOut && !isRead) {
                count++;
            }
        }
        return count;
    }

    public static function markAsRead(targetId as String) as Void {
        initializeHistory();
        var changed = false;
        for (var i = 0; i < _messages.size(); i++) {
            var m = _messages[i];
            var tid = m[:targetId] as String;
            if (tid.equals(targetId)) {
                if (m.hasKey(:isRead) && !m[:isRead]) {
                    m[:isRead] = true;
                    changed = true;
                }
            }
        }
        if (changed) {
            persistMessages();
        }
    }

    public static function advanceOutgoingStatus(fromStatus as Number, toStatus as Number) as Boolean {
        initializeHistory();
        for (var i = 0; i < _messages.size(); i++) {
            var m = _messages[i];
            if (m[:isOutgoing] == true) {
                var st = (m.hasKey(:status) && m[:status] != null) ? (m[:status] as Number) : 0;
                if (st == fromStatus) {
                    m[:status] = toStatus;
                    persistMessages();
                    return true;
                }
            }
        }
        return false;
    }

    public static function updateLastOutgoingStatus(newStatus as Number) as Void {
        initializeHistory();
        for (var i = _messages.size() - 1; i >= 0; i--) {
            var m = _messages[i];
            if (m[:isOutgoing] == true) {
                var st = (m.hasKey(:status) && m[:status] != null) ? (m[:status] as Number) : 0;
                if (st < newStatus) {
                    m[:status] = newStatus;
                    persistMessages();
                    return;
                }
            }
        }
    }

    public static function formatTimeAgo(timestamp as Number) as String {
        var now = Time.now().value();
        var diff = now - timestamp;
        if (diff < 0) { diff = 0; }

        if (diff < 60) {
            return I18n.get(Rez.Strings.TimeJustNow);
        } else if (diff < 3600) {
            var min = (diff / 60).toNumber();
            return min.toString() + "m";
        } else {
            var hrs = (diff / 3600).toNumber();
            return hrs.toString() + "h";
        }
    }
}
