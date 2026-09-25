import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

class ChatThreadView extends WatchUi.View {
    public var targetId as String;
    public var targetName as String;

    private var _scrollOffset as Number = 0;
    private var _maxScroll as Number = 0;

    function initialize(tid as String, tname as String) {
        View.initialize();
        targetId = tid;

        // Ensure channel targets always display the correct channel name (#public etc.)
        if (tid.find("CH_") == 0) {
            var chIdx = tid.substring(3, tid.length()).toNumber();
            var chName = null;
            var channels = ContactManager.getChannels();
            for (var i = 0; i < channels.size(); i++) {
                if (channels[i][:idx] == chIdx) {
                    chName = channels[i][:name] as String;
                    break;
                }
            }
            if (chName != null) {
                targetName = chName;
            } else if (tname != null && tname.length() > 0 && tname.find("#") == 0) {
                targetName = tname;
            } else {
                targetName = "#" + chIdx;
            }
            // Synchronize active channel in ContactManager
            ContactManager.selectChannel(chIdx, targetName);
        } else if (tid.find("CT_") == 0) {
            var cid = tid.substring(3, tid.length());
            var ctName = null;
            var contacts = ContactManager.getContacts();
            for (var j = 0; j < contacts.size(); j++) {
                if (contacts[j][:id] != null && contacts[j][:id].equals(cid)) {
                    ctName = contacts[j][:name] as String;
                    break;
                }
            }
            targetName = (ctName != null) ? ctName : tname;
            // Synchronize active contact in ContactManager
            ContactManager.selectContact(cid, targetName);
        } else {
            targetName = tname;
        }
    }

    function onShow() as Void {
        ChatHistoryManager.markAsRead(targetId);
        _scrollOffset = 0; // Auto-align to newest
        WatchUi.requestUpdate();
    }

    public function scrollUp() as Void {
        _scrollOffset += 40;
        if (_scrollOffset > _maxScroll) {
            _scrollOffset = _maxScroll;
        }
        WatchUi.requestUpdate();
    }

