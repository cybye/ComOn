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
        targetName = tname;
    }

    function onShow() as Void {
        ChatHistoryManager.markAsRead(targetId);
        _scrollOffset = 0; // Auto-align to newest
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
        var h = dc.getHeight();
        var cx = w / 2;
        var fontXtiny = Graphics.FONT_SYSTEM_XTINY;
        var fontTiny  = Graphics.FONT_SYSTEM_TINY;
        var fontH = dc.getFontHeight(fontXtiny);

        // 1. Top Header
        dc.setColor(0x00d4ff, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 16, fontTiny, targetName, Graphics.TEXT_JUSTIFY_CENTER);

        var msgs = ChatHistoryManager.getMessagesForTarget(targetId);
        var subHeader = (msgs.size() == 1) ? "1 Nachricht" : (msgs.size().toString() + " Nachrichten");
        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 40, fontXtiny, subHeader, Graphics.TEXT_JUSTIFY_CENTER);

        // Header Divider
        dc.setColor(0x222a3a, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(40, 58, w - 40, 58);

        // 2. Compute Bubbles & Render
        var viewportTop = 62;
        var viewportBottom = 372;
        var viewportH = viewportBottom - viewportTop;

        // First calculate total content height
        var maxBubbleW = 280;
        var bubbleGap = 10;
        var totalContentH = 0;
        var bubbleLayouts = [] as Array<Dictionary>;

        for (var i = 0; i < msgs.size(); i++) {
            var m = msgs[i];
            var txt = m[:text] as String;
            var isOut = m[:isOutgoing] as Boolean;
            var sender = m[:sender] as String;
            var timeStr = ChatHistoryManager.formatTimeAgo(m[:time] as Number);

            var lines = wrapMessageText(dc, txt, fontXtiny, maxBubbleW - 20);
            var bubbleTextH = lines.size() * (fontH + 2);
            var bubbleH = 16 + bubbleTextH + 8; // header + text + padding

            // Measure max line width for compact bubble
            var longestLine = 0;
            for (var l = 0; l < lines.size(); l++) {
                var lw = dc.getTextWidthInPixels(lines[l], fontXtiny);
                if (lw > longestLine) { longestLine = lw; }
            }
            var computedBubbleW = longestLine + 24;
            if (computedBubbleW < 120) { computedBubbleW = 120; }
            if (computedBubbleW > maxBubbleW) { computedBubbleW = maxBubbleW; }

            bubbleLayouts.add({
                :msg => m,
                :lines => lines,
                :w => computedBubbleW,
                :h => bubbleH,
                :isOut => isOut,
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
        // When scrollOffset = 0, we align the bottom of content to viewportBottom
        var startY = (totalContentH > viewportH) ? 
            (viewportBottom - totalContentH + _scrollOffset) : 
            viewportTop;

        var curY = startY;
        for (var b = 0; b < bubbleLayouts.size(); b++) {
            var bl = bubbleLayouts[b];
            var bh = bl[:h] as Number;
            var bw = bl[:w] as Number;
            var isOut = bl[:isOut] as Boolean;
            var lines = bl[:lines] as Array<String>;
            var sender = bl[:sender] as String;
            var timeStr = bl[:timeStr] as String;

            // Only draw if within visible viewport
            if ((curY + bh) >= viewportTop && curY <= viewportBottom) {
                var bx = isOut ? (w - 36 - bw) : 36;

                // Bubble Card Fill & Border
                if (isOut) {
                    dc.setColor(0x0d2838, Graphics.COLOR_TRANSPARENT); // Deep Teal
                    dc.fillRoundedRectangle(bx, curY, bw, bh, 8);
                    dc.setColor(0x185675, Graphics.COLOR_TRANSPARENT);
                    dc.drawRoundedRectangle(bx, curY, bw, bh, 8);

                    // Header: "Ich" + time
                    dc.setColor(0x00d4ff, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(bx + 10, curY + 4, fontXtiny, "Ich", Graphics.TEXT_JUSTIFY_LEFT);
                    dc.setColor(0x6688aa, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(bx + bw - 10, curY + 4, fontXtiny, timeStr, Graphics.TEXT_JUSTIFY_RIGHT);
                } else {
                    dc.setColor(0x151b26, Graphics.COLOR_TRANSPARENT); // Dark Navy
                    dc.fillRoundedRectangle(bx, curY, bw, bh, 8);
                    dc.setColor(0x283547, Graphics.COLOR_TRANSPARENT);
                    dc.drawRoundedRectangle(bx, curY, bw, bh, 8);

                    // Header: Sender name in Orange + time
                    dc.setColor(0xff9500, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(bx + 10, curY + 4, fontXtiny, sender, Graphics.TEXT_JUSTIFY_LEFT);
                    dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(bx + bw - 10, curY + 4, fontXtiny, timeStr, Graphics.TEXT_JUSTIFY_RIGHT);
                }

                // Message Text Lines
                var textStartY = curY + 18;
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                for (var l = 0; l < lines.size(); l++) {
                    dc.drawText(bx + 10, textStartY + (l * (fontH + 2)), fontXtiny, lines[l], Graphics.TEXT_JUSTIFY_LEFT);
                }
            }

            curY += bh + bubbleGap;
        }

        // Scroll Indicators
        if (_scrollOffset < _maxScroll) {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 54, fontXtiny, "▲", Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (_scrollOffset > 0) {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 362, fontXtiny, "▼", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // 3. Bottom Quick Action Button: [ 💬 Antworten ]
        var btnW = 210;
        var btnH = 44;
        var btnX = cx - (btnW / 2);
        var btnY = 380;

        dc.setColor(0x155724, Graphics.COLOR_TRANSPARENT); // Forest Green
        dc.fillRoundedRectangle(btnX, btnY, btnW, btnH, 10);
        dc.setColor(0x00e676, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(btnX, btnY, btnW, btnH, 10);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, btnY + 11, fontXtiny, "💬 Antworten", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function wrapMessageText(dc as Graphics.Dc, text as String, font as Graphics.FontDefinition, maxWidth as Number) as Array<String> {
        var lines = [] as Array<String>;
        if (text == null || text.length() == 0) {
            return lines;
        }

        var words = [] as Array<String>;
        var cur = "";
        for (var i = 0; i < text.length(); i++) {
            var ch = text.substring(i, i + 1);
            if (ch.equals(" ") || ch.equals("\n")) {
                if (cur.length() > 0) {
                    words.add(cur);
                    cur = "";
                }
            } else {
                cur += ch;
            }
        }
        if (cur.length() > 0) {
            words.add(cur);
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
                }
                currentLine = word;
            }
        }
        if (currentLine.length() > 0) {
            lines.add(currentLine);
        }
        return lines;
    }
}
