import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

class ChatsListView extends WatchUi.View {
    private var _selectedIndex as Number = 0;
    private var _cachedItems as Array<Dictionary> = [] as Array<Dictionary>;

    function initialize() {
        View.initialize();
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
                    :idx => 0,
                    :cid => cid,
                    :isAction => false
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
        // Bubble sort / insertion sort (list is typically small, < 20 items)
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

    private var _screenW as Number = 454;

    public function getCardIndexAt(x as Number, y as Number) as Number {
        var count = _cachedItems.size();
        if (count == 0) {
            return -1;
        }
        var cx = _screenW / 2;
        var cardW = 368;
        var cardH = 108;
        var cardGap = 16;
        var cardStep = cardH + cardGap;
        var cardX = cx - (cardW / 2);

        if (x < (cardX - 25) || x > (cardX + cardW + 25)) {
            return -1;
        }

        var startY = 161 - (_selectedIndex * cardStep);

        for (var i = 0; i < count; i++) {
            var cyCard = startY + (i * cardStep);
            if ((cyCard + cardH) >= 60 && cyCard <= 430) {
                if (y >= cyCard && y <= (cyCard + cardH)) {
                    return i;
                }
            }
        }
        return -1;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        _screenW = dc.getWidth();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = _screenW / 2;

        var fontXtiny = Graphics.FONT_SYSTEM_XTINY;
        var fontTiny  = Graphics.FONT_SYSTEM_TINY;

        var bleMgr = getBleManager();

        // ==========================================
        // 1. TOP CROWN HEADER (OPTION A)
        // ==========================================
        drawCrownHeader(dc, cx, fontXtiny, fontTiny, bleMgr);

        // ==========================================
        // 2. CHAT CARDS LIST (WHATSAPP STYLE - CENTERED AT EQUATOR)
        // ==========================================
        updateItemList();
        var count = _cachedItems.size();

        if (count == 0) {
            // Empty placeholder
            dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 210, fontTiny, I18n.get(Rez.Strings.NoChats), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, 240, fontXtiny, I18n.get(Rez.Strings.PromptPressMenuForOptions), Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var cardW = 368;
        var cardH = 108;
        var cardGap = 16;
        var cardStep = cardH + cardGap;
        var cardX = cx - (cardW / 2);

        // Center selected card at the equator (card center y = 215, top = 161)
        var startY = 161 - (_selectedIndex * cardStep);

        for (var i = 0; i < count; i++) {
            var cyCard = startY + (i * cardStep);

            if ((cyCard + cardH) >= 60 && cyCard <= 430) {
                var isSelected = (i == _selectedIndex);
                drawChatCard(dc, cardX, cyCard, cardW, cardH, _cachedItems[i], isSelected, fontXtiny, fontTiny);
            }
        }

        // ==========================================
        // 3. SCROLL INDICATORS
        // ==========================================
        if (_selectedIndex > 0) {
            dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - 6, 34], [cx + 6, 34], [cx, 26]]);
        }
        if (_selectedIndex < count - 1) {
            dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - 6, 420], [cx + 6, 420], [cx, 428]]);
        }
    }

    //! Option A Crown Header: ComOn glyph + Live Node Telemetry with vector symbols
    private function drawCrownHeader(dc as Graphics.Dc, cx as Number, fontXtiny as Graphics.FontDefinition, fontTiny as Graphics.FontDefinition, bleMgr as MeshBleManager) as Void {
        var title = "ComOn";
        var titleW = dc.getTextWidthInPixels(title, fontTiny);
        var iconW = 22;
        var iconH = 15;
        var iconGap = 7;
        var totalW = iconW + iconGap + titleW;
        var startX = cx - (totalW / 2);
        var iconY = 46;

        // Speech bubble glyph (Green WhatsApp style)
        dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT); // WhatsApp Green
        dc.fillRoundedRectangle(startX, iconY, iconW, iconH, 4);
        dc.fillPolygon([[startX + 4, iconY + iconH - 1], [startX, iconY + iconH + 4], [startX + 9, iconY + iconH - 1]]);

        // Radio wave / RSS broadcast icon inside header speech bubble
        var dotX = startX + 7;
        var dotY = iconY + 11;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // Origin dot
        dc.fillCircle(dotX, dotY, 1);
        // Arcs radiating towards top-right (0 to 90 degrees)
        dc.setPenWidth(1);
        // Inner arc (radius 3)
        dc.drawArc(dotX, dotY, 3, Graphics.ARC_COUNTER_CLOCKWISE, 0, 90);
        // Outer arc (radius 6)
        dc.drawArc(dotX, dotY, 6, Graphics.ARC_COUNTER_CLOCKWISE, 0, 90);

        // App title "ComOn"
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + iconW + iconGap, iconY + (iconH / 2), fontTiny, title, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Telemetry Subline: Live Node Battery & LoRa Signal with Vector Icons
        var subY = 82;
        drawTelemetryBar(dc, cx, subY, fontXtiny, bleMgr);
    }

    //! Draw compact vector battery and LoRa signal meter
    public static function drawTelemetryBar(dc as Graphics.Dc, cx as Number, y as Number, fontXtiny as Graphics.FontDefinition, bleMgr as MeshBleManager) as Void {
        var fontH = dc.getFontHeight(fontXtiny);
        var yMid = y + (fontH / 2);

        if (bleMgr.isSyncing) {
            dc.setColor(0x00d4ff, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, yMid, fontXtiny, I18n.get(Rez.Strings.StatusSyncing), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (bleMgr.isConnected) {
            var bat = bleMgr.nodeBatteryPercent;
            var batStr = (bat != null) ? (bat.toString() + "%") : "--%";
            var rssi = bleMgr.loraRssi;
            var rssiStr = (rssi != null) ? (rssi.toString() + "dBm") : "--";

            var batTextW = dc.getTextWidthInPixels(batStr, fontXtiny);
            var rssiTextW = dc.getTextWidthInPixels(rssiStr, fontXtiny);

            var batIconW = 20; // 17 body + 3 nipple
            var sigIconW = 16; // 4 bars
            var dotW = dc.getTextWidthInPixels("  •  ", fontXtiny);

            var totalW = batIconW + 5 + batTextW + dotW + sigIconW + 5 + rssiTextW;
            var curX = cx - (totalW / 2);

            // 1. Battery Icon (perfectly centered on yMid)
            var batH = 10;
            var batY = yMid - (batH / 2);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(curX, batY, 17, batH, 2);
            dc.fillRectangle(curX + 17, yMid - 2, 2, 4); // positive tip centered

            // Battery fill
            var fillPct = (bat != null) ? bat : 50;
            if (fillPct > 100) { fillPct = 100; }
            if (fillPct < 0) { fillPct = 0; }
            var fillW = ((13 * fillPct) / 100).toNumber();
            var batColor = (fillPct > 20) ? 0x00e676 : 0xff3b30;
            dc.setColor(batColor, Graphics.COLOR_TRANSPARENT);
            if (fillW > 0) {
                dc.fillRectangle(curX + 2, batY + 2, fillW, batH - 4);
            }

            // Battery percentage text
            curX += batIconW + 5;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(curX, yMid - 1, fontXtiny, batStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            // Separator bullet
            curX += batTextW;
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(curX, yMid - 1, fontXtiny, "  •  ", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            // 2. LoRa Signal Bars (aligned to digit baseline)
            curX += dotW;
            var sigBaseY = yMid + 5; // Text baseline alignment
            var barsActive = 1;
            if (rssi != null) {
                if (rssi >= -70) { barsActive = 4; }
                else if (rssi >= -85) { barsActive = 3; }
                else if (rssi >= -105) { barsActive = 2; }
                else { barsActive = 1; }
            }
            var barHeights = [3, 6, 9, 12];
            for (var b = 0; b < 4; b++) {
                var bh = barHeights[b];
                var bx = curX + (b * 4);
                var by = sigBaseY - bh;
                var col = (b < barsActive) ? 0x00d4ff : 0x334455;
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, 3, bh);
            }

            // LoRa RSSI text
            curX += sigIconW + 5;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(curX, yMid - 1, fontXtiny, rssiStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (bleMgr.isScanning) {
            dc.setColor(0x00d4ff, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, yMid, fontXtiny, I18n.get(Rez.Strings.StatusScanning), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(0xffaa00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, yMid, fontXtiny, I18n.get(Rez.Strings.StatusDisconnected), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    //! Render a single WhatsApp-style Chat Card
    private function drawChatCard(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, item as Dictionary, isSelected as Boolean, fontXtiny as Graphics.FontDefinition, fontTiny as Graphics.FontDefinition) as Void {
        if (item.hasKey(:isAction) && (item[:isAction] as Boolean) == true) {
            drawActionCard(dc, x, y, w, h, item, isSelected, fontXtiny, fontTiny);
            return;
        }

        var tid = item[:tid] as String;
        var title = item[:title] as String;
        var unread = ChatHistoryManager.getUnreadCountForTarget(tid);
        var lastMsg = ChatHistoryManager.getLastMessageForTarget(tid);

        // 1. Card Fill
        dc.setColor(0x151b24, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 18);

        // 2. Focus Border
        if (isSelected) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, h, 18);
            dc.drawRoundedRectangle(x + 1, y + 1, w - 2, h - 2, 17);
        } else {
            dc.setColor(0x2a3647, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, h, 18);
        }

        // 3. Top Line: Chat Title + Timestamp
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var maxTitleW = w - 110;
        var displayTitle = title;
        if (dc.getTextWidthInPixels(displayTitle, fontTiny) > maxTitleW) {
            while (displayTitle.length() > 2 && dc.getTextWidthInPixels(displayTitle + "..", fontTiny) > maxTitleW) {
                displayTitle = displayTitle.substring(0, displayTitle.length() - 1);
            }
            displayTitle = displayTitle + "..";
        }
        dc.drawText(x + 18, y + 18, fontTiny, displayTitle, Graphics.TEXT_JUSTIFY_LEFT);

        // Right: Timestamp in WhatsApp Green
        var timeStr = "";
        if (lastMsg != null) {
            timeStr = ChatHistoryManager.formatTimeAgo(lastMsg[:time] as Number);
        }
        if (timeStr.length() > 0) {
            dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT); // WhatsApp Green
            dc.drawText(x + w - 18, y + 20, fontXtiny, timeStr, Graphics.TEXT_JUSTIFY_RIGHT);
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

        // Ensure preview text strictly truncates before colliding with badge
        var maxPreviewW = (unread > 0) ? (w - 78) : (w - 54);
        var previewStartX = x + 18;

        // If outgoing message, draw status checkmark before preview text
        if (isOutgoingLast) {
            var checkW = (lastStatus == 2) ? 14 : 9;
            drawStatusCheckmark(dc, previewStartX, y + 66, lastStatus);
            previewStartX += checkW + 6;
            maxPreviewW -= (checkW + 6);
        }

        var displayPreview = preview;
        if (dc.getTextWidthInPixels(displayPreview, fontXtiny) > maxPreviewW) {
            while (displayPreview.length() > 3 && dc.getTextWidthInPixels(displayPreview + "...", fontXtiny) > maxPreviewW) {
                displayPreview = displayPreview.substring(0, displayPreview.length() - 1);
            }
            displayPreview = displayPreview + "...";
        }

        dc.setColor(0x9aa8b8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(previewStartX, y + 62, fontXtiny, displayPreview, Graphics.TEXT_JUSTIFY_LEFT);

        // 5. Unread Count Badge in bottom-right corner (underneath timestamp)
        if (unread > 0) {
            drawUnreadBadge(dc, x + w - 16, y + 75, unread, fontXtiny);
        }
    }

    //! Draw unread badge pill/circle with count
    public static function drawUnreadBadge(dc as Graphics.Dc, rightX as Number, centerY as Number, unread as Number, font as Graphics.FontDefinition) as Void {
        var unreadStr = (unread > 99) ? "99+" : unread.toString();
        var strW = dc.getTextWidthInPixels(unreadStr, font);
        
        var badgeH = 24;
        var badgeW = strW + 16;
        if (badgeW < badgeH) {
            badgeW = badgeH;
        }
        var badgeX = rightX - badgeW;
        var badgeY = centerY - (badgeH / 2);

        // Dark outline separates the count from the card while preserving a compact badge.
        dc.setColor(0x06110c, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(badgeX - 1, badgeY - 1, badgeW + 2, badgeH + 2, (badgeH + 2) / 2);
        dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(badgeX, badgeY, badgeW, badgeH, badgeH / 2);

        dc.setColor(0x062b14, Graphics.COLOR_TRANSPARENT);
        dc.drawText(badgeX + (badgeW / 2), centerY, font, unreadStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Draw vector checkmark / status icon (Pending, Sent to node, Broadcast on mesh)
    public static function drawStatusCheckmark(dc as Graphics.Dc, x as Number, y as Number, status as Number) as Void {
        if (status == 0) {
            // Pending: clock icon
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawCircle(x + 4, y + 4, 3);
            dc.drawLine(x + 4, y + 2, x + 4, y + 4);
            dc.drawLine(x + 4, y + 4, x + 6, y + 4);
        } else if (status == 1) {
            // Sent to node: Single checkmark (muted green)
            dc.setColor(0x88c4a0, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(x, y + 4, x + 3, y + 7);
            dc.drawLine(x + 3, y + 7, x + 8, y + 1);
            dc.setPenWidth(1);
        } else if (status >= 2) {
            // Broadcast on mesh: Double checkmark (bright WhatsApp green)
            dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            // First check
            dc.drawLine(x, y + 4, x + 3, y + 7);
            dc.drawLine(x + 3, y + 7, x + 8, y + 1);
            // Second check (offset by 5px)
            dc.drawLine(x + 5, y + 4, x + 8, y + 7);
            dc.drawLine(x + 8, y + 7, x + 13, y + 1);
            dc.setPenWidth(1);
        }
    }

    //! Render an Action Card (e.g. "+ Neuer Chat")
    private function drawActionCard(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, item as Dictionary, isSelected as Boolean, fontXtiny as Graphics.FontDefinition, fontTiny as Graphics.FontDefinition) as Void {
        var title = item[:title] as String;
        var count = item.hasKey(:contactCount) ? (item[:contactCount] as Number) : 0;
        var subText = I18n.format(Rez.Strings.ActionNewChatSub, [ count ]);

        // 1. Card Fill
        dc.setColor(0x151b24, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 18);

        // 2. Focus Border
        if (isSelected) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, h, 18);
            dc.drawRoundedRectangle(x + 1, y + 1, w - 2, h - 2, 17);
        } else {
            dc.setColor(0x2a3647, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, h, 18);
        }

        // 3. Top Line: Title in WhatsApp Green
        dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 18, y + 18, fontTiny, title, Graphics.TEXT_JUSTIFY_LEFT);

        // Right side: chevron ">"
        dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w - 22, y + (h / 2), fontTiny, ">", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // 4. Bottom Line: Subtitle ("X Kontakte")
        dc.setColor(0x9aa8b8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 18, y + 62, fontXtiny, subText, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
