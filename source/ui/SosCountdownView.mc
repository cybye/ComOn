import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Attention;
import Toybox.Lang;

class SosCountdownView extends WatchUi.View {
    public var countdown as Number = 5;
    private var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        DisplayProfile.init(dc);
        setLayout(Rez.Layouts.SosCountdownLayout(dc));
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
        triggerVibe();
        WatchUi.requestUpdate();
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        countdown--;
        triggerVibe();
        if (countdown <= 0) {
            if (_timer != null) {
                _timer.stop();
                _timer = null;
            }
            sendSosNow();
            return;
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
        var bleMgr = getBleManager();
        bleMgr.sendSosEmergency(0); // Broadcast emergency on channel 0

        if (Attention has :vibrate) {
            var p = [ new Attention.VibeProfile(100, 500), new Attention.VibeProfile(0, 200), new Attention.VibeProfile(100, 500) ];
            Attention.vibrate(p);
        }

        WatchUi.switchToView(new SosActiveView(), new SosActiveDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var header = findDrawableById("SosHeader") as WatchUi.Text?;
        if (header != null) {
            header.setText(I18n.get(Rez.Strings.SosHeader));
        }
        var abort = findDrawableById("SosAbortHint") as WatchUi.Text?;
        if (abort != null) {
            abort.setText(I18n.get(Rez.Strings.SosBackCancel));
        }

        View.onUpdate(dc);

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;

        // Pulsing countdown circle
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, centerY, DisplayProfile.scale(65));

        dc.setColor(0x881111, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(DisplayTheme.ringPenW());
        dc.drawCircle(centerX, centerY, DisplayProfile.scale(73));
        dc.setPenWidth(1);

        // Centered countdown number
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY, Graphics.FONT_SYSTEM_NUMBER_HOT, countdown.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class SosCountdownDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Boolean {
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            return true;
        }
        return false;
    }
}
