# maccarbonprint.tcl --
#
#      Script support to the MacCarbonPrint package.
#
# Copyright (c) 2003, Mats Bengtsson
# 
# $Id: maccarbonprint.tcl,v 1.1 2008-02-20 06:50:16 matben Exp $

namespace eval ::maccarbonprint:: {
    
    variable smoothOpts
    array set smoothOpts {0 0 1 1 bezier 1}    

    variable debug 0
}

# ::maccarbonprint::printcanvas --
# 
#      Utility function for printing a canvas. Includes the complete
#      printing loop.
#       
# Arguments:
#       wcanvas       the canvas widget path
#       printObj      print object returned from ::maccarbonprint::print.
#       args      -shrinkoutput     (D=1) shrinks pages to only print existing items
#   
# Results:
#       none.

proc ::maccarbonprint::printcanvas {wcanvas printObj args} {
    
    array set argsArr {
        -shrinkoutput        1
    }
    array set argsArr $args
    
    set firstPage 1
    set lastPage 1
    set scale 1.0
    set errMsg ""
    
    array set optsArr [::maccarbonprint::printconfigure $printObj]
    set scrollRect [$wcanvas cget -scrollregion]
    if {[llength $scrollRect] == 4} {
	foreach {x y canWidth canHeight} $scrollRect break
    } else {
	set x 0
	set y 0
	set canWidth [$wcanvas cget -width]
	set canHeight [$wcanvas cget -height]
    }
    set bbox [$wcanvas bbox all]
    if {$bbox == ""} {
	# Empty canvas.
	return
    }
    foreach {x1 y1 x2 y2} $bbox break
    foreach {pageX pageY pageWidth pageHeight} $optsArr(-adjustedpagerect) break
    
    if {$argsArr(-shrinkoutput)} {
        set canWidth $x2
        set canHeight $y2
    }
    
    Debug 2 "x=$x, y=$y, canWidth=$canWidth, canHeight=$canHeight"
    Debug 2 "pageX=$pageX, pageY=$pageY, pageWidth=$pageWidth, pageHeight=$pageHeight"
    
    set nx [expr int($canWidth/$pageWidth + 1)]
    set ny [expr int($canHeight/$pageHeight + 1)]
        
    set lastPage [expr $nx * $ny]
    if {$optsArr(-lastpage) < $lastPage} {
    	set lastPage $optsArr(-lastpage)
    }
    Debug 2 "nx=$nx, ny=$ny, lastPage=$lastPage"

    # The print loop. Note error handling...
    if {[catch {::maccarbonprint::opendoc $printObj $firstPage $lastPage} errMsg]} {
	return -code error $errMsg
    }    
    
    for {set page [expr $firstPage - 1]} {$page < $lastPage} {incr page} {
    	
	# left-to-right, top-to-bottom.
	set x [expr int($pageWidth * ($page % $nx))]
	set y [expr int($pageHeight * ($page/$nx))]
	
	Debug 2 "\tpage=$page, x=$x, y=$y"
	
	if {![catch {
	    ::maccarbonprint::openpage $printObj  \
	      -offsetx $x -offsety $y -scale $scale
	} printWin]} {
	    
	    # Print page.
	    ::maccarbonprint::printAll $wcanvas $printWin
	    catch {::maccarbonprint::closepage $printObj}
	} else {
	    set errMsg $printWin
	}
    }
    catch {::maccarbonprint::closedoc $printObj}

    if {$errMsg != ""} {
    	return -code error $errMsg
    } else {
        return ""
    }
}

proc ::maccarbonprint::printAll {wcanvas printWin} {
    variable smoothOpts

    Debug 2 "::maccarbonprint::printAll wcanvas=$wcanvas, printWin=$printWin"
    
    foreach id [$wcanvas find all] {
    	set type [$wcanvas type $id]
    	set opts {}
    	foreach opt [$wcanvas itemconfigure $id] {
    	    set key [lindex $opt 0]
    	    set def [lindex $opt 3]
    	    set val [lindex $opt 4]

    	    switch -- $key {
    	        -smooth {
    	            set val $smoothOpts($val)
    	        }
    	        default {
		    # empty.
    	        }
    	    }
	    
	    # Add only if not default.
	    if {![string equal $def $val]} {
		lappend opts $key $val
	    }
    	}    	
    	Debug 2 "--- id=$id, type=$type"
    	
    	switch -- $type {
    	    window {
    	        # empty.
    	    }
    	    default {
    	        eval {$printWin create $type} [$wcanvas coords $id] $opts
    	    }
    	}    
    }
}

