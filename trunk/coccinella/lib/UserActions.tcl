#  UserActions.tcl ---
#  
#      This file is part of the whiteboard application. It implements typical
#      user actions, such as callbacks from buttons and menus.
#      
#  Copyright (c) 2000-2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: UserActions.tcl,v 1.3 2003-01-30 17:34:08 matben Exp $

namespace eval ::UserActions:: {
    
    namespace export   \
       SavePostscript  \
       DoEraseAll DoPutCanvasDlg DoPutCanvas   \
      DoGetCanvas
}

# UserActions::CancelAllPutGetAndPendingOpen ---
#
#       It is supposed to stop every put and get operation taking place.
#       This may happen when the user presses a stop button or something.
#       
# Arguments:
#
# Results:

proc ::UserActions::CancelAllPutGetAndPendingOpen {wtop} {
    global  prefs
    
    upvar ::${wtop}::wapp wapp

    # This shall be made instance specific!!!
    ::PutFileIface::CancelAll
    ::GetFile::CancelAll
    if {[string equal $prefs(protocol) "jabber"]} {
	::Network::OpenConnectionKillAll
	::UI::SetStatusMessage $wtop {}
	::UI::StartStopAnimatedWave $wapp(statmess) 0
    } else {
	OpenCancelAllPending
    }
}

# UserActions::SelectAll --
#
#       Selects all items in the canvas.
#   
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       none

proc ::UserActions::SelectAll {wtop} {
    
    upvar ::${wtop}::wapp wapp
    set wCan $wapp(can)
    $wCan delete tbbox
    set ids [$wCan find all]
    foreach id $ids {
	$wCan dtag $id selected
	::CanvasDraw::MarkBbox $wCan 1 $id
    }
}

# UserActions::DeselectAll --
#
#       Deselects all items in the canvas.
#   
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       none

proc ::UserActions::DeselectAll {wtop} {
    
    upvar ::${wtop}::wapp wapp
    
    set wCan $wapp(can)
    $wCan delete withtag tbbox
    $wCan dtag all selected
    
    # menus
    ::UI::FixMenusWhenSelection $wCan
}

# UserActions::RaiseOrLowerItems --
#
#       Raise or lower the stacking order of the selected canvas item.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       what   "raise" or "lower"
#       
# Results:
#       none.

proc ::UserActions::RaiseOrLowerItems {wtop {what raise}} {
    
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::state state
    
    set w $wapp(can)    

    set cmdList {}
    set undoList {}
    foreach id [$w find withtag selected] {
	set utag [::CanvasUtils::GetUtag $w $id]
	lappend cmdList [list $what $utag all]
	lappend undoList [::CanvasUtils::GetStackingCmd $w $utag]
    }
    if {$state(canGridOn) && [string equal $what "lower"]} {
	lappend cmdList [list lower grid all]
    }
    set redo [list ::CanvasUtils::CommandList $wtop $cmdList]
    set undo [list ::CanvasUtils::CommandList $wtop $undoList]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
}

# UserActions::SetCanvasBgColor --
#
#       Sets background color of canvas.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       color dialog shown.

proc ::UserActions::SetCanvasBgColor {wtop} {
    global  prefs state
    
    upvar ::${wtop}::wapp wapp
    
    set w $wapp(can)
    set prevCol $state(bgColCan)
    set col [tk_chooseColor -initialcolor $state(bgColCan)]
    if {[string length $col] > 0} {
	
	# The change should be triggered automatically through the trace.
	set state(bgColCan) $col
	set cmd [list configure -bg $col]
	set undocmd [list configure -bg $prevCol]
	set redo [list ::CanvasUtils::Command $wtop $cmd]
	set undo [list ::CanvasUtils::Command $wtop $undocmd]
	eval $redo
	undo::add [::UI::GetUndoToken $wtop] $undo $redo
    }
}

# UserActions::DoCanvasGrid --
#
#       Make a grid in the canvas; uses state(canGridOn) to toggle grid.
#       
# Arguments:
#       
# Results:
#       grid shown/hidden.

