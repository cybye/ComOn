import Toybox.System;
import Toybox.Background;
import Toybox.Notifications;
import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.Lang;

(:background)
class MeshBackgroundDelegate extends System.ServiceDelegate {
    // Foreground refreshes the timestamp every 60s; older means the app died without onStop
    private static const FOREGROUND_FLAG_MAX_AGE_SECS as Number = 180;
    // Temporal events cannot be scheduled closer than 5 minutes apart
    private static const MIN_TEMPORAL_SECS as Number = 300;
    // While DND is on, re-check at this interval without touching BLE
    private static const DND_RECHECK_SECS as Number = 1800;
    // Backoff for an unreachable node: starts after this many failed runs, capped at MAX_BACKOFF_SECS
    private static const BACKOFF_AFTER_FAILURES as Number = 3;
    private static const MAX_BACKOFF_SECS as Number = 3600;
    private var _poller as MeshBackgroundNodePoller? = null;
    private var _runId as Number = 0;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        System.println("MeshBackgroundDelegate: onTemporalEvent triggered");
        if (MeshBackgroundDiagnostics.wasPreviousRunUnfinished()) {
            // Previous poll never completed -> it was killed by the system time limit
            var killedStreak = readFailStreak() + 1;
            Storage.setValue(StorageKeys.BG_FAIL_STREAK, killedStreak);
            System.println("Background poll: previous run was terminated by the system (fail streak " + killedStreak + ")");
        }
        _runId = MeshBackgroundDiagnostics.startRun("temporal");

        var intervalSecs = configuredIntervalSecs();

        // 0 = Aus / Disabled
        if (intervalSecs <= 0) {
            System.println("Background check disabled by user setting.");
            MeshBackgroundDiagnostics.finishRun(_runId, "disabled", false, 0);
            Background.deleteTemporalEvent();
            Background.exit(null);
            return;
        }

        if (Storage.getValue(StorageKeys.FOREGROUND_ACTIVE) == true) {
            // Safety: if flag is stale (app crashed without calling onStop), ignore it
            var flaggedAt = Storage.getValue(StorageKeys.FOREGROUND_ACTIVE_AT);
            var isStale = false;
            if (flaggedAt instanceof Number) {
                var age = Time.now().value() - (flaggedAt as Number);
                if (age > FOREGROUND_FLAG_MAX_AGE_SECS) {
                    isStale = true;
                    System.println("Background poll: foreground flag is stale (" + age + "s old), clearing");
                    Storage.deleteValue(StorageKeys.FOREGROUND_ACTIVE);
                    Storage.deleteValue(StorageKeys.FOREGROUND_ACTIVE_AT);
                }
            } else {
                // No timestamp recorded — treat as stale to be safe
                isStale = true;
                Storage.deleteValue(StorageKeys.FOREGROUND_ACTIVE);
            }
            if (!isStale) {
                var outcome = (Storage.getValue(StorageKeys.SCHEDULER_PROBE) == true) ? "scheduler_probe" : "foreground_active";
                System.println("Background poll: skipped while ComOn foreground session is active");
                MeshBackgroundDiagnostics.finishRun(_runId, outcome, false, 0);
                completeBackgroundEvent(0, null, null, [] as Array<String>, intervalSecs);
                return;
            }
        }

        // Quiet hours: no notification would be noticed, so do not wake the BLE radio at all.
        // Checked before any BLE setup; costs only a profile/settings read.
        if (MeshQuietPolicy.isEnabled()) {
            var untilWake = MeshQuietPolicy.secondsUntilWake();
            if (untilWake > 0) {
                // Single wake-up shortly after the configured wake time, nothing in between
                System.println("Background poll: sleep window active, next check in " + untilWake + "s");
                MeshBackgroundDiagnostics.finishRun(_runId, "quiet_sleep", false, 0);
                completeBackgroundEvent(0, null, null, [] as Array<String>, untilWake + 60);
                return;
            }
            if (MeshQuietPolicy.isDndActive()) {
                System.println("Background poll: Do Not Disturb active, skipping");
                MeshBackgroundDiagnostics.finishRun(_runId, "quiet_dnd", false, 0);
                completeBackgroundEvent(0, null, null, [] as Array<String>, (intervalSecs > DND_RECHECK_SECS) ? intervalSecs : DND_RECHECK_SECS);
                return;
            }
        }

