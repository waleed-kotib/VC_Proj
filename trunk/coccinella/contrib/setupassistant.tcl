#  setupassistant.tcl ---
#  
#      This file is part of the whiteboard application.
#      It implements a setup assistant toplevel interface.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
# $Id: setupassistant.tcl,v 1.1.1.1 2002-12-08 10:56:20 matben Exp $
# 
# ########################### USAGE ############################################
#
#   NAME
#      setupassistant - a setup assistant toplevel dialog.
#      
#   SYNOPSIS
#      setupassistant pathName ?options?
#      
#   OPTIONS
#       Notebook class:
#	-borderwidth, borderWidth, BorderWidth
#	-relief, relief, Relief
#	-takefocus, takeFocus, TakeFocus
#	
#	SetupAssistant class:
#	-closecommand, closeCommand, CloseCommand
#	-finishcommand, finishCommand, FinishCommand
#	-font, font, Font
#	-nextpagecommand, nextPageCommand, NextPageCommand
#	-takefocus, takeFocus, TakeFocus
#	
#   WIDGET COMMANDS
#      pathName cget option
#      pathName configure ?option? ?value option value ...?
#      pathName displaypage pageName
#      pathName deletepage pageName
#      pathName newpage pageName ?option value ...?
#
# ########################### CHANGES ##########################################
#
#       1.0     

package require notebook
package provide setupassistant 1.0

namespace eval ::setupassistant::  {
    
    namespace export setupassistant

    # Globals same for all instances of this widget.
    variable widgetGlobals

    set widgetGlobals(debug) 0
}

# ::setupassistant::Init --
#
#       Contains initializations needed for the setupassistant widget. It is
#       only necessary to invoke it for the first instance of a widget since
#       all stuff defined here are common for all widgets of this type.
#       
# Arguments:
#       none.
# Results:
#       Defines option arrays and icons for movie controllers.

proc ::setupassistant::Init { } {
    global  tcl_platform

    variable widgetCommands
    variable widgetGlobals
    variable widgetOptions
    variable notebookOptions
    variable suOptions

    if {$widgetGlobals(debug) > 1}  {
	puts "::setupassistant::Init"
    }
    
    # List all allowed options with their database names and class names.
    
    array set widgetOptions {
	-background          {background           Background          }  \
	-borderwidth         {borderWidth          BorderWidth         }  \
	-closecommand        {closeCommand         CloseCommand        }  \
	-finishcommand       {finishCommand        FinishCommand       }  \
	-font                {font                 Font                }  \
	-nextpagecommand     {nextPageCommand      NextPageCommand     }  \
	-takefocus           {takeFocus            TakeFocus           }  \
    }
    set notebookOptions {-borderwidth -relief}
    set suOptions {
	-background -font -takefocus -closecommand -finishcommand -nextpagecommand
    }
  
    # The legal widget commands. These are actually the Notebook commands.
    set widgetCommands {cget configure deletepage displaypage newpage}

    option add *SetupAssistant.activeTabColor      #efefef      widgetDefault
    option add *SetupAssistant.background          #ffffff      widgetDefault
    option add *SetupAssistant.closeCommand        {}           widgetDefault
    option add *SetupAssistant.finishCommand       {}           widgetDefault
    option add *SetupAssistant.nextPageCommand     {}           widgetDefault
    option add *Notebook.takeFocus                 0            widgetDefault
    
    # Platform specifics...
    switch $tcl_platform(platform) {
	{unix} {
	    option add *SetupAssistant.font    {Helvetica -12 bold}   widgetDefault
	}
	{windows} {
	    option add *SetupAssistant.font    {system}    widgetDefault
	}
	{macintosh} {
	    option add *SetupAssistant.font    {system}    widgetDefault
	}
    }
  
    # This allows us to clean up some things when we go away.
    bind SetupAssistant <Destroy> [list ::setupassistant::DestroyHandler %W]
}

# setupassistant::setupassistant --
#
#       Constructor for the Mac tabbed notebook.
#   
# Arguments:
#       w      the widget path.
#       args   list of '-name value' options.
# Results:
#       The widget.

