# wavelabel.tcl ---
#
#      This file is part of The Coccinella application. 
#      It implements a combined label and dynamic status animation.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  This source file is distributed under the BSD licens.
#
# $Id: wavelabel.tcl,v 1.2 2004-10-09 13:21:55 matben Exp $
#
# ########################### USAGE ############################################
#
#   NAME
#      wavelabel - status animation and label
#      
#   SYNOPSIS
#      wavelabel pathName ?options?
#      
#   OPTIONS
#      -background, background, Background
#      -foreground, foreground, Foreground
#      -height, height, Height
#      -image, image, Image
#      -type, type, Type
#      
#   WIDGET COMMANDS
#      pathName cget option
#      pathName configure ?option? ?value option value ...?
#      pathName message str
#      pathName start
#      pathName stop
#
# ########################### CHANGES ##########################################
#
#       1.0      first release

package provide wavelabel 1.0

namespace eval ::wavelabel:: {

    # Static variables.
    variable stat
    
    set stat(debug) 2
    
    # Define speed and update frequency. Pix per sec and times per sec.
    set speed 150
    set freq  16
    set stat(pix)  [expr int($speed/$freq)]
    set stat(wait) [expr int(1000.0/$freq)]
}

# ::wavelabel::Init --
#
#       Contains initializations needed for the wavelabel widget. It is
#       only necessary to invoke it for the first instance of a widget since
#       all stuff defined here are common for all widgets of this type.
#       
# Arguments:
#       none.
# Results:
#       Defines option arrays.

proc ::wavelabel::Init { } {
    global tcl_platform
    
    variable stat
    variable widgetOptions
    variable widgetCommands
    
    if {$stat(debug) > 1} {
	puts "::wavelabel::Init"
    }
    
    # We use a variable 'this(platform)' that is more convenient for MacOS X.
    switch -- $tcl_platform(platform) {
	unix {
	    set this(platform) $tcl_platform(platform)
	    if {[package vcompare [info tclversion] 8.3] == 1} {	
		if {[string equal [tk windowingsystem] "aqua"]} {
		    set this(platform) "macosx"
		}
	    }
	}
	windows - macintosh {
	    set this(platform) $tcl_platform(platform)
	}
    }

    # List all allowed options with their database names and class names.
    array set widgetOptions {
	-background    {background    Background }      \
	-font          {font          Font       }      \
	-foreground    {foreground    Foreground }      \
	-height        {height        Height     }      \
	-image         {image         Image      }      \
	-takefocus     {takeFocus     TakeFocus  }      \
	-type          {type          Type       }      \
    }
  
    # The legal widget commands.
    set widgetCommands {cget configure message start stop}

    # Drawing stuff for the arrows.

    
    # Options for this widget
    option add *WaveLabel.background    white        widgetDefault
    option add *WaveLabel.foreground    black        widgetDefault
    option add *WaveLabel.height        14           widgetDefault
    option add *WaveLabel.image         ""           widgetDefault
    option add *WaveLabel.takeFocus     0            widgetDefault
    option add *WaveLabel.type          image        widgetDefault

    # Platform specifics...
    switch -- $this(platform) {
	unix {
	    option add *WaveLabel.font  {Helvetica -10}   widgetDefault
	}
	windows {
	    option add *WaveLabel.font  {Arial 8}         widgetDefault
	}
	macintosh {
	    option add *WaveLabel.font  {Geneva 9}        widgetDefault
	}
	macosx {
	    option add *WaveLabel.font  {{Lucida Grande} 11} widgetDefault
	}
    }

    # Define the class bindings.
    # This allows us to clean up some things when we go away.
    bind WaveLabel <Destroy> [list ::wavelabel::DestroyHandler %W]
}

# ::wavelabel::wavelabel --
#
#       The constructor of this class; it creates an instance named 'w' of the
#       wavelabel. 
#       
# Arguments:
#       w       the widget path.
#       args    (optional) list of key value pairs for the widget options.
# Results:
#       The widget path or an error. Calls the necessary procedures to make a 
#       complete movie controller widget.

