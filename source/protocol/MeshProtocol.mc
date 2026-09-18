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
    public const CMD_GET_CHANNELS           = 6;
    public const CMD_SET_DEVICE_TIME        = 8;
    public const CMD_GET_BATTERY_AND_STORAGE = 9;

    // Response and Push Codes
    public const RESP_CODE_OK               = 0;
    public const RESP_CODE_ERR              = 1;
    public const RESP_CODE_CONTACTS_START   = 2;
    public const RESP_CODE_CONTACT          = 3;
    public const RESP_CODE_END_OF_CONTACTS  = 4;
    public const RESP_CODE_SENT             = 6;
    public const RESP_CODE_CHANNELS_START   = 7;
    public const RESP_CODE_CHANNEL          = 8;
    public const RESP_CODE_END_OF_CHANNELS  = 9;
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

    //! Encode channel list query from node
    public function encodeGetChannels() as ByteArray {
        var payload = [CMD_GET_CHANNELS] as Array<Number>;
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

    //! Format detailed ASCII telemetry string with speed & stationary status
    public function formatDetailedPositionString(lat as Double?, lon as Double?, alt as Float?, hr as Number?, speedKmh as Float?, isStationary as Boolean, isSos as Boolean) as String {
        var latStr = (lat != null) ? lat.format("%.5f") : "NO_GPS";
        var lonStr = (lon != null) ? lon.format("%.5f") : "NO_GPS";
        var altStr = (alt != null) ? alt.format("%.0f") + "m" : "-";
        var hrStr = (hr != null && hr > 0) ? (hr.toString() + "bpm") : "-";
        var spdStr = (speedKmh != null && speedKmh >= 0.0) ? (speedKmh.format("%.1f") + "km/h") : "0.0km/h";
        
        var str = "POS: " + latStr + "," + lonStr + " | " + altStr + " | HF:" + hrStr + " | " + spdStr;
        if (isStationary) {
            str += " [STAT]";
        }
        if (isSos) {
            str = "[SOS] " + str;
        }
        return str;
    }

    //! Format SOS emergency string
    public function formatSosString(lat as Double?, lon as Double?, alt as Float?, hr as Number?) as String {
        var latStr = (lat != null) ? lat.format("%.5f") : "NO_GPS";
        var lonStr = (lon != null) ? lon.format("%.5f") : "NO_GPS";
        var altStr = (alt != null) ? alt.format("%.0f") + "m" : "-";
        var hrStr = (hr != null) ? hr.toString() + "bpm" : "-";

        return "[SOS] NOTRUF! Pos: " + latStr + "," + lonStr + " (" + altStr + ") HF: " + hrStr;
    }

    //! Encode ultra-compact 15-byte binary telemetry frame (LoRa-optimized)
    public function encodeBinaryTelemetry(lat as Double?, lon as Double?, alt as Float?, hr as Number?, speedKmh as Float?, batPct as Number?, isStationary as Boolean, isSos as Boolean) as ByteArray {
        var payload = [] as Array<Number>;
        payload.add(0x01); // MsgType = 0x01 (Single Fix)

        // Lat (int32 * 1e7)
        var latInt = (lat != null) ? (lat * 10000000.0).toLong() : 0L;
        payload.add((latInt & 0xFF).toNumber());
        payload.add(((latInt >> 8) & 0xFF).toNumber());
        payload.add(((latInt >> 16) & 0xFF).toNumber());
        payload.add(((latInt >> 24) & 0xFF).toNumber());

        // Lon (int32 * 1e7)
        var lonInt = (lon != null) ? (lon * 10000000.0).toLong() : 0L;
        payload.add((lonInt & 0xFF).toNumber());
        payload.add(((lonInt >> 8) & 0xFF).toNumber());
        payload.add(((lonInt >> 16) & 0xFF).toNumber());
        payload.add(((lonInt >> 24) & 0xFF).toNumber());

        // Alt (int16 meters)
        var altInt = (alt != null) ? alt.toNumber() : 0;
        payload.add((altInt & 0xFF));
        payload.add(((altInt >> 8) & 0xFF));

        // HeartRate (uint8)
        payload.add((hr != null && hr > 0 && hr <= 255) ? hr : 0);

        // Speed (uint8 in 0.5 km/h steps)
        var spdByte = (speedKmh != null && speedKmh > 0.0) ? (speedKmh * 2.0).toNumber() : 0;
        if (spdByte > 255) { spdByte = 255; }
        payload.add(spdByte);

        // Battery (uint8 %)
        payload.add((batPct != null && batPct >= 0 && batPct <= 100) ? batPct : 100);

        // Flags
        var flags = 0;
        if (isStationary) { flags |= 0x01; }
        if (isSos)        { flags |= 0x02; }
        payload.add(flags);

        return payload as ByteArray;
    }

    //! Encode multi-sample bundled telemetry frame (15B Base + N*7B Deltas)
    public function encodeMultiSampleTelemetry(baseLat as Double, baseLon as Double, baseAlt as Float, baseHr as Number, deltaSamples as Array<Dictionary>) as ByteArray {
        var payload = [] as Array<Number>;
        payload.add(0x02); // MsgType = 0x02 (Multi-Sample Bundle)
        payload.add(deltaSamples.size() & 0xFF); // Sample count

        // Base Fix fields (same scaling as single fix)
        var latInt = (baseLat * 10000000.0).toLong();
        payload.add((latInt & 0xFF).toNumber());
        payload.add(((latInt >> 8) & 0xFF).toNumber());
        payload.add(((latInt >> 16) & 0xFF).toNumber());
        payload.add(((latInt >> 24) & 0xFF).toNumber());

        var lonInt = (baseLon * 10000000.0).toLong();
        payload.add((lonInt & 0xFF).toNumber());
        payload.add(((lonInt >> 8) & 0xFF).toNumber());
        payload.add(((lonInt >> 16) & 0xFF).toNumber());
        payload.add(((lonInt >> 24) & 0xFF).toNumber());

        var altInt = baseAlt.toNumber();
        payload.add((altInt & 0xFF));
        payload.add(((altInt >> 8) & 0xFF));
        payload.add((baseHr > 0 && baseHr <= 255) ? baseHr : 0);

        // Append delta samples
        for (var i = 0; i < deltaSamples.size(); i++) {
            var sample = deltaSamples[i];
            var dt = (sample[:deltaTime] != null) ? (sample[:deltaTime] as Number) : 0;
            var dLat = (sample[:deltaLat] != null) ? (sample[:deltaLat] as Number) : 0;
            var dLon = (sample[:deltaLon] != null) ? (sample[:deltaLon] as Number) : 0;
            var sHr = (sample[:hr] != null) ? (sample[:hr] as Number) : 0;

            payload.add((dt & 0xFF));
            payload.add(((dt >> 8) & 0xFF));
            payload.add((dLat & 0xFF));
            payload.add(((dLat >> 8) & 0xFF));
            payload.add((dLon & 0xFF));
            payload.add(((dLon >> 8) & 0xFF));
            payload.add(sHr & 0xFF);
        }

        return payload as ByteArray;
    }
}
