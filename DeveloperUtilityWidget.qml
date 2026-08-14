import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./components" as Components
import "utils/converter.js" as Converter

PluginComponent {
    id: root

    property var config: Converter.getConfig()
    property var conversionResults: []
    property bool isProcessing: false
    property string statusMessage: ""
    property var processingErrors: []
    property bool jsonValid: false
    property string inputText: ""
    property bool autoCloseOnCopy: pluginData?.autoCloseOnCopy ?? false
    property bool showHistory: false
    property var history: []
    property int flashIndex: -1
    property int expandedCardIndex: -1

    property var enabledFeatures: ({
        enableColor: pluginData?.enableColor ?? true,
        enableJson: pluginData?.enableJson ?? true,
        enableJwt: pluginData?.enableJwt ?? true,
        enableTimestamp: pluginData?.enableTimestamp ?? true,
        enableUrl: pluginData?.enableUrl ?? true,
        enableBase64: pluginData?.enableBase64 ?? true,
        enableNumber: pluginData?.enableNumber ?? true
    })

    signal copyCompletedForClose()

    popoutHeight: parentScreen ? Math.floor(parentScreen.height * 0.8) : 600

    onPluginServiceChanged: {
        if (pluginService) {
            history = pluginService.loadPluginState("developerUtilities", "history", [])
        }
    }

    function addHistory(text) {
        var updated = [text]
        for (var i = 0; i < history.length && updated.length < 10; i++) {
            if (history[i] !== text) {
                updated.push(history[i])
            }
        }
        history = updated
        if (pluginService) {
            pluginService.savePluginState("developerUtilities", "history", history)
        }
    }

    function removeHistory(index) {
        history = history.filter(function(_, i) { return i !== index })
        if (pluginService) {
            pluginService.savePluginState("developerUtilities", "history", history)
        }
    }

    function clearHistory() {
        history = []
        if (pluginService) {
            pluginService.savePluginState("developerUtilities", "history", history)
        }
    }

    function copyResult(index) {
        if (index >= 0 && index < root.conversionResults.length) {
            clipboardHelper.text = root.conversionResults[index].content
            clipboardHelper.selectAll()
            clipboardHelper.copy()
            ToastService.showInfo(I18n.tr("Copied", "DeveloperUtilities") + ": " + root.conversionResults[index].label)
            root.flashIndex = index
            root.addHistory(root.inputText)
            if (root.autoCloseOnCopy) {
                root.copyCompletedForClose()
            }
        }
    }

    function toggleExpand(index) {
        if (root.expandedCardIndex === index) {
            root.expandedCardIndex = -1
        } else {
            root.expandedCardIndex = index
        }
    }

    horizontalBarPill: Component {
        DankIcon {
            name: "code"
            size: Theme.barIconSize(root.barThickness, -4)
            color: Theme.widgetIconColor
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "code"
            size: Theme.barIconSize(root.barThickness)
            color: Theme.widgetIconColor
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            property bool isPinned: false

            readonly property int maxHeight: (root.parentScreen ? Math.floor(root.parentScreen.height * 0.8) : 600) - Theme.spacingS * 2

            headerText: I18n.tr("Developer Utilities", "DeveloperUtilities")
            showCloseButton: true

            headerActions: Row {
                spacing: Theme.spacingXS

                StyledText {
                    text: inputArea.text.length + " " + I18n.tr("chars", "DeveloperUtilities")
                    font.pixelSize: Theme.fontSizeSmall
                    color: inputArea.text.length > 100000 ? Theme.error : Theme.surfaceVariantText
                    visible: inputArea.text.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankActionButton {
                    iconName: "content_paste"
                    iconColor: Theme.surfaceVariantText
                    iconSize: Theme.iconSize - 4
                    onClicked: {
                        inputArea.text = ""
                        root.inputText = ""
                        root.conversionResults = []
                        inputArea.paste()
                    }
                }

                DankActionButton {
                    iconName: "history"
                    iconColor: root.showHistory ? Theme.primary : Theme.surfaceVariantText
                    iconSize: Theme.iconSize - 4
                    onClicked: root.showHistory = !root.showHistory
                }

                DankActionButton {
                    iconName: "delete"
                    iconColor: Theme.surfaceVariantText
                    iconSize: Theme.iconSize - 4
                    enabled: inputArea.text.length > 0
                    onClicked: {
                        inputArea.text = ""
                        root.inputText = ""
                        root.conversionResults = []
                    }
                }

                DankActionButton {
                    iconName: "push_pin"
                    iconColor: popout.isPinned ? Theme.primary : Theme.surfaceVariantText
                    iconSize: Theme.iconSize - 4
                    onClicked: popout.isPinned = !popout.isPinned
                }
            }

            Connections {
                target: popout.parentPopout
                function onShouldBeVisibleChanged() {
                    if (popout.parentPopout.shouldBeVisible) {
                        focusInputTimer.restart()
                    } else {
                        root.expandedCardIndex = -1
                    }
                }
            }

            Timer {
                id: focusInputTimer
                interval: 50
                onTriggered: {
                    inputArea.forceActiveFocus()
                    if (inputArea.text.length > 0) {
                        inputArea.selectAll()
                    }
                }
            }

            onIsPinnedChanged: {
                if (parentPopout && 'backgroundInteractive' in parentPopout) {
                    parentPopout.backgroundInteractive = !isPinned
                }
            }

            Connections {
                target: root
                function onCopyCompletedForClose() {
                    closeDelayTimer.start()
                }
            }

            Timer {
                id: closeDelayTimer
                interval: 150
                onTriggered: {
                    if (closePopout) {
                        closePopout()
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                Column {
                    id: mainColumn
                    width: root.showHistory ? 720 : parent.width
                    leftPadding: Theme.spacingS
                    rightPadding: Theme.spacingS
                    topPadding: Theme.spacingM
                    bottomPadding: Theme.spacingL
                    spacing: Theme.spacingM

                Rectangle {
                    width: parent.width - Theme.spacingS * 2
                    height: 120
                    color: Theme.surfaceContainerHighest
                    radius: Theme.cornerRadius
                    border.width: inputArea.activeFocus ? 2 : 1
                    border.color: inputArea.text.length > 100000 ? Theme.error : (inputArea.activeFocus ? Theme.primary : Theme.surfaceVariant)

                    DankFlickable {
                        id: inputFlickable
                        anchors.fill: parent
                        anchors.margins: 1
                        clip: true
                        contentWidth: width - 11

                        TextArea.flickable: TextArea {
                            id: inputArea
                            wrapMode: TextArea.Wrap
                            selectByMouse: true
                            font.family: "Monospace"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            selectedTextColor: Theme.background
                            selectionColor: Theme.primary
                            leftPadding: Theme.spacingM
                            rightPadding: Theme.spacingM
                            topPadding: Theme.spacingS
                            bottomPadding: Theme.spacingS
                            cursorDelegate: Rectangle {
                                width: 1.5
                                radius: 1
                                color: Theme.surfaceText
                                opacity: 1.0
                                SequentialAnimation on opacity {
                                    running: inputArea.activeFocus
                                    loops: Animation.Infinite
                                    PropertyAnimation { from: 1.0; to: 0.0; duration: 650; easing.type: Easing.InOutQuad }
                                    PropertyAnimation { from: 0.0; to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
                                }
                            }
                            background: Rectangle { color: "transparent" }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
                                    if (inputArea.selectedText.length === 0 && root.conversionResults.length > 0) {
                                        root.copyResult(0)
                                        event.accepted = true
                                    }
                                }
                            }
                            onTextChanged: {
                                root.inputText = text
                                if (text.trim() === "") {
                                    root.conversionResults = []
                                    root.isProcessing = false
                                    root.statusMessage = ""
                                    root.processingErrors = []
                                    root.jsonValid = false
                                } else {
                                    root.isProcessing = true
                                    debounceTimer.restart()
                                }
                            }
                        }

                        StyledText {
                            text: I18n.tr("Paste text to convert...", "DeveloperUtilities")
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                            font.family: inputArea.font.family
                            font.pixelSize: inputArea.font.pixelSize
                            visible: inputArea.text.length === 0
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.leftMargin: inputArea.leftPadding
                            anchors.topMargin: inputArea.topPadding
                            z: inputArea.z + 1
                        }
                    }
                }

                StyledText {
                    width: parent.width - Theme.spacingS * 2
                    visible: root.processingErrors.length > 0 || root.jsonValid
                    text: root.processingErrors.length > 0
                        ? root.processingErrors.map(function(error) { return error.message }).join("\n")
                        : I18n.tr("Valid JSON", "DeveloperUtilities")
                    color: root.processingErrors.length > 0 ? Theme.error : Theme.primary
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                DankFlickable {
                    id: resultsFlickable
                    width: parent.width - Theme.spacingS * 2
                    height: Math.min(resultsColumn.implicitHeight, root.popoutHeight - 200)
                    clip: true
                    contentWidth: width
                    contentHeight: resultsColumn.implicitHeight

                    Column {
                        id: resultsColumn
                        width: resultsFlickable.width
                        spacing: Theme.spacingM

                        Repeater {
                            model: root.conversionResults

                            Loader {
                                id: cardLoader
                                required property var modelData
                                required property int index
                                width: resultsColumn.width
                                visible: root.expandedCardIndex === -1 || root.expandedCardIndex === index
                                sourceComponent: Components.ResultCard {
                                    id: resultCard
                                    resultType: cardLoader.modelData.type
                                    resultLabel: cardLoader.modelData.label
                                    resultContent: cardLoader.modelData.content
                                    needHighlight: cardLoader.modelData.needHighlight || false
                                    maxExpandHeight: root.popoutHeight - 200

                                    Binding {
                                        target: resultCard
                                        property: "isFullyExpanded"
                                        value: root.expandedCardIndex === cardLoader.index
                                    }

                                    onCopyRequested: {
                                        clipboardHelper.text = resultContent
                                        clipboardHelper.selectAll()
                                        clipboardHelper.copy()
                                        ToastService.showInfo(I18n.tr("Copied", "DeveloperUtilities"))
                                        root.addHistory(root.inputText)
                                        copyCompleted()
                                        if (root.autoCloseOnCopy) {
                                            root.copyCompletedForClose()
                                        }
                                    }
                                    onExpandRequested: {
                                        root.toggleExpand(cardLoader.index)
                                    }
                                    Connections {
                                        target: root
                                        function onFlashIndexChanged() {
                                            if (root.flashIndex === cardLoader.index) {
                                                copyCompleted()
                                                root.flashIndex = -1
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            width: resultsColumn.width
                            height: hintColumn.implicitHeight + Theme.spacingL
                            visible: root.conversionResults.length === 0 && !root.isProcessing

                            Column {
                                id: hintColumn
                                anchors.centerIn: parent
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: "transform"
                                    size: 40
                                    color: Theme.surfaceVariant
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: I18n.tr("Supported conversions", "DeveloperUtilities")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Row {
                                    spacing: Theme.spacingM
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    DankIcon { visible: root.enabledFeatures.enableColor; name: "palette"; size: Theme.fontSizeMedium; color: Theme.surfaceVariantText }
                                    DankIcon { visible: root.enabledFeatures.enableJson; name: "data_object"; size: Theme.fontSizeMedium; color: Theme.surfaceVariantText }
                                    DankIcon { visible: root.enabledFeatures.enableJwt; name: "key"; size: Theme.fontSizeMedium; color: Theme.surfaceVariantText }
                                    DankIcon { visible: root.enabledFeatures.enableTimestamp; name: "schedule"; size: Theme.fontSizeMedium; color: Theme.surfaceVariantText }
                                    DankIcon { visible: root.enabledFeatures.enableUrl; name: "link"; size: Theme.fontSizeMedium; color: Theme.surfaceVariantText }
                                    DankIcon { visible: root.enabledFeatures.enableBase64; name: "code"; size: Theme.fontSizeMedium; color: Theme.surfaceVariantText }
                                    DankIcon { visible: root.enabledFeatures.enableNumber; name: "tag"; size: Theme.fontSizeMedium; color: Theme.surfaceVariantText }
                                }
                            }
                        }

                        Item {
                            width: resultsColumn.width
                            height: 80
                            visible: root.isProcessing

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                Repeater {
                                    model: 3

                                    Rectangle {
                                        id: dot
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: Theme.primary
                                        scale: 0.6
                                        opacity: 0.4

                                        property int delay: index * 150

                                        SequentialAnimation on scale {
                                            running: root.isProcessing
                                            loops: Animation.Infinite
                                            PauseAnimation { duration: dot.delay }
                                            NumberAnimation {
                                                from: 0.6
                                                to: 1.0
                                                duration: 200
                                                easing.type: Easing.OutQuad
                                            }
                                            NumberAnimation {
                                                from: 1.0
                                                to: 0.6
                                                duration: 200
                                                easing.type: Easing.InQuad
                                            }
                                            PauseAnimation { duration: 450 - dot.delay }
                                        }
                                        SequentialAnimation on opacity {
                                            running: root.isProcessing
                                            loops: Animation.Infinite
                                            PauseAnimation { duration: dot.delay }
                                            NumberAnimation {
                                                from: 0.4
                                                to: 1.0
                                                duration: 200
                                                easing.type: Easing.OutQuad
                                            }
                                            NumberAnimation {
                                                from: 1.0
                                                to: 0.4
                                                duration: 200
                                                easing.type: Easing.InQuad
                                            }
                                            PauseAnimation { duration: 450 - dot.delay }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                }

                Rectangle {
                    width: parent.width - mainColumn.width - parent.spacing
                    height: mainColumn.height
                    visible: root.showHistory
                    color: Theme.surfaceContainerHigh
                    radius: Theme.cornerRadius

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            width: parent.width

                            StyledText {
                                text: I18n.tr("History", "DeveloperUtilities") + " (" + root.history.length + "/10)"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                            }

                            DankActionButton {
                                id: clearHistoryButton
                                enabled: root.history.length > 0
                                iconName: "delete_sweep"
                                iconColor: Theme.error
                                iconSize: Theme.iconSize - 6
                                onClicked: root.clearHistory()
                            }
                        }

                        StyledText {
                            width: parent.width
                            visible: root.history.length === 0
                            text: I18n.tr("No history", "DeveloperUtilities")
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.surfaceVariantText
                        }

                        DankFlickable {
                            width: parent.width
                            height: parent.height - y
                            visible: root.history.length > 0
                            clip: true
                            contentWidth: width
                            contentHeight: historyColumn.implicitHeight

                            Column {
                                id: historyColumn
                                width: parent.width
                                spacing: Theme.spacingS

                                Repeater {
                                    model: root.history

                                    Rectangle {
                                        required property string modelData
                                        required property int index
                                        width: historyColumn.width
                                        height: 56
                                        radius: Theme.cornerRadius
                                        color: historyMouseArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer

                                        StyledText {
                                            anchors.left: parent.left
                                            anchors.right: deleteHistoryButton.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.margins: Theme.spacingM
                                            text: modelData.replace(/\s+/g, " ")
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                            color: Theme.surfaceText
                                        }

                                        MouseArea {
                                            id: historyMouseArea
                                            anchors.fill: parent
                                            anchors.rightMargin: deleteHistoryButton.width
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: inputArea.text = modelData
                                        }

                                        DankActionButton {
                                            id: deleteHistoryButton
                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.spacingS
                                            anchors.verticalCenter: parent.verticalCenter
                                            iconName: "delete"
                                            iconColor: Theme.error
                                            iconSize: Theme.iconSize - 6
                                            onClicked: root.removeHistory(index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: debounceTimer
        interval: root.config.DEBOUNCE_INTERVAL
        onTriggered: {
            var result = Converter.process(root.inputText, root.enabledFeatures)
            root.conversionResults = result.results
            root.processingErrors = result.error ? [{ message: result.error }] : result.errors
            root.jsonValid = result.jsonValid || false
            root.isProcessing = false
            root.statusMessage = result.results.length > 0 ? result.results.length + " conversions" : ""
        }
    }

    TextEdit {
        id: clipboardHelper
        visible: false
    }

    popoutWidth: root.showHistory ? 1040 : 720
}
