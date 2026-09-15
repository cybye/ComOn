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
                _messages = stored as Array<Dictionary>;
            }
        } catch (e) {
            _messages = [] as Array<Dictionary>;
        }

        // Pre-seed with helpful initial messages if empty
        if (_messages.size() == 0) {
            var now = Time.now().value();
            addMessage("CH_0", "Basisstation", "MeshCore Gateway online. Kanal 0 bereit.", false, now - 600);
            addMessage("CH_0", "Florian", "Funktest Bergwacht OK. Empfang sauber.", false, now - 180);
            addMessage("CT_NODE_COMP1", "Begleiter 1", "Bin 200m hinter dir am Steig.", false, now - 300);
        }
    }

    public static function addMessage(targetId as String, sender as String, text as String, isOutgoing as Boolean, customTime as Number?) as Void {
        initializeHistory();

        var t = (customTime != null) ? customTime : Time.now().value();
        var msg = {
            :targetId => targetId,
            :sender => sender,
            :text => text,
            :isOutgoing => isOutgoing,
            :time => t
        };

        _messages.add(msg);

        // Keep size within bounds (Ring buffer)
        while (_messages.size() > MAX_HISTORY) {
            _messages.remove(_messages[0]);
        }

        // Persist to storage
        try {
            Storage.setValue(STORAGE_KEY, _messages);
        } catch (e) {
            // ignore storage quota limits gracefully
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
