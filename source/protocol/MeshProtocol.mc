import Toybox.Lang;
import Toybox.Time;
import Toybox.System;

module MeshProtocol {
    // Companion Protocol Commands
    public const CMD_APP_START              = 1;
    public const CMD_SEND_TXT_MSG           = 2;
    public const CMD_SEND_CHANNEL_TXT_MSG   = 3;
    public const CMD_GET_CONTACTS           = 4;
    public const CMD_SET_DEVICE_TIME        = 6;
    public const CMD_SYNC_NEXT_MESSAGE      = 10;
    public const CMD_GET_BATTERY_AND_STORAGE = 20;
    public const CMD_DEVICE_QUERY           = 22;
    public const CMD_GET_CHANNEL            = 31;
    public const CMD_GET_STATS              = 56;

    public const STATS_TYPE_CORE            = 0;
    public const STATS_TYPE_RADIO           = 1;

    // Response and Push Codes
    public const RESP_CODE_OK               = 0;
    public const RESP_CODE_ERR              = 1;
    public const RESP_CODE_CONTACTS_START   = 2;
    public const RESP_CODE_CONTACT          = 3;
    public const RESP_CODE_END_OF_CONTACTS  = 4;
    public const RESP_CODE_SELF_INFO        = 5;
    public const RESP_CODE_SENT             = 6;
    public const RESP_CODE_CONTACT_MSG      = 7;
    public const RESP_CODE_CHANNEL_MSG      = 8;
    public const RESP_CODE_NO_MORE_MESSAGES = 10;
    public const RESP_CODE_BATT_AND_STORAGE = 12;
    public const RESP_CODE_DEVICE_INFO      = 13;
    public const RESP_CODE_CONTACT_MSG_V3   = 16;
    public const RESP_CODE_CHANNEL_MSG_V3   = 17;
    public const RESP_CODE_CHANNEL_INFO     = 18;
    public const RESP_CODE_STATS            = 24;
    public const PUSH_CODE_MSG_WAITING      = 0x83;

    //! Encode a channel text message (e.g. broadcast or group channel)
    public function encodeChannelMessage(channelIdx as Number, text as String) as ByteArray {
        var textBytes = text.toUtf8Array();
        var now = Time.now().value(); // uint32 timestamp

        // Header: [CMD (1B), txt_type (1B=0 plain), channel_idx (1B), timestamp (4B little endian)]
        var payload = []b;
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

        return payload;
    }

    //! Extract 6-byte public key prefix from contactId (either 12-char hex string or raw string fallback)
    public function extractPubkeyPrefix(contactId as String?) as Array<Number> {
        var prefix = [] as Array<Number>;
        if (contactId == null || contactId.length() == 0) {
            for (var z = 0; z < 6; z++) { prefix.add(0); }
            return prefix;
        }

        var isHex = (contactId.length() >= 12);
        if (isHex) {
            for (var c = 0; c < 12; c++) {
                var ch = contactId.substring(c, c + 1);
                if ("0123456789ABCDEFabcdef".find(ch) == null) {
                    isHex = false;
                    break;
                }
            }
        }

        if (isHex) {
            for (var k = 0; k < 6; k++) {
                var sub = contactId.substring(k * 2, (k * 2) + 2);
                try {
                    prefix.add(sub.toNumberWithBase(16));
                } catch (e) {
                    prefix.add(0);
                }
            }
        } else {
            var raw = contactId.toUtf8Array();
            for (var b = 0; b < 6; b++) {
                prefix.add((b < raw.size()) ? raw[b] : 0);
            }
        }
        return prefix;
    }

    //! Encode a direct text message to a contact (CMD_SEND_TXT_MSG = 2)
    public function encodeContactMessage(contactId as String, text as String) as ByteArray {
        var textBytes = text.toUtf8Array();
        var now = Time.now().value(); // uint32 timestamp

        // Header: [CMD_SEND_TXT_MSG (1B), txt_type (1B=0 plain), attempt (1B=0), timestamp (4B little endian), pubkey_prefix (6B)]
        var payload = []b;
        payload.add(CMD_SEND_TXT_MSG); // 2
        payload.add(0);                 // txt_type: 0 = plain text
        payload.add(0);                 // attempt: 0

        // Timestamp little endian
        payload.add((now & 0xFF));
        payload.add(((now >> 8) & 0xFF));
        payload.add(((now >> 16) & 0xFF));
        payload.add(((now >> 24) & 0xFF));

        // PubKey prefix: 6 bytes
        var prefix = extractPubkeyPrefix(contactId);
        for (var p = 0; p < 6; p++) {
            payload.add(prefix[p]);
        }

        // Text bytes (max 160 bytes)
        for (var i = 0; i < textBytes.size() && i < 160; i++) {
            payload.add(textBytes[i]);
        }

        return payload;
    }

    //! Encode a command to query contacts list from node (all contacts)
    public function encodeGetContacts() as ByteArray {
        return [CMD_GET_CONTACTS]b;
    }

    public function encodeAppStart() as ByteArray {
        return [CMD_APP_START, 0, 0, 0, 0, 0, 0, 0]b;
    }

    public function encodeDeviceQuery() as ByteArray {
        return [CMD_DEVICE_QUERY, 3]b;
    }

    //! Encode incremental contacts query with 'since' timestamp
    public function encodeGetContactsSince(sinceTimestamp as Number) as ByteArray {
        return [
            CMD_GET_CONTACTS,
            (sinceTimestamp & 0xFF),
            ((sinceTimestamp >> 8) & 0xFF),
            ((sinceTimestamp >> 16) & 0xFF),
            ((sinceTimestamp >> 24) & 0xFF)
        ]b;
    }

    //! Encode a query for one channel slot
    public function encodeGetChannel(channelIdx as Number) as ByteArray {
        return [CMD_GET_CHANNEL, channelIdx]b;
    }

    //! Encode sync next message request
    public function encodeSyncNextMessage() as ByteArray {
        return [CMD_SYNC_NEXT_MESSAGE]b;
    }

    //! Encode set device time command (synchronizes GPS clock with node)
    public function encodeSetDeviceTime(timestamp as Number) as ByteArray {
        return [
            CMD_SET_DEVICE_TIME,
            (timestamp & 0xFF),
            ((timestamp >> 8) & 0xFF),
            ((timestamp >> 16) & 0xFF),
            ((timestamp >> 24) & 0xFF)
        ]b;
    }

    //! Encode battery and storage query
    public function encodeGetBattery() as ByteArray {
        return [CMD_GET_BATTERY_AND_STORAGE]b;
    }

    public function encodeGetStats(statsType as Number) as ByteArray {
        return [CMD_GET_STATS, statsType]b;
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
        var payload = []b;
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

        return payload;
    }

    //! Encode multi-sample bundled telemetry frame (15B Base + N*7B Deltas)
    public function encodeMultiSampleTelemetry(baseLat as Double, baseLon as Double, baseAlt as Float, baseHr as Number, deltaSamples as Array<Dictionary>) as ByteArray {
        var payload = []b;
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

        return payload;
    }
}