proc ::setupassistant::setupassistant {w args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable suOptions
    variable notebookOptions

    if {$widgetGlobals(debug) > 1} {
	puts "::setupassistant::setupassistant w=$w, args='$args'"
    }
    
    # Perform a one time initialization.
    if {![info exists widgetOptions]} {
	Init
    }
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]} {
	    error "unknown option \"$name\" for the setupassistant widget"
	}
    }

    # Instance specific namespace
    namespace eval ::setupassistant::${w} {
	variable options
	variable widgets
	variable suInfo
    }
    
    # Set simpler variable names.
    upvar ::setupassistant::${w}::options options
    upvar ::setupassistant::${w}::widgets widgets
    upvar ::setupassistant::${w}::suInfo suInfo

    # We use a frame for this specific widget class.
    set widgets(this) [frame $w -class SetupAssistant]
    set widgets(frame) ::setupassistant::${w}::${w}
    set widgets(nbframe) $w.notebook
    set widgets(head) $w.head
    set widgets(btframe) $w.btframe
    set widgets(btforward) $w.btframe.fwd
    set widgets(btbackward) $w.btframe.bwd
    
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $widgets(frame)

    # Process the new configuration options.
    array set argsarr $args

    # Parse options for the tabs. First get widget defaults.
    foreach name $suOptions {
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
    
    # Create the actual widget procedure.
    proc ::${w} {command args}   \
      "eval ::setupassistant::WidgetProc {$w} \$command \$args"
    
    # Select the notebook options from the args.
    set notebookArgs {}
    foreach name $notebookOptions {
	if {[info exists argsarr($name)]} {
	    lappend notebookArgs $name $argsarr($name)
	}
    }
    
    # Build.
    pack [label $widgets(head) -text {Setup Assistant} -font $options(-font) \
      -anchor w -bg $options(-background)] -padx 10 -pady 4 -side top -fill x
    pack [frame $w.div1 -height 2 -borderwidth 2 -relief sunken  \
      -bg $options(-background)] -fill x -pady 2
    
    # Creating the notebook widget also makes all the database initializations.
    eval {::notebook::notebook $widgets(nbframe)} $notebookArgs
    $widgets(frame) configure -bg $options(-background)
    pack $widgets(nbframe) -expand yes -fill both
    
    pack [frame $w.div2 -height 2 -borderwidth 2 -relief sunken  \
       -bg $options(-background)] -fill x -pady 2
    pack [frame $widgets(btframe) -bg $options(-background)]  \
      -fill x -side top
    pack [button $widgets(btforward) -text {Next} -width 10   \
      -command [list [namespace current]::ForwardCmd $w]  \
      -highlightbackground $options(-background)]   \
      -side right -padx 5 -pady 5
    pack [button $widgets(btbackward) -text {Close} -width 10 \
       -command [list [namespace current]::BackwardCmd $w]  \
       -highlightbackground $options(-background)] \
       -side right -padx 5 -pady 5
    
    set suInfo(current) {}
    set suInfo(pending) {}

    return $w
}

# ::setupassistant::WidgetProc --
#
#       This implements the methods, cget, configure etc.
#       
# Arguments:
#       w       the widget path.
#       command the actual command; cget, configure etc.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::setupassistant::WidgetProc {w command args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable widgetCommands
    upvar ::setupassistant::${w}::options options
    upvar ::setupassistant::${w}::widgets widgets
    
    if {$widgetGlobals(debug) > 2} {
	puts "::setupassistant::WidgetProc w=$w, command=$command, args=$args"
    }
    set result {}
    
    # Which command?
    switch -- $command {
	{cget} {
	    if {[llength $args] != 1} {
		error "wrong # args: should be $w cget option"
	    }
	    set result $options($args)
	}
	{configure} {
	    set result [eval {Configure $w} $args]
	}
	{deletepage} {
	    set result [eval {DeletePage $w} $args]
	}
	{displaypage} {
	    if {[llength $args] != 1} {
		error "wrong # args: should be $w displaypage pageName"
	    }
	    set result [eval {Display $w} $args]
	}
	{newpage} {
	    set result [eval {NewPage $w} $args]
	}
	{default} {
	    error "unknown command \"$command\" of the setupassistant widget.\
	      Must be one of $widgetCommands"
	}
    }
    return $result
}

