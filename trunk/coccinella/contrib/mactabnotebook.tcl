#  mactabnotebook.tcl ---
#  
#      This file is part of The Coccinella application.
#      It implements a tabbed notebook interface.
#      This widget is "derived" from the notebook widget.
#      Code idee from Harrison & McLennan
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
# $Id: mactabnotebook.tcl,v 1.8 2004-01-13 14:50:20 matben Exp $
# 
# ########################### USAGE ############################################
#
#   NAME
#      mactabnotebook - a tabbed notebook widget with a Mac touch.
#      
#   SYNOPSIS
#      mactabnotebook pathName ?options?
#      
#   OPTIONS
#       Notebook class:
#	-borderwidth, borderWidth, BorderWidth
#	-relief, relief, Relief
#	-takefocus, takeFocus, TakeFocus
#	
#	MacTabnotebook class:
#	-activetabcolor, activeTabColor, ActiveTabColor
#	-margin, margin, Margin
#	-style, style, Style
#	-tabbackground, tabBackground, TabBackground
#	-tabcolor, tabColor, TabColor
#	-tabfont, tabFont, TabFont
#	-takefocus, takeFocus, TakeFocus
#	
#   WIDGET COMMANDS
#      pathName cget option
#      pathName configure ?option? ?value option value ...?
#      pathName deletepage pageName
#      pathName displaypage ?pageName?
#      pathName newpage pageName ?-text value?
#      pathName pages
#
# ########################### CHANGES ##########################################
#
#       1.0     Original version
#       1.1     Added -text option to 'newpage' method

package require notebook
package provide mactabnotebook 1.0

namespace eval ::mactabnotebook::  {
    
    namespace export mactabnotebook
    
    # Arrays that collects a information needed.
    # Is unset when finished.
    
    variable toDrawPoly
    variable toDrawLine

    # Globals same for all instances of this widget.
    variable widgetGlobals

    set widgetGlobals(debug) 0
}

# ::mactabnotebook::Init --
#
#       Contains initializations needed for the mactabnotebook widget. It is
#       only necessary to invoke it for the first instance of a widget since
#       all stuff defined here are common for all widgets of this type.
#       
# Arguments:
#       none.
# Results:
#       Defines option arrays and icons for movie controllers.