proc ::wavelabel::wavelabel {w args} {

    variable stat
    variable widgetOptions

    if {$stat(debug) > 1} {
	puts "::wavelabel::wavelabel w=$w, args=$args"
    }
    
    # We need to make Init at least once.
    if {![info exists widgetOptions]} {
	Init
    }
    
    # Error checking.
    foreach {name value} $args  {
	if {![info exists widgetOptions($name)]} {
	    error "unknown option for the wavelabel: $name"
	}
    }
    
    # Continues in the 'Build' procedure.
    return [eval Build $w $args]
}


# ::wavelabel::Build --
#
#       Parses options, creates widget command, and calls the Configure 
#       procedure to do the rest.
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#       The widget path or an error.

proc ::wavelabel::Build {w args} {

    variable stat
    variable widgetOptions

    if {$stat(debug) > 1} {
	puts "::wavelabel::Build w=$w, args=$args"
    }

    # Instance specific namespace
    namespace eval ::wavelabel::${w} {
	variable options
	variable widgets
	variable priv
    }
    
    # Set simpler variable names.
    upvar ::wavelabel::${w}::options options
    upvar ::wavelabel::${w}::widgets widgets

    # We use a frame for this specific widget class.
    set widgets(this) [frame $w -class WaveLabel]
    
    # Set only the name here.
    set widgets(canvas) $w.can
    set widgets(frame) ::wavelabel::${w}::${w}
    
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $widgets(frame)
    
    # Parse options. First get widget defaults.
    foreach name [array names widgetOptions] {
	set optName [lindex $widgetOptions($name) 0]
	set optClass [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
	#puts "name=$name, optName=$optName, optClass=$optClass, options=$options($name)"
    }
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    if {[llength $args] > 0} {
	array set options $args
    }
    
    # Create the actual widget procedure.
    proc ::${w} {command args}   \
      "eval ::wavelabel::WidgetProc {$w} \$command \$args"

    canvas $widgets(canvas) -height $options(-height)  \
      -bd 0 -highlightthickness 0 -bg $options(-background)
    pack $widgets(canvas) -fill both
    
    $widgets(canvas) create text 10 0 -anchor nw -text "" -font $options(-font) \
      -tags tstr

    # The actual drawing takes place from 'Configure' which calls
    # the 'Draw' procedure when necessary.
    eval Configure $widgets(this) [array get options]

    return $w
}

# ::wavelabel::WidgetProc --
#
#       This implements the methods; only two: cget and configure.
#       
# Arguments:
#       w       the widget path.
#       command the actual command; cget or configure.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::wavelabel::WidgetProc {w command args} {
    
    variable stat
    variable widgetOptions
    variable widgetCommands
    upvar ::wavelabel::${w}::widgets widgets
    upvar ::wavelabel::${w}::options options
    
    if {$stat(debug) > 1} {
	puts "::wavelabel::WidgetProc w=$w, command=$command, args=$args"
    }
    
    # Error checking.
    if {[lsearch -exact $widgetCommands $command] == -1} {
	error "unknown wavelabel command: $command"
    }
    set result {}
    
    # Which command?
    switch -- $command {
	cget {
	    if {[llength $args] != 1} {
		error "wrong # args: should be $w cget option"
	    }
	    set result $options($args)
	}
	configure {
	    set result [eval Configure $w $args]
	}
	message {
	    $widgets(canvas) itemconfigure stattxt -text [lindex $args 0]
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

# ::wavelabel::Configure --
#
#       Implements the "configure" widget command (method). 
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::wavelabel::Configure {w args} {
    
    variable stat
    variable widgetOptions
    upvar ::wavelabel::${w}::options options
    upvar ::wavelabel::${w}::widgets widgets
    upvar ::wavelabel::${w}::priv    priv
    
    if {$stat(debug) > 1} {
	puts "::wavelabel::Configure w=$w, args=$args"
    }
    
    # Error checking.
    foreach {name value} $args  {
	if {![info exists widgetOptions($name)]} {
	    error "unknown option for the wavelabel: $name"
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
	error "value for \"[lindex $args end]\" missing"
    }    
	
    # Process the new configuration options.
    set needsRedraw 0
    array set opts $args
	
    foreach opt [array names opts] {
	set newValue $opts($opt)
	if {[info exists options($opt)]} {
	    set oldValue $options($opt)
	} else  {
	    set oldValue {}
	}
	set options($opt) $newValue
	if {$stat(debug) > 1} {
	    puts "::wavelabel::Configure opt=$opt, n=$newValue, o=$oldValue"
	}
	
	# Some options need action from the widgets side.
	switch -- $opt {
	    -background {
		$widgets(canvas) configure -background $newValue
	    }
	    -foreground {
		$widgets(canvas) itemconfigure tstr -fill $newValue
	    }
	    -height {
		$widgets(canvas) configure -height $newValue
	    }
	}
    }
    if {[string equal $options(-type) "image"] && ($options(-image) == "")} {
	error "-image option missing"
    }
}
	
# ::wavelabel::Start --
#
#       Starts the running arrows.
#       
# Arguments:
#       w       the widget path.
# Results:
#       none.

proc ::wavelabel::Start {w} {

    variable stat
    upvar ::wavelabel::${w}::options options

    if {$stat(debug) > 1} {
	puts "::wavelabel::Start w=$w"
    }
    switch -- $options(-type) {
	image {
	    StartImage $w
	}
	step {
	    StartStep $w
	}
    }
    return {}
}

proc ::wavelabel::StartImage {w} {
    
    variable stat
    upvar ::wavelabel::${w}::options options
    upvar ::wavelabel::${w}::widgets widgets
    upvar ::wavelabel::${w}::priv    priv
    
    # Check if not already started.
    if {[info exists priv(killid)]} {
	return
    }
    
    set id [$widgets(canvas) create image 0 0 -anchor nw \
      -image $options(-image) -tags twave]
    $widgets(canvas) lower $id
    set priv(imw) [image width $options(-image)]
    set priv(id)  $id
    set priv(x)   0
    set priv(dir) 1
    set priv(killid) [after $stat(wait) [list ::wavelabel::AnimateImage $w]]
}

proc ::wavelabel::StartStep {w} {
    
    variable stat
    upvar ::wavelabel::${w}::options options
    upvar ::wavelabel::${w}::widgets widgets
    upvar ::wavelabel::${w}::priv    priv

    puts "::wavelabel::StartStep"
    
    set h  [winfo height $w]
    set yu 3
    set yl [expr $h-3]
    set xw [expr ($yl-$yu)/2]
    set dx [expr 2*$xw]
    set n  10
    set c $widgets(canvas)
    foreach {fr fg fb} [winfo rgb . black] break
    foreach {br bg bb} [winfo rgb . white] break
    set priv(x)    0
    set priv(dx)   $dx
    set priv(xtot) [expr $n * $dx]
    set priv(dir)  1
    
    # Right moving part.
    for {set i 0} {$i < $n} {incr i} {
	set x [expr -$i*$dx]
	set r [expr  ($fr + (($br - $fr) * $i)/$n) >> 8]
	set g [expr  ($fg + (($bg - $fg) * $i)/$n) >> 8]
	set b [expr  ($fb + (($bb - $fb) * $i)/$n) >> 8]
	set col [format "#%02x%02x%02x" $r $g $b]
	$c create rect $x $yu [expr $x-$xw] $yl -outline "" -fill $col \
	  -tags tstepright
    }
    
    # Left moving part.
    for {set i 0} {$i < $n} {incr i} {
	set x [expr -$i*$dx]
	set r [expr  ($fr + (($br - $fr) * $i)/$n) >> 8]
	set g [expr  ($fg + (($bg - $fg) * $i)/$n) >> 8]
	set b [expr  ($fb + (($bb - $fb) * $i)/$n) >> 8]
	set col [format "#%02x%02x%02x" $r $g $b]
	$c create rect $x $yu [expr $x-$xw] $yl -outline "" -fill $col \
	  -tags tstepleft
    }
    
    # Keep both of them beyond the left edge of the widget.
    $c scale tstepleft 0 0 -1 1
    $c move tstepleft -$priv(xtot) 0
    set priv(killid) [after $stat(wait) [list ::wavelabel::AnimateStep $w]]
}

proc ::wavelabel::AnimateImage {w} {

    variable stat
    upvar ::wavelabel::${w}::widgets widgets
    upvar ::wavelabel::${w}::priv    priv
    
    set deltax [expr $priv(dir) * $stat(pix)]
    incr priv(x) $deltax
    if {$priv(x) > [expr [winfo width $w] - $priv(imw)/2]} {
	set priv(dir) -1
    } elseif {$priv(x) <= -$priv(imw)/2} {
	set priv(dir) 1
    }
    $widgets(canvas) move twave $deltax 0
    set priv(killid) [after $stat(wait) [list ::wavelabel::AnimateImage $w]]
}

proc ::wavelabel::AnimateStep {w} {

    variable stat
    upvar ::wavelabel::${w}::widgets widgets
    upvar ::wavelabel::${w}::priv    priv

    set deltax [expr $priv(dir) * $stat(pix)]
    incr priv(x) $deltax
    set c $widgets(canvas)
    
    puts "priv(x)=$priv(x)"
    # Treat the left and right moving independently but let them trigger
    # each other.
    if {$priv(x) > [winfo width $w]} {
	
    }
    if {$priv(x) > [expr [winfo width $w] + $priv(xtot)]} {
	set priv(dir) -1
	$c move tstepleft [expr [winfo width $w] + $priv(xtot)] 0
    } elseif {$priv(x) <= 0} {
	set priv(dir) 1
    }
    if {$priv(dir) == 1} {
	$c move tstepright $deltax 0
    } else {
	$c move tstepleft $deltax 0
    }
    set priv(killid) [after $stat(wait) [list ::wavelabel::AnimateStep $w]]
}

# ::wavelabel::Stop --
#
#       Stops the animation.
#       
# Arguments:
#       w       the widget path.
# Results:
#       none.

proc ::wavelabel::Stop {w} {

    variable stat
    upvar ::wavelabel::${w}::options options
    upvar ::wavelabel::${w}::widgets widgets
    upvar ::wavelabel::${w}::priv    priv

    if {$stat(debug) > 1} {
	puts "::wavelabel::Stop w=$w"
    }
    if {[info exists priv(killid)]} {
	catch {after cancel $priv(killid)}
	unset priv(killid)
    }
    switch -- $options(-type) {
	image {
	    catch {$widgets(canvas) delete twave}
	}
	step {
	    catch {
		$widgets(canvas) delete tstepright
		$widgets(canvas) delete tstepleft
	    }
	}
    }
    return {}
}

proc ::wavelabel::X {t a k} {
    return [expr $a/$k * ($t - 2*$k*int(($t+$k)/(2*$k)))]
}

# ::wavelabel::DestroyHandler --
#
#       The exit handler of a wavelabel widget.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       the internal state is cleaned up, namespace deleted.

proc ::wavelabel::DestroyHandler {w} {

    upvar ::wavelabel::${w}::priv priv
 
    if {[info exists priv(killerId)]} {
	catch {after cancel $priv(killerId)}
    }
     
    # Remove the namespace with the widget.
    namespace delete ::wavelabel::${w}
}

#-------------------------------------------------------------------------------