# ::setupassistant::Configure --
#
#       Implements the "configure" widget command (method). 
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::setupassistant::Configure {w args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable suOptions
    upvar ::setupassistant::${w}::options options
    upvar ::setupassistant::${w}::widgets widgets
    
    if {$widgetGlobals(debug) > 1} {
	puts "::setupassistant::Configure w=$w, args='$args'"
    }
    
    # Error checking.
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]}  {
	    error "unknown option for the setupassistant widget: $name"
	}
    }
    if {[llength $args] == 0} {
	
	# Return all setupassistant options.
	foreach opt $suOptions {
	    set optName [lindex $widgetOptions($opt) 0]
	    set optClass [lindex $widgetOptions($opt) 1]
	    set def [option get $w $optName $optClass]
	    #puts "opt=$opt, optName=$optName, optClass=$optClass, def=$def"
	    lappend results [list $opt $optName $optClass $def $options($opt)]
	}
	
	# Get all notebook options as well.
	set nbConfig [$widgets(nbframe) configure]
	return "$results $nbConfig"
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
	error "value for \"[lindex $args end]\" missing"
    }    

    # Process the new configuration options.
    array set argsarr $args
    set redraw 0
    set notebookArgs {}

    # Process the configuration options given to us.
    foreach opt [array names argsarr] {
	set newValue $argsarr($opt)
	set oldValue $options($opt)
	switch -- $opt {
	    {-borderwidth} - {-relief} {
		lappend notebookArgs $opt $newValue
	    }
	}
    }
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    if {[llength $args] > 0}  {
	array set options $args
    }
    if {[llength $notebookArgs] > 0} {
	eval {$widgets(nbframe) configure} $notebookArgs
    }
    
    # Redraw if needed.
    if {$redraw} {
	Refresh $w
    }
    return {}
}

# setupassistant::NewPage --
#
#       Creates a new page in the widget.
#   
# Arguments:
#       w      the widget.
#       name   its name.
#       args   -headtext text
#              -position pageName
# Results:
#       The page widget path.

proc ::setupassistant::NewPage {w name args} {
    
    variable widgetGlobals
    upvar ::setupassistant::${w}::suInfo suInfo
    upvar ::setupassistant::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1} {
	puts "::setupassistant::NewPage w=$w, name=$name"
    }
    array set argsarr $args
    set page [$widgets(nbframe) page $name]
    lappend suInfo(pages) $name
    if {[info exists argsarr(-headtext)]} {
	set suInfo($name,head) $argsarr(-headtext)
    } else {
	set suInfo($name,head) $name
    }
    if {$suInfo(pending) == ""} {
	set id [after idle [list ::setupassistant::Refresh $w]]
	set suInfo(pending) $id
    }
    
    return $page
}

# setupassistant::DeletePage --
#
#       Deletes a page in the widget.
#   
# Arguments:
#       w      the widget.
#       name   its name.
# Results:
#       none.

proc ::setupassistant::DeletePage {w name} {
    
    variable widgetGlobals
    upvar ::setupassistant::${w}::suInfo suInfo
    upvar ::setupassistant::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1} {
	puts "::setupassistant::DeletePage w=$w, name=$name"
    }
    $widgets(nbframe) deletepage $name
    set ind [lsearch -exact $suInfo(pages) $name]
    if {$ind >= 0} {
	set suInfo(pages) [lreplace $suInfo(pages) $ind $ind]
	if {$suInfo(pending) == ""} {
	    set id [after idle [list ::setupassistant::Refresh $w]]
	    set suInfo(pending) $id
	}
    }
    return {}
}

# setupassistant::Refresh --
#
#       Makes the actual drawings of all the.
#   
# Arguments:
#       w      the widget.
# Results:
#       The page widget path.