proc ::mactabnotebook::Init { } {
    global  tcl_platform

    variable toDrawPoly
    variable toDrawLine
    variable toDrawPolyAqua
    variable widgetCommands
    variable widgetGlobals
    variable widgetOptions
    variable notebookOptions
    variable tabOptions
    variable tabDefs
    variable this

    if {$widgetGlobals(debug) > 1}  {
	puts "::mactabnotebook::Init"
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
	-activeforeground    {activeForeground     ActiveForeground    }  \
	-activetabbackground {activeTabBackground  ActiveTabBackground }  \
	-activetabcolor      {activeTabColor       ActiveTabColor      }  \
	-activetaboutline    {activeTabOutline     ActiveTabOutline    }  \
	-background          {background           Background          }  \
	-borderwidth         {borderWidth          BorderWidth         }  \
	-foreground          {foreground           Foreground          }  \
	-margin              {margin               Margin              }  \
	-relief              {relief               Relief              }  \
	-style               {style                Style               }  \
	-tabbackground       {tabBackground        TabBackground       }  \
	-tabcolor            {tabColor             TabColor            }  \
	-tabfont             {tabFont              TabFont             }  \
	-taboutline          {tabOutline           TabOutline          }  \
	-takefocus           {takeFocus            TakeFocus           }  \
    }
    set notebookOptions {-borderwidth -relief}
    set tabOptions {-activeforeground -activetabcolor -activetaboutline \
      -background -foreground -margin -style \
      -tabbackground -tabcolor -tabfont -taboutline -takefocus}
  
    # The legal widget commands. These are actually the Notebook commands.
    set widgetCommands {cget configure deletepage displaypage newpage pages}

    option add *MacTabnotebook.activeForeground    black        widgetDefault
    option add *MacTabnotebook.activeTabColor      #efefef      widgetDefault
    option add *MacTabnotebook.activeTabBackground #cdcdcd      widgetDefault
    option add *MacTabnotebook.activeTabOutline    black        widgetDefault
    option add *MacTabnotebook.background          white        widgetDefault
    option add *MacTabnotebook.margin              6            widgetDefault
    option add *MacTabnotebook.style               classic      widgetDefault
    option add *MacTabnotebook.tabBackground       #dedede      widgetDefault
    option add *MacTabnotebook.tabColor            #cecece      widgetDefault
    option add *MacTabnotebook.tabOutline          gray20       widgetDefault
    option add *Notebook.takeFocus                 0            widgetDefault

    # Aqua
    if {0} {
	option add *MacTabnotebook.activeTabBackground #cdcdcd      widgetDefault
	option add *MacTabnotebook.tabBackground       #acacac      widgetDefault    
	option add *MacTabnotebook.outline             #656565      widgetDefault    
	option add *MacTabnotebook.foreground          #3a3a3a      widgetDefault    
    }
    
    # Platform specifics...
    switch -- $this(platform) {
	unix {
	    option add *MacTabnotebook.tabFont    {Helvetica -12 bold}   widgetDefault
	}
	windows {
	    option add *MacTabnotebook.tabFont    {system}   widgetDefault
	}
	macintosh {
	    option add *MacTabnotebook.tabFont    {system}    widgetDefault
	}
	macosx {
	    option add *MacTabnotebook.tabFont    {{Lucida Grande} 12 bold} widgetDefault
	}
    }
    
    # Canvas drawing commands for the tabs as:
    # 
    # polyogon: {coords col fill tags}
    # line:     {coords col tags}
    
    set toDrawPoly {
	{0 0 $x 0 \
	  [expr $xplm - 2] [expr $ymim + 5] \
	  [expr $xplm] [expr $ymim + 1] \
	  [expr $xplm + 2] $ymim \
	  [expr $xplm + $wd - 2] $ymim \
	  [expr $xplm + $wd] [expr $ymim + 1] \
	  [expr $xplm + $wd + 2] [expr $ymim + 5] \
	  [expr $x + $wd + 2 * $margin] 0  \
	  2000 0 2000 9 0 9}  \
	  black $color {[list $name tab tab-$name]}}
	
    set toDrawLine {
	{1 8 1 1 [expr $x + 1] 1 [expr $x + 1] 0  \
	  [expr $xplm - 1] [expr $ymim + 5] \
	  [expr $xplm] [expr $ymim + 2] \
	  [expr $xplm + 2] [expr $ymim + 1] \
	  [expr $xplm + $wd - 2] [expr $ymim + 1]} \
	#cecece {[list $name ln1up ln1up-$name]}  \
	{2 7 2 2 [expr $x + 1] 2 [expr $x + 2] 0  \
	  [expr $xplm - 0] [expr $ymim + 5] \
	  [expr $xplm] [expr $ymim + 3] \
	  [expr $xplm + 2] [expr $ymim + 2] \
	  [expr $xplm + $wd - 1] [expr $ymim + 2]} \
	#dedede {[list $name ln2up ln2up-$name]}  \
	{[expr $xplm + $wd] [expr $ymim + 3] \
	[expr $xplm + $wd + 1] [expr $ymim + 6] \
	[expr $x + $wd + 2 * $margin - 2] -2}  \
	#bdbdbd {[list $name ln2dn ln2dn-$name]}  \
	{[expr $xplm + $wd] [expr $ymim + 2] \
	[expr $xplm + $wd + 1] [expr $ymim + 4] \
	[expr $x + $wd + 2 * $margin - 1] -1}  \
	#adadad {[list $name ln1dn ln1dn-$name]}  \
	{0 0 $x 0 \
	[expr $xplm - 2] [expr $ymim + 5] \
	[expr $xplm] [expr $ymim + 1] \
	[expr $xplm + 2] [expr $ymim] \
	[expr $xplm + $wd - 2] [expr $ymim] \
	[expr $xplm + $wd] [expr $ymim + 1] \
	[expr $xplm + $wd + 2] [expr $ymim + 5] \
	[expr $x + $wd + 2 * $margin] 0}  \
	black {[list $name ln-$name]}   \
	{[expr $x + $wd + 2 * $margin] 1 2000 1}   \
	#cecece {[list $name ln1tp-$name]}  \
	{[expr $x + $wd + 2 * $margin] 2 2000 2}   \
	#ffffff {[list $name ln2tp-$name]}  \
	{2 8 2000 8}   \
	#9c9c9c {[list $name ln1bt-$name]}  \
	{3 7 2000 7}   \
	#bdbdbd {[list $name ln2bt-$name]}  \
    }
  
    # Helpers to easily switch from one state to another.
    set tabDefs(active,in) {
	ln1up #cecece ln2up #dedede ln1dn #adadad ln2dn #bdbdbd
	ln1tp #cecece ln2tp #ffffff ln1bt #9c9c9c ln2bt #bdbdbd
    }
    set tabDefs(active,out) {
	ln1up #efefef ln2up #efefef ln1dn #efefef ln2dn #efefef
	ln1tp #efefef ln2tp #efefef ln1bt #efefef ln2bt #efefef
    }
    set tabDefs(normal,in) {
	ln1up #cecece ln2up #dedede ln1dn #adadad ln2dn #bdbdbd
    }
    set tabDefs(normal,out) {
	ln1up #dedede ln2up #dedede ln1dn #dedede ln2dn #dedede
    }
    
    # Aqua style tabs:
    #
    # polyogon: {coords col fill tags}
    set toDrawPolyAqua {
	{-2 0 -2 $yl $xleft $yl $xleft $yu $xright $yu $xright $yl \
	  2000 $yl 2000 0}
	$outline $fill $tags
    }
    
    # This allows us to clean up some things when we go away.
    bind MacTabnotebook <Destroy> [list ::mactabnotebook::DestroyHandler %W]
}

