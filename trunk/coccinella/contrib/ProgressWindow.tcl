#  ProgressWindow.tcl ---
#  
#       This file is part of the whiteboard application. It makes a progress 
#       window. The 'updatePerc' is a number between 0 and 100.
#       The 'cancelCmd' should contain the fully qualified command for the 
#       cancel operation.
#       If we have the add on "Progressbar", 'prefs(Progressbar)' is true (1).
#      
#  Copyright (c) 2000-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: ProgressWindow.tcl,v 1.4 2003-12-13 17:54:40 matben Exp $
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
#      -filename, fileName, FileName
#      -font1, font1, Font1
#      -font2, font2, Font2
#      -name, name, Name
#      -percent, percent, Percent
#      -text, text, Text
#      -text2, text2, Text2
#      
#    WIDGET COMMAND
#       pathName cget option
#       pathName configure ?option? ?value option value ...?
#       
#-------------------------------------------------------------------------------

package provide ProgressWindow 1.0

if {![info exists prefs(Progressbar)]} {
    set prefs(Progressbar) 0
}

namespace eval ::ProgressWindow:: {
    global  tcl_platform
    
    # Main routine gets exported.
    namespace export ProgressWindow    
    variable widgetOptions
    variable widgetCommands
    variable this
    variable macWindowStyle
    
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

    if {[string match "mac*" $this(platform)]} {
	if {[info tclversion] <= 8.3} {
	    set macWindowStyle "unsupported1 style"
	} else {
	    set macWindowStyle "::tk::unsupported::MacWindowStyle style"
	}
    }
    
    # List all allowed options with their database names and class names.
    
    array set widgetOptions {
	-background          {background           Background          }  \
	-cancelcmd           {cancelCmd            CancelCmd           }  \
	-filename            {fileName             FileName            }  \
	-font1               {font1                Font1               }  \
        -font2               {font2                Font2               }  \
        -name                {name                 Name                }  \
        -percent             {percent              Percent             }  \
        -text                {text                 Text                }  \
	-text2               {text2                Text2               }  \
      }
    set widgetCommands {cget configure}
    
    # Dimensions, same for all windows.
    variable dims
    array set dims {wwidth 282 wheight 96 xnw 12 ynw 42 xse 198 yse 54 ymid 48 \
      xtxt0 11 ytxt0 23 xtxt1 11 ytxt1 64 xtxt2 0 ytxt2 76 xcanbt 212  \
      xtxt0off 0}

    # Options for this widget
    option add *ProgressWindow.background    #dedede          widgetDefault
    option add *ProgressWindow.cancelCmd     {}               widgetDefault
    option add *ProgressWindow.fileName      {}               widgetDefault
    option add *ProgressWindow.name          {Progress}       widgetDefault
    option add *ProgressWindow.percent       0                widgetDefault
    option add *ProgressWindow.text          {Writing file:}  widgetDefault
    option add *ProgressWindow.text2         {}               widgetDefault
    
