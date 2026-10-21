import Toybox.Notifications;
import Toybox.Lang;
import Toybox.Attention;
import Toybox.System;
import Toybox.WatchUi;

class MeshNotificationManager {
    private static var _instance as MeshNotificationManager? = null;
    private var _lastSender as String = "Mesh";
    private var _lastTargetId as String = "CH_0";
    private var _registered as Boolean = false;
    private var _pendingLaunchAction as String? = null;
    private var _lastHandledAction as String? = null;
    private var _lastHandledAt as Number = 0;

    public static function getInstance() as MeshNotificationManager {
        if (_instance == null) {
            _instance = new MeshNotificationManager();
        }
        return _instance as MeshNotificationManager;
    }

    function initialize() {
    }

    public function register() as Void {
        if (_pendingLaunchAction != null) {
            var launchAction = _pendingLaunchAction as String;
            _pendingLaunchAction = null;
            handleAction(launchAction);
        }
        if (_registered) {
            return;
        }
        _registered = true;
        try {
            Notifications.registerForNotificationMessages(method(:onNotificationReceived));
        } catch (e) {
            System.println("Register notifications notice");
        }
    }

    public function setPendingLaunchAction(action as String) as Void {
        _pendingLaunchAction = action;
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

        // Build descriptive notification title (e.g. "#public: Seb_Herb" or "@Alice")
        var channelName = null as String?;
        if (_lastTargetId.find("CH_") == 0) {
            var channelIndex = _lastTargetId.substring(3, _lastTargetId.length()).toNumber();
            var channels = ContactManager.getChannels();
            for (var c = 0; c < channels.size(); c++) {
                if (channels[c][:idx] == channelIndex) {
                    channelName = channels[c][:name] as String;
                    break;
                }
            }
        }
        var notifTitle = NotificationBuilder.formatNotificationTitle(_lastTargetId, sender, channelName);

        System.println("MeshNotificationManager: in-app toast for " + notifTitle + ": " + text);
        if (WatchUi has :showToast) {
            WatchUi.showToast(notifTitle + ": " + text, null);
        }
        if (WatchUi has :requestUpdate) {
            WatchUi.requestUpdate();
        }
    }

    public function selectTargetById(targetId as String) as Void {
        _lastTargetId = targetId;
        if (targetId.find("CH_") == 0) {
            var channelIndex = targetId.substring(3, targetId.length()).toNumber();
            var channelName = "#" + channelIndex;
            var channels = ContactManager.getChannels();
            for (var index = 0; index < channels.size(); index++) {
                if (channels[index][:idx] == channelIndex) {
                    channelName = channels[index][:name] as String;
                    break;
                }
            }
            ContactManager.selectChannel(channelIndex, channelName);
        } else if (targetId.find("CT_") == 0) {
            var contactId = targetId.substring(3, targetId.length());
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

    public function onNotificationReceived(message as Notifications.NotificationMessage) as Void {
        System.println("MeshNotificationManager: onNotificationReceived type=" + message.type + " action=" + message.action + " data=" + message.data);
        if (message.type == Notifications.NOTIFICATION_MESSAGE_TYPE_SELECTED) {
            var actionId = null as String?;
            if (message.action != null && message.action instanceof String) {
                actionId = message.action as String;
            } else if (message.data != null && message.data instanceof String) {
                actionId = message.data as String;
            }
            if (actionId == null) {
                actionId = NotificationBuilder.makeActionData(NotificationBuilder.ACTION_CHAT, _lastTargetId);
            }
            handleAction(actionId);
        }
    }

    private function handleAction(actionId as String) as Void {
        // The same selection can arrive via onStart state and the queued-message callback
        var now = System.getTimer();
        if (_lastHandledAction != null && (_lastHandledAction as String).equals(actionId) && now - _lastHandledAt < 5000) {
            return;
        }
        _lastHandledAction = actionId;
        _lastHandledAt = now;
        System.println("MeshNotificationManager: handling action " + actionId);

        var parsed = NotificationBuilder.parseActionData(actionId);
        var baseAction = parsed[:base] as String;
        var targetId = (parsed[:targetId] != null) ? (parsed[:targetId] as String) : _lastTargetId;

        if (baseAction.equals(NotificationBuilder.ACTION_LIST)) {
            // Launch already lands on the chat list
            return;
        } else if (baseAction.equals(NotificationBuilder.ACTION_CHAT)) {
            selectTargetById(targetId);
            var targetName = ContactManager.getTargetDisplayName();
            var view = new ChatThreadView(targetId, targetName);
            WatchUi.pushView(view, new ChatThreadDelegate(view), WatchUi.SLIDE_LEFT);
        } else if (baseAction.equals(NotificationBuilder.ACTION_REPLY)) {
            selectTargetById(targetId);
            var targetName = ContactManager.getTargetDisplayName();
            var view = new ChatThreadView(targetId, targetName);
            WatchUi.pushView(view, new ChatThreadDelegate(view), WatchUi.SLIDE_LEFT);
            WatchUi.pushView(CannedMessageMenu.createForTarget(targetId, targetName), new CannedMessageDelegate(targetId), WatchUi.SLIDE_LEFT);
        } else if (baseAction.equals(NotificationBuilder.ACTION_SEND_POS)) {
            selectTargetById(targetId);
            getBleManager().sendCurrentPositionToConversation(targetId);
        } else if (baseAction.equals(NotificationBuilder.ACTION_SEND_OK)) {
            selectTargetById(targetId);
            getBleManager().sendTextToConversation(targetId, I18n.get(Rez.Strings.CannedOk));
        }
    }
}
