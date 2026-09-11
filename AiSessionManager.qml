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
    property string activeLabel: "AI"
    property var activeSession: null
    readonly property string pluginPath: pluginService ? pluginService.getPluginPath(pluginId) : ""
    readonly property string helper: root.pluginPath + "/scripts/ai-session-manager"

    function refresh() {
        if (helper && !statusProcess.running) {
            statusProcess.command = [helper, "status", "--json"]
            statusProcess.running = true
        }
    }
    function run(action, sessionId) {
        Quickshell.execDetached(["ghostty", "-e", helper, action, sessionId])
        refreshTimer.start()
    }
    function select(sessionId) {
        Quickshell.execDetached([helper, "select", sessionId])
        refreshTimer.start()
    }

    Component.onCompleted: refresh()
    Timer { id: refreshTimer; interval: 600; repeat: false; onTriggered: root.refresh() }
    Timer { interval: 1000; running: true; repeat: false; onTriggered: root.refresh() }

    Process {
        id: statusProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.sessions = data.sessions || []
                    root.activeSession = root.sessions.find(session => session.active) || null
                    root.activeLabel = root.activeSession ? root.activeSession.label : "AI"
                } catch (error) {
                }
            }
        }
    }

    horizontalBarPill: Component {
        StyledRect {
            width: barContent.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: height / 2
            color: Theme.surfaceContainerHigh
            Row {
                id: barContent
                anchors.centerIn: parent
                spacing: Theme.spacingXS
                Image { width: Theme.fontSizeMedium + 3; height: width; source: root.pluginPath + "/assets/agent-orbit.svg"; sourceSize.width: 64; sourceSize.height: 64 }
                StyledText { text: root.activeLabel; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            width: parent.widgetThickness; height: parent.widgetThickness; radius: width / 2; color: Theme.surfaceContainerHigh
            Image { anchors.centerIn: parent; width: Theme.fontSizeMedium + 3; height: width; source: root.pluginPath + "/assets/agent-orbit.svg"; sourceSize.width: 64; sourceSize.height: 64 }
        }
    }

    popoutWidth: 460
    popoutHeight: 440
    popoutContent: Component {
        PopoutComponent {
            headerText: "Agentes"
            detailsText: "Cuentas y límites de tus sesiones de IA"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledRect {
                    width: parent.width; height: 78; radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    Row {
                        anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                        Image { width: 42; height: width; anchors.verticalCenter: parent.verticalCenter; source: root.pluginPath + "/assets/agent-orbit.svg"; sourceSize.width: 64; sourceSize.height: 64 }
                        Column {
                            width: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingXS
                            StyledText { text: root.activeSession ? (root.activeSession.provider === "codex" ? "Codex" : "Antigravity") : "Agente"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeLarge }
                            StyledText { text: root.activeSession ? root.activeSession.label + " · " + root.activeSession.usage.status : "Sin sesión"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight; width: parent.width }
                        }
                        StyledRect {
                            width: 68; height: 30; anchors.verticalCenter: parent.verticalCenter; radius: Theme.cornerRadiusSmall; color: Theme.primary
                            StyledText { anchors.centerIn: parent; text: "Abrir"; color: Theme.onPrimary; font.pixelSize: Theme.fontSizeSmall }
                            MouseArea { anchors.fill: parent; enabled: !!root.activeSession; onClicked: root.run("launch", root.activeSession.id) }
                        }
                    }
                }

                Column {
                    width: parent.width; spacing: Theme.spacingS
                    StyledText { text: "PERFIL ACTIVO"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                    Row {
                        width: parent.width; spacing: Theme.spacingS
                        Repeater {
                            model: root.sessions
                            delegate: StyledRect {
                                width: (parent.width - parent.spacing * 2) / 3; height: 40; radius: Theme.cornerRadiusSmall
                                color: modelData.active ? Theme.primary : Theme.surfaceContainerHigh
                                StyledText { anchors.centerIn: parent; text: modelData.label; color: modelData.active ? Theme.onPrimary : Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight; width: parent.width - Theme.spacingS * 2; horizontalAlignment: Text.AlignHCenter }
                                MouseArea { anchors.fill: parent; enabled: !modelData.active; onClicked: root.select(modelData.id) }
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.surfaceContainerHighest }

                Column {
                    width: parent.width; spacing: Theme.spacingS
                    StyledText { text: "LÍMITES"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                    Repeater {
                        model: root.activeSession && root.activeSession.usage ? root.activeSession.usage.limits : []
                        delegate: Column {
                            width: parent.width; spacing: Theme.spacingXS
                            Row {
                                width: parent.width
                                StyledText { text: modelData.label; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium; width: parent.width - usageText.width }
                                StyledText { id: usageText; text: modelData.used + "% usado"; color: modelData.used >= 90 ? Theme.error : Theme.primary; font.pixelSize: Theme.fontSizeSmall }
                            }
                            StyledRect {
                                width: parent.width; height: 8; radius: height / 2; color: Theme.surfaceContainerHighest
                                StyledRect { width: parent.width * Math.min(1, modelData.used / 100); height: parent.height; radius: parent.radius; color: modelData.used >= 90 ? Theme.error : Theme.primary }
                            }
                            StyledText { text: modelData.reset === "" ? "Reinicio no disponible" : "Reinicia: " + modelData.reset; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        }
                    }
                    StyledText {
                        visible: !root.activeSession || !root.activeSession.usage || root.activeSession.usage.limits.length === 0
                        width: parent.width; wrapMode: Text.WordWrap
                        text: root.activeSession && root.activeSession.usage ? root.activeSession.usage.status : "Selecciona una sesión"
                        color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.surfaceContainerHighest }

                Row {
                    width: parent.width; spacing: Theme.spacingS
                    StyledRect {
                        width: 90; height: 30; radius: Theme.cornerRadiusSmall; color: Theme.surfaceContainerHigh
                        StyledText { anchors.centerIn: parent; text: "Renombrar"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                        MouseArea { anchors.fill: parent; onClicked: renameField.forceActiveFocus() }
                    }
                    StyledRect {
                        width: 80; height: 30; radius: Theme.cornerRadiusSmall; color: Theme.surfaceContainerHigh
                        StyledText { anchors.centerIn: parent; text: "Login"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                        MouseArea { anchors.fill: parent; enabled: !!root.activeSession; onClicked: root.run("login", root.activeSession.id) }
                    }
                    StyledRect {
                        width: parent.width - 180; height: 30; radius: Theme.cornerRadiusSmall; color: Theme.surfaceContainerLowest
                        TextInput { id: renameField; anchors.fill: parent; anchors.leftMargin: Theme.spacingS; anchors.rightMargin: Theme.spacingS; verticalAlignment: TextInput.AlignVCenter; text: root.activeSession ? root.activeSession.label : ""; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; selectByMouse: true; onAccepted: { if (root.activeSession) { Quickshell.execDetached([root.helper, "rename", root.activeSession.id, text]); refreshTimer.start() } } }
                    }
                }
            }
        }
    }
}
