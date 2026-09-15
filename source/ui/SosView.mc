import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Attention;
import Toybox.Lang;

class SosView extends WatchUi.View {
    public var countdown as Number = 3;
    public var sosSent as Boolean = false;
    private var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
        triggerVibe();
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        if (!sosSent) {
            countdown--;
            triggerVibe();
            if (countdown <= 0) {
                sendSosNow();
            }
        }
        WatchUi.requestUpdate();
    }

    private function triggerVibe() as Void {
        if (Attention has :vibrate) {
            var p = [ new Attention.VibeProfile(100, 200) ];
            Attention.vibrate(p);
        }
    }

    public function sendSosNow() as Void {
        if (!sosSent) {
            sosSent = true;
            if (_timer != null) {
                _timer.stop();
                _timer = null;
            }
            var bleMgr = getBleManager();
            bleMgr.sendSosEmergency(0); // Broadcast emergency on channel 0

            if (Attention has :vibrate) {
                var p = [ new Attention.VibeProfile(100, 500), new Attention.VibeProfile(0, 200), new Attention.VibeProfile(100, 500) ];
                Attention.vibrate(p);
            }
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        if (!sosSent) {
            // Countdown phase
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, height / 2, 70);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 45, Graphics.FONT_SYSTEM_SMALL, "NOTRUF (SOS)", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(centerX, height / 2 - 25, Graphics.FONT_SYSTEM_NUMBER_HOT, countdown.toString(), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(centerX, height - 55, Graphics.FONT_SYSTEM_XTINY, "BACK: Abbrechen", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // SOS Sent phase
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 40, Graphics.FONT_SYSTEM_MEDIUM, "SOS GESENDET!", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 95, Graphics.FONT_SYSTEM_XTINY, "Notruf im LoRa Mesh aktiv.", Graphics.TEXT_JUSTIFY_CENTER);

            var pos = TelemetryProvider.getInstance().getFormattedPosition();
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 130, Graphics.FONT_SYSTEM_XTINY, pos, Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height - 50, Graphics.FONT_SYSTEM_XTINY, "BACK: Schließen", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class SosDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Boolean {
        // Immediate send
        return true;
    }
}
