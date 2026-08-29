import QtQuick
// Aliased, the way NumberField.qml aliases it: QtQuick.Controls exports its
// own Button and ButtonGroup, and an unaligned import puts two different
// types behind each of those names. Controls' ButtonGroup is a non-visual
// grouping object, so picking the wrong one loses the unit row entirely and
// says nothing in the log.
import QtQuick.Controls as QQC
import Qt.labs.folderlistmodel
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Ipsum.js" as Ipsum

// Bar icon with a pulldown — the Tiny Ipsum shape, one surface reached from
// the bar rather than a widget and a full-screen overlay.
//
// Everything the panel needs is here: pick a variant, pick a unit, set a
// count, read exactly the text that will be copied, roll a different sample,
// and copy it — at which point the panel closes and a toast says what landed.
Panel {
  id: root
  moduleName: "cschaba.omaipsum"
  ipcTarget: "cschaba.omaipsum.widget"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // The bar sizes a slot from its widget's implicit size — a root that does
  // not publish one gets a 0x0 slot and renders nothing at all, silently: no
  // icon, no gap, no error in the log. These two lines are the widget.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // --- corpora --------------------------------------------------------------
  //
  // corpora/ is discovered rather than listed, which is the promise its README
  // makes: a fourth variant is a fourth file and nothing else. The directory
  // sits beside this file, and a plugin runs from wherever the user symlinked
  // it, so the path has to come from the component's own URL.

  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")

  property var corpora: []
  property var failedFiles: []

  // Reading is finished when every file the scan found has either parsed or
  // failed. Until then the panel says so, rather than showing an empty picker
  // for the fraction of a second before the reads land.
  readonly property bool scanned: corpusFiles.status === FolderListModel.Ready
  readonly property bool loading: !scanned || (corpora.length + failedFiles.length) < corpusFiles.count
  readonly property bool hasCorpora: corpora.length > 0

  FolderListModel {
    id: corpusFiles
    folder: Qt.resolvedUrl("corpora")
    nameFilters: ["*.json"]
    showDirs: false
    // Sorted here and sorted again by name once parsed. Directory order is
    // whatever the filesystem hands back, which differs between machines and
    // between runs on one machine, and a picker whose entries move is worse
    // than a picker in an order nobody asked for.
    sortField: FolderListModel.Name
  }

  // One reader per file. Instantiator rather than Repeater, because a FileView
  // is not an Item and a Repeater will not build one.
  Instantiator {
    model: corpusFiles

    delegate: FileView {
      required property string fileName
      required property string filePath

      path: filePath
      // The panel reports its own failures; an error in the shell's journal
      // helps nobody who is looking at an empty variant list.
      printErrors: false
      onLoaded: root.acceptCorpus(fileName, text())
      onLoadFailed: root.rejectCorpus(fileName)
    }
  }

  function acceptCorpus(fileName, raw) {
    var corpus = null
    try {
      corpus = JSON.parse(raw)
    } catch (e) {
      corpus = null
    }

    // A corpus with no words makes generate() throw, so an empty one is a
    // failed file rather than a variant that produces nothing.
    if (!corpus || !corpus.id || !corpus.name || !corpus.words || !corpus.words.length) {
      root.rejectCorpus(fileName)
      return
    }

    var next = root.corpora.slice(0)
    // FileView can emit loaded more than once for the same file during
    // startup, and a variant listed twice is exactly how that shows up.
    // Identity is the id, which the schema pins to the filename stem.
    for (var i = 0; i < next.length; i++)
      if (next[i].id === corpus.id)
        return

    next.push(corpus)
    next.sort(function (a, b) {
      var an = String(a.name).toLowerCase()
      var bn = String(b.name).toLowerCase()
      if (an !== bn)
        return an < bn ? -1 : 1
      return String(a.id) < String(b.id) ? -1 : 1
    })
    root.corpora = next

    // Until the user picks for themselves the selection follows the list, so
    // the default is the first variant alphabetically however the reads
    // happened to finish. Without this it would be whichever file the disk
    // returned first, which is not the same variant twice running.
    if (!root.variantChosen)
      root.variantId = root.corpora[0].id
  }

  function rejectCorpus(fileName) {
    var next = root.failedFiles.slice(0)
    if (next.indexOf(fileName) >= 0)
      return
    next.push(fileName)
    next.sort()
    root.failedFiles = next
  }

  // --- what gets generated --------------------------------------------------

  property string variantId: ""
  property bool variantChosen: false
  property string unit: Ipsum.UNITS[0]
  property int count: 40

  readonly property var currentCorpus: {
    for (var i = 0; i < root.corpora.length; i++)
      if (root.corpora[i].id === root.variantId)
        return root.corpora[i]
    return root.corpora.length > 0 ? root.corpora[0] : null
  }

  readonly property string currentBlurb: currentCorpus && currentCorpus.blurb ? String(currentCorpus.blurb) : ""

  readonly property var variantOptions: {
    var out = []
    for (var i = 0; i < root.corpora.length; i++)
      out.push({
        "value": String(root.corpora[i].id),
        "label": String(root.corpora[i].name)
      })
    return out
  }

  readonly property var unitOptions: {
    var out = []
    for (var i = 0; i < Ipsum.UNITS.length; i++) {
      var name = Ipsum.UNITS[i]
      out.push({
        "value": name,
        "label": name.charAt(0).toUpperCase() + name.substring(1)
      })
    }
    return out
  }

  readonly property int unitIndex: Math.max(0, Ipsum.UNITS.indexOf(root.unit))

  // Upper bounds per unit, and they are not one number because the units are
  // not one size. 500 words is about a page. A sentence averages ten words
  // and a paragraph four or five sentences, so 100 sentences and 40 paragraphs
  // both come out near two thousand words — already past what anyone pastes as
  // placeholder text, and well past what the preview is any use for.
  readonly property int maxCount: root.unit === "words" ? 500 : (root.unit === "sentences" ? 100 : 40)

  // Words move in fives, because the useful range is ten to a few hundred and
  // crossing it one keystroke at a time is not a control anyone uses twice.
  // Sentences and paragraphs are small numbers where every value matters.
  readonly property int countStep: root.unit === "words" ? 5 : 1

  // The sample is a function of the settings and this number, and rolling it
  // is all Regenerate does. It is a property rather than a Math.random() in
  // the preview binding because that binding re-evaluates whenever anything
  // it reads changes — the text would reshuffle under the cursor.
  property int seed: 1

  function rollSeed() {
    // Imperative, so it happens once per call. Never in a binding.
    root.seed = 1 + Math.floor(Math.random() * 2147483646)
  }

  function setCount(value) {
    var next = Math.round(Number(value))
    if (!isFinite(next))
      next = 1
    next = Math.max(1, Math.min(root.maxCount, next))
    root.count = next
    // NumberField's SpinBox loses its `value: root.value` binding the first
    // time the user edits the field, so the clamped number has to be pushed
    // back rather than left to a binding that may no longer be there.
    if (countField.field.value !== next)
      countField.field.value = next
  }

  function setUnit(name) {
    if (Ipsum.UNITS.indexOf(name) === -1)
      return
    root.unit = name
    // maxCount moved with the unit: 400 words is fine, 400 paragraphs is not.
    root.setCount(root.count)
  }

  function stepUnit(delta) {
    var next = root.unitIndex + delta
    if (next < 0 || next >= Ipsum.UNITS.length)
      return
    root.setUnit(Ipsum.UNITS[next])
  }

  // Exactly the string that goes on the clipboard, and exactly what the
  // preview shows — one expression, so the two cannot disagree.
  readonly property string previewText: {
    var corpus = root.currentCorpus
    if (!corpus)
      return ""
    try {
      return Ipsum.generate(corpus, root.unit, root.count, Ipsum.makeRng(String(root.seed)))
    } catch (e) {
      return ""
    }
  }

  readonly property int previewWords: Ipsum.countWords(root.previewText)

  // --- clipboard ------------------------------------------------------------
  //
  // wl-clipboard is a runtime dependency of this widget: without wl-copy the
  // panel can generate text all day and never hand any of it over. Both
  // processes hang off root rather than off the panel content, because copying
  // closes the panel — a Process living inside it would be racing the surface
  // it was started from.

  // "checking" until the startup probe answers, so the first frames do not
  // accuse the user of a missing package. Only ever leaves that state here and
  // in copyProc's failure path.
  property string clipboardCheck: "checking"

  readonly property bool clipboardMissing: root.clipboardCheck === "missing"

  // The startup requirements check. `wl-copy --version` prints and exits
  // without opening the display or claiming a selection, so this costs one
  // exec and cannot clobber what the user already had on the clipboard.
  Process {
    id: clipboardProbe
    command: ["wl-copy", "--version"]
    running: true

    onExited: function (exitCode) {
      root.clipboardCheck = exitCode === 0 ? "present" : "missing"
    }

    // Quickshell emits neither started nor exited for a binary that is not on
    // PATH — running simply falls back to false and a warning goes to the
    // journal — so a missing wl-copy is the *absence* of an exit, and the only
    // way to read it is to start out pessimistic and be talked out of it.
    onRunningChanged: {
      if (!clipboardProbe.running && root.clipboardCheck === "checking")
        root.clipboardCheck = "missing"
    }
  }

  Process {
    id: copyProc

    // Held from the request until the child is up. Non-empty also means a copy
    // is in flight, which is what tells onRunningChanged below that a run
    // ended without ever reaching onStarted.
    property string pendingText: ""
    // Captured with the text: the panel is gone by the time the toast is sent,
    // and reopening it re-rolls the seed, so neither can be read back then.
    property string headline: ""
    property string detail: ""

    // Piped, never argv. The text is arbitrary and runs to thousands of words,
    // which is both past what ARG_MAX promises and a place where the blank
    // lines between paragraphs stop surviving intact.
    command: ["wl-copy", "--type", "text/plain"]
    stdinEnabled: true

    // The pipe does not exist before the child is up. Closing stdin afterwards
    // is the EOF that makes wl-copy stop reading and fork — left open, it waits
    // there forever and nothing reaches the clipboard.
    onStarted: {
      copyProc.write(copyProc.pendingText)
      copyProc.pendingText = ""
      copyProc.stdinEnabled = false
      // Closing here rather than in copyCurrent(): the pulldown disappearing is
      // the first acknowledgement the user gets, so it has to mean the child is
      // actually up and holding the text. The Process is a child of root, not
      // of the panel, so nothing is torn down underneath this write.
      root.close()
    }

    onExited: function (exitCode) {
      if (exitCode === 0) {
        root.notify(copyProc.headline, copyProc.detail, "low")
        return
      }
      // The panel closed on start, so there is no longer anywhere on screen to
      // put this. Silence would be the worst outcome the widget has — the user
      // pastes whatever was on the clipboard before and finds out much later —
      // so a failure that got this far goes out as a critical toast.
      root.notify("Nothing was copied", "wl-copy exited with " + exitCode, "critical")
    }

    onRunningChanged: {
      if (copyProc.running || !copyProc.pendingText)
        return
      // Never started: wl-copy is not installed. The panel is still open,
      // because the close lives in onStarted, so the message can go where the
      // user is already looking rather than into a toast behind their back.
      copyProc.pendingText = ""
      root.clipboardCheck = "missing"
    }
  }

  Process {
    id: notifyProc
  }

  // A Process rather than Util.execArgv: detaching is not needed here, and
  // execArgv would put a bash between the widget and the only two binaries it
  // is meant to run.
  function notify(headline, detail, urgency) {
    var args = ["omarchy-notification-send", "--app-name", "omaipsum", "-g", "󰈙", "-u", urgency, headline]
    // The description is optional and the parser reads the next positional as
    // one, so an empty string would show as a blank second line.
    if (detail)
      args.push(detail)
    notifyProc.command = args
    notifyProc.running = true
  }

  // "3 paragraphs of Bacon copied" — the amount and the variant are exactly
  // what the user can no longer check once the panel has closed.
  function copySummary() {
    var noun = root.count === 1 ? root.unit.replace(/s$/, "") : root.unit
    var name = root.currentCorpus ? String(root.currentCorpus.name) : "lorem ipsum"
    return root.count + " " + noun + " of " + name + " copied"
  }

  // The one place the clipboard is touched: the Copy button and the ⏎ hint both
  // land here. Closing on copy is the Tiny Ipsum behaviour and the default —
  // see onStarted for why it happens there and not on this line.
  function copyCurrent() {
    if (!root.previewText)
      return
    // A second ⏎ arriving before the first handover would swap the text out
    // from under onStarted.
    if (copyProc.pendingText)
      return

    copyProc.pendingText = root.previewText
    copyProc.headline = root.copySummary()
    // Redundant for the words unit, where the headline already carries the
    // number; useful for the other two, where nobody can count a paragraph.
    copyProc.detail = root.unit === "words" ? "" : root.previewWords + (root.previewWords === 1 ? " word" : " words")
    // onStarted turns this off after writing and it stays off, so every run has
    // to arm it again or the second copy gets no pipe at all.
    copyProc.stdinEnabled = true
    copyProc.running = true
  }

  // --- keyboard cursor ------------------------------------------------------
  //
  // The kit's panel-cursor recipe, from plugins/panels/audio: the root owns
  // cursorActive + focusSection + selectedIndex, every control binds hasCursor
  // off them, and hover writes the same state so mouse and keyboard never
  // disagree. Nothing is highlighted until one of them arrives.
  //
  // Every section here is a single cursor target except the action row, so
  // j/k is only ever "next section" and the walk-within-a-section logic the
  // audio panel needs collapses to one index step.

  property bool cursorActive: false
  property string focusSection: "variant"
  property int selectedIndex: 0

  // Set by PanelKeyCatcher's returnRequested, cleared by the
  // activateRequested that follows it for the same key. See the handler.
  property bool pendingReturn: false

  readonly property var sections: ["variant", "unit", "count", "actions"]

  function sectionCount(section) {
    return section === "actions" ? 2 : 1
  }

  function moveCursor(delta) {
    var i = root.sections.indexOf(root.focusSection)
    if (i < 0) {
      root.focusSection = root.sections[0]
      root.selectedIndex = 0
      return
    }
    var next = i + delta
    if (next < 0 || next >= root.sections.length)
      return
    root.focusSection = root.sections[next]
    root.selectedIndex = 0
  }

  // h/l changes a value where there is one, and walks where there is not. On
  // the unit row the chips switch under the cursor rather than needing a
  // second keystroke to commit: a three-way radio is the one control where
  // "move, then activate" is pure ceremony.
  function moveCursorH(delta) {
    if (root.focusSection === "unit") {
      root.stepUnit(delta)
      return
    }
    if (root.focusSection === "count") {
      root.setCount(root.count + delta * root.countStep)
      return
    }
    if (root.focusSection === "actions") {
      var next = root.selectedIndex + delta
      root.selectedIndex = Math.max(0, Math.min(root.sectionCount("actions") - 1, next))
    }
  }

  function activateCursor() {
    if (root.focusSection === "variant") {
      variantPicker.toggle()
      return
    }
    if (root.focusSection === "count") {
      // Space hands the field the keyboard, so a three-digit count is three
      // keystrokes instead of a hundred. Esc gives it back — see keyScope.
      countField.field.forceActiveFocus()
      return
    }
    if (root.focusSection === "actions") {
      if (root.selectedIndex === 0)
        root.rollSeed()
      else
        root.copyCurrent()
    }
    // "unit": h/l already committed the choice, so Space on that row does
    // nothing rather than offering a second way to pick what is picked.
  }

  function setCursor(section, index) {
    root.cursorActive = true
    root.focusSection = section
    root.selectedIndex = index
  }

  function scrollPreview(dy) {
    var flick = previewScroll.contentItem
    if (!flick)
      return
    var limit = Math.max(0, flick.contentHeight - flick.height)
    flick.contentY = Math.max(0, Math.min(limit, flick.contentY + dy))
  }

  // A fresh sample every time the panel opens: the tool exists to hand you a
  // different chunk of text, so reopening it on last time's would be the wrong
  // default. The cursor starts hidden, as it does in every first-party panel.
  onOpenedChanged: {
    if (!opened)
      return
    root.rollSeed()
    root.cursorActive = false
    root.focusSection = "variant"
    root.selectedIndex = 0
    root.pendingReturn = false
  }

  // --- bar button -----------------------------------------------------------

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // A Nerd Font glyph in `text`, the way every first-party bar widget draws
    // its icon; nf-md-file_document, the same one Omarchy uses for a document.
    text: "󰈙"
    tooltipText: "Lorem ipsum"
    onPressed: root.toggle()
  }

  // --- pulldown -------------------------------------------------------------

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    // Wrapper for the keys PanelKeyCatcher does not claim. An unaccepted key
    // leaves the catcher and propagates to its parent, so Page Up/Down and the
    // way back out of the count field live here rather than overriding the
    // catcher's own Keys handler — which is how the dev gallery does it.
    Item {
      id: keyScope
      anchors.fill: parent

      Keys.priority: Keys.AfterItem
      Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape && countField.field.activeFocus) {
          keyCatcher.forceActiveFocus()
          event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
          root.scrollPreview(previewBox.height * 0.8)
          event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          root.scrollPreview(-previewBox.height * 0.8)
          event.accepted = true
        }
      }

      PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent

        // While the variant list is up it owns j/k and Enter, and while the
        // count field is focused it owns the digits. Either would otherwise be
        // read twice — once by the control and once as panel navigation.
        blocked: variantPicker.popupOpen || countField.field.activeFocus

        onMoveRequested: function (dx, dy) {
          // The first movement only reveals the cursor. Landing on a control
          // and changing it in the same keystroke is how people alter a
          // setting they never saw highlighted.
          if (!root.cursorActive) {
            root.cursorActive = true
            return
          }
          if (dy !== 0)
            root.moveCursor(dy)
          else if (dx !== 0)
            root.moveCursorH(dx)
        }
        onReturnRequested: root.pendingReturn = true
        onActivateRequested: {
          // PanelKeyCatcher emits returnRequested and then activateRequested
          // for the same Return, and only activateRequested for Space. Noting
          // the Return is what lets ⏎ mean copy from anywhere while Space
          // still works the control under the cursor — otherwise ⏎ did both.
          if (root.pendingReturn) {
            root.pendingReturn = false
            root.copyCurrent()
            return
          }
          if (root.cursorActive)
            root.activateCursor()
        }
        onCloseRequested: root.close()
        onTextKey: function (t) {
          if (t === "r" || t === "R")
            root.rollSeed()
        }

        Column {
          id: column
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: Style.spacing.lg

          // --- loading and failure ------------------------------------------

          Text {
            width: parent.width
            visible: root.loading && !root.hasCorpora
            text: "Reading text variants…"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            width: parent.width
            visible: !root.loading && !root.hasCorpora
            spacing: Style.spacing.sm

            Text {
              width: parent.width
              text: root.failedFiles.length > 0 ? "None of the text variants could be read" : "No text variants installed"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              // Name the directory, because the fix is always a file in it.
              text: root.failedFiles.length > 0 ? root.failedFiles.join(", ") + " in " + root.pluginDir + "corpora/" : "Expected one JSON file per variant in " + root.pluginDir + "corpora/"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WrapAnywhere
            }
          }

          // --- variant ------------------------------------------------------

          Dropdown {
            id: variantPicker
            width: parent.width
            visible: root.hasCorpora
            label: "Variant"
            options: root.variantOptions
            value: root.variantId
            foreground: root.foreground
            accent: Color.accent
            fontFamily: root.fontFamily
            hasCursor: root.cursorActive && root.focusSection === "variant"
            onChanged: function (value) {
              root.variantId = value
              root.variantChosen = true
              root.setCursor("variant", 0)
            }
            onHovered: function (isHovered) {
              if (isHovered)
                root.setCursor("variant", 0)
            }
          }

          // The blurb as a line rather than a tooltip: it is the only thing
          // that says what a variant sounds like before you generate it, and a
          // tooltip would hide that from the keyboard entirely.
          Text {
            width: parent.width
            visible: root.hasCorpora && root.currentBlurb !== ""
            text: root.currentBlurb
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          // A partial failure still gets a working picker — one unreadable
          // file should not cost you the other variants — but it says so.
          Text {
            width: parent.width
            visible: root.hasCorpora && root.failedFiles.length > 0
            text: "Couldn’t read " + root.failedFiles.join(", ")
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          // --- how much -----------------------------------------------------

          Row {
            width: parent.width
            visible: root.hasCorpora
            spacing: Style.spacing.controlGap

            NumberField {
              id: countField
              anchors.verticalCenter: parent.verticalCenter
              from: 1
              to: root.maxCount
              stepSize: root.countStep
              value: root.count
              fieldWidth: Style.space(78)
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              hasCursor: root.cursorActive && root.focusSection === "count"
              onModified: function (value) {
                root.setCount(value)
              }
              onHovered: function (on) {
                if (on)
                  root.setCursor("count", 0)
              }
            }

            ButtonGroup {
              id: unitPicker
              anchors.verticalCenter: parent.verticalCenter
              options: root.unitOptions
              value: root.unit
              // Never a Tab stop: this panel drives its own cursor, and a
              // second focus model on the same row would fight it.
              focusable: false
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              cursorIndex: (root.cursorActive && root.focusSection === "unit") ? root.unitIndex : -1
              onChanged: function (value) {
                root.setUnit(value)
                root.setCursor("unit", 0)
              }
              onHovered: function (index, isHovered) {
                if (isHovered)
                  root.setCursor("unit", 0)
              }
            }
          }

          // --- preview ------------------------------------------------------

          Item {
            width: parent.width
            visible: root.hasCorpora
            height: previewHeader.implicitHeight

            PanelSectionHeader {
              id: previewHeader
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "PREVIEW"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              anchors.right: parent.right
              anchors.baseline: previewHeader.baseline
              text: root.previewWords + (root.previewWords === 1 ? " word" : " words")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          BorderSurface {
            id: previewBox
            width: parent.width
            visible: root.hasCorpora
            // Deliberately a fixed height. The panel hangs off a bar icon, so
            // a preview that grew with the count would shove every control
            // below it while the user is still holding the key that changed
            // it. Overflow scrolls; nothing moves.
            height: Style.space(150)
            radius: Style.cornerRadius
            padding: Style.spacing.controlPaddingY
            color: Style.normalFillFor(root.foreground, Color.accent)
            borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

            QQC.ScrollView {
              id: previewScroll
              anchors.fill: parent
              anchors.topMargin: previewBox.contentTopInset
              anchors.bottomMargin: previewBox.contentBottomInset
              anchors.leftMargin: previewBox.contentLeftInset
              anchors.rightMargin: previewBox.contentRightInset
              clip: true
              QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff

              Text {
                // Width pinned to the box, not to availableWidth: a scrollbar
                // appearing would narrow the text, which makes it taller,
                // which keeps the scrollbar — a binding loop.
                width: previewBox.width - previewBox.contentLeftInset - previewBox.contentRightInset
                text: root.previewText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }
            }
          }

          PanelSeparator {
            width: parent.width
            visible: root.hasCorpora
            foreground: root.foreground
          }

          // The runtime dependency, said out loud next to the button that needs
          // it — set by the startup probe, and again by a copy that never
          // started. Copy stays enabled underneath: this is a stale answer the
          // moment the user installs the package, and the copy path re-tests it
          // anyway.
          Text {
            width: parent.width
            visible: root.hasCorpora && root.clipboardMissing
            text: "wl-copy not found — install wl-clipboard to copy"
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          // --- actions ------------------------------------------------------

          Item {
            width: parent.width
            visible: root.hasCorpora
            height: Math.max(actionRow.implicitHeight, hintLabel.implicitHeight)

            // The shell has no hints component — omapass's ActionHints lives
            // in omapass — and one line of Text does not justify a new type.
            Text {
              id: hintLabel
              anchors.left: parent.left
              anchors.right: actionRow.left
              anchors.rightMargin: Style.spacing.controlGap
              anchors.verticalCenter: parent.verticalCenter
              text: "j/k move · h/l change · space pick · r new sample · ⏎ copy · esc close"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Row {
              id: actionRow
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.controlGap

              Button {
                text: "Regenerate"
                bordered: true
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                hasCursor: root.cursorActive && root.focusSection === "actions" && root.selectedIndex === 0
                onClicked: {
                  root.setCursor("actions", 0)
                  root.rollSeed()
                }
                onHovered: function (isHovered) {
                  if (isHovered)
                    root.setCursor("actions", 0)
                }
              }

              Button {
                text: "Copy"
                bordered: true
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                hasCursor: root.cursorActive && root.focusSection === "actions" && root.selectedIndex === 1
                onClicked: {
                  root.setCursor("actions", 1)
                  root.copyCurrent()
                }
                onHovered: function (isHovered) {
                  if (isHovered)
                    root.setCursor("actions", 1)
                }
              }
            }
          }
        }
      }
    }
  }
}
