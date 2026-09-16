import Toybox.Lang;
import Toybox.Time;
import Toybox.System;

module MeshProtocol {
    // Companion Protocol Commands
    public const CMD_APP_START              = 1;
    public const CMD_SEND_TXT_MSG           = 2;
    public const CMD_SEND_CHANNEL_TXT_MSG   = 3;
    public const CMD_GET_CONTACTS           = 4;
    public const CMD_SYNC_NEXT_MESSAGE      = 5;
    public const CMD_SET_DEVICE_TIME        = 8;
    public const CMD_GET_BATTERY_AND_STORAGE = 9;

    // Response and Push Codes
    public const RESP_CODE_OK               = 0;
    public const RESP_CODE_ERR              = 1;
    public const RESP_CODE_CONTACTS_START   = 2;
    public const RESP_CODE_CONTACT          = 3;
    public const RESP_CODE_END_OF_CONTACTS  = 4;
    public const RESP_CODE_SENT             = 6;
    public const PUSH_CODE_MSG_WAITING      = 0x83;

    //! Encode a channel text message (e.g. broadcast or group channel)
    public function encodeChannelMessage(channelIdx as Number, text as String) as ByteArray {
        var textBytes = text.toUtf8Array();
        var now = Time.now().value(); // uint32 timestamp

        // Header: [CMD (1B), txt_type (1B=0 plain), channel_idx (1B), timestamp (4B little endian)]
        var payload = [] as Array<Number>;
        payload.add(CMD_SEND_CHANNEL_TXT_MSG);
        payload.add(0); // plain text
        payload.add(channelIdx);
        
        // Timestamp little endian
        payload.add((now & 0xFF));
        payload.add(((now >> 8) & 0xFF));
        payload.add(((now >> 16) & 0xFF));
        payload.add(((now >> 24) & 0xFF));

        // Append text bytes
        for (var i = 0; i < textBytes.size(); i++) {
            payload.add(textBytes[i]);
        }

        return payload as ByteArray;
    }

    //! Encode a command to query contacts list from node (all contacts)
    public function encodeGetContacts() as ByteArray {
        var payload = [CMD_GET_CONTACTS] as Array<Number>;
        return payload as ByteArray;
    }

    //! Encode incremental contacts query with 'since' timestamp
    public function encodeGetContactsSince(sinceTimestamp as Number) as ByteArray {
        var payload = [
            CMD_GET_CONTACTS,
            (sinceTimestamp & 0xFF),
            ((sinceTimestamp >> 8) & 0xFF),
            ((sinceTimestamp >> 16) & 0xFF),
            ((sinceTimestamp >> 24) & 0xFF)
        ] as Array<Number>;
        return payload as ByteArray;
    }

    //! Encode sync next message request
    public function encodeSyncNextMessage() as ByteArray {
        var payload = [CMD_SYNC_NEXT_MESSAGE] as Array<Number>;
        return payload as ByteArray;
    }

    //! Encode set device time command (synchronizes GPS clock with node)
    public function encodeSetDeviceTime(timestamp as Number) as ByteArray {
        var payload = [
            CMD_SET_DEVICE_TIME,
            (timestamp & 0xFF),
            ((timestamp >> 8) & 0xFF),
            ((timestamp >> 16) & 0xFF),
            ((timestamp >> 24) & 0xFF)
        ] as Array<Number>;
        return payload as ByteArray;
    }

    //! Encode battery and storage query
    public function encodeGetBattery() as ByteArray {
        var payload = [CMD_GET_BATTERY_AND_STORAGE] as Array<Number>;
        return payload as ByteArray;
    }

    //! Format telemetry / location string
    public function formatPositionString(lat as Double?, lon as Double?, alt as Float?, hr as Number?, steps as Number?) as String {
        var latStr = (lat != null) ? lat.format("%.5f") : "-";
        var lonStr = (lon != null) ? lon.format("%.5f") : "-";
        var altStr = (alt != null) ? alt.format("%.0f") + "m" : "-";
        var hrStr = (hr != null) ? hr.toString() + "bpm" : "-";
        var stepsStr = (steps != null) ? steps.toString() : "-";
        
        return "POS: " + latStr + "," + lonStr + " | " + altStr + " | HF:" + hrStr + " | Stp:" + stepsStr;
    }

    //! Format SOS emergency string
    public function formatSosString(lat as Double?, lon as Double?, alt as Float?, hr as Number?) as String {
        var latStr = (lat != null) ? lat.format("%.5f") : "NO_GPS";
        var lonStr = (lon != null) ? lon.format("%.5f") : "NO_GPS";
        var altStr = (alt != null) ? alt.format("%.0f") + "m" : "-";
        var hrStr = (hr != null) ? hr.toString() + "bpm" : "-";

        return "[SOS] NOTRUF! Pos: " + latStr + "," + lonStr + " (" + altStr + ") HF: " + hrStr;
    }
}