proc ::setupassistant::Refresh {w} {
    
    variable widgetGlobals
    upvar ::setupassistant::${w}::options options
    upvar ::setupassistant::${w}::suInfo suInfo

    if {$widgetGlobals(debug) > 1} {
	puts "::setupassistant::Refresh w=$w"
    }
    if {[string length $suInfo(current)]} {
	Display $w $suInfo(current)
    } else {
	Display $w [lindex $suInfo(pages) 0]
    }	
    set suInfo(pending) {}
}

# setupassistant::ForwardCmd --
#
#       Binding command for the Next button.
#   
# Arguments:
#       w      the widget.
# Results:
#       none.

proc ::setupassistant::ForwardCmd {w} {
    
    variable widgetGlobals
    upvar ::setupassistant::${w}::options options
    upvar ::setupassistant::${w}::suInfo suInfo
    upvar ::setupassistant::${w}::widgets widgets
    
    # If any registers callback, check return value.
    if {[string length $options(-nextpagecommand)]} {
	set code [catch {uplevel #0 $options(-nextpagecommand) $suInfo(current)} msg]
	if {$code != 0} {
	    return
	}
    }
    set ind [lsearch -exact $suInfo(pages) $suInfo(current)]
    incr ind
    set nextpage [lindex $suInfo(pages) $ind]
    Display $w $nextpage
}

# setupassistant::BackwardCmd --
#
#       Binding command for the Previous button.
#   
# Arguments:
#       w      the widget.
# Results:
#       none.

proc ::setupassistant::BackwardCmd {w} {
    
    variable widgetGlobals
    upvar ::setupassistant::${w}::suInfo suInfo
    upvar ::setupassistant::${w}::widgets widgets

    set ind [lsearch -exact $suInfo(pages) $suInfo(current)]
    #puts "BackwardCmd ind=$ind"
    if {$ind > 0} {
	incr ind -1
    }
    set prevpage [lindex $suInfo(pages) $ind]
    Display $w $prevpage
}

# setupassistant::Display --
#
#       Makes the name page the frontmost one.
#   
# Arguments:
#       w      the widget.
#       name   its name.
# Results:
#       none.

proc ::setupassistant::Display {w name} {
    
    variable widgetGlobals
    upvar ::setupassistant::${w}::options options
    upvar ::setupassistant::${w}::suInfo suInfo
    upvar ::setupassistant::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1} {
	puts "::setupassistant::Display w=$w, name=$name"
    }
    set ind [lsearch -exact $suInfo(pages) $name]
    set lastInd [expr [llength $suInfo(pages)] - 1]
    if {$widgetGlobals(debug) > 1} {
	puts "ind=$ind, lastInd=$lastInd"
    }
    
    # Configure the buttons.
    if {$ind == 0} {
	$widgets(btbackward) configure -text {Close}  \
	  -command $options(-closecommand)
	$widgets(btforward) configure -text {Next}  \
	  -command [list [namespace current]::ForwardCmd $w]
    } else {
	$widgets(btbackward) configure -text {Previous}  \
	  -command [list [namespace current]::BackwardCmd $w]
    } 
    if {$ind == $lastInd} {
	$widgets(btforward) configure -text {Finish}   \
	  -command $options(-finishcommand)
    } else {
	$widgets(btforward) configure -text {Next}	\
	  -command [list [namespace current]::ForwardCmd $w]
    }
    
    # Set head text.
    $widgets(head) configure -text $suInfo($name,head)
    
    # Set notebook page.
    $widgets(nbframe) displaypage $name
    set suInfo(current) $name
}

# setupassistant::DestroyHandler --
#
#       The exit handler of a setupassistant.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       the internal state is cleaned up, namespace deleted.

proc ::setupassistant::DestroyHandler {w} {
    variable widgetGlobals
    
    if {$widgetGlobals(debug) > 1} {
	puts "::setupassistant::DestroyHandler w=$w"
    }

    # Remove the namespace with the widget.
    if {[string compare [winfo class $w] {SetupAssistant}] == 0} {
	namespace delete ::setupassistant::${w}
    }
}
    
#-------------------------------------------------------------------------------


