/*
 *   Copyright 2016 David Edmundson <davidedmundson@kde.org>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU Library General Public License as
 *   published by the Free Software Foundation; either version 2 or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details
 *
 *   You should have received a copy of the GNU Library General Public
 *   License along with this program; if not, write to the
 *   Free Software Foundation, Inc.,
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

import QtQuick 2.15

import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasma5support 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.workspace.keyboardlayout as Keyboards

import Qt5Compat.GraphicalEffects
import org.kde.kirigami 2.20 as Kirigami

// Needed for the shader resources used by components/UserDelegate.qml
import org.kde.breeze.components

import "components"

Item {
    id: root

    // If we're using software rendering, draw outlines instead of shadows
    // See https://bugs.kde.org/show_bug.cgi?id=398317
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Kirigami.Theme.inherit: false

    width: 1600
    height: 900

    property string notificationMessage

    // theme.conf uses the standard lowercase "background" key. Keep reading the
    // legacy "Background" key so existing user configuration files keep working.
    readonly property string backgroundType: config.type || "image"
    readonly property url backgroundImage: config.background || config.Background || Qt.resolvedUrl("assets/bg.jpg")
    readonly property color backgroundColor: config.background_color || "#0F111A"

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    Item {
        id: wallpaper
        anchors.fill: parent

        Repeater {
            model: screenModel

            Background {
                x: geometry.x
                y: geometry.y
                width: geometry.width
                height: geometry.height

                sceneBackgroundType: root.backgroundType
                sceneBackgroundColor: root.backgroundColor
                sceneBackgroundImage: root.backgroundImage
            }
        }
    }

    MouseArea {
        id: loginScreenRoot
        anchors.fill: parent

        hoverEnabled: true
        drag.filterChildren: true

        StackView {
            id: mainStack
            anchors.centerIn: parent
            width: Math.max(Kirigami.Units.gridUnit * 12, Math.min(parent.width / 3, Kirigami.Units.gridUnit * 30))
            height: Math.max(Kirigami.Units.gridUnit * 14, Math.min(root.height / 2, Kirigami.Units.gridUnit * 26))

            focus: true //StackView is an implicit focus scope, so we need to give this focus so the item inside will have it

            Timer {
                //SDDM has a bug in 0.13 where even though we set the focus on the right item within the window, the window doesn't have focus
                //it is fixed in 6d5b36b28907b16280ff78995fef764bb0c573db which will be 0.14
                //we need to call "window->activate()" *After* it's been shown. We can't control that in QML so we use a shoddy timer
                //it's been this way for all Plasma 5.x without a huge problem
                running: true
                repeat: false
                interval: 200
                onTriggered: mainStack.forceActiveFocus()
            }

            initialItem: Login {
                id: userListComponent
                userListModel: userModel
                userListCurrentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
                lastUserName: userModel.lastUser

                showUserList: {
                    if ( !userListModel.hasOwnProperty("count")
                    || !userListModel.hasOwnProperty("disableAvatarsThreshold"))
                        return (userList.y + mainStack.y) > 0

                    if ( userListModel.count == 0 ) return false

                    return userListModel.count <= userListModel.disableAvatarsThreshold && (userList.y + mainStack.y) > 0
                }

                notificationMessage: {
                    var text = ""
                    if (capsLockState.locked) {
                        text += i18ndc("plasma-desktop-sddm-theme", "@info:status", "Caps Lock is on")
                        if (root.notificationMessage) {
                            text += " • "
                        }
                    }
                    text += root.notificationMessage
                    return text
                }

                onLoginRequest: (username, password) => root.tryLogin(username, password)
            }

            Behavior on opacity {
                OpacityAnimator {
                    duration: Kirigami.Units.longDuration
                }
            }
        }

        Component {
            id: userPromptComponent
            Login {
                showUsernamePrompt: true
                notificationMessage: root.notificationMessage

                // using a model rather than a QObject list to avoid QTBUG-75900
                userListModel: ListModel {
                    ListElement {
                        name: ""
                        iconSource: ""
                    }
                    Component.onCompleted: {
                        // as we can't bind inside ListElement
                        setProperty(0, "name", i18ndc("plasma-desktop-sddm-theme", "@info:usagetip", "Type in Username and Password"));
                    }
                }

                onLoginRequest: (username, password) => root.tryLogin(username, password)
            }
        }

        ColumnLayout {
            id: actionButtonsColumn
            spacing: 2
            y: root.height / 2 - height / 2
            anchors.left: formBg.left

            property bool showChangeUserButton: true

            function changeMainstackView(action) {

                action == 1 ? mainStack.push(userPromptComponent) : mainStack.pop()

                actionButtonsColumn.showChangeUserButton = !actionButtonsColumn.showChangeUserButton
            }

            ActionButton {
                iconSource: Qt.resolvedUrl("assets/suspend.svg")
                Accessible.name: i18ndc("plasma-desktop-sddm-theme", "@action:button Suspend to RAM", "Sleep")
                onClicked: sddm.suspend()
                enabled: sddm.canSuspend
                visible: !Keyboards.KWinVirtualKeyboard.visible
            }
            ActionButton {
                iconSource: Qt.resolvedUrl("assets/restart.svg")
                Accessible.name: i18ndc("plasma-desktop-sddm-theme", "@action:button", "Restart")
                onClicked: sddm.reboot()
                enabled: sddm.canReboot
                visible: !Keyboards.KWinVirtualKeyboard.visible
            }
            ActionButton {
                iconSource: Qt.resolvedUrl("assets/shutdown.svg")
                Accessible.name: i18ndc("plasma-desktop-sddm-theme", "@action:button", "Shut Down")
                onClicked: sddm.powerOff()
                enabled: sddm.canPowerOff
                visible: !Keyboards.KWinVirtualKeyboard.visible
            }
            ActionButton {
                iconSource: Qt.resolvedUrl("assets/change_user.svg")
                Accessible.name: i18ndc("plasma-desktop-sddm-theme", "@action:button For switching to a username and password prompt", "Other…")
                onClicked: actionButtonsColumn.changeMainstackView(1)
                enabled: true
                visible: !userListComponent.showUsernamePrompt && !Keyboards.KWinVirtualKeyboard.visible && actionButtonsColumn.showChangeUserButton
            }
            ActionButton {
                iconSource: "go-previous"
                Accessible.name: i18ndc("plasma-desktop-sddm-theme", "@action:button", "List Users")
                onClicked: actionButtonsColumn.changeMainstackView(2)
                visible: !Keyboards.KWinVirtualKeyboard.visible && !actionButtonsColumn.showChangeUserButton
            }

        }


        Rectangle {
            id: blurBg
            anchors.fill: parent
            anchors.centerIn: parent
            color: "#0F111A"
            opacity: 0.1
            z:-1
            radius: 10
        }

        Rectangle {
            id: formBg
            width: mainStack.width + actionButtonsColumn.width*2
            height: mainStack.height
            anchors.centerIn: mainStack
            radius: 10
            color: "#0F111A"
            opacity: 0.5
            z:-1
        }

        Rectangle {
            id: actionButtonsBg
            width: actionButtonsColumn.width
            height: mainStack.height
            anchors.centerIn: actionButtonsColumn
            radius: 10
            color: "#0F111A"
            opacity: 0.5
            z:-1
        }

        ShaderEffectSource {
            id: blurArea
            sourceItem: wallpaper
            width: blurBg.width
            height: blurBg.height
            anchors.centerIn: blurBg
            sourceRect: Qt.rect(blurBg.x, blurBg.y, blurBg.width, blurBg.height)
            visible: !root.softwareRendering
            z:-2
        }

        GaussianBlur {
            id: blur
            height: blurBg.height
            width: blurBg.width
            source: blurArea
            radius: 50
            samples: 50 * 2 + 1
            cached: true
            anchors.centerIn: blurBg
            visible: !root.softwareRendering
            z:-2
        }

        //Footer
        RowLayout {
            id: footer
            visible:true

            anchors {
                bottom: parent.bottom
                left: parent.left
                margins: Kirigami.Units.smallSpacing
            }

            Behavior on opacity {
                OpacityAnimator {
                    duration: Kirigami.Units.longDuration
                }
            }

            PlasmaComponents.ToolButton {
                text: i18ndc("plasma-desktop-sddm-theme", "Button to show/hide virtual keyboard", "Virtual Keyboard")
                font.pointSize: config.fontSize
                icon.name: Keyboards.KWinVirtualKeyboard.visible ? "input-keyboard-virtual-on" : "input-keyboard-virtual-off"
                visible: Keyboards.KWinVirtualKeyboard.available
                onClicked: {
                    if (Keyboards.KWinVirtualKeyboard.visible) {
                        Keyboards.KWinVirtualKeyboard.active = false;
                    } else {
                        // Otherwise the password field loses focus and virtual keyboard
                        // keystrokes get eaten
                        userListComponent.focusFirstVisibleFormControl();
                        Keyboards.KWinVirtualKeyboard.forceActivate();
                    }
                }
            }

            KeyboardButton {
                id: keyboardButton

                onKeyboardLayoutChanged: userListComponent.focusFirstVisibleFormControl()
            }

            SessionButton {
                id: sessionButton

                onSessionChanged: userListComponent.focusFirstVisibleFormControl()
            }

        }

        RowLayout {
            id: footerRight
            spacing: 10
            visible:true

            anchors {
                bottom: parent.bottom
                right: parent.right
                margins: 10
            }

            Behavior on opacity {
                OpacityAnimator {
                    duration: Kirigami.Units.longDuration
                }
            }

           Battery {
                fontSize: config.fontSize
            }

            Clock {
                id: clock
                visible: true
            }
        }
    }

    function tryLogin(username, password) {
        root.notificationMessage = ""
        footer.enabled = false
        footerRight.enabled = false
        mainStack.enabled = false
        userListComponent.userList.opacity = 0.75
        sddm.login(username, password, sessionButton.currentIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            notificationMessage = i18ndc("plasma-desktop-sddm-theme", "@info:status", "Login Failed")
            footer.enabled = true
            footerRight.enabled = true
            mainStack.enabled = true
            userListComponent.userList.opacity = 1
            Qt.callLater(function() {
                if (mainStack.currentItem && mainStack.currentItem.focusFirstVisibleFormControl) {
                    mainStack.currentItem.focusFirstVisibleFormControl()
                }
            })
        }
        function onLoginSucceeded() {
            //note SDDM will kill the greeter at some random point after this
            //there is no certainty any transition will finish, it depends on the time it
            //takes to complete the init
            mainStack.opacity = 0
            footer.opacity = 0
            footerRight.opacity = 0
        }
    }

    onNotificationMessageChanged: {
        if (notificationMessage) {
            notificationResetTimer.start();
        }
    }

    Timer {
        id: notificationResetTimer
        interval: 3000
        onTriggered: notificationMessage = ""
    }
}
