#  buttontray.tcl ---
#  
#      This file is part of The Coccinella application.
#      It implements a fancy button tray widget.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#  This source file is distributed under the BSD license.
#  
# $Id: buttontray.tcl,v 1.21 2005-03-11 06:55:55 matben Exp $
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
#	-padx, padX, PadX
#	-pady, padY, PadY
#	-relief, relief, Relief
#	-takefocus, takeFocus, TakeFocus
#	
#   WIDGET COMMANDS
#      pathName buttonconfigure name
#      pathName cget option
#      pathName configure ?option? ?value option value ...?
#      pathName exists name
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
    variable labelOptions
    
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
    
    # Guard against tile redefining widgets.
    foreach widget {canvas frame label} {
	interp alias {} [namespace current]::${widget} {} ::${widget}
    }
    
    # List all allowed options with their database names and class names.
    array set widgetOptions {
	-activebackground    {activeBackground     ActiveBackground    }  \
	-activeforeground    {activeForeground     ActiveForeground    }  \
	-background          {background           Background          }  \
	-borderwidth         {borderWidth          BorderWidth         }  \
	-compound            {compound             Compound            }  \
	-disabledforeground  {disabledForeground   DisabledForeground  }  \
	-font                {font                 Font                }  \
	-foreground          {foreground           Foreground          }  \
	-height              {height               Height              }  \
	-image               {image                Image               }  \
	-labelbackground     {labelBackground      Background          }  \
	-labelpadx           {labelPadX            LabelPadX           }  \
	-labelpady           {labelPadY            LabelPadY           }  \
	-packpadx            {packPadX             PackPadX            }  \
	-packpady            {packPadY             PackPadY            }  \
	-padx                {padX                 PadX                }  \
	-pady                {padY                 PadY                }  \
	-relief              {relief               Relief              }  \
	-style               {style                Style               }  \
    }
    set frameOptions {-background -borderwidth -padx -pady -relief}
    set labelOptions {-compound -disabledforeground -font -foreground \
      -labelbackground -labelpadx -labelpady}
    # Add -image later...
    set trayOptions [array names widgetOptions]
  
    # The legal widget commands.
    set widgetCommands {buttonconfigure cget configure minwidth newbutton}
        
    option add *ButtonTray.activeBackground   gray40            widgetDefault
    option add *ButtonTray.activeForeground   white             widgetDefault
    option add *ButtonTray.background         white             widgetDefault
    option add *ButtonTray.borderWidth        0                 widgetDefault
    option add *ButtonTray.compound           none              widgetDefault
    option add *ButtonTray.disabledForeground gray50            widgetDefault
    option add *ButtonTray.foreground         black             widgetDefault
    option add *ButtonTray.height             0                 widgetDefault
    option add *ButtonTray.image              ""                widgetDefault
    option add *ButtonTray.labelBackground    white             widgetDefault
    option add *ButtonTray.labelPadX          2                 widgetDefault
    option add *ButtonTray.labelPadY          2                 widgetDefault
    option add *ButtonTray.packPadX           2                 widgetDefault
    option add *ButtonTray.packPadY           2                 widgetDefault
    option add *ButtonTray.padX               6                 widgetDefault
    option add *ButtonTray.padY               4                 widgetDefault
    option add *ButtonTray.relief             flat              widgetDefault
    option add *ButtonTray.style              fancy             widgetDefault
    
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
#       args   list of '-name value' options.
#       
# Results:
#       The widget.

