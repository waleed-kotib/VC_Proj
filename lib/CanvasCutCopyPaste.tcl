
#  CanvasCutCopyPaste.tcl ---
#  
#      This file is part of the whiteboard application. It implements the
#      cut, copy, and paste commands to and from canvas, typically canvas items.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: CanvasCutCopyPaste.tcl,v 1.3 2003-05-18 13:20:21 matben Exp $

package provide CanvasCutCopyPaste 1.0

namespace eval ::CanvasCCP:: {
    
    # Default for 'clipToken' should always be "string" to be prepared
    # for imports from other apps.
    variable clipToken "string"

    # Use a very unlikely combination for the separator of items in clipboard.
    # Perhaps it is enough to use a nonprintable character; 
    # what happens with binary data?    BAD!!!!!!!!!
    variable clipItemSep " ANDqzU\06 "
}

# CanvasCCP::CopySelectedToClipboard --
#
#       Copies the selection, either complete items or pure text, to the clipboard.
#       If there are no selected items, pure text is copied.
#       Set a flag 'clipToken' to tell which; "string" or "item".
#       The items are copied one by one using 'CopySingleItemToClipboard'.
#       doWhat: "cut" or "copy".
#       
# Arguments:
#       w      the canvas widget.
#       doWhat "cut" or "copy".
#       
# Results:
#       none
 
proc ::CanvasCCP::CopySelectedToClipboard {w doWhat} {
    variable clipItemSep
    variable clipToken
    
    Debug 2 "CopySelectedToClipboard:: w=$w, doWhat=$doWhat"
    Debug 2 "   focus=[focus], class=[winfo class $w]"

    if {![string equal [winfo class $w] "Canvas"]} {
	return
    }
    set wtop [::UI::GetToplevelNS $w]
    clipboard clear
    
    # Assume for the moment that we have copied from the Canvas.
    # First, get canvas objects with tag 'selected'.
    set ids [$w find withtag selected]	
    
    # If selected text within text item.
    if {[llength $ids] == 0} {
	CanvasTextCopy $w
	if {[string equal $doWhat "cut"]} {
	    ::CanvasText::Delete $w
	}
	set clipToken "string"
    } else {
	
	# Loop over all selected items, use 'clipItemSep' as separator.
	foreach id $ids {
	    CopySingleItemToClipboard $w $doWhat $id
	    if {[lindex $ids end] != $id} {
		clipboard append $clipItemSep
	    }
	}
	set clipToken "item"
    }
    ::UI::FixMenusWhenCopy $w
}

# CanvasCCP::CopySingleItemToClipboard --
#
#       Copies the item given by 'id' to the clipboard.
#       doWhat: "cut" or "copy".
#       
# Arguments:
#       w      the canvas widget.
#       doWhat "cut" or "copy".
#       id
#       
# Results:
#       none

proc ::CanvasCCP::CopySingleItemToClipboard {w doWhat id} {
    
    Debug 2 "CopySingleItemToClipboard:: id=$id"

    if {[llength $id] == 0} {
	return
    }
    set wtop [::UI::GetToplevelNS $w]
    set theTags [$w gettags $id]

    # Get all actual options.
    set opcmd [::CanvasUtils::GetItemOpts $w $id]
    
    # Strip off options that are irrelevant; is helpful for other clients with
    # version numbers lower than this if they don't understand new options.
    set opcmd [CanvasStripItemOptions $opcmd]
    set itemType [$w type $id]
    set co [$w coords $id]
    set cmd [concat "create" $itemType $co $opcmd]
    
    # Copy the canvas object to the clipboard.
    clipboard append $cmd
    
    # If cut then delete items.
    if {$doWhat == "cut"} {
	::CanvasDraw::DeleteItem $w 0 0 $id
	$w delete withtag tbbox
    } elseif {$doWhat == "copy"} {
	
    }
    ::UI::FixMenusWhenCopy $w
}

# CanvasCCP::PasteFromClipboardTo
#
#       
# Arguments:
#       w      the focus (canvas) widget.
#       
# Results:
#       none

