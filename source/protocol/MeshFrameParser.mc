import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.System;

(:background)
module MeshFrameParser {
    // Shared Protocol Command Codes
    public const CMD_SYNC_NEXT_MESSAGE       as Number = 10;
    public const CMD_GET_BATTERY_AND_STORAGE as Number = 20;

    // Shared Response and Push Codes
    public const RESP_CODE_OK                as Number = 0;
    public const RESP_CODE_ERR               as Number = 1;
    public const RESP_CODE_CONTACTS_START    as Number = 2;
    public const RESP_CODE_CONTACT           as Number = 3;
    public const RESP_CODE_END_OF_CONTACTS   as Number = 4;
    public const RESP_CODE_SELF_INFO         as Number = 5;
    public const RESP_CODE_SENT              as Number = 6;
    public const RESP_CODE_CONTACT_MSG       as Number = 7;
    public const RESP_CODE_CHANNEL_MSG       as Number = 8;
    public const RESP_CODE_NO_MORE_MESSAGES  as Number = 10;
    public const RESP_CODE_BATT_AND_STORAGE  as Number = 12;
    public const RESP_CODE_DEVICE_INFO       as Number = 13;
    public const RESP_CODE_CONTACT_MSG_V3    as Number = 16;
    public const RESP_CODE_CHANNEL_MSG_V3    as Number = 17;
    public const RESP_CODE_CHANNEL_INFO      as Number = 18;
    public const RESP_CODE_STATS             as Number = 24;
    public const RESP_CODE_CHANNEL_DATA_RECV as Number = 27; // 0x1B: Inbound channel datagram

    public const PUSH_CODE_ADVERT            as Number = 0x80;
    public const PUSH_CODE_PATH_UPDATED      as Number = 0x81;
    public const PUSH_CODE_SEND_CONFIRMED    as Number = 0x82;
    public const PUSH_CODE_MSG_WAITING       as Number = 0x83;
    public const PUSH_CODE_LOG_RX_DATA       as Number = 0x88;
    public const PUSH_CODE_NEW_ADVERT        as Number = 0x8A;

    public const CONTACT_FRAME_SIZE          as Number = 148;
    public const CHANNEL_INFO_FRAME_SIZE     as Number = 50;
    public const ADVERT_FRAME_SIZE           as Number = 33;

    public function isControlFrame(code as Number) as Boolean {
        return code == RESP_CODE_NO_MORE_MESSAGES ||
               code == RESP_CODE_ERR ||
               code == RESP_CODE_BATT_AND_STORAGE ||
               isMessageFrame(code) ||
               code >= 0x80;
    }

    public function isMessageFrame(code as Number) as Boolean {
        return code == RESP_CODE_CONTACT_MSG ||
               code == RESP_CODE_CHANNEL_MSG ||
               code == RESP_CODE_CONTACT_MSG_V3 ||
               code == RESP_CODE_CHANNEL_MSG_V3;
    }

    public function isFragmentablePacket(code as Number) as Boolean {
        return isMessageFrame(code) ||
               code == RESP_CODE_CHANNEL_DATA_RECV ||
               code == RESP_CODE_CONTACT ||
               code == RESP_CODE_CHANNEL_INFO ||
               code == RESP_CODE_SELF_INFO ||
               code == RESP_CODE_DEVICE_INFO ||
               code >= 0x80;
    }

    //! Detects when the nRF52 BLE UART transport aborts a partial multi-chunk notification
    //! and retries transmitting the exact same frame from byte 0.
    public function isFragmentRetry(buffer as ByteArray?, chunk as ByteArray?) as Boolean {
        if (buffer == null || chunk == null || chunk.size() < 20 || buffer.size() < 20) {
            return false;
        }
        for (var i = 0; i < 20; i++) {
            if (buffer[i] != chunk[i]) {
                return false;
            }
        }
        return true;
    }

    //! Checks whether a frame (either single-chunk or reassembled) has reached its known protocol length.
    public function isCompleteKnownSizeFrame(buffer as ByteArray?) as Boolean {
        if (buffer == null || buffer.size() == 0) {
            return false;
        }
        var code = buffer[0] as Number;
        if (code == RESP_CODE_CONTACT || code == PUSH_CODE_NEW_ADVERT) {
            return buffer.size() >= CONTACT_FRAME_SIZE;
        }
        if (code == RESP_CODE_CHANNEL_INFO) {
            return buffer.size() >= CHANNEL_INFO_FRAME_SIZE;
        }
        if (code == RESP_CODE_CHANNEL_DATA_RECV) {
            if (buffer.size() < 9) {
                return false;
            }
            var dataLen = (buffer[8] as Number) & 0xFF;
            return buffer.size() >= (9 + dataLen);
        }
        if (code == PUSH_CODE_ADVERT || code == PUSH_CODE_PATH_UPDATED) {
            return buffer.size() >= ADVERT_FRAME_SIZE;
        }
        return false;
    }

