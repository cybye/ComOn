import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

class ChatsListView extends WatchUi.View {
    private var _selectedIndex as Number = 0;
    private var _cachedItems as Array<Dictionary> = [] as Array<Dictionary>;
    private var _screenW as Number = 454;
    private var _fontBody as FontRef = Graphics.FONT_SYSTEM_TINY;
    private var _fontCaption as FontRef = Graphics.FONT_SYSTEM_XTINY;

    function initialize() {
        View.initialize();
        _screenW = DisplayProfile.screenW;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        DisplayProfile.init(dc);
        _screenW = dc.getWidth();
        _fontBody = Graphics.FONT_SYSTEM_TINY;
        _fontCaption = Graphics.FONT_SYSTEM_XTINY;
    }

    function onShow() as Void {
        updateItemList();
        WatchUi.requestUpdate();
    }

    public function updateItemList() as Void {
        var list = [] as Array<Dictionary>;

        // 1. Group Channels (e.g. #public)
        var channels = ContactManager.getChannels();
        for (var i = 0; i < channels.size(); i++) {
            var ch = channels[i];
            var idx = ch[:idx] as Number;
            var name = ch[:name] as String;
            var tid = "CH_" + idx;

            list.add({
                :tid => tid,
                :title => name,
                :isChannel => true,
                :idx => idx,
                :cid => null
            });
        }

        // 2. Direct Contacts (1:1 DMs) - Messenger principle: active chats only
        var contacts = ContactManager.getClientContacts();
        for (var j = 0; j < contacts.size(); j++) {
            var c = contacts[j];
            var cid = c[:id] as String;
            var cname = c[:name] as String;
            var tid = "CT_" + cid;

            var isActive = (ContactManager.isContactTarget && ContactManager.selectedContactId != null && ContactManager.selectedContactId.equals(cid));
            var hasMsgs = ChatHistoryManager.hasMessagesForTarget(tid);

            if (isActive || hasMsgs) {
                list.add({
                    :tid => tid,
                    :title => cname,
                    :isChannel => false,
                    :idx => -1,
                    :cid => cid
                });
            }
        }

        // Attach last message timestamp to each chat item for chronological sorting
        for (var k = 0; k < list.size(); k++) {
            var item = list[k];
            var lastM = ChatHistoryManager.getLastMessageForTarget(item[:tid] as String);
            var lastTime = (lastM != null && lastM[:time] != null) ? (lastM[:time] as Number) : 0;
            item[:lastTime] = lastTime;
        }

        // Sort descending by lastTime (most recent message at the very top)
        for (var a = 0; a < list.size() - 1; a++) {
            for (var b = 0; b < list.size() - 1 - a; b++) {
                var timeA = list[b][:lastTime] as Number;
                var timeB = list[b + 1][:lastTime] as Number;
                if (timeB > timeA) {
                    var temp = list[b];
                    list[b] = list[b + 1];
                    list[b + 1] = temp;
                }
            }
        }

        // 3. Action Card: "+ Neuer Chat" (always at the bottom of the list)
        var clientCount = ContactManager.getClientContactsCount();
        list.add({
            :tid => "ACTION_NEW_CHAT",
            :title => I18n.get(Rez.Strings.ActionNewChat),
            :isChannel => false,
            :idx => 0,
            :cid => null,
            :isAction => true,
            :contactCount => clientCount
        });

        _cachedItems = list;
        if (_selectedIndex >= _cachedItems.size() && _cachedItems.size() > 0) {
            _selectedIndex = _cachedItems.size() - 1;
        }
        if (_selectedIndex < 0) {
            _selectedIndex = 0;
        }
    }

    public function getItemsCount() as Number {
        return _cachedItems.size();
    }

    public function getSelectedIndex() as Number {
        return _selectedIndex;
    }

    public function getSelectedItem() as Dictionary? {
        if (_selectedIndex >= 0 && _selectedIndex < _cachedItems.size()) {
            return _cachedItems[_selectedIndex];
        }
        return null;
    }

    public function selectIndex(idx as Number) as Void {
        if (idx >= 0 && idx < _cachedItems.size()) {
            _selectedIndex = idx;
            WatchUi.requestUpdate();
        }
    }

    public function nextItem() as Void {
        if (_cachedItems.size() > 0 && _selectedIndex < _cachedItems.size() - 1) {
            _selectedIndex++;
            WatchUi.requestUpdate();
        }
    }