        MeshBackgroundDiagnostics.setState(_runId, "polling");
        _poller = new MeshBackgroundNodePoller(self);
        _poller.start();
    }

    private function configuredIntervalSecs() as Number {
        var intervalSecs = Storage.getValue(StorageKeys.BG_INTERVAL);
        return (intervalSecs instanceof Number) ? (intervalSecs as Number) : 300; // Default: 5 min
    }

    private function readFailStreak() as Number {
        var streak = Storage.getValue(StorageKeys.BG_FAIL_STREAK);
        return (streak instanceof Number) ? (streak as Number) : 0;
    }

    //! Doubles the interval for every failed run beyond BACKOFF_AFTER_FAILURES-1,
    //! e.g. 5 min -> 10 -> 20 -> 40 -> 60 (cap). Never shortens the configured interval.
    private function backoffIntervalSecs(intervalSecs as Number, failStreak as Number) as Number {
        if (failStreak < BACKOFF_AFTER_FAILURES || intervalSecs >= MAX_BACKOFF_SECS) {
            return intervalSecs;
        }
        var secs = intervalSecs;
        for (var i = BACKOFF_AFTER_FAILURES - 1; i < failStreak && secs < MAX_BACKOFF_SECS; i++) {
            secs *= 2;
        }
        return (secs > MAX_BACKOFF_SECS) ? MAX_BACKOFF_SECS : secs;
    }

    public function onPollComplete(messageCount as Number, lastSender as String?, lastMessage as String?, lastNotificationTitle as String?, connectedToNode as Boolean, targetIds as Array<String>, polledBatteryPercent as Number?) as Void {
        var outcome = connectedToNode ? ((messageCount > 0) ? "messages" : "empty") : "node_unavailable";
        MeshBackgroundDiagnostics.finishRun(_runId, outcome, connectedToNode, messageCount);
        var failStreak = connectedToNode ? 0 : (readFailStreak() + 1);
        Storage.setValue(StorageKeys.BG_FAIL_STREAK, failStreak);
        var nextIntervalSecs = backoffIntervalSecs(configuredIntervalSecs(), failStreak);
        if (failStreak >= BACKOFF_AFTER_FAILURES) {
            System.println("Background poll: node unreachable " + failStreak + "x, backing off to " + nextIntervalSecs + "s");
        }
        if (connectedToNode) {
            Storage.deleteValue(StorageKeys.BG_NODE_UNAVAILABLE_NOTIFIED);
        } else if (Storage.getValue(StorageKeys.BG_NODE_UNAVAILABLE_NOTIFIED) != true) {
            try {
                Notifications.showNotification("ComOn", "Node unavailable", { :body => "Background check could not connect to the node.", :dismissPrevious => true });
                Storage.setValue(StorageKeys.BG_NODE_UNAVAILABLE_NOTIFIED, true);
                System.println("MeshBackgroundDelegate: posted node-unavailable notification");
            } catch (e) {
                System.println("MeshBackgroundDelegate: node-unavailable notification failed: " + e.getErrorMessage());
            }
        }
        if (polledBatteryPercent != null) {
            var pct = polledBatteryPercent as Number;
            if (pct <= 15) {
                if (Storage.getValue(StorageKeys.BG_LOW_BATTERY_NOTIFIED) != true) {
                    try {
                        Notifications.showNotification("ComOn", "Node Battery low", { :body => "MeshCore Node battery low at " + pct + "%", :dismissPrevious => false });
                        Storage.setValue(StorageKeys.BG_LOW_BATTERY_NOTIFIED, true);
                        System.println("MeshBackgroundDelegate: posted low-battery notification (" + pct + "%)");
                    } catch (e) {
                        System.println("MeshBackgroundDelegate: low-battery notification failed: " + e.getErrorMessage());
                    }
                }
            } else if (pct > 20) {
                Storage.deleteValue(StorageKeys.BG_LOW_BATTERY_NOTIFIED);
            }
        }
        if (messageCount > 0 && lastSender != null && lastMessage != null) {
            try {
                var body = lastMessage as String;
                if (messageCount > 1) {
                    var batchTemplate = Storage.getValue(StorageKeys.NOTIF_INCOMING_BATCH);
                    if (batchTemplate == null) {
                        batchTemplate = "$1$s new messages";
                    }
                    body = Lang.format(batchTemplate as String, [ messageCount.format("%d") ]) + "\n" + body;
                }
                var actions = [] as Array<Notifications.Action>;
                var primaryData = NotificationBuilder.ACTION_LIST;
                if (targetIds.size() == 1) {
                    primaryData = NotificationBuilder.makeActionData(NotificationBuilder.ACTION_CHAT, targetIds[0]);
                    actions = NotificationBuilder.buildTargetActions(
                        targetIds[0],
                        storedLabel(StorageKeys.NOTIF_OPEN_CHAT, "Open Chat"),
                        storedLabel(StorageKeys.NOTIF_REPLY, "Reply"),
                        storedLabel(StorageKeys.NOTIF_POSITION, "Position"),
                        storedLabel(StorageKeys.NOTIF_OK, "OK")
                    );
                } else {
                    var openChatsLabel = storedLabel(StorageKeys.NOTIF_OPEN_CHATS, "Open Chats");
                    actions.add({ :label => openChatsLabel, :data => NotificationBuilder.ACTION_LIST });
                }
                var notificationTitle = (lastNotificationTitle != null) ? lastNotificationTitle : ("Mesh: " + lastSender);
                var subTitle = storedLabel(StorageKeys.NOTIF_INCOMING_MSG, "Incoming message");
                Notifications.showNotification(notificationTitle, subTitle, {
                    :body => body,
                    :data => primaryData,
                    :dismissPrevious => true,
                    :actions => actions
                });
            } catch (e) {
                System.println("MeshBackgroundDelegate: notification failed: " + e.getErrorMessage());
            }
        }
        completeBackgroundEvent(messageCount, lastSender, lastMessage, targetIds, nextIntervalSecs);
    }

    private function storedLabel(key as String, fallback as String) as String {
        var value = Storage.getValue(key);
        return (value instanceof String) ? (value as String) : fallback;
    }

    //! Re-registers the recurring temporal event with the given interval and exits.
    //! A recurring Duration (rather than a one-shot Moment) is used on purpose: if a
    //! later run dies before rescheduling, the event still keeps firing.
    private function completeBackgroundEvent(messageCount as Number, lastSender as String?, lastMessage as String?, targetIds as Array<String>, nextIntervalSecs as Number) as Void {
        var sender = (lastSender != null) ? lastSender : "";
        var message = (lastMessage != null) ? lastMessage : "";
        try {
            if (nextIntervalSecs > 0) {
                var secs = (nextIntervalSecs < MIN_TEMPORAL_SECS) ? MIN_TEMPORAL_SECS : nextIntervalSecs;
                Background.registerForTemporalEvent(new Time.Duration(secs));
            }
        } catch (e) {
            System.println("MeshBackgroundDelegate: reschedule error: " + e.getErrorMessage());
        }

        Background.exit({ "messageCount" => messageCount, "lastSender" => sender, "lastMessage" => message, "targetIds" => targetIds });
    }
}
