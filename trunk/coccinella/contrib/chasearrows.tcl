#  chasearrows.tcl ---
#  
#      This file is part of the whiteboard application. It implements two
#      running arrows to show a wait state.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: chasearrows.tcl,v 1.1.1.1 2002-12-08 10:54:14 matben Exp $
#
# ########################### USAGE ############################################
#
#   NAME
#      chasearrows - two running arrows.
#      
#   SYNOPSIS
#      chasearrows pathName ?options?
#      
#   OPTIONS
#      -background, background, Background
#      -foreground, foreground, Foreground
#      -size, size, Size
#      -takefocus, takeFocus, TakeFocus
#      
#   WIDGET COMMANDS
#      pathName cget option
#      pathName configure ?option? ?value option value ...?
#      pathName start
#      pathName stop
#
# ########################### CHANGES ##########################################
#
#       1.0      first release

package provide chasearrows 1.0

namespace eval ::chasearrows:: {

    # The public interface.
    namespace export chasearrows

    # Globals same for all instances of this widget.
    variable widgetGlobals
    
    set widgetGlobals(debug) 0
    set widgetGlobals(timeStep) 150
    set widgetGlobals(rotStep) [expr 3.14159/8]
}

# ::chasearrows::Init --
#
#       Contains initializations needed for the chasearrows widget. It is
#       only necessary to invoke it for the first instance of a widget since
#       all stuff defined here are common for all widgets of this type.
#       
# Arguments:
#       none.
# Results:
#       Defines option arrays.

proc ::chasearrows::Init {  }  {
    
    variable widgetGlobals
    variable widgetOptions
    variable widgetCommands
    
    if {$widgetGlobals(debug) > 1}  {
	puts "::chasearrows::Init"
    }
    
    # List all allowed options with their database names and class names.
    
    array set widgetOptions {
	-background    {background    Background }      \
	-foreground    {foreground    Foreground }      \
	-size          {size          Size       }      \
	-takefocus     {takeFocus     TakeFocus  }      \
    }
  
    # The legal widget commands.
    set widgetCommands {cget configure start stop}

    # Drawing stuff for the arrows.
    InitDrawingStuff

    # Options for this widget
    option add *ChaseArrows.background    white        widgetDefault
    option add *ChaseArrows.foreground    black        widgetDefault
    option add *ChaseArrows.size          32           widgetDefault
    option add *ChaseArrows.takeFocus     0            widgetDefault
    
    # Define the class bindings.
    # This allows us to clean up some things when we go away.
    bind ChaseArrows <Destroy> [list ::chasearrows::DestroyHandler %W]
}

# ::chasearrows::InitDrawingStuff --
#
#       Initialize the drawing coordinates for the arrows.
#       
# Arguments:
#       
# Results:
#       Globals initialized. 

proc ::chasearrows::InitDrawingStuff { } {
    global  tcl_platform
    
    variable widgetGlobals
    
    if {$widgetGlobals(debug) > 1}  {
	puts "::chasearrows::InitDrawingStuff"
    }

    # Drawing stuff for the arrows.
    set pi 3.14159
    set div [expr $pi/8]
    set step [expr $pi/8]
    set phiend [expr 3*$pi/4 + 0.001]
    set thetaDelta $widgetGlobals(rotStep)
    foreach size {16 32} {
	set ind -1
	if {$size == 16} {
	    set a 8
	    set r 6
	} else {
	    set a 16
	    set r 12
	}
	for {set theta 0.0} {$theta < $pi} {set theta [expr $theta + $thetaDelta]} {
	    incr ind
	    set lineCoords {}
	    for {set i 0} {$i < 2} {incr i} {
		set co {}
		for {set phi 0.0} {$phi <= $phiend} {set phi [expr $phi + $div]} {
		    lappend co   \
		      [expr $a + $r*cos($phi + $i*$pi + $theta)]  \
		      [expr $a + $r*sin($phi + $i*$pi + $theta)]
		}
		lappend lineCoords $co
	    }
	    set widgetGlobals(todraw,$size,$ind) $lineCoords
	}
	set widgetGlobals(lastInd) $ind
    }
    
    # Arrow heads.
    if {[string compare $tcl_platform(platform) {unix}] == 0} {
	set widgetGlobals(arrshape16) {4 4 2}
	set widgetGlobals(arrshape32) {5 5 3}
    } elseif {[string compare $tcl_platform(platform) {macintosh}] == 0} {
	set widgetGlobals(arrshape16) {3 3 2}
	set widgetGlobals(arrshape32) {4 4 2}
    } elseif {[string compare $tcl_platform(platform) {windows}] == 0} {
	set widgetGlobals(arrshape16) {4 4 2}
	set widgetGlobals(arrshape32) {5 5 3}
    }
}

