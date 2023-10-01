import QtQuick 2.2
import QtQuick.Dialogs 1.0
import QtQuick.Controls 2.0
import MuseScore 3.0
import FileIO 3.0

MuseScore {
    menuPath: "Plugins.ExportNumbersNLetters"
    description: "Description goes here"
    version: "1.0"
    requiresScore: true
    pluginType: "dialog"
    id: window
    width: 800
    height: 600

    property string outputNumbers
    property string outputLetters
    property var output
    property string letterMappingFilePath : "mappings/letters_mapping_default_de.json"
    property var lettersMapping
    property string numberMappingFilePath : "mappings/numbers_mapping_default.json"
    property var numbersMapping

    QProcess {
        id: proc
    }

    onRun: {
        checkEnvironment()
        processMappings()
        processPreview()
    }
    function checkEnvironment() {
    }
    function showObject(oObject) {
        //  PURPOSE: Lists all key -> value pairs to the console.
        //  NOTE: To reduce clutter I am filtering out any 
        //'undefined' properties. (The MuseScore 'element' object
        //is very flat - it will show many, many properties for any
        //given element type; but for any given element many, if not 
        //most of these properties will return 'undefined' as they 
        //are not all valid for all element types. If you want to see 
        //this comment out the filter.)
        
        if (Object.keys(oObject).length >0) {
            Object.keys(oObject)
            .filter(function(key) {
                return oObject[key] != null;
            })
            .sort()
            .forEach(function eachKey(key) {
                console.log("---- ---- ", key, " : <", oObject[key], ">");
            });
        }
    }

    function stringRepeat(s,c) {
        var str = ""
        for (var i=0; i<c; i++) {
            str += s
        }
        return str
    }

    function oPart(partname) {
        this.name = partname
        this.data = []
        this.getOutput = function(format) {
            var oL = ""
            var oN = ""
            this.data.sort(function(a,b) {
                var dif = a.nind-b.nind
                if (dif!=0) {
                    return dif
              } 
                if (b.type=="layout_break") {
                    return 1
                }
                return -1
            })

            // normalize consecutive rests
            for (var j=0; j<this.data.length-1; j++) {
                if (this.data[j].type == "rest" && this.data[j+1].type == "rest") {
                    this.data[j].duration += this.data[j+1].duration
                    this.data.splice(j+1,1)
                }
            }
            if (this.data.length>0 && this.data[0].type == "rest") {
                this.data.splice(0,1)
            }

            // TODO: also eliminate spaces at line beginnings in general
            if (this.name.length>0) {
                switch (format) {
                    case "txt":
                        oL += this.name+"\n"
                        oN += this.name+"\n"
                        break
                    case "html":
                    case "docx":
                    case "pdf":
                        oL += "<h2>"+this.name+"</h2>\n"
                        oN += "<h2>"+this.name+"</h2>\n"
                        break
                    case "md":
                        oL += "## "+this.name+"\n"
                        oN += "## "+this.name+"\n"
                        break
                    default:
                        console.log("using default part naming")
                        break
                }
            } else {
            }

            var minDist = 1000
            var maxDist = 0
            for (var j=1; j<this.data.length; j++) {
                if (this.data[j].type=="note") {
                    var dist = -1
                    for (var k=j-1; k>=0; k--) {
                        if (this.data[k].type == "note") {
                            dist = this.data[j].nind-this.data[k].nind
                            break
                        }
                    }
                    if (dist>0) {
                        minDist = Math.min(minDist, dist)
                        maxDist = Math.max(maxDist, dist)
                    }
                }
            }
            var minDist_l = Math.log(minDist)
            var maxDist_l = Math.log(maxDist)

            var rowInd = 0
            for (var j=0; j<this.data.length; j++) {
                if (this.data[j].type=="note") {
                    if (rowInd>0) {
                        var dist = 0
                        for (var k=j-1; k>=0; k--) {
                            if (this.data[k].type == "note") {
                                dist = this.data[j].nind-this.data[k].nind
                                break
                            }
                        }
                        var spaces = 0
                        if (!spacingMethod.checked) {
                            var spaces = Math.floor(dist*scalingSlider.value*3)
                        } else {
                            var dist_l = Math.log(dist)
                            if (maxDist_l-minDist_l==0) {
                                spaces = Math.floor(dist)
                            } else if (maxDist<=1.5) {
                                spaces = Math.floor((dist_l-minDist_l)/(maxDist_l-minDist_l)*scalingSlider.value*maxDist*2)
                            } else {
                                spaces = Math.floor((dist_l-minDist_l)/(maxDist_l-minDist_l)*scalingSlider.value*12)
                            }
                        }
                        var spaceVal = " "
                        switch(format) {
                            case "html":
                            case "docx":
                            case "pdf":
                                spaceVal = "&nbsp;"
                                break
                            default:
                                spaceVal = " "
                        }
                        oL += stringRepeat(spaceVal, spaces)
                        oN += stringRepeat(spaceVal, spaces)
                    }

                    var no = this.data[j].getOutput(format)
                    oL += no.letters
                    oN += no.numbers
                } else if (this.data[j].type=="layout_break") {
                    if (layoutBreakCheckBox.checked) {
                        switch(format)  {
                            case "html":
                            case "docx":
                            case "pdf":
                                oL += "<br />"
                                oN += "<br />"
                                break
                            default:
                                oL += "\n"
                                oN += "\n"
                        }
                        rowInd = -1
                    }
                } else {
                    console.log("different type "+this.data[j].type)
                }
                rowInd++
            }
            switch(format)  {
                case "html":
                case "docx":
                case "pdf":
                    break
                default:
                    if (this.data.length>0) {
                        oL += "\n"
                        oN += "\n"
                    }
            }
            return {
                letters: oL,
                numbers: oN
            }
        }
    }

    function processHelper(score, staff) {
        this.parts = []
        this.score = score
        this.staff = staff
        this.newPart = function(partname) {
            var p = new oPart(partname)
            this.parts.push(p)
        },
        this.checkPart = function() {
            if (this.parts.length==0) {
                this.parts.push(new oPart("")) // TODO: is tihs handled everywhere?
            }
        }
        this.newNote = function(nind, tpitch, dur, sharps) {
            this.checkPart()
            this.parts[this.parts.length-1].data.push({
                nind: nind,
                type: "note",
                pitch: tpitch,
                duration: dur,
                sharps: sharps,
                getOutput: function(format) {
                    switch(format) {
                        case "html-docx_maybe":
                            return {
                                letters: (sharps?lettersMapping[this.pitch].sharp.txt:lettersMapping[this.pitch].flat.txt) + "&nbsp;",
                                numbers: numbersMapping[this.pitch].txt + "&nbsp;"
                            }
                            break
                        case "html":
                        case "docx":
                        case "pdf":
                            return {
                                letters: (sharps?lettersMapping[this.pitch].sharp.html:lettersMapping[this.pitch].flat.html) + "&nbsp;",
                                numbers: numbersMapping[this.pitch].html + "&nbsp;"
                            }
                            break
                        default:
                            return {
                                letters: (sharps?lettersMapping[this.pitch].sharp.txt:lettersMapping[this.pitch].flat.txt) + " ",
                                numbers: numbersMapping[this.pitch].txt + " "
                            }
                    }
                }
            })
        },
        this.newRest = function(nind,dur) {
            return
            this.checkPart()
            
            this.parts[this.parts.length-1].data.push({
                nind: nind,
                type: "rest",
                duration: dur
            })
        },
        this.lastLayoutInfoNind = -1,
        this.newLayoutBreak = function(nind) {
            if (nind<=this.lastLayoutInfoNind) {
                return
            }
            this.lastLayoutInfoNind = nind
            this.checkPart()
            this.parts[this.parts.length-1].data.push({
                nind: nind,
                type: "layout_break"
            })
        },

        this.getOutput = function(format) {
            if (format == undefined) {
                format = "txt"
            }
            var oL = ""
            var oN = ""
            
            switch (format) {
                case "txt":
                    oL += this.score.title+" - "+this.staff.part.instruments[0].longName + "\n"
                    oN += this.score.title+" - "+this.staff.part.instruments[0].longName + "\n"
                    break;
                case "html":
                case "docx":
                case "pdf":
                    oL += "<h1 style='text-align: center;'>"+this.score.title+"</h1>\n<h3 style='text-align: right;'>"+this.staff.part.instruments[0].longName+"</h3>"
                    oN += "<h1 style='text-align: center;'>"+this.score.title+"</h1>\n<h3 style='text-align: right;'>"+this.staff.part.instruments[0].longName+"</h3>"
                    oL += "<style>* {margin: 0px; padding: 0px} html { background-color: #DDDDDD; } body {max-width: 21cm; padding: 2cm; margin: auto; background-color: white; font-family: Arial, Helvetica, sans-serif; } h2 { margin-top: 0.6cm } </style>"
                    oN += "<style>* {margin: 0px; padding: 0px} html { background-color: #DDDDDD; } body {max-width: 21cm; padding: 2cm; margin: auto; background-color: white; font-family: Arial, Helvetica, sans-serif; } h2 { margin-top: 0.6cm } </style>"
                    break
                case "md":
                    oL += "# "+this.score.title+"\n### "+this.staff.part.instruments[0].longName+"\n"
                    oN += "# "+this.score.title+"\n### "+this.staff.part.instruments[0].longName+"\n"
                    break;
                default:
                    console.log("using default score naming")
                    break
            }

            for (var i=0; i<this.parts.length; i++) {
                var p = this.parts[i]
                var o = p.getOutput(format)
                console.log("part "+p.name+" length "+p.data.length)
                oL += o.letters
                oN += o.numbers
                switch (format) {
                    case "txt":
                    case "md":
                        oL += "\n"
                        oN += "\n"
                        break;
                    case "html":
                    case "docx":
                    case "pdf":
                        //if (p.data.length>0) {
                            oL += "<br />\n"
                            oN += "<br />\n"
                        //}
                        break;
                    default:
                        break
                }
            }

            return {
                letters: oL,
                numbers: oN
            }
        }
    }
    function getStaffFromInd(i) {
        var c = curScore.newCursor()
        c.voice = 0
        c.rewind(0)
        c.staffIdx = i
        return c.element.staff
    }

    function processStaffVoice(staff,voice, format) {

        if (format==undefined) {
            format = "txt"
        }

        var instrumentPitchOffset = 0
        var sss = getStaffFromInd(staff)
        if(sss.part.instruments[0].instrumentId.indexOf("brass.trombone")==0) {
            instrumentPitchOffset = 12
        } else if(sss.part.instruments[0].instrumentId.indexOf("brass.euphonium")==0) {
            instrumentPitchOffset = 12
        } else if(sss.part.instruments[0].instrumentId.indexOf("brass.sousaphone")==0) {
            instrumentPitchOffset = 24
        } else if(sss.part.instruments[0].instrumentId.indexOf("brass.trumpet")==0) {
            instrumentPitchOffset = 0
        } else {
            console.log(sss.part.instruments[0].instrumentId)
        }

        var cur = curScore.newCursor()
        cur.staffIdx = staff
        cur.voice = voice 
        cur.rewind(0)
        
        var score = cur.score
        
        var pH = new processHelper(score, sss)

        
        var  i = 0
        while (cur.segment) {
        
            var nind = cur.segment.tick/division

            var textAnno = {"type":"none"}

            for (var j=0; j<cur.segment.annotations.length; j++) {
                var an = cur.segment.annotations[j]
                console.log("another annotation "+an.type)
                if (an.type==41) { // tempo annotation
                } else if (an.type==42 && sss.is(an.staff)) {
                    //console.log("  staff text "+an.text+" "+an.systemFlag+" "+sss.is(an.staff))
                    textAnno = {"type":"staff","text": an.text}
                } else if (an.type==43) {
                    //console.log("  system text "+an.text+" "+an.systemFlag+" "+sss.is(an.staff))
                    if (textAnno.type=="none") {
                        textAnno = {"type":"system","text": an.text}
                    }
                } else {
                    console.log("  ======> Annotation with type "+an.type+" "+an.userName())
                }
            }
            if (textAnno.type!="none") {
                pH.newPart(textAnno.text)
            }

        
            if (cur.element) {
                if (cur.element.type==Element.CHORD) {
                    /* TODO: handle multiple notes
                    for (var j=0; j<cur.element.notes.length; j++) {
                        var n = cur.element.notes[j]
                        var pitch = n.pitch + instrumentPitchOffset
                        var tpitch = pitch + (n.tpc2-n.tpc1)
                    }
                    */
                    var n = cur.element.notes[0]
                    var pitch = n.pitch + instrumentPitchOffset
                    var tpitch = pitch + (n.tpc2-n.tpc1)
                    if (n.tieBack!==null && n.tieBack.startNote.pitch==n.pitch) {
                    } else {
                        pH.newNote(nind, tpitch, cur.element.actualDuration, useSharps(cur))
                    }
                } else if (cur.element.type==Element.REST) {
                    var duration = cur.element.actualDuration
                    pH.newRest(nind,duration.numerator/duration.denominator)
                } else {
                    console.log("  ======> Other element of type "+cur.element.userName()+")")
                }
            } else {
                console.log("No element")
            }

            var mes = cur.measure.elements
            var m = cur.measure
            for (var j=0; j<mes.length; j++) {
                var me = mes[j]
                if (me.type==Element.LAYOUT_BREAK) {
                    pH.newLayoutBreak(m.lastSegment.tick/division)
                    if (!m.lastSegment) {
                    } else if (m.lastSegment.is(cur.segment)) {
                    } else {
                        var cs = m.firstSegment
                        while (cs!=null) {
                            cs = cs.nextInMeasure
                        }
                    }
                } else {
                    console.log("    =====> Other measure element "+m.name)
                }
            }
            
        
            cur.next()
            
            /*
            i = i+1
            if (i>60) {
                break
            }
            */
        }

        var o = pH.getOutput(format)
        return o
    }
    function getSelectedStaffsOrAllInd() {
        var selectedStaffs = []
        if (curScore.selection.elements.length>0) {
            if (curScore.selection.isRange) {
                for (var i=curScore.selection.startStaff; i<curScore.selection.endStaff; i++) {
                    selectedStaffs.push(i)
                }
            } else {
                var c = curScore.newCursor()
                c.voice = 0
                c.rewind(0)
                for (var i=0; i<curScore.selection.elements.length; i++) {
                    var e = curScore.selection.elements[i]
                    if (e.type==Element.CHORD || e.type==Element.NOTE || e.type==Element.REST) {
                        var selectInd = -1
                        for (var j=0; j<curScore.nstaves; j++) {
                            c.staffIdx = j
                            if (e.staff.is(c.element.staff)) {
                                selectInd = j
                                break
                            }
                        }
                        if (selectedStaffs.indexOf(selectInd)<0) {
                            selectedStaffs.push(selectInd)
                        }
                    }
                }
            }
        }
        if (selectedStaffs.length==0) {
            for (var i=0; i<curScore.nstaves; i++) {
                selectedStaffs.push(i)
            }
        }

        return selectedStaffs
    }
    function processPreview() {
        //console.log("processPreview")
        var selectedStaffs = getSelectedStaffsOrAllInd()
        for (var i=0; i<selectedStaffs.length; i++) {
            var staff = selectedStaffs[i]
            var sss = getStaffFromInd(staff)
        }

        var o = processStaffVoice(selectedStaffs[0], 0)
        outputLetters = o.letters
        outputNumbers = o.numbers
    }

    Control {
        id: mainControl
        width: parent.width
        height: parent.height

        Rectangle {
            id: backgroundRect
            color: "#EEEEEE"
            width: parent.width
            height: parent.height

            Control {
                id: titleRow

                anchors.top: parent.top
                anchors.left: parent.left
                width: parent.width
                height: childrenRect.height

                Label {
                    id: textLabel
                    wrapMode: Text.WordWrap
                    text: qsTr("Preview of current settings on the right")
                    font.pointSize: 12
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                }
            }

            Control {
                id: mainRow
                anchors.top: titleRow.bottom
                height: childrenRect.height

                Control {
                    id: textAreaColumn
                    leftPadding: 4
                    height: childrenRect.height
                    width: childrenRect.width
                    anchors.left: parent.left
                    anchors.leftMargin: 4

                    TextArea {
                        id: previewTextLetters
                        height: 250
                        width: 500
                        wrapMode: TextEdit.WrapAnywhere
                        textFormat: TextEdit.PlainText
                        text: outputLetters

                        background: Rectangle {
                            border.color: "#111111"
                        }
                    }

                    TextArea {
                        id: previewTextNumbers
                        height: 250
                        width: 500
                        wrapMode: TextEdit.WrapAnywhere
                        textFormat: TextEdit.PlainText
                        text: outputNumbers
                        anchors.top: previewTextLetters.bottom
                        anchors.topMargin: 4

                        background: Rectangle {
                            border.color:"#111111"
                        }
                    }
                }
                Control {
                    id: settingsColumn
                    anchors.left: textAreaColumn.right

                    Control {
                        id: sharpOrFlatRow
                        width: childrenRect.width
                        height: childrenRect.height

                        Label {
                            id: sharpOrFlatLabel
                            text: qsTr("Use sharps or flats")
                            anchors.verticalCenter: sharpOrFlatSelectionBox.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                        }
                        ComboBox {
                            id: sharpOrFlatSelectionBox
                            anchors.left: sharpOrFlatLabel.right
                            anchors.leftMargin: 8
                            textRole: "text"
                            currentIndex: 0
                            model: ListModel {
                                id: sharpOrFlatSelection
                                ListElement { text: "auto"; value: "auto" }
                                ListElement { text: qsTr("sharps"); value: "sharp" }
                                ListElement { text: qsTr("flats"); value: "flat" }
                            }
                            width: 90
                            onCurrentIndexChanged: function () {
                                processPreview()
                            }
                        }
                    }

                    Control {
                        id: outputFormatRow
                        anchors.top: sharpOrFlatRow.bottom
                        anchors.topMargin: 8
                        width: childrenRect.width
                        height: childrenRect.height

                        Label {
                            id: outputFormatLabel
                            text: qsTr("Output Format")
                            anchors.verticalCenter: outputFormatSelectionBox.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                        }
                        ComboBox {
                            id: outputFormatSelectionBox
                            anchors.left: outputFormatLabel.right
                            anchors.leftMargin: 8
                            textRole: "text"
                            model: ListModel {
                                id: outputFormatSelection
                                ListElement { text: "docx"; value: "docx" }
                                ListElement { text: "pdf"; value: "pdf"; visible: true }
                                ListElement { text: "txt"; value: "txt" }
                                ListElement { text: "md"; value: "md" }
                                ListElement { text: "html"; value: "html" }
                            }
                            width: 90
                            onCurrentIndexChanged: function () {
                                console.debug("selected "+outputFormatSelection.get(currentIndex).text+" ("+currentIndex+")")
                            }
                        }
                    }

                    Control {
                        id: lettersSuffixRow
                        anchors.top: outputFormatRow.bottom
                        anchors.topMargin: 8
                        width: childrenRect.width
                        height: childrenRect.height

                        Label {
                            id: lettersSuffixLabel
                            text: qsTr("Letters file suffix")
                            anchors.verticalCenter: lettersSuffixRect.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                        }
                        Rectangle {
                            id: lettersSuffixRect
                            anchors.left: lettersSuffixLabel.right
                            anchors.leftMargin: 8
                            color: "white"
                            width: childrenRect.width
                            height: childrenRect.height

                            TextEdit {
                                id: lettersSuffix
                                width: 120
                                text: qsTr("Letters")
                                selectByMouse: true
                            }
                        }
                    }

                    Control {
                        id: numbersSuffixRow
                        anchors.top: lettersSuffixRow.bottom
                        anchors.topMargin: 8
                        width: childrenRect.width
                        height: childrenRect.height

                        Label {
                            id: numbersSuffixLabel
                            text: qsTr("Numbers file suffix")
                            anchors.verticalCenter: numbersSuffixRect.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                        }
                        Rectangle {
                            id: numbersSuffixRect
                            anchors.left: numbersSuffixLabel.right
                            anchors.leftMargin: 8
                            color: "white"
                            width: childrenRect.width
                            height: childrenRect.height

                            TextEdit {
                                id: numbersSuffix
                                width: 120
                                text: qsTr("Numbers")
                                selectByMouse: true
                            }
                        }
                    }

                    Control {
                        id: lettersMappingFileRow
                        anchors.top: numbersSuffixRow.bottom
                        anchors.topMargin: 8
                        width: childrenRect.width
                        height: childrenRect.height

                        Label {
                            id: lettersMappingFileLabel
                            text: qsTr("Letters map file")
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: buttonLettersMappingFile.verticalCenter
                        }
                        
                        Button {
                            id : buttonLettersMappingFile
                            anchors.left: lettersMappingFileLabel.right
                            anchors.leftMargin: 4
                            text: qsTr(letterMappingFilePath.substr(letterMappingFilePath.lastIndexOf("/")+1))
                            onClicked: {
                                console.log("select mapping file")
                                lettersMappingFileDialog.open()
                            }
                        }
                    }

                    Control {
                        id: numbersMappingFileRow
                        anchors.top: lettersMappingFileRow.bottom
                        anchors.topMargin: 8
                        width: childrenRect.width
                        height: childrenRect.height

                        Label {
                            id: numbersMappingFileLabel
                            text: qsTr("Numbers map file")
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: buttonNumbersMappingFile.verticalCenter
                        }
                        
                        Button {
                            id : buttonNumbersMappingFile
                            anchors.left: numbersMappingFileLabel.right
                            anchors.leftMargin: 4
                            text: qsTr(numberMappingFilePath.substr(numberMappingFilePath.lastIndexOf("/")+1))
                            onClicked: {
                                console.log("select mapping file")
                                numbersMappingFileDialog.open()
                            }
                        }
                    }

                    CheckBox {
                        id: layoutBreakCheckBox
                        anchors.top: numbersMappingFileRow.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        checked: true
                        text: qsTr("Layout break creates newline")
                        onCheckedChanged: function () {
                            console.log("check changed")
                            processPreview()
                        }
                    }

                    CheckBox {
                        id: spacingMethod
                        anchors.top: layoutBreakCheckBox.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        checked: true
                        text: qsTr("Use logarithmic spacing method")
                        onCheckedChanged: function () {
                            processPreview()
                        }
                    }

                    Control {
                        anchors.top: spacingMethod.bottom
                        anchors.topMargin: 8
                        width: childrenRect.width
                        height: childrenRect.height

                        Label {
                            id: scalingLabel
                            text: qsTr("Spacing")
                            anchors.verticalCenter: scalingSlider.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                        }

                        Slider {
                            id: scalingSlider
                            anchors.left: scalingLabel.right
                            anchors.leftMargin: 8
                            value: 0.6
                            from: 0
                            to: 1
                            onMoved: function() {
                                processPreview()
                            }
                        }

                        Label {
                            id: scalingSliderLabel
                            text: scalingSlider.value.toFixed(2)
                            anchors.verticalCenter: scalingSlider.verticalCenter
                            anchors.left: scalingSlider.right
                            anchors.leftMargin: 4
                        }
                    }
                }
            }

            Control {
                id: buttonRow
                anchors.top: mainRow.bottom
                anchors.bottom: parent.bottom
                width: parent.width
                height: childrenRect.height

                Button {
                    id : buttonSaveOutput
                    anchors.right: buttonCancel.left
                    anchors.rightMargin: 4
                    text: qsTr("Save Output")
                    onClicked: {
                        console.log("save output")
                        saveFileDialog.open()
                    }
                }

                Button {
                    id : buttonCancel
                    anchors.right: buttonRow.right
                    anchors.rightMargin: 4
                    text: qsTr("Cancel")
                    onClicked: {
                        Qt.quit();
                    }
                }
            }
        }
    }

    function getLocalPath(path) {
        path = path.replace(/^(file:\/{2})/,"")
        if (Qt.platform.os == "windows") path = path.replace(/^\//,"")
        path = decodeURIComponent(path)
        return path
    }

    FileIO {
        id: outputFile
        onError: console.log(msg)
    }
     
    function dirname(p) {
        if (p.indexOf("/")>=0) {
            p = (p.slice(0,p.lastIndexOf("/")+1))
        }
        if (p.indexOf("\\")>=0) {
            p = (p.slice(0,p.lastIndexOf("\\")+1))
        }
        return p
    }
     
    function basename(p) {
        if (p.indexOf("/")>=0) {
            p = (p.slice(p.lastIndexOf("/")+1))
        }
        if (p.indexOf("\\")>=0) {
            p = (p.slice(p.lastIndexOf("\\")+1))
        }
        return p
    }

    function extension(p) {
        return (p.slice(p.lastIndexOf(".")+1))
    }

    function pandocConversion(inp, outp) {
        if (Qt.platform.os=="linux") {
            var cmd = "pandoc -s -o \""+outp+"\" \""+inp+"\" --reference-doc=\""+filePath+"/reference.docx\""
            proc.start(cmd);
            var val = proc.waitForFinished(-1);
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else if (Qt.platform.os=="windows") {
            var cmd = 'Powershell.exe -Command "pandoc -s -o \''+outp+'\' \''+inp+'\' --reference-doc=\''+filePath+'/reference.docx\'"'
            proc.start(cmd);
            var val = proc.waitForFinished(-1);
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else {
            console.log("unknown os ",Qt.platform.os)
        }
    }
    function rmfile(path) {
      if (["linux", "osx"].indexOf(Qt.platform.os)>=0) {
        var cmd = 'rm "'+path+'"'
        proc.start(cmd);
        var val = proc.waitForFinished(-1);
        console.log(cmd)
        console.log(val)
        console.log(proc.readAllStandardOutput())
      } else if (Qt.platform.os=="windows") {
        var cmd = "Powershell.exe -Command \"Remove-Item '"+path+"'\""
        proc.start(cmd);
        var val = proc.waitForFinished(-1);
        console.log(cmd)
        console.log(val)
        console.log(proc.readAllStandardOutput())
      } else {
        console.log("unknown os",Qt.platform.os)
      }
    }

    FileDialog {
        id: saveFileDialog
        title: qsTr("Output destination")
        selectExisting: false
        selectFolder: true
        selectMultiple: false
        folder: shortcuts.home
        onAccepted: {
            var filename = saveFileDialog.fileUrl.toString()
            var generatedFiles = "Generated files:\n\n"
            
            if(filename){

                filename = getLocalPath(filename)
                var destFolder = dirname(filename+"/")

                var score = curScore
                var origPath = score.path
                var cdir = dirname(origPath)
                var cname = basename(origPath)
                cname = cname.slice(0, cname.lastIndexOf('.'))

                var format = outputFormatSelection.get(outputFormatSelectionBox.currentIndex).value
                
                var ext = "txt"
                switch(format) {
                    case "md":
                        ext = "md"
                        break
                    case "html":
                    case "docx":
                    case "pdf":
                        ext = "html"
                        break;
                    case "txt":
                        ext = "txt"
                        break;
                    default:

                }

                var selectedStaffs = getSelectedStaffsOrAllInd()
                for (var i=0; i<selectedStaffs.length; i++) {
                    var staff = selectedStaffs[i]
                    console.log("processing staff "+staff)
                    var sss = getStaffFromInd(staff)
                    if (!sss.part.hasPitchedStaff) {
                        continue
                    }

                    var instrumentName = sss.part.instruments[0].longName
                    instrumentName = instrumentName.replace(" ","_")
                
                    var o = processStaffVoice(staff,0, format)

                    var suff_l = lettersSuffix.text
                    if (suff_l.length<1) {
                        suff_l = qsTr("Letters")
                    }
                    var suff_n = numbersSuffix.text
                    if (suff_n.length<1) {
                        suff_n = qsTr("Numbers")
                    }

                    var lettersfn = cname + "-" + instrumentName + "_" + suff_l
                    var lettersfn_e = destFolder+lettersfn+"."+ext
                    outputFile.source = getLocalPath(lettersfn_e)
                    outputFile.write(o.letters)
                    generatedFiles += lettersfn_e+"\n"
                    if (format=="docx" || format=="pdf"){
                        var lettersfn_f = destFolder+lettersfn+"."+format
                        console.log(destFolder, lettersfn, lettersfn_e, lettersfn_f, cname)
                        pandocConversion(getLocalPath(lettersfn_e),getLocalPath(lettersfn_f))
                        generatedFiles += lettersfn_f+"\n"
                        rmfile(getLocalPath(lettersfn_e));
                    }

                    var numbersfn = cname + "-" + instrumentName + "_" + suff_n
                    var numbersfn_e = destFolder+numbersfn+"."+ext
                    outputFile.source = getLocalPath(numbersfn_e)
                    outputFile.write(o.numbers)
                    generatedFiles += numbersfn_e+"\n"
                    if (format=="docx" || format=="pdf"){
                        var numbersfn_f = destFolder+numbersfn+"."+format
                        pandocConversion(getLocalPath(numbersfn_e),getLocalPath(numbersfn_f))
                        generatedFiles += numbersfn_f+"\n"
                        rmfile(getLocalPath(numbersfn_e));
                    }
        
                }

                outputFile.source = getLocalPath(filename)
                outputFile.write(generatedFiles)
                
                Qt.quit()
            }
            processPreview()
        }
    }

    FileDialog {
        id: numbersMappingFileDialog
        title: qsTr("Numbers Mapping File")
        selectExisting: true
        selectFolder: false
        selectMultiple: false
        folder: shortcuts.home
        onAccepted: {
            var filename = numbersMappingFileDialog.fileUrl.toString()
            
            if(filename){
                filename = getLocalPath(filename)
                console.log("selected "+filename)
                numberMappingFilePath = filename

                processMappings()
                
                processPreview()
            }
        }
    }

    FileDialog {
        id: lettersMappingFileDialog
        title: qsTr("Letters Mapping File")
        selectExisting: true
        selectFolder: false
        selectMultiple: false
        folder: shortcuts.home
        onAccepted: {
            var filename = lettersMappingFileDialog.fileUrl.toString()
            
            if(filename){
                filename = getLocalPath(filename)
                console.log("selected "+filename)
                letterMappingFilePath = filename

                processMappings()
            }
        }
    }

    function processMappings() {
        var xhr = new XMLHttpRequest
        xhr.open("GET", numberMappingFilePath)
        xhr.onreadystatechange = function() {
            if (xhr.readyState == XMLHttpRequest.DONE) {
                numbersMapping = JSON.parse(xhr.responseText)
                console.log("updated numbers mapping")
                processPreview()
            }
        }
        xhr.send()

        var xhr1 = new XMLHttpRequest
        xhr1.open("GET", letterMappingFilePath)
        xhr1.onreadystatechange = function() {
            if (xhr1.readyState == XMLHttpRequest.DONE) {
                lettersMapping = JSON.parse(xhr1.responseText)
                console.log("updated letters mapping")
                processPreview()
            }
        }
        xhr1.send()
    }


        
        
    function numbers(pitch) {
        switch (pitch) {
            case 54: return "1/2/3"
            case 55: return "1/3"
            case 56: return "2/3"
            case 57: return "½"
            case 58: return "1"
            case 59: return "2"
            case 60: return "L"
            case 61: return "1/2/3"
            case 62: return "1/3"
            case 63: return "2/3"
            case 64: return "½"
            case 65: return "1"
            case 66: return "2"
            case 67: return "L"
            case 68: return "2/3"
            case 69: return "½"
            case 70: return "1"
            case 71: return "2"
            case 72: return "L"
            case 73: return "½"
            case 74: return "1"
            case 75: return "2"
            case 76: return "L"
            case 77: return "1"
            case 78: return "2"
            case 79: return "L"
            case 80: return "2/3"
            case 81: return "½"
            case 82: return "1"
            case 83: return "2"
            case 84: return "L"
            default: ""
        }
    }

    function letters(tpitch, cur) {
        if (useSharps(cur)) {
            return lettersSharp(tpitch)
        } else {
            return lettersFlat(tpitch)
        }
    }

    function useSharps(cur) {
        if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="auto") {
            if (cur.keySignature<0) {
                return false
            } else {
                return true
            }
        } else if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="sharp") {
            return true
        } else if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="flat") {
            return false
        }
    }
    
    function lettersSharp(pitch) {
        switch (pitch) {
            case 54: return "Fis"
            case 55: return "G"
            case 56: return "Gis"
            case 57: return "A"
            case 58: return "Ais"
            case 59: return "H"
            case 60: return "C"
            case 61: return "Cis"
            case 62: return "D"
            case 63: return "Dis"
            case 64: return "E"
            case 65: return "F"
            case 66: return "Fis"
            case 67: return "G"
            case 68: return "Gis"
            case 69: return "A"
            case 70: return "Ais"
            case 71: return "H"
            case 72: return "C"
            case 73: return "Cis"
            case 74: return "D"
            case 75: return "Dis"
            case 76: return "E"
            case 77: return "F"
            case 78: return "Fis"
            case 79: return "G"
            case 80: return "Gis"
            case 81: return "A"
            case 82: return "Ais"
            case 83: return "H"
            case 84: return "C"
            default: ""
        }
    }
    
    
    
    function lettersFlat(pitch) {
        switch (pitch) {
            case 54: return "Ges"
            case 55: return "G"
            case 56: return "As"
            case 57: return "A"
            case 58: return "B"
            case 59: return "H"
            case 60: return "C"
            case 61: return "Des"
            case 62: return "D"
            case 63: return "Es"
            case 64: return "E"
            case 65: return "F"
            case 66: return "Ges"
            case 67: return "G"
            case 68: return "As"
            case 69: return "A"
            case 70: return "B"
            case 71: return "H"
            case 72: return "C"
            case 73: return "Des"
            case 74: return "D"
            case 75: return "Es"
            case 76: return "E"
            case 77: return "F"
            case 78: return "Ges"
            case 79: return "G"
            case 80: return "As"
            case 81: return "A"
            case 82: return "B"
            case 83: return "H"
            case 84: return "C"
            default: ""
        }
    }
    
    
    function textdeco(pitch, format, letters) {
        switch(format) {
            case "html":
            case "docx":
            case "pdf":
                if (!letters) {
                    if (pitch <= 59) {
                        return ["<b>","</b>"]
                    } else if (60 <= pitch && pitch <= 66) {
                        return ["<u>","</u>"]
                    } else if (67 <= pitch && pitch <= 71) {
                        return ["",""]
                    } else if (72 <= pitch && pitch <= 75) {
                        return ["","'"]
                    } else if (76 <= pitch && pitch <= 78) {
                        return ["","''"]
                    } else if (79 <= pitch && pitch <= 83) {
                        return ["","'''"]
                    }  else if (84 <= pitch) {
                        return ["","''''"]
                    } else {
                        return ["",""]
                    }
                } else {
                    if (pitch <= 59) {
                        return ["<u>","</u>"]
                    } else if (60 <= pitch && pitch <= 71) {
                        return ["",""]
                    } else if (72 <= pitch && pitch <= 83) {
                        return ["","'"]
                    } else if (84 <= pitch) {
                        return ["","''"]
                    } else {
                        return ["",""]
                    }
                }
                break
            default:
                if (!letters) {
                    if (pitch <= 59) {
                        return ["",""]
                    } else if (60 <= pitch && pitch <= 66) {
                        return ["",""]
                    } else if (67 <= pitch && pitch <= 71) {
                        return ["",""]
                    } else if (72 <= pitch && pitch <= 75) {
                        return ["","'"]
                    } else if (76 <= pitch && pitch <= 78) {
                        return ["","''"]
                    } else if (79 <= pitch && pitch <= 83) {
                        return ["","'''"]
                    }  else if (84 <= pitch) {
                        return ["","''''"]
                    } else {
                        return ["",""]
                    }
                } else {
                    if (pitch <= 59) {
                        return ["",""]
                    } else if (60 <= pitch && pitch <= 71) {
                        return ["",""]
                    } else if (72 <= pitch && pitch <= 83) {
                        return ["","'"]
                    } else if (84 <= pitch) {
                        return ["","''"]
                    } else {
                        return ["",""]
                    }
                }
        }
    }
        
}



/*
TODO:
- use concert pitch or make it an option
- special ties maybe with more than two notes on same pitch
- handle other instruments
- add abililty to have system text in the middle of notes of some staffs
*/
