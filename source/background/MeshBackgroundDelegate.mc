import Toybox.System;
import Toybox.Background;
import Toybox.Notifications;
import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.Lang;

(:background)
class MeshBackgroundDelegate extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        System.println("MeshBackgroundDelegate: onTemporalEvent triggered");

        // Read configured background check interval (default 300s = 5 min)
        var intervalSecs = Storage.getValue("bgInterval");
        if (intervalSecs == null) {
            intervalSecs = 300;
        }

        // 0 = Aus / Disabled
        if (intervalSecs <= 0) {
            System.println("Background check disabled by user setting.");
            Background.exit(null);
            return;
        }

        // Check simulated or buffered incoming messages
        var simEnabled = Storage.getValue("sim_virtualNodeEnabled");
        if (simEnabled == null || simEnabled == true) {
            var missedCount = Storage.getValue("sim_pendingMsgCount");
            if (missedCount != null && (missedCount as Number) > 0) {
                var lastSender = Storage.getValue("sim_lastPendingSender") as String?;
                if (lastSender == null) { lastSender = "Alex"; }
                var lastMsg = Storage.getValue("sim_lastPendingMsg") as String?;
                if (lastMsg == null) { lastMsg = "Treffpunkt erreicht, alles OK!"; }

                var options = {
                    :body => lastMsg,
                    :dismissPrevious => true,
                    :actions => [
                        { :label => "Chat öffnen", :data => "ACTION_CHAT" },
                        { :label => "Antworten", :data => "ACTION_REPLY" }
                    ] as Array<Notifications.Action>
                };

                try {
                    Notifications.showNotification("Mesh: " + lastSender, "Eingehende Nachricht", options);
                    System.println("MeshBackgroundDelegate: notification posted for " + lastSender);
                } catch (e) {
                    System.println("MeshBackgroundDelegate: notification failed: " + e.getErrorMessage());
                }

                Storage.setValue("sim_pendingMsgCount", 0);
            }
        }

        // Reschedule next background execution according to user setting
        try {
            Background.registerForTemporalEvent(new Time.Duration(intervalSecs as Number));
        } catch (e) {
            System.println("MeshBackgroundDelegate: reschedule error: " + e.getErrorMessage());
        }

        Background.exit(true);
    }
}
