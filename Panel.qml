import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Native clock popout, restyled only with Omarchy's own palette and metrics.
Panel {
    id: root
    moduleName: "omarchy.clock"
    ipcTarget: "omarchy.clock"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    readonly property var barIdentity: hostWidget || root
    property date today: new Date()
    property string activeMode: String(setting("calendarMode", "bs")).toLowerCase() === "ad" ? "ad" : "bs"
    readonly property bool bsMode: activeMode === "bs"
    // BS is written in Nepali throughout this view. AD deliberately retains
    // Arabic numerals, as it is the Gregorian/English alternative.
    readonly property bool nepaliDigits: bsMode
    readonly property var todayBs: Model.bsDateFor(today)
    readonly property string todayKey: bsMode && todayBs ? Model.bsKey(todayBs.year, todayBs.month, todayBs.day) : Model.keyForDate(today)
    readonly property color contentForeground: bar ? bar.foreground : Color.foreground
    readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property int weekStart: bsMode ? 0 : Model.normalizedWeekStart(setting("weekStartDay", null), Qt.locale().firstDayOfWeek)
    readonly property var weekdays: bsMode ? [0,1,2,3,4,5,6] : Model.weekdayOrder(weekStart)
    readonly property var adLocale: Qt.locale("en_US")
    readonly property var bsWeekdayNames: ["आइतबार", "सोमबार", "मंगलबार", "बुधबार", "बिहीबार", "शुक्रबार", "शनिबार"]

    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    readonly property bool viewingCurrentMonth: bsMode && todayBs ? viewYear === todayBs.year && viewMonth === todayBs.month : viewYear === today.getFullYear() && viewMonth === today.getMonth()
    readonly property var weeks: bsMode ? Model.bsMonthGrid(viewYear, viewMonth, todayKey) : Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)

    readonly property int cellWidth: Style.space(56)
    readonly property int cellHeight: Style.space(34)
    readonly property int cellSpacing: Style.space(2)
    readonly property int gridWidth: 7 * cellWidth + 6 * cellSpacing

    function persistSettings(values) {
        var entry = { id: root.moduleName }
        for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
        for (var key in values) entry[key] = values[key]
        root.settings = entry
        if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
        if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") root.bar.shell.updateEntryInline(root.moduleName, entry)
    }

    function setMode(mode) {
        var next = mode === "ad" ? "ad" : "bs"
        if (next === root.activeMode) return
        root.activeMode = next
        root.persistSettings({ calendarMode: next })
        root.goToToday()
        gridColumn.opacity = 0.35
    }

    function goToToday() {
        if (root.bsMode && root.todayBs) {
            root.viewYear = root.todayBs.year
            root.viewMonth = root.todayBs.month
        } else {
            root.viewYear = root.today.getFullYear()
            root.viewMonth = root.today.getMonth()
        }
    }

    function moveMonth(delta) {
        if (root.bsMode) {
            var nextBs = Model.stepBsMonth(viewYear, viewMonth, delta)
            if (nextBs) {
                viewYear = nextBs.year
                viewMonth = nextBs.month
            }
        } else {
            var nextAd = Model.stepMonth(viewYear, viewMonth, delta)
            viewYear = nextAd.year
            viewMonth = nextAd.month
        }
    }

    function weekdayLabel(day) {
        return root.bsMode ? root.bsWeekdayNames[day] : String(root.adLocale.dayName(day, Locale.ShortFormat)).toUpperCase()
    }

    function dayText(day) {
        return root.nepaliDigits && root.bsMode ? Model.toDevanagari(day) : String(day)
    }

    function todayText() {
        if (root.bsMode && root.todayBs) {
            return root.dayText(root.todayBs.day) + " " + Model.NEPALI_MONTHS_NP[root.todayBs.month] + " " + (root.nepaliDigits ? Model.toDevanagari(root.todayBs.year) : root.todayBs.year)
        }
        return Qt.formatDate(root.today, "MMMM d, yyyy")
    }

    function monthText() {
        if (root.bsMode) {
            return Model.NEPALI_MONTHS_NP[viewMonth] + " " + (root.nepaliDigits ? Model.toDevanagari(viewYear) : viewYear)
        }
        return Qt.formatDate(new Date(viewYear, viewMonth, 1), "MMMM yyyy").toUpperCase()
    }

    function open() {
        refresh()
        root.controller.show()
        Qt.callLater(function() {
            if (root.opened) setCenterHoverRevealSuppressed(true)
        })
    }

    function close() {
        setCenterHoverRevealSuppressed(false)
        root.controller.hide()
    }

    function toggle() {
        if (opened) close()
        else open()
    }

    function refresh() {
        today = new Date()
        goToToday()
    }

    function switchPanel(direction) {
        return bar && typeof bar.switchPanelFrom === "function" ? bar.switchPanelFrom(barIdentity, direction) : false
    }

    function setCenterHoverRevealSuppressed(value) {
        if (bar && "centerHoverRevealSuppressed" in bar) bar.centerHoverRevealSuppressed = value
    }

    Component.onCompleted: goToToday()

    SystemClock {
        precision: SystemClock.Minutes
        onDateChanged: {
            var followed = root.viewingCurrentMonth
            root.today = date
            if (followed) root.goToToday()
        }
    }

    KeyboardPanel {
        id: popup
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        centerOnBar: true
        focusTarget: keyCatcher
        contentWidth: popup.fittedContentWidth(Style.space(560))
        contentHeight: popup.fittedContentHeight(calendarColumn.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onMoveRequested: function(dx, dy) {
                if (dx !== 0) root.moveMonth(dx)
                if (dy !== 0) root.moveMonth(dy * 12)
            }
            onActivateRequested: root.goToToday()
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }
            onTextKey: function(t) {
                if (t === "[") root.moveMonth(-1)
                else if (t === "]") root.moveMonth(1)
                else if (t === "t" || t === "T") root.goToToday()
                else if (t === "b" || t === "B") root.setMode("bs")
                else if (t === "a" || t === "A") root.setMode("ad")
            }

            Flickable {
                anchors.fill: parent
                contentWidth: calendarColumn.width
                contentHeight: calendarColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: calendarColumn
                    // Keep content independent of Flickable's contentWidth; binding it
                    // back to the viewport creates a width loop during popup mapping.
                    width: Style.space(560)
                    spacing: Style.space(10)

                    Item {
                        width: parent.width
                        height: Style.space(72)

                        Column {
                            anchors.centerIn: parent
                            spacing: Style.space(4)

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.todayText()
                                color: root.contentForeground
                                font.family: root.contentFontFamily
                                font.pixelSize: 34
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.bsMode ? "विक्रम संवत" : "GREGORIAN"
                                color: Qt.darker(root.contentForeground, 1.55)
                                font.family: root.contentFontFamily
                                font.pixelSize: Style.font.caption
                                font.letterSpacing: 1
                            }
                        }
                    }

                    Rectangle {
                        id: modeControl
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Style.space(132)
                        height: Style.space(28)
                        radius: Style.cornerRadius > 0 ? height / 2 : 0
                        color: Style.hoverFillFor(root.contentForeground, Color.accent)
                        border.width: Style.spacing.hairline
                        border.color: Style.normalBorderFor(root.contentForeground, Color.accent)

                        Rectangle {
                            width: parent.width / 2
                            height: parent.height - Style.spacing.hairline * 2
                            y: Style.spacing.hairline
                            x: root.bsMode ? Style.spacing.hairline : parent.width / 2 - Style.spacing.hairline
                            radius: parent.radius
                            color: Style.selectedStateColor(root.contentForeground, Color.accent)
                            Behavior on x {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Row {
                            anchors.fill: parent

                            Repeater {
                                model: ["BS", "AD"]

                                Item {
                                    required property string modelData
                                    width: modeControl.width / 2
                                    height: modeControl.height

                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        color: (parent.modelData === "BS") === root.bsMode
                                               ? Style.contrastingTextColor(Style.selectedStateColor(root.contentForeground, Color.accent))
                                               : Qt.darker(root.contentForeground, 1.6)
                                        font.family: root.contentFontFamily
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.setMode(parent.modelData.toLowerCase())
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: gridColumn.height

                        WheelHandler {
                            onWheel: function(event) {
                                if (event.angleDelta.y !== 0) {
                                    root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
                                }
                            }
                        }

                        Column {
                            id: gridColumn
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Style.space(3)
                            opacity: 1
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }
                            onOpacityChanged: if (opacity < 1) Qt.callLater(function() { opacity = 1 })

                            Row {
                                spacing: root.cellSpacing

                                Repeater {
                                    model: root.weekdays

                                    Text {
                                        required property var modelData
                                        width: root.cellWidth
                                        height: Style.space(16)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: root.weekdayLabel(modelData)
                                        color: Qt.darker(root.contentForeground, 1.5)
                                        font.family: root.contentFontFamily
                                        font.pixelSize: root.bsMode ? Style.font.caption * 0.82 : Style.font.caption
                                        font.bold: true
                                        font.letterSpacing: root.bsMode ? 0 : 1
                                    }
                                }
                            }

                            Repeater {
                                model: root.weeks

                                Row {
                                    required property var modelData
                                    spacing: root.cellSpacing

                                    Repeater {
                                        model: modelData.days

                                        Rectangle {
                                            required property var modelData
                                            width: root.cellWidth
                                            height: root.cellHeight
                                            radius: Style.cornerRadius
                                            color: "transparent"
                                            border.width: modelData.today ? Style.spacing.hairline : 0
                                            border.color: Style.normalBorderFor(root.contentForeground, Color.accent)

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.dayText(modelData.day)
                                                color: modelData.inMonth
                                                       ? (modelData.weekend ? Qt.darker(root.contentForeground, 1.45) : root.contentForeground)
                                                       : Qt.darker(root.contentForeground, 2.2)
                                                font.family: root.contentFontFamily
                                                font.pixelSize: Style.font.body
                                                font.bold: modelData.today
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: monthNav.height

                        Item {
                            id: monthNav
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.gridWidth
                            height: monthLabel.implicitHeight + Style.space(10)

                            Text {
                                id: monthLabel
                                anchors.centerIn: parent
                                width: Style.space(190)
                                horizontalAlignment: Text.AlignHCenter
                                text: root.monthText()
                                color: Qt.darker(root.contentForeground, 1.4)
                                font.family: root.contentFontFamily
                                font.pixelSize: Style.font.body
                                font.letterSpacing: 1
                            }

                            PanelActionButton {
                                anchors.left: parent.left
                                anchors.leftMargin: -Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                iconText: "󰅁"
                                tooltipText: "Previous month"
                                foreground: root.contentForeground
                                fontFamily: root.contentFontFamily
                                onClicked: root.moveMonth(-1)
                            }

                            PanelActionButton {
                                anchors.right: parent.right
                                anchors.rightMargin: -Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                iconText: "󰅂"
                                tooltipText: "Next month"
                                foreground: root.contentForeground
                                fontFamily: root.contentFontFamily
                                onClicked: root.moveMonth(1)
                            }
                        }
                    }
                }
            }
        }
    }
}