# mactabnotebook::mactabnotebook --
#
#       Constructor for the Mac tabbed notebook.
#   
# Arguments:
#       w      the widget.
#       args   list of '-name value' options.
# Results:
#       The widget.

proc ::mactabnotebook::mactabnotebook {w args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable tabOptions
    variable notebookOptions

    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::mactabnotebook w=$w, args='$args'"
    }
    
    # Perform a one time initialization.
    if {![info exists widgetOptions]} {
	Init
    }
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]} {
	    error "unknown option \"$name\" for the mactabnotebook widget"
	}
    }

    # Instance specific namespace
    namespace eval ::mactabnotebook::${w} {
	variable options
	variable widgets
	variable tnInfo
    }
    
    # Set simpler variable names.
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::widgets widgets
    upvar ::mactabnotebook::${w}::tnInfo tnInfo

    # We use a frame for this specific widget class.
    set widgets(this) [frame $w -class MacTabnotebook]
    set widgets(canvas) [canvas $w.tabs -highlightthickness 0]
    set widgets(frame) ::mactabnotebook::${w}::${w}
    set widgets(nbframe) $w.notebook
    pack $w.tabs -fill x
    
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $widgets(frame)

    # Process the new configuration options.
    array set argsarr $args

    # Parse options for the tabs. First get widget defaults.
    foreach name $tabOptions {
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
      "eval ::mactabnotebook::WidgetProc {$w} \$command \$args"
    
    # Select the notebook options from the args.
    set notebookArgs {}
    foreach name $notebookOptions {
	if {[info exists argsarr($name)]} {
	    lappend notebookArgs $name $argsarr($name)
	}
    }
    
    # Creating the notebook widget also makes all the database initializations.
    eval {::notebook::notebook $widgets(nbframe)} $notebookArgs
    pack $widgets(nbframe) -expand yes -fill both

    # Note the plus (+) signs here.
    bind [winfo toplevel $w] <FocusOut> "+ ::mactabnotebook::ConfigTabs $w"
    bind [winfo toplevel $w] <FocusIn> "+ ::mactabnotebook::ConfigTabs $w"
    
    set tnInfo(tabs) {}
    set tnInfo(current) {}
    set tnInfo(pending) {}

    return $w
}

