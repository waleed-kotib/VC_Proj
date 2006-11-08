#  ttoolbar.tcl ---
#  
#      This file is part of The Coccinella application.
#      It implements a toolbar mega widget using tile.
#      
#  Copyright (c) 2005-2006  Mats Bengtsson
#  This source file is distributed under the BSD license.
#  
# $Id: ttoolbar.tcl,v 1.7 2006-11-08 07:44:38 matben Exp $
# 
# ########################### USAGE ############################################
#
#   NAME
#      ttoolbar - toolbar megawidget.
#      
#   SYNOPSIS
#      ttoolbar pathName ?options?
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
#      pathName newbutton name -text str -image name -disabledimage name 
#                              -command cmd args
#
# ########################### CHANGES ##########################################
#
#       1.0     Original version

package provide ttoolbar 1.0

namespace eval ::ttoolbar::  {
    
    namespace export ttoolbar
    
}

# ::ttoolbar::Init --
#
#       Contains initializations needed for the ttoolbar widget. It is
#       only necessary to invoke it for the first instance of a widget since
#       all stuff defined here are common for all widgets of this type.
#       
# Arguments:
#       none.
#       
# Results:
#       none.

proc ::ttoolbar::Init { } {
    global  tcl_platform

    variable this
    variable ttoolbarOptions
    variable widgetOptions
    
    foreach name [tile::availableThemes] {

	if {[catch {package require tile::theme::$name}]} {
	    continue
	}

	style theme settings $name {
	    
	    style layout TToolbar.TButton {
		TToolbar.border -children {
		    TToolbar.padding -children {
			TToolbar.label -side left
		    }
		}
	    }
	    style configure TToolbar.TButton   \
	      -padding 2 -relief flat -borderwidth 1
	    style map TToolbar.TButton -relief {
		disabled flat
		selected sunken
		pressed  sunken
		active   raised
	    }
	}
    }
    
    # List all allowed options with their database names and class names.
    array set widgetOptions {
	-compound            {compound             Compound            }
	-packimagepadx       {packImagePadX        PackImagePadX       }
	-packimagepady       {packImagePadY        PackImagePadY       }
	-packtextpadx        {packTextPadX         PackTextPadX        }
	-packtextpady        {packTextPadY         PackTextPadY        }
	-padding             {padding              Padding             }
	-styleimage          {styleImage           StyleImage          }
	-styletext           {styleText            StyleText           }
    }
    
    set ttoolbarOptions [array names widgetOptions]

    option add *TToolbar.compound            both             widgetDefault
    option add *TToolbar.padding            {10 4 6 4}        widgetDefault
    option add *TToolbar.packImagePadX       4                widgetDefault
    option add *TToolbar.packImagePadY       0                widgetDefault
    option add *TToolbar.packTextPadX        0                widgetDefault
    option add *TToolbar.packTextPadY        0                widgetDefault
    option add *TToolbar.styleImage          TToolbar.TButton widgetDefault
    option add *TToolbar.styleText           Toolbutton       widgetDefault

    # This allows us to clean up some things when we go away.
    bind TToolbar <Destroy> {+::ttoolbar::DestroyHandler %W }
    
    set this(inited) 1
}

# ttoolbar::ttoolbar --
#
#       Constructor for the ttoolbar mega widget.
#   
# Arguments:
#       w      the widget.
#       args   list of '-name value' options.
#       
# Results:
#       The widget.

