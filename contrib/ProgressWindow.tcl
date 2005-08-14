#  ProgressWindow.tcl ---
#  
#       This file is part of The Coccinella application. It makes a progress 
#       window. The 'updatePerc' is a number between 0 and 100.
#       The 'cancelCmd' should contain the fully qualified command for the 
#       cancel operation.
#       It requires the tile extension, probably 0.6.2 or later.
#      
#  Copyright (c) 2000-2005  Mats Bengtsson
#  This source file is distributed under the BSD license.
#  
# $Id: ProgressWindow.tcl,v 1.26 2005-08-14 06:56:45 matben Exp $
# 
#-------------------------------------------------------------------------------
#
#   It is written in an object oriented style. 
#   
#   NAME
#      ProgressWindow - Creates a progress window.
#      
#   SYNOPSIS
#      ProgressWindow toplevelWindow ?options?
#      
#   SPECIFIC OPTIONS
#      -cancelcmd, cancelCmd, CancelCmd
#      -font1, font1, Font1
#      -font2, font2, Font2
#      -name, name, Name
#      -pausecmd, pauseCmd, PauseCmd
#      -percent, percent, Percent
#      -text, text, Text
#      -text2, text2, Text2
#      -text3, text3, Text3
#      
#    WIDGET COMMAND
#       pathName cget option
#       pathName configure ?option? ?value option value ...?
#       
#-------------------------------------------------------------------------------

package require msgcat

package provide ProgressWindow 1.0


namespace eval ::ProgressWindow:: {
    global  tcl_platform
    
    # Main routine gets exported.
    namespace export ProgressWindow    
    variable widgetOptions
    variable widgetCommands
            
    # List all allowed options with their database names and class names.
    
    array set widgetOptions {
	-background          {background           Background          }  \
	-cancelcmd           {cancelCmd            CancelCmd           }  \
	-font1               {font1                Font1               }  \
        -font2               {font2                Font2               }  \
        -name                {name                 Name                }  \
	-pausecmd            {pauseCmd             PauseCmd            }  \
        -percent             {percent              Percent             }  \
        -text                {text                 Text                }  \
	-text2               {text2                Text2               }  \
	-text3               {text3                Text3               }  \
      }
    set widgetCommands {cget configure}
    
    # Dimensions.
    variable dims
    array set dims {
	width  200 
	height  16 
    }
    
    style default ProgressWindow.TButton -font TkHeadingFont

    # Options for this widget
    set name [::msgcat::mc {Progress}]
    option add *ProgressWindow.background    #dedede          widgetDefault
    option add *ProgressWindow.cancelCmd     {}               widgetDefault
    option add *ProgressWindow.name          $name            widgetDefault
    option add *ProgressWindow.pauseCmd      {}               widgetDefault
    option add *ProgressWindow.percent       0                widgetDefault
    option add *ProgressWindow.text          "Writing file"   widgetDefault
    option add *ProgressWindow.text2         ""               widgetDefault
    option add *ProgressWindow.text3         ""               widgetDefault
    option add *ProgressWindow.font1         TkDefaultFont    widgetDefault
    option add *ProgressWindow.font2         TkHeadingFont    widgetDefault
}

# ::ProgressWindow::ProgressWindow ---
#
#       The constructor.
#       
# Arguments:
#       w       the widget path (toplevel).
#       args    (optional) list of key value pairs for the widget options.
#       
# Results:
#       The widget path or an error.