    //! Validates whether a chunk is the start of a new message frame (0x07, 0x08, 0x10, 0x11).
    public function isNewMessageHeader(chunk as ByteArray?) as Boolean {
        if (chunk == null || chunk.size() < 12) {
            return false;
        }
        var code = chunk[0] as Number;
        if (code == RESP_CODE_CHANNEL_MSG || code == RESP_CODE_CHANNEL_MSG_V3) {
            if (code == RESP_CODE_CHANNEL_MSG_V3 && (chunk[2] != 0 || chunk[3] != 0)) {
                return false;
            }
            var parsed = parseChannelMessage(chunk);
            return parsed != null && parsed.hasKey(:text);
        }
        if (code == RESP_CODE_CONTACT_MSG || code == RESP_CODE_CONTACT_MSG_V3) {
            if (code == RESP_CODE_CONTACT_MSG_V3 && (chunk[2] != 0 || chunk[3] != 0)) {
                return false;
            }
            var parsed = parseDirectMessage(chunk);
            return parsed != null && parsed.hasKey(:text);
        }
        return false;
    }

    //! Validates whether a chunk is the start of a channel data datagram (0x1B).
    public function isChannelDataHeader(chunk as ByteArray?) as Boolean {
        if (chunk == null || chunk.size() < 9) {
            return false;
        }
        var code = chunk[0] as Number;
        if (code != RESP_CODE_CHANNEL_DATA_RECV) {
            return false;
        }
        // Bytes 2..3 are reserved (0x00, 0x00), byte 4 is channel_idx (0..15)
        var chIdx = (chunk[4] as Number) & 0xFF;
        return chunk[2] == 0 && chunk[3] == 0 && chIdx < 16;
    }

    //! Determines if an incoming BLE chunk is a true protocol frame boundary that must close
    //! an open fragment buffer before processing the new chunk.
    public function isFrameBoundary(buffer as ByteArray?, chunk as ByteArray?) as Boolean {
        if (buffer == null || buffer.size() == 0 || chunk == null || chunk.size() == 0) {
            return false;
        }
        var bufCode = buffer[0] as Number;
        var firstByte = chunk[0] as Number;
        var chunkSize = chunk.size();

        // Single-byte control responses
        if (chunkSize == 1) {
            // Note: If buffer is currently collecting a text message, a 1-byte 0x0A is a trailing '\n'
            // character because the next message has not been requested yet.
            if (firstByte == RESP_CODE_NO_MORE_MESSAGES && !isMessageFrame(bufCode)) {
                return true;
            }
            if (firstByte == RESP_CODE_OK || firstByte == RESP_CODE_ERR || firstByte == PUSH_CODE_MSG_WAITING) {
                return true;
            }
            return false;
        }

        // 2-byte error response [RESP_CODE_ERR, err_code]
        if (chunkSize == 2 && firstByte == RESP_CODE_ERR && ((chunk[1] as Number) & 0xFF) <= 16 && !isMessageFrame(bufCode)) {
            return true;
        }

        // Fixed-size frames (0x03, 0x8A, 0x12, 0x1B) should not be split by heuristic headers mid-frame
        if (bufCode == RESP_CODE_CONTACT || bufCode == PUSH_CODE_NEW_ADVERT ||
            bufCode == RESP_CODE_CHANNEL_INFO || bufCode == RESP_CODE_CHANNEL_DATA_RECV) {
            return false;
        }

        if (isMessageFrame(firstByte) && isNewMessageHeader(chunk)) {
            return true;
        }
        if (firstByte == RESP_CODE_CHANNEL_DATA_RECV && isChannelDataHeader(chunk)) {
            return true;
        }
        return false;
    }

    //! Parse battery voltage and calculate percentage
    //! Returns Dictionary with :mv and :percent, or null if frame invalid
    public function parseBattery(value as ByteArray) as Dictionary? {
        if (value == null || value.size() < 3) {
            return null;
        }
        var mv = (value[1] as Number) | ((value[2] as Number) << 8);
        var percent = 0;
        if (mv > 5000) {
            // 2S battery pack (6.6V - 8.4V)
            percent = (((mv - 6600) * 100) / 1800).toNumber();
        } else {
            // 1S LiPo pack (3.3V - 4.2V)
            percent = (((mv - 3300) * 100) / 900).toNumber();
        }
        if (percent < 0) { percent = 0; }
        if (percent > 100) { percent = 100; }

        return {
            :mv => mv,
            :percent => percent
        };
    }

