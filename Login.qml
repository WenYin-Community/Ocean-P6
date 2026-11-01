import "components"

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

import org.kde.kirigami 2.20 as Kirigami

SessionManagementScreen {
    id: root
    property Item mainPasswordBox: passwordBox

    property bool showUsernamePrompt: !showUserList

    property string lastUserName

    readonly property bool passwordRequired: !userList.currentItem || userList.currentItem.needsPassword !== false

    //the y position that should be ensured visible when the on screen keyboard is visible
    property int visibleBoundary: mapFromItem(loginButton, 0, 0).y
    onHeightChanged: visibleBoundary = mapFromItem(loginButton, 0, 0).y + loginButton.height + Kirigami.Units.smallSpacing

    signal loginRequest(string username, string password)

    onShowUsernamePromptChanged: {
        if (!showUsernamePrompt) {
            lastUserName = ""
        }
    }

    onUserSelected: {
        passwordBox.clear()
        Qt.callLater(root.focusFirstVisibleFormControl)
    }

    StackView.onActivating: {
        Qt.callLater(root.focusFirstVisibleFormControl)
    }

    function focusFirstVisibleFormControl() {
        var nextControl = userNameInput.visible ? userNameInput
            : (passwordBox.visible ? passwordBox : loginButton)
        // Using TabFocusReason, so that the loginButton gets the visual highlight.
        nextControl.forceActiveFocus(Qt.TabFocusReason)
    }

    /*
    * Login has been requested with the following username and password
    * If username field is visible, it will be taken from that, otherwise from the "name" property of the currentIndex
    */
    function startLogin() {
        if (!loginButton.enabled) {
            return
        }

        var username = showUsernamePrompt ? userNameInput.text : userList.selectedUser
        var password = passwordBox.text

        //this is partly because it looks nicer
        //but more importantly it works round a Qt bug that can trigger if the app is closed with a TextField focused
        //DAVE REPORT THE FRICKING THING AND PUT A LINK
        loginButton.forceActiveFocus();
        loginRequest(username, password);
    }

    Input {
        id: userNameInput
        Layout.fillWidth: true
        Layout.topMargin: 10
        Layout.bottomMargin: 10
        text: lastUserName
        visible: showUsernamePrompt
        focus: showUsernamePrompt && !lastUserName //if there's a username prompt it gets focus first, otherwise password does
        placeholderText: i18ndc("plasma-desktop-sddm-theme", "@info:placeholder in textfield", "Username")

        onAccepted: root.focusFirstVisibleFormControl()
    }

    Input {
        id: passwordBox
        placeholderText: i18ndc("plasma-desktop-sddm-theme", "@info:placeholder in textfield", "Password")
        visible: root.showUsernamePrompt || root.passwordRequired
        focus: visible && (root.showUsernamePrompt ? root.lastUserName !== "" : true)
        echoMode: TextInput.Password

        Layout.fillWidth: true

        onAccepted: root.startLogin()

        Keys.onEscapePressed: {
            root.forceActiveFocus();
        }

        //if empty and left or right is pressed change selection in user switch
        //this cannot be in keys.onLeftPressed as then it doesn't reach the password box
        Keys.onPressed: {
            if (event.key == Qt.Key_Left && !text) {
                userList.decrementCurrentIndex();
                event.accepted = true
            }
            if (event.key == Qt.Key_Right && !text) {
                userList.incrementCurrentIndex();
                event.accepted = true
            }
        }

        Connections {
            target: sddm
            function onLoginFailed() {
                passwordBox.selectAll()
                if (passwordBox.visible) {
                    passwordBox.forceActiveFocus()
                }
            }
        }
    }
    Button {
        id: loginButton
        text: i18ndc("plasma-desktop-sddm-theme", "@action:button", "Log In")
        Accessible.name: text
        enabled: root.showUsernamePrompt
            ? userNameInput.text !== ""
            : (!root.passwordRequired || passwordBox.text !== "")

        Layout.topMargin: 10
        Layout.bottomMargin: 10
        Layout.fillWidth: true
        Layout.preferredHeight: passwordBox.implicitHeight
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

        font.pointSize: config.fontSize
        font.family: config.font

        contentItem: Text {
            text: loginButton.text
            font: loginButton.font
            opacity: enabled ? 1.0 : 0.3
            color: config.highlight_color
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            id: buttonBackground
            anchors.fill: parent
            radius: 10
            color: config.selected_color
            opacity: enabled ? 1.0 : 0.3
        }

        onClicked: startLogin();
    }

}
