import Toybox.Lang;
import Toybox.Notifications;

(:background)
module NotificationBuilder {
    // Action IDs
    public const ACTION_LIST     as String = "ACTION_LIST";
    public const ACTION_CHAT     as String = "ACTION_CHAT";
    public const ACTION_REPLY    as String = "ACTION_REPLY";
    public const ACTION_SEND_POS as String = "ACTION_SEND_POS";
    public const ACTION_SEND_OK  as String = "ACTION_SEND_OK";
    public const ACTION_SEP      as String = "|";

    //! Construct action data string e.g. "ACTION_CHAT|CT_1A2B3C"
    public function makeActionData(baseAction as String, targetId as String?) as String {
        if (targetId == null || targetId.length() == 0) {
            return baseAction;
        }
        return baseAction + ACTION_SEP + targetId;
    }

    //! Parse an incoming action string into { :base => String, :targetId => String? }
    public function parseActionData(actionString as String?) as Dictionary {
        if (actionString == null || actionString.length() == 0) {
            return { :base => ACTION_LIST, :targetId => null };
        }
        var pipeIndex = actionString.find(ACTION_SEP);
        if (pipeIndex != null && pipeIndex > 0) {
            return {
                :base => actionString.substring(0, pipeIndex),
                :targetId => actionString.substring(pipeIndex + 1, actionString.length())
            };
        }
        return { :base => actionString, :targetId => null };
    }

    //! Build standard notification action array for a single target
    public function buildTargetActions(targetId as String, openChatLabel as String, replyLabel as String, posLabel as String, okLabel as String) as Array<Notifications.Action> {
        var actions = [] as Array<Notifications.Action>;
        actions.add({ :label => openChatLabel, :data => makeActionData(ACTION_CHAT, targetId) });
        actions.add({ :label => replyLabel,    :data => makeActionData(ACTION_REPLY, targetId) });
        actions.add({ :label => posLabel,      :data => makeActionData(ACTION_SEND_POS, targetId) });
        actions.add({ :label => okLabel,       :data => makeActionData(ACTION_SEND_OK, targetId) });
        return actions;
    }

    //! Format the notification title based on target prefix (#channel or @contact)
    public function formatNotificationTitle(targetId as String, sender as String, channelName as String?) as String {
        if (targetId.find("CH_") == 0) {
            var chName = (channelName != null) ? channelName : ("#" + targetId.substring(3, targetId.length()));
            return chName + ": " + sender;
        } else {
            return "@" + sender;
        }
    }
}
