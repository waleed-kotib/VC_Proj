#  entrypopup.tcl ---
#  
#      This file is part of The Coccinella application. It implements an
#      entry with a popup menu button widget.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: entrypopup.tcl,v 1.2 2004-01-13 14:50:20 matben Exp $
#
# ########################### USAGE ############################################
#
#   NAME
#      entrypopup - an entry with popup menu button.
#      
#   SYNOPSIS
#      entrypopup pathName ?options?
#      
#   OPTIONS
#      -popupfont, popupFont, PopupFont
#      -popuplist, popupList, PopupList
#      
#      all entry widget options
#      
#   WIDGET COMMANDS
#      pathName cget option
#      pathName configure ?option? ?value option value ...?
#
# ########################### CHANGES ##########################################
#
#       1.0      first release

package provide entrypopup 1.0

namespace eval ::entrypopup:: {

    # The public interface.
    namespace export entrypopup

    # Globals same for all instances of this widget.
    variable widgetGlobals
    
    set widgetGlobals(debug) 0
}

# ::entrypopup::Init --
#
#       Contains initializations needed for the entrypopup widget. It is
#       only necessary to invoke it for the first instance of a widget since
#       all stuff defined here are common for all widgets of this type.
#       
# Arguments:
#       none.
# Results:
#       Defines option arrays and icons for movie controllers.

proc ::entrypopup::Init { } {
    
    variable widgetGlobals
    variable widgetOptions
    
    if {$widgetGlobals(debug) > 1} {
	puts "::entrypopup::Init"
    }
    
    # List all allowed options with their database names and class names.
    
    array set widgetOptions {
	-popupfont     {popupFont     PopupFont  }      \
	-popuplist     {popupList     PopupList  }      \
    }  
      
    # The items to draw the popup button. Colors must be in sync with todraw.
    set widgetGlobals(btup1) #dedede
    set widgetGlobals(btup2) #ffffff
    set widgetGlobals(btdn1) #737373
    set widgetGlobals(btdn2) #adadad
    set widgetGlobals(todraw) {
	line {0 $size 0 0 $size 0} #dedede tu1    \
	line {1 $size1 1 1 $size1 1} #ffffff tu2    \
	line {0 $size1 $size1 $size1 $size1 0} #737373 td1    \
	line {1 $size2 $size2 $size2 $size2 1} #adadad td2    \
    }
        
    # Options for this widget
    option add *EntryPopup.popupFont     {}        widgetDefault
    option add *EntryPopup.popupList     {}        widgetDefault
}

# ::entrypopup::entrypopup --
#
#       The constructor of this class; it creates an instance named 'w' of the
#       entrypopup. 
#       
# Arguments:
#       w       the widget path.
#       args    (optional) list of key value pairs for the widget options.
#       
# Results:
#       The widget path or an error. Calls the necessary procedures to make a 
#       complete entrypopup widget.

proc ::entrypopup::entrypopup {w args} {
    
    variable widgetGlobals
    variable widgetOptions
    
    if {$widgetGlobals(debug) > 1} {
	puts "::entrypopup::entrypopup w=$w, args=$args"
    }
    
    # We need to make Init at least once.
    if {![info exists widgetOptions]} {
	Init
    }
    
    # No error checking yet. Entry works automatically anyway.
    
    # Continues in the 'Build' procedure.
    set wans [eval Build $w $args]
    return $wans
}

# ::entrypopup::Build --
#
#       Parses options, creates widget command, and calls the Configure 
#       procedure to do the rest.
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#       The widget path or an error.

