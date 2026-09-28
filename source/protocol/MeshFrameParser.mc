import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.System;

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

    public const PUSH_CODE_ADVERT            as Number = 0x80;
    public const PUSH_CODE_PATH_UPDATED      as Number = 0x81;
    public const PUSH_CODE_SEND_CONFIRMED    as Number = 0x82;
    public const PUSH_CODE_MSG_WAITING       as Number = 0x83;
    public const PUSH_CODE_LOG_RX_DATA       as Number = 0x88;
    public const PUSH_CODE_NEW_ADVERT        as Number = 0x8A;

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
               code == RESP_CODE_CONTACT ||
               code == RESP_CODE_CHANNEL_INFO ||
               code >= 0x80;
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

    //! Safely decode UTF-8 bytes to String
    public function decodeText(value as ByteArray, offset as Number) as String? {
        if (value == null || offset >= value.size()) {
            return null;
        }
        var textBytes = [] as Array<Number>;
        for (var index = offset; index < value.size(); index++) {
            textBytes.add(value[index]);
        }
        try {
            return StringUtil.utf8ArrayToString(textBytes);
        } catch (e) {
            System.println("MeshFrameParser: invalid UTF-8 text");
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

        var text = decodeText(value, textOffset);
        if (text == null || text.length() == 0) {
            return null;
        }

        var channelIndex = value[offset] as Number;
        var sender = "Mesh";
        var message = text;
        var separator = text.find(": ");
        if (separator != null && separator > 0) {
            sender = text.substring(0, separator);
            message = text.substring(separator + 2, text.length());
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
    public function parseBinaryChannel(value as ByteArray) as Dictionary? {
        if (value == null || value.size() < 2) {
            return null;
        }
        var chIdx = value[1] as Number;
        var nameBytes = [] as Array<Number>;
        for (var i = 2; i < 34 && i < value.size() && value[i] != 0; i++) {
            nameBytes.add(value[i]);
        }
        var nameStr = StringUtil.utf8ArrayToString(nameBytes);
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
    public function parseBinaryContact(value as ByteArray) as Dictionary? {
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
            var nameStr = StringUtil.utf8ArrayToString(nameBytes);
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
            var idLen = value[1] as Number;
            if (value.size() >= 2 + idLen + 1) {
                var idBytes = [] as Array<Number>;
                for (var i = 2; i < 2 + idLen; i++) { idBytes.add(value[i]); }
                var idStr = StringUtil.utf8ArrayToString(idBytes);

                var nameLenIdx = 2 + idLen;
                var nameLen = value[nameLenIdx] as Number;
                if (value.size() >= nameLenIdx + 1 + nameLen) {
                    var nameBytes2 = [] as Array<Number>;
                    for (var j = nameLenIdx + 1; j < nameLenIdx + 1 + nameLen; j++) { nameBytes2.add(value[j]); }
                    var nameStr2 = StringUtil.utf8ArrayToString(nameBytes2);
                    return {
                        :id => idStr,
                        :name => nameStr2,
                        :advType => 1
                    };
                }
            }
        }
        return null;
    }
}