proc ::ttoolbar::ttoolbar {w args} {
    
    variable this
    variable ttoolbarOptions
    variable widgetOptions
    
    # Perform a one time initialization.
    if {![info exists this(inited)]} {
	Init
    }

    # Instance specific namespace
    namespace eval ::ttoolbar::${w} {
	variable options
	variable widgets
	variable locals
    }
    
    # Set simpler variable names.
    upvar ::ttoolbar::${w}::options options
    upvar ::ttoolbar::${w}::widgets widgets
    upvar ::ttoolbar::${w}::locals locals

    # We use a frame for this specific widget class.
    set widgets(this)  [ttk::frame $w -class TToolbar]
    set widgets(frame) ::ttoolbar::${w}::${w}

    # Padding to make all flush left.
    ttk::frame $w.pad
    grid  $w.pad  -column 99 -row 0 -sticky ew
    grid columnconfigure $w 99 -weight 1

    # Parse options for the widget. First get widget defaults.
    foreach name $ttoolbarOptions {
	set optName  [lindex $widgetOptions($name) 0]
	set optClass [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
    }
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    if {[llength $args]} {
	eval {Configure $w} $args
	#array set options $args
    }
    set locals(uid) 0
        
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $widgets(frame)
    
    # Create the actual widget procedure.
    proc ::${w} {command args}   \
      "eval ::ttoolbar::WidgetProc {$w} \$command \$args"
 
    return $w
}

# ::ttoolbar::WidgetProc --
#
#       This implements the methods, cget, configure etc.
#       
# Arguments:
#       w       the widget path.
#       command the actual command; cget, configure etc.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::ttoolbar::WidgetProc {w command args} {
    
    variable widgetCommands
    upvar ::ttoolbar::${w}::options options
    upvar ::ttoolbar::${w}::locals locals
    
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
	    set result [info exists locals($name,-state)]
	}
	minwidth {
	    set result [MinWidth $w]
	}
	newbutton {
	    set result [eval {NewButton $w} $args]
	}
	default {
	    return -code error "unknown command \"$command\" of the ttoolbar widget.\
	      Must be one of $widgetCommands"
	}
    }
    return $result
}