    public function scrollDown() as Void {
        _scrollOffset -= 40;
        if (_scrollOffset < 0) {
            _scrollOffset = 0;
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var cx = w / 2;
        var fontXtiny = Graphics.FONT_SYSTEM_XTINY;
        var fontTiny  = Graphics.FONT_SYSTEM_TINY;
        var fontH = dc.getFontHeight(fontXtiny);

        // 1. Top Header: Chat Title (clean without telemetry clutter)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 38, fontTiny, targetName, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 2. Content Area
        var msgs = ChatHistoryManager.getMessagesForTarget(targetId);
        var viewportTop = 64;
        var viewportBottom = 366;
        var viewportH = viewportBottom - viewportTop;

        if (msgs.size() == 0) {
            dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 195, fontTiny, I18n.get(Rez.Strings.NoMessages), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, 228, fontXtiny, I18n.get(Rez.Strings.PromptPressStartToWrite), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // 2. Compute Bubbles & Render
        var maxBubbleW = 290;
        var bubbleGap = 10;
        var totalContentH = 0;
        var bubbleLayouts = [] as Array<Dictionary>;

        for (var i = 0; i < msgs.size(); i++) {
            var m = msgs[i];
            var txt = m[:text] as String;
            var isOut = m[:isOutgoing] as Boolean;
            var status = (m has :status && m[:status] != null) ? (m[:status] as Number) : 0;
            var sender = isOut ? I18n.get(Rez.Strings.SenderMe) : (m[:sender] as String);
            var timeStr = ChatHistoryManager.formatTimeAgo(m[:time] as Number);

            var lines = wrapMessageText(dc, txt, fontXtiny, maxBubbleW - 24);
            var lineH = fontH + 3;
            var bubbleTextH = lines.size() * lineH;
            // header (fontH + 6) + gap (4) + text + bottom padding (8)
            var bubbleH = fontH + 18 + bubbleTextH;

            // Measure max line width of text
            var longestLine = 0;
            for (var l = 0; l < lines.size(); l++) {
                var lw = dc.getTextWidthInPixels(lines[l], fontXtiny);
                if (lw > longestLine) { longestLine = lw; }
            }

            // Ensure bubble accommodates sender + gap + timestamp + checkmarks
            var senderW = dc.getTextWidthInPixels(sender, fontXtiny);
            var timeW = dc.getTextWidthInPixels(timeStr, fontXtiny);
            var checkW = isOut ? ((status == 2) ? 14 : 9) : 0;
            var headerContentW = senderW + timeW + checkW + 24; // space between name, time and check
            if (headerContentW > longestLine) {
                longestLine = headerContentW;
            }

            var computedBubbleW = longestLine + 24;
            if (computedBubbleW < 130) { computedBubbleW = 130; }
            if (computedBubbleW > maxBubbleW) { computedBubbleW = maxBubbleW; }

            bubbleLayouts.add({
                :msg => m,
                :lines => lines,
                :w => computedBubbleW,
                :h => bubbleH,
                :isOut => isOut,
                :status => status,
                :sender => sender,
                :timeStr => timeStr
            });

            totalContentH += bubbleH + bubbleGap;
        }

        // Calculate max scroll
        if (totalContentH > viewportH) {
            _maxScroll = totalContentH - viewportH;
        } else {
            _maxScroll = 0;
            _scrollOffset = 0;
        }

        // Draw Bubbles
        // Always bottom-align content towards viewportBottom (just above the button)
        var startY = viewportBottom - totalContentH + _scrollOffset;

        var curY = startY;
        for (var b = 0; b < bubbleLayouts.size(); b++) {
            var bl = bubbleLayouts[b];
            var bh = bl[:h] as Number;
            var bw = bl[:w] as Number;
            var isOut = bl[:isOut] as Boolean;
            var status = bl[:status] as Number;
            var lines = bl[:lines] as Array<String>;
            var sender = bl[:sender] as String;
            var timeStr = bl[:timeStr] as String;

            // Only draw if within visible viewport
            if ((curY + bh) >= viewportTop && curY <= viewportBottom) {
                var bx = isOut ? (w - 32 - bw) : 32;

                // Safety space check: truncate sender if name + time + check is too wide
                var availHeaderW = bw - 20;
                var timeW = dc.getTextWidthInPixels(timeStr, fontXtiny);
                var checkW = isOut ? ((status == 2) ? 14 : 9) : 0;
                var maxSenderW = availHeaderW - timeW - checkW - 10;
                var displaySender = sender;
                if (dc.getTextWidthInPixels(displaySender, fontXtiny) > maxSenderW) {
                    while (displaySender.length() > 2 && dc.getTextWidthInPixels(displaySender + "..", fontXtiny) > maxSenderW) {
                        displaySender = displaySender.substring(0, displaySender.length() - 1);
                    }
                    displaySender = displaySender + "..";
                }

                // Bubble Card Fill & Border
                if (isOut) {
                    dc.setColor(0x0e4727, Graphics.COLOR_TRANSPARENT); // WhatsApp Dark Green
                    dc.fillRoundedRectangle(bx, curY, bw, bh, 10);
                    dc.setColor(0x18703e, Graphics.COLOR_TRANSPARENT);
                    dc.drawRoundedRectangle(bx, curY, bw, bh, 10);

                    // Header: "Ich"
                    dc.setColor(0x25d366, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(bx + 10, curY + 6, fontXtiny, displaySender, Graphics.TEXT_JUSTIFY_LEFT);

                    // Right side: Checkmarks + Time
                    var cW = (status == 2) ? 14 : 9;
                    var checkX = bx + bw - 10 - cW;
                    var checkY = curY + 10;
                    ChatsListView.drawStatusCheckmark(dc, checkX, checkY, status);

                    dc.setColor(0x88c4a0, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(checkX - 5, curY + 6, fontXtiny, timeStr, Graphics.TEXT_JUSTIFY_RIGHT);
                } else {
                    dc.setColor(0x1a232f, Graphics.COLOR_TRANSPARENT); // Dark Grey Card
                    dc.fillRoundedRectangle(bx, curY, bw, bh, 10);
                    dc.setColor(0x2f3e52, Graphics.COLOR_TRANSPARENT);
                    dc.drawRoundedRectangle(bx, curY, bw, bh, 10);

                    // Header: Sender name in Cyan/Orange + time
                    dc.setColor(0xff9500, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(bx + 10, curY + 6, fontXtiny, displaySender, Graphics.TEXT_JUSTIFY_LEFT);
                    dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(bx + bw - 10, curY + 6, fontXtiny, timeStr, Graphics.TEXT_JUSTIFY_RIGHT);
                }

                // Message Text Lines (spaced clearly below sender header)
                var textStartY = curY + fontH + 10;
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                for (var l = 0; l < lines.size(); l++) {
                    var lineStr = lines[l];
                    if (lineStr.length() > 0) {
                        dc.drawText(bx + 10, textStartY + (l * (fontH + 3)), fontXtiny, lineStr, Graphics.TEXT_JUSTIFY_LEFT);
                    }
                }
            }

            curY += bh + bubbleGap;
        }

        // Scroll Indicators (positioned outside viewport so they never overlap bubbles)
        if (_scrollOffset < _maxScroll) {
            dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - 7, 58], [cx + 7, 58], [cx, 51]]);
        }
        if (_scrollOffset > 0) {
            dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - 7, 368], [cx + 7, 368], [cx, 375]]);
        }

