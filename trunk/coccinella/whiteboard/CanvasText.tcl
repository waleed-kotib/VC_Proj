#  CanvasText.tcl ---
#  
#      This file is part of The Coccinella application. It implements the
#      text commands associated with the text tool.
#      
#  Copyright (c) 2000-2004  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: CanvasText.tcl,v 1.5 2004-11-07 14:22:58 matben Exp $

#  All code in this file is placed in one common namespace.

package require sha1pure

package provide CanvasText 1.0

namespace eval ::CanvasText:: {

    # Array that holds private stuff.
    variable priv
    set priv(font)  {}
    set priv(sha1)  {}
    set priv(magic) 069819a0dfa9f2171e86c03a281f43f208ac3516
}


proc ::CanvasText::Init {wcan} {
    
    namespace eval [namespace current]::${wcan} {
	set buffer(str) ""
    }
    bind $wcan <Destroy> [list [namespace current]::Free %W]
}

proc ::CanvasText::Free {wcan} {
    
    EvalBufferedText $wcan
    
    # Remove the namespace with the widget.
    namespace delete [namespace current]::${wcan}
}

# This could be done with 'bindtags' instead!!!!!!
 
# Perhaps canvas text item stuff should go in a more general package
# with specials like undo and network handling using callbacks.

# ::CanvasText::EditBind --
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
	::CanvasText::Insert %W %A
    }
    $w bind text <Right> {
	::CanvasText::MoveRight %W
    }
    $w bind text <Left> {
	::CanvasText::MoveLeft %W
    }
    $w bind text <Up> {
	::CanvasText::SetCursor %W [::CanvasText::UpDownLine %W -1]
    }
    $w bind text <Down> {
	::CanvasText::SetCursor %W [::CanvasText::UpDownLine %W 1]
    }
    $w bind text <Shift-Left> {
	::CanvasText::KeySelect %W [::CanvasText::PrevPos %W insert]
    }
    $w bind text <Shift-Right> {
	::CanvasText::KeySelect %W [::CanvasText::NextPos %W insert]
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
    
    # These may interfere with canvas widget bindings for scrolling.
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
}

# ::CanvasText::Copy --
#  
#       Just copies text from text items. If selected text, copy that,
#       else if text item has focus copy complete text item.
#       
# Arguments:
#       c      the canvas widget.
#       
# Results:
#       none

proc ::CanvasText::Copy {c} {
    variable priv
    
    Debug 2 "::CanvasText::Copy select item=[$c select item]"

    if {[$c select item] != {}}	 { 
	clipboard clear
	set t [$c select item]
	set text [$c itemcget $t -text]
	set start [$c index $t sel.first]
	set end [$c index $t sel.last]
	set str [string range $text $start $end]
	clipboard append $str
	
	# Keep track of font in clipboard and a hash to see if changed
	# before pasting it.
	set priv(font) [$c itemcget $t -font]
	set priv(sha1) [sha1pure::sha1 "$priv(magic)$str"]
	#OwnClipboard $c
    }
    puts "priv(font)=$priv(font) "
}

proc ::CanvasText::OwnClipboard {c} {
    
    # this creates some weird behaviour???
    selection own -command [list [namespace current]::LostClipboard $c] \
      -selection CLIPBOARD $c
}

proc ::CanvasText::LostClipboard {c} {
    variable priv
    
    puts "::CanvasText::LostClipboard"
    set priv(font) {}
}

# ::CanvasText::SetFocus --
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

proc ::CanvasText::SetFocus {w x y {forceNew 0}} {
    global  prefs fontSize2Points
    
    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    focus $w
    set id [::CanvasUtils::FindTypeFromOverlapping $w $x $y "text"]

    Debug 2 "SetFocus:: id=$id"
    
    # If we have an unsent buffer, be sure to send it first.
    if {$prefs(batchText)} {
	EvalBufferedText $w
    }
    if {($id == "") || ([$w type $id] != "text") || $forceNew} {
	
	# No text item under cursor, make a new empty text item.
	set utag [::CanvasUtils::NewUtag]
	set y [expr $y - [font metrics [list $state(font)] -linespace]/2]
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
	set cmdlocal  [concat $cmd -font [list $fontsLocal]]
	set cmdremote [concat $cmd -font [list $fontsRemote]]
	set undocmd   [list delete $utag]

	set redo [list ::CanvasUtils::CommandExList $wtop  \
	  [list [list $cmdlocal local] [list $cmdremote remote]]]
	set undo [list ::CanvasUtils::Command $wtop $undocmd]
	eval $redo
	undo::add [::WB::GetUndoToken $wtop] $undo $redo

	$w focus $utag
	$w select clear
	$w icursor $utag 0
    }
}

# ::CanvasText::Insert --
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

