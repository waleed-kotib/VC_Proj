#  notebook.tcl ---
#  
#      This file is part of The Coccinella application.
#      It implements a notebook interface.
#      Code idee from Harrison & McLennan
#      
#  Copyright (c) 2003-2004  Mats Bengtsson
#  
# $Id: notebook.tcl,v 1.5 2004-06-09 14:26:17 matben Exp $
# 
# ########################### USAGE ############################################
#
#   NAME
#      notebook - a notebook widget.
#      
#   SYNOPSIS
#      notebook pathName ?options?
#      
#   OPTIONS
#       Notebook class:
#	-borderwidth, borderWidth, BorderWidth
#	-relief, relief, Relief
#	-takefocus, takeFocus, TakeFocus
#	
#   WIDGET COMMANDS
#      pathName cget option
#      pathName configure ?option? ?value option value ...?
#      pathName deletepage pageName
#      pathName displaypage pageName
#      pathName page pageName
#      pathName pages
#
# ########################### CHANGES ##########################################
#
#       1.0     

package provide notebook 1.0

namespace eval ::notebook::  {
    
    namespace export notebook
    
    # Globals same for all instances of this widget.
    variable widgetGlobals

    set widgetGlobals(debug) 0
}

# ::notebook::Init --
#
#       Contains initializations needed for the notebook widget. It is
#       only necessary to invoke it for the first instance of a widget since
#       all stuff defined here are common for all widgets of this type.
#       
# Arguments:
#       none.
# Results:
#       Defines option arrays and icons for movie controllers.

proc ::notebook::Init { } {
    global  tcl_platform

    variable widgetCommands
    variable widgetGlobals
    variable widgetOptions
    variable notebookOptions

    if {$widgetGlobals(debug) > 1}  {
	puts "::notebook::Init"
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
    option add *Notebook.background                white        widgetDefault
    option add *Notebook.borderWidth               0            widgetDefault
    option add *Notebook.relief                    flat         widgetDefault
    option add *Notebook.takeFocus                 0            widgetDefault
    
    # This allows us to clean up some things when we go away.
    bind Notebook <Destroy> [list ::notebook::DestroyHandler %W]
}

# notebook::notebook --
#
#       Constructor for the notebook.
#   
# Arguments:
#       w      the widget.
#       args   list of '-name value' options.
# Results:
#       The widget.

proc ::notebook::notebook {w args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable notebookOptions

    if {$widgetGlobals(debug) > 1} {
	puts "::notebook::notebook w=$w, args='$args'"
    }
    
    # Perform a one time initialization.
    if {![info exists widgetOptions]} {
	Init
    }
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]} {
	    return -code error "unknown option \"$name\" for the notebook widget"
	}
    }

    # Instance specific namespace
    namespace eval ::notebook::${w} {
	variable options
	variable widgets
	variable nbInfo
    }
    
    # Set simpler variable names.
    upvar ::notebook::${w}::options options
    upvar ::notebook::${w}::widgets widgets
    upvar ::notebook::${w}::nbInfo nbInfo

    # We use a frame for this specific widget class.
    set widgets(this) [frame $w -class Notebook]
    #set widgets(frame) $widgets(this)
    set widgets(frame) ::notebook::${w}::${w}
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
      "eval ::notebook::WidgetProc {$w} \$command \$args"
        
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

# ::notebook::WidgetProc --
#
#       This implements the methods, cget, configure etc.
#       
# Arguments:
#       w       the widget path.
#       command the actual command; cget, configure etc.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::notebook::WidgetProc {w command args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable widgetCommands
    upvar ::notebook::${w}::options options
    upvar ::notebook::${w}::widgets widgets
    upvar ::notebook::${w}::nbInfo nbInfo
    
    if {$widgetGlobals(debug) > 2} {
	puts "::notebook::WidgetProc w=$w, command=$command, args=$args"
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
	    if {[llength $args] != 1} {
		return -code error "wrong # args: should be $w displaypage pageName"
	    }
	    set result [eval {Display $w} $args]
	}
	page {
	    set result [eval {Page $w} $args]
	}
	pages {
	    set result [Pages $w]
	}
	default {
	    return -code error "unknown command \"$command\" of the notebook widget.\
	      Must be one of $widgetCommands"
	}
    }
    return $result
}