proc ::ProgressWindow::ProgressWindow {w args} {
    global  tcl_platform
    
    variable widgetOptions
    variable widgetCommands
    
    # Some error checking. Odd number, bail.
    if {[expr {[llength $args]%2}] == 1} {
	error "Options are not consistent"
    }
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]} {
	    error "unknown option \"$name\" for the ProgressWindow widget"
	}
    }
    
    # Namespace for this specific instance.
    namespace eval ::ProgressWindow::$w {
	variable options
	variable widgets
    }
    
    # Refer to these variables by local names.
    upvar ::ProgressWindow::${w}::options options
    upvar ::ProgressWindow::${w}::widgets widgets
    
    toplevel $w -class ProgressWindow
    wm withdraw $w
    if {[tk windowingsystem] == "aqua"} {
	::tk::unsupported::MacWindowStyle style $w document \
	  {collapseBox verticalZoom}
    }
    wm resizable $w 0 0
    wm protocol $w WM_DELETE_WINDOW [list [namespace current]::Close $w]
    
    # We use a frame for this specific widget class.
    set widgets(this) $w
    set widgets(frame) $w.fr
    set widgets(toplevel) ::ProgressWindow::${w}::${w}
    
    # Parse options. First get widget defaults.
    foreach name [array names widgetOptions] {
	set optName        [lindex $widgetOptions($name) 0]
	set optClass       [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
    }
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    if {[llength $args] > 0} {
	array set options $args
    }
    
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $widgets(toplevel)
    
    # Create the actual widget procedure.
    proc ::${w} {command args}   \
      "eval ::ProgressWindow::WidgetProc {$w} \$command \$args"
    
    # Ready to actually make it.
    wm title $w $options(-name)
    Build $w
    
    # Cleanup things when finished.
    bind $w <Destroy> [list ::ProgressWindow::Cleanup $w]
    return $w
}
    
# ::ProgressWindow::WidgetProc --
#
#       This implements the methods, cget, configure etc.
#       
# Arguments:
#       w       the widget path (toplevel).
#       command the actual command; cget, configure etc.
#       args    list of key value pairs for the widget options.
#       
# Results:
#

proc ::ProgressWindow::WidgetProc {w command args} {
    
    variable widgetCommands
    upvar ::ProgressWindow::${w}::options options
    
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
	default {
	    error "unknown command \"$command\" of the ProgressWindow widget.\
	      Must be one of $widgetCommands"
	}
    }
    return $result
}

# ::ProgressWindow::Build ---
#
#       The progress window is created.
#       
# Arguments:
#       w       the widget path (toplevel).

proc ::ProgressWindow::Build {w} {
    global  tcl_platform
    
    variable dims
    upvar ::ProgressWindow::${w}::options options
    upvar ::ProgressWindow::${w}::widgets widgets
    
    set wall $widgets(frame)
    ttk::frame $wall -padding {16 6}
    pack $wall
    
    set wmid            $wall.mid
    set wlabel          $wall.la
    set wlabel2         $wall.la2
    set wlabel3         $wall.la3
    set wpause          $wall.pause
    set wprog           $wmid.prog
    set wcancel         $wmid.cancel

    set widgets(label)  $wlabel
    set widgets(label2) $wlabel2
    set widgets(label3) $wlabel3
    set widgets(pause)  $wpause
    set widgets(cancel) $wcancel
    
    ttk::label $wlabel \
      -font $options(-font1) -text $options(-text) -justify left
    pack $wlabel -side top -anchor w -pady 4
    
    # Frame with progress bar and Cancel button.
    ttk::frame $wmid
    pack $wmid -side top -fill x

    ttk::progressbar $wprog \
      -orient horizontal -maximum 100 -length $dims(width) \
      -variable ::ProgressWindow::${w}::percent
    pack $wprog -side left -fill x -expand 1
    
    set cancelCmd [list [namespace current]::CancelBt $w $options(-cancelcmd)]
    ttk::button $wcancel \
      -style ProgressWindow.TButton \
      -text [::msgcat::mc Cancel] -command $cancelCmd
    pack $wcancel -side right -padx 8

    if {$options(-pausecmd) != {}} {
	ttk::label $wpause -text [::msgcat::mc Pause] -fg blue
	array set fontArr [font actual [$widgets(pause) cget -font]]
	set fontArr(-underline) 1
	$wpause configure -font [array get fontArr]
	pack $wpause -side right
	bind $wpause <Button-1> [list [namespace current]::Pause $w]
	bind $wpause <Enter> [list $wpause configure -fg red]
	bind $wpause <Leave> [list $wpause configure -fg blue]
    }
    
    # Small text below progress bar.
    ttk::label $wlabel2 -font $options(-font2) -text $options(-text2)
    ttk::label $wlabel3 -font $options(-font2) -text $options(-text3)
    pack $wlabel2 -side top -anchor w
    pack $wlabel3 -side top -anchor w
    
    ConfigurePercent $w $options(-percent)
    
    update idletasks
    set wrapwidth [winfo reqwidth $wmid]
    $wlabel configure -wraplength $wrapwidth
    
    wm deiconify $w
    raise $w
    focus $w
}