proc ::CanvasCCP::PasteFromClipboardTo {w} {
    
    set wClass [winfo class $w]
    Debug 2 "PasteFromClipboardTo:: w=$w, wClass=$wClass"

    switch -glob -- $wClass {
	Canvas {
	    ::CanvasCCP::PasteFromClipboardToCanvas $w
	} 
	Wish* - Whiteboard {
	
	    # We assume that it is the canvas that should receive this?
	    set wtop [::UI::GetToplevelNS $w]
	    upvar ::${wtop}::wapp wapp
	    ::CanvasCCP::PasteFromClipboardToCanvas $wapp(can)
	}
	default {
	
	    # Wild guess...
	    event generate $w <<Paste>>
	}
    }
}

# CanvasCCP::PasteFromClipboardToCanvas --
#
#       Depending on 'clipToken', either paste simple text string, or complete item(s).
#       Items are pasted one by one using 'PasteSingleFromClipboardToCanvas'.
#       
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       none

proc ::CanvasCCP::PasteFromClipboardToCanvas {w} {
    variable clipItemSep
    variable clipToken

    Debug 2 "PasteFromClipboardToCanvas:: w=$w"

    $w delete withtag tbbox
    $w dtag all selected
    
    # Pick apart the clipboard content with the 'clipItemSep' separator.
    if {[catch {selection get -sel CLIPBOARD} cmds]} {
	return
    }
    Debug 2 "  PasteFromClipboardToCanvas:: clipToken=$clipToken, cmds=$cmds"
    $w delete withtag tbbox
    
    # Try to figure out if put text string (clipToken="string") or complete
    # canvas create item command (clipToken="item").
    
    set tmpCmds $cmds
    
    # Check first if it has the potential of a canvas command.
    if {[regexp  "^create " $cmds]} {
	set sep [string trim $clipItemSep]
	set firstCmd [CmdToken tmpCmds $sep]
	
	# Then check if it really is a canvas command.
	if {[info complete ".junk $firstCmd"]} {
	    set clipToken "item"
	} else {
	    set clipToken "string"	    
	} 
    } else {
	set clipToken "string"	    
    }
        
    # Depending on clipToken, either paste simple text string, or complete item(s).
    if {$clipToken == "string"} {
	
	# Find out if there is a current focus on a text item.
	if {[$w focus] == ""} {
	    eval ::CanvasText::CanvasFocus $w [::CanvasUtils::NewImportAnchor] 1
	}
	::CanvasText::TextInsert $w $cmds
	
    } elseif {$clipToken == "item"} {
	set sep [string trim $clipItemSep]
	set firstCmd [CmdToken cmds $sep]
	while {$firstCmd != -1} {
	    PasteSingleFromClipboardToCanvas $w $firstCmd
	    set firstCmd [CmdToken cmds $sep]
	}
    }
    
    # Default for 'clipToken' should always be "string" to be prepared
    # for imports from other apps. Not 100% foolproof.
    set clipToken "string"
}

# CanvasCCP::PasteSingleFromClipboardToCanvas --
#
#       Evaluates the canvas create command given by 'cmd', but at a coordinate
#       offset, makes it the new selection and copies it again to clipboard.
#       Be sure to treat newlines correctly when sending command to clients.
#       
# Arguments:
#       w      the canvas widget.
#       cmd
#       
# Results:
#       copied canvas item, sent to all clients.

proc ::CanvasCCP::PasteSingleFromClipboardToCanvas {w cmd} {
    global  prefs allIPnumsToSend

    set nl_ "\\n"
    Debug 2 "PasteSingleFromClipboardToCanvas:: cmd=$cmd"

    set wtop [::UI::GetToplevelNS $w]
    
    # add new tags
    set itemType [lindex $cmd 1]
    set utag [::CanvasUtils::NewUtag]
    set theTags [list $itemType $utag]
    lappend cmd -tags $theTags
    
    # make coordinate offset, first get coords
    set ind1 [lsearch $cmd \[0-9.\]*]
    set ind2 [expr [lsearch $cmd -*\[a-z\]*] - 1]
    set theCoords [lrange $cmd $ind1 $ind2]
    set cooOffset {}
    foreach coo $theCoords {
	lappend cooOffset [expr $coo + $prefs(offsetCopy)]
    }
    
    # paste back coordinates in cmd
    set newcmd [concat [lrange $cmd 0 [expr $ind1 - 1]] $cooOffset  \
      [lrange $cmd [expr $ind2 + 1] end]]
    set undocmd "delete $utag"
    
    # Change font size from points to html size when sending it to clients.
    if {[string equal $itemType "text"]} {
	set cmdremote [::CanvasUtils::FontHtmlToPointSize $newcmd 1]
    } else {
	set cmdremote $newcmd
    }
    
    # Write to all other clients; need to make a one liner first.
    regsub -all "\n" $cmdremote $nl_ cmdremote
    set redo [list ::CanvasUtils::CommandExList $wtop  \
      [list [list $newcmd "local"] [list $cmdremote "remote"]]]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
    
    # Create new bbox and select item.
    ::CanvasDraw::MarkBbox $w 1 $utag
    
    # Copy the newly pasted object to clipboard.
    CopySelectedToClipboard $w copy
}

