import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    property var popoutService: null
    property var sessions: []
    property var activeSession: null
    property string activeLabel: "AI"
    property string selectedProvider: "codex"
    property bool settingsMode: false
    property string pendingResetCreditId: ""
    readonly property string pluginPath: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")
    readonly property string helper: root.pluginPath + "/scripts/ai-session-manager"

    function logoFor(session) { return root.pluginPath + "/assets/" + (session && session.provider === "codex" ? "openai.png" : "antigravity.png") }
    function refresh() { if (helper && !statusProcess.running) { statusProcess.command = [helper, "status", "--json"]; statusProcess.running = true } }
    function refreshUsage() { if (helper && !usageProcess.running) { usageProcess.command = [helper, "refresh"]; usageProcess.running = true } }
    function run(action, sessionId) { Quickshell.execDetached(["ghostty", "-e", helper, action, sessionId]); refreshTimer.start() }
    function select(sessionId) { Quickshell.execDetached([helper, "select", sessionId]); refreshTimer.start() }
    function consumeReset(sessionId, creditId) {
        if (pendingResetCreditId !== creditId) { pendingResetCreditId = creditId; resetConfirmTimer.restart(); return }
        Quickshell.execDetached([helper, "consume-reset", sessionId, creditId])
        pendingResetCreditId = ""
        refreshAfterReset.start()
    }
    Component.onCompleted: { refresh(); refreshUsage() }
    Timer { id: refreshTimer; interval: 600; repeat: false; onTriggered: root.refresh() }
    Timer { interval: 1000; running: true; repeat: false; onTriggered: root.refresh() }
    Timer { interval: 300000; running: true; repeat: true; onTriggered: root.refreshUsage() }
    Timer { id: resetConfirmTimer; interval: 6000; repeat: false; onTriggered: root.pendingResetCreditId = "" }
    Timer { id: refreshAfterReset; interval: 1800; repeat: false; onTriggered: root.refreshUsage() }
    Process {
        id: statusProcess
        stdout: StdioCollector { onStreamFinished: {
            try { const data = JSON.parse(text); root.sessions = data.sessions || []; root.activeSession = root.sessions.find(session => session.active) || null; root.activeLabel = root.activeSession ? root.activeSession.label : "AI" } catch (error) {}
        } }
    }
    Process { id: usageProcess; onExited: root.refresh() }

    horizontalBarPill: Component {
        StyledRect {
            width: barContent.implicitWidth + Theme.spacingM * 2; height: parent.widgetThickness; radius: height / 2; color: Theme.surfaceContainerHigh
            Row { id: barContent; anchors.centerIn: parent; spacing: Theme.spacingXS
                Image { width: Theme.fontSizeMedium + 3; height: width; source: root.logoFor(root.activeSession); sourceSize.width: 128; sourceSize.height: 128 }
                StyledText { text: root.activeLabel; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
            }
        }
    }
    verticalBarPill: Component {
        StyledRect { width: parent.widgetThickness; height: parent.widgetThickness; radius: width / 2; color: Theme.surfaceContainerHigh
            Image { anchors.centerIn: parent; width: Theme.fontSizeMedium + 3; height: width; source: root.logoFor(root.activeSession); sourceSize.width: 128; sourceSize.height: 128 }
        }
    }

    function providerTitle() { return selectedProvider === "codex" ? "Codex" : "Antigravity" }
    function providerSession() {
        for (let i = 0; i < sessions.length; i++) if (sessions[i].provider === selectedProvider && sessions[i].active) return sessions[i]
        for (let i = 0; i < sessions.length; i++) if (sessions[i].provider === selectedProvider) return sessions[i]
        return null
    }
    function remaining(resetAt) {
        const ms = Number(resetAt) - Date.now()
        if (!(ms > 0)) return "ahora"
        const minutes = Math.ceil(ms / 60000)
        if (minutes >= 1440) return Math.ceil(minutes / 1440) + " d"
        if (minutes >= 60) return Math.floor(minutes / 60) + " h " + (minutes % 60) + " min"
        return minutes + " min"
    }

    popoutWidth: 460
    popoutHeight: 480
    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn
            headerText: root.settingsMode ? "Gestionar perfiles" : "Agentes"
            detailsText: root.settingsMode ? "Inicios de sesión y nombres" : "Uso y límites de tus agentes"
            showCloseButton: true
            headerActions: Component {
                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: settingsArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                    DankIcon { anchors.centerIn: parent; name: root.settingsMode ? "arrow_back" : "settings"; size: Theme.iconSize - 4; color: Theme.surfaceText }
                    MouseArea { id: settingsArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.settingsMode = !root.settingsMode }
                }
            }

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popoutColumn.headerHeight - popoutColumn.detailsHeight - Theme.spacingXL

                Flickable {
                    id: panelFlick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: dashboard.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    interactive: contentHeight > height

                    Column {
                        id: dashboard
                        width: panelFlick.width
                        spacing: Theme.spacingM

                Column {
                    visible: !root.settingsMode
                    width: parent.width
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        height: 58
                        spacing: Theme.spacingM
                        Image { width: 46; height: width; anchors.verticalCenter: parent.verticalCenter; source: root.logoFor(root.providerSession()); sourceSize.width: 256; sourceSize.height: 256 }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS
                            StyledText { text: root.providerTitle(); color: Theme.surfaceText; font.pixelSize: Theme.fontSizeLarge }
                            StyledText { text: root.providerSession() ? root.providerSession().usage.status : "Sin perfil"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        Repeater {
                            model: [{ id: "codex", name: "Codex" }, { id: "agy", name: "Antigravity" }]
                            delegate: StyledRect {
                                width: (parent.width - parent.spacing) / 2; height: 34; radius: Theme.cornerRadiusSmall
                                property bool hovered: tabMouse.containsMouse
                                color: root.selectedProvider === modelData.id ? Theme.surfaceContainerHighest : (hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                border.width: root.selectedProvider === modelData.id ? 1 : 0
                                border.color: Theme.primary
                                Row { anchors.centerIn: parent; spacing: Theme.spacingXS
                                    Image { width: 18; height: width; source: root.logoFor({ provider: modelData.id }); sourceSize.width: 128; sourceSize.height: 128 }
                                    StyledText { text: modelData.name; color: root.selectedProvider === modelData.id || parent.parent.hovered ? Theme.primary : Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                }
                                MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.selectedProvider = modelData.id }
                            }
                        }
                    }

                    Column {
                        visible: root.selectedProvider === "codex"
                        width: parent.width
                        spacing: Theme.spacingS
                        StyledText { text: "CUENTA CODEX"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        Row {
                            width: parent.width
                            spacing: Theme.spacingM
                            readonly property var first: root.sessions.length > 0 ? root.sessions.find(s => s.id === "codex-1") : null
                            readonly property var second: root.sessions.length > 0 ? root.sessions.find(s => s.id === "codex-2") : null
                            StyledText { width: (parent.width - switcher.width - parent.spacing * 2) / 2; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: parent.first ? parent.first.label : "Codex 1"; color: parent.first && parent.first.active ? Theme.surfaceText : Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeMedium; font.bold: parent.first && parent.first.active }
                            StyledRect {
                                id: switcher; width: 42; height: 24; radius: height / 2; anchors.verticalCenter: parent.verticalCenter; color: parent.second && parent.second.active ? Theme.primary : Theme.surfaceContainerHighest
                                StyledRect { width: 18; height: 18; radius: width / 2; anchors.verticalCenter: parent.verticalCenter; x: parent.parent.second && parent.parent.second.active ? parent.width - width - 3 : 3; color: parent.parent.second && parent.parent.second.active ? Theme.onPrimary : Theme.surfaceText }
                                MouseArea { anchors.fill: parent; onClicked: { const target = parent.parent.second && parent.parent.second.active ? parent.parent.first : parent.parent.second; if (target) root.select(target.id) } }
                            }
                            StyledText { width: (parent.width - switcher.width - parent.spacing * 2) / 2; anchors.verticalCenter: parent.verticalCenter; text: parent.second ? parent.second.label : "Codex 2"; color: parent.second && parent.second.active ? Theme.surfaceText : Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeMedium; font.bold: parent.second && parent.second.active }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.surfaceContainerHighest }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        StyledText { text: "LÍMITES"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        Repeater {
                            model: root.providerSession() && root.providerSession().usage ? root.providerSession().usage.limits : []
                            delegate: Column {
                                width: parent.width; spacing: Theme.spacingXS
                                Row {
                                    width: parent.width
                                    StyledText { text: modelData.label; width: parent.width - availability.implicitWidth; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium }
                                    StyledText { id: availability; text: (100 - modelData.used) + "% disponible"; color: modelData.used >= 90 ? Theme.error : Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                }
                                StyledRect { width: parent.width; height: 7; radius: height / 2; color: Theme.surfaceContainerHighest
                                    StyledRect { width: parent.width * Math.max(0, 1 - modelData.used / 100); height: parent.height; radius: parent.radius; color: modelData.used >= 90 ? Theme.error : Theme.primary }
                                }
                                StyledText { text: "Reinicia en " + root.remaining(modelData.resetAt); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                            }
                        }
                        StyledText { visible: !root.providerSession() || !root.providerSession().usage || root.providerSession().usage.limits.length === 0; width: parent.width; text: root.providerSession() ? root.providerSession().usage.status : "Sin perfil"; wrapMode: Text.WordWrap; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                    }

                    Column {
                        visible: root.providerSession() && root.providerSession().usage && root.providerSession().usage.resetCredits && root.providerSession().usage.resetCredits.length > 0
                        width: parent.width; spacing: Theme.spacingS
                        Rectangle { width: parent.width; height: 1; color: Theme.surfaceContainerHighest }
                        StyledText { text: "RESETS DISPONIBLES · " + (root.providerSession().usage.availableResetCount || root.providerSession().usage.resetCredits.length); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        Repeater {
                            model: root.providerSession() && root.providerSession().usage ? (root.providerSession().usage.resetCredits || []) : []
                            delegate: StyledRect {
                                width: parent.width; height: 46; radius: Theme.cornerRadiusSmall; color: Theme.surfaceContainerHigh
                                Row { anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: Theme.spacingS
                                    Column { width: parent.width - resetButton.width - parent.spacing; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingXS
                                        StyledText { text: modelData.title; width: parent.width; elide: Text.ElideRight; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                        StyledText { text: modelData.expires === "" ? "Caducidad no disponible" : "Caduca: " + modelData.expires; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                                    }
                                    StyledRect {
                                        id: resetButton; width: root.pendingResetCreditId === modelData.id ? 88 : 70; height: 26; anchors.verticalCenter: parent.verticalCenter; radius: Theme.cornerRadiusSmall
                                        color: root.pendingResetCreditId === modelData.id ? Theme.error : Theme.surfaceContainerHighest
                                        StyledText { anchors.centerIn: parent; text: root.pendingResetCreditId === modelData.id ? "Confirmar" : "Usar"; color: root.pendingResetCreditId === modelData.id ? Theme.onError : Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                        MouseArea { anchors.fill: parent; onClicked: root.consumeReset(root.providerSession().id, modelData.id) }
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    visible: root.settingsMode
                    width: parent.width
                    spacing: Theme.spacingS
                    Repeater {
                        model: root.sessions
                        delegate: StyledRect {
                            width: parent.width; height: 76; radius: Theme.cornerRadius; color: Theme.surfaceContainerHigh
                            Row { anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                                Image { width: 34; height: width; anchors.verticalCenter: parent.verticalCenter; source: root.logoFor(modelData); sourceSize.width: 128; sourceSize.height: 128 }
                                Column { width: parent.width - 195; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingXS
                                    TextInput { id: nameInput; width: parent.width; text: modelData.label; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium; selectByMouse: true }
                                    StyledText { text: modelData.authenticated ? "Sesión iniciada" : "Sin iniciar sesión"; color: modelData.authenticated ? Theme.primary : Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                                }
                                StyledRect { width: 58; height: 30; anchors.verticalCenter: parent.verticalCenter; radius: Theme.cornerRadiusSmall; color: Theme.surfaceContainerHighest
                                    StyledText { anchors.centerIn: parent; text: "Login"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                    MouseArea { anchors.fill: parent; onClicked: root.run("login", modelData.id) }
                                }
                                StyledRect { width: 58; height: 30; anchors.verticalCenter: parent.verticalCenter; radius: Theme.cornerRadiusSmall; color: Theme.primary
                                    StyledText { anchors.centerIn: parent; text: "Guardar"; color: Theme.onPrimary; font.pixelSize: Theme.fontSizeSmall }
                                    MouseArea { anchors.fill: parent; onClicked: { Quickshell.execDetached([root.helper, "rename", modelData.id, nameInput.text]); refreshTimer.start() } }
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
}