proc ::UserActions::DoCanvasGrid {wtop} {
    global  prefs this
    
    upvar ::${wtop}::state state
    upvar ::${wtop}::wapp wapp

    set wCan $wapp(can)
    set length 2000
    set gridDist $prefs(gridDist)
    if {$state(canGridOn) == 0} {
	$wCan delete grid
	return
    }
    if {$this(platform) == "windows"} {
	for {set x $gridDist} {$x <= $length} {set x [expr $x + $gridDist]} {
	    $wCan create line $x 0 $x $length  \
	      -width 1 -fill gray50 -tags grid
	}
	for {set y $gridDist} {$y <= $length} {set y [expr $y + $gridDist]} {
	    $wCan create line 0 $y $length $y  \
	      -width 1 -fill gray50 -tags grid
	}
    } else {
	for {set x $gridDist} {$x <= $length} {set x [expr $x + $gridDist]} {
	    $wCan create line $x 0 $x $length  \
	      -width 1 -fill gray50 -tags grid -stipple gray50
	}
	for {set y $gridDist} {$y <= $length} {set y [expr $y + $gridDist]} {
	    $wCan create line 0 $y $length $y  \
	      -width 1 -fill gray50 -tags grid -stipple gray50
	}
    }
    $wCan lower grid
}
    
# UserActions::SavePostscript --
#
#       Save canvas to a postscript file.
#       Save canvas to a XML/SVG file.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       file save dialog shown, file written.

proc ::UserActions::SavePostscript {wtop} {
    global  prefs this
    
    upvar ::${wtop}::wapp wapp
    
    if {[winfo exists $wapp(can)]} {
	set w $wapp(can)
    } else {
	return
    }
    set typelist {
	{"Postscript File"    {.ps}}
	{"XML/SVG"            {.svg}}
    }
    set userDir [::Utils::GetDirIfExist $prefs(userDir)]
    set opts [list -initialdir $userDir]
    if {$prefs(haveSaveFiletypes)} {
	lappend opts -filetypes $typelist
    }
    set ans [eval {tk_getSaveFile -title [::msgcat::mc {Save As}]  \
      -filetypes $typelist -defaultextension ".ps"  \
      -initialfile "canvas.ps"} $opts]
    if {[string length $ans] > 0} {
	set prefs(userDir) [file dirname $ans]
	if {[file extension $ans] == ".svg"} {
	    ::can2svg::canvas2file $w $ans
	} else {
	    eval {$w postscript} $prefs(postscriptOpts) {-file $ans}
	    if {[string equal $this(platform) "macintosh"]} {
		file attributes $ans -type TEXT -creator vgrd
	    }
	}
    }
}
    
# UserActions::DoPrintCanvas --
#
#       Platform independent printing of canvas.

proc ::UserActions::DoPrintCanvas {wtop} {
    global  this prefs wDlgs
    
    upvar ::${wtop}::wapp wapp
    
    set wCan $wapp(can)
    
    switch -- $this(platform) {
	"macintosh" {
	    SavePostscript $wtop
	}
	"windows" {
	    if {!$prefs(printer)} {
		tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
		  -message [::msgcat::mc messprintnoextension]
	    } else {
		::Windows::Printer::Print $wCan
	    }
	}
	"unix" - "macosx" {
	    ::PrintPSonUnix::PrintPSonUnix $wDlgs(print) $wCan
	}
    }
}

# UserActions::DoPrintText --
#
#

proc ::UserActions::DoPrintText {wtext args} {
    global  this prefs wDlgs
        
    if {[winfo class $wtext] != "Text"} {
	error "::UserActions::DoPrintText: $wtext not a text widget!"
    }
    switch -- $this(platform) {
	"macintosh" {
	    tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
	      -message [::msgcat::mc messprintnoextension]
	}
	"windows" {
	    if {!$prefs(printer)} {
		tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
		  -message [::msgcat::mc messprintnoextension]
	    } else {
		eval {::Windows::Printer::Print $wtext} $args
	    }
	}
	"unix" - "macosx" {
	    ::PrintPSonUnix::PrintPSonUnix $wDlgs(print) $wtext
	}
    }
}

