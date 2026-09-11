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

    Timer { id: refreshTimer; interval: 500; repeat: false; onTriggered: root.refresh() }
    Timer { interval: 1000; running: true; repeat: false; onTriggered: root.refresh() }

    Process {
        id: statusProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.sessions = data.sessions || []
                    const active = root.sessions.find(session => session.active)
                    root.activeLabel = active ? active.label : "AI"
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
            width: parent.widgetThickness
            height: parent.widgetThickness
            radius: width / 2
            color: Theme.surfaceContainerHigh
            Image { anchors.centerIn: parent; width: Theme.fontSizeMedium + 3; height: width; source: root.pluginPath + "/assets/agent-orbit.svg"; sourceSize.width: 64; sourceSize.height: 64 }
        }
    }

    popoutWidth: 470
    popoutHeight: 410
    popoutContent: Component {
        PopoutComponent {
            headerText: "Sesiones de IA"
            detailsText: "Elige el perfil que usarán tus terminales"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: root.sessions
                    delegate: StyledRect {
                        width: parent.width
                        height: 88
                        radius: Theme.cornerRadius
                        color: modelData.active ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            StyledRect {
                                width: 44; height: 44
                                anchors.verticalCenter: parent.verticalCenter
                                radius: width / 2
                                color: modelData.active ? Theme.primary : Theme.surfaceContainerHighest
                                Image { anchors.centerIn: parent; width: 28; height: width; source: root.pluginPath + "/assets/agent-orbit.svg"; sourceSize.width: 64; sourceSize.height: 64 }
                            }

                            Column {
                                width: 164
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS
                                StyledRect {
                                    width: parent.width; height: 30
                                    radius: Theme.cornerRadiusSmall
                                    color: Theme.surfaceContainerLowest
                                    TextInput {
                                        id: sessionLabel
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingS
                                        anchors.rightMargin: Theme.spacingS
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: modelData.label
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        selectByMouse: true
                                    }
                                }
                                StyledText {
                                    text: modelData.provider === "codex" ? "Codex" : "Antigravity"
                                    color: modelData.authenticated ? Theme.primary : Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            Column {
                                width: 74
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS
                                StyledRect {
                                    width: parent.width; height: 28
                                    radius: Theme.cornerRadiusSmall
                                    color: modelData.active ? Theme.primary : Theme.surfaceContainerHighest
                                    StyledText { anchors.centerIn: parent; text: modelData.active ? "Activa" : "Usar"; color: modelData.active ? Theme.onPrimary : Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                    MouseArea { anchors.fill: parent; enabled: !modelData.active; onClicked: root.select(modelData.id) }
                                }
                                StyledText {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "Guardar"
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    MouseArea { anchors.fill: parent; onClicked: { Quickshell.execDetached([root.helper, "rename", modelData.id, sessionLabel.text]); refreshTimer.start() } }
                                }
                            }

                            Column {
                                width: 74
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS
                                StyledRect {
                                    width: parent.width; height: 28
                                    radius: Theme.cornerRadiusSmall
                                    color: Theme.surfaceContainerHighest
                                    StyledText { anchors.centerIn: parent; text: "Login"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                    MouseArea { anchors.fill: parent; onClicked: root.run("login", modelData.id) }
                                }
                                StyledText {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "Abrir"
                                    color: Theme.primary
                                    font.pixelSize: Theme.fontSizeSmall
                                    MouseArea { anchors.fill: parent; onClicked: root.run("launch", modelData.id) }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: "Los perfiles de Codex están aislados; las credenciales siguen en el cliente oficial."
                    wrapMode: Text.WordWrap
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
