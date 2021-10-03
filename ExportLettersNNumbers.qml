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
            processPreview()
      
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

      function processHelper() {
            this.parts = []
            this.newPart = function(partname) {
                  this.parts.push({
                        name: partname,
                        data: []
                  })
            },
            this.checkPart = function() {
                  if (this.parts.length==0) {
                        this.parts.push({
                              data: []
                        })
                  }
            }
            this.newNote = function(nind, tpitch, dur, letter, number, dashes) {
                  this.checkPart()
                  this.parts[this.parts.length-1].data.push({
                        nind: nind,
                        type: "note",
                        pitch: tpitch,
                        duration: dur,
                        letter: letter,
                        number: number,
                        dashes: dashes
                  })
            },
            this.newRest = function(nind,dur) {
                  this.checkPart()
                  //console.log(`rest of length ${dur}`)
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
            this.getOutput = function() {
                  outputLetters = ""
                  outputNumbers = ""
                  for (let i=0; i<this.parts.length; i++) {
                        let p = this.parts[i]
                        p.data.sort(function(a,b) {
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
                        for (let j=0; j<p.data.length-1; j++) {
                              if (p.data[j].type == "rest" && p.data[j+1].type == "rest") {
                                    p.data[j].duration += p.data[j+1].duration
                                    p.data.splice(j+1,1)
                              }
                        }
                        if (p.data[0].type == "rest") {
                              p.data.splice(0,1)
                        }
                        if (i>0) {
                              outputLetters += "\n\n"
                              outputNumbers += "\n\n"
                        }
                        if ("name" in p) {
                              outputLetters += p.name+"\n"
                              outputNumbers += p.name+"\n"
                        }
                        for (let j=0; j<p.data.length; j++) {
                              switch(p.data[j].type) {
                                    case "note":
                                          outputLetters += p.data[j].letter + p.data[j].dashes + " "
                                          outputNumbers += p.data[j].number + p.data[j].dashes + " "
                                          break;
                                    case "layout_break":
                                          if (layoutBreakCheckBox.checked) {
                                                outputLetters += "\n"
                                                outputNumbers += "\n"
                                          }
                                          break;
                                    case "rest": 
                                          //console.log(`rest of length ${p.data[j].duration*4} at ${p.data[j].nind}`)
                                          var len = p.data[j].duration*4
                                          var spaces = Math.floor(Math.max(2,Math.min(8,len*2.3)))
                                          outputLetters += (" ").repeat(spaces)
                                          outputNumbers += (" ").repeat(spaces)
                                          break;
                                    default:
                                          break;
                              }
                        }
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

      function processStaffVoice(staff,voice) {

            var instrumentPitchOffset = 0
            var sss = getStaffFromInd(staff)
            if(sss.part.instruments[0].instrumentId.indexOf("brass.trombone")==0) {
                  instrumentPitchOffset = 12
            } else if(sss.part.instruments[0].instrumentId.indexOf("brass.sousaphone")==0) {
                  instrumentPitchOffset = 24
            }
            //console.log("instrumentPitchOffset",instrumentPitchOffset)

            var cur = curScore.newCursor()
            cur.staffIdx = staff
            cur.voice = voice 
            cur.rewind(0)

            var pH = new processHelper()
            
            console.log("---------")
            
            var score = cur.score
            
            console.log(`Score "${score.title}" ("${score.scoreName}") with ${score.nstaves} staves, ${score.ntracks} tracks, ${score.nmeasures} measures`)
            console.log("---------")

            
            var  i = 0
            while (cur.segment) {
            
                  var nind = cur.segment.tick/division
                  //console.log(`Segment ${i} at ${cur.segment.tick}`)
                  //console.log(`  Tick ${+cur.segment.tick}`)
                  //console.log(`  Ind ${nind}`)
                  //console.log(`  KeySig ${cur.keySignature}`)
                  //console.log(`  staff ${cur.staffIdx}  voice ${cur.voice}  track ${cur.track}`)
                  
                  for (let j=0; j<cur.segment.annotations.length; j++) {
                        var an = cur.segment.annotations[j]
                        if (an.type==41) {
                              console.log(`  tempo annotation`)
                        } else if (an.type==42) {
                              console.log(`  staff text`) // TODO: do the same as system text?
                        } else if (an.type==43) {
                              //console.log(`  system text: ${an.text}`)
                              outputLetters += `\n\n${an.text}:\n`
                              outputNumbers += `\n\n${an.text}:\n`
                              pH.newPart(an.text)
                        } else {
                              console.log(`  ======> Annotation with type ${an.type} ${an.userName()}`)
                        }
                  }

            
                  if (cur.element) {
                        if (cur.element.type==Element.CHORD) {
                              /* TODO: handle multiple notes
                              for (let j=0; j<cur.element.notes.length; j++) {
                                    var n = cur.element.notes[j]
                                    var pitch = n.pitch + instrumentPitchOffset
                                    var tpitch = pitch + (n.tpc2-n.tpc1)
                                    //console.log("  Note  "+tpitch + "\t"+ lettersSharp(tpitch)+dashes(tpitch)+"    \t"+ lettersFlat(tpitch)+dashes(tpitch)+"\t"+ numbers(tpitch)+dashes(tpitch))//+"\t\t"+n.tpc+"\t"+n.tpc1+"\t"+n.tpc2+"\t"+(n.tpc2-n.tpc1))
                              }
                              */
                              var n = cur.element.notes[0]
                              var pitch = n.pitch + instrumentPitchOffset
                              var tpitch = pitch + (n.tpc2-n.tpc1)
                              if (n.tieBack!==null && n.tieBack.startNote.pitch==n.pitch) {
                                    //console.log(`    Tie back ${n.tieBack.startNote.pitch}`)
                              } else {
                                    pH.newNote(nind, tpitch, cur.element.actualDuration, letters(tpitch,cur), numbers(tpitch), dashes(tpitch))
                                    //console.log("    Note  "+tpitch + "\t"+ lettersSharp(tpitch)+dashes(tpitch)+"    \t"+ lettersFlat(tpitch)+dashes(tpitch)+"\t"+ numbers(tpitch)+dashes(tpitch))//+"\t\t"+n.tpc+"\t"+n.tpc1+"\t"+n.tpc2+"\t"+(n.tpc2-n.tpc1))
                                    
                                    
                                    //outputLetters += letters(tpitch, cur)
                                    //outputLetters += dashes(tpitch)+" "
                                    //outputNumbers += numbers(tpitch)
                                    //outputNumbers += dashes(tpitch)+" "
                              }
                        } else if (cur.element.type==Element.REST) {
                              var duration = cur.element.actualDuration
                              //console.log(`duration ${duration}`)
                              //console.log(duration.numerator/duration.denuminator)
                              pH.newRest(nind,duration.numerator/duration.denominator)
                              // cur.element has numerator,denuminator (of whole note), ticks and str
                              //console.log("    Rest\t"+duration.str)
                        } else {
                              console.log("  ======> Other element of type "+cur.element.userName()+")")
                        }
                  } else {
                        console.log("No element")
                  }

                  var mes = cur.measure.elements
                  var m = cur.measure
                  for (let j=0; j<mes.length; j++) {
                        let me = mes[j]
                        if (me.type==Element.LAYOUT_BREAK) {
                              //console.log(`    position ${me.position.str}  timesig ${me.timesigActual.str} lastSegment ${m.lastSegment.name} ${m.lastSegment.segmentType} ${m.lastSegment.tick} ${cur.segment.tick}`)
                              pH.newLayoutBreak(m.lastSegment.tick/division)
                              if (!m.lastSegment) {
                                    //console.log(`    no lastSegment`)
                              } else if (m.lastSegment.is(cur.segment)) {
                                    //console.log(`    layout break`)
                              } else {
                                    //console.log(`    too early for layout break`)
                                    var cs = m.firstSegment
                                    while (cs!=null) {
                                          //console.log(cs.name, cs.type, cs.segmentType, cs.tick)
                                          cs = cs.nextInMeasure
                                    }
                              }
                        } else {
                              console.log(`    =====> Other measure element ${m.name}`)
                        }
                  }
                  
            
                  cur.next()
                  
                  i = i+1
                  if (i>60) {
                        //break
                  }
            }

            console.log("collected")
            pH.getOutput()
            console.log(outputLetters)
      }
      function getSelectedStaffsOrAllInd() {
            // get selected staffs
            var selectedStaffs = new Set()
            if (curScore.selection.elements.length>0) {
                  if (curScore.selection.isRange) {
                        for (let i=curScore.selection.startStaff; i<curScore.selection.endStaff; i++) {
                              selectedStaffs.add(i)
                        }
                  } else {
                        var c = curScore.newCursor()
                        c.voice = 0
                        c.rewind(0)
                        for (let i=0; i<curScore.selection.elements.length; i++) {
                              var e = curScore.selection.elements[i]
                              if (e.type==Element.CHORD || e.type==Element.NOTE || e.type==Element.REST) {
                                    var selectInd = -1
                                    for (let j=0; j<curScore.nstaves; j++) {
                                          c.staffIdx = j
                                          if (e.staff.is(c.element.staff)) {
                                                //console.log(`found it at ${j}`)
                                                selectInd = j
                                                break
                                          }
                                    }
                                    selectedStaffs.add(selectInd)
                              }
                        }
                  }
            }
            if (selectedStaffs.size==0) {
                  for (var i=0; i<curScore.nstaves; i++) {
                        selectedStaffs.add(i)
                  }
            }
            selectedStaffs = [...selectedStaffs]

            return selectedStaffs
      }
      function processPreview() {
            var selectedStaffs = getSelectedStaffsOrAllInd()
            console.log("selectedStaffs")
            for (let staff of selectedStaffs) {
                  console.log(staff)
                  var sss = getStaffFromInd(staff)
                  //console.log(sss.part, sss.part.instruments.length)
                  //showObject(sss.part)
                  //showObject(sss.part.instruments[0])
            }

            processStaffVoice(selectedStaffs[0], 0)

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
                              processPreview()
                              //console.debug(sharpOrFlatSelection.get(currentIndex).text)
                        }
                  }
            }

            CheckBox {
                  id: layoutBreakCheckBox
                  checked: false
                  text: "Layout break creates newline"
                  onCheckedChanged: function () {
                        console.log("check changed")
                        processPreview()
                  }
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
            //anchors.top: settingsColumn.bottom
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
       
      function dirname(p) {
            return (p.slice(0,p.lastIndexOf("/")+1))
      }
       
      function basename(p) {
            return (p.slice(p.lastIndexOf("/")+1))
      }

      function extension(p) {
            return (p.slice(p.lastIndexOf(".")+1))
      }

      FileDialog {
            id: saveFileDialog
            title: qsTr("Please specify destination for output")
            selectExisting: false
            selectFolder: false
            selectMultiple: false
            onAccepted: {
                  var filename = saveFileDialog.fileUrl.toString()
                  var generatedFiles = "Generated files:\n\n"
                  if(filename){
                        var bfn = basename(filename)
                        bfn = bfn.slice(0,bfn.lastIndexOf('.'))

                        var selectedStaffs = getSelectedStaffsOrAllInd()
                        for (let staff of selectedStaffs) {
                              //processStaffVoice()
                              var sss = getStaffFromInd(staff)
                              //console.log(sss.part, sss.part.instruments.length)
                              //showObject(sss.part)
                              //showObject(sss.part.instruments[0])

                              // instrumentId (brass.trumpet.bflat)
                              // longName (Trompete 1)
                              // shortName (T1)
                              var instrumentName = sss.part.instruments[0].longName
                              instrumentName = instrumentName.replace(" ","_")
                              //console.log(instrumentName)

                              processStaffVoice(staff,0)
                              var lettersfn = bfn + "_" + instrumentName + "_B"
                              lettersfn = dirname(filename)+lettersfn+"."+extension(filename)
                              outputFile.source = getLocalPath(lettersfn)
                              outputFile.write(outputLetters)
                              generatedFiles += lettersfn+"\n"

                              var numbersfn = bfn + "_" + instrumentName + "_Z"
                              numbersfn = dirname(filename)+numbersfn+"."+extension(filename)
                              outputFile.source = getLocalPath(numbersfn)
                              outputFile.write(outputNumbers)
                              generatedFiles += numbersfn+"\n"
            
                        }


                        outputFile.source = getLocalPath(filename)
                        outputFile.write(generatedFiles)
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

      function letters(tpitch, cur) {
            if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="auto") {
                  if (cur.keySignature<0) {
                        return lettersFlat(tpitch)
                  } else {
                        return lettersSharp(tpitch)
                  }
            } else if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="sharp") {
                  return lettersSharp(tpitch)
            } else if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="flat") {
                  return lettersFlat(tpitch)
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
- special ties maybe with more than two notes on same pitch
- handle other instruments
- make mapping customizable
*/
