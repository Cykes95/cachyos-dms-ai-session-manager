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
    readonly property string helper: (pluginService ? pluginService.getPluginPath(pluginId) : "") + "/scripts/ai-session-manager"
    function refresh() { if (helper && !statusProcess.running) { statusProcess.command = [helper, "status", "--json"]; statusProcess.running = true } }
    function run(action, id) { Quickshell.execDetached(["ghostty", "-e", helper, action, id]); refreshTimer.start() }
    function select(id) { Quickshell.execDetached([helper, "select", id]); refreshTimer.start() }
    Component.onCompleted: refresh()
    Timer { id: refreshTimer; interval: 500; repeat: false; onTriggered: root.refresh() }
    Process { id: statusProcess; stdout: StdioCollector { onStreamFinished: { try { const data = JSON.parse(text); root.sessions = data.sessions || []; const active = root.sessions.find(s => s.active); root.activeLabel = active ? active.label : "AI" } catch (error) {} } } }
    horizontalBarPill: Component { StyledRect { width: label.implicitWidth + Theme.spacingM * 2; height: parent.widgetThickness; radius: Theme.cornerRadius; color: Theme.surfaceContainerHigh
        StyledText { id: label; anchors.centerIn: parent; text: "AI · " + root.activeLabel; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
    } }
    verticalBarPill: Component { StyledRect { width: parent.widgetThickness; height: label.implicitHeight + Theme.spacingM * 2; radius: Theme.cornerRadius; color: Theme.surfaceContainerHigh
        StyledText { id: label; anchors.centerIn: parent; text: "AI"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
    } }
    popoutWidth: 430
    popoutHeight: 360
    popoutContent: Component { PopoutComponent { headerText: "AI sessions"; detailsText: "Profiles keep Codex logins separate"; showCloseButton: true
        Column { width: parent.width; spacing: Theme.spacingS
            Repeater { model: root.sessions
                delegate: Rectangle { width: parent.width; height: 68; radius: Theme.cornerRadius; color: modelData.active ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                    Row { anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: Theme.spacingS
                        Column { width: 135; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: modelData.label; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium }
                            StyledText { text: modelData.provider + (modelData.authenticated ? " · ready" : " · sign in"); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        }
                        Rectangle { width: 54; height: 28; radius: Theme.cornerRadiusSmall; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter
                            StyledText { anchors.centerIn: parent; text: "Use"; color: Theme.onPrimary; font.pixelSize: Theme.fontSizeSmall }
                            MouseArea { anchors.fill: parent; onClicked: root.select(modelData.id) }
                        }
                        Rectangle { width: 54; height: 28; radius: Theme.cornerRadiusSmall; color: Theme.surfaceContainerHighest; anchors.verticalCenter: parent.verticalCenter
                            StyledText { anchors.centerIn: parent; text: "Login"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                            MouseArea { anchors.fill: parent; onClicked: root.run("login", modelData.id) }
                        }
                        Rectangle { width: 54; height: 28; radius: Theme.cornerRadiusSmall; color: Theme.surfaceContainerHighest; anchors.verticalCenter: parent.verticalCenter
                            StyledText { anchors.centerIn: parent; text: "Open"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                            MouseArea { anchors.fill: parent; onClicked: root.run("launch", modelData.id) }
                        }
                    }
                }
            }
            StyledText { width: parent.width; text: "Rename sessions in the plugin settings before signing in."; wrapMode: Text.WordWrap; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
        }
    }
}