    public function previousItem() as Void {
        if (_cachedItems.size() > 0 && _selectedIndex > 0) {
            _selectedIndex--;
            WatchUi.requestUpdate();
        }
    }

    public function getCardIndexAt(x as Number, y as Number) as Number {
        var count = _cachedItems.size();
        if (count == 0) {
            return -1;
        }
        var cx = _screenW / 2;
        var cardW = DisplayProfile.scale(368);
        var cardH = DisplayProfile.scale(108);
        var cardGap = DisplayProfile.scale(16);
        var cardStep = cardH + cardGap;
        var cardX = cx - (cardW / 2);

        var margin = DisplayProfile.scale(25);
        if (x < (cardX - margin) || x > (cardX + cardW + margin)) {
            return -1;
        }

        var startY = DisplayProfile.scale(161) - (_selectedIndex * cardStep);
        var minY = DisplayProfile.scale(60);
        var maxY = DisplayProfile.scale(430);

        for (var i = 0; i < count; i++) {
            var cyCard = startY + (i * cardStep);
            if ((cyCard + cardH) >= minY && cyCard <= maxY) {
                if (y >= cyCard && y <= (cyCard + cardH)) {
                    return i;
                }
            }
        }
        return -1;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        _screenW = dc.getWidth();
        DisplayProfile.init(dc);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = _screenW / 2;
        var bleMgr = getBleManager();

        // 1. TOP CROWN HEADER (OPTION A)
        drawCrownHeader(dc, cx, _fontCaption, _fontBody, bleMgr);

        // 2. CHAT CARDS LIST (WHATSAPP STYLE - CENTERED AT EQUATOR)
        updateItemList();
        var count = _cachedItems.size();

        if (count == 0) {
            dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, DisplayProfile.scale(210), _fontBody, I18n.get(Rez.Strings.NoChats), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, DisplayProfile.scale(240), _fontCaption, I18n.get(Rez.Strings.PromptPressMenuForOptions), Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var cardW = DisplayProfile.scale(368);
        var cardH = DisplayProfile.scale(108);
        var cardGap = DisplayProfile.scale(16);
        var cardStep = cardH + cardGap;
        var cardX = cx - (cardW / 2);

        var startY = DisplayProfile.scale(161) - (_selectedIndex * cardStep);
        var minY = DisplayProfile.scale(60);
        var maxY = DisplayProfile.scale(430);

        for (var i = 0; i < count; i++) {
            var cyCard = startY + (i * cardStep);

            if ((cyCard + cardH) >= minY && cyCard <= maxY) {
                var isSelected = (i == _selectedIndex);
                drawChatCard(dc, cardX, cyCard, cardW, cardH, _cachedItems[i], isSelected, _fontCaption, _fontBody);
            }
        }

        // 3. SCROLL INDICATORS
        var arrowHalfW = DisplayProfile.scale(6);
        var topArrowY1 = DisplayProfile.scale(34);
        var topArrowY2 = DisplayProfile.scale(26);
        var botArrowY1 = DisplayProfile.scale(420);
        var botArrowY2 = DisplayProfile.scale(428);

        if (_selectedIndex > 0) {
            dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - arrowHalfW, topArrowY1], [cx + arrowHalfW, topArrowY1], [cx, topArrowY2]]);
        }
        if (_selectedIndex < count - 1) {
            dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - arrowHalfW, botArrowY1], [cx + arrowHalfW, botArrowY1], [cx, botArrowY2]]);
        }
    }

    //! Fast text truncation helper using binary search
    public static function truncateText(dc as Graphics.Dc, text as String, font as FontRef, maxW as Number) as String {
        if (text.length() == 0 || dc.getTextWidthInPixels(text, font) <= maxW) {
            return text;
        }
        var ellipsis = "..";
        var elW = dc.getTextWidthInPixels(ellipsis, font);
        if (elW >= maxW) {
            return "";
        }
        var low = 0;
        var high = text.length();
        var best = 0;
        while (low <= high) {
            var mid = (low + high) / 2;
            var sub = text.substring(0, mid) + ellipsis;
            if (dc.getTextWidthInPixels(sub, font) <= maxW) {
                best = mid;
                low = mid + 1;
            } else {
                high = mid - 1;
            }
        }
        return text.substring(0, best) + ellipsis;
    }

    //! Option A Crown Header: ComOn glyph + Live Node Telemetry with vector symbols
    private function drawCrownHeader(dc as Graphics.Dc, cx as Number, fontCaption as FontRef, fontBody as FontRef, bleMgr as MeshBleManager) as Void {
        var title = "ComOn";
        var titleW = dc.getTextWidthInPixels(title, fontBody);
        var iconW = DisplayProfile.scale(22);
        var iconH = DisplayProfile.scale(15);
        var iconGap = DisplayProfile.scale(7);
        var totalW = iconW + iconGap + titleW;
        var startX = cx - (totalW / 2);
        var iconY = DisplayProfile.scale(46);

        // Speech bubble glyph (Green WhatsApp style)
        dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
        var rBubble = DisplayProfile.scale(4);
        dc.fillRoundedRectangle(startX, iconY, iconW, iconH, rBubble);
        dc.fillPolygon([[startX + DisplayProfile.scale(4), iconY + iconH - 1], [startX, iconY + iconH + DisplayProfile.scale(4)], [startX + DisplayProfile.scale(9), iconY + iconH - 1]]);

        // Radio wave / RSS broadcast icon inside header speech bubble
        var dotX = startX + DisplayProfile.scale(7);
        var dotY = iconY + DisplayProfile.scale(11);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, dotY, 1);
        dc.setPenWidth(1);
        dc.drawArc(dotX, dotY, DisplayProfile.scale(3), Graphics.ARC_COUNTER_CLOCKWISE, 0, 90);
        dc.drawArc(dotX, dotY, DisplayProfile.scale(6), Graphics.ARC_COUNTER_CLOCKWISE, 0, 90);

        // App title "ComOn"
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + iconW + iconGap, iconY + (iconH / 2), fontBody, title, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Telemetry Subline
        var subY = DisplayProfile.scale(82);
        drawTelemetryBar(dc, cx, subY, fontCaption, bleMgr);
    }

    //! Draw compact vector battery and LoRa signal meter
    public static function drawTelemetryBar(dc as Graphics.Dc, cx as Number, y as Number, fontCaption as FontRef, bleMgr as MeshBleManager) as Void {
        var fontH = dc.getFontHeight(fontCaption);
        var yMid = y + (fontH / 2);

        if (bleMgr.isSyncing) {
            dc.setColor(0x00d4ff, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, yMid, fontCaption, I18n.get(Rez.Strings.StatusSyncing), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (bleMgr.isConnected) {
            var bat = bleMgr.nodeBatteryPercent;
            var batStr = (bat != null) ? (bat.toString() + "%") : "--%";
            var rssi = bleMgr.loraRssi;
            var rssiStr = (rssi != null) ? (rssi.toString() + "dBm") : "--";

            var batTextW = dc.getTextWidthInPixels(batStr, fontCaption);
            var rssiTextW = dc.getTextWidthInPixels(rssiStr, fontCaption);

            var bodyW = DisplayProfile.scale(17);
            var tipW = DisplayProfile.scale(3);
            var batIconW = bodyW + tipW;
            var sigIconW = DisplayProfile.scale(16);
            var gap5 = DisplayProfile.scale(5);
            var dotW = dc.getTextWidthInPixels("  •  ", fontCaption);

            var totalW = batIconW + gap5 + batTextW + dotW + sigIconW + gap5 + rssiTextW;
            var curX = cx - (totalW / 2);

            // 1. Battery Icon
            var batH = DisplayProfile.scale(10);
            var batY = yMid - (batH / 2);
            dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(curX, batY, bodyW, batH, 2);
            dc.fillRectangle(curX + bodyW, yMid - DisplayProfile.scale(2), tipW, DisplayProfile.scale(4));

            // Battery fill
            var fillPct = (bat != null) ? bat : 50;
            if (fillPct > 100) { fillPct = 100; }
            if (fillPct < 0) { fillPct = 0; }
            var innerMaxW = bodyW - DisplayProfile.scale(4);
            if (innerMaxW < 1) { innerMaxW = 1; }
            var fillW = ((innerMaxW * fillPct) / 100).toNumber();
            var batColor = (fillPct > 20) ? DisplayTheme.accent() : 0xff3b30;
            dc.setColor(batColor, Graphics.COLOR_TRANSPARENT);
            if (fillW > 0) {
                dc.fillRectangle(curX + DisplayProfile.scale(2), batY + DisplayProfile.scale(2), fillW, batH - DisplayProfile.scale(4));
            }

            // Battery percentage text
            curX += batIconW + gap5;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(curX, yMid - 1, fontCaption, batStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            // Separator bullet
            curX += batTextW;
            dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(curX, yMid - 1, fontCaption, "  •  ", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            // 2. LoRa Signal Bars
            curX += dotW;
            var sigBaseY = yMid + DisplayProfile.scale(5);
            var barsActive = 1;
            if (rssi != null) {
                if (rssi >= -70) { barsActive = 4; }
                else if (rssi >= -85) { barsActive = 3; }
                else if (rssi >= -105) { barsActive = 2; }
                else { barsActive = 1; }
            }
            var barHeights = [DisplayProfile.scale(3), DisplayProfile.scale(6), DisplayProfile.scale(9), DisplayProfile.scale(12)];
            var barW = DisplayProfile.scale(3);
            var barStep = DisplayProfile.scale(4);
            for (var b = 0; b < 4; b++) {
                var bh = barHeights[b];
                var bx = curX + (b * barStep);
                var by = sigBaseY - bh;
                var col = (b < barsActive) ? 0x00d4ff : DisplayTheme.divider();
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, barW, bh);
            }

            // LoRa RSSI text
            curX += sigIconW + gap5;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(curX, yMid - 1, fontCaption, rssiStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (bleMgr.isScanning) {
            dc.setColor(0x00d4ff, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, yMid, fontCaption, I18n.get(Rez.Strings.StatusScanning), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(0xffaa00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, yMid, fontCaption, I18n.get(Rez.Strings.StatusDisconnected), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    //! Render a single WhatsApp-style Chat Card
    private function drawChatCard(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, item as Dictionary, isSelected as Boolean, fontCaption as FontRef, fontBody as FontRef) as Void {
        if (item.hasKey(:isAction) && (item[:isAction] as Boolean) == true) {
            drawActionCard(dc, x, y, w, h, item, isSelected, fontCaption, fontBody);
            return;
        }

        var tid = item[:tid] as String;
        var title = item[:title] as String;
        var unread = ChatHistoryManager.getUnreadCountForTarget(tid);
        var lastMsg = ChatHistoryManager.getLastMessageForTarget(tid);

        var rCard = DisplayTheme.cardRadius();

        // 1. Card Fill
        dc.setColor(DisplayTheme.cardBg(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, rCard);

        // 2. Focus Border
        if (isSelected) {
            dc.setColor(DisplayTheme.focusBorder(), Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, h, rCard);
            dc.drawRoundedRectangle(x + 1, y + 1, w - 2, h - 2, (rCard > 1) ? (rCard - 1) : 1);
        } else {
            dc.setColor(DisplayTheme.cardBorder(), Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, h, rCard);
        }

        var pad18 = DisplayProfile.scale(18);

        // 3. Top Line: Chat Title + Timestamp
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var maxTitleW = w - DisplayProfile.scale(110);
        var displayTitle = truncateText(dc, title, fontBody, maxTitleW);
        dc.drawText(x + pad18, y + pad18, fontBody, displayTitle, Graphics.TEXT_JUSTIFY_LEFT);

        // Right: Timestamp in WhatsApp Green
        var timeStr = "";
        if (lastMsg != null) {
            timeStr = ChatHistoryManager.formatTimeAgo(lastMsg[:time] as Number);
        }
        if (timeStr.length() > 0) {
            dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + w - pad18, y + DisplayProfile.scale(20), fontCaption, timeStr, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // 4. Bottom Line: Last Message Preview + Unread Count Badge
        var preview = I18n.get(Rez.Strings.NoMessages);
        var isOutgoingLast = false;
        var lastStatus = 0;
        if (lastMsg != null) {
            isOutgoingLast = (lastMsg[:isOutgoing] == true);
            lastStatus = (lastMsg has :status && lastMsg[:status] != null) ? (lastMsg[:status] as Number) : 0;
            var s = isOutgoingLast ? I18n.get(Rez.Strings.SenderMe) : (lastMsg[:sender] as String);
            var txt = lastMsg[:text] as String;
            preview = s + ": " + txt;
        }

        var maxPreviewW = (unread > 0) ? (w - DisplayProfile.scale(78)) : (w - DisplayProfile.scale(54));
        var previewStartX = x + pad18;

        if (isOutgoingLast) {
            var checkW = (lastStatus == 2) ? DisplayProfile.scale(14) : DisplayProfile.scale(9);
            drawStatusCheckmark(dc, previewStartX, y + DisplayProfile.scale(66), lastStatus);
            previewStartX += checkW + DisplayProfile.scale(6);
            maxPreviewW -= (checkW + DisplayProfile.scale(6));
        }

        var displayPreview = truncateText(dc, preview, fontCaption, maxPreviewW);
        dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(previewStartX, y + DisplayProfile.scale(62), fontCaption, displayPreview, Graphics.TEXT_JUSTIFY_LEFT);

        // 5. Unread Count Badge
        if (unread > 0) {
            drawUnreadBadge(dc, x + w - DisplayProfile.scale(16), y + DisplayProfile.scale(75), unread, fontCaption);
        }
    }

    //! Draw unread badge pill/circle with count
    public static function drawUnreadBadge(dc as Graphics.Dc, rightX as Number, centerY as Number, unread as Number, font as FontRef) as Void {
        var unreadStr = (unread > 99) ? "99+" : unread.toString();
        var strW = dc.getTextWidthInPixels(unreadStr, font);

        var badgeH = DisplayProfile.scale(24);
        var badgeW = strW + DisplayProfile.scale(16);
        if (badgeW < badgeH) {
            badgeW = badgeH;
        }
        var badgeX = rightX - badgeW;
        var badgeY = centerY - (badgeH / 2);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(badgeX - 1, badgeY - 1, badgeW + 2, badgeH + 2, (badgeH + 2) / 2);
        dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(badgeX, badgeY, badgeW, badgeH, badgeH / 2);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(badgeX + (badgeW / 2), centerY, font, unreadStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Draw vector checkmark / status icon (Pending, Sent to node, Broadcast on mesh)
    public static function drawStatusCheckmark(dc as Graphics.Dc, x as Number, y as Number, status as Number) as Void {
        var p4 = DisplayProfile.scale(4);
        var p2 = DisplayProfile.scale(2);
        var p3 = DisplayProfile.scale(3);
        var p7 = DisplayProfile.scale(7);
        var p8 = DisplayProfile.scale(8);
        var p1 = DisplayProfile.scale(1);
        var p5 = DisplayProfile.scale(5);
        var p13 = DisplayProfile.scale(13);

        if (status == 0) {
            dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawCircle(x + p4, y + p4, p3);
            dc.drawLine(x + p4, y + p2, x + p4, y + p4);
            dc.drawLine(x + p4, y + p4, x + p4 + p2, y + p4);
        } else if (status == 1) {
            dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(x, y + p4, x + p3, y + p7);
            dc.drawLine(x + p3, y + p7, x + p8, y + p1);
            dc.setPenWidth(1);
        } else if (status >= 2) {
            dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(x, y + p4, x + p3, y + p7);
            dc.drawLine(x + p3, y + p7, x + p8, y + p1);
            dc.drawLine(x + p5, y + p4, x + p8, y + p7);
            dc.drawLine(x + p8, y + p7, x + p13, y + p1);
            dc.setPenWidth(1);
        }
    }

    //! Render an Action Card (e.g. "+ Neuer Chat")
    private function drawActionCard(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, item as Dictionary, isSelected as Boolean, fontCaption as FontRef, fontBody as FontRef) as Void {
        var title = item[:title] as String;
        var count = item.hasKey(:contactCount) ? (item[:contactCount] as Number) : 0;
        var subText = I18n.format(Rez.Strings.ActionNewChatSub, [ count ]);

        var rCard = DisplayTheme.cardRadius();
        var pad18 = DisplayProfile.scale(18);

        // 1. Card Fill
        dc.setColor(DisplayTheme.cardBg(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, rCard);

        // 2. Focus Border
        if (isSelected) {
            dc.setColor(DisplayTheme.focusBorder(), Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, h, rCard);
            dc.drawRoundedRectangle(x + 1, y + 1, w - 2, h - 2, (rCard > 1) ? (rCard - 1) : 1);
        } else {
            dc.setColor(DisplayTheme.cardBorder(), Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, h, rCard);
        }

        // 3. Top Line: Title in WhatsApp Green
        dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + pad18, y + pad18, fontBody, title, Graphics.TEXT_JUSTIFY_LEFT);

        // Right side: chevron ">"
        dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w - DisplayProfile.scale(22), y + (h / 2), fontBody, ">", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // 4. Bottom Line: Subtitle ("X Kontakte")
        dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + pad18, y + DisplayProfile.scale(62), fontCaption, subText, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