proc ::entrypopup::Build {w args} {

    variable widgetGlobals
    variable widgetOptions

    if {$widgetGlobals(debug) > 1} {
	puts "::entrypopup::Build w=$w, args=$args"
    }

    # Instance specific namespace
    namespace eval ::entrypopup::${w} {
	variable options
	variable widgets
	variable wlocals
    }
    
    # Set simpler variable names.
    upvar ::entrypopup::${w}::options options
    upvar ::entrypopup::${w}::widgets widgets
    upvar ::entrypopup::${w}::wlocals wlocals

    # We use a frame for this specific widget class.
    set widgets(this) [frame $w -class EntryPopup]
    
    # Set only the names here.
    set widgets(entry)  $w.ent
    set widgets(canvas) $w.canvas
    set widgets(menu)   $w.menu
    set widgets(frame)  ::entrypopup::${w}::${w}
    
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $widgets(frame)
    
    # Parse options. First get widget defaults. Only popup specifics.
    foreach name [array names widgetOptions] {
	set optName [lindex $widgetOptions($name) 0]
	set optClass [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
    }
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    if {[llength $args] > 0} {
	array set options $args
    }
    
    # Create the actual widget procedure.
    proc ::${w} {command args}   \
      "eval ::entrypopup::WidgetProc {$w} \$command \$args"
    
    # Make all subwidgets.
    entry $widgets(entry) 
    canvas $widgets(canvas) -bd 0 -highlightthickness 0 -bg #dedede
    pack $widgets(entry) -side left -fill x 
    pack $widgets(canvas) -side right
    set size [winfo reqheight $widgets(entry)]

    set m $widgets(menu)
    menu $m -tearoff 0
    foreach lab $options(-popuplist) {
	$m add command -label $lab -command [list ::entrypopup::MenuCmd $w $lab]
    }
    bind $widgets(canvas) <Button-1> [list ::entrypopup::Pressed $w %X %Y]
    bind $widgets(canvas) <ButtonRelease> [list ::entrypopup::Released $w]
		
    # The actual drawing takes place from 'Configure' which calls
    # the 'Draw' procedure when necessary.
    eval Configure $widgets(this) [array get options]

    return $w
}

# ::entrypopup::WidgetProc --
#
#       This implements the methods; only two: cget and configure.
#       
# Arguments:
#       w       the widget path.
#       command the actual command; cget or configure.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::entrypopup::WidgetProc {w command args} {
    
    variable widgetGlobals
    variable widgetOptions
    upvar ::entrypopup::${w}::widgets widgets
    upvar ::entrypopup::${w}::options options
    
    if {$widgetGlobals(debug) > 1} {
	puts "::entrypopup::WidgetProc w=$w, command=$command, args=$args"
    }
    set result {}
    
    # Which command?
    switch -- $command {
	cget {
	    if {[llength $args] != 1} {
		error "wrong # args: should be $w cget option"
	    }
	    if {[info exists options($args)]} {
		set result $options($args)
	    } else {
		set result [$widgets(entry) cget $args]
	    }
	}
	configure {
	    set result [eval Configure $w $args]
	}
    }
    return $result
}

# ::entrypopup::Configure --
#
#       Implements the "configure" widget command (method). 
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::entrypopup::Configure {w args} {
    
    variable widgetGlobals
    variable widgetOptions
    upvar ::entrypopup::${w}::options options
    upvar ::entrypopup::${w}::widgets widgets
    upvar ::entrypopup::${w}::wlocals wlocals
    
    if {$widgetGlobals(debug) > 1} {
	puts "::entrypopup::Configure w=$w, args=$args"
    }
    
    # No error checking.

    if {[llength $args] == 0} {
	
	# Return all options.
	foreach opt [lsort [array names widgetOptions]] {
	    set optName [lindex $widgetOptions($opt) 0]
	    set optClass [lindex $widgetOptions($opt) 1]
	    set def [option get $w $optName $optClass]
	    lappend results [list $opt $optName $optClass $def $options($opt)]
	}
	set results "$results [$widgets(entry) configure]"
	return $results
    } elseif {[llength $args] == 1} {
	
	# Return configuration value for this option.
	set opt $args
	if {[info exists widgetOptions($opt)]} {
	    set optName [lindex $widgetOptions($opt) 0]
	    set optClass [lindex $widgetOptions($opt) 1]
	    set def [option get $w $optName $optClass]
	    set result [list $opt $optName $optClass $def $options($opt)]
	} else {
	    set result [$widgets(entry) configure $opt]
	}
	return $result
    }
    
    # Error checking.
    if {[expr {[llength $args]%2}] == 1} {
	error "value for \"[lindex $args end]\" missing"
    }    
    
    # Process the new configuration options.
    set oldPopuplist $options(-popuplist)
    if {[llength $args] > 0} {
	array set options $args
    }
    set needsRedraw 1
    
    # Do the entry options. Separate the popup and entry options.
    array set argsarr $args
    foreach optname [array names widgetOptions] {
	catch {unset argsarr($optname)}
    }
    eval {$widgets(entry) configure} [array get argsarr] 
    set size [winfo reqheight $widgets(entry)]
    $widgets(canvas) configure -width $size -height $size
    if {[llength $options(-popupfont)]} {
	$widgets(menu) configure -font $options(-popupfont)
    }
    if {$oldPopuplist != $options(-popuplist)} {
	set m $widgets(menu)
	$m delete 0 end
	foreach lab $options(-popuplist) {
	    $m add command -label $lab   \
	      -command [list ::entrypopup::MenuCmd $w $lab]
	}
    }
    
    # And finally...
    if {$needsRedraw} {
	Draw $w
    }
}

