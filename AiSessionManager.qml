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
    property bool settingsMode: false
    readonly property string pluginPath: pluginService ? pluginService.getPluginPath(pluginId) : ""
    readonly property string helper: root.pluginPath + "/scripts/ai-session-manager"

    function logoFor(session) { return root.pluginPath + "/assets/" + (session && session.provider === "codex" ? "openai.png" : "antigravity.png") }
    function refresh() { if (helper && !statusProcess.running) { statusProcess.command = [helper, "status", "--json"]; statusProcess.running = true } }
    function run(action, sessionId) { Quickshell.execDetached(["ghostty", "-e", helper, action, sessionId]); refreshTimer.start() }
    function select(sessionId) { Quickshell.execDetached([helper, "select", sessionId]); refreshTimer.start() }
    Component.onCompleted: refresh()
    Timer { id: refreshTimer; interval: 600; repeat: false; onTriggered: root.refresh() }
    Timer { interval: 1000; running: true; repeat: false; onTriggered: root.refresh() }
    Process {
        id: statusProcess
        stdout: StdioCollector { onStreamFinished: {
            try { const data = JSON.parse(text); root.sessions = data.sessions || []; root.activeSession = root.sessions.find(session => session.active) || null; root.activeLabel = root.activeSession ? root.activeSession.label : "AI" } catch (error) {}
        } }
    }

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

    popoutWidth: 460
    popoutHeight: 455
    popoutContent: Component {
        PopoutComponent {
            headerText: root.settingsMode ? "Gestionar perfiles" : "Agentes"
            detailsText: root.settingsMode ? "Inicios de sesión y nombres" : "Cuentas y límites de tus sesiones de IA"
            showCloseButton: false
            Column {
                width: parent.width; spacing: Theme.spacingM

                Row {
                    width: parent.width; height: 20; layoutDirection: Qt.RightToLeft; spacing: Theme.spacingS
                    DankIcon { name: "close"; color: Theme.surfaceVariantText; size: Theme.iconSize - 4
                        MouseArea { anchors.fill: parent; onClicked: closePopout() }
                    }
                    DankIcon { name: root.settingsMode ? "arrow_back" : "settings"; color: Theme.surfaceVariantText; size: Theme.iconSize - 4
                        MouseArea { anchors.fill: parent; onClicked: root.settingsMode = !root.settingsMode }
                    }
                }

                Column {
                    visible: !root.settingsMode; width: parent.width; spacing: Theme.spacingM
                    StyledRect {
                        width: parent.width; height: 76; radius: Theme.cornerRadius; color: Theme.surfaceContainerHigh
                        Row { anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                            Image { width: 42; height: width; anchors.verticalCenter: parent.verticalCenter; source: root.logoFor(root.activeSession); sourceSize.width: 256; sourceSize.height: 256 }
                            Column { width: parent.width - 144; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingXS
                                StyledText { text: root.activeSession ? (root.activeSession.provider === "codex" ? "Codex" : "Antigravity") : "Agente"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeLarge }
                                StyledText { text: root.activeSession ? root.activeSession.label + " · " + root.activeSession.usage.status : "Sin sesión"; width: parent.width; elide: Text.ElideRight; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                            }
                            StyledRect { width: 68; height: 30; anchors.verticalCenter: parent.verticalCenter; radius: Theme.cornerRadiusSmall; color: Theme.primary
                                StyledText { anchors.centerIn: parent; text: "Abrir"; color: Theme.onPrimary; font.pixelSize: Theme.fontSizeSmall }
                                MouseArea { anchors.fill: parent; enabled: !!root.activeSession; onClicked: root.run("launch", root.activeSession.id) }
                            }
                        }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "PERFIL ACTIVO"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        Row { width: parent.width; spacing: Theme.spacingS
                            Repeater { model: root.sessions
                                delegate: StyledRect { width: (parent.width - parent.spacing * 2) / 3; height: 42; radius: Theme.cornerRadiusSmall; color: modelData.active ? Theme.primary : Theme.surfaceContainerHigh
                                    Row { anchors.centerIn: parent; spacing: Theme.spacingXS
                                        Image { width: 17; height: width; source: root.logoFor(modelData); sourceSize.width: 128; sourceSize.height: 128 }
                                        StyledText { text: modelData.label; color: modelData.active ? Theme.onPrimary : Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                    }
                                    MouseArea { anchors.fill: parent; enabled: !modelData.active; onClicked: root.select(modelData.id) }
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.surfaceContainerHighest }
                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "LÍMITES"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        Repeater { model: root.activeSession && root.activeSession.usage ? root.activeSession.usage.limits : []
                            delegate: Column { width: parent.width; spacing: Theme.spacingXS
                                Row { width: parent.width
                                    StyledText { text: modelData.label; width: parent.width - usageText.width; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium }
                                    StyledText { id: usageText; text: modelData.used + "% usado"; color: modelData.used >= 90 ? Theme.error : Theme.primary; font.pixelSize: Theme.fontSizeSmall }
                                }
                                StyledRect { width: parent.width; height: 8; radius: height / 2; color: Theme.surfaceContainerHighest
                                    StyledRect { width: parent.width * Math.min(1, modelData.used / 100); height: parent.height; radius: parent.radius; color: modelData.used >= 90 ? Theme.error : Theme.primary }
                                }
                                StyledText { text: modelData.reset === "" ? "Reinicio no disponible" : "Se reinicia en " + modelData.reset; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                            }
                        }
                        StyledText { visible: !root.activeSession || !root.activeSession.usage || root.activeSession.usage.limits.length === 0; width: parent.width; wrapMode: Text.WordWrap; text: root.activeSession && root.activeSession.usage ? root.activeSession.usage.status : "Selecciona una sesión"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                    }

                    Column { visible: root.activeSession && root.activeSession.usage && root.activeSession.usage.resetCredits && root.activeSession.usage.resetCredits.length > 0; width: parent.width; spacing: Theme.spacingS
                        Rectangle { width: parent.width; height: 1; color: Theme.surfaceContainerHighest }
                        StyledText { text: "RESETS DISPONIBLES · " + root.activeSession.usage.resetCredits.length; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        Repeater { model: root.activeSession && root.activeSession.usage ? (root.activeSession.usage.resetCredits || []) : []
                            delegate: Row { width: parent.width
                                StyledText { text: modelData.title; width: parent.width - expiry.implicitWidth; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
                                StyledText { id: expiry; text: modelData.expires === "" ? "" : "Caduca: " + modelData.expires; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                            }
                        }
                    }
                }

                Column {
                    visible: root.settingsMode; width: parent.width; spacing: Theme.spacingS
                    Repeater { model: root.sessions
                        delegate: StyledRect { width: parent.width; height: 82; radius: Theme.cornerRadius; color: Theme.surfaceContainerHigh
                            Row { anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                                Image { width: 36; height: width; anchors.verticalCenter: parent.verticalCenter; source: root.logoFor(modelData); sourceSize.width: 128; sourceSize.height: 128 }
                                Column { width: parent.width - 205; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingXS
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
                    StyledText { width: parent.width; text: "Cada perfil de Codex conserva su inicio de sesión aislado."; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap }
                }
            }
        }
    }
}
