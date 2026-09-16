import Toybox.Notifications;
import Toybox.Lang;
import Toybox.Attention;
import Toybox.System;
import Toybox.WatchUi;

class MeshNotificationManager {
    private static var _instance as MeshNotificationManager? = null;
    private var _lastSender as String = "Mesh";
    private var _lastTargetId as String = "CH_0";

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

    public function showIncomingMessage(sender as String, text as String, targetId as String or Null) as Void {
        _lastSender = sender;
        _lastTargetId = (targetId != null) ? targetId : (ContactManager.isContactTarget ? ("CT_" + ContactManager.selectedContactId) : ("CH_" + ContactManager.selectedChannelIdx));

        // Haptic feedback
        try {
            if (Attention has :vibrate) {
                var vibeProfile = [ new Attention.VibeProfile(100, 250), new Attention.VibeProfile(0, 100), new Attention.VibeProfile(100, 250) ];
                Attention.vibrate(vibeProfile);
            }
        } catch (e) {
            // ignore
        }

        var options = {
            :body => text,
            :dismissPrevious => true,
            :actions => [
                { :label => "Chat öffnen", :data => "ACTION_CHAT" },
                { :label => "Antworten", :data => "ACTION_REPLY" },
                { :label => "Position senden", :data => "ACTION_SEND_POS" },
                { :label => "Alles OK", :data => "ACTION_SEND_OK" }
            ] as Array<Notifications.Action>
        };

        System.println("MeshNotificationManager: showNotification called for " + sender + " - " + text);
        try {
            Notifications.showNotification("Mesh: " + sender, "Eingehende Nachricht", options);
            System.println("MeshNotificationManager: showNotification succeeded");
        } catch (e) {
            System.println("MeshNotificationManager: showNotification error: " + e.getErrorMessage());
            e.printStackTrace();
        }
    }

    public function onNotificationReceived(message as Notifications.NotificationMessage) as Void {
        if (message.type == Notifications.NOTIFICATION_MESSAGE_TYPE_SELECTED) {
            var actionId = message.action as String;
            var bleMgr = getBleManager();
            var chIdx = ContactManager.selectedChannelIdx;

            // Ensure contact is selected if it's a known contact
            if (!_lastSender.equals("Mesh") && !_lastSender.equals("Node (Echo)")) {
                ContactManager.selectContact(_lastSender, _lastSender);
            }

            if (actionId.equals("ACTION_CHAT")) {
                var view = new ChatThreadView(_lastTargetId, _lastSender);
                WatchUi.pushView(view, new ChatThreadDelegate(view), WatchUi.SLIDE_LEFT);
            } else if (actionId.equals("ACTION_REPLY")) {
                var view = new ChatThreadView(_lastTargetId, _lastSender);
                WatchUi.pushView(view, new ChatThreadDelegate(view), WatchUi.SLIDE_LEFT);
                WatchUi.pushView(new CannedMessageMenu(), new CannedMessageDelegate(), WatchUi.SLIDE_LEFT);
            } else if (actionId.equals("ACTION_SEND_POS")) {
                bleMgr.sendCurrentPosition(chIdx);
            } else if (actionId.equals("ACTION_SEND_OK")) {
                bleMgr.sendChannelText(chIdx, "Alles OK");
            }
        }
    }
}