    //! Safely decode UTF-8 byte array to String with graceful fallback to printable ASCII or null
    public function safeUtf8(bytes as Array<Number> or ByteArray or Null) as String? {
        if (bytes == null || bytes.size() == 0) {
            return null;
        }
        var numArr;
        if (bytes instanceof Array) {
            numArr = bytes;
        } else {
            numArr = [] as Array<Number>;
            for (var idx = 0; idx < bytes.size(); idx++) {
                numArr.add(bytes[idx] as Number);
            }
        }
        try {
            return StringUtil.utf8ArrayToString(numArr);
        } catch (e) {
            try {
                var asciiChars = [] as Array<Char>;
                for (var i = 0; i < numArr.size(); i++) {
                    var b = numArr[i] as Number;
                    if (b >= 32 && b <= 126) {
                        asciiChars.add(b.toChar());
                    }
                }
                if (asciiChars.size() > 0) {
                    return StringUtil.charArrayToString(asciiChars);
                }
            } catch (ex) {
                // Ignore fallback exception
            }
            return null;
        }
    }

    //! Safely decode UTF-8 bytes to String, stopping at C-string null terminator (0x00)
    //! and rejecting binary control characters.
    public function decodeText(value as ByteArray, offset as Number) as String? {
        if (value == null || offset >= value.size()) {
            return null;
        }
        var textBytes = [] as Array<Number>;
        var hasPrintable = false;
        for (var index = offset; index < value.size(); index++) {
            var b = (value[index] as Number) & 0xFF;
            if (b == 0) {
                break; // C-string null terminator
            }
            // Reject binary control bytes (except \t=9, \n=10, \r=13)
            if ((b < 32 && b != 9 && b != 10 && b != 13) || b == 127) {
                return null;
            }
            if (b > 32) {
                hasPrintable = true;
            }
            textBytes.add(b);
        }
        if (!hasPrintable || textBytes.size() == 0) {
            return null;
        }
        try {
            return StringUtil.utf8ArrayToString(textBytes);
        } catch (e) {
            return null;
        }
    }

    //! Parse incoming channel message (v1: code=8, v3: code=17)
    //! Returns Dictionary with :channelIdx, :sender, :text, :snr (optional)
    public function parseChannelMessage(value as ByteArray) as Dictionary? {
        if (value == null || value.size() == 0) {
            return null;
        }
        var code = value[0] as Number;
        if (code != RESP_CODE_CHANNEL_MSG && code != RESP_CODE_CHANNEL_MSG_V3) {
            return null;
        }

        var isV3 = (code == RESP_CODE_CHANNEL_MSG_V3);
        var offset = isV3 ? 4 : 1;
        var textOffset = offset + 7;
        if (value.size() <= textOffset) {
            return null;
        }

        var channelIndex = (value[offset] as Number) & 0xFF;
        if (channelIndex >= 16) {
            return null;
        }

        var txtType = (value[offset + 2] as Number) & 0xFF;
        if (txtType > 2) {
            return null;
        }
        if (txtType == 2) {
            // TXT_TYPE_SIGNED_PLAIN includes a 4-byte sender signature before the UTF-8 text
            textOffset += 4;
            if (value.size() <= textOffset) {
                return null;
            }
        }

        var text = decodeText(value, textOffset);
        if (text == null || text.length() == 0) {
            return null;
        }

        var sender = "Mesh";
        var message = text;
        var separator = text.find(": ");
        if (separator != null && separator > 0) {
            sender = text.substring(0, separator);
            message = text.substring(separator + 2, text.length());
        }
        if (message == null || message.length() == 0) {
            return null;
        }

        var result = {
            :channelIdx => channelIndex,
            :sender => sender,
            :text => message
        };

        if (isV3) {
            var snr = value[1] as Number;
            if (snr > 127) { snr -= 256; }
            result[:snr] = (snr / 4).toNumber();
        }

        return result;
    }

    //! Parse incoming channel data datagram (code=27 / 0x1B)
    //! Extracts SNR for telemetry without treating binary data as a chat message.
    //! Returns Dictionary with :snr or null
    public function parseChannelData(value as ByteArray) as Dictionary? {
        if (value == null || value.size() < 2) {
            return null;
        }
        var code = value[0] as Number;
        if (code != RESP_CODE_CHANNEL_DATA_RECV) {
            return null;
        }
        var snr = value[1] as Number;
        if (snr > 127) { snr -= 256; }

        return {
            :snr => (snr / 4).toNumber()
        };
    }