proc ::UserActions::PageSetup { } {
    global  this prefs wDlgs
    
    switch -- $this(platform) {
	macintosh {
	    tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
	      -message [::msgcat::mc messprintnoextension]
	}
	windows {
	    if {!$prefs(printer)} {
		tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
		  -message [::msgcat::mc messprintnoextension]
	    } else {
		::Windows::Printer::PageSetup
	    }
	}
	unix - macosx {
	    ::PSPageSetup::PSPageSetup .page
	}
    }
}

proc ::UserActions::Speak {msg {voice {}}} {
    global  this prefs
    
    switch -- $this(platform) {
	macintosh {
	    ::Mac::Speech::Speak $msg $voice
	}
	windows {
	    ::MSSpeech::Speak $msg $voice
	}
	unix - macosx {
	}
    }
}

proc ::UserActions::SpeakGetVoices { } {
    global  this prefs
    
    switch -- $this(platform) {
	macintosh {
	    return [::Mac::Speech::GetVoices]
	}
	windows {
	    return [::MSSpeech::GetVoices]
	}
	unix - macosx {
	    return {}
	}
    }
}

# UserActions::DoConnect --
#
#       Protocol independent open connection to server.

proc ::UserActions::DoConnect { } {
    global  prefs wDlgs
    
    if {[string equal $prefs(protocol) {jabber}]} {
	::Jabber::Login::Login $wDlgs(jlogin)
    } elseif {![string equal $prefs(protocol) {server}]} {
	::OpenConnection::OpenConnection $wDlgs(openConn)
    }
}

# UserActions::ResizeItem --
#
#       Scales each selected item in canvas 'w' by a factor 'factor'. 
#       Not all item types are rescaled. 
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       factor   a numerical factor to scale with.
#       
# Results:
#       item resized, propagated to clients.

proc ::UserActions::ResizeItem {wtop factor} {
    global  prefs
    
    upvar ::${wtop}::wapp wapp
    
    set w $wapp(can)
    set ids [$w find withtag selected]
    if {[string length $ids] == 0} {
	return
    }
    if {$prefs(scaleCommonCG)} {
	set bbox [eval $w bbox $ids]
	set cgx [expr ([lindex $bbox 0] + [lindex $bbox 2])/2.0]
	set cgy [expr ([lindex $bbox 1] + [lindex $bbox 3])/2.0]
    }
    set cmdList {}
    set undoList {}
    set invfactor [expr 1.0/$factor]
    foreach id $ids {
	set utag [::CanvasUtils::GetUtag $w $id]
	if {[string length $utag] == 0} {
	    continue
	}	

	# Sort out the nonrescalable ones.
	set theType [$w type $id]
	if {[string equal $theType "text"] ||   \
	  [string equal $theType "image"] ||    \
	  [string equal $theType "window"]} {
	    continue
	}
	if {!$prefs(scaleCommonCG)} {
	    foreach {left top right bottom} [$w bbox $id] { break }
	    set cgx [expr ($left + $right)/2.0]
	    set cgy [expr ($top + $bottom)/2.0]
	}
	lappend cmdList [list scale $utag $cgx $cgy $factor $factor]
	lappend undoList [list scale $utag $cgx $cgy $invfactor $invfactor]
    }    
    set redo [list ::CanvasUtils::CommandList $wtop $cmdList]
    set undo [list ::CanvasUtils::CommandList $wtop $undoList]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
    
    # New markers.
    foreach id $ids {
	$w delete id$id
	$w dtag $id selected
	::CanvasDraw::MarkBbox $w 1 $id
    }
}

# UserActions::FlipItem --
#
#

