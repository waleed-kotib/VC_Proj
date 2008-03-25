#  CanvasCutCopyPaste.tcl ---
#  
#      This file is part of The Coccinella application. It implements the
#      cut, copy, and paste commands to and from canvas, typically canvas items.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
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
# $Id: CanvasCutCopyPaste.tcl,v 1.11 2008-03-25 08:52:31 matben Exp $

package provide CanvasCutCopyPaste 1.0

namespace eval ::CanvasCCP:: {
    
    # Default for 'clipToken' should always be "string" to be prepared
    # for imports from other apps.
    variable clipToken "string"

    # For canvas items we use the following format in the clipboard:
    #   {$magicToken {{create line ...} {import ...} ...}}
    variable magicToken c75a6301-530b0317
}

# CanvasCCP::Cut, Copy, Paste --
# 
#       Event bind commands for Whiteboard virtual events <<Cut>>, <<Copy>>, 
#       and <<Paste>>.

proc ::CanvasCCP::Cut {w} {
    CopySelected $w cut
}

proc ::CanvasCCP::Copy {w} {
    CopySelected $w copy
}

proc ::CanvasCCP::Paste {w} {
    PasteOnCanvas $w
}

# CanvasCCP::CopySelected --
#
#       Copies the selection, either complete items or pure text, to the clipboard.
#       If there are no selected items, pure text is copied.
#       Set a flag 'clipToken' to tell which; "string" or "item".
#       The items are copied one by one using 'CopySingle'.
#       doWhat: "cut" or "copy".
#       
# Arguments:
#       wcan        the canvas widget.
#       doWhat "cut" or "copy".
#       
# Results:
#       none
 
proc ::CanvasCCP::CopySelected {wcan doWhat} {
    variable clipToken
    variable magicToken
    
    Debug 4 "CopySelected:: wcan=$wcan, doWhat=$doWhat"
    Debug 4 "\t focus=[focus], class=[winfo class $wcan]"

    if {![string equal [winfo class $wcan] "Canvas"]} {
	return
    }
    set w [winfo toplevel $wcan]
    clipboard clear
    
    # Assume for the moment that we have copied from the Canvas.
    # First, get canvas objects with tag 'selected'.
    set ids [$wcan find withtag selected]	
    
    # If selected text within text item.
    if {$ids eq {}} {
	::CanvasText::Copy $wcan
	if {[string equal $doWhat "cut"]} {
	    ::CanvasText::Delete $wcan
	}
	set clipToken "string"
    } else {
	
	# See format definition above.
	clipboard append "$magicToken {"
	foreach id $ids {
	    CopySingle $wcan $doWhat $id
	}
	clipboard append "}"
	set clipToken "item"
    }
    
    # This was an attempt to do image garbage collection...
    #selection handle -selection CLIPBOARD $wcan \
    #  [list [namespace current]::SelectionHandle $wcan]
    #selection own -selection CLIPBOARD \
    #  -command [list [namespace current]::SelectionLost $wcan] $wcan
}

# CanvasCCP::SelectionLost --
# 
#       Shall do garabage collection of images.

proc ::CanvasCCP::SelectionLost {wcan} {
    
    puts "_______::CanvasCCP::SelectionLost wcan=$wcan"
    
}

proc ::CanvasCCP::SelectionHandle {wcan offset maxbytes} {
    puts "::CanvasCCP::SelectionHandle w=$w, offset=$offset, maxbytes=$maxbytes"
    
    if {[catch {selection get -sel CLIPBOARD} str]} {
	puts "\t catch"
	return "ERROR: $str"
    }
    puts "\t str=$str"
    return [string range $str $offset [expr $offset + $maxbytes]]
}

# CanvasCCP::CopySingle --
#
#       Copies the item given by 'id' to the clipboard.
#       doWhat: "cut" or "copy".
#       
# Arguments:
#       wcan   the canvas widget.
#       doWhat "cut" or "copy".
#       id
#       
# Results:
#       none

proc ::CanvasCCP::CopySingle {wcan doWhat id} {
    
    Debug 4 "CopySingle:: id=$id"

    if {$id eq ""} {
	return
    }
    set w [winfo toplevel $wcan]
    set tags [$wcan gettags $id]
    
    # Do not allow copies of broken images (mess).
    if {[lsearch $tags broken] >= 0} {
	return
    }
    
    # Get all actual options.
    set opcmd [::CanvasUtils::GetItemOpts $wcan $id]
    
    # Strip off options that are irrelevant; is helpful for other clients with
    # version numbers lower than this if they don't understand new options.
    set opcmd [CanvasStripItemOptions $opcmd]
    set itemType [$wcan type $id]
    set co [$wcan coords $id]
    set cmd [concat "create" $itemType $co $opcmd]
        
    # Copy the canvas object to the clipboard.
    clipboard append " {$cmd}"
    
    # If cut then delete items.
    switch -- $doWhat {
	cut {
	    
	    # There is currently a memory leak when images are cut!
	    ::CanvasDraw::DeselectItem $wcan $id
	    ::CanvasDraw::DeleteIds $wcan $id all -trashunusedimages 0
	}
	copy {
	    # empty
	}	
    }
}

