import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

(:background)
class MeshBackgroundInboxStore {
    private static const STORAGE_KEY as String = StorageKeys.BG_PENDING_MESSAGES;
    private static const MAX_BG_HISTORY as Number = 10;

    public static function addIncomingMessage(targetId as String, sender as String, text as String) as Void {
        if (text == null || text.length() == 0 || (sender.equals("Mesh") && text.length() < 2)) {
            return;
        }
        try {
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
            while (messages.size() > MAX_BG_HISTORY) {
                messages.remove(messages[0]);
            }
            Storage.setValue(STORAGE_KEY, messages);
        } catch (e) {
            System.println("MeshBackgroundInboxStore error: " + e.getErrorMessage());
        }
    }
}
