import Toybox.Lang;
import Toybox.Time;
import Toybox.System;
import Toybox.Application.Storage;

class TelemetryDispatcher {
    private static var _instance as TelemetryDispatcher? = null;

    public var baseIntervalSecs as Number = 60;
    public var stationaryIntervalSecs as Number = 300;

    public var secondsSinceLastSend as Number = 0;
    public var lastSendStatus as String = "Bereit";
    public var totalPacketsSent as Number = 0;

    private var _wasStationary as Boolean = false;

    public static function getInstance() as TelemetryDispatcher {
        if (_instance == null) {
            _instance = new TelemetryDispatcher();
        }
        return _instance as TelemetryDispatcher;
    }

    function initialize() {
    }

    //! Evaluated every second from compute(info)
    public function tick(bleManager as MeshBleManager) as Void {
        secondsSinceLastSend++;

        var agg = TelemetryAggregator.getInstance();

        // Check if movement just resumed after stationary -> immediate update trigger!
        if (_wasStationary && !agg.isStationary && agg.hasGpsFix) {
            System.println("TelemetryDispatcher: Movement resumed! Triggering immediate beacon.");
            dispatchTelemetry(bleManager);
            _wasStationary = false;
            return;
        }
        _wasStationary = agg.isStationary;

        // Determine current interval threshold
        var currentThreshold = agg.isStationary ? stationaryIntervalSecs : baseIntervalSecs;

        if (secondsSinceLastSend >= currentThreshold) {
            dispatchTelemetry(bleManager);
        }
    }

    public function dispatchTelemetry(bleManager as MeshBleManager) as Boolean {
        var agg = TelemetryAggregator.getInstance();
        if (!agg.hasGpsFix || agg.currentLat == null || agg.currentLon == null) {
            lastSendStatus = "Kein GPS";
            return false;
        }

        secondsSinceLastSend = 0;

        // Check configured telemetry format (0 = Binary, 1 = ASCII Text)
        var fmt = Storage.getValue("telemetryFormat");
        if (fmt == null) { fmt = 0; }

        var chIdx = ContactManager.selectedChannelIdx;
        var isDirect = ContactManager.isContactTarget;
        var targetName = ContactManager.getTargetDisplayName();

        var success = false;

        if ((fmt as Number) == 0) {
            // Option 1: Ultra-compact Binary format
            var batPct = System.getSystemStats().battery.toNumber();
            var buffered = agg.flushBufferedSamples();

            var packetBytes = null;
            if (buffered.size() > 0) {
                // Multi-sample bundle
                packetBytes = MeshProtocol.encodeMultiSampleTelemetry(
                    agg.currentLat as Double,
                    agg.currentLon as Double,
                    (agg.currentAlt != null) ? (agg.currentAlt as Float) : 0.0,
                    (agg.currentHr != null) ? (agg.currentHr as Number) : 0,
                    buffered
                );
            } else {
                // Single fix frame
                packetBytes = MeshProtocol.encodeBinaryTelemetry(
                    agg.currentLat,
                    agg.currentLon,
                    agg.currentAlt,
                    agg.currentHr,
                    agg.currentSpeedKmh,
                    batPct,
                    agg.isStationary,
                    false
                );
            }

            success = bleManager.sendRaw(packetBytes);
            lastSendStatus = success ? ("Binär -> " + targetName) : "Sendefehler";
        } else {
            // Option 2: Human-readable ASCII Text format
            var text = MeshProtocol.formatDetailedPositionString(
                agg.currentLat,
                agg.currentLon,
                agg.currentAlt,
                agg.currentHr,
                agg.currentSpeedKmh,
                agg.isStationary,
                false
            );

            success = bleManager.sendChannelText(chIdx, text);
            lastSendStatus = success ? ("Text -> " + targetName) : "Sendefehler";
        }

        if (success) {
            totalPacketsSent++;
        }

        return success;
    }
}