proc ::CanvasText::Insert {w char} {
    global  this prefs
    variable priv
        
    upvar ::CanvasText::${w}::buffer buffer
        
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
	Debug 4 "Insert:: utag == {}"
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
    
    # If this is an empty text item then reuse any cached font.
    if {([$w itemcget $itfocus -text] == "") && ($priv(font) != {})} {
	if {[string equal $priv(sha1) [sha1pure::sha1 "$priv(magic)$char"]]} {
	    ::CanvasUtils::ItemConfigure $w $itfocus -font $priv(font)
	}
    }
    
    # The actual canvas text insertion; note that 'ind' is found above.
    set cmd [list insert $itfocus insert $char]
    set undocmd [list dchars $utag $ind [expr $ind + [string length $char]]]
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]    
    eval {$w} $cmd
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
        
    Debug 9 "\t utag = $utag, ind = $ind, char: $char"
    
    # Need to treat the case with actual newlines in char string.
    # Write to all other clients; need to make a one liner first.
    regsub -all "\n" $char $nl_ oneliner
    if {$prefs(batchText)} {	
	if {[string length $buffer(str)] == 0} {
	    set buffer(ind)  $ind
	    set buffer(utag) $utag
	}
	append buffer(str) $oneliner
	
	if {[string match *${punct}* $char]} {
	    EvalBufferedText $w
	} else {
	    ScheduleTextBuffer $w
	}
    } else {
	::WB::SendMessageList $wtop [list [list insert $utag $ind $oneliner]]
    }
}

# ::CanvasText::SetCursor --
# 
# 
#
# Arguments:
# w -		The canvas window.
# pos -		The desired new position for the cursor in the text item.

proc ::CanvasText::SetCursor {w pos} {

    set id [$w focus]
    $w select clear
    $w icursor $id $pos
}

proc ::CanvasText::PrevPos {w pos} {
    
    set id [$w focus]
    set ind [$w index $id $pos]
    if {$ind == 0} {
	return 0
    } else {
	return [expr {$ind-1}]
    }
}

proc ::CanvasText::NextPos {w pos} {
    
    set id [$w focus]
    set str [$w itemcget $id -text]
    set ind [$w index $id $pos]
    if {$ind == [string length $str]} {
	return $ind
    } else {
	return [expr {$ind+1}]
    }
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

# ::CanvasText::MoveRight --
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

# ::CanvasText::MoveLeft --
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
      [string equal $this(platform) "windows"]} {
	
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

# Find index of new character. Only for left justified text.

proc ::CanvasText::UpDownLine {w dir} {
    
    set id [$w focus]
    set ind [$w index $id insert]
    set str [$w itemcget $id -text]
    
    # Up one line.
    if {$dir == -1} {
	set prevNL  [string last \n $str [expr {$ind - 1}]]
	set prev2NL [string last \n $str [expr {$prevNL - 1}]]
	
	# If first line.
	if {$prevNL == -1} {
	    return $ind
	}
	set ncharLeft [expr {$ind - $prevNL - 1}]
	set new [min [expr {$prev2NL + $ncharLeft + 1}] $prevNL]
    } else {
	
	# Down one line.
	set prevNL  [string last \n $str [expr $ind - 1]]
	set nextNL  [string first \n $str [expr $prevNL + 1]]
	set next2NL [string first \n $str [expr $nextNL + 1]]
	
	# If last line.
	if {$nextNL == -1} {
	    return $ind
	}
	set ncharLeft [expr {$ind - $prevNL - 1}]
	if {$next2NL == -1} {
	    set new [expr {$nextNL + $ncharLeft + 1}]
	} else {
	    set new [min [expr {$nextNL + $ncharLeft + 1}] $next2NL]
	}
    }
    return $new
}

# ::CanvasText::KeySelect --
# 
#       It moves the cursor to the new position, then extends the selection
#       to that position.

proc ::CanvasText::KeySelect {w new} {
    
    set id [$w focus]
    set insert [$w index $id insert]
    if {$new == $insert} {
	return
    }
    if {[$w select item] == ""} {
	$w select from $id insert
	if {$new >= $insert} {
	    $w select to $id [expr {$new - 1}]
	} else {
	    $w select to $id $new 
	}
    } else {
	set first [$w index $id sel.first]
	set last  [$w index $id sel.last]
	incr last
	set right  [expr {$new > $insert} ? 1 : 0]
	set inside [expr {($new >= $first) && ($new <= $last)} ? 1 : 0]
	if {$new == $first} {
	    $w select clear
	} elseif {$new == $last && $right} {
	    $w select clear
	} else {
	    if {$new >= $first} {
		if {$right && $inside} {
		    set to $new
		} else {
		    set to [expr {$new - 1}]
		}
	    } else {
		set to $new
	    }
	    $w select to $id $to
	}
    }
    $w icursor $id $new
}

proc ::CanvasText::InsertBegin {w} {
    
    set foc [$w focus]
    
    # Find index of new character. Only for left justified text.
    set ind [expr [$w index $foc insert] - 1]
    set str [$w itemcget $foc -text]
    set prevNL [expr [string last \n $str $ind] + 1]
    if {$prevNL == -1} {
	$w icursor $foc 0
    } else {
	$w icursor $foc $prevNL
    }
}

proc ::CanvasText::InsertEnd {w} {
    
    set foc [$w focus]
    
    # Find index of new character. Only for left justified text.
    set ind [$w index $foc insert]
    set str [$w itemcget $foc -text]
    set nextNL [string first \n $str $ind]
    if {$nextNL == -1} {
	$w icursor $foc end
    } else {
	$w icursor $foc $nextNL
    }
}

# ::CanvasText::Hit --
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

# ::CanvasText::Drag --
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
    ::CanvasCmd::DeselectAll $wtop
    $w select to current @$x,$y
    
    # Mac text bindings.????
    if {[string match "mac*" $this(platform)]} {
	#$w focus
    }
    
    # menus
    ::UI::FixMenusWhenSelection $w
}

