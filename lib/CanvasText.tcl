#  CanvasText.tcl ---
#  
#      This file is part of the whiteboard application. It implements the
#      text commands associated with the text tool.
#      
#  Copyright (c) 2000-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: CanvasText.tcl,v 1.6 2003-09-28 06:29:08 matben Exp $

#  All code in this file is placed in one common namespace.

package provide CanvasText 1.0

namespace eval ::CanvasText:: {

    # For batched text.
    variable textBuffer ""
    variable textAfterID
    # The index of the insertion point.
    variable indBuffer
    variable itnoBuffer
    
}

# This could be done with 'bindtags' instead!!!!!!

# CanvasText::EditBind --
#
#       Sets up all canvas and canvas text item bindings.
#       Typically when the user clicks the text tool button.
#       
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       none

# Could this be done with 'bindtags' instead???

proc ::CanvasText::EditBind {w} {
    global  this
    
    $w bind text <Button-1> {
	::CanvasText::Hit %W [%W canvasx %x] [%W canvasy %y]
    }
    $w bind text <B1-Motion> {
	::CanvasText::Drag %W [%W canvasx %x] [%W canvasy %y]
    }
    $w bind text <Double-Button-1> {
	::CanvasText::SelectWord %W [%W canvasx %x] [%W canvasy %y]
    }
    $w bind text <Delete> {
	::CanvasText::Delete %W
    }
    
    # Swallow any commands on mac's. 
    if {[string match "mac*" $this(platform)]} {
	$w bind text <Command-Any-Key> {# nothing}
	# Testing... for chinese input method...
	$w bind text <Command-t> {
	    break
	}
    }
    $w bind text <BackSpace> {
	::CanvasText::Delete %W
    }
    $w bind text <Return> {
	::CanvasText::NewLine %W
    }
    $w bind text <KeyPress> {
	::CanvasText::TextInsert %W %A
    }
    $w bind text <Key-Right> {
	::CanvasText::MoveRight %W
    }
    $w bind text <Key-Left> {
	::CanvasText::MoveLeft %W
    }

    # Ignore all Alt, Meta, and Control keypresses unless explicitly bound.
    # Otherwise, if a widget binding for one of these is defined, the
    # <KeyPress> class binding will also fire and insert the character,
    # which is wrong.  Ditto for Escape, and Tab.
    
    $w bind text <Alt-KeyPress> {# nothing}
    $w bind text <Meta-KeyPress> {# nothing}
    $w bind text <Control-KeyPress> {# nothing}
    $w bind text <Escape> {# nothing}
    $w bind text <KP_Enter> {# nothing}
    $w bind text <Tab> {# nothing}

    # Additional emacs-like bindings.
    $w bind text <Control-d> {
	::CanvasText::Delete %W 1
    }
    $w bind text <Control-a> {
	::CanvasText::InsertBegin %W
    }
    $w bind text <Control-e> {
	::CanvasText::InsertEnd %W
    }
    $w bind text <Control-Left> {
	::CanvasText::SetCursor %W [::CanvasText::PrevWord %W]
    }
    $w bind text <Control-Right> {
	::CanvasText::SetCursor %W [::CanvasText::NextWord %W]
    }
    $w bind text <Control-Up> {
	::CanvasText::SetCursor %W 0
    }
    $w bind text <Control-Down> {
	::CanvasText::SetCursor %W end
    }
    $w bind text <Home> {
	::CanvasText::InsertBegin %W
    }
    $w bind text <End> {
	::CanvasText::InsertEnd %W
    }
        
    # Need some new string functions here.
    $w bind text <Key-Up> {
	::CanvasText::MoveUpOrDown %W up
    }
    $w bind text <Key-Down> {
	::CanvasText::MoveUpOrDown %W down
    }
}

# CanvasText::CanvasFocus --
#
#       Puts a text insert bar in the canvas. If already text item under 
#       the mouse then give focus to that item. If 'forceNew', then always 
#       make a new item.
#
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       forceNew   make new item regardless if text item under the mouse.
#       
# Results:
#       none

proc ::CanvasText::CanvasFocus {w x y {forceNew 0}} {
    global  prefs fontSize2Points
    
    set wtop [::UI::GetToplevelNS $w]
    upvar ::${wtop}::state state

    focus $w
    set id [::CanvasUtils::FindTypeFromOverlapping $w $x $y "text"]

    Debug 2 "CanvasFocus:: id=$id"
    
    # If we have an unsent buffer, be sure to send it first.
    if {$prefs(batchText)} {
	DoSendBufferedText $wtop
    }
    if {($id == "") || ([$w type $id] != "text") || $forceNew} {
	
	# No text item under cursor, make a new empty text item.
	set utag [::CanvasUtils::NewUtag]
	set cmd [list create text $x $y -text ""   \
	  -tags [list std text $utag] -anchor nw -fill $state(fgCol)]
	set fontsLocal [list $state(font) $fontSize2Points($state(fontSize)) \
	  $state(fontWeight)]
	
	# If 'useHtmlSizes', then transport the html sizes instead of point sizes.
	if {$prefs(useHtmlSizes)} {
	    set fontsRemote  \
	      [list $state(font) $state(fontSize) $state(fontWeight)]
	} else {
	    set fontsRemote $fontsLocal
	}
	set cmdlocal [concat $cmd -font [list $fontsLocal]]
	set cmdremote [concat $cmd -font [list $fontsRemote]]
	set undocmd "delete $utag"

	set redo [list ::CanvasUtils::CommandExList $wtop  \
	  [list [list $cmdlocal "local"] [list $cmdremote "remote"]]]
	set undo [list ::CanvasUtils::Command $wtop $undocmd]
	eval $redo
	undo::add [::UI::GetUndoToken $wtop] $undo $redo

	$w focus $utag
	$w select clear
	$w icursor $utag 0
    }
}

# CanvasText::TextInsert --
#
#       Inserts text string 'char' at the insert point of the text item
#       with focus. Handles newlines as well.
#
# Arguments:
#       w      the canvas widget.
#       char   the char or text string to insert.
#       
# Results:
#       none

proc ::CanvasText::TextInsert {w char} {
    global  allIPnumsToSend this prefs
        
    variable textBuffer
    variable indBuffer
    variable itnoBuffer
    
    set punct {[.,;?!]}
    set nl_ "\\n"
    
    # First, find out if there are any text item with focus.
    # If not, then make one.
    if {[$w focus] == ""} {
	
    }
    set wtop [::UI::GetToplevelNS $w]
    
    # Find the 'itno'.
    set utag [::CanvasUtils::GetUtag $w focus]
    if {$utag == "" || $char == ""}	 {
	Debug 4 "TextInsert:: utag == {}"
	return
    }
    set itfocus [$w focus]
    
    # The index of the insertion point.
    set ind [$w index $itfocus insert]

    # Mac text bindings: delete selection before inserting.
    if {[string match "mac*" $this(platform)] ||   \
      ($this(platform) == "windows")} {
	if {![catch {selection get} s]} {
	    if {$s != ""} {
		Delete $w
		selection clear
	    }
	}
    }
    
    # The actual canvas text insertion; note that 'ind' is found above.
    set cmd [list insert $itfocus insert $char]
    set undocmd [list dchars $utag $ind [expr $ind + [string length $char]]]
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]    
    eval {$w} $cmd
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
        
    Debug 9 "TextInsert:: utag = $utag, ind = $ind, char: $char"
    
    # Need to treat the case with actual newlines in char string.
    # Write to all other clients; need to make a one liner first.
    if {[llength $allIPnumsToSend]} {
	regsub -all "\n" $char $nl_ oneliner
	if {$prefs(batchText)} {
	    
	    # If this is the beginning of the buffer, record the index.
	    if {[string length $textBuffer] == 0} {
		set indBuffer $ind
		set itnoBuffer $utag
	    }
	    append textBuffer $oneliner
	    if {[string match *${punct}* $char]} {
		DoSendBufferedText $wtop
	    } else {
		ScheduleTextInsert $wtop
	    }
	} else {
	    SendClientCommand $wtop \
	      [list "CANVAS:" insert $utag $ind $oneliner]
	}
    }
    
    # If speech, speech last sentence if finished.
    # Use the default voice on this system.
    if {$prefs(SpeechOn)} {
	if {[string match *${punct}* $char]} {
	    set theText [$w itemcget $utag -text]
	    if {[string length $theText]} {
		::UserActions::Speak $theText $prefs(voiceUs)
	    }
	}
    }
}

# CanvasText::SetCursor --
# 
# 
#
# Arguments:
# w -		The canvas window.
# pos -		The desired new position for the cursor in the text item.

proc ::CanvasText::SetCursor {w pos} {

    set foc [$w focus]
    $w select clear
    $w icursor $foc $pos
}

proc ::CanvasText::NextWord {w} {
    
    set id [$w focus]
    set str [$w itemcget $id -text]
    set ind [$w index $id insert]
    set next [tcl_startOfNextWord $str $ind]
    if {$next == -1} {
	set next end
    }
    return $next
}

proc ::CanvasText::PrevWord {w} {
    
    set id [$w focus]
    set str [$w itemcget $id -text]
    set ind [$w index $id insert]
    set prev [tcl_startOfPreviousWord $str $ind]
    if {$prev == -1} {
	set prev 0
    }
    return $prev
}

# CanvasText::MoveRight --
#
#       Move insert cursor one step to the right.
#
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       none

proc ::CanvasText::MoveRight {w} {
    global  this
    
    set foc [$w focus]
    
    # Mac text bindings: remove selection then move insert to end.
    if {[string match "mac*" $this(platform)] ||  \
      $this(platform) == "windows"} {
	
	# If selection.
	if {![catch {selection get} s]} {
	    if {$s != ""} {
		$w icursor $foc [expr [$w index $foc sel.last] + 1]
		$w select clear
	    }
	} else {
	    $w icursor $foc [expr [$w index $foc insert] + 1]
	}
    } else {
	$w icursor $foc [expr [$w index $foc insert] + 1]
    }
}

# CanvasText::MoveLeft --
#
#       Move insert cursor one step to the left.
#
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       none

proc ::CanvasText::MoveLeft {w} {
    global  this
    
    set foc [$w focus]
    
    # Mac text bindings: remove selection then move insert to first.
    if {[string match "mac*" $this(platform)] ||  \
      $this(platform) == "windows"} {
	
	# If selection.
	if {![catch {selection get} s]} {
	    if {$s != ""} {
		$w icursor $foc [expr [$w index $foc sel.first] + 0]
		$w select clear
	    }
	} else {
	    $w icursor $foc [expr [$w index $foc insert] - 1]
	}
    } else {
	$w icursor $foc [expr [$w index $foc insert] - 1]
    }
}

# CanvasText::MoveUpOrDown --
#
#       Move insert cursor one step up or down. 
#       Counts chars from line break, not optimal solution.
#
# Arguments:
#       w      the canvas widget.
#       upOrDown  "up" or "down".
#       
# Results:
#       none

proc ::CanvasText::MoveUpOrDown {w upOrDown} {
    
    set foc [$w focus]
    
    # Find index of new character. Only for left justified text.
    set ind [$w index $foc insert]
    set theText [$w itemcget $foc -text]

    if {[string equal $upOrDown "up"]} {
	
	# Up one line. String operations.
	set indPrevNL [string last \n $theText [expr $ind - 1]]
	set indPrev2NL [string last \n $theText [expr $indPrevNL - 1]]
	
	# If first line.
	if {$indPrevNL == -1} {
	    return
	}
	set ncharLeft [expr $ind - $indPrevNL - 1]
	set newInd [min [expr $indPrev2NL + $ncharLeft + 1] $indPrevNL]
	$w icursor $foc $newInd
	
    } else {
	
	# Down one line.
	set indPrevNL [string last \n $theText [expr $ind - 1]]
	set indNextNL [string first \n $theText [expr $indPrevNL + 1]]
	set indNext2NL [string first \n $theText [expr $indNextNL + 1]]
	
	# If last line.
	if {$indNextNL == -1} {
	    return
	}
	set ncharLeft [expr $ind - $indPrevNL - 1]
	if {$indNext2NL == -1} {
	    
	    # Move to last line.
	    set newInd [expr $indNextNL + $ncharLeft + 1]
	} else {
	    set newInd [min [expr $indNextNL + $ncharLeft + 1] $indNext2NL]
	}
	$w icursor $foc $newInd
    }
}

proc ::CanvasText::InsertBegin {w} {
    
    set foc [$w focus]
    
    # Find index of new character. Only for left justified text.
    set ind [expr [$w index $foc insert] - 1]
    set theText [$w itemcget $foc -text]
    set indPrevNL [expr [string last \n $theText $ind] + 1]
    if {$indPrevNL == -1} {
	$w icursor $foc 0
    } else {
	$w icursor $foc $indPrevNL
    }
}

proc ::CanvasText::InsertEnd {w} {
    
    set foc [$w focus]
    
    # Find index of new character. Only for left justified text.
    set ind [$w index $foc insert]
    set theText [$w itemcget $foc -text]
    set indNextNL [string first \n $theText $ind]
    if {$indNextNL == -1} {
	$w icursor $foc end
    } else {
	$w icursor $foc $indNextNL
    }
}

# CanvasText::Hit --
#
#       Called when clicking a text item with the text tool selected.
#
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       select   
#       
# Results:
#       none

proc ::CanvasText::Hit {w x y {select 1}} {

    Debug 2 "::CanvasText::Hit select=$select"

    $w focus current
    $w icursor current @$x,$y
    $w select clear
    $w select from current @$x,$y
}

# CanvasText::Drag --
#
#       Text selection when dragging the mouse over a text item.
#
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasText::Drag {w x y} {
    global  this
    
    set wtop [::UI::GetToplevelNS $w]
    ::UserActions::DeselectAll $wtop
    $w select to current @$x,$y
    
    # Mac text bindings.????
    if {[string match "mac*" $this(platform)]} {
	#$w focus
    }
    
    # menus
    ::UI::FixMenusWhenSelection $w
}

# CanvasText::SelectWord --
#
#       Typically selects wholw word when double clicking it.
#
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasText::SelectWord {w x y} {
    
    set wtop [::UI::GetToplevelNS $w]
    ::UserActions::DeselectAll $wtop
    $w focus current
    
    set id [$w find withtag current]
    if {$id == ""} {
	return
    }
    if {[$w type $id] != "text"} {
	return
    }
    set txt [$w itemcget $id -text]
    set ind [$w index $id @$x,$y]
    
    # Find the boundaries of the word and select word.
    $w select from $id [string wordstart $txt $ind]
    $w select adjust $id [expr [string wordend $txt $ind] - 1]
    
    # menus
    ::UI::FixMenusWhenSelection $w
}

# CanvasText::NewLine --
#
#       Insert a newline in a text item. Careful when sending it to remote
#       clients; double escaped.
#
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       none

proc ::CanvasText::NewLine {w} {
    global  prefs
    
    variable textBuffer
    variable indBuffer

    set nl_ "\\n"
    set wtop [::UI::GetToplevelNS $w]
    
    # Find the 'utag'.
    set utag [::CanvasUtils::GetUtag $w focus]
    if {$utag == ""}	 {
	return
    }
    
    # If we are buffering text, be sure to send buffer now if any.
    if {$prefs(batchText)} {
	DoSendBufferedText $wtop
    }
    set ind [$w index [$w focus] insert]
    set cmdlocal [list insert $utag $ind \n]
    set cmdremote [list insert $utag $ind $nl_]
    set undocmd [list dchars $utag $ind]
    set redo [list ::CanvasUtils::CommandExList $wtop  \
      [list [list $cmdlocal "local"] [list $cmdremote "remote"]]]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
}

# CanvasText::Delete --
#
#       Called when doing text 'cut' or pressing the Delete key.
#       A backspace if selected text deletes that text.
#       A backspace if text item has focus deletes text left of insert cursor.
#
# Arguments:
#       w      the canvas widget.
#       offset (D=0) is 1 if we want to delete a character right of insertion
#              point (control-d)
#       
# Results:
#       none

proc ::CanvasText::Delete {w {offset 0}} {
    global  prefs
    
    Debug 2 "::CanvasText::Delete"

    set idfocus [$w focus]
    set utag [::CanvasUtils::GetUtag $w focus]
    if {$utag == ""} {
	return
    }
    set wtop [::UI::GetToplevelNS $w]
	
    # If we have an unsent buffer, be sure to send it first.
    if {$prefs(batchText)} {
	DoSendBufferedText $wtop
    }
    
    if {[string length [$w select item]] > 0}	 {
	set sfirst [$w index $idfocus sel.first]
	set slast [$w index $idfocus sel.last]
	set thetext [$w itemcget $idfocus -text]
	set str [string range $thetext $sfirst $slast]
	set cmd [list dchars $utag $sfirst $slast]
	set undocmd [list insert $utag $sfirst $str]

    } elseif {$idfocus != {}} {
	set ind [expr [$w index $idfocus insert] - 1 + $offset]
	set thetext [$w itemcget $idfocus -text]
	set str [string index $thetext $ind]
	set cmd [list dchars $utag $ind]
	set undocmd [list insert $utag $ind $str]
    }
    if {[info exists cmd]} {
	set redo [list ::CanvasUtils::Command $wtop $cmd]
	set undo [list ::CanvasUtils::Command $wtop $undocmd]    
	eval $redo
	undo::add [::UI::GetUndoToken $wtop] $undo $redo
    }
}

# CanvasText::ScheduleTextInsert --
#
#       Schedules a send operation for our text inserts.
#       
# Arguments:
#       
# Results:
#       none.

proc ::CanvasText::ScheduleTextInsert {wtop} {
    global  prefs
    
    variable textAfterID
    
    if {[info exists textAfterID]} {
	after cancel $textAfterID
    }
    set textAfterID [after [expr $prefs(batchTextms)]   \
      [list [namespace current]::DoSendBufferedText $wtop]]
}

# CanvasText::DoSendBufferedText --
#
#       This is the proc where buffered text are sent to clients.
#       Buffer emptied.
#       
# Arguments:
#       
# Results:
#       socket(s) written via 'SendClientCommand'.

proc ::CanvasText::DoSendBufferedText {wtop} {
    global  allIPnumsToSend
    
    variable textAfterID
    variable textBuffer
    variable indBuffer
    variable itnoBuffer

    if {[info exists textAfterID]} {
	after cancel $textAfterID
	unset textAfterID
    }
    if {[llength $allIPnumsToSend] && [string length $textBuffer]} {
	SendClientCommand $wtop   \
	  [list "CANVAS:" insert $itnoBuffer $indBuffer $textBuffer]
    }    
    set textBuffer ""
}

#-------------------------------------------------------------------------------