# ::mactabnotebook::WidgetProc --
#
#       This implements the methods, cget, configure etc.
#       
# Arguments:
#       w       the widget path.
#       command the actual command; cget, configure etc.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::mactabnotebook::WidgetProc {w command args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable widgetCommands
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::widgets widgets
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    
    if {$widgetGlobals(debug) > 2} {
	puts "::mactabnotebook::WidgetProc w=$w, command=$command, args=$args"
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
	    set result [eval {Configure $w} $args]
	}
	deletepage {
	    set result [eval {DeletePage $w} $args]
	}
	displaypage {
	    if {[llength $args] == 0} {
		return $tnInfo(current)
	    } elseif {[llength $args] == 1} {
		set result [eval {Display $w} $args]
	    } else {
		error "wrong # args: should be $w displaypage ?pageName?"
	    }
	}
	newpage {
	    set result [eval {NewPage $w} $args]
	}
	pages {
	    set result [Pages $w]
	}
	default {
	    error "unknown command \"$command\" of the mactabnotebook widget.\
	      Must be one of $widgetCommands"
	}
    }
    return $result
}

# ::mactabnotebook::Configure --
#
#       Implements the "configure" widget command (method). 
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::mactabnotebook::Configure {w args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable tabOptions
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::widgets widgets
    
    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::Configure w=$w, args='$args'"
    }
    
    # Error checking.
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]}  {
	    error "unknown option for the mactabnotebook widget: $name"
	}
    }
    if {[llength $args] == 0} {
	
	# Return all mactabnotebook options.
	foreach opt $tabOptions {
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
	    -activetabcolor - -margin - -tabbackground -   \
	      -tabcolor - -tabfont {		
		set redraw 1
	    }
	    -borderwidth - -relief {
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
	Build $w
    }
    return {}
}

# mactabnotebook::NewPage --
#
#       Creates a new page in the widget.
#   
# Arguments:
#       w      the widget.
#       name   its name.
#       args   ?-text value?
# Results:
#       The page widget path.

proc ::mactabnotebook::NewPage {w name args} {
    
    variable widgetGlobals
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::NewPage w=$w, name=$name"
    }
    foreach {key value} $args {
	switch -- $key {
	    -text {
		set tnInfo($name,$key) $value
	    }
	    default {
		return -code error "Unknown option \"$key\" to newpage"
	    }
	}
    }
    set page [$widgets(nbframe) page $name]
    lappend tnInfo(tabs) $name
    
    if {$tnInfo(pending) == ""} {
	set id [after idle [list ::mactabnotebook::Build $w]]
	set tnInfo(pending) $id
    }
    return $page
}

proc ::mactabnotebook::Pages {w} {
    
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    
    return $tnInfo(tabs)
}

# mactabnotebook::DeletePage --
#
#       Deletes a page in the widget.
#   
# Arguments:
#       w      the widget.
#       name   its name.
# Results:
#       none.

proc ::mactabnotebook::DeletePage {w name} {
    
    variable widgetGlobals
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::DeletePage w=$w, name=$name"
    }
    if {[catch {$widgets(nbframe) deletepage $name} err]} {
	return -code error $err
    }
    set ind [lsearch -exact $tnInfo(tabs) $name]
    if {$ind < 0} {
	return -code error "Page \"$name\" is not there"
    }
    set newCurrentName $tnInfo(current)
    
    # If we are about to delete the current page, set another current.
    # Best to pick the same is 'notebook'.
    if {[string equal $tnInfo(current) $name]} {
	
	# Set next page to current.
	set newInd [expr $ind + 1]
	set newCurrentName [lindex $tnInfo(tabs) $newInd]
	if {$newInd >= [llength $tnInfo(tabs)]} {
	    
	    # We are about to delete the last page, set current to next to last.
	    set newCurrentName [lindex $tnInfo(tabs) end-1]
	}
	set tnInfo(current) $newCurrentName
    }
    set tnInfo(tabs) [lreplace $tnInfo(tabs) $ind $ind]
    if {$tnInfo(pending) == ""} {
	set id [after idle [list ::mactabnotebook::Build $w]]
	set tnInfo(pending) $id
    }
    return {}
}