# ::CanvasText::SelectWord --
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
    ::CanvasCmd::DeselectAll $wtop
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
    $w select from   $id [string wordstart $txt $ind]
    $w select adjust $id [expr [string wordend $txt $ind] - 1]
    
    # menus
    ::UI::FixMenusWhenSelection $w
}

# ::CanvasText::NewLine --
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
    
    set nl_ "\\n"
    set wtop [::UI::GetToplevelNS $w]
    
    # Find the 'utag'.
    set utag [::CanvasUtils::GetUtag $w focus]
    if {$utag == ""}	 {
	return
    }
    
    # If we are buffering text, be sure to send buffer now if any.
    if {$prefs(batchText)} {
	EvalBufferedText $w
    }
    set ind [$w index [$w focus] insert]
    set cmdlocal [list insert $utag $ind \n]
    set cmdremote [list insert $utag $ind $nl_]
    set undocmd [list dchars $utag $ind]
    set redo [list ::CanvasUtils::CommandExList $wtop  \
      [list [list $cmdlocal local] [list $cmdremote remote]]]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
}

# ::CanvasText::Delete --
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
    variable priv
    
    Debug 2 "::CanvasText::Delete"

    set idfocus [$w focus]
    set utag [::CanvasUtils::GetUtag $w focus]
    if {$utag == ""} {
	return
    }
    set wtop [::UI::GetToplevelNS $w]
	
    # If we have an unsent buffer, be sure to send it first.
    if {$prefs(batchText)} {
	EvalBufferedText $w
    }
    
    if {[$w select item] != ""} {
	set sfirst [$w index $idfocus sel.first]
	set slast [$w index $idfocus sel.last]
	set str [$w itemcget $idfocus -text]
	set str [string range $str $sfirst $slast]
	set cmd [list dchars $utag $sfirst $slast]
	set undocmd [list insert $utag $sfirst $str]
    } elseif {$idfocus != {}} {
	set ind [expr [$w index $idfocus insert] - 1 + $offset]
	set str [$w itemcget $idfocus -text]
	set str [string index $str $ind]
	set cmd [list dchars $utag $ind]
	set undocmd [list insert $utag $ind $str]
    }
    if {[info exists cmd]} {
	set redo [list ::CanvasUtils::Command $wtop $cmd]
	set undo [list ::CanvasUtils::Command $wtop $undocmd]    
	eval $redo
	undo::add [::WB::GetUndoToken $wtop] $undo $redo
    }
}

# ::CanvasText::Paste --
#
#       Unix style paste using button 2.
#       
# Arguments:
#       c      the canvas widget.
#       x,y
#       
# Results:
#       none

proc ::CanvasText::Paste {c {x {}} {y {}}} {
    
    Debug 2 "::CanvasText::Paste"
    
    # If no selection just return.
    if {[catch {selection get} _s] &&   \
      [catch {selection get -selection CLIPBOARD} _s]} {
	Debug 2 "\t no selection"
	return
    }
    Debug 2 "\t CanvasTextPaste:: selection=$_s"
    
    # Once the text string is found use...
    Insert $c $_s
}

# ::CanvasText::ScheduleTextBuffer --
#
#       Schedules a send operation for our text inserts.
#       
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       none.

proc ::CanvasText::ScheduleTextBuffer {w} {
    global  prefs
    
    upvar ::CanvasText::${w}::buffer buffer
    
    if {[info exists buffer(afterid)]} {
	after cancel $buffer(afterid)
    }
    set buffer(afterid) [after [expr $prefs(batchTextms)]   \
      [list [namespace current]::EvalBufferedText $w]]
}

# ::CanvasText::EvalBufferedText --
#
#       This is the proc where buffered text are sent to clients.
#       Buffer emptied.
#       
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       any registered send message hook invoked.

proc ::CanvasText::EvalBufferedText {w} {

    upvar ::CanvasText::${w}::buffer buffer
    
    if {[info exists buffer(afterid)]} {
	after cancel $buffer(afterid)
	unset buffer(afterid)
    }
    
    # Run all registered hooks like speech.
    if {[info exists buffer(utag)] && [string length $buffer(str)]} {
	set str [$w itemcget $buffer(utag) -text]
	::hooks::run whiteboardTextInsertHook me $str
    }
    
    if {[string length $buffer(str)]} {
	set wtop [::UI::GetToplevelNS $w]
	::WB::SendMessageList $wtop  \
	  [list [list insert $buffer(utag) $buffer(ind) $buffer(str)]]
    }    
    set buffer(str) ""
}

#-------------------------------------------------------------------------------

