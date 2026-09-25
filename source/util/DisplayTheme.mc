import Toybox.Graphics;
import Toybox.Lang;

class DisplayTheme {
    // -------------------------------------------------------------
    // AMOLED Variant
    // -------------------------------------------------------------
    (:amoled)
    public static function cardBg() as Number {
        return 0x151b24;
    }

    (:amoled)
    public static function cardBorder() as Number {
        return 0x2a3647;
    }

    (:amoled)
    public static function focusBorder() as Number {
        return Graphics.COLOR_WHITE;
    }

    (:amoled)
    public static function accent() as Number {
        return 0x00e676; // WhatsApp green
    }

    (:amoled)
    public static function accentDark() as Number {
        return 0x124726; // WhatsApp forest green
    }

    (:amoled)
    public static function muted() as Number {
        return 0x9aa8b8;
    }

    (:amoled)
    public static function outBubble() as Number {
        return 0x0e4727;
    }

    (:amoled)
    public static function outBubbleBorder() as Number {
        return 0x18703e;
    }

    (:amoled)
    public static function inBubble() as Number {
        return 0x1a232f;
    }

    (:amoled)
    public static function inBubbleBorder() as Number {
        return 0x2f3e52;
    }

    (:amoled)
    public static function divider() as Number {
        return 0x222a3a;
    }

    (:amoled)
    public static function ringPenW() as Number {
        return 3;
    }

    (:amoled)
    public static function bubbleRadius() as Number {
        return 10;
    }

    (:amoled)
    public static function cardRadius() as Number {
        return 18;
    }

    (:amoled)
    public static function sosCardBg() as Number {
        return 0x180808;
    }

    (:amoled)
    public static function sosCardBorder() as Number {
        return Graphics.COLOR_RED;
    }

    // -------------------------------------------------------------
    // MIP Variant (High-contrast 64-color palette)
    // -------------------------------------------------------------
    (:mip)
    public static function cardBg() as Number {
        return Graphics.COLOR_BLACK;
    }

    (:mip)
    public static function cardBorder() as Number {
        return Graphics.COLOR_LT_GRAY;
    }

    (:mip)
    public static function focusBorder() as Number {
        return Graphics.COLOR_WHITE;
    }

    (:mip)
    public static function accent() as Number {
        return Graphics.COLOR_GREEN;
    }

    (:mip)
    public static function accentDark() as Number {
        return Graphics.COLOR_DK_GREEN;
    }

    (:mip)
    public static function muted() as Number {
        return Graphics.COLOR_LT_GRAY;
    }

    (:mip)
    public static function outBubble() as Number {
        return Graphics.COLOR_BLACK;
    }

    (:mip)
    public static function outBubbleBorder() as Number {
        return Graphics.COLOR_GREEN;
    }

    (:mip)
    public static function inBubble() as Number {
        return Graphics.COLOR_BLACK;
    }

    (:mip)
    public static function inBubbleBorder() as Number {
        return Graphics.COLOR_WHITE;
    }

    (:mip)
    public static function divider() as Number {
        return Graphics.COLOR_DK_GRAY;
    }

    (:mip)
    public static function ringPenW() as Number {
        return 2;
    }

    (:mip)
    public static function bubbleRadius() as Number {
        return 8;
    }

    (:mip)
    public static function cardRadius() as Number {
        return 10;
    }

    (:mip)
    public static function sosCardBg() as Number {
        return Graphics.COLOR_BLACK;
    }

    (:mip)
    public static function sosCardBorder() as Number {
        return Graphics.COLOR_RED;
    }
}
