import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

(:background)
class MeshBackgroundInboxStore {
    private static const STORAGE_KEY as String = "cfg_chat_history";
    private static const MAX_HISTORY as Number = 40;

    public static function addIncomingMessage(targetId as String, sender as String, text as String) as Void {
        var messages = [] as Array<Dictionary>;
        var stored = Storage.getValue(STORAGE_KEY);
        if (stored instanceof Array) {
            messages = stored as Array<Dictionary>;
        }

        messages.add({
            "targetId" => targetId,
            "sender" => sender,
            "text" => text,
            "isOutgoing" => false,
            "time" => Time.now().value(),
            "isRead" => false,
            "status" => 0
        });
        while (messages.size() > MAX_HISTORY) {
            messages.remove(messages[0]);
        }
        Storage.setValue(STORAGE_KEY, messages);
    }
}