# ::notebook::Configure --
#
#       Implements the "configure" widget command (method). 
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::notebook::Configure {w args} {
    
    variable widgetGlobals
    variable widgetOptions
    upvar ::notebook::${w}::options options
    upvar ::notebook::${w}::widgets widgets
    
    if {$widgetGlobals(debug) > 1} {
	puts "::notebook::Configure w=$w, args='$args'"
    }
    
    # Error checking.
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]}  {
	    return -code error "unknown option for the notebook widget: $name"
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

# notebook::Page --
#
#       Adds a new page to an existing notebook.
#   
# Arguments:
#       w      the "base" widget.
#       name   the name of the new page.
# Results:
#       The page widget path.

proc ::notebook::Page {w name} {

    variable widgetGlobals
    upvar ::notebook::${w}::nbInfo nbInfo
    upvar ::notebook::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1} {
	puts "::notebook::Page w=$w, name=$name"
    }
    set page "$w.page[incr nbInfo(uid)]"
    lappend nbInfo(pages)  $page
    set nbInfo(page-$name) $page
    set nbInfo(name-$page) $name
    
    # We should probably add configuration options here.
    frame $page
    
    # If this is the only page, display it.
    if {[llength $nbInfo(pages)] == 1} {
	::notebook::Display $w $name
    }
    
    # Need to rebuild since size may have changed.
    set nbInfo(fixSize) 1
    if {$nbInfo(pending) == ""} {
	set nbInfo(pending) [after idle [list ::notebook::Build $w]]
    }
    return $page
}

proc ::notebook::Pages {w} {

    upvar ::notebook::${w}::nbInfo nbInfo
    
    set names {}
    foreach key [array names nbInfo "name-*"] {
	lappend names $nbInfo($key)
    }
    return $names
}

# notebook::DeletePage --
#
#       Deletes a page from the notebook.
#   
# Arguments:
#       w      the widget.
#       name   the name of the deleted page.
# Results:
#       none.

proc ::notebook::DeletePage {w name} {

    variable widgetGlobals
    upvar ::notebook::${w}::nbInfo nbInfo

    if {$widgetGlobals(debug) > 1} {
	puts "::notebook::DeletePage w=$w, name=$name"
    }
    if {[info exists nbInfo(page-$name)]} {
	set page $nbInfo(page-$name)
    } else {
	return -code error "bad notebook page \"$name\""
    }
    set ind [lsearch -exact $nbInfo(pages) $page]
    if {$ind < 0} {
	return -code error "Page \"$name\" is not there"
    }
    set newCurrentPage $nbInfo(current)
    
    # If we are about to delete the current page, set another current.
    if {[string equal $page $nbInfo(current)]} {
	
	# Set next page to current.
	set newInd [expr $ind + 1]
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
    ::notebook::Display $w $newCurrentName
    after idle [list catch destroy $page]
    return {}
}

# notebook::Display --
#
#       Brings up a particular page in the notebook.
#   
# Arguments:
#       w      the "base" widget.
#       name   bring up this page.
# Results:
#       none.

proc ::notebook::Display {w name} {

    variable widgetGlobals
    upvar ::notebook::${w}::nbInfo nbInfo
    upvar ::notebook::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1} {
	puts "::notebook::Display w=$w, name=$name, display=$nbInfo(display),\
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
	set nbInfo(pending) [after idle [list ::notebook::Build $w]]
    }
}

# notebook::Build --
# 
#       Does the actual job of unpacking and packing pages.
#       Shall only be called at idle. Calls FixSize to compute geometry
#       depending on nbInfo(fixSize).

proc ::notebook::Build {w} {
    
    variable widgetGlobals
    upvar ::notebook::${w}::nbInfo nbInfo
    upvar ::notebook::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1} {
	puts "::notebook::Build w=$w, current=$nbInfo(current),\
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

# notebook::FixSize --
#
#       Scan through all our pages and set the notebooks size equal to
#       the size of the biggest page.
#   
# Arguments:
#       win    the "base" widget.
# Results:
#       none.

proc ::notebook::FixSize {win} {
    
    variable widgetGlobals
    upvar ::notebook::${win}::nbInfo nbInfo
    upvar ::notebook::${win}::widgets widgets
    
    if {$widgetGlobals(debug) > 2} {
	puts "::notebook::FixSize win=$win"
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
	set maxw [expr $maxw + 2 * $bd]
	set maxh [expr $maxh + 2 * $bd]
	if {$widgetGlobals(debug) > 2} {
	    puts "\t configure -width $maxw -height $maxh"
	}
	
	# Be sure to configure the original frame widget.
	$widgets(frame) configure -width $maxw -height $maxh
    }
    set nbInfo(fixSize) 0
}

# notebook::DestroyHandler --
#
#       The exit handler of a notebook.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       the internal state is cleaned up, namespace deleted.

proc ::notebook::DestroyHandler {w} {
    
    variable widgetGlobals
    upvar ::notebook::${w}::nbInfo nbInfo

    if {$widgetGlobals(debug) > 2} {
	puts "::notebook::DestroyHandler w=$w, pending=$nbInfo(pending)"
    }
    if {$nbInfo(pending) != ""} {
	catch {after cancel $nbInfo(pending)}
    }

    # Remove the namespace with the widget.
    if {[string equal [winfo class $w] {Notebook}]} {
	namespace delete ::notebook::${w}
    }
}
    
#-------------------------------------------------------------------------------


