#  ProgressWindow.tcl ---
#  
#       This file is part of The Coccinella application. It makes a progress 
#       window. The 'updatePerc' is a number between 0 and 100.
#       The 'cancelCmd' should contain the fully qualified command for the 
#       cancel operation.
#      
#  Copyright (c) 2000-2004  Mats Bengtsson
#  This source file is distributed under the BSD license.
#  
#  See the README file for license, bugs etc.
#  
# $Id: ProgressWindow.tcl,v 1.21 2004-12-09 15:20:27 matben Exp $
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
    variable this
    variable buttoncmd button
    variable framecmd  frame
    variable labelcmd  label
    
    if {[catch {package require progressbar}]} {
	set this(haveprogressbar) 0
    } else {
	set this(haveprogressbar) 1
    }
    if {1 || [catch {package require tile}]} {
	set this(havetile) 0
    } else {
	set this(havetile) 1
	set buttoncmd tbutton
	set framecmd  tframe
	set labelcmd  tlabel
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
    if {[string equal $this(platform) "unix"]} {
	set this(havetile) 0
    }
    
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

    # Options for this widget
    option add *ProgressWindow.background    #dedede          widgetDefault
    option add *ProgressWindow.cancelCmd     {}               widgetDefault
    option add *ProgressWindow.name          [::msgcat::mc {Progress}] widgetDefault
    option add *ProgressWindow.pauseCmd      {}               widgetDefault
    option add *ProgressWindow.percent       0                widgetDefault
    option add *ProgressWindow.text          "Writing file"   widgetDefault
    option add *ProgressWindow.text2         {}               widgetDefault
    option add *ProgressWindow.text3         {}               widgetDefault
    
    # Platform specifics...
    switch -glob -- $this(platform) {
	unix {
	    option add *ProgressWindow.font1    {Helvetica 10 bold}   widgetDefault
	    option add *ProgressWindow.font2    {Helvetica 10 normal} widgetDefault
	}
	windows {
	    option add *ProgressWindow.font1    {Arial 8 bold}        widgetDefault
	    option add *ProgressWindow.font2    {Arial 8 normal}      widgetDefault
	}
	macintosh {
	    option add *ProgressWindow.font1    system                widgetDefault
	    option add *ProgressWindow.font2    {Geneva 9 normal}     widgetDefault
	}
	macosx {
	    option add *ProgressWindow.font1    system                widgetDefault
	    option add *ProgressWindow.font2    {{Lucida Grande} 11}  widgetDefault
	}
    }
    
    variable debugLevel 0
}

# ::ProgressWindow::ProgressWindow ---
#
#       The constructor.
#       
# Arguments:
#       w       the widget path (toplevel).
#       args    (optional) list of key value pairs for the widget options.
# Results:
#       The widget path or an error.