proc ::UserActions::FlipItem {wtop direction} {
    
    upvar ::${wtop}::wapp wapp
    
    set w $wapp(can)
    set id [$w find withtag selected]
    if {[llength $id] != 1} {
	return
    }
    set theType [$w type $id]
    if {![string equal $theType "line"] &&  \
      ![string equal $theType "polygon"]} {
	return
    }
    set utag [::CanvasUtils::GetUtag $w $id]
    foreach {left top right bottom} [$w bbox $id] { break }
    set xmid [expr ($left + $right)/2]
    set ymid [expr ($top + $bottom)/2]
    set flipco {}
    set coords [$w coords $id]
    if {[string equal $direction "horizontal"]} {
	foreach {x y} $coords {
	    lappend flipco [expr 2*$xmid - $x] $y
	}	
    } elseif {[string equal $direction "vertical"]} {
	foreach {x y} $coords {
	    lappend flipco $x [expr 2*$ymid - $y]
	}	
    }
    set cmd "coords $utag $flipco"
    set undocmd "coords $utag $coords"    
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
	
    # New markers.
    $w delete id$id
    ::CanvasDraw::MarkBbox $w 1 $id
}

# UserActions::Undo --
#
#       The undo command.

proc ::UserActions::Undo {wtop} {
    
    # Make the text stuff in sync.
    ::CanvasText::DoSendBufferedText $wtop
    
    # The actual undo command.
    undo::undo [::UI::GetUndoToken $wtop]
    
    ::CanvasDraw::SyncMarks $wtop
}

# UserActions::Redo --
#
#       The redo command.

proc ::UserActions::Redo {wtop} {
    
    undo::redo [::UI::GetUndoToken $wtop]
}

# UserActions::DoEraseAll --
#
#       Erases all items in canvas except for grids. Deselects all items.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       where    "all": erase this canvas and all others.
#                "remote": erase only client canvases.
#                "local": erase only own canvas.
#       
# Results:
#       all items deleted, propagated to all clients.

proc ::UserActions::DoEraseAll {wtop {where all}} {
    
    upvar ::${wtop}::wapp wapp
    
    set wCan $wapp(can)
    ::UserActions::DeselectAll $wtop
    foreach id [$wCan find all] {
	
	# Do not erase grid.
	set theTags [$wCan gettags $id]
	if {[lsearch $theTags grid] >= 0} {
	    continue
	}
	::CanvasDraw::DeleteItem $wCan 0 0 $id $where
    }
}

proc ::UserActions::EraseAll {wtop} {
    
    upvar ::${wtop}::wapp wapp
    
    set wCan $wapp(can)
    foreach id [$wCan find all] {
	$wCan delete $id
    }
}

# UserActions::DoPutCanvasDlg --
#
#       Erases all client canvases, transfers this canvas to all clients.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       all items deleted, propagated to all clients.

proc ::UserActions::DoPutCanvasDlg {wtop} {
    
    upvar ::${wtop}::wapp wapp
    
    set wCan $wapp(can)
    set ans [tk_messageBox -message [FormatTextForMessageBox \
      "Warning! Syncing this canvas first erases all client canvases."] \
      -icon warning -type okcancel -default ok]
    if {$ans != "ok"} {
	return
    }
    
    # Erase all other client canvases.
    DoEraseAll $wtop "remote"

    # Put this canvas to all others.
    DoPutCanvas $wCan all
}
    
# UserActions::DoPutCanvas --
#   
#       Synchronizes, or puts, this canvas to all others. 
#       It uses a temporary file. Images don't work automatically.
#       If 'toIPnum' then put canvas 'w' only to that ip number.
#       
# Arguments:
#       w        the canvas.
#       toIPnum  if ip number given, then put canvas 'w' only to that ip number.
#                else put to all clients.
#       
# Results:
#       .

proc ::UserActions::DoPutCanvas {w {toIPnum all}} {
    global  this

    Debug 2 "::UserActions::DoPutCanvas w=$w, toIPnum=$toIPnum"

    set tmpFile ".tmp[clock seconds].can"
    set absFilePath [file join $this(path) $tmpFile]

    # Save canvas to temporary file.
    if {[catch [list open $absFilePath w] fileId]} {
	tk_messageBox -message [FormatTextForMessageBox  \
	  [::msgcat::mc messfailopwrite $tmpFile $fileId]] \
	  -icon error -type ok
    }
    ::CanvasFile::CanvasToFile $w $fileId $absFilePath
    catch {close $fileId}

    if {[catch [list open $absFilePath r] fileId]} {
	tk_messageBox -message [FormatTextForMessageBox  \
	  [::msgcat::mcset en messfailopread $tmpFile $fileId]] \
	  -icon error -type ok
    }
    
    # Distribute to all other client canvases.
    if {$toIPnum == "all"} {
	::CanvasFile::FileToCanvas $w $fileId $absFilePath -where remote
    } else {
	::CanvasFile::FileToCanvas $w $fileId $absFilePath -where $toIPnum
    }
    catch {close $fileId}

    # Finally delete the temporary file.
    file delete $absFilePath
}

