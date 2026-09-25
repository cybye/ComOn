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
                { :label => I18n.get(Rez.Strings.NotifActionOpenChat), :data => "ACTION_CHAT" },
                { :label => I18n.get(Rez.Strings.NotifActionReply), :data => "ACTION_REPLY" },
                { :label => I18n.get(Rez.Strings.NotifActionPosition), :data => "ACTION_SEND_POS" },
                { :label => I18n.get(Rez.Strings.NotifActionOk), :data => "ACTION_SEND_OK" }
            ] as Array<Notifications.Action>
        };

        // Build descriptive notification title (e.g. "#public: Seb_Herb" or "@Alice")
        var notifTitle = sender;
        if (_lastTargetId.find("CH_") == 0) {
            var channelIndex = _lastTargetId.substring(3, _lastTargetId.length()).toNumber();
            var chName = "#" + channelIndex;
            var channels = ContactManager.getChannels();
            for (var c = 0; c < channels.size(); c++) {
                if (channels[c][:idx] == channelIndex) {
                    chName = channels[c][:name] as String;
                    break;
                }
            }
            notifTitle = chName + ": " + sender;
        } else {
            notifTitle = "@" + sender;
        }

        System.println("MeshNotificationManager: showNotification called for " + notifTitle + " - " + text);
        try {
            Notifications.showNotification(notifTitle, I18n.get(Rez.Strings.NotifIncomingMsg), options);
            System.println("MeshNotificationManager: showNotification succeeded");
        } catch (e) {
            System.println("MeshNotificationManager: showNotification error: " + e.getErrorMessage());
            e.printStackTrace();
        }
    }

    public function onNotificationReceived(message as Notifications.NotificationMessage) as Void {
        if (message.type == Notifications.NOTIFICATION_MESSAGE_TYPE_SELECTED) {
            var actionId = message.action as String;
            if (actionId.find("ACTION_CHAT|") == 0) {
                _lastTargetId = actionId.substring(12, actionId.length());
                actionId = "ACTION_CHAT";
            }

            if (actionId.equals("ACTION_LIST")) {
                var listView = new ChatsListView();
                WatchUi.pushView(listView, new ChatsListDelegate(listView), WatchUi.SLIDE_LEFT);
            } else if (actionId.equals("ACTION_CHAT")) {
                selectNotificationTarget();
                var targetName = ContactManager.getTargetDisplayName();
                var view = new ChatThreadView(_lastTargetId, targetName);
                WatchUi.pushView(view, new ChatThreadDelegate(view), WatchUi.SLIDE_LEFT);
            } else if (actionId.equals("ACTION_REPLY")) {
                selectNotificationTarget();
                var targetName = ContactManager.getTargetDisplayName();
                var view = new ChatThreadView(_lastTargetId, targetName);
                WatchUi.pushView(view, new ChatThreadDelegate(view), WatchUi.SLIDE_LEFT);
                WatchUi.pushView(CannedMessageMenu.createForTarget(_lastTargetId, targetName), new CannedMessageDelegate(_lastTargetId), WatchUi.SLIDE_LEFT);
            } else if (actionId.equals("ACTION_SEND_POS")) {
                var bleMgr = getBleManager();
                selectNotificationTarget();
                var chIdx = ContactManager.selectedChannelIdx;
                bleMgr.sendCurrentPosition(chIdx);
            } else if (actionId.equals("ACTION_SEND_OK")) {
                var bleMgr = getBleManager();
                selectNotificationTarget();
                var chIdx = ContactManager.selectedChannelIdx;
                bleMgr.sendChannelText(chIdx, I18n.get(Rez.Strings.CannedOk));
            }
        }
    }

    private function selectNotificationTarget() as Void {
        if (_lastTargetId.find("CH_") == 0) {
            var channelIndex = _lastTargetId.substring(3, _lastTargetId.length()).toNumber();
            var channelName = "#" + channelIndex;
            var channels = ContactManager.getChannels();
            for (var index = 0; index < channels.size(); index++) {
                if (channels[index][:idx] == channelIndex) {
                    channelName = channels[index][:name] as String;
                    break;
                }
            }
            ContactManager.selectChannel(channelIndex, channelName);
        } else if (_lastTargetId.find("CT_") == 0) {
            var contactId = _lastTargetId.substring(3, _lastTargetId.length());
            var contactName = _lastSender;
            var contacts = ContactManager.getClientContacts();
            for (var index = 0; index < contacts.size(); index++) {
                var storedContactId = contacts[index][:id] as String;
                var normalizedStoredId = storedContactId.toUpper();
                var normalizedTargetId = contactId.toUpper();
                if (normalizedStoredId.equals(normalizedTargetId) || normalizedStoredId.find(normalizedTargetId) == 0) {
                    contactId = storedContactId;
                    contactName = contacts[index][:name] as String;
                    break;
                }
            }
            ContactManager.selectContact(contactId, contactName);
        }
    }
}
