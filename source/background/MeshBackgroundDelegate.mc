import Toybox.System;
import Toybox.Background;
import Toybox.Notifications;
import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.Lang;

(:background)
class MeshBackgroundDelegate extends System.ServiceDelegate {
    private static const STORAGE_NODE_UNAVAILABLE_NOTIFIED as String = "cfg_bg_node_unavailable_notified";
    private static const STORAGE_FOREGROUND_ACTIVE as String = "cfg_foreground_active";
    private static const STORAGE_SCHEDULER_PROBE as String = "cfg_bg_scheduler_probe";
    private static const STORAGE_NOTIF_INCOMING_BATCH as String = "cfg_notif_incoming_batch";
    private static const STORAGE_NOTIF_OPEN_CHAT as String = "cfg_notif_open_chat";
    private static const STORAGE_NOTIF_OPEN_CHATS as String = "cfg_notif_open_chats";
    private var _poller as MeshBackgroundNodePoller? = null;
    private var _runId as Number = 0;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        System.println("MeshBackgroundDelegate: onTemporalEvent triggered");
        _runId = MeshBackgroundDiagnostics.startRun("temporal");

        // Read configured background check interval (default 300s = 5 min)
        var intervalSecs = Storage.getValue("bgInterval");
        if (intervalSecs == null) {
            intervalSecs = 300;
        }

        // 0 = Aus / Disabled
        if (intervalSecs <= 0) {
            System.println("Background check disabled by user setting.");
            MeshBackgroundDiagnostics.finishRun(_runId, "disabled", false, 0);
            Background.deleteTemporalEvent();
            Background.exit(null);
            return;
        }

        if (Storage.getValue(STORAGE_FOREGROUND_ACTIVE) == true) {
            var outcome = (Storage.getValue(STORAGE_SCHEDULER_PROBE) == true) ? "scheduler_probe" : "foreground_active";
            System.println("Background poll: skipped while ComOn foreground session is active");
            MeshBackgroundDiagnostics.finishRun(_runId, outcome, false, 0);
            completeBackgroundEvent(0, null, null, [] as Array<String>);
            return;
        }

        MeshBackgroundDiagnostics.setState(_runId, "polling");
        _poller = new MeshBackgroundNodePoller(self);
        _poller.start();
    }

    public function onPollComplete(messageCount as Number, lastSender as String?, lastMessage as String?, lastNotificationTitle as String?, connectedToNode as Boolean, targetIds as Array<String>) as Void {
        var outcome = connectedToNode ? ((messageCount > 0) ? "messages" : "empty") : "node_unavailable";
        MeshBackgroundDiagnostics.finishRun(_runId, outcome, connectedToNode, messageCount);
        if (connectedToNode) {
            Storage.deleteValue(STORAGE_NODE_UNAVAILABLE_NOTIFIED);
        } else if (Storage.getValue(STORAGE_NODE_UNAVAILABLE_NOTIFIED) != true) {
            try {
                Notifications.showNotification("ComOn", "Node unavailable", { :body => "Background check could not connect to the node.", :dismissPrevious => true });
                Storage.setValue(STORAGE_NODE_UNAVAILABLE_NOTIFIED, true);
                System.println("MeshBackgroundDelegate: posted node-unavailable notification");
            } catch (e) {
                System.println("MeshBackgroundDelegate: node-unavailable notification failed: " + e.getErrorMessage());
            }
        }
        if (messageCount > 0 && lastSender != null && lastMessage != null) {
            try {
                var body = lastMessage as String;
                if (messageCount > 1) {
                    var batchTemplate = Storage.getValue(STORAGE_NOTIF_INCOMING_BATCH);
                    if (batchTemplate == null) {
                        batchTemplate = "$1$s new messages";
                    }
                    body = Lang.format(batchTemplate as String, [ messageCount.format("%d") ]) + "\n" + body;
                }
                var actions = [] as Array<Notifications.Action>;
                if (targetIds.size() == 1) {
                    var openChatLabel = Storage.getValue(STORAGE_NOTIF_OPEN_CHAT);
                    if (openChatLabel == null) {
                        openChatLabel = "Open Chat";
                    }
                    actions.add({ :label => openChatLabel as String, :data => "ACTION_CHAT|" + targetIds[0] });
                } else if (targetIds.size() > 1) {
                    var openChatsLabel = Storage.getValue(STORAGE_NOTIF_OPEN_CHATS);
                    if (openChatsLabel == null) {
                        openChatsLabel = "Open Chats";
                    }
                    actions.add({ :label => openChatsLabel as String, :data => "ACTION_LIST" });
                }
                var notificationTitle = (lastNotificationTitle != null) ? lastNotificationTitle : ("Mesh: " + lastSender);
                Notifications.showNotification(notificationTitle, "Eingehende Nachricht", { :body => body, :dismissPrevious => true, :actions => actions });
            } catch (e) {
                System.println("MeshBackgroundDelegate: notification failed: " + e.getErrorMessage());
            }
        }
        completeBackgroundEvent(messageCount, lastSender, lastMessage, targetIds);
    }

    private function completeBackgroundEvent(messageCount as Number, lastSender as String?, lastMessage as String?, targetIds as Array<String>) as Void {
        var intervalSecs = Storage.getValue("bgInterval");
        if (intervalSecs == null) {
            intervalSecs = 300;
        }
        var sender = (lastSender != null) ? lastSender : "";
        var message = (lastMessage != null) ? lastMessage : "";
        try {
            if ((intervalSecs as Number) > 0) {
                Background.registerForTemporalEvent(new Time.Duration(intervalSecs as Number));
            }
        } catch (e) {
            System.println("MeshBackgroundDelegate: reschedule error: " + e.getErrorMessage());
        }

        Background.exit({ "messageCount" => messageCount, "lastSender" => sender, "lastMessage" => message, "targetIds" => targetIds });
    }
}