# ::chasearrows::chasearrows --
#
#       The constructor of this class; it creates an instance named 'w' of the
#       chasearrows. 
#       
# Arguments:
#       w       the widget path.
#       args    (optional) list of key value pairs for the widget options.
# Results:
#       The widget path or an error. Calls the necessary procedures to make a 
#       complete movie controller widget.

proc ::chasearrows::chasearrows {w args}  {

    variable widgetGlobals
    variable widgetOptions

    if {$widgetGlobals(debug) > 1}  {
	puts "::chasearrows::chasearrows w=$w, args=$args"
    }
    
    # We need to make Init at least once.
    if {![info exists widgetOptions]}  {
	Init
    }
    
    # Error checking.
    foreach {name value} $args  {
	if {![info exists widgetOptions($name)]}  {
	    error "unknown option for the chasearrows: $name"
	}
    }
    
    # Continues in the 'Build' procedure.
    return [eval Build $w $args]
}

# ::chasearrows::Build --
#
#       Parses options, creates widget command, and calls the Configure 
#       procedure to do the rest.
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#       The widget path or an error.

proc ::chasearrows::Build { w args }  {

    variable widgetGlobals
    variable widgetOptions

    if {$widgetGlobals(debug) > 1}  {
	puts "::chasearrows::Build w=$w, args=$args"
    }

    # Instance specific namespace
    namespace eval ::chasearrows::${w} {
	variable options
	variable widgets
	variable wlocals
    }
    
    # Set simpler variable names.
    upvar ::chasearrows::${w}::options options
    upvar ::chasearrows::${w}::widgets widgets

    # We use a frame for this specific widget class.
    set widgets(this) [frame $w -class ChaseArrows]
    
    # Set only the name here.
    set widgets(canvas) $w.can
    set widgets(frame) ::chasearrows::${w}::${w}
    
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $widgets(frame)
    
    # Parse options. First get widget defaults.
    foreach name [array names widgetOptions] {
	set optName [lindex $widgetOptions($name) 0]
	set optClass [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
    }
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    if {[llength $args] > 0}  {
	array set options $args
    }
    
    # Create the actual widget procedure.
    proc ::${w} {command args}   \
      "eval ::chasearrows::WidgetProc {$w} \$command \$args"

    canvas $widgets(canvas) -width $options(-size) -height $options(-size)  \
      -bd 0 -highlightthickness 0 -bg $options(-background)
    pack $widgets(canvas) -fill both
    
    # The actual drawing takes place from 'Configure' which calls
    # the 'Draw' procedure when necessary.
    eval Configure $widgets(this) [array get options]

    return $w
}

# ::chasearrows::WidgetProc --
#
#       This implements the methods; only two: cget and configure.
#       
# Arguments:
#       w       the widget path.
#       command the actual command; cget or configure.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::chasearrows::WidgetProc { w command args }  {
    
    variable widgetGlobals
    variable widgetOptions
    variable widgetCommands
    upvar ::chasearrows::${w}::widgets widgets
    upvar ::chasearrows::${w}::options options
    
    if {$widgetGlobals(debug) > 1}  {
	puts "::chasearrows::WidgetProc w=$w, command=$command, args=$args"
    }
    
    # Error checking.
    if {[lsearch -exact $widgetCommands $command] == -1}  {
	error "unknown chasearrows command: $command"
    }
    set result {}
    
    # Which command?
    switch -- $command {
	cget {
	    if {[llength $args] != 1}  {
		error "wrong # args: should be $w cget option"
	    }
	    set result $options($args)
	}
	configure {
	    set result [eval Configure $w $args]
	}
	start {
	    set result [eval Start $w $args]
	}
	stop {
	    set result [eval Stop $w $args]
	}
    }
    return $result
}