proc ::entrypopup::Pressed {w x y} {
    
    variable widgetGlobals
    upvar ::entrypopup::${w}::wlocals wlocals
    upvar ::entrypopup::${w}::widgets widgets
    
    $widgets(canvas) configure -bg #636363
    $widgets(canvas) itemconfigure tu1 -fill #424242
    $widgets(canvas) itemconfigure tu2 -fill #525252
    $widgets(canvas) itemconfigure td1 -fill #8c8c8c
    $widgets(canvas) itemconfigure td2 -fill #737373
    $widgets(canvas) itemconfigure tri -fill white
    $widgets(canvas) move tri 1 1
    update idletasks

    # Post popup menu.
    set menuw [winfo reqwidth $widgets(menu)]
    set xp [expr [winfo rootx $widgets(canvas)] + $wlocals(size) - $menuw]
    set yp [expr [winfo rooty $widgets(canvas)] + $wlocals(size)]
    $widgets(menu) post $xp $yp
}

proc ::entrypopup::Released {w} {
    
    variable widgetGlobals
    upvar ::entrypopup::${w}::widgets widgets    
    
    $widgets(canvas) configure -bg #dedede
    $widgets(canvas) itemconfigure tu1 -fill $widgetGlobals(btup1)
    $widgets(canvas) itemconfigure tu2 -fill $widgetGlobals(btup2)
    $widgets(canvas) itemconfigure td1 -fill $widgetGlobals(btdn1)
    $widgets(canvas) itemconfigure td2 -fill $widgetGlobals(btdn2)
    $widgets(canvas) itemconfigure tri -fill black
    $widgets(canvas) move tri -1 -1
}

proc ::entrypopup::MenuCmd {w lab} {
    
    upvar ::entrypopup::${w}::widgets widgets

    $widgets(entry) delete 0 end
    $widgets(entry) insert end $lab
}
		
# ::entrypopup::Draw --
#
#       This is the actual drawing routine.
#       
# Arguments:
#       w       the widget path.
# Results:
#       none.

proc ::entrypopup::Draw {w} {
    
    variable widgetGlobals
    upvar ::entrypopup::${w}::options options
    upvar ::entrypopup::${w}::widgets widgets
    upvar ::entrypopup::${w}::wlocals wlocals
    
    if {$widgetGlobals(debug) > 1} {
	puts "::entrypopup::Draw w=$w"
    }

    set wlocals(size) [winfo reqheight $widgets(entry)]
    set size $wlocals(size)
    set size1 [expr $size - 1]
    set size2 [expr $size - 2]
    $widgets(canvas) delete all
        
    # Draw popmenu button.
    foreach {item coords col tag} $widgetGlobals(todraw) {
	eval {$widgets(canvas) create $item} $coords {-fill $col -tags $tag}
    }
    $widgets(canvas) create polygon -5 0 5 0 0 6 -outline {} -fill black  \
      -tags tri
    $widgets(canvas) move tri [expr $size/2] [expr $size/2 - 3]
}

#-------------------------------------------------------------------------------