# ::maccarbonprint::printtext --
# 
#      Utility function for printing a text widget. Includes the complete
#      printing loop. Handles only pure text with uniform font.
#       
# Arguments:
#       wtext         the canvas widget path
#       printObj      print object returned from ::maccarbonprint::print.
#       args      
#                
#   
# Results:
#       none.

proc ::maccarbonprint::printtext {wtext printObj args} {
    
    array set argsArr [list \
	-font        [$wtext cget -font]    \
    ]
    array set argsArr $args
    
    set firstPage 1
    set lastPage 1
    set scale 1.0
    set errMsg ""
    
    array set optsArr [::maccarbonprint::printconfigure $printObj]

    foreach {pageX pageY pageWidth pageHeight} $optsArr(-adjustedpagerect) break
        	
    # We make a dummy text widget to figure out the geometry of things.
    set wtmp .__print_text
    text $wtmp -font $argsArr(-font) -wrap word
    
    # Resize the text widget to be the size of the print width.
    # Translate between characters to pixels.
    set charWidth [expr [font measure $argsArr(-font) 0000000000]/10]    
    $wtmp configure -width [expr int($pageWidth/$charWidth)]
    $wtmp insert end [$wtext get 1.0 end]
    
    # Split the actual text into pieces that fit onto a printing page.
    # No idea of how to fix this...
    array set metricArr [font metrics $argsArr(-font)]
    set useHeight [expr $pageHeight - $metricArr(-linespace) - 4]
    set displayLinesPerPage [expr int($useHeight/$metricArr(-linespace))]
    
    # Prints only a single page so far.
    set textPage(0) [$wtext get 1.0 end]

    # Need to figure out number of pages.
    set lastPage 1
    if {$optsArr(-lastpage) < $lastPage} {
	set lastPage $optsArr(-lastpage)
    }
    set lastPage 1
    Debug 2 "lastPage=$lastPage"

    # The print loop. Note error handling...
    if {[catch {::maccarbonprint::opendoc $printObj $firstPage $lastPage} errMsg]} {
	return -code error $errMsg
    }    
    
    for {set page [expr $firstPage - 1]} {$page < $lastPage} {incr page} {
		
	Debug 2 "\tpage=$page"
	
	if {![catch {
	    ::maccarbonprint::openpage $printObj
	} printWin]} {
	    
	    # Print page.
	    $printWin create text 0 0 -text $textPage($page) -anchor nw  \
	      -width $pageWidth -font $argsArr(-font)
	    catch {::maccarbonprint::closepage $printObj}
	} else {
	    set errMsg $printWin
	}
    }
    catch {::maccarbonprint::closedoc $printObj}
    destroy $wtmp

    if {$errMsg != ""} {
	return -code error $errMsg
    } else {
	return ""
    }
}

# ::maccarbonprint::easytextprint --
# 
#      Utility function for printing a text widget. Includes the complete
#      printing loop. Works around limitations in maccarbonprint::textprint 
#      command (maccarbon::textprint prints only a single page) by placing 
#      text on canvas widget; can print multiple pages. Supports text only, 
#      not images.
# Arguments:
#       wtext         the canvas widget path
#       printObj      print object returned from ::maccarbonprint::print.
#       args      
#                
#   
# Results:
#       none.
# Contributed by Kevin Walzer, (c) 2007.

proc ::maccarbonprint::easytextprint {wtext printObj args} {


    set wtmp .__print_text
    canvas $wtmp -width 612

    set outputtext [$wtext get 1.0 end]
    set outputfont [$wtext cget -font]

    $wtmp create text 5 0 -text $outputtext -font $outputfont -width 580 -anchor nw

    ::maccarbonprint::printcanvas $wtmp $printObj

    destroy $wtmp
}

proc ::maccarbonprint::Debug {num str} {
    variable debug
    
    if {$num <= $debug} {
	puts $str
    }
}

#------------------------------------------------------------------------------