# ::chasearrows::Configure --
#
#       Implements the "configure" widget command (method). 
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::chasearrows::Configure { w args }  {
    
    variable widgetGlobals
    variable widgetOptions
    upvar ::chasearrows::${w}::options options
    upvar ::chasearrows::${w}::widgets widgets
    upvar ::chasearrows::${w}::wlocals wlocals
    
    if {$widgetGlobals(debug) > 1}  {
	puts "::chasearrows::Configure w=$w, args=$args"
    }
    
    # Error checking.
    foreach {name value} $args  {
	if {![info exists widgetOptions($name)]}  {
	    error "unknown option for the chasearrows: $name"
	}
    }
    if {[llength $args] == 0}  {
	
	# Return all options.
	foreach opt [lsort [array names widgetOptions]] {
	    set optName [lindex $widgetOptions($opt) 0]
	    set optClass [lindex $widgetOptions($opt) 1]
	    set def [option get $w $optName $optClass]
	    lappend results [list $opt $optName $optClass $def $options($opt)]
	}
	return $results
    } elseif {[llength $args] == 1}  {
	
	# Return configuration value for this option.
	set opt $args
	set optName [lindex $widgetOptions($opt) 0]
	set optClass [lindex $widgetOptions($opt) 1]
	set def [option get $w $optName $optClass]
	return [list $opt $optName $optClass $def $options($opt)]
    }
    
    # Error checking.
    if {[expr {[llength $args]%2}] == 1}  {
	error "value for \"[lindex $args end]\" missing"
    }    
        
    # Process the new configuration options.
    set needsRedraw 0
    array set opts $args
        
    foreach opt [array names opts] {
	set newValue $opts($opt)
	if {[info exists options($opt)]}  {
	    set oldValue $options($opt)
	} else  {
	    set oldValue {}
	}
	set options($opt) $newValue
	if {$widgetGlobals(debug) > 1}  {
	    puts "::chasearrows::Configure opt=$opt, n=$newValue, o=$oldValue"
	}
	
	# Some options need action from the widgets side.
	switch -- $opt {
	    -background {
		$widgets(canvas) configure -background $newValue
	    }
	    -foreground {
		$widgets(canvas) itemconfigure t_arrow -fill $newValue
	    }
	    -size {
		if {($newValue == 16) || ($newValue == 32)} {
		    $widgets(canvas) configure -width $newValue -height $newValue
		    InitDrawingStuff
		} else {
		    error "chasearrows: value for \"-size\" must be 16 or 32"
		}
	    }
	}
    }
}
		
# ::chasearrows::Start --
#
#       Starts the running arrows.
#       
# Arguments:
#       w       the widget path.
# Results:
#       none.

proc ::chasearrows::Start {w} {

    variable widgetGlobals
    upvar ::chasearrows::${w}::options options
    upvar ::chasearrows::${w}::widgets widgets
    upvar ::chasearrows::${w}::wlocals wlocals

    if {$widgetGlobals(debug) > 1}  {
	puts "::chasearrows::Start w=$w"
    }
    set wlocals(thetaInd) 0
    set theta 0
    set size $options(-size)

    # Draw the arrows.
    foreach coords $widgetGlobals(todraw,$size,0) {
	eval {$widgets(canvas) create line} $coords {-tag t_arrow   \
	  -fill $options(-foreground) -arrow last   \
	  -arrowshape $widgetGlobals(arrshape$size)}
    }
    
    # Start timer to animate.
    if {[info exists wlocals(killerId)]} {
	catch {after cancel $wlocals(killerId)}
    }
    set wlocals(killerId) [after $widgetGlobals(timeStep)   \
      [list [namespace current]::Rotate $w]]
    return {}
}
		
# ::chasearrows::Rotate --
#
#       Rotates the running arrows.
#       
# Arguments:
#       w       the widget path.
# Results:
#       none.

proc ::chasearrows::Rotate {w} {

    variable widgetGlobals
    upvar ::chasearrows::${w}::options options
    upvar ::chasearrows::${w}::widgets widgets
    upvar ::chasearrows::${w}::wlocals wlocals

    incr wlocals(thetaInd)
    if {$wlocals(thetaInd) > $widgetGlobals(lastInd)} {
	set wlocals(thetaInd) 0
    }
    set ind $wlocals(thetaInd)
    catch {$widgets(canvas) delete t_arrow}
    set size $options(-size)

    # Draw the arrows.
    foreach coords $widgetGlobals(todraw,$size,$ind) {
	eval {$widgets(canvas) create line} $coords {-tag t_arrow   \
	  -fill $options(-foreground) -arrow last   \
	  -arrowshape $widgetGlobals(arrshape$size)}
    }
    
    # Reschedule timer.
    set wlocals(killerId) [after $widgetGlobals(timeStep)   \
      [list [namespace current]::Rotate $w]]
}

# ::chasearrows::Stop --
#
#       Stops the running arrows.
#       
# Arguments:
#       w       the widget path.
# Results:
#       none.

proc ::chasearrows::Stop {w} {

    variable widgetGlobals
    upvar ::chasearrows::${w}::options options
    upvar ::chasearrows::${w}::widgets widgets
    upvar ::chasearrows::${w}::wlocals wlocals

    if {$widgetGlobals(debug) > 1}  {
	puts "::chasearrows::Stop w=$w"
    }
    if {[info exists wlocals(killerId)]} {
	catch {after cancel $wlocals(killerId)}
    }
    catch {$widgets(canvas) delete t_arrow}
    return {}
}

# ::chasearrows::DestroyHandler --
#
#       The exit handler of a chasearrows widget.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       the internal state is cleaned up, namespace deleted.

proc ::chasearrows::DestroyHandler {w} {

    upvar ::chasearrows::${w}::wlocals wlocals
 
    if {[info exists wlocals(killerId)]} {
	catch {after cancel $wlocals(killerId)}
    }
     
    # Remove the namespace with the widget.
    namespace delete ::chasearrows::${w}
}

#-------------------------------------------------------------------------------