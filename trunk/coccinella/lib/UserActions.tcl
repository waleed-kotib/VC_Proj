#  UserActions.tcl ---
#  
#      This file is part of the whiteboard application. It implements typical
#      user actions, such as callbacks from buttons and menus.
#      
#  Copyright (c) 2000-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: UserActions.tcl,v 1.25 2003-12-19 15:47:40 matben Exp $

namespace eval ::UserActions:: {
    
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
    
    # This must be instance specific!!!
    # I think we let put operations go on.
    #::PutFileIface::CancelAllWtop $wtop
    ::GetFileIface::CancelAllWtop $wtop
    ::Import::HttpResetAll $wtop
    if {[string equal $prefs(protocol) "jabber"]} {
	::Network::KillAll
	::WB::SetStatusMessage $wtop {}
	::WB::StartStopAnimatedWave $wtop 0
    } else {
	::OpenConnection::OpenCancelAllPending
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
    
    set wCan [::UI::GetCanvasFromWtop $wtop]
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
        
    set wCan [::UI::GetCanvasFromWtop $wtop]
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
    
    upvar ::${wtop}::state state
    
    set w [::UI::GetCanvasFromWtop $wtop]    

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
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
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
        
    set w [::UI::GetCanvasFromWtop $wtop]
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
	undo::add [::WB::GetUndoToken $wtop] $undo $redo
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

    set wCan [::UI::GetCanvasFromWtop $wtop]
    set length 2000
    set gridDist $prefs(gridDist)
    if {$state(canGridOn) == 0} {
	$wCan delete grid
	return
    }
    if {$this(platform) == "windows"} {
	for {set x $gridDist} {$x <= $length} {set x [expr $x + $gridDist]} {
	    $wCan create line $x 0 $x $length  \
	      -width 1 -fill gray50 -tags {notactive grid}
	}
	for {set y $gridDist} {$y <= $length} {set y [expr $y + $gridDist]} {
	    $wCan create line 0 $y $length $y  \
	      -width 1 -fill gray50 -tags {notactive grid}
	}
    } else {
	for {set x $gridDist} {$x <= $length} {set x [expr $x + $gridDist]} {
	    $wCan create line $x 0 $x $length  \
	      -width 1 -fill gray50 -tags {notactive grid} -stipple gray50
	}
	for {set y $gridDist} {$y <= $length} {set y [expr $y + $gridDist]} {
	    $wCan create line 0 $y $length $y  \
	      -width 1 -fill gray50 -tags {notactive grid} -stipple gray50
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
    
    set w [::UI::GetCanvasFromWtop $wtop]
    if {![winfo exists $w]} {
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
        
    set wCan [::UI::GetCanvasFromWtop $wtop]
    
    switch -- $this(platform) {
	macintosh - macosx {
	    ::Mac::Printer::Print $wtop
	}
	windows {
	    if {!$prefs(printer)} {
		tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
		  -message [::msgcat::mc messprintnoextension]
	    } else {
		::Windows::Printer::Print $wCan
	    }
	}
	unix {
	    ::Dialogs::UnixPrintPS $wDlgs(print) $wCan
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
	macintosh {
	    tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
	      -message [::msgcat::mc messprintnoextension]
	}
	macosx {
	    ::Mac::MacCarbonPrint::PrintText $wtext
	}
	windows {
	    if {!$prefs(printer)} {
		tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
		  -message [::msgcat::mc messprintnoextension]
	    } else {
		::Windows::Printer::DoPrintText $wtext
	    }
	}
	unix {
	    ::Dialogs::UnixPrintPS $wDlgs(print) $wtext
	}
    }
}

proc ::UserActions::PageSetup {wtop} {
    global  this prefs wDlgs
    
    switch -- $this(platform) {
	macintosh {
	    ::Mac::MacPrint::PageSetup $wtop
	}
	macosx {
	    ::Mac::MacCarbonPrint::PageSetup $wtop
	}
	windows {
	    if {!$prefs(printer)} {
		tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
		  -message [::msgcat::mc messprintnoextension]
	    } else {
		::Windows::Printer::PageSetup
	    }
	}
	unix {
	    ::PSPageSetup::PSPageSetup .page
	}
    }
}

proc ::UserActions::Speak {msg {voice {}}} {
    global  this prefs
    
    switch -- $this(platform) {
	macintosh - macosx {
	    ::Mac::Speech::Speak $msg $voice
	}
	windows {
	    ::MSSpeech::Speak $msg $voice
	}
	unix - macosx {
	    # empty.
	}
    }
}

proc ::UserActions::SpeakGetVoices { } {
    global  this prefs
    
    switch -- $this(platform) {
	macintosh - macosx {
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
    global  prefs
    
    if {[string equal $prefs(protocol) {jabber}]} {
	::Jabber::Login::Login
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
        
    set w [::UI::GetCanvasFromWtop $wtop]
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
	    foreach {left top right bottom} [$w bbox $id] break
	    set cgx [expr ($left + $right)/2.0]
	    set cgy [expr ($top + $bottom)/2.0]
	}
	lappend cmdList [list scale $utag $cgx $cgy $factor $factor]
	lappend undoList [list scale $utag $cgx $cgy $invfactor $invfactor]
    }    
    set redo [list ::CanvasUtils::CommandList $wtop $cmdList]
    set undo [list ::CanvasUtils::CommandList $wtop $undoList]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
    
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
        
    set w [::UI::GetCanvasFromWtop $wtop]
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
    foreach {left top right bottom} [$w bbox $id] break
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
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
	
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
    undo::undo [::WB::GetUndoToken $wtop]
    
    ::CanvasDraw::SyncMarks $wtop
}

# UserActions::Redo --
#
#       The redo command.

proc ::UserActions::Redo {wtop} {
    
    undo::redo [::WB::GetUndoToken $wtop]
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
        
    set wCan [::UI::GetCanvasFromWtop $wtop]
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
        
    set wCan [::UI::GetCanvasFromWtop $wtop]
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
        
    set wCan [::UI::GetCanvasFromWtop $wtop]
    set ans [tk_messageBox -message [FormatTextForMessageBox \
      "Warning! Syncing this canvas first erases all client canvases."] \
      -icon warning -type okcancel -default ok]
    if {$ans != "ok"} {
	return
    }
    
    # Erase all other client canvases.
    DoEraseAll $wtop "remote"

    # Put this canvas to all others.
    ::UserActions::DoPutCanvas $wCan all
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
    set getCanIPNum [::Dialogs::GetCanvas .getcan]
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
#       Lets remote client get binary entities (images ...) via http.

proc ::UserActions::DoSendCanvas {wtop} {
    
    set w [::UI::GetCanvasFromWtop $wtop]
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
			set line [::CanvasUtils::GetOnelinerForQTMovie $w $id \
			  -uritype http]
		    }
		    SnackFrame {			
			set line [::CanvasUtils::GetOnelinerForSnack $w $id \
			  -uritype http]
		    }
		    XanimFrame {
			# ?
			continue
		    }
		    default {
			if {[::Plugins::HaveSaveProcForWinClass $windowClass]} {
			    set procName \
			      [::Plugins::GetSaveProcForWinClass $windowClass]
			    set line [$procName $w $id -uritype http]
			}
		    }
		}
		if {$line != ""} {
		    lappend cmdList [concat "CANVAS:" $line]
		}
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
#       Typically called from the menu.
#       Take special actions before a window is closed.

proc ::UserActions::DoCloseWindow {{wevent {}}} {
    global  wDlgs
    
    set w [winfo toplevel [focus]]
    
    # If we bind to toplevel descriminate events coming from childrens.
    if {($wevent != "") && ($wevent != $w)} {
	return
    }
    if {$w == "."} {
	set wtop $w
    } else {
	set wtop ${w}.
    }
    Debug 2 "::UserActions::DoCloseWindow winfo class $w=[winfo class $w]"
    
    switch -- $w \
      $wDlgs(mainwb) {
	::WB::CloseWhiteboard $wtop
	return
    } \
      $wDlgs(jrostbro) {
	::UserActions::DoQuit -warning 1
	return
    }
    
    # Do different things depending on type of toplevel.
    switch -glob -- [winfo class $w] {
	Wish* - Whiteboard* - Coccinella* - Tclkit* {
	
	    # NOT ALWAYS CORRECT!!!!!!!
	    # Whiteboard window.
	    ::WB::CloseWhiteboard $wtop
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
	    ::Jabber::MailBox::Show -visible 0
	}
	JMain {
	    ::UserActions::DoQuit -warning 1
	}
	default {
	    destroy $w
	}
    }
}

# UserActions::DoQuit ---
#
#       Is called just before quitting to be able to save various
#       preferences etc.
#       
# Arguments:
#       args        ?-warning boolean?
#       
# Results:
#       boolean, qid quit or not

proc ::UserActions::DoQuit {args} {
    global  prefs this
    
    array set argsArr {
	-warning      0
    }
    array set argsArr $args
    if {$argsArr(-warning)} {
	set ans [tk_messageBox -title [::msgcat::mc Quit?] -type yesno  \
	  -default yes -message [::msgcat::mc messdoquit?]]
	if {$ans == "no"} {
	    return $ans
	}
    }
    
    # Run all quit hooks.
    hooks::run quitAppHook
    

            
    # If we used 'Edit/Revert To/Application Defaults' be sure to reset...
    set prefs(firstLaunch) 0
        
    # If we are a jabber client, put us unavailable, logout, etc.
    if {[string equal $prefs(protocol) "jabber"]} {
	::Jabber::EndSession
    }
    
    # Delete widgets with sounds.
    ::Sounds::Free
    ::Dialogs::Free
     
    if {[string equal $prefs(protocol) "jabber"]} {
	
	# Same for pane positions.
	set prefs(paneGeom) [::Jabber::GetAllPanePos] 
    }
    
    # Save to the preference file and quit...
    ::PreferencesUtils::SaveToFile
    ::Theme::SavePrefsFile
    
    # Should we clean up our 'incoming' directory?
    if {$prefs(clearCacheOnQuit)} {
	file delete -force -- $prefs(incomingPath)
	file mkdir $prefs(incomingPath)
    }
    
    # Cleanup. Beware, no windows with open movies must exist here!
    file delete -force $this(tmpPath)
    exit
}

#-------------------------------------------------------------------------------
