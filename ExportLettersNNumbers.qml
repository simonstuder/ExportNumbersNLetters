import QtQuick 2.0
import QtQuick.Dialogs 1.0
import QtQuick.Controls 1.0
import MuseScore 3.0
import FileIO 3.0

MuseScore {
      menuPath: "Plugins.ExportNumbersNFigures"
      description: "Description goes here"
      version: "1.0"
      requiresScore: true
      pluginType: "dialog"
      id: window
      width: 800
      height: 600

      property string outputNumbers
      property string outputLetters

      onRun: {
            processScore()
      
            //Qt.quit()
      }

      function processScore() {

            var cur = curScore.newCursor()
            cur.staffIdx = 0
            cur.voice = 0
            cur.rewind(0)
            
            console.log("---------")
            
            var score = cur.score
            
            console.log(`Score "${score.title}" ("${score.scoreName}") with ${score.nstaves} staves, ${score.ntracks} tracks, ${score.nmeasures} measures`)
            console.log("---------")

            outputLetters = ""
            outputNumbers = ""
            
            var  i = 0
            while (cur.segment) {
            
                  var nind = cur.segment.tick/division
                  console.log(`Segment ${i}`)
                  //console.log(`  Tick ${+cur.segment.tick}`)
                  console.log(`  Ind ${nind}`)
                  //console.log(`  KeySig ${cur.keySignature}`)
                  
                  for (let j=0; j<cur.segment.annotations.length; j++) {
                        var an = cur.segment.annotations[j]
                        if (an.type==41) {
                              console.log(`  tempo annotation`)
                        } else if (an.type==42) {
                              console.log(`  staff text`) // TODO: do the same as system text?
                        } else if (an.type==43) {
                              console.log(`  system text: ${an.text}`)
                              outputLetters += `\n\n${an.text}:\n`
                              outputNumbers += `\n\n${an.text}:\n`
                        } else {
                              console.log(`  ======> Annotation with type ${an.type} ${an.userName()}`)
                        }
                  }
            
                  if (cur.element) {
                        if (cur.element.type==Element.CHORD) {
                              for (let j=0; j<cur.element.notes.length; j++) {
                                    var n = cur.element.notes[j]
                                    var pitch = n.pitch
                                    var tpitch = pitch + (n.tpc2-n.tpc1)
                                    console.log("  Note  "+tpitch + "\t"+ lettersSharp(tpitch)+dashes(tpitch)+"    \t"+ lettersFlat(tpitch)+dashes(tpitch)+"\t"+ numbers(tpitch)+dashes(tpitch))//+"\t\t"+n.tpc+"\t"+n.tpc1+"\t"+n.tpc2+"\t"+(n.tpc2-n.tpc1))
                              }
                              if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="auto") {
                                    if (cur.keySignature<0) {
                                          outputLetters += lettersFlat(tpitch)
                                    } else {
                                          outputLetters += lettersSharp(tpitch)
                                    }
                              } else if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="sharp") {
                                    outputLetters += lettersSharp(tpitch)
                              } else if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="flat") {
                                    outputLetters += lettersFlat(tpitch)
                              }
                              outputLetters += dashes(tpitch)+" "
                              outputNumbers += numbers(tpitch)
                              outputNumbers += dashes(tpitch)+" "
                        } else if (cur.element.type==Element.LAYOUT_BREAK) {
                              console.log("  layout break")
                        } else if (cur.element.type==Element.NOTE) {
                              console.log("  note")
                        } else if (cur.element.type==Element.REST) {
                              var duration = cur.element.actualDuration
                              // cur.element has numerator,denuminator (of whole note), ticks and str
                              console.log("  Rest\t"+duration.str)
                        } else {
                              console.log("  ======> Other element of type "+cur.element.userName()+")")
                        }
                  } else {
                        console.log("No element")
                  }
                  
            
                  cur.next()
                  
                  i = i+1
                  if (i>60) {
                        //break
                   }
            }
      }

      Label {
            id: textLabel
            wrapMode: Text.WordWrap
            text: qsTr("Preview of current settings to the right")
            font.pointSize:12
            anchors.left: window.left
            anchors.top: window.top
            anchors.leftMargin: 10
            anchors.topMargin: 10
      }

      Column {
            id: settingsColumn
            anchors.top: textLabel.bottom
            anchors.right: window.right
            anchors.topMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Row {
                  spacing: 2

                  Text {
                        id: sharpOrFlatLabel
                        text: "Use sharp or flats"
                        anchors.verticalCenter: sharpOrFlatSelectionBox.verticalCenter
                  }
                  ComboBox {
                        id: sharpOrFlatSelectionBox
                        currentIndex: 0
                        model: ListModel {
                              id: sharpOrFlatSelection
                              ListElement { text: "auto"; value: "auto" }
                              ListElement { text: qsTr("sharp"); value: "sharp" }
                              ListElement { text: qsTr("flat"); value: "flat" }
                        }
                        width: 70
                        onCurrentIndexChanged: function () {
                              processScore()
                              //console.debug(sharpOrFlatSelection.get(currentIndex).text)
                        }
                  }
            }

            CheckBox {
                  id: exampleCheckBox
                  checked: true
                  text: "CheckBox"
            }
      }

      TextArea {
            id: previewTextLetters
            anchors.top: textLabel.bottom
            anchors.left: window.left
            anchors.right: settingsColumn.left
            anchors.topMargin: 10
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height:250
            wrapMode: TextEdit.WrapAnywhere
            textFormat: TextEdit.PlainText
            text: outputLetters
      }

      TextArea {
            id: previewTextNumbers
            anchors.top: previewTextLetters.bottom
            anchors.left: window.left
            anchors.right: settingsColumn.left
            anchors.topMargin: 10
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height:250
            wrapMode: TextEdit.WrapAnywhere
            textFormat: TextEdit.PlainText
            text: outputNumbers
      }


      Button {
            id : buttonCancel
            text: qsTr("Cancel")
            anchors.top: settingsColumn
            anchors.bottom: window.bottom
            anchors.right: window.right
            anchors.rightMargin: 10
            anchors.bottomMargin: 10
            onClicked: {
                  Qt.quit();
            }
      }

      Button {
            id : buttonSaveOutput
            text: qsTr("Save Output")
            anchors.bottom: window.bottom
            anchors.right: previewTextNumbers.right
            anchors.rightMargin: 10
            anchors.bottomMargin: 10
            onClicked: {
                  console.log("save output")
                  saveFileDialog.open()
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
            //source: tempPath() + "/my_file.xml"
            onError: console.log(msg)
      }
       
      FileDialog {
            id: saveFileDialog
            title: qsTr("Please specify destination for output")
            selectExisting: false
            selectFolder: false
            selectMultiple: false
            onAccepted: {
                  var filename = saveFileDialog.fileUrl.toString()
                  if(filename){
                        outputFile.source = getLocalPath(filename)
                        outputFile.write(outputLetters)
                  }
            }
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
                  case 81: return "½'"
                  case 82: return "1"
                  case 83: return "2"
                  case 84: return "L"
                  default: ""
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
      
      function dashes(pitch) {
            if (72 <= pitch && pitch <= 75) {
                  return "'"
            } else if (76 <= pitch && pitch <= 78) {
                  return "''"
             } else if (79 <= pitch && pitch <= 83) {
                  return "'''"
             }  else if (84 <= pitch) {
                  return "''''"
             } else {
                  return ""
             }
      }
            
}



/*
TODO:
- use concert pitch or make it an option
*/