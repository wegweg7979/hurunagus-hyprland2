import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 640
  height: 480
  color: "#1a1b26"

  // SDDM stores the last successful user in /var/lib/sddm/state.conf.
  // On a fresh install or rebase that file does not exist yet, so
  // userModel.lastIndex is 0 and the picker below starts on the first
  // human account instead of submitting an empty username.
  // If the remembered user no longer exists, lastIndex is also 0.
  // SDDM 0.21 UserModel::NameRole is Qt::UserRole + 1.
  property int userNameRole: 0x0101
  property int initialUserIndex: {
    var index = userModel.lastIndex
    if (index === undefined || index === null || index < 0 || index >= userModel.count)
      return 0
    return index
  }
  property string currentUser: {
    if (userModel.count > 0)
      return (userModel.data(userModel.index(initialUserIndex, 0), userNameRole) || "").toString()
    return ""
  }
  property bool loginFailed: false
  property int userRowHeight: 40
  // SDDM 0.21 SessionModel::NameRole is Qt::UserRole + 4. Its DisplayRole
  // is empty, so the upstream "find uwsm" loop never matched.
  property int sessionNameRole: 0x0104
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), sessionNameRole) || "").toString()
      if (name.indexOf("uwsm") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }

  function userNameAt(index) {
    if (index < 0 || index >= userModel.count)
      return ""
    return (userModel.data(userModel.index(index, 0), userNameRole) || "").toString()
  }

  function setUserFromItem() {
    var item = userList.currentItem
    if (!item)
      return

    var userName = item.userName
    if (!userName || userName === root.currentUser)
      return

    root.currentUser = userName
    root.loginFailed = false
  }

  function selectRelativeUser(delta) {
    var count = userList.count
    if (count < 1)
      return

    var current = userList.currentIndex
    var next
    if (current < 0)
      next = delta > 0 ? 0 : count - 1
    else
      next = (current + delta + count) % count
    if (next !== current) {
      var userName = userNameAt(next)
      if (userName.length > 0) {
        root.currentUser = userName
        userList.currentIndex = next
        userList.positionViewAtIndex(next, ListView.Contain)
        root.loginFailed = false
        password.text = ""
      }
    }
    password.forceActiveFocus()
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      // Clear first: onTextChanged resets loginFailed while editing.
      password.text = ""
      root.loginFailed = true
      password.forceActiveFocus()
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 32

    Image {
      id: logo
      source: "logo.png"
      width: Math.min(sourceSize.width, root.width * 0.8)
      height: sourceSize.width > 0 ? Math.round(width * sourceSize.height / sourceSize.width) : 0
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
    }

    // User picker. One row per human account. Click a name, or use Up/Down
    // while the password field has focus, to change the selected account.
    ListView {
      id: userList
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(root.width * 0.8, 360)
      height: Math.min(userModel.count * root.userRowHeight, 200)
      model: userModel
      spacing: 0
      clip: true
      interactive: true
      boundsBehavior: Flickable.StopAtBounds
      currentIndex: userModel.count > 0 ? root.initialUserIndex : -1

      onCurrentItemChanged: root.setUserFromItem()

      delegate: Item {
        id: userItem
        width: userList.width
        height: root.userRowHeight
        property string userName: model.name

        Text {
          id: userLabel
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 20
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: userItem.userName
          color: "#ffffff"
          opacity: userList.currentIndex === index ? 1.0 : (userMouse.containsMouse ? 0.7 : 0.45)
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 18
          font.letterSpacing: 1
        }

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: userLabel.bottom
          anchors.topMargin: 3
          width: Math.min(userLabel.implicitWidth, userLabel.width)
          height: 2
          radius: 1
          color: "#ffffff"
          opacity: 0.5
          visible: userList.currentIndex === index
        }

        MouseArea {
          id: userMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (userItem.userName.length > 0 && userItem.userName !== root.currentUser) {
              root.currentUser = userItem.userName
              root.loginFailed = false
              password.text = ""
              userList.currentIndex = index
            }
            password.forceActiveFocus()
          }
        }
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 15

      Image {
        source: root.loginFailed ? "lock-failed.png" : "lock.png"
        width: 34
        height: 38
        fillMode: Image.PreserveAspectFit
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: entry.width
        height: entry.height

        Image {
          id: entry
          source: root.loginFailed ? "entry-failed.png" : "entry.png"
          anchors.centerIn: parent
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: 20
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Repeater {
            model: Math.min(password.text.length, 21)

            Image {
              source: "bullet.png"
              width: 7
              height: 7
            }
          }
        }

        TextInput {
          id: password
          anchors.fill: parent
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 24
          font.letterSpacing: 5
          passwordCharacter: "\u2022"
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          cursorDelegate: Item {}
          focus: true

          onTextChanged: root.loginFailed = false

          Keys.onPressed: {
            if (event.key === Qt.Key_Up) {
              root.selectRelativeUser(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_Down) {
              root.selectRelativeUser(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (root.currentUser.length > 0)
                sddm.login(root.currentUser, password.text, root.sessionIndex)
              event.accepted = true
            }
          }
        }
      }
    }
  }

  Component.onCompleted: {
    if (userList.count > 0) {
      if (userList.currentIndex < 0)
        userList.currentIndex = 0
      userList.positionViewAtIndex(userList.currentIndex, ListView.Contain)
    }
    root.setUserFromItem()
    password.forceActiveFocus()
  }
}
