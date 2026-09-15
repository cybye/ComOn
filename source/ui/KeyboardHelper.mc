import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Application.Storage;

class KeyboardHelper {
    public static const MODE_QWERTY as Number = 0;
    public static const MODE_QWERTZ as Number = 1;
    public static const MODE_NATIVE as Number = 2;

    private static const STORAGE_KEY as String = "cfg_keyboard_mode";
    private static var _mode as Number? = null;

    public static function getKeyboardMode() as Number {
        if (_mode == null) {
            try {
                var stored = Storage.getValue(STORAGE_KEY);
                if (stored != null && (stored instanceof Number)) {
                    _mode = stored;
                } else {
                    _mode = MODE_QWERTY;
                }
            } catch (e) {
                _mode = MODE_QWERTY;
            }
        }
        return _mode as Number;
    }

    public static function setKeyboardMode(mode as Number) as Void {
        _mode = mode;
        try {
            Storage.setValue(STORAGE_KEY, mode);
        } catch (e) {
            // ignore
        }
    }

    public static function getModeName(mode as Number) as String {
        if (mode == MODE_QWERTZ) {
            return "QWERTZ (Touch)";
        } else if (mode == MODE_NATIVE) {
            return "Nativ (Garmin)";
        } else {
            return "QWERTY (Touch)";
        }
    }

    public static function openKeyboard(initialText as String) as Void {
        var mode = getKeyboardMode();
        if (mode == MODE_NATIVE) {
            if (WatchUi has :TextPicker) {
                WatchUi.pushView(new WatchUi.TextPicker(initialText), new CustomTextPickerDelegate(), WatchUi.SLIDE_DOWN);
            } else {
                WatchUi.showToast("Natives Rad nicht verfuegbar", null);
            }
        } else {
            var isQwerty = (mode == MODE_QWERTY);
            var keyView = new QwertyKeyboardView(initialText, isQwerty);
            WatchUi.pushView(keyView, new QwertyKeyboardDelegate(keyView), WatchUi.SLIDE_DOWN);
        }
    }
}
