#  mnotebook.tcl ---
#  
#      This file is part of The Coccinella application.
#      It implements a notebook interface.
#      Code idee from Harrison & McLennan
#      
#  Copyright (c) 2003-2005  Mats Bengtsson
#  This source file is distributed under the BSD license.
#  
# $Id: mnotebook.tcl,v 1.3 2005-08-14 06:56:45 matben Exp $
# 
# ########################### USAGE ############################################
#
#   NAME
#      mnotebook - a notebook widget.
#      
#   SYNOPSIS
#      mnotebook pathName ?options?
#      
#   OPTIONS
#       Mnotebook class:
#	-borderwidth, borderWidth, BorderWidth
#	-relief, relief, Relief
#	-takefocus, takeFocus, TakeFocus
#	
#   WIDGET COMMANDS
#      pathName cget option
#      pathName configure ?option? ?value option value ...?
#      pathName deletepage pageName
#      pathName displaypage ?pageName?
#      pathName exists pageName
#      pathName page pageName
#      pathName pages
#
# ########################### CHANGES ##########################################
#
#       1.0     

package provide mnotebook 1.0

namespace eval ::mnotebook::  {
        
    # Globals same for all instances of this widget.
    variable widgetGlobals

    set widgetGlobals(debug) 0
}

# ::mnotebook::Init --
#
#       Contains initializations needed for the notebook widget. It is
#       only necessary to invoke it for the first instance of a widget since
#       all stuff defined here are common for all widgets of this type.
#       
# Arguments:
#       none.
# Results:
#       Defines option arrays and icons for movie controllers.

proc ::mnotebook::Init { } {
    global  tcl_platform

    variable widgetCommands
    variable widgetGlobals
    variable widgetOptions
    variable notebookOptions

    if {$widgetGlobals(debug) > 1}  {
	puts "::mnotebook::Init"
    }
    
    # List all allowed options with their database names and class names.    
    array set widgetOptions {
	-background          {background           Background          }  \
	-borderwidth         {borderWidth          BorderWidth         }  \
	-relief              {relief               Relief              }  \
	-takefocus           {takeFocus            TakeFocus           }  \
    }
    set notebookOptions {-background -borderwidth -relief -takefocus}
  
    # The legal widget commands.
    set widgetCommands {cget configure deletepage displaypage page pages}
  
    # Having a background identical with pages background minimizes flashes.
    option add *Mnotebook.background                white        widgetDefault
    option add *Mnotebook.borderWidth               0            widgetDefault
    option add *Mnotebook.relief                    flat         widgetDefault
    option add *Mnotebook.takeFocus                 0            widgetDefault
    
    # This allows us to clean up some things when we go away.
    bind Mnotebook <Destroy> [list ::mnotebook::DestroyHandler %W]
}

# mnotebook::mnotebook --
#
#       Constructor for the notebook.
#   
# Arguments:
#       w      the widget.
#       args   list of '-name value' options.
# Results:
#       The widget.

proc ::mnotebook::mnotebook {w args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable notebookOptions

    if {$widgetGlobals(debug) > 1} {
	puts "::mnotebook::mnotebook w=$w, args='$args'"
    }
    
    # Perform a one time initialization.
    if {![info exists widgetOptions]} {
	Init
    }
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]} {
	    return -code error "unknown option \"$name\" for the mnotebook widget"
	}
    }

    # Instance specific namespace
    namespace eval ::mnotebook::${w} {
	variable options
	variable widgets
	variable nbInfo
    }
    
    # Set simpler variable names.
    upvar ::mnotebook::${w}::options options
    upvar ::mnotebook::${w}::widgets widgets
    upvar ::mnotebook::${w}::nbInfo nbInfo

    # We use a frame for this specific widget class.
    set widgets(this) [frame $w -class Mnotebook]
    #set widgets(frame) $widgets(this)
    set widgets(frame) ::mnotebook::${w}::${w}
    pack propagate $w 0
    
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $widgets(frame)

    # Process the new configuration options.
    array set argsarr $args

    # Parse options for the notebook. First get widget defaults.
    foreach name $notebookOptions {
	set optName [lindex $widgetOptions($name) 0]
	set optClass [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
	if {$widgetGlobals(debug) > 1} {
	    puts "   name=$name, optName=$optName, optClass=$optClass"
	}
    }
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    if {[llength $args] > 0}  {
	array set options $args
    }
    set optsList [array get options]
    eval {$widgets(frame) configure} $optsList
    
    # Create the actual widget procedure.
    proc ::${w} {command args}   \
      "eval ::mnotebook::WidgetProc {$w} \$command \$args"
        
    set nbInfo(uid) 0
    set nbInfo(pages) {}
    
    # current is the widget path to the actually packed page.
    set nbInfo(current) ""
    
    # display is the widget path to the page that we want as front page.
    set nbInfo(display) ""
    set nbInfo(pending) ""
    set nbInfo(fixSize) 0
    
    return $w
}

