import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Application.Storage;
import Toybox.System;

class KeyboardHelper {
    public static function openKeyboard(initialText as String) as Void {
        openKeyboardForTarget(initialText, null);
    }

    public static function openKeyboardForTarget(initialText as String, targetId as String?) as Void {
        if (WatchUi has :TextPicker) {
            WatchUi.pushView(new WatchUi.TextPicker(initialText), new CustomTextPickerDelegate(targetId), WatchUi.SLIDE_DOWN);
        } else {
            WatchUi.showToast("Native TextPicker not available", null);
        }
    }
}

