import Toybox.Notifications;
import Toybox.Lang;
import Toybox.Attention;
import Toybox.System;
import Toybox.WatchUi;

class MeshNotificationManager {
    private static var _instance as MeshNotificationManager? = null;

    public static function getInstance() as MeshNotificationManager {
        if (_instance == null) {
            _instance = new MeshNotificationManager();
        }
        return _instance as MeshNotificationManager;
    }

    function initialize() {
    }

    public function register() as Void {
        try {
            Notifications.registerForNotificationMessages(method(:onNotificationReceived));
        } catch (e) {
            System.println("Register notifications notice");
        }
    }

    public function showIncomingMessage(sender as String, text as String) as Void {
        // Haptic feedback
        if (Attention has :vibrate) {
            var vibeProfile = [ new Attention.VibeProfile(100, 300), new Attention.VibeProfile(0, 150), new Attention.VibeProfile(100, 300) ];
            Attention.vibrate(vibeProfile);
        }

        var options = {
            :body => text,
            :actions => [
                { :label => "Antworten", :data => "ACTION_REPLY" },
                { :label => "Position senden", :data => "ACTION_SEND_POS" },
                { :label => "Alles OK", :data => "ACTION_SEND_OK" },
                { :label => "Schließen", :data => "ACTION_DISMISS" }
            ] as Array<Notifications.Action>
        };

        try {
            Notifications.showNotification("Mesh: " + sender, "Eingehende Nachricht", options);
        } catch (e) {
            System.println("showNotification error");
            e.printStackTrace();
        }
    }

    public function onNotificationReceived(message as Notifications.NotificationMessage) as Void {
        if (message.type == Notifications.NOTIFICATION_MESSAGE_TYPE_SELECTED) {
            var actionId = message.action as String;
            var bleMgr = getBleManager();
            var chIdx = ContactManager.selectedChannelIdx;

            if (actionId.equals("ACTION_REPLY")) {
                var keyView = new QwertyKeyboardView("");
                WatchUi.pushView(keyView, new QwertyKeyboardDelegate(keyView), WatchUi.SLIDE_DOWN);
            } else if (actionId.equals("ACTION_SEND_POS")) {
                bleMgr.sendCurrentPosition(chIdx);
            } else if (actionId.equals("ACTION_SEND_OK")) {
                bleMgr.sendChannelText(chIdx, "Alles OK");
            }
        }
    }
}
