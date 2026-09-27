import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

//! Drop-in replacement for Timer.Timer; all instances share one hardware timer
//! because devices cap the number of concurrently running Toybox timers.
class SoftTimer {
    private var _callback as (Method() as Void)? = null;
    private var _period as Number = 0;
    private var _repeat as Boolean = false;
    private var _due as Number = 0;
    private var _active as Boolean = false;

    function initialize() {
    }

    public function isActive() as Boolean {
        return _active;
    }

    public function start(callback as Method() as Void, time as Number, repeat as Boolean) as Void {
        var scheduler = SoftTimerScheduler.getInstance();
        scheduler.remove(self);
        _callback = callback;
        _period = time;
        _repeat = repeat;
        _due = System.getTimer() + time;
        _active = true;
        scheduler.add(self);
    }

    public function stop() as Void {
        _active = false;
        SoftTimerScheduler.getInstance().remove(self);
    }

    public function getDue() as Number {
        return _due;
    }

    public function fire(now as Number) as Void {
        var cb = _callback;
        if (_repeat) {
            _due = now + _period;
        } else {
            _active = false;
        }
        if (cb != null) {
            cb.invoke();
        }
    }
}

class SoftTimerScheduler {
    private static var _instance as SoftTimerScheduler? = null;
    private static const MIN_DELAY_MS as Number = 50;

    private var _timers as Array<SoftTimer> = [] as Array<SoftTimer>;
    private var _hwTimer as Timer.Timer? = null;

    public static function getInstance() as SoftTimerScheduler {
        if (_instance == null) {
            _instance = new SoftTimerScheduler();
        }
        return _instance as SoftTimerScheduler;
    }

    function initialize() {
    }

    public function add(timer as SoftTimer) as Void {
        if (_timers.indexOf(timer) < 0) {
            _timers.add(timer);
        }
        reschedule();
    }

    public function remove(timer as SoftTimer) as Void {
        if (_timers.indexOf(timer) >= 0) {
            _timers.remove(timer);
            reschedule();
        }
    }

    private function reschedule() as Void {
        if (_hwTimer != null) {
            _hwTimer.stop();
        }
        if (_timers.size() == 0) {
            return;
        }
        var now = System.getTimer();
        var minDelay = null as Number?;
        for (var i = 0; i < _timers.size(); i++) {
            var delay = _timers[i].getDue() - now;
            if (minDelay == null || delay < minDelay) {
                minDelay = delay;
            }
        }
        var wait = minDelay as Number;
        if (wait < MIN_DELAY_MS) {
            wait = MIN_DELAY_MS;
        }
        if (_hwTimer == null) {
            _hwTimer = new Timer.Timer();
        }
        _hwTimer.start(method(:onTick), wait, false);
    }

    public function onTick() as Void {
        var now = System.getTimer();
        var due = [] as Array<SoftTimer>;
        for (var i = 0; i < _timers.size(); i++) {
            if (_timers[i].getDue() - now <= 0) {
                due.add(_timers[i]);
            }
        }
        for (var j = 0; j < due.size(); j++) {
            var timer = due[j];
            // An earlier callback may have stopped this timer
            if (_timers.indexOf(timer) < 0) {
                continue;
            }
            _timers.remove(timer);
            timer.fire(now);
            if (timer.isActive() && _timers.indexOf(timer) < 0) {
                _timers.add(timer);
            }
        }
        reschedule();
    }
}