# CanvasCCP::CanvasTextCopy --
#  
#       Just copies text from text items. If selected text, copy that,
#       else if text item has focus copy complete text item.
#       
# Arguments:
#       c      the canvas widget.
#       
# Results:
#       none

proc ::CanvasCCP::CanvasTextCopy {c} {
    
    Debug 2 "CanvasTextCopy::"

    if {[$c select item] != {}}	 { 
	clipboard clear
	set t [$c select item]
	set text [$c itemcget $t -text]
	set start [$c index $t sel.first]
	set end [$c index $t sel.last]
	clipboard append [string range $text $start $end]
    } elseif {[$c focus] != {}}	 {
	clipboard clear
	set t [$c focus]
	set text [$c itemcget $t -text]
	clipboard append $text
    }
}

# CanvasCCP::CanvasTextPaste --
#
#       Unix style paste using button 2.
#       
# Arguments:
#       c      the canvas widget.
#       x,y
#       
# Results:
#       none

proc ::CanvasCCP::CanvasTextPaste {c {x {}} {y {}}} {
    
    Debug 2 "CanvasTextPaste::"
    
    # If no selection just return.
    if {[catch {selection get} _s] &&   \
      [catch {selection get -selection CLIPBOARD} _s]} {
	Debug 2 "  CanvasTextPaste:: no selection"
	return
    }
    Debug 2 "  CanvasTextPaste:: selection=$_s"
    
    # Once the text string is found use...
    ::CanvasText::TextInsert $c $_s
    return
}

# CanvasCCP::CmdToken --
#   
#       Returns part of 'cmdName' up to 'separator' and deletes that part 
#       from 'cmdName'.
#       
# Arguments:
#       cmdName     
#       separator
#       
# Results:
#       part of 'cmdName' up to 'separator'.

proc ::CanvasCCP::CmdToken {cmdName separator} {
    upvar $cmdName theCmd
    
    # If nothing then return -1.
    if {$theCmd == ""} {
	return -1
    }
    set indSep [lsearch -exact $theCmd $separator]
    
    # If no separator then just return the remaining part.
    if {$indSep == -1} {
	set firstPart $theCmd
	set theCmd {}
	return $firstPart
    }
    
    # If separator in -text then ???.
    if {[lindex $theCmd [expr $indSep - 1]] != "-text"} {
	set firstPart [lrange $theCmd 0 [expr $indSep - 1]]
    } else {
	puts "Warning in CmdToken: -text part wrong"
    }
    set theCmd [lrange $theCmd [expr $indSep + 1] end]
    return $firstPart
}

# CanvasCCP::CanvasStripItemOptions
#
#       Takes a list of '-option value' pairs and discards options that doesn't
#       make a difference, such as empty lists, zeros etc.
#       
# Arguments:
#       optList      the list of pairs '-option value'
#       
# Results:
#       The modified '-option value' list.

proc ::CanvasCCP::CanvasStripItemOptions {optList} {
    
    set opts {}
    foreach {name val} $optList {

	# First, discard if empty list. This is not true for -fill for polygons.
	# A nonexistent -fill option for a polygon fills it with black, which
	# is correct for Tk 8.0 but a bug in Tk 8.3.
	if {($val == "") && ![string equal $name "-fill"]} {
	    continue
	}
	
	# Pick options that can be discarded if zero.
	switch -- $name {
	    "-disabledwidth" - "-activewidth" - "-dashoffset" {
		if {[string equal $val "0"]} {
		    continue
		}
	    }
	    "-offset" - "-outlineoffset" {
		if {[string equal $val "0,0"]} {
		    continue
		}
	    }
	    "-smooth" {

		# We take the opportunity to fix a bug(?) in 8.3.
		if {[string equal $val "bezier"]} {
		    set val 1
		}		
	    }
	}
	lappend opts $name $val
    }
    
    # And get back the modified list to return.
    return $opts
}

#-------------------------------------------------------------------------------
