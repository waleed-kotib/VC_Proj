#  buttontray.tcl ---
#  
#      This file is part of The Coccinella application.
#      It implements a fancy button tray widget.
#      
#  Copyright (c) 2002-2004  Mats Bengtsson
#  
# $Id: buttontray.tcl,v 1.7 2004-03-31 07:55:17 matben Exp $
# 
# ########################### USAGE ############################################
#
#   NAME
#      buttontray - a tabbed notebook widget with a Mac touch.
#      
#   SYNOPSIS
#      buttontray pathName ?options?
#      
#   OPTIONS
#	-borderwidth, borderWidth, BorderWidth
#	-relief, relief, Relief
#	-takefocus, takeFocus, TakeFocus
#	
#   WIDGET COMMANDS
#      pathName cget option
#      pathName buttonconfigure name
#      pathName configure ?option? ?value option value ...?
#      pathName minwidth
#      pathName newbutton name text image imageDis cmd args
#
# ########################### CHANGES ##########################################
#
#       1.0     Original version

package provide buttontray 1.0

namespace eval ::buttontray::  {
    
    namespace export buttontray
    
}

# ::buttontray::Init --
#
#       Contains initializations needed for the buttontray widget. It is
#       only necessary to invoke it for the first instance of a widget since
#       all stuff defined here are common for all widgets of this type.
#       
# Arguments:
#       none.
#       
# Results:
#       none.

proc ::buttontray::Init { } {
    global  tcl_platform

    variable this
    variable widgetOptions
    variable frameOptions
    variable trayOptions
    
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
	-activebackground    {activeBackground     ActiveBackground    }  \
	-activeforeground    {activeForeground     ActiveForeground    }  \
	-background          {background           Background          }  \
	-borderwidth         {borderWidth          BorderWidth         }  \
	-disabledforeground  {disabledForeground   DisabledForeground  }  \
	-font                {font                 Font                }  \
	-foreground          {foreground           Foreground          }  \
	-relief              {relief               Relief              }  \
    }
    set frameOptions {-background -borderwidth -relief}
    foreach name [array names widgetOptions] {
	lappend trayOptions $name
    }
  
    # The legal widget commands.
    set widgetCommands {buttonconfigure cget configure minwidth newbutton}
        
    option add *ButtonTray.activeBackground   gray40            widgetDefault
    option add *ButtonTray.activeForeground   white             widgetDefault
    option add *ButtonTray.background         white             widgetDefault
    option add *ButtonTray.borderWidth        0                 widgetDefault
    option add *ButtonTray.disabledForeground gray50            widgetDefault
    option add *ButtonTray.foreground         black             widgetDefault
    option add *ButtonTray.relief             flat              widgetDefault
    
    # Platform specifics...
    switch -- $this(platform) {
	unix {
	    option add *ButtonTray.font  {Helvetica -10}   widgetDefault
	}
	windows {
	    option add *ButtonTray.font  {Arial 8}         widgetDefault
	}
	macintosh {
	    option add *ButtonTray.font  {Geneva 9}        widgetDefault
	}
	macosx {
	    option add *ButtonTray.font  {{Lucida Grande} 11} widgetDefault
	}
    }
    
    # This allows us to clean up some things when we go away.
    bind ButtonTray <Destroy> [list ::buttontray::DestroyHandler %W]
}

# buttontray::buttontray --
#
#       Constructor for the buttontray mega widget.
#   
# Arguments:
#       w      the widget.
#       height
#       args   list of '-name value' options.
#       
# Results:
#       The widget.

