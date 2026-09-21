import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

(:background)
class MeshBackgroundDiagnostics {
    private static const STORAGE_KEY as String = "cfg_bg_diagnostics_v1";

    public static function startRun(mode as String) as Number {
        var runId = 1;
        var stored = Storage.getValue(STORAGE_KEY);
        if (stored instanceof Dictionary && stored.hasKey("runId") && stored["runId"] != null) {
            runId = (stored["runId"] as Number) + 1;
        }

        Storage.setValue(STORAGE_KEY, {
            "version" => 1,
            "runId" => runId,
            "mode" => mode,
            "state" => "triggered",
            "outcome" => "running",
            "startedAt" => Time.now().value(),
            "endedAt" => null,
            "connected" => false,
            "messages" => 0
        });
        return runId;
    }

    public static function setState(runId as Number, state as String) as Void {
        var stored = Storage.getValue(STORAGE_KEY);
        if (!(stored instanceof Dictionary) || !stored.hasKey("runId") || stored["runId"] != runId) {
            return;
        }
        stored["state"] = state;
        Storage.setValue(STORAGE_KEY, stored);
    }

    public static function finishRun(runId as Number, outcome as String, connected as Boolean, messages as Number) as Void {
        var stored = Storage.getValue(STORAGE_KEY);
        if (!(stored instanceof Dictionary) || !stored.hasKey("runId") || stored["runId"] != runId) {
            return;
        }
        stored["state"] = "complete";
        stored["outcome"] = outcome;
        stored["endedAt"] = Time.now().value();
        stored["connected"] = connected;
        stored["messages"] = messages;
        Storage.setValue(STORAGE_KEY, stored);
    }

    public static function getLatest() as Dictionary? {
        var stored = Storage.getValue(STORAGE_KEY);
        return (stored instanceof Dictionary) ? (stored as Dictionary) : null;
    }
}