# CanvasCCP::PasteOnCanvas --
#
#       Depending on 'clipToken', either paste simple text string, or complete item(s).
#       Items are pasted one by one using 'PasteSingleOnCanvas'.
#       
# Arguments:
#       wcan   the canvas widget.
#       
# Results:
#       none

proc ::CanvasCCP::PasteOnCanvas {wcan} {
    variable clipToken
    variable magicToken

    Debug 4 "PasteOnCanvas:: wcan=$wcan"
    
    if {[catch {selection get -sel CLIPBOARD} str]} {
	return
    }
    Debug 4 "\t str=$str"
    ::CanvasCmd::DeselectAll $wcan
        
    # Check first if it has the potential of a canvas command.
    if {[regexp ^$magicToken $str]} {
	set clipToken "item"
    } else {
	set clipToken "string"	    
    }
        
    # Depending on clipToken, either paste simple text string, or complete item(s).
    switch -- $clipToken {
	string {
	
	    # Find out if there is a current focus on a text item.
	    set itemfocus [$wcan focus]
	    if {$itemfocus eq ""} {
		eval ::CanvasText::SetFocus $wcan \
		  [::CanvasUtils::NewImportAnchor $wcan] 1
	    }
	    ::CanvasText::Insert $wcan $str
	    
	    # ...and remove (set) focus if not there before.
	    $wcan focus $itemfocus
	} 
	item {
	    foreach cmd [lindex $str 1] {
		PasteSingleOnCanvas $wcan $cmd
	    }
	}
    }
    
    # Default for 'clipToken' should always be "string" to be prepared
    # for imports from other apps. Not 100% foolproof.
    set clipToken "string"
}

# CanvasCCP::PasteSingleOnCanvas --
#
#       Evaluates the canvas create command given by 'cmd', but at a coordinate
#       offset, makes it the new selection and copies it again to clipboard.
#       Be sure to treat newlines correctly when sending command to clients.
#       
# Arguments:
#       wcan      the canvas widget.
#       cmd
#       
# Results:
#       copied canvas item, sent to all clients.

proc ::CanvasCCP::PasteSingleOnCanvas {wcan cmd} {
    global  prefs
    
    Debug 4 "PasteSingleOnCanvas:: cmd=$cmd"
    
    set w [winfo toplevel $wcan]
    
    switch -- [lindex $cmd 0] {
	import {
	    set utag [::CanvasUtils::NewUtag]
	    set cmd [CanvasUtils::ReplaceUtag $cmd $utag]
	    set x [expr [lindex $cmd 1] + $prefs(offsetCopy)]
	    set y [expr [lindex $cmd 2] + $prefs(offsetCopy)]
	    set cmd [lreplace $cmd 1 2 $x $y]
	    set cmd [::CanvasUtils::SkipStackingOptions $cmd]
	    ::Import::HandleImportCmd $wcan $cmd
	}
	create {
	    
	    # add new tags
	    set itemType [lindex $cmd 1]
	    set utag [::CanvasUtils::NewUtag]
	    set tags [list std $itemType $utag]
	    lappend cmd -tags $tags
	    
	    # Take precaution if -image does not exist anymore.
	    set ind [lsearch -exact $cmd -image]
	    if {$ind >= 0} {
		if {[catch {image inuse [lindex $cmd [incr ind]]}]} {
		    return
		}
	    }
	    #set cmd [CanvasUtils::ReplaceUtag $cmd $utag]
	    
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
	    set undocmd [list delete $utag]
	    
	    # Change font size from points to html size when sending it to clients.
	    if {[string equal $itemType "text"]} {
		set cmdremote [::CanvasUtils::FontHtmlToPointSize $newcmd 1]
	    } else {
		set cmdremote $newcmd
	    }
	    
	    # Write to all other clients; need to make a one liner first.
	    set nl_ {\\n}
	    regsub -all "\n" $cmdremote $nl_ cmdremote
	    set redo [list ::CanvasUtils::CommandExList $w  \
	      [list [list $newcmd local] [list $cmdremote remote]]]
	    set undo [list ::CanvasUtils::Command $w $undocmd]
	    eval $redo
	    undo::add [::WB::GetUndoToken $wcan] $undo $redo

	    ::CanvasFile::SetUnsaved $wcan
	}
    }
    
    # Create new bbox and select item.
    ::CanvasDraw::MarkBbox $wcan 1 $utag
    
    # Copy the newly pasted object to clipboard.
    CopySelected $wcan copy
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
    if {$theCmd eq ""} {
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
    if {[lindex $theCmd [expr $indSep - 1]] ne "-text"} {
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
	if {($val eq "") && ![string equal $name "-fill"]} {
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