# UserActions::DoGetCanvas --
#
#       .
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       .

proc ::UserActions::DoGetCanvas {wtop} {
    
    # The dialog to select remote client.
    set getCanIPNum [::GetCanvas::GetCanvas .getcan]
    Debug 2 "DoGetCanvas:: getCanIPNum=$getCanIPNum"

    if {$getCanIPNum == ""} {
	return
    }    
    
    # Erase everything in own canvas.
    DoEraseAll $wtop "local"
    
    # GET CANVAS.
    # Jabber????
    SendClientCommand $wtop "GET CANVAS:" -ips $getCanIPNum
}

# UserActions::DoSendCanvas --
#
#       Puts the complete canvas to remote client(s).
#       Does not use a temporary file. Does not add anything to undo stack.
#       Needed because jabber should get everything in single batch.

proc ::UserActions::DoSendCanvas {wtop} {
    
    upvar ::${wtop}::wapp wapp   
    set w $wapp(can)
    set cmdList {}
    
    foreach id [$w find all] {
	set tags [$w gettags $id]
	if {([lsearch $tags grid] >= 0) || ([lsearch $tags tbbox] >= 0)} {
	    continue
	}
	set type [$w type $id]

	switch -- $type {
	    image {
		set line [::CanvasUtils::GetOnelinerForImage $w $id \
		  -uritype http]
		lappend cmdList [concat "CANVAS:" $line]
	    }
	    window {
		
		# A movie: for QT we have a complete widget; 
		set windowName [$w itemcget $id -window]
		set windowClass [winfo class $windowName]
		
		switch -- $windowClass {
		    QTFrame {
			set line [::CanvasUtils::GetOnelinerForQTMovie $w $id]
		    }
		    SnackFrame {			
			set line [::CanvasUtils::GetOnelinerForSnack $w $id]
		    }
		    XanimFrame {
			# ?
		    }
		    default {
			
			# What about other formats that are put in their own
			# window widget? We should have some hook here for
			# 3rd party extensions such VTK.
			
			continue
		    }
		}
		lappend cmdList [concat "CANVAS:" $line]
	    }
	    default {
		set cmd [::CanvasUtils::GetOnelinerForItem $w $id]
		lappend cmdList [concat "CANVAS:" $cmd]
	    }
	}
    }
    
    # Be sure to send jabber stuff in a single batch. 
    # Jabber: override doSend checkbutton!
    SendClientCommandList $wtop $cmdList -force 1
}

# UserActions::DoCloseWindow --
#
#       Typically called from 'wm protocol $w WM_DELETE_WINDOW'
#       to take special actions before a window is closed.

proc ::UserActions::DoCloseWindow { } {
    global  wDlgs
    
    set w [winfo toplevel [focus]]
    
    # Do different things depending on type of toplevel.
    switch -glob -- [winfo class $w] {
	Wish* {
	    # Main window.
	    if {$w == "."} {
		::UserActions::DoQuit -warning 1
	    }
	}
	Whiteboard {
	    if {$w == "."} {
		::UserActions::DoQuit -warning 1
	    } else {
		destroy $w
	    }
	}
	Preferences {
	    ::Preferences::CancelPushBt
	}
	Chat {
	    ::Jabber::Chat::Close -toplevel $w
	}
	GroupChat {
	    ::Jabber::GroupChat::CloseToplevel $w
	}
	MailBox {
	    ::Jabber::MailBox::Show $wDlgs(jinbox) -visible 0
	}
	RostServ {
	    ::Jabber::RostServ::Show $wDlgs(jrostbro) -visible 0
	}
	default {
	    destroy $w
	}
    }
}

