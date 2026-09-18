import Toybox.Lang;
import Toybox.Activity;
import Toybox.Position;
import Toybox.Time;
import Toybox.Math;
import Toybox.System;

class TelemetryAggregator {
    private static var _instance as TelemetryAggregator? = null;

    public var currentLat as Double? = null;
    public var currentLon as Double? = null;
    public var currentAlt as Float? = null;
    public var currentHr as Number? = null;
    public var currentSpeedKmh as Float? = null;
    public var totalDistanceMeters as Float? = null;

    public var hasGpsFix as Boolean = false;
    public var isStationary as Boolean = false;

    // Motion Detection State
    private var _lastFixLat as Double? = null;
    private var _lastFixLon as Double? = null;
    private var _lastFixTime as Number = 0;
    private var _stationaryCounter as Number = 0; // seconds below threshold

    // Buffered intermediate samples for bundling
    private var _bufferedSamples as Array<Dictionary> = [] as Array<Dictionary>;
    private var _lastSampleTime as Number = 0;

    public static function getInstance() as TelemetryAggregator {
        if (_instance == null) {
            _instance = new TelemetryAggregator();
        }
        return _instance as TelemetryAggregator;
    }

    function initialize() {
    }

    //! Ingest standard Activity.Info from compute(info)
    public function updateFromActivity(info as Activity.Info) as Void {
        var now = Time.now().value();

        // 1. Position & GPS Fix
        if (info.currentLocation != null) {
            var rad = info.currentLocation.toRadians();
            currentLat = rad[0] * 180.0 / Math.PI;
            currentLon = rad[1] * 180.0 / Math.PI;
            hasGpsFix = true;
        } else {
            try {
                var pInfo = Position.getInfo();
                if (pInfo != null && pInfo.position != null) {
                    var rad = pInfo.position.toRadians();
                    currentLat = rad[0] * 180.0 / Math.PI;
                    currentLon = rad[1] * 180.0 / Math.PI;
                    hasGpsFix = true;
                } else {
                    hasGpsFix = false;
                }
            } catch (e) {
                hasGpsFix = false;
            }
        }

        // 2. Altitude
        if (info.altitude != null) {
            currentAlt = info.altitude;
        }

        // 3. Heart Rate
        if (info.currentHeartRate != null) {
            currentHr = info.currentHeartRate;
        }

        // 4. Speed (convert m/s to km/h)
        if (info.currentSpeed != null && info.currentSpeed >= 0.0) {
            currentSpeedKmh = info.currentSpeed * 3.6;
        } else {
            currentSpeedKmh = 0.0;
        }

        // 5. Total Distance
        if (info.elapsedDistance != null) {
            totalDistanceMeters = info.elapsedDistance;
        }

        // 6. Evaluate Motion / Stillstand
        evaluateMotion(now);
    }

    private function evaluateMotion(now as Number) as Void {
        if (!hasGpsFix || currentLat == null || currentLon == null) {
            isStationary = false;
            return;
        }

        if (_lastFixLat == null || _lastFixLon == null) {
            _lastFixLat = currentLat;
            _lastFixLon = currentLon;
            _lastFixTime = now;
            isStationary = false;
            return;
        }

        // Approximate distance delta in meters (1 deg lat ~ 111,320m)
        var dLatMeters = ((currentLat as Double) - (_lastFixLat as Double)).abs() * 111320.0;
        var dLonMeters = ((currentLon as Double) - (_lastFixLon as Double)).abs() * 111320.0 * Math.cos((currentLat as Double) * Math.PI / 180.0);
        var distDelta = Math.sqrt((dLatMeters * dLatMeters) + (dLonMeters * dLonMeters));

        var speed = (currentSpeedKmh != null) ? (currentSpeedKmh as Float) : 0.0;

        // If speed < 1.8 km/h (0.5 m/s) and distance delta < 20 meters
        if (speed < 1.8 && distDelta < 20.0) {
            _stationaryCounter++;
            if (_stationaryCounter >= 15) { // 15 seconds stationary
                isStationary = true;
            }
        } else {
            // Significant motion detected
            _stationaryCounter = 0;
            isStationary = false;
            _lastFixLat = currentLat;
            _lastFixLon = currentLon;
            _lastFixTime = now;
        }

        // Periodic intermediate sampling for multi-sample bundling (every 30s)
        if (now - _lastSampleTime >= 30 && _bufferedSamples.size() < 6) {
            _lastSampleTime = now;
            var dt = (now - _lastFixTime).toNumber();
            var dLatInt = (((currentLat as Double) - (_lastFixLat as Double)) * 100000.0).toNumber();
            var dLonInt = (((currentLon as Double) - (_lastFixLon as Double)) * 100000.0).toNumber();
            var hrVal = (currentHr != null) ? (currentHr as Number) : 0;

            _bufferedSamples.add({
                :deltaTime => dt,
                :deltaLat => dLatInt,
                :deltaLon => dLonInt,
                :hr => hrVal
            });
        }
    }

    public function getBufferedSamples() as Array<Dictionary> {
        return _bufferedSamples;
    }

    public function flushBufferedSamples() as Array<Dictionary> {
        var copy = _bufferedSamples;
        _bufferedSamples = [] as Array<Dictionary>;
        return copy;
    }
}
