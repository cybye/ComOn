import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

class ChatThreadView extends WatchUi.View {
    public var targetId as String;
    public var targetName as String;

    private var _scrollOffset as Number = 0;
    private var _maxScroll as Number = 0;

    private var _fontBody as FontRef = Graphics.FONT_SYSTEM_TINY;
    private var _fontCaption as FontRef = Graphics.FONT_SYSTEM_XTINY;

    function initialize(id as String, name as String) {
        View.initialize();
        targetId = id;
        targetName = name;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        DisplayProfile.init(dc);
        _fontBody = Graphics.FONT_SYSTEM_TINY;
        _fontCaption = Graphics.FONT_SYSTEM_XTINY;
    }

    function onShow() as Void {
        ChatHistoryManager.markAsRead(targetId);
        WatchUi.requestUpdate();
    }

    public function scrollUp() as Void {
        _scrollOffset += DisplayProfile.scale(40);
        if (_scrollOffset > _maxScroll) {
            _scrollOffset = _maxScroll;
        }
        WatchUi.requestUpdate();
    }

    public function scrollDown() as Void {
        _scrollOffset -= DisplayProfile.scale(40);
        if (_scrollOffset < 0) {
            _scrollOffset = 0;
        }
        WatchUi.requestUpdate();
    }

    public function getHeaderTapLimit() as Number {
        return DisplayProfile.scale(60);
    }