proc ::buttontray::buttontray {w args} {
    
    variable widgetOptions
    variable frameOptions
    variable trayOptions
    
    # Perform a one time initialization.
    if {![info exists widgetOptions]} {
	Init
    }
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]} {
	    return -code error "unknown option \"$name\" for the buttontray widget"
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
    set widgets(this)   [frame $w -class ButtonTray]
    set widgets(frame) ::buttontray::${w}::${w}

    # Parse options for the widget. First get widget defaults.
    # foreach name [concat $trayOptions $frameOptions]
    foreach name $trayOptions {
	set optName  [lindex $widgetOptions($name) 0]
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
    if {[string equal $options(-style) "fancy"]} {
	set widgets(canvas) [canvas $w.c -highlightthickness 0]
	pack $widgets(canvas) -fill both -expand 1
	$widgets(canvas) configure -bg $options(-background)
    }
    SetGeometries $w
        
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
    
    set result {}
    
    # Which command?
    switch -- $command {
	buttonconfigure {
	    set result [eval {ButtonConfigure $w} $args]
	}
	cget {
	    if {[llength $args] != 1} {
		return -code error "wrong # args: should be $w cget option"
	    }
	    set result $options($args)
	}
	configure {
	    set result [eval {Configure $w} $args]
	}
	exists {
	    set name [lindex $args 0]
	    set result [info exists locals($name,wlab)]
	}
	minwidth {
	    set result [MinWidth $w]
	}
	newbutton {
	    set result [eval {NewButton $w} $args]
	}
	default {
	    return -code error "unknown command \"$command\" of the buttontray widget.\
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
	    return -code error "unknown option for the moviecontroller: $name"
	}
    }
    if {[llength $args] == 0}  {
	
	# Return all options.
	foreach opt [lsort [array names widgetOptions]] {
	    set optName  [lindex $widgetOptions($opt) 0]
	    set optClass [lindex $widgetOptions($opt) 1]
	    set def      [option get $w $optName $optClass]
	    lappend results [list $opt $optName $optClass $def $options($opt)]
	}
	return $results
    } elseif {[llength $args] == 1}  {
	
	# Return configuration value for this option.
	set opt $args
	set optName  [lindex $widgetOptions($opt) 0]
	set optClass [lindex $widgetOptions($opt) 1]
	set def      [option get $w $optName $optClass]
	return [list $opt $optName $optClass $def $options($opt)]
    }
    
    # Error checking.
    if {[expr {[llength $args]%2}] == 1}  {
	return -code error "value for \"[lindex $args end]\" missing"
    }    
	
    # Process the new configuration options.
    
}

proc ::buttontray::SetGeometries {w} {
    
    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals

    switch -- $options(-style) {
	fancy {
	    if {$options(-height) > 0} {
		set height [expr $options(-height) - 2 * $options(-pady) \
		  - 2 * $options(-borderwidth)]
	    } else {
		# Assume icons 32x32.
		set height [expr {32 + 2}]
		
		# Consider the actual font metrics to make the necessary height.
		set linespace [font metrics $options(-font) -linespace]
		incr height $linespace
		incr height 2
	    }
	    $widgets(canvas) configure -height $height
	    set locals(ytxt) 35
	    
	    # Standard minimum button width.
	    set locals(minbtwidth) 46
	    
	    # Left edge of previous button.
	    set locals(xleft) 2
	}
	plain {
	    set locals(minwidth) 0
	}
    }
}

proc ::buttontray::NewButton {w args} {
    
    upvar ::buttontray::${w}::options options

    switch -- $options(-style) {
	fancy {
	    eval {NewFancyButton $w} $args
	}
	plain {
	    eval {NewButtonPlain $w} $args
	}
    }
}

proc ::buttontray::NewFancyButton {w name args} {

    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals
    
    set locals($name,-text)    $name
    set locals($name,-command) ""
    set locals($name,-state)   normal
    set locals($name,-image)   ""
    set locals($name,-disabledimage) ""
    foreach {key value} $args {
	set locals($name,$key) $value
    }

    set font  $options(-font)
    set fg    $options(-foreground)
    set can   $widgets(canvas)
    set str   $locals($name,-text)
    set image $locals($name,-image)
    set txtwidth [expr [font measure $font $str] + 6]
    set btwidth [expr $txtwidth > $locals(minbtwidth) ? $txtwidth : $locals(minbtwidth)]

    # Round to nearest higher even value.    
    set btwidth [expr $btwidth + $btwidth % 2]

    # Mid position of this button.
    set xpos [expr $locals(xleft) + $btwidth/2]
    set wlab [label $can.$name -bd 1 -relief flat -image $image]
    set idlab [$can create window $xpos 0 -anchor n -window $wlab]
    set idtxt [$can create text $xpos $locals(ytxt) -text $str  \
      -font $font -anchor n -fill $fg]

    set locals($name,idlab)    $idlab
    set locals($name,idtxt)    $idtxt
    set locals($name,wlab)     $wlab
    
    SetFancyButtonBinds $w $name
    if {[llength $args]} {
	eval {FancyButtonConfigure $w $name} $args
    }
    incr locals(xleft) $btwidth
}

proc ::buttontray::SetFancyButtonBinds {w name} {

    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals
    
    set can   $widgets(canvas)
    set wlab  $locals($name,wlab)
    set idtxt $locals($name,idtxt)
    set cmd   $locals($name,-command)

    bind $wlab <Enter>    [list ::buttontray::EnterFancy $w $name label]
    bind $wlab <Leave>    [list ::buttontray::LeaveFancy $w $name label]
    bind $wlab <Button-1> [list $wlab configure -relief sunken]
    bind $wlab <ButtonRelease> "[list $wlab configure -relief raised];\
      $can configure -cursor arrow; $cmd"

    $can bind $idtxt <Enter> [list ::buttontray::EnterFancy $w $name text]
    $can bind $idtxt <Leave> [list ::buttontray::LeaveFancy $w $name text]
    $can bind $idtxt <Button-1> $cmd   
}

proc ::buttontray::EnterFancy {w name which} {

    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals

    set can   $widgets(canvas)
    set wlab  $locals($name,wlab)
    set idtxt $locals($name,idtxt)
    set abg   $options(-activebackground)
    set afg   $options(-activeforeground)
    
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
    $can itemconfigure $idtxt -fill $afg
    $can create polygon $coords -fill $abg -tags activebg -outline "" \
      -smooth 1 -splinesteps 10
    $can lower activebg $idtxt
}

proc ::buttontray::LeaveFancy {w name which} {

    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals

    set can $widgets(canvas)
    set wlab $locals($name,wlab)
    set idtxt $locals($name,idtxt)
    set fg $options(-foreground)

    if {[string equal $which "label"]} {
	$wlab configure -relief flat
    }
    $can itemconfigure $idtxt -fill $fg
    catch {$can delete activebg}
    $can configure -cursor arrow
}

proc ::buttontray::ButtonConfigure {w name args} {
    
    upvar ::buttontray::${w}::options options

    switch -- $options(-style) {
	fancy {
	    eval {FancyButtonConfigure $w $name} $args
	}
	plain {
	    eval {PlainButtonConfigure $w $name} $args
	}
    }
}

proc ::buttontray::FancyButtonConfigure {w name args} {
    
    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals
    
    if {![info exists locals($name,wlab)]} {
	return -code error "button \"$name\" does not exist in $w"
    }
    set wlab  $locals($name,wlab)
    set idtxt $locals($name,idtxt)
    set can   $widgets(canvas)
    
    foreach {key value} $args {
	
	switch -- $key {
	    -command {
		set locals($name,-command) $value
		SetFancyButtonBinds $w $name
	    }
	    -state {
		if {[string equal $value "normal"]} {
		    $wlab configure -image $locals($name,-image)
		    $can itemconfigure $idtxt -fill $options(-foreground)
		    SetFancyButtonBinds $w $name
		} else {
		    $wlab configure -image $locals($name,-disabledimage) -relief flat
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
		set locals($name,-state) $value
	    }
	    -text {
		set locals($name,-text) $value
		$can itemconfigure $idtxt -text $value
	    }
	    -image {
		set locals($name,-image) $value
		if {[string equal $locals($name,-state) "normal"]} {
		    $wlab configure -image $value
		}
	    }
	    -disabledimage {
		set locals($name,-disabledimage) $value
		if {[string equal $locals($name,-state) "disabled"]} {
		    $wlab configure -image $value
		}
	    }
	}
    }
}

proc ::buttontray::NewButtonPlain {w name args} {
    
    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::widgets widgets
    upvar ::buttontray::${w}::locals locals
        
    set locals($name,-text)    ""
    set locals($name,-image)   ""
    set locals($name,-command) ""
    set locals($name,-state)   normal
    foreach {key value} $args {
	set locals($name,$key) $value
    }
    set wlab [label $w.$name -text $locals($name,-text) -bd 1 -relief flat]
    set locals($name,wlab) $wlab
    
    # Two optional frames for custom packing and padding. Only db.
    set frame1 [option get $wlab frame1 {}]
    set frame2 [option get $wlab frame2 {}]
    if {$frame1 == "1"} {
	set wfr1 $w.${name}frame1
	frame $wfr1
	pack $wfr1 -side left -fill y
	if {$frame2 == "1"} {
	    set wfr2 $w.${name}frame2
	    frame $wfr2
	    pack $wfr2 -side left -fill y -in $wfr1
	    pack $wlab -side left -in $wfr2
	} else {
	    pack $wlab -side left -in $wfr1
	}
	raise $wlab
    } else {
	pack $wlab -side left -padx $options(-packpadx) -pady $options(-packpady)
    }
    SetPlainButtonBinds $w $name    
    eval {PlainButtonConfigure $w $name} $args
}

proc ::buttontray::SetPlainButtonBinds {w name} {
    
    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::locals locals
    
    set wlab  $locals($name,wlab)
    set cmd   $locals($name,-command)
    
    $wlab configure -state normal

    bind $wlab <Enter> [list ::buttontray::EnterPlain $w $name]
    bind $wlab <Leave> [list ::buttontray::LeavePlain $w $name]
    bind $wlab <Button-1> [list $wlab configure -relief sunken]
    bind $wlab <ButtonRelease> "[list $wlab configure -relief flat];\
      $wlab configure -cursor arrow; $cmd"
}

proc ::buttontray::PlainButtonConfigure {w name args} {
    
    variable labelOptions
    upvar ::buttontray::${w}::options options
    upvar ::buttontray::${w}::locals locals
    
    if {![info exists locals($name,wlab)]} {
	return -code error "button \"$name\" does not exist in $w"
    }
    set wlab  $locals($name,wlab)
    array set argsArr $args
    
    # Priorities:
    #   1 'newbutton' arguments 
    #   2 buttonLabel options from database
    #   3 buttontray options

    foreach optName $labelOptions {
	set realName [string map {label ""} $optName]
	set opts($realName) $options($optName)
	set dbName "button[string totitle [string trimleft $realName -] 0 0]"
	set value [option get $wlab $dbName {}]
	if {[info exists argsArr($realName)]} {
	    set opts($realName) $argsArr($realName)
	} elseif {$value != ""} {
	    set opts($realName) $value
	}
	#puts "name=$name, optName=$optName, realName=$realName, options()=$options($optName)"
    }
    eval {$wlab configure} [array get opts]
    
    foreach {key value} $args {
	
	switch -- $key {
	    -command {
		set locals($name,-command) $value
		SetPlainButtonBinds $w $name
	    }
	    -state {
		if {[string equal $value "normal"]} {
		    SetPlainButtonBinds $w $name
		} else {
		    $wlab configure -relief flat -state $value
		    bind $wlab <Enter> {}
		    bind $wlab <Leave> {}
		    bind $wlab <Button-1> {}
		    bind $wlab <ButtonRelease> {}
		}
		set locals($name,-state) $value
	    }
	    -text {
		set locals($name,-text) $value
		# ???
	    }
	    -image {
		set locals($name,-image) $value
		if {[string equal $locals($name,-state) "normal"]} {
		    #$wlab configure -image $value
		}
	    }
	    -disabledimage {
		set locals($name,-disabledimage) $value
		if {[string equal $locals($name,-state) "disabled"]} {
		    #$wlab configure -image $value
		}
	    }
	}
    }
}

proc ::buttontray::EnterPlain {w name} {
    
    upvar ::buttontray::${w}::locals locals
    
    set wlab  $locals($name,wlab)
    $wlab configure -relief raised
}

proc ::buttontray::LeavePlain {w name} {
    
    upvar ::buttontray::${w}::locals locals
    
    set wlab  $locals($name,wlab)
    $wlab configure -relief flat
}

proc ::buttontray::OptsEqual {optName val1 val2} {
    
    if {[regexp {.*(background|color|foreground).*} $optName]} {
	if {[string equal [winfo rgb . $val1] [winfo rgb . $val2]]} {
	    return 1
	} else {
	    return 0
	}
    } else {
	return [string equal $val1 $val2]
    }
}

# buttontray::MinWidth --
#
#       Returns the width of all buttons created in the shortcut button pad.

proc ::buttontray::MinWidth {w} {
    
    upvar ::buttontray::${w}::locals locals
    upvar ::buttontray::${w}::options options
    
    switch -- $options(-style) {
	fancy {
	    set width $locals(xleft)
	    incr width [$w cget -padx]
	    incr width 2
	}
	plain {
	    set width [expr 2 * $options(-padx)]
	    foreach {key wlab} [array get locals *,wlab] {
		array set packInfo [pack info $wlab]
		incr width [expr 2 * $packInfo(-padx)]
		incr width [winfo reqwidth $wlab]
		if {[winfo exists ${wlab}frame1]} {
		    incr width [expr 2 * [${wlab}frame1 cget -padx]]
		}
		if {[winfo exists ${wlab}frame2]} {
		    incr width [expr 2 * [${wlab}frame2 cget -padx]]
		}
	    }
	}
    }
    return $width
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