# ::mnotebook::WidgetProc --
#
#       This implements the methods, cget, configure etc.
#       
# Arguments:
#       w       the widget path.
#       command the actual command; cget, configure etc.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::mnotebook::WidgetProc {w command args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable widgetCommands
    upvar ::mnotebook::${w}::options options
    upvar ::mnotebook::${w}::widgets widgets
    upvar ::mnotebook::${w}::nbInfo nbInfo
    
    if {$widgetGlobals(debug) > 2} {
	puts "::mnotebook::WidgetProc w=$w, command=$command, args=$args"
    }
    set result {}
    
    # Which command?
    switch -- $command {
	cget {
	    if {[llength $args] != 1} {
		return -code error "wrong # args: should be $w cget option"
	    }
	    set result $options($args)
	}
	configure {
	    set result [eval {Configure $w} $args]
	}
	deletepage {
	    set result [eval {DeletePage $w} $args]
	}
	displaypage {
	    if {[llength $args] == 0} {
		return $nbInfo(display)
	    } elseif {[llength $args] == 1} {
		set result [eval {Display $w} $args]
	    } else {
		return -code error "wrong # args: should be $w displaypage ?pageName?"
	    }
	}
	exists {
	    set result [eval {Exists $w} $args]
	}
	page {
	    set result [eval {Page $w} $args]
	}
	pages {
	    set result [Pages $w]
	}
	default {
	    return -code error "unknown command \"$command\" of the mnotebook widget.\
	      Must be one of $widgetCommands"
	}
    }
    return $result
}

# ::mnotebook::Configure --
#
#       Implements the "configure" widget command (method). 
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::mnotebook::Configure {w args} {
    
    variable widgetGlobals
    variable widgetOptions
    upvar ::mnotebook::${w}::options options
    upvar ::mnotebook::${w}::widgets widgets
    
    if {$widgetGlobals(debug) > 1} {
	puts "::mnotebook::Configure w=$w, args='$args'"
    }
    
    # Error checking.
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]}  {
	    return -code error "unknown option for the mnotebook widget: $name"
	}
    }
    if {[llength $args] == 0} {
	
	# Return all options.
	foreach opt [lsort [array names widgetOptions]] {
	    set optName [lindex $widgetOptions($opt) 0]
	    set optClass [lindex $widgetOptions($opt) 1]
	    set def [option get $w $optName $optClass]
	    lappend results [list $opt $optName $optClass $def $options($opt)]
	}
	return $results
    } elseif {[llength $args] == 1} {
	
	# Return configuration value for this option.
	set opt $args
	set optName [lindex $widgetOptions($opt) 0]
	set optClass [lindex $widgetOptions($opt) 1]
	set def [option get $w $optName $optClass]
	return [list $opt $optName $optClass $def $options($opt)]
    }
    
    # Error checking.
    if {[expr {[llength $args]%2}] == 1} {
	return -code error "value for \"[lindex $args end]\" missing"
    }    
    
    if {[llength $args] > 0} {
	eval {$w configure} $args
    }
    return {}
}

# mnotebook::Page --
#
#       Adds a new page to an existing notebook.
#   
# Arguments:
#       w      the "base" widget.
#       name   the name of the new page.
# Results:
#       The page widget path.

proc ::mnotebook::Page {w name} {

    variable widgetGlobals
    upvar ::mnotebook::${w}::nbInfo nbInfo
    upvar ::mnotebook::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1} {
	puts "::mnotebook::Page w=$w, name=$name"
    }
    set page $w.page[incr nbInfo(uid)]
    lappend nbInfo(pages)  $page
    set nbInfo(page-$name) $page
    set nbInfo(name-$page) $name
    
    # We should probably add configuration options here.
    ttk::frame $page
    
    # If this is the only page, display it.
    if {[llength $nbInfo(pages)] == 1} {
	Display $w $name
    }
    
    # Need to rebuild since size may have changed.
    set nbInfo(fixSize) 1
    if {$nbInfo(pending) == ""} {
	set nbInfo(pending) [after idle [list ::mnotebook::Build $w]]
    }
    return $page
}

proc ::mnotebook::Pages {w} {

    upvar ::mnotebook::${w}::nbInfo nbInfo
    
    set names {}
    foreach key [array names nbInfo "name-*"] {
	lappend names $nbInfo($key)
    }
    return $names
}

proc ::mnotebook::Exists {w name} {

    upvar ::mnotebook::${w}::nbInfo nbInfo
    
    if {[info exists nbInfo(page-$name)]} {
	return 1
    } else {
	return 0
    }
}

# mnotebook::DeletePage --
#
#       Deletes a page from the notebook.
#   
# Arguments:
#       w      the widget.
#       name   the name of the deleted page.
# Results:
#       none.