# ::ttoolbar::Configure --
#
#       Implements the "configure" widget command (method). 
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::ttoolbar::Configure {w args} {

    variable widgetOptions
    upvar ::ttoolbar::${w}::options options
    upvar ::ttoolbar::${w}::widgets widgets
    upvar ::ttoolbar::${w}::locals locals
    
    # Error checking.
    foreach {name value} $args  {
	if {![info exists widgetOptions($name)]}  {
	    return -code error "unknown option for the ttoolbar: $name"
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
    array set saveOpts [array get options]
    array set options $args
	
    # Process the new configuration options.
    set ncol [llength [array names locals *,-text]]
    if {$ncol && ($saveOpts(-compound) ne $options(-compound))} {
	set wtexts [lsearch -glob -inline -all [winfo children $w] $w.t*]
	set wimages [lsearch -glob -inline -all [winfo children $w] $w.i*]

	switch -- $options(-compound) {
	    both {
		set mapimage 1
		set maptext  1
	    }
	    image {
		set mapimage 1
		set maptext  0
	    }
	    text {
		set mapimage 0
		set maptext  1
	    }
	}
	if {$maptext} {
	    set ncol 0
	    foreach wtext $wtexts {
		grid  $wtext  -column $ncol -row 1 \
		  -padx $options(-packtextpadx) -pady $options(-packtextpady)
		incr ncol
	    }
	} else {
	    eval {grid forget} $wtexts	    
	}
	if {$mapimage} {
	    set ncol 0
	    foreach wimage $wimages {
		grid  $wimage  -column $ncol -row 0 \
		  -padx $options(-packimagepadx) -pady $options(-packimagepady)
		incr ncol
	    }
	} else {
	    eval {grid forget} $wimages
	}
    }
}

proc ::ttoolbar::NewButton {w name args} {
    
    upvar ::ttoolbar::${w}::options options
    upvar ::ttoolbar::${w}::widgets widgets
    upvar ::ttoolbar::${w}::locals locals
        
    set ncol [llength [array names locals *,-text]]

    set locals($name,-text)           $name
    set locals($name,-command)        ""
    set locals($name,-state)          normal
    set locals($name,-image)          ""
    set locals($name,-disabledimage)  ""

    set uid $locals(uid)
    set wimage $w.i$uid
    set wtext  $w.t$uid
    set locals($name,uid)    $locals(uid)
    set widgets($name,image) $wimage
    set widgets($name,text)  $wtext
    
    set cmd [list [namespace current]::Invoke $w $name]
    ttk::button $wimage -style $options(-styleimage) -command $cmd  \
      -compound image
    ttk::button $wtext  -style $options(-styletext)  -command $cmd  \
      -compound text
       
    switch -- $options(-compound) {
	both {
	    set mapimage 1
	    set maptext  1
	}
	image {
	    set mapimage 1
	    set maptext  0
	}
	text {
	    set mapimage 0
	    set maptext  1
	}
    }
    if {$mapimage} {
	grid  $wimage  -column $ncol -row 0 \
	  -padx $options(-packimagepadx) -pady $options(-packimagepady)
    } 
    if {$maptext} {
	grid  $wtext  -column $ncol -row 1 \
	  -padx $options(-packtextpadx) -pady $options(-packtextpady)
    }
    eval {ButtonConfigure $w $name} $args
    
    incr locals(uid)
}

proc ::ttoolbar::Invoke {w name} {

    upvar ::ttoolbar::${w}::locals locals

    uplevel #0 $locals($name,-command)
}

proc ::ttoolbar::ButtonConfigure {w name args} {
    
    upvar ::ttoolbar::${w}::widgets widgets
    upvar ::ttoolbar::${w}::locals locals
    
    if {![info exists locals($name,-state)]} {
	return -code error "button \"$name\" does not exist in $w"
    }
    
    foreach {key value} $args {
	set flags($key) 1
	
	switch -- $key {
	    -command - -disabledimage - -image - -state {
		set locals($name,$key) $value
	    }
	    -text {
		set locals($name,-text) $value
		$widgets($name,text) configure -text $value
	    }
	}
    }
    if {[info exists flags(-image)] || [info exists flags(-disabledimage)]} {
	set imName    $locals($name,-image)
	set imNameDis $locals($name,-disabledimage)
	if {$imName != ""} {
	    set imSpec $imName
	    if {$imNameDis != ""} {
		lappend imSpec disabled $imNameDis background $imNameDis
	    }
	    $widgets($name,image) configure -image $imSpec
	}
    }
    if {[info exists flags(-state)]} {	
	if {[string equal $locals($name,-state) "normal"]} {
	    $widgets($name,image) state {!disabled}
	    $widgets($name,text)  state {!disabled}
	} else {
	    $widgets($name,image) state {disabled}
	    $widgets($name,text)  state {disabled}
	}
    }
}

# ttoolbar::MinWidth --
#
#       Returns the width of all buttons created in the shortcut button pad.

proc ::ttoolbar::MinWidth {w} {
    
    upvar ::ttoolbar::${w}::options options
    upvar ::ttoolbar::${w}::widgets widgets
    
    switch -- [llength $options(-padding)] {
	1 {
	    set width [expr 2*$options(-padding)]
	}
	2 {
	    set width [expr 2*[lindex $options(-padding) 0]]
	}
	4 {
	    set width [expr [lindex $options(-padding) 0] + \
	      [lindex $options(-padding) 2]]
	}
    }

    foreach {key wtext} [array get widgets *,text] {
	array set gridInfo [grid info $wtext]
	incr width [expr 2*$gridInfo(-padx)]
	incr width [winfo reqwidth $wtext]
    }
    return $width
}

# ttoolbar::DestroyHandler --
#
#       The exit handler of a ttoolbar.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       the internal state is cleaned up, namespace deleted.

proc ::ttoolbar::DestroyHandler {w} {
    
    # Remove the namespace with the widget.
    if {[string equal [winfo class $w] "TToolbar"]} {
	namespace delete ::ttoolbar::${w}
    }
}
    
#-------------------------------------------------------------------------------