# mactabnotebook::Build --
#
#       Makes the actual drawings of all the tabs.
#   
# Arguments:
#       w      the widget.
# Results:
#       The page widget path.

proc ::mactabnotebook::Build {w} {
    upvar ::mactabnotebook::${w}::options options
    
    switch -- $options(-style) {
	classic {
	    ::mactabnotebook::BuildClassic $w
	}
	aqua {
	    ::mactabnotebook::BuildAqua $w
	}
	default {
	    return -code error "unkonwn style "
	}
    }
}

proc ::mactabnotebook::BuildClassic {w} {
    
    variable toDrawPoly
    variable toDrawLine
    variable widgetGlobals
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::tnInfo tnInfo

    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::BuildClassic w=$w"
    }
    $w.tabs delete all
    set margin $options(-margin)
    set color $options(-tabcolor)
    set font $options(-tabfont)
    set x 2
    set maxh 0
    set coords { }
    
    foreach name $tnInfo(tabs) {
	if {[info exists tnInfo($name,-text)]} {
	    set str $tnInfo($name,-text)
	} else {
	    set str $name
	}
	set id [$w.tabs create text \
	  [expr $x + $margin + 2] [expr -0.5 * $margin]  \
	  -anchor sw -text $str -font $font -tags [list ttxt $name]]
	
	set bbox [$w.tabs bbox $id]
	set wd [expr [lindex $bbox 2] - [lindex $bbox 0]]
	set ht [expr [lindex $bbox 3] - [lindex $bbox 1]]
	if {$ht > $maxh} {
	    set maxh $ht
	}
	
	# The actual drawing of the tab here.
	
	set xplm [expr $x + $margin]
	set ymim [expr -$ht - $margin]
	foreach {coords col fill tags} $toDrawPoly {
	    eval $w.tabs create polygon $coords -outline $col -fill $fill \
	      -tags $tags
	}
	foreach {coords col tags} $toDrawLine {
	    eval $w.tabs create line $coords -fill $col -tags $tags
	}
	$w.tabs raise $id	
	$w.tabs bind $name <ButtonPress-1>  \
	  [list ::mactabnotebook::ButtonPressTab $w $name]
	incr x [expr $wd + 2 * $margin + 3]
    }
    set height [expr $maxh + 2 * $margin]
    $w.tabs move all 0 $height
    $w.tabs configure -width $x -height [expr $height + 10]
    if {[string length $tnInfo(current)]} {
	Display $w $tnInfo(current)
    } else {
	Display $w [lindex $tnInfo(tabs) 0]
    }	
    set tnInfo(pending) {}
}

