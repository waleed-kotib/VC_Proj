#  CanvasText.tcl ---
#  
#      This file is part of The Coccinella application. It implements the
#      text commands associated with the text tool.
#      
#  Copyright (c) 2000-2005  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: CanvasText.tcl,v 1.14 2007-07-19 06:28:19 matben Exp $

package require sha1

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
	set buffer(str)  ""
	set buffer(text) ""
    }
    # @@@ window destroyed before this!
    bind $wcan <Destroy> [list [namespace current]::OnDestroy %W]
}

proc ::CanvasText::OnDestroy {wcan} {
    
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
#       wcan   the canvas widget.
#       
# Results:
#       none

# Could this be done with 'bindtags' instead???

proc ::CanvasText::EditBind {wcan} {
    global  this
    
    $wcan bind text <Button-1> {
	::CanvasText::Hit %W [%W canvasx %x] [%W canvasy %y]
    }
    $wcan bind text <B1-Motion> {
	::CanvasText::Drag %W [%W canvasx %x] [%W canvasy %y]
    }
    $wcan bind text <Double-Button-1> {
	::CanvasText::SelectWord %W [%W canvasx %x] [%W canvasy %y]
    }
    $wcan bind text <Delete> {
	::CanvasText::Delete %W
    }
    
    # Swallow any commands on mac's. 
    if {[string match "mac*" $this(platform)]} {
	$wcan bind text <Command-Any-Key> {# nothing}
	# Testing... for chinese input method...
	$wcan bind text <Command-t> {
	    break
	}
    }
    $wcan bind text <BackSpace> {
	::CanvasText::Delete %W
    }
    $wcan bind text <Return> {
	::CanvasText::NewLine %W
    }
    $wcan bind text <KeyPress> {
	::CanvasText::Insert %W %A
    }
    $wcan bind text <Right> {
	::CanvasText::MoveRight %W
    }
    $wcan bind text <Left> {
	::CanvasText::MoveLeft %W
    }
    $wcan bind text <Up> {
	::CanvasText::SetCursor %W [::CanvasText::UpDownLine %W -1]
    }
    $wcan bind text <Down> {
	::CanvasText::SetCursor %W [::CanvasText::UpDownLine %W 1]
    }
    $wcan bind text <Shift-Left> {
	::CanvasText::KeySelect %W [::CanvasText::PrevPos %W insert]
    }
    $wcan bind text <Shift-Right> {
	::CanvasText::KeySelect %W [::CanvasText::NextPos %W insert]
    }

    # Ignore all Alt, Meta, and Control keypresses unless explicitly bound.
    # Otherwise, if a widget binding for one of these is defined, the
    # <KeyPress> class binding will also fire and insert the character,
    # which is wrong.  Ditto for Escape, and Tab.
    
    $wcan bind text <Alt-KeyPress>      {# nothing}
    $wcan bind text <Meta-KeyPress>     {# nothing}
    $wcan bind text <Control-KeyPress>  {# nothing}
    $wcan bind text <Escape>            {# nothing}
    $wcan bind text <KP_Enter>          {# nothing}
    $wcan bind text <Tab>               {# nothing}

    # Additional emacs-like bindings.
    $wcan bind text <Control-d> {
	::CanvasText::Delete %W 1
    }
    $wcan bind text <Control-a> {
	::CanvasText::InsertBegin %W
    }
    $wcan bind text <Control-e> {
	::CanvasText::InsertEnd %W
    }
    
    # These may interfere with canvas widget bindings for scrolling.
    $wcan bind text <Control-Left> {
	::CanvasText::SetCursor %W [::CanvasText::PrevWord %W]
    }
    $wcan bind text <Control-Right> {
	::CanvasText::SetCursor %W [::CanvasText::NextWord %W]
    }
    $wcan bind text <Control-Up> {
	::CanvasText::SetCursor %W 0
    }
    $wcan bind text <Control-Down> {
	::CanvasText::SetCursor %W end
    }
    $wcan bind text <Home> {
	::CanvasText::InsertBegin %W
    }
    $wcan bind text <End> {
	::CanvasText::InsertEnd %W
    }
}

# ::CanvasText::Copy --
#  
#       Just copies text from text items. If selected text, copy that,
#       else if text item has focus copy complete text item.
#       
# Arguments:
#       wcan      the canvas widget.
#       
# Results:
#       none

proc ::CanvasText::Copy {wcan} {
    variable priv
    
    Debug 2 "::CanvasText::Copy select item=[$wcan select item]"

    if {[$wcan select item] ne {}} { 
	clipboard clear
	set t [$wcan select item]
	set text [$wcan itemcget $t -text]
	set start [$wcan index $t sel.first]
	set end [$wcan index $t sel.last]
	set str [string range $text $start $end]
	clipboard append $str
	
	# Keep track of font in clipboard and a hash to see if changed
	# before pasting it.
	set priv(font) [$wcan itemcget $t -font]
	set priv(sha1) [sha1::sha1 "$priv(magic)$str"]
	#OwnClipboard $wcan
    }
}

proc ::CanvasText::OwnClipboard {wcan} {
    
    # this creates some weird behaviour???
    selection own -command [list [namespace current]::LostClipboard $wcan] \
      -selection CLIPBOARD $wcan
}

proc ::CanvasText::LostClipboard {wcan} {
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
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       forceNew   make new item regardless if text item under the mouse.
#       
# Results:
#       none

proc ::CanvasText::SetFocus {wcan x y {forceNew 0}} {
    global  prefs fontSize2Points
    
    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]

    focus $wcan
    set id [::CanvasUtils::FindIdFromOverlapping $wcan $x $y "text"]

    Debug 2 "SetFocus:: id=$id"
    
    # If we have an unsent buffer, be sure to send it first.
    if {$prefs(batchText)} {
	EvalBufferedText $wcan
    }
    if {($id eq "") || ([$wcan type $id] ne "text") || $forceNew} {
	
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

	set redo [list ::CanvasUtils::CommandExList $w  \
	  [list [list $cmdlocal local] [list $cmdremote remote]]]
	set undo [list ::CanvasUtils::Command $w $undocmd]
	eval $redo
	undo::add [::WB::GetUndoToken $wcan] $undo $redo

	$wcan focus $utag
	$wcan select clear
	$wcan icursor $utag 0
    }
}

# ::CanvasText::Insert --
#
#       Inserts text string 'char' at the insert point of the text item
#       with focus. Handles newlines as well.
#
# Arguments:
#       wcan   the canvas widget.
#       char   the char or text string to insert.
#       
# Results:
#       none

proc ::CanvasText::Insert {wcan char} {
    global  this prefs
    variable priv
        
    upvar ::CanvasText::${wcan}::buffer buffer
        
    set punct {[.,;?!]}
    set nl_ "\\n"
    
    # First, find out if there are any text item with focus.
    # If not, then make one.
    if {[$wcan focus] eq ""} {
	
    }
    set w [winfo toplevel $wcan]
    
    # Find the 'utag'.
    set utag [::CanvasUtils::GetUtag $wcan focus]
    if {$utag eq "" || $char eq ""}	 {
	Debug 4 "Insert:: utag == {}"
	return
    }
    set itfocus [$wcan focus]
    
    # The index of the insertion point.
    set ind [$wcan index $itfocus insert]

    # Mac text bindings: delete selection before inserting.
    if {[string match "mac*" $this(platform)] ||   \
      ($this(platform) eq "windows")} {
	if {![catch {selection get} s]} {
	    if {$s ne ""} {
		Delete $wcan
		selection clear
	    }
	}
    }
    
    # If this is an empty text item then reuse any cached font.
    if {([$wcan itemcget $itfocus -text] eq "") && ($priv(font) ne {})} {
	if {[string equal $priv(sha1) [sha1::sha1 "$priv(magic)$char"]]} {
	    ::CanvasUtils::ItemConfigure $wcan $itfocus -font $priv(font)
	}
    }
    
    # The actual canvas text insertion; note that 'ind' is found above.
    set cmd [list insert $itfocus insert $char]
    set undocmd [list dchars $utag $ind [expr $ind + [string length $char]]]
    set redo [list ::CanvasUtils::Command $w $cmd]
    set undo [list ::CanvasUtils::Command $w $undocmd]    
    eval {$wcan} $cmd
    undo::add [::WB::GetUndoToken $wcan] $undo $redo
        
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
	set buffer(text) [$wcan itemcget $utag -text]
	
	if {[string match *${punct}* $char]} {
	    EvalBufferedText $wcan
	} else {
	    ScheduleTextBuffer $wcan
	}
    } else {
	::WB::SendMessageList $w [list [list insert $utag $ind $oneliner]]
    }
}

# ::CanvasText::SetCursor --
# 
# 
#
# Arguments:
# w -		The canvas window.
# pos -		The desired new position for the cursor in the text item.

proc ::CanvasText::SetCursor {wcan pos} {

    set id [$wcan focus]
    $wcan select clear
    $wcan icursor $id $pos
}

proc ::CanvasText::PrevPos {wcan pos} {
    
    set id [$wcan focus]
    set ind [$wcan index $id $pos]
    if {$ind == 0} {
	return 0
    } else {
	return [expr {$ind-1}]
    }
}

proc ::CanvasText::NextPos {wcan pos} {
    
    set id [$wcan focus]
    set str [$wcan itemcget $id -text]
    set ind [$wcan index $id $pos]
    if {$ind == [string length $str]} {
	return $ind
    } else {
	return [expr {$ind+1}]
    }
}

proc ::CanvasText::NextWord {wcan} {
    
    set id [$wcan focus]
    set str [$wcan itemcget $id -text]
    set ind [$wcan index $id insert]
    set next [tcl_startOfNextWord $str $ind]
    if {$next == -1} {
	set next end
    }
    return $next
}

proc ::CanvasText::PrevWord {wcan} {
    
    set id [$wcan focus]
    set str [$wcan itemcget $id -text]
    set ind [$wcan index $id insert]
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
#       wcan   the canvas widget.
#       
# Results:
#       none

proc ::CanvasText::MoveRight {wcan} {
    global  this
    
    set foc [$wcan focus]
    
    # Mac text bindings: remove selection then move insert to end.
    if {[string match "mac*" $this(platform)] ||  \
      $this(platform) eq "windows"} {
	
	# If selection.
	if {![catch {selection get} s]} {
	    if {$s ne ""} {
		$wcan icursor $foc [expr [$wcan index $foc sel.last] + 1]
		$wcan select clear
	    }
	} else {
	    $wcan icursor $foc [expr [$wcan index $foc insert] + 1]
	}
    } else {
	$wcan icursor $foc [expr [$wcan index $foc insert] + 1]
    }
}

# ::CanvasText::MoveLeft --
#
#       Move insert cursor one step to the left.
#
# Arguments:
#       wcan   the canvas widget.
#       
# Results:
#       none

proc ::CanvasText::MoveLeft {wcan} {
    global  this
    
    set foc [$wcan focus]
    
    # Mac text bindings: remove selection then move insert to first.
    if {[string match "mac*" $this(platform)] ||  \
      [string equal $this(platform) "windows"]} {
	
	# If selection.
	if {![catch {selection get} s]} {
	    if {$s ne ""} {
		$wcan icursor $foc [expr [$wcan index $foc sel.first] + 0]
		$wcan select clear
	    }
	} else {
	    $wcan icursor $foc [expr [$wcan index $foc insert] - 1]
	}
    } else {
	$wcan icursor $foc [expr [$wcan index $foc insert] - 1]
    }
}

# Find index of new character. Only for left justified text.

proc ::CanvasText::UpDownLine {wcan dir} {
    
    set id [$wcan focus]
    set ind [$wcan index $id insert]
    set str [$wcan itemcget $id -text]
    
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

proc ::CanvasText::KeySelect {wcan new} {
    
    set id [$wcan focus]
    set insert [$wcan index $id insert]
    if {$new == $insert} {
	return
    }
    if {[$wcan select item] eq ""} {
	$wcan select from $id insert
	if {$new >= $insert} {
	    $wcan select to $id [expr {$new - 1}]
	} else {
	    $wcan select to $id $new 
	}
    } else {
	set first [$wcan index $id sel.first]
	set last  [$wcan index $id sel.last]
	incr last
	set right  [expr {$new > $insert} ? 1 : 0]
	set inside [expr {($new >= $first) && ($new <= $last)} ? 1 : 0]
	if {$new == $first} {
	    $wcan select clear
	} elseif {$new == $last && $right} {
	    $wcan select clear
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
	    $wcan select to $id $to
	}
    }
    $wcan icursor $id $new
}

proc ::CanvasText::InsertBegin {wcan} {
    
    set foc [$wcan focus]
    
    # Find index of new character. Only for left justified text.
    set ind [expr [$wcan index $foc insert] - 1]
    set str [$wcan itemcget $foc -text]
    set prevNL [expr [string last \n $str $ind] + 1]
    if {$prevNL == -1} {
	$wcan icursor $foc 0
    } else {
	$wcan icursor $foc $prevNL
    }
}

proc ::CanvasText::InsertEnd {wcan} {
    
    set foc [$wcan focus]
    
    # Find index of new character. Only for left justified text.
    set ind [$wcan index $foc insert]
    set str [$wcan itemcget $foc -text]
    set nextNL [string first \n $str $ind]
    if {$nextNL == -1} {
	$wcan icursor $foc end
    } else {
	$wcan icursor $foc $nextNL
    }
}

# ::CanvasText::Hit --
#
#       Called when clicking a text item with the text tool selected.
#
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       select   
#       
# Results:
#       none

proc ::CanvasText::Hit {wcan x y {select 1}} {

    Debug 2 "::CanvasText::Hit select=$select"

    $wcan focus current
    $wcan icursor current @$x,$y
    $wcan select clear
    $wcan select from current @$x,$y
}

# ::CanvasText::Drag --
#
#       Text selection when dragging the mouse over a text item.
#
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasText::Drag {wcan x y} {
    global  this
    
    ::CanvasCmd::DeselectAll $wcan
    $wcan select to current @$x,$y
    
    # Mac text bindings.????
    if {[string match "mac*" $this(platform)]} {
	#$wcan focus
    }
}

# ::CanvasText::SelectWord --
#
#       Typically selects wholw word when double clicking it.
#
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasText::SelectWord {wcan x y} {
    
    ::CanvasCmd::DeselectAll $wcan
    $wcan focus current
    
    set id [$wcan find withtag current]
    if {$id eq ""} {
	return
    }
    if {[$wcan type $id] ne "text"} {
	return
    }
    set txt [$wcan itemcget $id -text]
    set ind [$wcan index $id @$x,$y]
    
    # Find the boundaries of the word and select word.
    $wcan select from   $id [string wordstart $txt $ind]
    $wcan select adjust $id [expr [string wordend $txt $ind] - 1]
}

# ::CanvasText::NewLine --
#
#       Insert a newline in a text item. Careful when sending it to remote
#       clients; double escaped.
#
# Arguments:
#       wcan   the canvas widget.
#       
# Results:
#       none

proc ::CanvasText::NewLine {wcan} {
    global  prefs fontPoints2Size
    
    set nl_ "\\n"
    set w [winfo toplevel $wcan]
    
    # Find the 'utag'.
    set utag [::CanvasUtils::GetUtag $wcan focus]
    if {$utag eq ""}	 {
	return
    }
    
    # If we are buffering text, be sure to send buffer now if any.
    if {$prefs(batchText)} {
	EvalBufferedText $wcan
    }
    set ind [$wcan index [$wcan focus] insert]
    if {$prefs(wb,nlNewText)} {
	set str [$wcan itemcget $utag -text]
	set right [string range $str $ind end]
	set cmds {}
	set undocmds {}
	if {$right ne ""} {
	    lappend cmds [list [list dchars $utag $ind end] all]
	    lappend undocmds [list insert $utag end $right]
	}
	
	array set opts [::CanvasUtils::GetItemOpts $wcan $utag]
	set utagNew [::CanvasUtils::NewUtag]
	set opts(-tags) [list std text $utagNew]
	set opts(-text) $right
	lassign [$wcan bbox $utag] x1 y1 x2 y2
	array set fmetrics [font metrics $opts(-font)]
	set y [expr {$y2 + $fmetrics(-descent)}]
	
	# Local command.
	set cmd [concat create text $x1 $y [array get opts]]
	lappend cmds [list $cmd local]
	
	# Remote command.
	set size [lindex $opts(-font) 1]
	lset opts(-font) 1 $fontPoints2Size($size)
	set cmd [concat create text $x1 $y [array get opts]]
	lappend cmds [list $cmd remote]
	lappend undocmds [list delete $utagNew]
	set redo [list ::CanvasUtils::CommandExList $w $cmds]
	set undo [list ::CanvasUtils::CommandList $w $undocmds]
      } else {
	set cmdlocal [list insert $utag $ind \n]
	set cmdremote [list insert $utag $ind $nl_]
	set undocmd [list dchars $utag $ind]	
	set redo [list ::CanvasUtils::CommandExList $w  \
	  [list [list $cmdlocal local] [list $cmdremote remote]]]
	set undo [list ::CanvasUtils::Command $w $undocmd]
    }

    eval $redo
    undo::add [::WB::GetUndoToken $wcan] $undo $redo

    if {$prefs(wb,nlNewText)} {
	$wcan focus $utagNew
    }
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

proc ::CanvasText::Delete {wcan {offset 0}} {
    global  prefs
    variable priv
    
    Debug 2 "::CanvasText::Delete"

    set idfocus [$wcan focus]
    set utag [::CanvasUtils::GetUtag $wcan focus]
    if {$utag eq ""} {
	return
    }
    set w [winfo toplevel $wcan]
	
    # If we have an unsent buffer, be sure to send it first.
    if {$prefs(batchText)} {
	EvalBufferedText $wcan
    }
    
    if {[$wcan select item] ne ""} {
	set sfirst [$wcan index $idfocus sel.first]
	set slast [$wcan index $idfocus sel.last]
	set str [$wcan itemcget $idfocus -text]
	set str [string range $str $sfirst $slast]
	set cmd [list dchars $utag $sfirst $slast]
	set undocmd [list insert $utag $sfirst $str]
    } elseif {$idfocus ne {}} {
	set ind [expr [$wcan index $idfocus insert] - 1 + $offset]
	set str [$wcan itemcget $idfocus -text]
	set str [string index $str $ind]
	set cmd [list dchars $utag $ind]
	set undocmd [list insert $utag $ind $str]
    }
    if {[info exists cmd]} {
	set redo [list ::CanvasUtils::Command $w $cmd]
	set undo [list ::CanvasUtils::Command $w $undocmd]    
	eval $redo
	undo::add [::WB::GetUndoToken $wcan] $undo $redo
    }
}

# ::CanvasText::Paste --
#
#       Unix style paste using button 2.
#       
# Arguments:
#       wcan    the canvas widget.
#       x,y
#       
# Results:
#       none

proc ::CanvasText::Paste {wcan {x {}} {y {}}} {
    
    Debug 2 "::CanvasText::Paste"
    
    # If no selection just return.
    if {[catch {selection get} _s] &&   \
      [catch {selection get -selection CLIPBOARD} _s]} {
	Debug 2 "\t no selection"
	return
    }
    Debug 2 "\t CanvasTextPaste:: selection=$_s"
    
    # Once the text string is found use...
    Insert $wcan $_s
}

# ::CanvasText::ScheduleTextBuffer --
#
#       Schedules a send operation for our text inserts.
#       
# Arguments:
#       wcan   the canvas widget.
#       
# Results:
#       none.

proc ::CanvasText::ScheduleTextBuffer {wcan} {
    global  prefs
    
    upvar ::CanvasText::${wcan}::buffer buffer
    
    if {[info exists buffer(afterid)]} {
	after cancel $buffer(afterid)
    }
    set buffer(afterid) [after [expr $prefs(batchTextms)]   \
      [list [namespace current]::EvalBufferedText $wcan]]
}

# ::CanvasText::EvalBufferedText --
#
#       This is the proc where buffered text are sent to clients.
#       Buffer emptied.
#       Can be called *after* widget is destroyed!
#       
# Arguments:
#       wcan   the canvas widget.
#       
# Results:
#       any registered send message hook invoked.

proc ::CanvasText::EvalBufferedText {wcan} {

    upvar ::CanvasText::${wcan}::buffer buffer
    
    if {[info exists buffer(afterid)]} {
	after cancel $buffer(afterid)
	unset buffer(afterid)
    }
    
    # Run all registered hooks like speech.
    # @@@ This is not good since it repeates the complete string.
    if {[info exists buffer(utag)] && [string length $buffer(str)]} {
	::hooks::run whiteboardTextInsertHook me $buffer(text)
    }
    
    if {[string length $buffer(str)]} {
	set w ".[lindex [split $wcan .] 1]"
	::WB::SendMessageList $w  \
	  [list [list insert $buffer(utag) $buffer(ind) $buffer(str)]]
    }    
    set buffer(str) ""
}

#-------------------------------------------------------------------------------