    public function isPillTapped(tx as Number, ty as Number) as Boolean {
        var w = DisplayProfile.screenW;
        var h = DisplayProfile.screenH;
        var cx = w / 2;
        var btnW = DisplayProfile.scale(230);
        var btnH = DisplayProfile.scale(46);
        var btnX = cx - (btnW / 2);
        var btnY = h - DisplayProfile.scale(76);
        var margin = DisplayProfile.scale(10);

        return (ty >= (btnY - margin) && ty <= (btnY + btnH + margin) && tx >= (btnX - margin) && tx <= (btnX + btnW + margin));
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        DisplayProfile.init(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var fontH = dc.getFontHeight(_fontCaption);

        // 1. Top Header: Chat Title
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, DisplayProfile.scale(38), _fontBody, targetName, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 2. Content Area
        var msgs = ChatHistoryManager.getMessagesForTarget(targetId);
        var viewportTop = DisplayProfile.scale(64);
        var viewportBottom = h - DisplayProfile.scale(88);
        var viewportH = viewportBottom - viewportTop;

        if (msgs.size() == 0) {
            dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, viewportTop + (viewportH / 2) - DisplayProfile.scale(16), _fontBody, I18n.get(Rez.Strings.NoMessages), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, viewportTop + (viewportH / 2) + DisplayProfile.scale(16), _fontCaption, I18n.get(Rez.Strings.PromptPressStartToWrite), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // 3. Compute Bubbles & Render
        var maxBubbleW = (w * 0.75).toNumber();
        var bubbleGap = DisplayProfile.scale(10);
        var totalContentH = 0;
        var bubbleLayouts = [] as Array<Dictionary>;

        for (var i = 0; i < msgs.size(); i++) {
            var m = msgs[i];
            var txt = m[:text] as String;
            var isOut = m[:isOutgoing] as Boolean;
            var status = (m has :status && m[:status] != null) ? (m[:status] as Number) : 0;
            var sender = isOut ? I18n.get(Rez.Strings.SenderMe) : (m[:sender] as String);
            var timeStr = ChatHistoryManager.formatTimeAgo(m[:time] as Number);

            var lines = wrapMessageText(dc, txt, _fontCaption, maxBubbleW - DisplayProfile.scale(24));
            var lineH = fontH + DisplayProfile.scale(3);
            var bubbleTextH = lines.size() * lineH;
            var bubbleH = fontH + DisplayProfile.scale(18) + bubbleTextH;

            var longestLine = 0;
            for (var l = 0; l < lines.size(); l++) {
                var lw = dc.getTextWidthInPixels(lines[l], _fontCaption);
                if (lw > longestLine) { longestLine = lw; }
            }

            var senderW = dc.getTextWidthInPixels(sender, _fontCaption);
            var timeW = dc.getTextWidthInPixels(timeStr, _fontCaption);
            var checkW = isOut ? ((status == 2) ? DisplayProfile.scale(14) : DisplayProfile.scale(9)) : 0;
            var headerContentW = senderW + timeW + checkW + DisplayProfile.scale(24);
            if (headerContentW > longestLine) {
                longestLine = headerContentW;
            }

            var minBubbleW = DisplayProfile.scale(130);
            var computedBubbleW = longestLine + DisplayProfile.scale(24);
            if (computedBubbleW < minBubbleW) { computedBubbleW = minBubbleW; }
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
        var startY = viewportBottom - totalContentH + _scrollOffset;
        var curY = startY;
        var sideInset = DisplayProfile.scale(32);
        var rBubble = DisplayTheme.bubbleRadius();

        for (var b = 0; b < bubbleLayouts.size(); b++) {
            var bl = bubbleLayouts[b];
            var bh = bl[:h] as Number;
            var bw = bl[:w] as Number;
            var isOut = bl[:isOut] as Boolean;
            var status = bl[:status] as Number;
            var lines = bl[:lines] as Array<String>;
            var sender = bl[:sender] as String;
            var timeStr = bl[:timeStr] as String;

            if ((curY + bh) >= viewportTop && curY <= viewportBottom) {
                var bx = isOut ? (w - sideInset - bw) : sideInset;

                var availHeaderW = bw - DisplayProfile.scale(20);
                var timeW = dc.getTextWidthInPixels(timeStr, _fontCaption);
                var checkW = isOut ? ((status == 2) ? DisplayProfile.scale(14) : DisplayProfile.scale(9)) : 0;
                var maxSenderW = availHeaderW - timeW - checkW - DisplayProfile.scale(10);
                var displaySender = ChatsListView.truncateText(dc, sender, _fontCaption, maxSenderW);

                // Bubble Card Fill & Border
                if (isOut) {
                    dc.setColor(DisplayTheme.outBubble(), Graphics.COLOR_TRANSPARENT);
                    dc.fillRoundedRectangle(bx, curY, bw, bh, rBubble);
                    dc.setColor(DisplayTheme.outBubbleBorder(), Graphics.COLOR_TRANSPARENT);
                    dc.drawRoundedRectangle(bx, curY, bw, bh, rBubble);

                    // Header: "Ich"
                    dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
                    dc.drawText(bx + DisplayProfile.scale(10), curY + DisplayProfile.scale(6), _fontCaption, displaySender, Graphics.TEXT_JUSTIFY_LEFT);

                    // Right side: Checkmarks + Time
                    var cW = (status == 2) ? DisplayProfile.scale(14) : DisplayProfile.scale(9);
                    var checkX = bx + bw - DisplayProfile.scale(10) - cW;
                    var checkY = curY + DisplayProfile.scale(10);
                    ChatsListView.drawStatusCheckmark(dc, checkX, checkY, status);

                    dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
                    dc.drawText(checkX - DisplayProfile.scale(5), curY + DisplayProfile.scale(6), _fontCaption, timeStr, Graphics.TEXT_JUSTIFY_RIGHT);
                } else {
                    dc.setColor(DisplayTheme.inBubble(), Graphics.COLOR_TRANSPARENT);
                    dc.fillRoundedRectangle(bx, curY, bw, bh, rBubble);
                    dc.setColor(DisplayTheme.inBubbleBorder(), Graphics.COLOR_TRANSPARENT);
                    dc.drawRoundedRectangle(bx, curY, bw, bh, rBubble);

                    // Header: Sender name
                    dc.setColor(0xff9500, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(bx + DisplayProfile.scale(10), curY + DisplayProfile.scale(6), _fontCaption, displaySender, Graphics.TEXT_JUSTIFY_LEFT);
                    dc.setColor(DisplayTheme.muted(), Graphics.COLOR_TRANSPARENT);
                    dc.drawText(bx + bw - DisplayProfile.scale(10), curY + DisplayProfile.scale(6), _fontCaption, timeStr, Graphics.TEXT_JUSTIFY_RIGHT);
                }

                // Message Text Lines
                var textStartY = curY + fontH + DisplayProfile.scale(10);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                var stepLineH = fontH + DisplayProfile.scale(3);
                for (var l = 0; l < lines.size(); l++) {
                    var lineStr = lines[l];
                    if (lineStr.length() > 0) {
                        dc.drawText(bx + DisplayProfile.scale(10), textStartY + (l * stepLineH), _fontCaption, lineStr, Graphics.TEXT_JUSTIFY_LEFT);
                    }
                }
            }

            curY += bh + bubbleGap;
        }

        // Scroll Indicators
        var arrowHalfW = DisplayProfile.scale(7);
        if (_scrollOffset < _maxScroll) {
            dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - arrowHalfW, viewportTop - DisplayProfile.scale(6)], [cx + arrowHalfW, viewportTop - DisplayProfile.scale(6)], [cx, viewportTop - DisplayProfile.scale(13)]]);
        }
        if (_scrollOffset > 0) {
            dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - arrowHalfW, viewportBottom + DisplayProfile.scale(2)], [cx + arrowHalfW, viewportBottom + DisplayProfile.scale(2)], [cx, viewportBottom + DisplayProfile.scale(9)]]);
        }

        // 4. Bottom Quick Action Button: Green WhatsApp Pill [ Nachricht / Message ]
        var btnW = DisplayProfile.scale(230);
        var btnH = DisplayProfile.scale(46);
        var btnX = cx - (btnW / 2);
        var btnY = h - DisplayProfile.scale(76);
        var rBtn = btnH / 2;

        dc.setColor(DisplayTheme.accentDark(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(btnX, btnY, btnW, btnH, rBtn);
        dc.setColor(DisplayTheme.accent(), Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(btnX, btnY, btnW, btnH, rBtn);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, btnY + (btnH / 2) - 2, _fontBody, I18n.get(Rez.Strings.MessageLabel), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function wrapMessageText(dc as Graphics.Dc, text as String, font as FontRef, maxWidth as Number) as Array<String> {
        var lines = [] as Array<String>;
        if (text == null || text.length() == 0) {
            return lines;
        }

        var maxLines = 25;

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

        // 2. Wrap each paragraph independently
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
