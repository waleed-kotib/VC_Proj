#  CanvasText.tcl ---
#  
#      This file is part of the whiteboard application. It implements the
#      text commands associated with the text tool.
#      
#  Copyright (c) 2000-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: CanvasText.tcl,v 1.2 2003-01-11 16:16:09 matben Exp $

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
#       c      the canvas widget.
#       
# Results:
#       none

# Could this be done with 'bindtags' instead???

proc ::CanvasText::EditBind {c} {
    global  this
    
    # Should add virtual events...
    #	bind $c <<Cut>> {
    #	::CanvasCCP::CanvasTextCopy %W; Delete %W
    #	}
    #	bind $c <<Copy>> {
    #	::CanvasCCP::CanvasTextCopy %W
    #	}
    #	bind $c <<Paste>> {
    #	::CanvasCCP::CanvasTextPaste %W
    #	}
    bind $c <Button-1> {
	::CanvasText::CanvasFocus %W [%W canvasx %x] [%W canvasy %y]
    }
    bind $c <Button-2> {
	::CanvasCCP::CanvasTextPaste %W [%W canvasx %x] [%W canvasy %y]
    }
    $c bind text <Button-1> {
	::CanvasText::Hit %W [%W canvasx %x] [%W canvasy %y]
    }
    $c bind text <B1-Motion> {
	::CanvasText::Drag %W [%W canvasx %x] [%W canvasy %y]
    }
    $c bind text <Double-Button-1> {
	::CanvasText::SelectWord %W [%W canvasx %x] [%W canvasy %y]
    }
    $c bind text <Delete> {
	::CanvasText::Delete %W
    }
    
    # Swallow any commands on mac's. 
    if {[string match "mac*" $this(platform)]} {
	$c bind text <Command-Any-Key> {# nothing}
	# Testing... for chinese input method...
	$c bind text <Command-t> {
	    break
	}
    }
    $c bind text <BackSpace> {
	::CanvasText::Delete %W
    }
    $c bind text <Return> {
	::CanvasText::NewLine %W
    }
    $c bind text <KeyPress> {
	::CanvasText::TextInsert %W %A
    }
    $c bind text <Key-Right> {
	::CanvasText::MoveRight %W
    }
    $c bind text <Key-Left> {
	::CanvasText::MoveLeft %W
    }

    # Ignore all Alt, Meta, and Control keypresses unless explicitly bound.
    # Otherwise, if a widget binding for one of these is defined, the
    # <KeyPress> class binding will also fire and insert the character,
    # which is wrong.  Ditto for Escape, and Tab.
    
    $c bind text <Alt-KeyPress> {# nothing}
    $c bind text <Meta-KeyPress> {# nothing}
    $c bind text <Control-KeyPress> {# nothing}
    $c bind text <Escape> {# nothing}
    $c bind text <KP_Enter> {# nothing}
    $c bind text <Tab> {# nothing}

    # Additional emacs-like bindings.
    $c bind text <Control-d> {
	::CanvasText::Delete %W 1
    }
    $c bind text <Control-a> {
	::CanvasText::InsertBegin %W
    }
    $c bind text <Control-e> {
	::CanvasText::InsertEnd %W
    }
    $c bind text <Control-Left> {
	::CanvasText::SetCursor %W [::CanvasText::PrevWord %W]
    }
    $c bind text <Control-Right> {
	::CanvasText::SetCursor %W [::CanvasText::NextWord %W]
    }
    $c bind text <Control-Up> {
	::CanvasText::SetCursor %W 0
    }
    $c bind text <Control-Down> {
	::CanvasText::SetCursor %W end
    }
    $c bind text <Home> {
	::CanvasText::InsertBegin %W
    }
    $c bind text <End> {
	::CanvasText::InsertEnd %W
    }
        
    # Need some new string functions here.
    if {[info tclversion] >= 8.2} {
	$c bind text <Key-Up> {
	    ::CanvasText::MoveUpOrDown %W up
	}
	$c bind text <Key-Down> {
	    ::CanvasText::MoveUpOrDown %W down
	}
    }
    
    # Stop certain keyboard accelerators from firing:
    bind $c <Control-a> {break}
}

# CanvasText::CanvasFocus --
#
#       Puts a text insert bar in the canvas. If already text item under 
#       the mouse then give focus to that item. If 'forceNew', then always 
#       make a new item.
#
# Arguments:
#       c      the canvas widget.
#       x,y    the mouse coordinates.
#       forceNew   make new item regardless if text item under the mouse.
#       
# Results:
#       none

proc ::CanvasText::CanvasFocus {c x y {forceNew 0}} {
    global  prefs fontSize2Points
    
    set wtop [::UI::GetToplevelNS $c]
    upvar ::${wtop}::state state

    focus $c
    set id [::CanvasUtils::FindTypeFromOverlapping $c $x $y "text"]

    Debug 2 "CanvasFocus:: id=$id"
    
    # If we have an unsent buffer, be sure to send it first.
    if {$prefs(batchText)} {
	DoSendBufferedText $wtop
    }
    if {($id == "") || ([$c type $id] != "text") || $forceNew} {
	
	# No text item under cursor, make a new empty text item.
	set utag [::CanvasUtils::NewUtag]
	set cmd [list create text $x $y -text ""   \
	  -tags [list text $utag] -anchor nw -fill $state(fgCol)]
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

	$c focus $utag
	$c select clear
	$c icursor $utag 0
    }
}

# CanvasText::TextInsert --
#
#       Inserts text string 'char' at the insert point of the text item
#       with focus. Handles newlines as well.
#
# Arguments:
#       c      the canvas widget.
#       char   the char or text string to insert.
#       
# Results:
#       none

proc ::CanvasText::TextInsert {c char} {
    global  allIPnumsToSend this prefs
        
    variable textBuffer
    variable indBuffer
    variable itnoBuffer
    
    set punct {[.,;?!]}
    set nl_ "\\n"
    
    # First, find out if there are any text item with focus.
    # If not, then make one.
    if {[llength [$c focus]] == 0} {
	
    }
    set wtop [::UI::GetToplevelNS $c]
    
    # Find the 'itno'.
    set utag [::CanvasUtils::GetUtag $c focus]
    if {$utag == "" || $char == ""}	 {
	Debug 4 "TextInsert:: utag == {}"
	return
    }
    set itfocus [$c focus]
    
    # The index of the insertion point.
    set ind [$c index $itfocus insert]

    # Mac text bindings: delete selection before inserting.
    if {[string match "mac*" $this(platform)] ||   \
      ($this(platform) == "windows")} {
	if {![catch {selection get} s]} {
	    if {[llength $s] > 0} {
		Delete $c
		selection clear
	    }
	}
    }
    
    # The actual canvas text insertion; note that 'ind' is found above.
    set cmd [list insert $itfocus insert $char]
    set undocmd [list dchars $utag $ind [expr $ind + [string length $char]]]
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]    
    eval {$c} $cmd
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
	    set theText [$c itemcget $utag -text]
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
# c -		The canvas window.
# pos -		The desired new position for the cursor in the text item.

proc ::CanvasText::SetCursor {c pos} {

    set foc [$c focus]
    $c select clear
    $c icursor $foc $pos
}

proc ::CanvasText::NextWord {c} {
    
    set id [$c focus]
    set str [$c itemcget $id -text]
    set ind [$c index $id insert]
    set next [tcl_startOfNextWord $str $ind]
    if {$next == -1} {
	set next end
    }
    return $next
}

proc ::CanvasText::PrevWord {c} {
    
    set id [$c focus]
    set str [$c itemcget $id -text]
    set ind [$c index $id insert]
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
#       c      the canvas widget.
#       
# Results:
#       none

proc ::CanvasText::MoveRight {c} {
    global  this
    
    set foc [$c focus]
    
    # Mac text bindings: remove selection then move insert to end.
    if {[string match "mac*" $this(platform)] ||  \
      $this(platform) == "windows"} {
	
	# If selection.
	if {![catch {selection get} s]} {
	    if {[llength $s] > 0} {
		$c icursor $foc [expr [$c index $foc sel.last] + 1]
		$c select clear
	    }
	} else {
	    $c icursor $foc [expr [$c index $foc insert] + 1]
	}
    } else {
	$c icursor $foc [expr [$c index $foc insert] + 1]
    }
}

# CanvasText::MoveLeft --
#
#       Move insert cursor one step to the left.
#
# Arguments:
#       c      the canvas widget.
#       
# Results:
#       none

proc ::CanvasText::MoveLeft {c} {
    global  this
    
    set foc [$c focus]
    
    # Mac text bindings: remove selection then move insert to first.
    if {[string match "mac*" $this(platform)] ||  \
      $this(platform) == "windows"} {
	
	# If selection.
	if {![catch {selection get} s]} {
	    if {[llength $s] > 0} {
		$c icursor $foc [expr [$c index $foc sel.first] + 0]
		$c select clear
	    }
	} else {
	    $c icursor $foc [expr [$c index $foc insert] - 1]
	}
    } else {
	$c icursor $foc [expr [$c index $foc insert] - 1]
    }
}

# CanvasText::MoveUpOrDown --
#
#       Move insert cursor one step up or down. 
#       Counts chars from line break, not optimal solution.
#
# Arguments:
#       c      the canvas widget.
#       upOrDown  "up" or "down".
#       
# Results:
#       none

proc ::CanvasText::MoveUpOrDown {c upOrDown} {
    
    set foc [$c focus]
    
    # Find index of new character. Only for left justified text.
    set ind [$c index $foc insert]
    set theText [$c itemcget $foc -text]

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
	$c icursor $foc $newInd
	
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
	$c icursor $foc $newInd
    }
}

proc ::CanvasText::InsertBegin {c} {
    
    set foc [$c focus]
    
    # Find index of new character. Only for left justified text.
    set ind [expr [$c index $foc insert] - 1]
    set theText [$c itemcget $foc -text]
    set indPrevNL [expr [string last \n $theText $ind] + 1]
    if {$indPrevNL == -1} {
	$c icursor $foc 0
    } else {
	$c icursor $foc $indPrevNL
    }
}

proc ::CanvasText::InsertEnd {c} {
    
    set foc [$c focus]
    
    # Find index of new character. Only for left justified text.
    set ind [$c index $foc insert]
    set theText [$c itemcget $foc -text]
    set indNextNL [string first \n $theText $ind]
    if {$indNextNL == -1} {
	$c icursor $foc end
    } else {
	$c icursor $foc $indNextNL
    }
}

# CanvasText::Hit --
#
#       Called when clicking a text item with the text tool selected.
#
# Arguments:
#       c      the canvas widget.
#       x,y    the mouse coordinates.
#       select   
#       
# Results:
#       none

proc ::CanvasText::Hit {c x y {select 1}} {

    Debug 2 "::CanvasText::Hit select=$select"

    $c focus current
    $c icursor current @$x,$y
    $c select clear
    $c select from current @$x,$y
}

# CanvasText::Drag --
#
#       Text selection when dragging the mouse over a text item.
#
# Arguments:
#       c      the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasText::Drag {c x y} {
    global  this
    
    set wtop [::UI::GetToplevelNS $c]
    ::UserActions::DeselectAll $wtop
    $c select to current @$x,$y
    
    # Mac text bindings.????
    if {[string match "mac*" $this(platform)]} {
	#$c focus
    }
    
    # menus
    ::UI::FixMenusWhenSelection $c
}

# CanvasText::SelectWord --
#
#       Typically selects wholw word when double clicking it.
#
# Arguments:
#       c      the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasText::SelectWord {c x y} {
    
    set wtop [::UI::GetToplevelNS $c]
    ::UserActions::DeselectAll $wtop
    $c focus current
    
    set id [$c find withtag current]
    if {$id == ""} {
	return
    }
    if {[$c type $id] != "text"} {
	return
    }
    set txt [$c itemcget $id -text]
    set ind [$c index $id @$x,$y]
    
    # Find the boundaries of the word and select word.
    $c select from $id [string wordstart $txt $ind]
    $c select adjust $id [expr [string wordend $txt $ind] - 1]
    
    # menus
    ::UI::FixMenusWhenSelection $c
}

# CanvasText::NewLine --
#
#       Insert a newline in a text item. Careful when sending it to remote
#       clients; double escaped.
#
# Arguments:
#       c      the canvas widget.
#       
# Results:
#       none

proc ::CanvasText::NewLine {c} {
    global  prefs
    
    variable textBuffer
    variable indBuffer

    set nl_ "\\n"
    set wtop [::UI::GetToplevelNS $c]
    
    # Find the 'utag'.
    set utag [::CanvasUtils::GetUtag $c focus]
    if {$utag == ""}	 {
	return
    }
    
    # If we are buffering text, be sure to send buffer now if any.
    if {$prefs(batchText)} {
	DoSendBufferedText $wtop
    }
    set ind [$c index [$c focus] insert]
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
#       c      the canvas widget.
#       offset (D=0) is 1 if we want to delete a character right of insertion
#              point (control-d)
#       
# Results:
#       none

proc ::CanvasText::Delete {c {offset 0}} {
    global  prefs
    
    Debug 2 "Delete"

    set idfocus [$c focus]
    set utag [::CanvasUtils::GetUtag $c focus]
    if {$utag == ""} {
	return
    }
    set wtop [::UI::GetToplevelNS $c]
	
    # If we have an unsent buffer, be sure to send it first.
    if {$prefs(batchText)} {
	DoSendBufferedText $wtop
    }
    
    if {[string length [$c select item]] > 0}	 {
	set sfirst [$c index $idfocus sel.first]
	set slast [$c index $idfocus sel.last]
	set thetext [$c itemcget $idfocus -text]
	set str [string range $thetext $sfirst $slast]
	set cmd [list dchars $utag $sfirst $slast]
	set undocmd [list insert $utag $sfirst $str]

    } elseif {$idfocus != {}} {
	set ind [expr [$c index $idfocus insert] - 1 + $offset]
	set thetext [$c itemcget $idfocus -text]
	set str [string index $thetext $ind]
	set cmd [list dchars $utag $ind]
	set undocmd [list insert $utag $ind $str]
    }
    if {[info exists cmd]} {
	set redo [list ::CanvasUtils::Command $wtop $cmd]
	set undo [list ::CanvasUtils::Command $wtop $undocmd]    
	eval {$c} $cmd
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

