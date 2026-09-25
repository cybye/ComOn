import Toybox.Lang;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.ActivityMonitor;
import Toybox.System;
import Toybox.Math;

class TelemetryProvider {
    public var currentLat as Double? = null;
    public var currentLon as Double? = null;
    public var currentAlt as Float? = null;
    public var hasGpsFix as Boolean = false;

    private static var _instance as TelemetryProvider? = null;

    public static function getInstance() as TelemetryProvider {
        if (_instance == null) {
            _instance = new TelemetryProvider();
        }
        return _instance as TelemetryProvider;
    }

    function initialize() {
    }

    public function startTracking() as Void {
        try {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        } catch (e) {
            System.println("TelemetryProvider: enableLocationEvents error: " + e.getErrorMessage());
        }
        refreshPosition();
    }

    public function stopTracking() as Void {
        try {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        } catch (e) {
            // ignore
        }
    }

    public function refreshPosition() as Void {
        try {
            var info = Position.getInfo();
            if (info != null && info.position != null) {
                onPosition(info);
            }
        } catch (e) {
            // ignore
        }
    }

    public function onPosition(info as Position.Info) as Void {
        if (info != null && info.position != null) {
            var rad = info.position.toRadians();
            currentLat = rad[0] * 180.0 / Math.PI;
            currentLon = rad[1] * 180.0 / Math.PI;
            if (info.altitude != null) {
                currentAlt = info.altitude;
            }
            hasGpsFix = true;
            System.println("TelemetryProvider: GPS fix updated -> " + currentLat + ", " + currentLon + " (acc=" + info.accuracy + ")");
        } else {
            hasGpsFix = false;
        }
    }

    public function getHeartRate() as Number? {
        var sensorInfo = Sensor.getInfo();
        if (sensorInfo != null && sensorInfo.heartRate != null) {
            return sensorInfo.heartRate;
        }
        return null;
    }

    public function getSteps() as Number? {
        var actInfo = ActivityMonitor.getInfo();
        if (actInfo != null && actInfo.steps != null) {
            return actInfo.steps;
        }
        return null;
    }

    public function getBatteryPercent() as Float {
        var stats = System.getSystemStats();
        return stats.battery;
    }

    public function getFormattedPosition() as String {
        return MeshProtocol.formatPositionString(currentLat, currentLon, currentAlt, getHeartRate(), getSteps());
    }

    public function getFormattedSos() as String {
        return MeshProtocol.formatSosString(currentLat, currentLon, currentAlt, getHeartRate());
    }
}