proc ::mactabnotebook::BuildAqua {w} {
    
    variable toDrawPolyAqua
    variable widgetGlobals
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::tnInfo tnInfo

    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::BuildAqua w=$w"
    }
    $w.tabs delete all

    set font $options(-tabfont)
    set outline $options(-taboutline)
    set fill $options(-tabbackground)
    array set metricsArr [font metrics $font]
    set fontHeight $metricsArr(-linespace)

    set x 8
    set xtext [expr int($x + $fontHeight)]
    set yl -6
    set yltext [expr $yl - 2]
    set yu [expr $yltext - $fontHeight - 2]
    set height [expr abs($yu - 6)]
        
    #{0 0 0 $yl $xleft $yl $xleft $yu $xright $yu $xright $yl 2000 $yl 2000 0}
    #$outline $fill $tags

    foreach name $tnInfo(tabs) {
	if {[info exists tnInfo($name,-text)]} {
	    set str $tnInfo($name,-text)
	} else {
	    set str $name
	}
	set id [$w.tabs create text $xtext $yltext  \
	  -anchor sw -text $str -font $font -tags [list ttxt $name]]
	
	set bbox [$w.tabs bbox $id]
	set wd [expr [lindex $bbox 2] - [lindex $bbox 0]]
	set ht [expr [lindex $bbox 3] - [lindex $bbox 1]]
	set xleft $x
	set xright [expr $xtext + $wd + $fontHeight + 4]
	
	# Draw tabs.
	foreach {coords poutline pfill tags} $toDrawPolyAqua {
	    eval $w.tabs create polygon $coords  \
	      -fill $pfill -outline $poutline -tags $tags
	}
	
	
	set x $xright    
	set xtext [expr int($x + $fontHeight)]
    }
    $w.tabs move all 0 $height
    $w.tabs raise ttxt
    $w.tabs configure -width $x -height $height
    
}

proc ::mactabnotebook::ButtonPressTab {w name} {
    
    upvar ::mactabnotebook::${w}::tnInfo tnInfo

    if {[string equal $name $tnInfo(current)]} {
	return
    }
    Display $w $name
}

# mactabnotebook::ConfigTabs --
#
#       Configures the tabs to their correct state: 
#       focusin/focusout/active/normal.
#   
# Arguments:
#       w      the widget.
# Results:
#       none.

proc ::mactabnotebook::ConfigTabs {w} {

    variable tabDefs
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::options options

    set foc out
    set lncol #737373
    if {[string length [focus]] &&  \
      [string equal [winfo toplevel [focus]] [winfo toplevel $w]]} {
	set foc in
	set lncol black
    }
    set current $tnInfo(current)

    foreach name $tnInfo(tabs) {
	if {[string equal $current $name]} {
	    foreach {t col} $tabDefs(active,$foc) {
		$w.tabs itemconfigure ${t}-${name} -fill $col
	    }
	    $w.tabs itemconfigure ln-$name -fill $lncol
	} else {
	    foreach {t col} $tabDefs(normal,$foc) {
		$w.tabs itemconfigure ${t}-${name} -fill $col
	    }
	    $w.tabs itemconfigure ln-$name -fill $lncol
	}
    }    
    if {[string equal $foc "in"]} {
	$w.tabs itemconfigure tab -fill $options(-tabcolor) -outline $lncol
	$w.tabs itemconfigure tab-$current -fill $options(-activetabcolor) \
	  -outline black
    } else {
	$w.tabs itemconfigure tab -fill #dedede -outline $lncol
	$w.tabs itemconfigure tab-$current -fill #efefef -outline $lncol
    }
    $w.tabs itemconfigure ttxt -fill $lncol
}
    
# mactabnotebook::Display --
#
#       Makes the name page the frontmost one.
#   
# Arguments:
#       w      the widget.
#       name   its name.
#       opt    (optional) "force",
#              "tabsonly"
# Results:
#       none.

proc ::mactabnotebook::Display {w name {opt {}}} {
    
    variable widgetGlobals
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::widgets widgets
    
    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::Display w=$w, name=$name"
    }
    if {$opt != "tabsonly"} {
	$widgets(nbframe) displaypage $name
    }
    $w.tabs raise $name
    set tnInfo(current) $name
    ConfigTabs $w
}

# mactabnotebook::DestroyHandler --
#
#       The exit handler of a mactabnotebook.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       the internal state is cleaned up, namespace deleted.

proc ::mactabnotebook::DestroyHandler {w} {
    
    # Remove the namespace with the widget.
    if {[string equal [winfo class $w] "MacTabnotebook"]} {
	namespace delete ::mactabnotebook::${w}
    }
}
    
#-------------------------------------------------------------------------------


