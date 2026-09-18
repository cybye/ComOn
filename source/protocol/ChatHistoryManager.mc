import Toybox.Lang;
import Toybox.Time;
import Toybox.Application.Storage;

class ChatHistoryManager {
    private static const STORAGE_KEY as String = "cfg_chat_history";
    private static const MAX_HISTORY as Number = 40;

    private static var _messages as Array<Dictionary> = [] as Array<Dictionary>;
    private static var _initialized as Boolean = false;

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
                    loaded.add({
                        :targetId => it["targetId"],
                        :sender => it["sender"],
                        :text => it["text"],
                        :isOutgoing => it["isOutgoing"],
                        :time => it["time"],
                        :isRead => it["isRead"]
                    });
                }
                _messages = loaded;
            }
        } catch (e) {
            _messages = [] as Array<Dictionary>;
        }

        // Pre-seed with initial messages if empty
        if (_messages.size() == 0) {
            var now = Time.now().value();
            addMessageWithTime("CH_0", "Basisstation", "Mesh Gateway online. Kanal 0 bereit.", false, now - 600, true);
            addMessageWithTime("CH_0", "Florian", "Funktest Bergwacht OK. Empfang sauber.", false, now - 180, false);
            addMessageWithTime("CH_0", "Ich", "Verstanden, danke!", true, now - 120, true);
            addMessageWithTime("CT_NODE_COMP1", "Begleiter 1", "Bin 200m hinter dir am Steig.", false, now - 300, false);
        }
    }

    public static function addMessage(targetId as String, sender as String, text as String, isOutgoing as Boolean) as Void {
        addMessageWithTime(targetId, sender, text, isOutgoing, null, isOutgoing ? true : false);
    }

    public static function addMessageWithTime(targetId as String, sender as String, text as String, isOutgoing as Boolean, customTime as Number?, isRead as Boolean?) as Void {
        initializeHistory();

        var t = (customTime != null) ? customTime : Time.now().value();
        var readStatus = (isRead != null) ? isRead : (isOutgoing ? true : false);

        var msg = {
            :targetId => targetId,
            :sender => sender,
            :text => text,
            :isOutgoing => isOutgoing,
            :time => t,
            :isRead => readStatus
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
                    "isRead" => m[:isRead]
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
            var read = (m has :isRead && m[:isRead] != null) ? (m[:isRead] as Boolean) : true;
            if (tid.equals(targetId) && !isOut && !read) {
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
                if (m has :isRead && !m[:isRead]) {
                    m[:isRead] = true;
                    changed = true;
                }
            }
        }
        if (changed) {
            persistMessages();
        }
    }

    public static function formatTimeAgo(timestamp as Number) as String {
        var now = Time.now().value();
        var diff = now - timestamp;
        if (diff < 0) { diff = 0; }

        if (diff < 60) {
            return "gerade";
        } else if (diff < 3600) {
            var min = (diff / 60).toNumber();
            return min.toString() + "m";
        } else {
            var hrs = (diff / 3600).toNumber();
            return hrs.toString() + "h";
        }
    }
}