proc ::buttontray::buttontray {w height args} {
    
    variable widgetOptions
    variable frameOptions
    variable trayOptions
    
    # Perform a one time initialization.
    if {![info exists widgetOptions]} {
	Init
    }
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]} {
	    error "unknown option \"$name\" for the buttontray widget"
	}
    }

    # Instance specific namespace
    namespace eval ::buttontray::${w} {
	variable options
	variable widgets
	variable locals
    }
    
    # Set simpler variable names.
    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals

    # We use a frame for this specific widget class.
    set widgets(this) [frame $w -class ButtonTray]
    set widgets(canvas) [canvas $w.c -highlightthickness 0 -height $height]
    set widgets(frame) ::buttontray::${w}::${w}
    pack $widgets(canvas) -fill both -expand 1

    # Parse options for the widget. First get widget defaults.
    foreach name $trayOptions {
	set optName [lindex $widgetOptions($name) 0]
	set optClass [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
    }
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    if {[llength $args] > 0}  {
	array set options $args
    }
    set frameOpts {}
    foreach name $frameOptions {
	lappend frameOpts $name $options($name)
    }
    if {[llength $frameOpts]} {
	eval {$widgets(this) configure} $frameOpts
    }
    $widgets(canvas) configure -bg $options(-background)
    
    # Standard minimum button width.
    set locals(minbtwidth) 46
    
    # Left edge of previous button.
    set locals(xleft) 6
    
    # Consider the actual font metrics to make the necessary height.
    set linespace [font metrics $options(-font) -linespace]
    set locals(yoffset) 3
    set locals(ytxt) [expr $locals(yoffset) + 34]
    
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $widgets(frame)
    
    # Create the actual widget procedure.
    proc ::${w} {command args}   \
      "eval ::buttontray::WidgetProc {$w} \$command \$args"
 
    return $w
}

# ::buttontray::WidgetProc --
#
#       This implements the methods, cget, configure etc.
#       
# Arguments:
#       w       the widget path.
#       command the actual command; cget, configure etc.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::buttontray::WidgetProc {w command args} {
    
    variable widgetOptions
    variable widgetCommands
    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals
    
    #puts "::buttontray::WidgetProc w=$w, command=$command, args=$args"
    set result {}
    
    # Which command?
    switch -- $command {
	buttonconfigure {
	    set result [eval {ButtonConfigure $w} $args]
	}
	cget {
	    if {[llength $args] != 1} {
		error "wrong # args: should be $w cget option"
	    }
	    set result $options($args)
	}
	configure {
	    set result [eval {Configure $w} $args]
	}
	minwidth {
	    set result [MinWidth $w]
	}
	newbutton {
	    set result [eval {NewButton $w} $args]
	}
	default {
	    error "unknown command \"$command\" of the buttontray widget.\
	      Must be one of $widgetCommands"
	}
    }
    return $result
}

