import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Attention;
import Toybox.Lang;

class SosView extends WatchUi.View {
    public var countdown as Number = 5;
    public var sosSent as Boolean = false;
    public var repeatCountdown as Number = 60;
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
        } else {
            repeatCountdown--;
            if (repeatCountdown <= 0) {
                repeatCountdown = 60;
                var bleMgr = getBleManager();
                bleMgr.sendSosEmergency(0); // Periodic emergency broadcast
                if (Attention has :vibrate) {
                    var p = [ new Attention.VibeProfile(100, 300) ];
                    Attention.vibrate(p);
                }
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
            repeatCountdown = 60;
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
        var centerY = height / 2;

        if (!sosSent) {
            // Countdown phase
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 72, Graphics.FONT_SYSTEM_TINY, I18n.get(Rez.Strings.SosHeader), Graphics.TEXT_JUSTIFY_CENTER);

            // Pulsing countdown circle
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, centerY, 65);

            dc.setColor(0x881111, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawCircle(centerX, centerY, 73);
            dc.setPenWidth(1);

            // Centered countdown number
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, centerY, Graphics.FONT_SYSTEM_NUMBER_HOT, countdown.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            // Bottom cancel hint
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height - 68, Graphics.FONT_SYSTEM_XTINY, I18n.get(Rez.Strings.SosBackCancel), Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // SOS Sent phase
            // Header
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 72, Graphics.FONT_SYSTEM_TINY, I18n.get(Rez.Strings.SosSentTitle), Graphics.TEXT_JUSTIFY_CENTER);

            // Telemetry Card
            var cardW = width - 84;
            var cardX = (width - cardW) / 2;
            var cardY = 120;
            var cardH = 196;
            var cardR = 14;

            // Card background & border
            dc.setColor(0x180808, Graphics.COLOR_BLACK);
            dc.fillRoundedRectangle(cardX, cardY, cardW, cardH, cardR);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRoundedRectangle(cardX, cardY, cardW, cardH, cardR);
            dc.setPenWidth(1);

            // Card Header
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, cardY + 14, Graphics.FONT_SYSTEM_XTINY, I18n.get(Rez.Strings.SosCardTelemetry), Graphics.TEXT_JUSTIFY_CENTER);

            // Row 1: GPS Position (centered)
            var telem = TelemetryProvider.getInstance();
            telem.refreshPosition();
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            var posText = (telem.hasGpsFix && telem.currentLat != null && telem.currentLon != null) ? (telem.currentLat.format("%.4f") + "°, " + telem.currentLon.format("%.4f") + "°") : I18n.get(Rez.Strings.SosCardGpsWaiting);
            dc.drawText(centerX, cardY + 52, Graphics.FONT_SYSTEM_XTINY, posText, Graphics.TEXT_JUSTIFY_CENTER);

            // Row 2: Vitals & Alt (centered)
            var altStr = (telem.currentAlt != null) ? (telem.currentAlt.format("%.0f") + "m") : "--m";
            var hr = telem.getHeartRate();
            var hrStr = (hr != null) ? (hr.toString() + " bpm") : "-- bpm";
            var stp = telem.getSteps();
            var stpStr = (stp != null) ? (stp.toString() + " Stp") : "0 Stp";
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, cardY + 86, Graphics.FONT_SYSTEM_XTINY, altStr + "  |  " + hrStr + "  |  " + stpStr, Graphics.TEXT_JUSTIFY_CENTER);

            // Row 3: Channel (centered)
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, cardY + 120, Graphics.FONT_SYSTEM_XTINY, I18n.get(Rez.Strings.SosCardChannel), Graphics.TEXT_JUSTIFY_CENTER);

            // Row 4: Auto-Beacon indicator (centered with live countdown)
            dc.setColor(0x00FF88, Graphics.COLOR_TRANSPARENT);
            var repeatStr = "* " + I18n.format(Rez.Strings.SosCardBeacon, [ repeatCountdown ]);
            dc.drawText(centerX, cardY + 152, Graphics.FONT_SYSTEM_XTINY, repeatStr, Graphics.TEXT_JUSTIFY_CENTER);

            // Bottom action hint safely inside the bezel
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height - 68, Graphics.FONT_SYSTEM_XTINY, I18n.get(Rez.Strings.SosBackClose), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class SosDelegate extends WatchUi.BehaviorDelegate {
    private var _view as SosView?;

    function initialize(view as SosView or Null) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Boolean {
        // Der 5s-Countdown muss zwingend ablaufen (Schutz vor Fehlalarmen durch Doppel-Klick auf START)
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            // Countdown kann nicht uebersprungen werden
            return true;
        }
        return false;
    }
}
