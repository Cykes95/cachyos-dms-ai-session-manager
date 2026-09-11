import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

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

    function logoFor(session) {
        return root.pluginPath + "/assets/" + (session && session.provider === "codex" ? "openai.png" : "antigravity.png");
    }

    function refresh() {
        if (helper && !statusProcess.running) {
            statusProcess.command = [helper, "status", "--json"];
            statusProcess.running = true;
        }
    }

    function refreshUsage() {
        if (helper && !usageProcess.running) {
            usageProcess.command = [helper, "refresh"];
            usageProcess.running = true;
        }
    }

    function run(action, sessionId) {
        Quickshell.execDetached(["ghostty", "-e", helper, action, sessionId]);
        refreshTimer.start();
        postLaunchRefresh.restart();
    }

    function select(sessionId) {
        Quickshell.execDetached([helper, "select", sessionId]);
        refreshTimer.start();
    }

    function consumeReset(sessionId, creditId) {
        if (pendingResetCreditId !== creditId) {
            pendingResetCreditId = creditId;
            resetConfirmTimer.restart();
            return ;
        }
        Quickshell.execDetached([helper, "consume-reset", sessionId, creditId]);
        pendingResetCreditId = "";
        refreshAfterReset.start();
    }

    function providerTitle() {
        return selectedProvider === "codex" ? "Codex" : "Antigravity";
    }

    function providerSession() {
        for (let i = 0; i < sessions.length; i++) if (sessions[i].provider === selectedProvider && sessions[i].active) {
            return sessions[i];
        }
        for (let i = 0; i < sessions.length; i++) if (sessions[i].provider === selectedProvider) {
            return sessions[i];
        }
        return null;
    }

    function remaining(resetAt) {
        const ms = Number(resetAt) - Date.now();
        if (!(ms > 0))
            return "ahora";

        const minutes = Math.ceil(ms / 60000);
        if (minutes >= 1440)
            return Math.ceil(minutes / 1440) + " d";

        if (minutes >= 60)
            return Math.floor(minutes / 60) + " h " + (minutes % 60) + " min";

        return minutes + " min";
    }

    Component.onCompleted: {
        refresh();
        refreshUsage();
    }
    popoutWidth: 500
    popoutHeight: 640

    Timer {
        id: refreshTimer

        interval: 600
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1000
        running: true
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.refreshUsage()
    }

    Timer {
        id: resetConfirmTimer

        interval: 6000
        repeat: false
        onTriggered: root.pendingResetCreditId = ""
    }

    Timer {
        id: refreshAfterReset

        interval: 1800
        repeat: false
        onTriggered: root.refreshUsage()
    }

    Timer {
        id: postLaunchRefresh

        interval: 3500
        repeat: false
        onTriggered: root.refreshUsage()
    }

    Process {
        id: statusProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.sessions = data.sessions || [];
                    root.activeSession = root.sessions.find((session) => {
                        return session.active;
                    }) || null;
                    root.activeLabel = root.activeSession ? root.activeSession.label : "AI";
                } catch (error) {
                }
            }
        }

    }

    Process {
        id: usageProcess

        onExited: root.refresh()
    }

    horizontalBarPill: Component {
        Item {
            id: barRoot

            implicitWidth: pillRect.implicitWidth
            implicitHeight: root.widgetThickness
            width: implicitWidth
            height: implicitHeight

            StyledRect {
                id: pillRect

                anchors.fill: parent
                implicitWidth: barContent.implicitWidth + Theme.spacingM * 2
                radius: height / 2
                color: pillHover.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.width: 1
                border.color: pillHover.containsMouse ? Theme.outline : Theme.withAlpha(Theme.outlineVariant, 0.4)

                Row {
                    id: barContent

                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(18, Math.min(22, Math.round(barRoot.height * 0.58)))
                        height: width
                        source: root.logoFor(root.activeSession)
                        sourceSize.width: 128
                        sourceSize.height: 128
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.activeLabel
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                    }

                    StyledRect {
                        width: 8
                        height: 8
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: {
                            const sess = root.activeSession;
                            if (!sess || !sess.usage || !sess.usage.limits || sess.usage.limits.length === 0)
                                return Theme.primary;

                            const mainLimit = sess.usage.limits[0];
                            if (mainLimit.used >= 95)
                                return Theme.error;

                            if (mainLimit.used >= 75)
                                return "#f59e0b";

                            return "#10b981";
                        }
                    }

                }

                MouseArea {
                    id: pillHover

                    anchors.fill: parent
                    acceptedButtons: Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: (mouse) => {
                        if (root.activeSession)
                            root.run("launch", root.activeSession.id);

                    }
                }

            }

        }

    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.widgetThickness
            implicitHeight: root.widgetThickness
            width: implicitWidth
            height: implicitHeight

            StyledRect {
                anchors.fill: parent
                radius: width / 2
                color: vPillHover.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.width: 1
                border.color: vPillHover.containsMouse ? Theme.outline : Theme.withAlpha(Theme.outlineVariant, 0.4)

                Image {
                    anchors.centerIn: parent
                    width: Math.max(18, Math.min(22, Math.round(parent.height * 0.58)))
                    height: width
                    source: root.logoFor(root.activeSession)
                    sourceSize.width: 128
                    sourceSize.height: 128
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                StyledRect {
                    width: 7
                    height: 7
                    radius: 3.5
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 3
                    color: {
                        const sess = root.activeSession;
                        if (!sess || !sess.usage || !sess.usage.limits || sess.usage.limits.length === 0)
                            return Theme.primary;

                        const mainLimit = sess.usage.limits[0];
                        if (mainLimit.used >= 95)
                            return Theme.error;

                        if (mainLimit.used >= 75)
                            return "#f59e0b";

                        return "#10b981";
                    }
                }

                MouseArea {
                    id: vPillHover

                    anchors.fill: parent
                    acceptedButtons: Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: (mouse) => {
                        if (root.activeSession)
                            root.run("launch", root.activeSession.id);

                    }
                }

            }

        }

    }

    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn

            headerText: root.settingsMode ? "Gestionar perfiles" : "Agentes"
            detailsText: root.settingsMode ? "Inicios de sesión y nombres" : "Uso y límites de tus agentes"
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popoutColumn.headerHeight - popoutColumn.detailsHeight - Theme.spacingXL

                Flickable {
                    id: flickable

                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: mainContainer.implicitHeight + Theme.spacingS
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        target: null
                        onWheel: (event) => {
                            flickable.contentY = Math.max(0, Math.min(flickable.contentHeight - flickable.height, flickable.contentY - event.angleDelta.y));
                        }
                    }

                    Column {
                        id: mainContainer

                        width: parent.width
                        spacing: Theme.spacingM

                        // 1. DASHBOARD VIEW (when !settingsMode)
                        Column {
                            visible: !root.settingsMode
                            width: parent.width
                            spacing: Theme.spacingM

                            // HERO CARD: Active Profile Overview & Terminal Launcher
                            StyledRect {
                                width: parent.width
                                height: 88
                                radius: 20
                                color: Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: Theme.withAlpha(Theme.outlineVariant, 0.35)

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    StyledRect {
                                        width: 54
                                        height: 54
                                        radius: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Theme.surfaceContainerHighest

                                        Image {
                                            anchors.centerIn: parent
                                            width: 32
                                            height: 32
                                            source: root.logoFor(root.providerSession())
                                            sourceSize.width: 128
                                            sourceSize.height: 128
                                        }

                                        StyledRect {
                                            width: 12
                                            height: 12
                                            radius: 6
                                            anchors.bottom: parent.bottom
                                            anchors.right: parent.right
                                            anchors.margins: -1
                                            color: root.providerSession() && root.providerSession().authenticated ? "#10b981" : Theme.error
                                            border.width: 2
                                            border.color: parent.color
                                        }

                                    }

                                    Column {
                                        width: parent.width - 54 - termBtn.width - parent.spacing * 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        StyledText {
                                            width: parent.width
                                            text: root.selectedProvider === "codex" && root.providerSession() ? (root.providerTitle() + " · " + root.providerSession().label) : root.providerTitle()
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeLarge
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                        }

                                        Row {
                                            spacing: Theme.spacingXS

                                            StyledRect {
                                                height: 22
                                                width: tierBadgeText.implicitWidth + 16
                                                radius: height / 2
                                                color: Theme.withAlpha(Theme.primary, 0.15)

                                                StyledText {
                                                    id: tierBadgeText

                                                    anchors.centerIn: parent
                                                    text: (root.providerSession() && root.providerSession().usage ? root.providerSession().usage.status : "Sin perfil").toUpperCase()
                                                    color: Theme.primary
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.Bold
                                                }

                                            }

                                        }

                                    }

                                    StyledRect {
                                        id: termBtn

                                        width: 120
                                        height: 42
                                        radius: height / 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: termMouse.containsMouse ? Theme.primaryHover : Theme.primary

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingXS

                                            DankIcon {
                                                name: "terminal"
                                                size: 18
                                                color: Theme.onPrimary
                                            }

                                            StyledText {
                                                text: "Terminal"
                                                color: Theme.onPrimary
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.Bold
                                            }

                                        }

                                        MouseArea {
                                            id: termMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const sess = root.providerSession();
                                                if (sess)
                                                    root.run("launch", sess.id);

                                            }
                                        }

                                    }

                                }

                            }

                            // PROVIDER SWITCHER: Segmented Control
                            StyledRect {
                                width: parent.width
                                height: 46
                                radius: height / 2
                                color: Theme.surfaceContainerHighest

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    spacing: 4

                                    Repeater {
                                        model: [{
                                            "id": "codex",
                                            "name": "Codex"
                                        }, {
                                            "id": "agy",
                                            "name": "Antigravity"
                                        }]

                                        delegate: StyledRect {
                                            property bool isSelected: root.selectedProvider === modelData.id
                                            property bool hovered: provMouse.containsMouse

                                            width: (parent.width - 4) / 2
                                            height: parent.height
                                            radius: height / 2
                                            color: isSelected ? Theme.primary : (hovered ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: Theme.spacingS

                                                Image {
                                                    width: 20
                                                    height: 20
                                                    source: root.logoFor({
                                                        "provider": modelData.id
                                                    })
                                                    sourceSize.width: 128
                                                    sourceSize.height: 128
                                                }

                                                StyledText {
                                                    text: modelData.name
                                                    color: parent.parent.isSelected ? Theme.onPrimary : Theme.surfaceText
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    font.weight: parent.parent.isSelected ? Font.Bold : Font.Normal
                                                }

                                            }

                                            MouseArea {
                                                id: provMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectedProvider = modelData.id
                                            }

                                        }

                                    }

                                }

                            }

                            // CODEX ACCOUNT SELECTOR CARDS
                            Column {
                                visible: root.selectedProvider === "codex"
                                width: parent.width
                                spacing: Theme.spacingS

                                Row {
                                    width: parent.width

                                    StyledText {
                                        text: "CUENTAS DISPONIBLES"
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        width: parent.width - accHintText.implicitWidth
                                    }

                                    StyledText {
                                        id: accHintText

                                        text: "Haz clic para cambiar"
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                    }

                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingM

                                    Repeater {
                                        model: root.sessions.filter((s) => {
                                            return s.provider === "codex";
                                        })

                                        delegate: StyledRect {
                                            property bool isActive: modelData.active
                                            property bool hovered: accMouse.containsMouse

                                            width: (parent.width - Theme.spacingM) / 2
                                            height: 66
                                            radius: 18
                                            color: isActive ? Theme.withAlpha(Theme.primary, 0.12) : (hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                            border.width: isActive ? 2 : 1
                                            border.color: isActive ? Theme.primary : Theme.withAlpha(Theme.outlineVariant, 0.3)

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingM
                                                spacing: Theme.spacingS

                                                StyledRect {
                                                    width: 36
                                                    height: 36
                                                    radius: 18
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: parent.parent.isActive ? Theme.primary : Theme.surfaceContainerHighest

                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: modelData.label ? modelData.label.charAt(0).toUpperCase() : "C"
                                                        color: parent.parent.parent.isActive ? Theme.onPrimary : Theme.surfaceText
                                                        font.pixelSize: Theme.fontSizeMedium
                                                        font.weight: Font.Bold
                                                    }

                                                }

                                                Column {
                                                    width: parent.width - 36 - (parent.parent.isActive ? 24 : 0) - parent.spacing * 2
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 2

                                                    StyledText {
                                                        width: parent.width
                                                        text: modelData.label
                                                        color: parent.parent.parent.isActive ? Theme.primary : Theme.surfaceText
                                                        font.pixelSize: Theme.fontSizeMedium
                                                        font.weight: Font.Bold
                                                        elide: Text.ElideRight
                                                    }

                                                    StyledText {
                                                        width: parent.width
                                                        text: {
                                                            const u = modelData.usage;
                                                            if (!u || !u.limits || u.limits.length === 0)
                                                                return u ? u.status : "Codex";

                                                            const mainLim = u.limits[0];
                                                            return (100 - mainLim.used) + "% disp. · " + (u.status ? u.status.toUpperCase() : "");
                                                        }
                                                        color: Theme.surfaceVariantText
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        elide: Text.ElideRight
                                                    }

                                                }

                                                DankIcon {
                                                    visible: parent.parent.isActive
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    name: "check_circle"
                                                    size: 20
                                                    color: Theme.primary
                                                }

                                            }

                                            MouseArea {
                                                id: accMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.select(modelData.id)
                                            }

                                        }

                                    }

                                }

                            }

                            // LIMITS & USAGE SECTION
                            Column {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: "LÍMITES DE USO"
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                }

                                Repeater {
                                    model: root.providerSession() && root.providerSession().usage ? root.providerSession().usage.limits : []

                                    delegate: StyledRect {
                                        width: parent.width
                                        height: 78
                                        radius: 18
                                        color: Theme.surfaceContainerHigh
                                        border.width: 1
                                        border.color: Theme.withAlpha(Theme.outlineVariant, 0.25)

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            spacing: 7

                                            Row {
                                                width: parent.width

                                                StyledText {
                                                    text: modelData.label
                                                    width: parent.width - availBadge.width
                                                    color: Theme.surfaceText
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    font.weight: Font.DemiBold
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    elide: Text.ElideRight
                                                }

                                                StyledRect {
                                                    id: availBadge

                                                    height: 22
                                                    width: availText.implicitWidth + 16
                                                    radius: height / 2
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: {
                                                        if (modelData.used >= 95)
                                                            return Theme.withAlpha(Theme.error, 0.18);

                                                        if (modelData.used >= 75)
                                                            return Theme.withAlpha("#f59e0b", 0.18);

                                                        return Theme.withAlpha(Theme.primary, 0.18);
                                                    }

                                                    StyledText {
                                                        id: availText

                                                        anchors.centerIn: parent
                                                        text: modelData.used >= 100 ? "Agotado · 0% libre" : ((100 - modelData.used) + "% disponible")
                                                        color: {
                                                            if (modelData.used >= 95)
                                                                return Theme.error;

                                                            if (modelData.used >= 75)
                                                                return "#f59e0b";

                                                            return Theme.primary;
                                                        }
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        font.weight: Font.Bold
                                                    }

                                                }

                                            }

                                            StyledRect {
                                                width: parent.width
                                                height: 12
                                                radius: height / 2
                                                color: Theme.surfaceContainerHighest

                                                StyledRect {
                                                    width: parent.width * Math.max(0, Math.min(1, (100 - modelData.used) / 100))
                                                    height: parent.height
                                                    radius: height / 2
                                                    color: {
                                                        if (modelData.used >= 95)
                                                            return Theme.error;

                                                        if (modelData.used >= 75)
                                                            return "#f59e0b";

                                                        return Theme.primary;
                                                    }
                                                }

                                            }

                                            Row {
                                                spacing: 6
                                                visible: (modelData.resetAt > 0) || (modelData.reset && modelData.reset !== "")

                                                DankIcon {
                                                    name: "schedule"
                                                    size: 13
                                                    color: Theme.surfaceVariantText
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    text: "Reinicia en " + root.remaining(modelData.resetAt) + (modelData.reset ? (" (" + modelData.reset + ")") : "")
                                                    color: Theme.surfaceVariantText
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                            }

                                        }

                                    }

                                }

                                StyledText {
                                    visible: !root.providerSession() || !root.providerSession().usage || root.providerSession().usage.limits.length === 0
                                    width: parent.width
                                    text: root.providerSession() ? root.providerSession().usage.status : "Sin perfil"
                                    wrapMode: Text.WordWrap
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeMedium
                                    horizontalAlignment: Text.AlignHCenter
                                }

                            }

                            // RESET CREDITS SECTION
                            Column {
                                visible: root.providerSession() && root.providerSession().usage && root.providerSession().usage.resetCredits && root.providerSession().usage.resetCredits.length > 0
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: "REINICIOS DISPONIBLES · " + (root.providerSession().usage.availableResetCount || root.providerSession().usage.resetCredits.length)
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                }

                                Repeater {
                                    model: root.providerSession() && root.providerSession().usage ? (root.providerSession().usage.resetCredits || []) : []

                                    delegate: StyledRect {
                                        width: parent.width
                                        height: 58
                                        radius: 18
                                        color: Theme.surfaceContainerHigh
                                        border.width: 1
                                        border.color: Theme.withAlpha(Theme.outlineVariant, 0.25)

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            spacing: Theme.spacingM

                                            StyledRect {
                                                width: 34
                                                height: 34
                                                radius: 17
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: Theme.withAlpha(Theme.primary, 0.15)

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: "bolt"
                                                    size: 18
                                                    color: Theme.primary
                                                }

                                            }

                                            Column {
                                                width: parent.width - 34 - resetActionBtn.width - parent.spacing * 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2

                                                StyledText {
                                                    text: modelData.title
                                                    width: parent.width
                                                    elide: Text.ElideRight
                                                    color: Theme.surfaceText
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    font.weight: Font.DemiBold
                                                }

                                                StyledText {
                                                    text: modelData.expires === "" ? "Sin fecha de caducidad" : ("Caduca: " + modelData.expires)
                                                    color: Theme.surfaceVariantText
                                                    font.pixelSize: Theme.fontSizeSmall
                                                }

                                            }

                                            StyledRect {
                                                id: resetActionBtn

                                                width: root.pendingResetCreditId === modelData.id ? 96 : 76
                                                height: 34
                                                anchors.verticalCenter: parent.verticalCenter
                                                radius: height / 2
                                                color: root.pendingResetCreditId === modelData.id ? Theme.error : Theme.surfaceContainerHighest

                                                StyledText {
                                                    anchors.centerIn: parent
                                                    text: root.pendingResetCreditId === modelData.id ? "Confirmar" : "Usar"
                                                    color: root.pendingResetCreditId === modelData.id ? Theme.onError : Theme.surfaceText
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.Bold
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.consumeReset(root.providerSession().id, modelData.id)
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                        }

                        // 2. SETTINGS VIEW (when settingsMode)
                        Column {
                            visible: root.settingsMode
                            width: parent.width
                            spacing: Theme.spacingM

                            StyledText {
                                text: "PERFILES CONFIGURADOS"
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                            }

                            Repeater {
                                model: root.sessions

                                delegate: StyledRect {
                                    width: parent.width
                                    height: 84
                                    radius: 20
                                    color: Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Theme.withAlpha(Theme.outlineVariant, 0.3)

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingM
                                        spacing: Theme.spacingM

                                        StyledRect {
                                            width: 46
                                            height: 46
                                            radius: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: Theme.surfaceContainerHighest

                                            Image {
                                                anchors.centerIn: parent
                                                width: 28
                                                height: 28
                                                source: root.logoFor(modelData)
                                                sourceSize.width: 128
                                                sourceSize.height: 128
                                            }

                                        }

                                        Column {
                                            width: parent.width - 46 - settingsActionRow.width - parent.spacing * 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            StyledRect {
                                                width: parent.width
                                                height: 34
                                                radius: height / 2
                                                color: Theme.surfaceContainerHighest
                                                border.width: nameInput.activeFocus ? 1.5 : 0
                                                border.color: Theme.primary

                                                TextInput {
                                                    id: nameInput

                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    text: modelData.label
                                                    color: Theme.surfaceText
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    font.weight: Font.Medium
                                                    selectByMouse: true
                                                }

                                            }

                                            Row {
                                                spacing: 5

                                                StyledRect {
                                                    width: 6
                                                    height: 6
                                                    radius: 3
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: modelData.authenticated ? "#10b981" : Theme.surfaceVariantText
                                                }

                                                StyledText {
                                                    text: modelData.authenticated ? "Sesión iniciada" : "Sin iniciar sesión"
                                                    color: modelData.authenticated ? "#10b981" : Theme.surfaceVariantText
                                                    font.pixelSize: Theme.fontSizeSmall
                                                }

                                            }

                                        }

                                        Row {
                                            id: settingsActionRow

                                            spacing: Theme.spacingS
                                            anchors.verticalCenter: parent.verticalCenter

                                            StyledRect {
                                                width: 72
                                                height: 34
                                                radius: height / 2
                                                color: loginHover.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                                                border.width: 1
                                                border.color: Theme.withAlpha(Theme.outlineVariant, 0.4)

                                                StyledText {
                                                    anchors.centerIn: parent
                                                    text: "Login"
                                                    color: Theme.surfaceText
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.Bold
                                                }

                                                MouseArea {
                                                    id: loginHover

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.run("login", modelData.id)
                                                }

                                            }

                                            StyledRect {
                                                width: 82
                                                height: 34
                                                radius: height / 2
                                                color: saveHover.containsMouse ? Theme.primaryHover : Theme.primary

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    DankIcon {
                                                        name: "check"
                                                        size: 16
                                                        color: Theme.onPrimary
                                                    }

                                                    StyledText {
                                                        text: "Guardar"
                                                        color: Theme.onPrimary
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        font.weight: Font.Bold
                                                    }

                                                }

                                                MouseArea {
                                                    id: saveHover

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        Quickshell.execDetached([root.helper, "rename", modelData.id, nameInput.text]);
                                                        refreshTimer.start();
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

            headerActions: Component {
                Row {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: refreshArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: "refresh"
                            size: Theme.iconSize - 4
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: refreshArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.refreshUsage();
                                root.refresh();
                            }
                        }

                    }

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: settingsArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: root.settingsMode ? "arrow_back" : "settings"
                            size: Theme.iconSize - 4
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: settingsArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.settingsMode = !root.settingsMode
                        }

                    }

                }

            }

        }

    }

}