# ::buttontray::Configure --
#
#       Implements the "configure" widget command (method). 
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::buttontray::Configure {w args} {

    variable widgetOptions
    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals
    
    # Error checking.
    foreach {name value} $args  {
	if {![info exists widgetOptions($name)]}  {
	    error "unknown option for the moviecontroller: $name"
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
    



}

proc ::buttontray::NewButton {w name txt image imageDis cmd args} {

    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals
    
    set font $options(-font)
    set foreground $options(-foreground)
	
    set can $widgets(canvas)
    set loctxt [::msgcat::mc $txt]
    set txtwidth [expr [font measure $font $loctxt] + 6]
    set btwidth [expr $txtwidth > $locals(minbtwidth) ? $txtwidth : $locals(minbtwidth)]

    # Round to nearest higher even value.    
    set btwidth [expr $btwidth + $btwidth % 2]

    # Mid position of this button.
    set xpos [expr $locals(xleft) + $btwidth/2]
    set wlab [label ${can}.[string tolower $name] -bd 1 -relief flat \
      -image $image]
    set idlab [$can create window $xpos $locals(yoffset) \
      -anchor n -window $wlab]
    set idtxt [$can create text $xpos $locals(ytxt) -text $loctxt  \
      -font $font -anchor n -fill $foreground]
    
    set locals($name,idlab) $idlab
    set locals($name,idtxt) $idtxt
    set locals($name,wlab) $wlab
    set locals($name,image) $image
    set locals($name,imageDis) $imageDis
    set locals($name,cmd) $cmd
    set locals($name,state) normal

    ::buttontray::SetButtonBinds $w $name
    if {[llength $args]} {
	eval {::buttontray::ButtonConfigure $w $name} $args
    }
    incr locals(xleft) $btwidth
}

proc ::buttontray::SetButtonBinds {w name} {

    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals
    
    set can $widgets(canvas)
    set wlab $locals($name,wlab)
    set idtxt $locals($name,idtxt)
    set cmd $locals($name,cmd)

    bind $wlab <Enter> [list ::buttontray::Enter $w $name label]
    bind $wlab <Leave> [list ::buttontray::Leave $w $name label]
    bind $wlab <Button-1> [list $wlab configure -relief sunken]
    bind $wlab <ButtonRelease> "[list $wlab configure -relief raised];\
      $can configure -cursor arrow; $cmd"

    $can bind $idtxt <Enter> [list ::buttontray::Enter $w $name text]
    $can bind $idtxt <Leave> [list ::buttontray::Leave $w $name text]
    $can bind $idtxt <Button-1> $cmd   
}

proc ::buttontray::Enter {w name which} {

    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals

    set can $widgets(canvas)
    set wlab $locals($name,wlab)
    set idtxt $locals($name,idtxt)
    set activebackground $options(-activebackground)
    set activeforeground $options(-activeforeground)
    
    if {[string equal $which "label"]} {
	$wlab configure -relief raised
    } elseif {[string equal $which "text"]} {
	$can configure -cursor hand2
    }
    foreach {x0 y0 x1 y1} [$can bbox $idtxt] break
    set indent 2
    incr x0 $indent
    incr x1 -$indent
    set h2 [expr ($y1-$y0)/2]
    set coords [list \
      [expr $x0-$h2] $y0 [expr $x0+$h2] $y0 \
      [expr $x1-$h2] $y0 [expr $x1+$h2] $y0 \
    [expr $x1+$h2] $y1 [expr $x1-$h2] $y1 \
    [expr $x0+$h2] $y1 [expr $x0-$h2] $y1]
    $can itemconfigure $idtxt -fill $activeforeground
    $can create polygon $coords -fill $activebackground  \
      -tags activebg -outline "" -smooth 1 -splinesteps 10
    $can lower activebg $idtxt
}

proc ::buttontray::Leave {w name which} {

    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals

    set can $widgets(canvas)
    set wlab $locals($name,wlab)
    set idtxt $locals($name,idtxt)
    set foreground       $options(-foreground)
    set activebackground $options(-activebackground)
    set activeforeground $options(-activeforeground)
    set background       $options(-background)

    if {[string equal $which "label"]} {
	$wlab configure -relief flat
    }
    $can itemconfigure $idtxt -fill $foreground
    catch {$can delete activebg}
    $can configure -cursor arrow
}

proc ::buttontray::ButtonConfigure {w name args} {
    
    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals

    set wlab $locals($name,wlab)
    set idtxt $locals($name,idtxt)
    set can $widgets(canvas)
    
    foreach {key value} $args {
	
	switch -- $key {
	    -command {
		set locals($name,cmd) $value
		SetButtonBinds $w $name
	    }
	    -state {
		if {[string equal $value "normal"]} {
		    $wlab configure -image $locals($name,image)
		    $can itemconfigure $idtxt -fill $options(-foreground)
		    SetButtonBinds $w $name
		} else {
		    $wlab configure -image $locals($name,imageDis) -relief flat
		    $can itemconfigure $idtxt -fill $options(-disabledforeground)
		    $can delete activebg
		    bind $wlab <Enter> {}
		    bind $wlab <Leave> {}
		    bind $wlab <Button-1> {}
		    bind $wlab <ButtonRelease> {}
		    $can bind $idtxt <Enter> {}
		    $can bind $idtxt <Leave> {}
		    $can bind $idtxt <Button-1> {}
		}
		set locals($name,state) $value
	    }
	    -image {
		set locals($name,image) $value
		if {[string equal $locals($name,state) "normal"]} {
		    $wlab configure -image $value
		}
	    }
	    -imagedis {
		set locals($name,imageDis) $value
		if {[string equal $locals($name,state) "disabled"]} {
		    $wlab configure -image $value
		}
	    }
	}
    }
}

# buttontray::MinWidth --
#
#       Returns the width of all buttons created in the shortcut button pad.

proc ::buttontray::MinWidth {w} {
    
    upvar ::buttontray::${w}::locals locals
    
    return $locals(xleft)
}

# buttontray::DestroyHandler --
#
#       The exit handler of a buttontray.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       the internal state is cleaned up, namespace deleted.

proc ::buttontray::DestroyHandler {w} {
    
    # Remove the namespace with the widget.
    if {[string equal [winfo class $w] "ButtonTray"]} {
	namespace delete ::buttontray::${w}
    }
}
    
#-------------------------------------------------------------------------------


