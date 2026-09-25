import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Attention;
import Toybox.Lang;

class SosActiveView extends WatchUi.View {
    public var repeatCountdown as Number = 60;
    private var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        DisplayProfile.init(dc);
        setLayout(Rez.Layouts.SosActiveLayout(dc));
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
        WatchUi.requestUpdate();
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
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
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var cardW = width - DisplayProfile.scale(84);
        var cardX = (width - cardW) / 2;
        var cardY = DisplayProfile.scale(105);
        var cardH = DisplayProfile.scale(196);
        var cardR = DisplayTheme.cardRadius();

        // Draw Telemetry Card container in canvas behind text
        dc.setColor(DisplayTheme.sosCardBg(), Graphics.COLOR_BLACK);
        dc.fillRoundedRectangle(cardX, cardY, cardW, cardH, cardR);
        dc.setColor(DisplayTheme.sosCardBorder(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(cardX, cardY, cardW, cardH, cardR);
        dc.setPenWidth(1);

        // Populate Layout Labels
        var header = findDrawableById("SosActiveHeader") as WatchUi.Text?;
        if (header != null) {
            header.setText(I18n.get(Rez.Strings.SosSentTitle));
        }

        var cardTitle = findDrawableById("SosCardTitle") as WatchUi.Text?;
        if (cardTitle != null) {
            cardTitle.setText(I18n.get(Rez.Strings.SosCardTelemetry));
        }

        var telem = TelemetryProvider.getInstance();
        telem.refreshPosition();
        var posText = (telem.hasGpsFix && telem.currentLat != null && telem.currentLon != null) ? (telem.currentLat.format("%.4f") + "°, " + telem.currentLon.format("%.4f") + "°") : I18n.get(Rez.Strings.SosCardGpsWaiting);
        var posRow = findDrawableById("SosPosRow") as WatchUi.Text?;
        if (posRow != null) {
            posRow.setText(posText);
        }

        var altStr = (telem.currentAlt != null) ? (telem.currentAlt.format("%.0f") + "m") : "--m";
        var hr = telem.getHeartRate();
        var hrStr = (hr != null) ? (hr.toString() + " bpm") : "-- bpm";
        var stp = telem.getSteps();
        var stpStr = (stp != null) ? (stp.toString() + " Stp") : "0 Stp";
        var vitalsRow = findDrawableById("SosVitalsRow") as WatchUi.Text?;
        if (vitalsRow != null) {
            vitalsRow.setText(altStr + "  |  " + hrStr + "  |  " + stpStr);
        }

        var channelRow = findDrawableById("SosChannelRow") as WatchUi.Text?;
        if (channelRow != null) {
            channelRow.setText(I18n.get(Rez.Strings.SosCardChannel));
        }

        var repeatStr = "* " + I18n.format(Rez.Strings.SosCardBeacon, [ repeatCountdown ]);
        var beaconRow = findDrawableById("SosBeaconRow") as WatchUi.Text?;
        if (beaconRow != null) {
            beaconRow.setText(repeatStr);
        }

        var closeHint = findDrawableById("SosCloseHint") as WatchUi.Text?;
        if (closeHint != null) {
            closeHint.setText(I18n.get(Rez.Strings.SosBackClose));
        }

        View.onUpdate(dc);
    }
}

class SosActiveDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