proc ::mnotebook::DeletePage {w name} {

    variable widgetGlobals
    upvar ::mnotebook::${w}::nbInfo nbInfo

    if {$widgetGlobals(debug) > 1} {
	puts "::mnotebook::DeletePage w=$w, name=$name"
    }
    if {[info exists nbInfo(page-$name)]} {
	set page $nbInfo(page-$name)
    } else {
	return -code error "bad mnotebook page \"$name\""
    }
    set ind [lsearch -exact $nbInfo(pages) $page]
    if {$ind < 0} {
	return -code error "Page \"$name\" is not there"
    }
    set newCurrentPage $nbInfo(current)
    
    # If we are about to delete the current page, set another current.
    if {[string equal $page $nbInfo(current)]} {
	
	# Set next page to current.
	set newInd [expr {$ind + 1}]
	set newCurrentPage [lindex $nbInfo(pages) $newInd]
	if {$newInd >= [llength $nbInfo(pages)]} {
	    
	    # We are about to delete the last page, set current to next to last.
	    set newCurrentPage [lindex $nbInfo(pages) end-1]
	}
    }
    set newCurrentName $nbInfo(name-$newCurrentPage)
    unset nbInfo(page-$name)
    unset nbInfo(name-$page)
    set nbInfo(pages) [lreplace $nbInfo(pages) $ind $ind]
    
    # There can be a change in geometry if removed a large page.
    catch {after cancel $nbInfo(pending)}
    Display $w $newCurrentName
    after idle [list catch destroy $page]
    return {}
}

# mnotebook::Display --
#
#       Brings up a particular page in the notebook.
#   
# Arguments:
#       w      the "base" widget.
#       name   bring up this page.
# Results:
#       none.

proc ::mnotebook::Display {w name} {

    variable widgetGlobals
    upvar ::mnotebook::${w}::nbInfo nbInfo
    upvar ::mnotebook::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1} {
	puts "::mnotebook::Display w=$w, name=$name, display=$nbInfo(display),\
	  current=$nbInfo(current)"
    }
    if {[info exists nbInfo(page-$name)]} {
	set page $nbInfo(page-$name)
    } elseif {[winfo exists $w.page$name]} {
	set page $w.page$name
    }
    if {$page == ""} {
	return -code error "bad notebook page \"$name\""
    }
    set nbInfo(display) $page
    if {$widgetGlobals(debug) > 2} {
	puts "\t +++++ page=$page, pending=$nbInfo(pending)"
    }
    if {$nbInfo(pending) == ""} {
	set nbInfo(pending) [after idle [list ::mnotebook::Build $w]]
    }
}

# mnotebook::Build --
# 
#       Does the actual job of unpacking and packing pages.
#       Shall only be called at idle. Calls FixSize to compute geometry
#       depending on nbInfo(fixSize).

proc ::mnotebook::Build {w} {
    
    variable widgetGlobals
    upvar ::mnotebook::${w}::nbInfo nbInfo
    upvar ::mnotebook::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1} {
	puts "::mnotebook::Build w=$w, current=$nbInfo(current),\
	  display=$nbInfo(display), fixSize=$nbInfo(fixSize)"
    }
    set nbInfo(pending) ""
    if {[string equal $nbInfo(display) $nbInfo(current)]} {
	return
    }
    if {$nbInfo(current) != ""} {
	pack forget $nbInfo(current)
    }
    set page $nbInfo(display)
    pack $page -expand yes -fill both
    
    # current id the actual packed page.
    set nbInfo(current) $page
    if {$nbInfo(fixSize)} {
	FixSize $w
    }
}

# mnotebook::FixSize --
#
#       Scan through all our pages and set the notebooks size equal to
#       the size of the biggest page.
#   
# Arguments:
#       win    the "base" widget.
# Results:
#       none.

proc ::mnotebook::FixSize {win} {
    
    variable widgetGlobals
    upvar ::mnotebook::${win}::nbInfo nbInfo
    upvar ::mnotebook::${win}::widgets widgets
    
    if {$widgetGlobals(debug) > 2} {
	puts "::mnotebook::FixSize win=$win"
    }
    update idletasks
    set maxw 0
    set maxh 0
    foreach page $nbInfo(pages) {
	set w [winfo reqwidth $page]
	if {$w > $maxw} {
	    set maxw $w
	}
	set h [winfo reqheight $page]
	if {$h > $maxh} {
	    set maxh $h
	}
    }
    if {($maxw > [winfo reqwidth $win]) || ($maxh > [winfo reqheight $win])} {
	set bd [$win cget -borderwidth]
	set maxw [expr {$maxw + 2 * $bd}]
	set maxh [expr {$maxh + 2 * $bd}]
	if {$widgetGlobals(debug) > 2} {
	    puts "\t configure -width $maxw -height $maxh"
	}
	
	# Be sure to configure the original frame widget.
	$widgets(frame) configure -width $maxw -height $maxh
    }
    set nbInfo(fixSize) 0
}

# mnotebook::DestroyHandler --
#
#       The exit handler of a notebook.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       the internal state is cleaned up, namespace deleted.

proc ::mnotebook::DestroyHandler {w} {
    
    variable widgetGlobals
    upvar ::mnotebook::${w}::nbInfo nbInfo

    if {$widgetGlobals(debug) > 2} {
	puts "::mnotebook::DestroyHandler w=$w, pending=$nbInfo(pending)"
    }
    if {$nbInfo(pending) != ""} {
	catch {after cancel $nbInfo(pending)}
    }

    # Remove the namespace with the widget.
    if {[string equal [winfo class $w] {Mnotebook}]} {
	namespace delete ::mnotebook::${w}
    }
}
    
#-------------------------------------------------------------------------------


