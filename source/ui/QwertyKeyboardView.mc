import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;

class QwertyKeyboardView extends WatchUi.View {
    public var currentText as String = "";
    public var isShift as Boolean = true;
    public var isSymbols as Boolean = false;
    public var isQwerty as Boolean = true; // QWERTY mode default as requested
    public var keys as Array<Dictionary> = [] as Array<Dictionary>;
    public var activeKeyId as String? = null;

    private var _cursorTimer as Timer.Timer?;
    public var cursorBlink as Boolean = true;

    function initialize(initialText as String) {
        View.initialize();
        currentText = initialText;
    }

    function onShow() as Void {
        _cursorTimer = new Timer.Timer();
        _cursorTimer.start(method(:onCursorTimer), 500, true);
        buildKeyLayout();
    }

    function onHide() as Void {
        if (_cursorTimer != null) {
            _cursorTimer.stop();
            _cursorTimer = null;
        }
    }

    function onCursorTimer() as Void {
        cursorBlink = !cursorBlink;
        if (activeKeyId != null) {
            activeKeyId = null;
        }
        WatchUi.requestUpdate();
    }

    public function buildKeyLayout() as Void {
        keys = [] as Array<Dictionary>;
        var cx = 227;

        // Row 1 (y = 102, h = 42)
        // In QWERTY: Q W E R T Y U I O P
        // In QWERTZ: Q W E R T Z U I O P
        var r1Labels = [] as Array<String>;
        if (isSymbols) {
            r1Labels = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"];
        } else if (isQwerty) {
            r1Labels = isShift ? ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"] : ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"];
        } else {
            r1Labels = isShift ? ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P"] : ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"];
        }

        var r1W = 33;
        var r1Gap = 3;
        var r1Total = (r1Labels.size() * r1W) + ((r1Labels.size() - 1) * r1Gap);
        var r1StartX = cx - (r1Total / 2);
        for (var i = 0; i < r1Labels.size(); i++) {
            keys.add({
                :id => "CHAR_" + r1Labels[i],
                :val => r1Labels[i],
                :x => r1StartX + (i * (r1W + r1Gap)),
                :y => 102,
                :w => r1W,
                :h => 42,
                :label => r1Labels[i],
                :bg => 0x1f2430,
                :fg => Graphics.COLOR_WHITE
            });
        }

        // Row 2 (y = 150, h = 42)
        var r2Labels = [] as Array<String>;
        if (isSymbols) {
            r2Labels = ["-", "/", ":", ";", "(", ")", "&", "@", "%"];
        } else {
            r2Labels = isShift ? ["A", "S", "D", "F", "G", "H", "J", "K", "L"] : ["a", "s", "d", "f", "g", "h", "j", "k", "l"];
        }

        var r2W = 36;
        var r2Gap = 4;
        var r2Total = (r2Labels.size() * r2W) + ((r2Labels.size() - 1) * r2Gap);
        var r2StartX = cx - (r2Total / 2);
        for (var i = 0; i < r2Labels.size(); i++) {
            keys.add({
                :id => "CHAR_" + r2Labels[i],
                :val => r2Labels[i],
                :x => r2StartX + (i * (r2W + r2Gap)),
                :y => 150,
                :w => r2W,
                :h => 42,
                :label => r2Labels[i],
                :bg => 0x1f2430,
                :fg => Graphics.COLOR_WHITE
            });
        }

        // Row 3 (y = 198, h = 42)
        // [SHIFT] [ Z/Y X C V B N M ] [ DEL ]
        var r3Y = 198;
        var r3StartX = 38;
        
        // Shift button on left
        keys.add({
            :id => "TOGGLE_SHIFT",
            :x => r3StartX,
            :y => r3Y,
            :w => 46,
            :h => 42,
            :label => isSymbols ? "#+=" : (isShift ? "SHF" : "shf"),
            :bg => isShift ? 0x2e3d59 : 0x191e28,
            :fg => isShift ? 0x00d4ff : Graphics.COLOR_LT_GRAY
        });

        var r3Labels = [] as Array<String>;
        if (isSymbols) {
            r3Labels = ["?", "!", "\"", "'", "+", "=", "*"];
        } else if (isQwerty) {
            r3Labels = isShift ? ["Z", "X", "C", "V", "B", "N", "M"] : ["z", "x", "c", "v", "b", "n", "m"];
        } else {
            r3Labels = isShift ? ["Y", "X", "C", "V", "B", "N", "M"] : ["y", "x", "c", "v", "b", "n", "m"];
        }

        var r3W = 34;
        var r3Gap = 4;
        var r3LettersX = r3StartX + 46 + 4;
        for (var i = 0; i < r3Labels.size(); i++) {
            keys.add({
                :id => "CHAR_" + r3Labels[i],
                :val => r3Labels[i],
                :x => r3LettersX + (i * (r3W + r3Gap)),
                :y => r3Y,
                :w => r3W,
                :h => 42,
                :label => r3Labels[i],
                :bg => 0x1f2430,
                :fg => Graphics.COLOR_WHITE
            });
        }

        // Backspace button on right
        var delX = r3LettersX + (r3Labels.size() * (r3W + r3Gap));
        keys.add({
            :id => "BACKSPACE",
            :x => delX,
            :y => r3Y,
            :w => 48,
            :h => 42,
            :label => "DEL",
            :bg => 0x3d2020,
            :fg => 0xff5555
        });

        // Row 4 (y = 246, h = 44)
        // [ ?123 / ABC ] [  LEERTASTE  ] [ . / , ] [ ✔ SEND ]
        var r4Y = 246;
        var r4StartX = 50;
        keys.add({
            :id => "TOGGLE_MODE",
            :x => r4StartX,
            :y => r4Y,
            :w => 56,
            :h => 44,
            :label => isSymbols ? "ABC" : "123",
            :bg => 0x242c3d,
            :fg => 0x00d4ff
        });

        keys.add({
            :id => "SPACE",
            :x => r4StartX + 56 + 5,
            :y => r4Y,
            :w => 144,
            :h => 44,
            :label => "LEER",
            :bg => 0x1f2430,
            :fg => 0xaaaaaa
        });

        keys.add({
            :id => "CHAR_DOT",
            :val => isSymbols ? "," : ".",
            :x => r4StartX + 56 + 5 + 144 + 5,
            :y => r4Y,
            :w => 36,
            :h => 44,
            :label => isSymbols ? "," : ".",
            :bg => 0x1f2430,
            :fg => Graphics.COLOR_WHITE
        });

        keys.add({
            :id => "SEND",
            :x => r4StartX + 56 + 5 + 144 + 5 + 36 + 5,
            :y => r4Y,
            :w => 86,
            :h => 44,
            :label => "SEND",
            :bg => 0x155724,
            :fg => 0x00e676
        });

        // Row 5 (y = 298, h = 36)
        // [QWERTY / QWERTZ Toggle] [ ✕ Abbrechen ]
        var r5Y = 298;
        var r5StartX = cx - 120;
        keys.add({
            :id => "TOGGLE_LAYOUT",
            :x => r5StartX,
            :y => r5Y,
            :w => 106,
            :h => 36,
            :label => isQwerty ? "QWERTY" : "QWERTZ",
            :bg => 0x222630,
            :fg => 0xffaa00
        });

        keys.add({
            :id => "CANCEL",
            :x => r5StartX + 106 + 8,
            :y => r5Y,
            :w => 126,
            :h => 36,
            :label => "Abbrechen",
            :bg => 0x1f1f24,
            :fg => 0x888888
        });
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2;
        var fontXtiny = Graphics.FONT_SYSTEM_XTINY;

        // 1. Target recipient banner at very top
        var targetName = ContactManager.getTargetDisplayName();
        dc.setColor(0xffaa00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 16, fontXtiny, "An: " + targetName, Graphics.TEXT_JUSTIFY_CENTER);

        // 2. Text Input Preview Box
        var boxW = 286;
        var boxH = 46;
        var boxX = cx - (boxW / 2);
        var boxY = 44;

        dc.setColor(0x10141f, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(boxX, boxY, boxW, boxH, 8);
        dc.setColor(0x2d3a52, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(boxX, boxY, boxW, boxH, 8);

        // Display current text with blinking cursor or placeholder
        if (currentText.length() == 0) {
            dc.setColor(0x556070, Graphics.COLOR_TRANSPARENT);
            dc.drawText(boxX + 12, boxY + 11, fontXtiny, cursorBlink ? "Tippen... |" : "Tippen...", Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            var displayText = currentText + (cursorBlink ? "|" : " ");
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            
            // Truncate display from left if too long to fit
            var maxTextWidth = boxW - 24;
            while (dc.getTextWidthInPixels(displayText, fontXtiny) > maxTextWidth && displayText.length() > 3) {
                displayText = displayText.substring(1, displayText.length());
            }
            dc.drawText(boxX + 12, boxY + 11, fontXtiny, displayText, Graphics.TEXT_JUSTIFY_LEFT);
        }

        // 3. Render all Keyboard Buttons
        for (var i = 0; i < keys.size(); i++) {
            var k = keys[i];
            var kid = k[:id] as String;
            var kx = k[:x];
            var ky = k[:y];
            var kw = k[:w];
            var kh = k[:h];
            var bg = k[:bg];
            var fg = k[:fg];
            var label = k[:label] as String;

            // Highlight active touched key
            if (activeKeyId != null && activeKeyId.equals(kid)) {
                bg = 0x00d4ff;
                fg = Graphics.COLOR_BLACK;
            }

            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(kx, ky, kw, kh, 6);
            dc.setColor(0x353f54, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(kx, ky, kw, kh, 6);

            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(kx + (kw / 2), ky + (kh / 2) - 11, fontXtiny, label, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // 4. Subtle hardware hint at bottom
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 350, fontXtiny, "START = Senden  |  BACK = Zurueck", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