    # Platform specifics...
    switch -glob -- $this(platform) {
	unix {
	    option add *ProgressWindow.font1            {Helvetica 10 bold}
	    option add *ProgressWindow.font2            {Helvetica 10 normal}
	}
	windows {
	    option add *ProgressWindow.font1            {Arial 8 bold}
	    option add *ProgressWindow.font2            {Arial 8 normal}
	}
	mac* {
	    option add *ProgressWindow.font1            {Geneva 9 bold}
	    option add *ProgressWindow.font1            system
	    option add *ProgressWindow.font2            {Geneva 9 normal}
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
    global  tcl_platform prefs
    
    variable widgetOptions
    variable widgetCommands
    variable debugLevel
    variable this
    variable macWindowStyle
    
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
    
    toplevel $w
    wm withdraw $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	
    }
    wm resizable $w 0 0
    
    # We use a frame for this specific widget class.
    set widgets(this) $w
    set widgets(frame) $w.fr
    set widgets(canvas) $w.fr.c
    set widgets(toplevel) ::ProgressWindow::${w}::${w}
    
    frame $widgets(frame) -class ProgressWindow
    pack $widgets(frame)

    # Parse options. First get widget defaults.
    foreach name [array names widgetOptions] {
	set optName [lindex $widgetOptions($name) 0]
	set optClass [lindex $widgetOptions($name) 1]
	set options($name) [option get $widgets(frame) $optName $optClass]
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
    global  tcl_platform prefs
    
    variable dims
    variable debugLevel
    upvar ::ProgressWindow::${w}::options options
    upvar ::ProgressWindow::${w}::widgets widgets
    
    if {$debugLevel >= 3} {
	puts "::ProgressWindow::Build:: w=$w"
    }
    wm title $w $options(-name)

    # Width of progress bar.
    set prwidth [expr $dims(xse) - $dims(xnw)]
    
    # Build.
    canvas $widgets(canvas) -scrollregion [list 0 0 $dims(wwidth) $dims(wheight)]  \
      -width $dims(wwidth) -height $dims(wheight) -highlightthickness 0  \
      -bd 1 -relief raised -background $options(-background)
    pack $widgets(canvas) -side top -fill x
    set id [$widgets(canvas) create text $dims(xtxt0) $dims(ytxt0) -anchor sw  \
      -font $options(-font1) -text $options(-text) -tags {ttext topttxt}]
    set xoff [expr [lindex [$widgets(canvas) bbox $id] 2] + 10]
    set dims(xtxt0off) $xoff
    if {[info exists options(-filename)]} {
	$widgets(canvas) create text $xoff $dims(ytxt0) -anchor sw   \
	  -text $options(-filename) -font $options(-font1) -tags {ttext tfilename}
    }
    
    # Small text below progress bar.
    if {[llength $options(-text2)]} {
	set id [$widgets(canvas) create text $dims(xtxt1) $dims(ytxt1) -anchor nw  \
	  -text $options(-text2) -font $options(-font2) -tags {ttext txt2}]
    } else {
	set id [$widgets(canvas) create text $dims(xtxt1) $dims(ytxt1) -anchor sw  \
	  -text {Remaining: } -font $options(-font2) -tags {ttext txt2}]
	set dims(xtxt2) [expr [lindex [$widgets(canvas) bbox $id] 2] + 10]
	if {$options(-percent) >= 100} {
	    $widgets(canvas) create text $dims(xtxt2) $dims(ytxt2) -anchor sw   \
	      -text {Document: done} -font $options(-font2) -tags {ttext percent}  \
	      -fill black
	} else {
	    $widgets(canvas) create text $dims(xtxt2) $dims(ytxt2) -anchor sw   \
	      -text "[expr 100 - int($options(-percent))]% left"  \
	      -font $options(-font2) -tags {ttext percent} -fill black
	}    
    }
    
    # Either use the "Progressbar" package or make our own.
    if {$prefs(Progressbar)} {
	set wpgb [::progressbar::progressbar $widgets(canvas).pr   \
	  -variable ::ProgressWindow::${w}::percent \
	  -width $prwidth -percent $options(-percent)]
	$widgets(canvas) create window $dims(xnw) [expr $dims(ymid) + 1] -anchor w \
	  -window $wpgb
    } else {
	$widgets(canvas) create rectangle $dims(xnw) $dims(ynw) $dims(xse) $dims(yse)  \
	  -fill #CECEFF -outline {}
	$widgets(canvas) create rectangle $dims(xnw) $dims(ynw) $dims(xnw) $dims(yse)  \
	  -outline {} -fill #424242 -tag progbar
	$widgets(canvas) create line $dims(xnw) $dims(ynw) $dims(xnw) $dims(yse)   \
	  $dims(xse) $dims(yse) $dims(xse) $dims(ynw) $dims(xnw) $dims(ynw)  \
	  -width 1 -fill black -tag trect
	if {$options(-percent) > 0} {
	    $widgets(canvas) coords progbar $dims(xnw) $dims(ynw)   \
	      [expr $options(-percent)*($dims(xse) - $dims(xnw))/100 + $dims(xnw)] \
	      $dims(yse)
	}
    }
    
    # Change to flat when no focus, to 3d when focus. Standard MacOS.
    if {$prefs(Progressbar)} {
	bind $w <FocusOut> [list ::ProgressWindow::PBFocusOut $w $wpgb]
	bind $w <FocusIn> [list ::ProgressWindow::PBFocusIn $w $wpgb]
    } else {
	bind $w <FocusOut> [list ::ProgressWindow::PBFocusOut $w junk]
	bind $w <FocusIn> [list ::ProgressWindow::PBFocusIn $w junk]
    }
    focus $w
    button $widgets(canvas).bt -text "Cancel"  \
      -command [list ::ProgressWindow::CancelBt $w $options(-cancelcmd)]  \
      -highlightbackground $options(-background)
    $widgets(canvas) create window $dims(xcanbt) $dims(ymid)   \
      -window $widgets(canvas).bt -anchor w
    update idletasks
    wm deiconify $w
    raise $w
    update idletasks
}

# ::ProgressWindow::Configure ---
#
#       Here we just configures an existing progress window.

proc ::ProgressWindow::Configure {w args} {
    global  prefs

    variable dims
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
    foreach optName [array names opts] {
	if {[string equal $opts($optName) $options($optName)]} {
	    continue
	}
	switch -- $optName {
	    -percent       {
		set perc $opts(-percent)
		
		# Only update progress bar
		if {$prefs(Progressbar)} {
		    set ::ProgressWindow::${w}::percent [expr int($perc)]
		} else {
		    $widgets(canvas) coords progbar $dims(xnw) $dims(ynw)   \
		      [expr $perc*($dims(xse) - $dims(xnw))/100 + $dims(xnw)]  \
		      $dims(yse)
		}
		
		# Percentage left.
		if {$options(-text2) == ""} {
		    $widgets(canvas) delete percent
		    if {$perc >= 100} {
			$widgets(canvas) create text $dims(xtxt2) $dims(ytxt2) -anchor sw   \
			  -text "Document: done" -font $options(-font2)    \
			  -tags {ttext percent} -fill $col
		    } else {
			$widgets(canvas) create text $dims(xtxt2) $dims(ytxt2) -anchor sw   \
			  -text "[expr 100 - int($perc)]% left"  \
			  -font $options(-font2) -tags {ttext percent} -fill $col
		    }
		}
	    }
	    -name        {
		wm title $w $opts(-name)
	    }
	    -filename    {
		$widgets(canvas) delete tfilename
		$widgets(canvas) create text $dims(xtxt0off) $dims(ytxt0) -anchor sw   \
		  -text $opts(-filename) -fill $col   \
		  -font $options(-font1) -tags {ttext tfilename}
	    }
	    -cancelcmd   {
		$widgets(canvas).bt configure  \
		  -command [list ::ProgressWindow::CancelBt $w $opts(-cancelcmd)]
	    }
	    -text        {
		error "-text should only be set when creating the progress window"
	    }
	    -text2       {
		$widgets(canvas) itemconfigure txt2 -text $opts(-text2)
	    }
	    default      {
		
	    }
	}
    }
    
    # Save newly set options.
    array set options $args
    update idletasks    
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

proc ::ProgressWindow::Cleanup {w} {
    
    catch {namespace delete ::ProgressWindow::$w}
}

proc ::ProgressWindow::PBFocusIn {w wpgb} {
    global  prefs
    
    upvar ::ProgressWindow::${w}::widgets widgets

    if {$prefs(Progressbar)} {
	$wpgb configure -shape 3d -color @blue0
    } else {
	$widgets(canvas) itemconfigure progbar -fill #424242
	$widgets(canvas) itemconfigure trect -fill black
    }
    $widgets(canvas) itemconfigure ttext -fill black
    $widgets(canvas).bt configure -state normal
}

proc ::ProgressWindow::PBFocusOut {w wpgb} {
    global  prefs
    
    upvar ::ProgressWindow::${w}::widgets widgets

    if {$prefs(Progressbar)} {
	$wpgb configure -shape flat -color #9C9CFF
    } else {
	$widgets(canvas) itemconfigure progbar -fill #9C9CFF
	$widgets(canvas) itemconfigure trect -fill #6B6B6B
    }
    $widgets(canvas) itemconfigure ttext -fill #6B6B6B
    $widgets(canvas).bt configure -state disabled
}

#-------------------------------------------------------------------------------