proc ::ProgressWindow::Close {w} {
    
    upvar ::ProgressWindow::${w}::widgets widgets

    $widgets(cancel) invoke
}

proc ::ProgressWindow::ConfigurePercent {w percent} {

    variable dims
    upvar ::ProgressWindow::${w}::options options
    upvar ::ProgressWindow::${w}::widgets widgets
    
    if {[string length $options(-text2)] == 0} {
	if {$percent >= 100} {
	    set str2 "[::msgcat::mc {Document}]: "
	    append str2 [::msgcat::mc {Done}]
	} else {
	    set str2 "[::msgcat::mc {Remaining}]: "
	    append str2 "[expr 100 - int($percent + 0.5)]%"
	}
	$widgets(label2) configure -text $str2
    }

    # Update progress bar.
    set ::ProgressWindow::${w}::percent [expr int($percent)]
}

# ::ProgressWindow::Configure ---
#
#       Here we just configures an existing progress window.

proc ::ProgressWindow::Configure {w args} {

    variable widgetOptions
    
    # Refer to these variables by local names.
    upvar ::ProgressWindow::${w}::options options
    upvar ::ProgressWindow::${w}::widgets widgets
    
    # Error checking.
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]} {
	    error "unknown option for the ProgressWindow widget: $name"
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
    
    # 'args' contain the new options while 'options' contain the present options.
    # Only if an option has changed it should be dealt with.
    foreach {name value} $args {
	set opts($name) $value
    }
    if {[string equal [focus] $w]} {
	set col black
    } else {
	set col #6B6B6B
    }

    # Process all configuration options.
    foreach {optName value} [array get opts] {
	if {[string equal $opts($optName) $options($optName)]} {
	    continue
	}
	
	switch -- $optName {
	    -percent       {
		ConfigurePercent $w $value
	    }
	    -name        {
		wm title $w $value
	    }
	    -cancelcmd   {
		$widgets(cancel) configure  \
		  -command [list ::ProgressWindow::CancelBt $w $value]
	    }
	    -text        {
		$widgets(label) configure -text $value
	    }
	    -text2       {
		$widgets(label2) configure -text $value
	    }
	    -text3       {
		$widgets(label3) configure -text $value
	    }
	    default      {
		return -code error "unrecognized option \"$optName\""
	    }
	}
    }
    
    # Save newly set options.
    array set options $args
}

# ::ProgressWindow::CancelBt ---
#
#       When pressing the cancel button, evaluate any -cancelcmd in the
#       correct namespace, and destroy the window.

proc ::ProgressWindow::CancelBt {w cancelCmd} {
        
    # We need to have a fully qualified command name here.
    # This command is always called from the global namespace.
    if {[llength $cancelCmd] > 0} {
	if {![string match "::*" $cancelCmd]} {
	    set nsup1 [uplevel 1 namespace current]
	    set cancelCmd ::$cancelCmd
	}
	eval $cancelCmd
    }
    catch {destroy $w}
}

proc ::ProgressWindow::Pause {w} {

    upvar ::ProgressWindow::${w}::widgets widgets
    upvar ::ProgressWindow::${w}::options options
    
    uplevel #0 $options(-pausecmd) pause

    set wpause $widgets(pause)
    $wpause configure -text [::msgcat::mc Restart]
    bind $wpause <Button-1> [list [namespace current]::Restart $w]

}

proc ::ProgressWindow::Restart {w} {

    upvar ::ProgressWindow::${w}::widgets widgets
    upvar ::ProgressWindow::${w}::options options
    
    uplevel #0 $options(-pausecmd) restart

    set wpause $widgets(pause)
    $wpause configure -text [::msgcat::mc Pause]
    bind $wpause <Button-1> [list [namespace current]::Pause $w]
    
}

proc ::ProgressWindow::Cleanup {w} {
    
    catch {namespace delete ::ProgressWindow::$w}
}

#-------------------------------------------------------------------------------