    //! Parse incoming direct contact message (v1: code=7, v3: code=16)
    //! Returns Dictionary with :senderHex, :text, :snr (optional)
    public function parseDirectMessage(value as ByteArray) as Dictionary? {
        if (value == null || value.size() == 0) {
            return null;
        }
        var code = value[0] as Number;
        if (code != RESP_CODE_CONTACT_MSG && code != RESP_CODE_CONTACT_MSG_V3) {
            return null;
        }

        var isV3 = (code == RESP_CODE_CONTACT_MSG_V3);
        var pubkeyOffset = isV3 ? 4 : 1;
        var textOffset = pubkeyOffset + 12; // pubkey(6) + path_len(1) + txt_type(1) + timestamp(4)
        if (value.size() <= textOffset) {
            return null;
        }

        var txtType = (value[pubkeyOffset + 7] as Number) & 0xFF;
        if (txtType > 2) {
            return null;
        }
        if (txtType == 2) {
            // TXT_TYPE_SIGNED_PLAIN includes a 4-byte sender signature before the UTF-8 text
            textOffset += 4;
            if (value.size() <= textOffset) {
                return null;
            }
        }

        var senderHex = "";
        for (var index = pubkeyOffset; index < pubkeyOffset + 6 && index < value.size(); index++) {
            senderHex += (value[index] & 0xFF).format("%02X");
        }

        var text = decodeText(value, textOffset);
        if (text == null || text.length() == 0) {
            return null;
        }

        var result = {
            :senderHex => senderHex,
            :text => text
        };

        if (isV3) {
            var snr = value[1] as Number;
            if (snr > 127) { snr -= 256; }
            result[:snr] = (snr / 4).toNumber();
        }

        return result;
    }

    //! Parse binary channel info frame (code=18)
    //! Returns Dictionary with :channelIdx, :name or null
    public function parseBinaryChannel(value as ByteArray or Null) as Dictionary? {
        if (value == null || value.size() < 2) {
            return null;
        }

        var chIdx = value[1] as Number;
        var nameEnd = value.size() > 34 ? 34 : value.size();
        var i = 2;
        while (i < nameEnd && value[i] != 0) {
            i++;
        }
        var nameBytes = [] as Array<Number>;
        for (var j = 2; j < i; j++) {
            nameBytes.add(value[j] as Number);
        }
        var nameStr = safeUtf8(nameBytes);
        if (nameStr == null || nameStr.length() == 0) {
            if (chIdx == 0) {
                nameStr = "public";
            } else {
                return null;
            }
        }
        return {
            :channelIdx => chIdx,
            :name => nameStr
        };
    }

    //! Parse binary contact frame (code=3 or push advert)
    //! Returns Dictionary with :id, :name, :advType or null
    public function parseBinaryContact(value as ByteArray or Null) as Dictionary? {
        if (value == null) {
            return null;
        }
        if (value.size() >= 132) {
            // Hardware format
            var idHex = "";
            for (var k = 1; k <= 6 && k < value.size(); k++) {
                var b = value[k] & 0xFF;
                idHex += b.format("%02X");
            }
            var advType = (value.size() > 33) ? (value[33] as Number) : 1;
            var nameBytes = [] as Array<Number>;
            for (var n = 100; n < 132 && n < value.size() && value[n] != 0; n++) {
                nameBytes.add(value[n]);
            }
            var nameStr = safeUtf8(nameBytes);
            if (nameStr == null || nameStr.length() == 0) {
                nameStr = "Node " + idHex;
            }
            return {
                :id => idHex,
                :name => nameStr,
                :advType => advType
            };
        } else if (value.size() >= 4) {
            // Compact / Simulator format: [3, idLen, idBytes..., nameLen, nameBytes...]
            // Only process if packet strictly matches the simulated envelope structure
            var idLen = value[1] as Number;
            var nameLenIdx = 2 + idLen;
            if (idLen > 0 && idLen < 32 && value.size() > nameLenIdx) {
                var nameLen = value[nameLenIdx] as Number;
                var totalExpected = nameLenIdx + 1 + nameLen;
                // Accept trailing bytes (e.g. null terminators) beyond the declared lengths.
                if (nameLen >= 0 && nameLen < 64 && value.size() >= totalExpected) {
                    var idBytes = [] as Array<Number>;
                    for (var i = 2; i < 2 + idLen; i++) { idBytes.add(value[i]); }
                    var idStr = safeUtf8(idBytes);

                    var nameBytes2 = [] as Array<Number>;
                    for (var j = nameLenIdx + 1; j < totalExpected; j++) { nameBytes2.add(value[j]); }
                    var nameStr2 = safeUtf8(nameBytes2);

                    if (idStr != null && idStr.length() > 0) {
                        return {
                            :id => idStr,
                            :name => (nameStr2 != null && nameStr2.length() > 0) ? nameStr2 : ("Node " + idStr),
                            :advType => 1
                        };
                    }
                }
            }
        }
        return null;
    }
}
