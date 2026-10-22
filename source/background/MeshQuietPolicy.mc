import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.UserProfile;

//! Decides whether a background poll is pointless because the user would not
//! see a notification anyway (scheduled sleep window or Do Not Disturb).
//!
//! The sleep window is taken from the user's configured sleep/wake times in
//! Garmin Connect, not from Garmin's sleep *detection*. That way the poller
//! stands down before sleep is detected and cannot interfere with detection.
(:background)
module MeshQuietPolicy {
    const SECS_PER_DAY as Number = 86400;

    //! Quiet mode is on unless the user explicitly disabled it.
    function isEnabled() as Boolean {
        return Storage.getValue(StorageKeys.BG_QUIET_MODE) != false;
    }

    //! Reads profile sleep/wake times and saves them into persistent storage.
    //! Safe to call from both foreground and background contexts.
    function updateSleepCache() as Void {
        try {
            var profile = UserProfile.getProfile();
            if (profile != null && (profile has :sleepTime) && (profile has :wakeTime)) {
                var sleepTime = profile.sleepTime;
                var wakeTime = profile.wakeTime;
                if ((sleepTime instanceof Time.Duration) && (wakeTime instanceof Time.Duration)) {
                    var sleepSecs = (sleepTime as Time.Duration).value() % SECS_PER_DAY;
                    var wakeSecs = (wakeTime as Time.Duration).value() % SECS_PER_DAY;
                    Storage.setValue(StorageKeys.CACHED_SLEEP_SECS, sleepSecs);
                    Storage.setValue(StorageKeys.CACHED_WAKE_SECS, wakeSecs);
                }
            }
        } catch (e) {
            // Profile read may fail defensively in background
        }
    }

    //! Seconds until the configured sleep window ends, or 0 when the current
    //! time is outside the window (or neither live profile nor cached values exist).
    function secondsUntilWake() as Number {
        var sleepSecs = null as Number?;
        var wakeSecs = null as Number?;

        try {
            var profile = UserProfile.getProfile();
            if (profile != null && (profile has :sleepTime) && (profile has :wakeTime)) {
                var sleepTime = profile.sleepTime;
                var wakeTime = profile.wakeTime;
                if ((sleepTime instanceof Time.Duration) && (wakeTime instanceof Time.Duration)) {
                    sleepSecs = (sleepTime as Time.Duration).value() % SECS_PER_DAY;
                    wakeSecs = (wakeTime as Time.Duration).value() % SECS_PER_DAY;
                    Storage.setValue(StorageKeys.CACHED_SLEEP_SECS, sleepSecs);
                    Storage.setValue(StorageKeys.CACHED_WAKE_SECS, wakeSecs);
                }
            }
        } catch (e) {
            System.println("MeshQuietPolicy: live sleep window read failed: " + e.getErrorMessage());
        }

        // Fallback to cached profile values if live UserProfile read returned null or unpopulated
        if (sleepSecs == null || wakeSecs == null) {
            var cachedSleep = Storage.getValue(StorageKeys.CACHED_SLEEP_SECS);
            var cachedWake = Storage.getValue(StorageKeys.CACHED_WAKE_SECS);
            if (cachedSleep instanceof Number && cachedWake instanceof Number) {
                sleepSecs = cachedSleep as Number;
                wakeSecs = cachedWake as Number;
            }
        }

        if (sleepSecs == null || wakeSecs == null) {
            return 0;
        }

        var clock = System.getClockTime();
        var now = (clock.hour * 3600) + (clock.min * 60) + clock.sec;
        return secondsUntilWindowEnd(now, sleepSecs as Number, wakeSecs as Number);
    }

    //! Pure window arithmetic (seconds since midnight), split out for testability.
    function secondsUntilWindowEnd(now as Number, sleepSecs as Number, wakeSecs as Number) as Number {
        if (sleepSecs == wakeSecs) {
            return 0;
        }
        if (sleepSecs > wakeSecs) {
            // Window crosses midnight, e.g. 22:30 -> 06:30
            if (now >= sleepSecs) {
                return (SECS_PER_DAY - now) + wakeSecs;
            }
            if (now < wakeSecs) {
                return wakeSecs - now;
            }
            return 0;
        }
        // Window within one day, e.g. 01:00 -> 09:00
        if (now >= sleepSecs && now < wakeSecs) {
            return wakeSecs - now;
        }
        return 0;
    }

    function isDndActive() as Boolean {
        try {
            var settings = System.getDeviceSettings();
            if (settings has :doNotDisturb) {
                return settings.doNotDisturb == true;
            }
        } catch (e) {
            System.println("MeshQuietPolicy: DND read failed: " + e.getErrorMessage());
        }
        return false;
    }
}
