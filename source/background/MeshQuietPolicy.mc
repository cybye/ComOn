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

    //! Seconds until the configured sleep window ends, or 0 when the current
    //! time is outside the window (or the profile cannot be read).
    function secondsUntilWake() as Number {
        try {
            var profile = UserProfile.getProfile();
            if (profile == null || !(profile has :sleepTime) || !(profile has :wakeTime)) {
                return 0;
            }
            var sleepTime = profile.sleepTime;
            var wakeTime = profile.wakeTime;
            if (!(sleepTime instanceof Time.Duration) || !(wakeTime instanceof Time.Duration)) {
                return 0;
            }
            var clock = System.getClockTime();
            var now = (clock.hour * 3600) + (clock.min * 60) + clock.sec;
            return secondsUntilWindowEnd(now, (sleepTime as Time.Duration).value() % SECS_PER_DAY, (wakeTime as Time.Duration).value() % SECS_PER_DAY);
        } catch (e) {
            System.println("MeshQuietPolicy: sleep window read failed: " + e.getErrorMessage());
            return 0;
        }
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