proc ::ProgressWindow::ProgressWindow {w args} {
    global  tcl_platform
    
    variable widgetOptions
    variable widgetCommands
    variable debugLevel
    variable this
    
    if {$debugLevel > 1} {
	puts "ProgressWindow:: w=$w, args=$args"
    }
    
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
    if {[string equal $this(platform) "macintosh"]} {
	::tk::unsupported::MacWindowStyle style $w documentProc
    } elseif {[string equal $this(platform) "macosx"]} {
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
	if {$debugLevel > 1} {
	    puts "   name=$name, optName=$optName, optClass=$optClass"
	}
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
    variable debugLevel
    upvar ::ProgressWindow::${w}::options options
    
    if {$debugLevel > 2} {
	puts "::ProgressWindow::WidgetProc w=$w, command=$command, args=$args"
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
    
    variable this
    variable dims
    variable debugLevel
    variable buttoncmd
    variable framecmd
    variable labelcmd
    upvar ::ProgressWindow::${w}::options options
    upvar ::ProgressWindow::${w}::widgets widgets
    
    if {$debugLevel >= 3} {
	puts "::ProgressWindow::Build:: w=$w"
    }
    set wall $widgets(frame)
    $framecmd $wall
    pack $wall -padx 16 -pady 6

    set wmid            $wall.mid
    set wbot            $wall.bot

    set widgets(label)  $wall.la
    set widgets(label2) $wbot.la2
    set widgets(label3) $wbot.la3
    set widgets(labelp) $wbot.lpause
    set widgets(pbar)   $wmid.pb
    set widgets(canvas) $wmid.pb
    set widgets(cancel) $wmid.btcancel
    
    set wpause $widgets(labelp)
    
    $labelcmd $widgets(label) -font $options(-font1) -text $options(-text) \
      -justify left
    pack $widgets(label)  -side top -anchor w -pady 4
    
    # Frame with progress bar and Cancel button.
    frame $wmid
    pack  $wmid -side top -fill x
    if {$this(havetile)} {
	tprogress $widgets(pbar) -from 0 -to 100 -length $dims(width) \
	  -variable ::ProgressWindow::${w}::percent
	$widgets(pbar) set $options(-percent)
	pack $widgets(pbar) -side left -fill x -expand 1
    } elseif {$this(haveprogressbar)} {
	::progressbar::progressbar $widgets(pbar)  \
	  -variable ::ProgressWindow::${w}::percent \
	  -width $dims(width) -percent $options(-percent)
	pack $widgets(pbar) -side left -fill x -expand 1
    } else {
	set width  $dims(width)
	set height $dims(height)
	set wcan $widgets(canvas)
	canvas $wcan -width $width -height $height \
	  -borderwidth 0 -relief sunken -highlightthickness 0
	$wcan create rectangle 0 0 $width $height  \
	  -fill #ceceff -outline {}
	$wcan create rectangle 0 0 0 0  \
	  -outline {} -fill #424242 -tag progbar
	$wcan create rectangle 0 0 $width $height  \
	  -fill {} -outline black
	if {$options(-percent) > 0} {
	    $wcan coords progbar 0 0  \
	      [expr ($options(-percent) * $width)/100] $height
	}
	pack $wcan -side left -fill x -expand 1
    }
    $buttoncmd $widgets(cancel) -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::CancelBt $w $options(-cancelcmd)]
    pack $widgets(cancel) -side right -padx 8

    # Frame for texts etc.
    frame $wbot
    pack  $wbot -side top -fill x
    if {$options(-pausecmd) != ""} {
	$labelcmd $wpause -text [::msgcat::mc Pause] -fg blue
	array set fontArr [font actual [$widgets(labelp) cget -font]]
	set fontArr(-underline) 1
	$wpause configure -font [array get fontArr]
	pack $wpause -side right
	bind $wpause <Button-1> [list [namespace current]::Pause $w]
	bind $wpause <Enter> [list $wpause configure -fg red]
	bind $wpause <Leave> [list $wpause configure -fg blue]
    }
    
    # Small text below progress bar.
    $labelcmd $widgets(label2) -font $options(-font2) -text $options(-text2)
    pack $widgets(label2) -side top -anchor w
    $labelcmd $widgets(label3) -font $options(-font2) -text $options(-text3)
    pack $widgets(label3) -side top -anchor w
    
    ::ProgressWindow::ConfigurePercent $w $options(-percent)
    
    # Change to flat when no focus, to 3d when focus. Standard MacOS.
    bind $w <FocusOut> [list ::ProgressWindow::PBFocusOut $w]
    bind $w <FocusIn>  [list ::ProgressWindow::PBFocusIn $w]

    update idletasks
    set wrapwidth [winfo reqwidth $wmid]
    $widgets(label) configure -wraplength $wrapwidth
    
    wm deiconify $w
    raise $w
    focus $w
}

proc ::ProgressWindow::Close {w} {
    
    upvar ::ProgressWindow::${w}::widgets widgets

    $widgets(cancel) invoke
}

proc ::ProgressWindow::ConfigurePercent {w percent} {

    variable this
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
    if {$this(haveprogressbar)} {
	set ::ProgressWindow::${w}::percent [expr int($percent)]
    } else {
	$widgets(canvas) coords progbar 0 0   \
	  [expr ($percent * $dims(width))/100] $dims(height)
    }
}

# ::ProgressWindow::Configure ---
#
#       Here we just configures an existing progress window.

proc ::ProgressWindow::Configure {w args} {

    variable this
    variable widgetOptions
    variable debugLevel
    
    # Refer to these variables by local names.
    upvar ::ProgressWindow::${w}::options options
    upvar ::ProgressWindow::${w}::widgets widgets
    
    if {$debugLevel >= 3} {
	puts "::ProgressWindow::Configure:: w=$w, args=$args"
    }
    
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
		::ProgressWindow::ConfigurePercent $w $value
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
    $widgets(labelp) configure -text [::msgcat::mc Restart]
    bind $widgets(labelp) <Button-1> [list [namespace current]::Restart $w]

}

proc ::ProgressWindow::Restart {w} {

    upvar ::ProgressWindow::${w}::widgets widgets
    upvar ::ProgressWindow::${w}::options options
    
    uplevel #0 $options(-pausecmd) restart
    $widgets(labelp) configure -text [::msgcat::mc Pause]
    bind $widgets(labelp) <Button-1> [list [namespace current]::Pause $w]
    
}

proc ::ProgressWindow::Cleanup {w} {
    
    catch {namespace delete ::ProgressWindow::$w}
}

proc ::ProgressWindow::PBFocusIn {w} {
    variable this
    
    upvar ::ProgressWindow::${w}::widgets widgets

    if {$this(havetile)} {
	# empty
    } elseif {$this(haveprogressbar)} {
	$widgets(pbar) configure -shape 3d -color @blue0
    } else {
	$widgets(canvas) itemconfigure progbar -fill #424242
	$widgets(canvas) itemconfigure trect -fill black
    }
    $widgets(label) configure -foreground black
    $widgets(label2) configure -foreground black
    $widgets(label3) configure -foreground black
}

proc ::ProgressWindow::PBFocusOut {w} {
    variable this
    
    upvar ::ProgressWindow::${w}::widgets widgets

    if {$this(havetile)} {
	# empty
    } elseif {$this(haveprogressbar)} {
	$widgets(pbar) configure -shape flat -color #9C9CFF
    } else {
	$widgets(canvas) itemconfigure progbar -fill #9C9CFF
	$widgets(canvas) itemconfigure trect -fill #6B6B6B
    }
    $widgets(label) configure -foreground #6B6B6B
    $widgets(label2) configure -foreground #6B6B6B
    $widgets(label3) configure -foreground #6B6B6B
}

#-------------------------------------------------------------------------------
