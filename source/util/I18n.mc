import Toybox.WatchUi;
import Toybox.Lang;

module I18n {
    //! Load a localized string from resource table
    function get(resId as ResourceId) as String {
        return WatchUi.loadResource(resId) as String;
    }

    //! Format a localized string template with dynamic parameters
    function format(resId as ResourceId, params as Array) as String {
        var tmpl = WatchUi.loadResource(resId) as String;
        return Lang.format(tmpl, params);
    }
}
