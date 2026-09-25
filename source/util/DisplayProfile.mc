import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

typedef FontRef as Graphics.FontDefinition or Graphics.VectorFont;

class DisplayProfile {
    public static var screenW as Number = 454;
    public static var screenH as Number = 454;
    private static var _scale as Float = 1.0f;

    public static function init(dc as Graphics.Dc) as Void {
        screenW = dc.getWidth();
        screenH = dc.getHeight();
        _scale = screenW / 454.0f;
    }

    public static function scale(px as Number) as Number {
        var scaled = (px * _scale).toNumber();
        return (scaled > 0 || px <= 0) ? scaled : 1;
    }

    public static function chordW(y as Number) as Number {
        var r = screenW / 2;
        var dy = y - r;
        var sq = (r * r) - (dy * dy);
        if (sq <= 0) {
            return 0;
        }
        return (2.0f * Math.sqrt(sq.toFloat())).toNumber();
    }
}