        // 3. Bottom Quick Action Button: Green WhatsApp Pill [ Nachricht / Message ]
        var btnW = 230;
        var btnH = 46;
        var btnX = cx - (btnW / 2);
        var btnY = 378;

        dc.setColor(0x124726, Graphics.COLOR_TRANSPARENT); // WhatsApp Forest Green Fill
        dc.fillRoundedRectangle(btnX, btnY, btnW, btnH, 23);
        dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT); // Bright WhatsApp Green Border
        dc.drawRoundedRectangle(btnX, btnY, btnW, btnH, 23);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, btnY + (btnH / 2) - 2, fontTiny, I18n.get(Rez.Strings.MessageLabel), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function wrapMessageText(dc as Graphics.Dc, text as String, font as Graphics.FontDefinition, maxWidth as Number) as Array<String> {
        var lines = [] as Array<String>;
        if (text == null || text.length() == 0) {
            return lines;
        }

        var maxLines = 25; // Safety cap against runaway packets or memory spikes

        // 1. Split text into paragraphs on newline (\n), stripping carriage returns (\r)
        var paragraphs = [] as Array<String>;
        var curPara = "";
        for (var i = 0; i < text.length(); i++) {
            var ch = text.substring(i, i + 1);
            if (ch.equals("\r")) {
                continue;
            }
            if (ch.equals("\n")) {
                paragraphs.add(curPara);
                curPara = "";
            } else {
                curPara += ch;
            }
        }
        if (curPara.length() > 0 || paragraphs.size() == 0) {
            paragraphs.add(curPara);
        }

        // 2. Wrap each paragraph independently, preserving deliberate empty lines
        for (var pIdx = 0; pIdx < paragraphs.size(); pIdx++) {
            if (lines.size() >= maxLines) {
                break;
            }

            var para = paragraphs[pIdx];
            if (para.length() == 0) {
                lines.add("");
                continue;
            }

            // Split paragraph into words
            var words = [] as Array<String>;
            var curWord = "";
            for (var w = 0; w < para.length(); w++) {
                var c = para.substring(w, w + 1);
                if (c.equals(" ")) {
                    if (curWord.length() > 0) {
                        words.add(curWord);
                        curWord = "";
                    }
                } else {
                    curWord += c;
                }
            }
            if (curWord.length() > 0) {
                words.add(curWord);
            }

            if (words.size() == 0) {
                lines.add("");
                continue;
            }

            var currentLine = "";
            for (var wIdx = 0; wIdx < words.size(); wIdx++) {
                var word = words[wIdx];
                var testLine = (currentLine.length() == 0) ? word : (currentLine + " " + word);
                if (dc.getTextWidthInPixels(testLine, font) <= maxWidth) {
                    currentLine = testLine;
                } else {
                    if (currentLine.length() > 0) {
                        lines.add(currentLine);
                        if (lines.size() >= maxLines) {
                            break;
                        }
                    }
                    currentLine = word;
                }
            }
            if (currentLine.length() > 0 && lines.size() < maxLines) {
                lines.add(currentLine);
            }
        }

        return lines;
    }
}