# UserActions::DoQuit ---
#
#       Is called just before quitting to collect some state variables which
#       we want to save for next time.
#       
# Arguments:
#       args        ?-warning boolean?
#       
# Results:
#       boolean, qid quit or not

proc ::UserActions::DoQuit {args} {
    global  prefs state allIPnumsTo localStateVars specialMacPrefPath this
    
    upvar ::UI::dims dims
    upvar ::.::state statelocal
    upvar ::.::wapp wapp
        
    array set argsArr {
	-warning      0
    }
    array set argsArr $args
    set wCan $wapp(can)
    if {$argsArr(-warning)} {
	set ans [tk_messageBox -title [::msgcat::mc Quit?] -type yesno  \
	  -default yes -message [::msgcat::mc messdoquit?]]
	if {$ans == "no"} {
	    return $ans
	}
    }

    # Before quitting, save user preferences. 
    # Need to collect some of them first.
    # Position of root window.
    # We want to save wRoot and hRoot as they would be without any clients 
    # in the communication frame.
    
    bind $wCan <Configure> {}
    
    foreach {dims(wRoot) hRoot dims(x) dims(y)} [::UI::ParseWMGeometry .] {}
    set dims(hRoot) [expr $dims(hCanvas) + $dims(hStatus) +  \
      $dims(hCommClean) + $dims(hTop) + $dims(hFakeMenu)]
    if {$prefs(haveScrollbars)} {
	incr dims(hRoot) [expr [winfo height $wapp(xsc)] + 4]
    }
    
    # Take the instance specific state vars and copy to global state vars.
    foreach key $localStateVars {
	set state($key) $statelocal($key)
    }
    set state(visToolbar) [::UI::IsShortcutButtonVisable .]
    
    # If we used 'Edit/Revert To/Application Defaults' be sure to reset...
    set prefs(firstLaunch) 0
    
    # Stop any running reflector server. Ask first?
    if {$state(reflectorStarted)} {
	set ans [tk_messageBox -icon error -type yesno -message \
	  "Should the Reflector Server be stopped?"]
	if {$ans == "yes"} {
	    ::NetworkSetup::StopServer
	}
    }
    
    # If we are a jabber client, put us unavailable etc.
    if {[string equal $prefs(protocol) "jabber"]} {
	::Jabber::EndSession
    }
    
    # Should we clean up our 'incoming' directory?
    
    # A workaround for the 'info script' bug on MacTk 8.3
    # Work on a temporary file and switch later.
    if {[string equal $::this(platform) "macintosh"] && [info exists specialMacPrefPath]} {
	set tmpFile ${specialMacPrefPath}.tmp
	if {![catch {open $tmpFile w} fid]} {
	    puts $fid "!\n!   Install path for the Whiteboard application."
	    puts $fid "!   The data written at: [clock format [clock seconds]]\n!"
	    puts $fid [format "%-24s\t%s" *thisPath: $this(path)]
	    close $fid
	    catch {file rename -force $tmpFile $specialMacPrefPath}
	    file attributes $specialMacPrefPath -type pref
	}
    }
    
    # Get dialog window geometries. Some jabber dialogs special.
    set prefs(winGeom) {}
    foreach win $prefs(winGeomList) {
	if {[winfo exists $win] && [winfo ismapped $win]} {
	    lappend prefs(winGeom) $win [wm geometry $win]
	} elseif {[info exists prefs(winGeom,$win)]} {
	    lappend prefs(winGeom) $win $prefs(winGeom,$win)
	}
    }
    if {[string equal $prefs(protocol) "jabber"]} {
	set prefs(winGeom) [concat $prefs(winGeom) [::Jabber::GetAllWinGeom]]
	
	# Same for pane positions.
	set prefs(paneGeom) [::Jabber::GetAllPanePos] 
    }
    
    # Save to the preference file and quit...
    PreferencesSaveToFile
    exit
}

#-------------------------------------------------------------------------------
