#  mactabnotebook.tcl ---
#  
#      This file is part of The Coccinella application.
#      It implements a tabbed notebook interface.
#      This widget is "derived" from the notebook widget.
#      Code idee from Harrison & McLennan
#      
#  Copyright (c) 2002-2004  Mats Bengtsson
#  This source file is distributed under the BSD license.
#  
# $Id: mactabnotebook.tcl,v 1.24 2004-11-14 13:53:26 matben Exp $
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
#       Frame class:
#	-borderwidth, borderWidth, BorderWidth
#	-relief, relief, Relief
#   
#       Notebook class:
#	-nbborderwidth, borderWidth, BorderWidth
#	-nbrelief, relief, Relief
#	-nbtakefocus, takeFocus, TakeFocus
#	
#	MacTabnotebook class:
#	-accent1, accent1, Accent1
#	-accent2, accent2, Accent2
#	-activetabcolor, activeTabColor, ActiveTabColor
#	-closebutton, closeButton, Button
#       -closebuttonbg, closeButtonBg, Background
#	-closecommand, closeCommand, Command
#	-margin1, margin1, Margin
#	-margin2, margin2, Margin
#	-orient, orient, Orient
#	-selectcommand, selectCommand, SelectCommand
#	-style, style, Style
#	-tabbackground, tabBackground, TabBackground
#	-tabborderwidth, tabBorderWidth, TabBorderWidth
#	-tabcolor, tabColor, TabColor
#	-tabrelief, tabRelief, TabRelief
#	-font, font, Font
#	-takefocus, takeFocus, TakeFocus
#	
#   WIDGET COMMANDS
#      pathName cget option
#      pathName configure ?option? ?value option value ...?
#      pathName deletepage pageName
#      pathName displaypage ?pageName?
#      pathName getuniquename pageName
#      pathName newpage pageName ?-text value -image imageName?
#      pathName nextpage
#      pathName pageconfigure pageName ?-text value -image imageName?
#      pathName pages
#
# ########################### CHANGES ##########################################
#
#       1.0     Original version
#       2.0     added large number of stuff, mainly styling things

package require notebook
package require colorutils

package provide mactabnotebook 2.0

namespace eval ::mactabnotebook::  {
        
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
    variable toDraw3DAqua
    variable toDrawPolyWinXP
    variable widgetCommands
    variable widgetGlobals
    variable widgetOptions
    variable frameOptions
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
	-accent1             {accent1              Accent1             }  \
	-accent2             {accent2              Accent2             }  \
	-activeforeground    {activeForeground     ActiveForeground    }  \
	-activetabbackground {activeTabBackground  ActiveTabBackground }  \
	-activetabcolor      {activeTabColor       ActiveTabColor      }  \
	-activetaboutline    {activeTabOutline     ActiveTabOutline    }  \
	-background          {background           Background          }  \
	-borderwidth         {borderWidth          BorderWidth         }  \
	-closebutton         {closeButton          Button              }  \
	-closebuttonbg       {closeButtonBg        Background          }  \
	-closecommand        {closeCommand         Command             }  \
	-font                {font                 Font                }  \
	-foreground          {foreground           Foreground          }  \
	-ipadx               {ipadX                PadX                }  \
	-ipady               {ipadY                PadY                }  \
	-margin1             {margin1              Margin              }  \
	-margin2             {margin2              Margin              }  \
	-nbborderwidth       {borderWidth          BorderWidth         }  \
	-nbrelief            {relief               Relief              }  \
	-orient              {orient               Orient              }  \
	-relief              {relief               Relief              }  \
	-selectcommand       {selectCommand        SelectCommand       }  \
	-style               {style                Style               }  \
	-tabbackground       {tabBackground        TabBackground       }  \
	-tabborderwidth      {tabBorderWidth       TabBorderWidth      }  \
	-tabcolor            {tabColor             TabColor            }  \
	-tabgradient1        {tabGradient1         TabColor            }  \
	-tabgradient2        {tabGradient2         TabColor            }  \
	-taboutline          {tabOutline           TabOutline          }  \
	-tabrelief           {tabRelief            TabRelief           }  \
	-takefocus           {takeFocus            TakeFocus           }  \
	-ymargin1            {yMargin1             YMargin1            }  \
    }
    set frameOptions    {-borderwidth -relief}
    set notebookOptions {-nbborderwidth -nbrelief}
    set tabOptions(nostyle) {
	-background -closebutton -closecommand -foreground
	-font -ipadx -ipady 
	-orient -selectcommand -style -takefocus
    }
    set tabOptions(styled) {
	-accent1 -accent2
	-activeforeground -activetabcolor -activetaboutline -activetabbackground
	-closebuttonbg
	-margin1 -margin2 
	-tabgradient1 -tabgradient2 -tabbackground -tabcolor -taboutline
	-tabborderwidth -tabrelief
	-ymargin1
    }
  
    # The legal widget commands. These are actually the Notebook commands.
    set widgetCommands \
      {cget configure deletepage displaypage newpage nextpage pages}

    # Nonstyled options.
    option add *MacTabnotebook.background              white        widgetDefault
    option add *MacTabnotebook.closeButton             0            widgetDefault
    option add *MacTabnotebook.closeCommand            ""           widgetDefault
    option add *MacTabnotebook.foreground              black        widgetDefault
    option add *MacTabnotebook.ipadX                   6            widgetDefault
    option add *MacTabnotebook.ipadY                   1            widgetDefault
    option add *MacTabnotebook.orient                  normal       widgetDefault
    option add *MacTabnotebook.style                   winxp        widgetDefault
    option add *MacTabnotebook.selectCommand           ""           widgetDefault
    option add *Notebook.takeFocus                     0            widgetDefault

    # Styled options for Mac Classic:
    option add *MacTabnotebook.activeForegroundMac     black        widgetDefault
    option add *MacTabnotebook.activeTabColorMac       #efefef      widgetDefault
    option add *MacTabnotebook.activeTabBackgroundMac  #cdcdcd      widgetDefault
    option add *MacTabnotebook.activeTabOutlineMac     black        widgetDefault
    option add *MacTabnotebook.margin1Mac              2            widgetDefault
    option add *MacTabnotebook.margin2Mac              6            widgetDefault
    option add *MacTabnotebook.tabBackgroundMac        #dedede      widgetDefault
    option add *MacTabnotebook.tabColorMac             #cecece      widgetDefault
    option add *MacTabnotebook.tabOutlineMac           gray20       widgetDefault
    option add *MacTabnotebook.yMargin1Mac             6            widgetDefault
    
    # Aqua:
    # taboutline          #575757 - #6a6a6a
    # activetabbackground #aaaaaa - #c6c6c6
    # tabbackground       #848484 - #949494
    option add *MacTabnotebook.activeForegroundAqua    #3a3a3a      widgetDefault
    option add *MacTabnotebook.activeTabBackgroundAqua #bbbbbb      widgetDefault
    option add *MacTabnotebook.margin1Aqua             2            widgetDefault
    option add *MacTabnotebook.margin2Aqua             0            widgetDefault
    option add *MacTabnotebook.tabBackgroundAqua       #8a8a8a      widgetDefault    
    option add *MacTabnotebook.tabBorderWidthAqua      1            widgetDefault    
    option add *MacTabnotebook.tabOutlineAqua          #575757      widgetDefault    
    option add *MacTabnotebook.tabReliefAqua           flat         widgetDefault    
    option add *MacTabnotebook.backgroundAqua          #bebebe      widgetDefault
    option add *MacTabnotebook.foregroundAqua          #3a3a3a      widgetDefault    
    option add *MacTabnotebook.yMargin1Aqua            6            widgetDefault
    
    # Winxp:
    # taboutline          #a0b4bf
    # activetabbackground #ffffff
    # tabbackground       #c8c8de - #ffffff
    # tabaccent           #ea9a3c, #ffd04d
    option add *MacTabnotebook.accent1Winxp            #ea9a3c      widgetDefault
    option add *MacTabnotebook.accent2Winxp            #ffd04d      widgetDefault
    option add *MacTabnotebook.activeForegroundWinxp   black        widgetDefault
    option add *MacTabnotebook.activeTabBackgroundWinxp white       widgetDefault
    option add *MacTabnotebook.closeButtonBgWinxp      #ca2208      widgetDefault
    option add *MacTabnotebook.margin1Winxp            0            widgetDefault
    option add *MacTabnotebook.margin2Winxp            2            widgetDefault
    option add *MacTabnotebook.tabBackgroundWinxp      white        widgetDefault    
    option add *MacTabnotebook.tabGradient1Winxp       white        widgetDefault    
    option add *MacTabnotebook.tabGradient2Winxp       #cecee2      widgetDefault    
    option add *MacTabnotebook.tabOutlineWinxp         #a0b4bf      widgetDefault    
    option add *MacTabnotebook.yMargin1Winxp           1            widgetDefault
    
    # Platform specifics...
    switch -- $this(platform) {
	unix {
	    option add *MacTabnotebook.font    {Helvetica -12}   widgetDefault
	}
	windows {
	    option add *MacTabnotebook.font    {system}   widgetDefault
	}
	macintosh {
	    option add *MacTabnotebook.font    {system}    widgetDefault
	}
	macosx {
	    option add *MacTabnotebook.font    {{Lucida Grande} 12} widgetDefault
	}
    }
    
    # Keep a level of indirection between the tabs name and its corresponding
    # canvas tags by having an uid for each tab and an array 'name2uid'.
    variable uid 0
    
    # Canvas drawing commands for the tabs as:
    # 
    # polyogon: {coords col fill tags}
    # line:     {coords col tags}
    
    set toDrawPoly {
	{0 0 $x 0 \
	  [expr {$xplm - 2}] [expr {$ymim + 5}] \
	  [expr $xplm] [expr {$ymim + 1}] \
	  [expr {$xplm + 2}] $ymim \
	  [expr {$xplm + $wd - 2}] $ymim \
	  [expr {$xplm + $wd}] [expr {$ymim + 1}] \
	  [expr {$xplm + $wd + 2}] [expr {$ymim + 5}] \
	  [expr {$x + $wd + 2 * $margin2}] 0  \
	  2000 0 2000 9 0 9}  \
	  black $color {[list $tname tab tab-$tname]}}
	
    set toDrawLine {
	{1 8 1 1 [expr $x + 1] 1 [expr $x + 1] 0  \
	  [expr $xplm - 1] [expr $ymim + 5] \
	  [expr $xplm] [expr $ymim + 2] \
	  [expr $xplm + 2] [expr $ymim + 1] \
	  [expr $xplm + $wd - 2] [expr $ymim + 1]} \
	#cecece {[list $tname ln1up ln1up-$tname]}  \
	{2 7 2 2 [expr $x + 1] 2 [expr $x + 2] 0  \
	  [expr $xplm - 0] [expr $ymim + 5] \
	  [expr $xplm] [expr $ymim + 3] \
	  [expr $xplm + 2] [expr $ymim + 2] \
	  [expr $xplm + $wd - 1] [expr $ymim + 2]} \
	#dedede {[list $tname ln2up ln2up-$tname]}  \
	{[expr $xplm + $wd] [expr $ymim + 3] \
	[expr $xplm + $wd + 1] [expr $ymim + 6] \
	[expr $x + $wd + 2 * $margin2 - 2] -2}  \
	#bdbdbd {[list $tname ln2dn ln2dn-$tname]}  \
	{[expr $xplm + $wd] [expr $ymim + 2] \
	[expr $xplm + $wd + 1] [expr $ymim + 4] \
	[expr $x + $wd + 2 * $margin2 - 1] -1}  \
	#adadad {[list $tname ln1dn ln1dn-$tname]}  \
	{0 0 $x 0 \
	[expr $xplm - 2] [expr $ymim + 5] \
	[expr $xplm] [expr $ymim + 1] \
	[expr $xplm + 2] [expr $ymim] \
	[expr $xplm + $wd - 2] [expr $ymim] \
	[expr $xplm + $wd] [expr $ymim + 1] \
	[expr $xplm + $wd + 2] [expr $ymim + 5] \
	[expr $x + $wd + 2 * $margin2] 0}  \
	black {[list $tname ln-$tname]}   \
	{[expr $x + $wd + 2 * $margin2] 1 2000 1}   \
	#cecece {[list $tname ln1tp-$tname]}  \
	{[expr $x + $wd + 2 * $margin2] 2 2000 2}   \
	#ffffff {[list $tname ln2tp-$tname]}  \
	{2 8 2000 8}   \
	#9c9c9c {[list $tname ln1bt-$tname]}  \
	{3 7 2000 7}   \
	#bdbdbd {[list $tname ln2bt-$tname]}  \
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
    # polyogon: {coords tags}
    set toDrawPolyAqua {
	{-2 0 -2 $yl $xleft $yl $xleft $yu $xright $yu $xright $yl \
	  2000 $yl 2000 0}
	{[list poly $tname poly-$tname]}
    }
    # 3D lines: {coords tags fill} (depend on -orient)
    set toDraw3DAqua(normal) {
	{-2 0 -2 $yl $xleft $yl $xleft $yu $xright $yu $xright $yl \
	  2000 $yl 2000 0}
	{[list 3d-light $tname 3d-light-$tname]}  $3dlight
	{$xright $yu $xright $yl}
	{[list 3d-dark $tname 3d-dark-$tname]}  $3ddark
    }
    set toDraw3DAqua(hang) {
	{-2 0 -2 $yl $xleft $yl $xleft $yu $xright $yu $xright $yl \
	  2000 $yl 2000 0}
	{[list 3d-light $tname 3d-light-$tname]}  $3ddark
	{$xleft $yl $xleft $yu}
	{[list 3d-dark $tname 3d-dark-$tname]}  $3dlight
    }
    set toDrawPolyWinXP {
	{-2 0 -2 $yl $xleft $yl $xleft [expr {$yu+2}] [expr {$xleft+2}] $yu \
	  [expr {$xright-2}] $yu $xright [expr {$yu+2}] $xright $yl \
	  2000 $yl 2000 0}
	{[list poly $tname poly-$tname]}
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
    variable frameOptions
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
	    return -code error "unknown option \"$name\" for the mactabnotebook widget"
	}
    }

    # Instance specific namespace
    namespace eval ::mactabnotebook::${w} {
	variable options
	variable widgets
	variable tnInfo
	variable name2uid
    }
    
    # Set simpler variable names.
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::widgets widgets
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::name2uid name2uid

    # We use a frame for this specific widget class.
    set widgets(this)    [frame $w -class MacTabnotebook]
    set widgets(canvas)  $w.tabs
    set widgets(frame)   ::mactabnotebook::${w}::${w}
    set widgets(nbframe) $w.notebook
    
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $widgets(frame)

    # Parse options for the tabs. First get widget defaults.
    # Non styled.
    foreach name $tabOptions(nostyle) {
	set optName        [lindex $widgetOptions($name) 0]
	set optClass       [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
	#puts "name=$name, optName=$optName, options($name)=$options($name)"
    }
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    array set options $args
    
    # Styled.
    set styleName [string totitle $options(-style)]
    foreach name $tabOptions(styled) {
	set optName        [lindex $widgetOptions($name) 0]
	append optName     $styleName
	set optClass       [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
    }
    array set options $args    
    
    canvas $widgets(canvas) -highlightthickness 0 -closeenough 0.0 \
      -background $options(-background)
    pack $widgets(canvas) -fill x
    
    # Create the actual widget procedure.
    proc ::${w} {command args}   \
      "eval ::mactabnotebook::WidgetProc {$w} \$command \$args"
    
    # Select the notebook options from the args.
    array set argsarr $args
    set notebookArgs {}
    foreach name $notebookOptions {
	if {[info exists argsarr($name)]} {
	    lappend notebookArgs $name $argsarr($name)
	}
    }
    set frameArgs {}
    foreach name $frameOptions {
	if {[info exists argsarr($name)]} {
	    lappend frameArgs $name $argsarr($name)
	}
    }
    if {[llength $frameArgs] > 0} {
	eval {$widgets(frame) configure} $frameArgs
    }

    # Creating the notebook widget also makes all the database initializations.
    eval {::notebook::notebook $widgets(nbframe)} $notebookArgs
    pack $widgets(nbframe) -expand yes -fill both

    # Note the plus (+) signs here.
    if {[string equal $options(-style) "mac"]} {
	bind [winfo toplevel $w] <FocusOut> "+ ::mactabnotebook::ConfigTabs $w"
	bind [winfo toplevel $w] <FocusIn> "+ ::mactabnotebook::ConfigTabs $w"
    }
    set tnInfo(tabs)     {}
    set tnInfo(current)  {}
    set tnInfo(previous) {}
    set tnInfo(pending)  {}
    set name2uid()       {}

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
		return -code error "wrong # args: should be $w cget option"
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
		return -code error "wrong # args: should be $w displaypage ?pageName?"
	    }
	}
	getuniquename {
	    set result [GetUniqueName $w [lindex $args 0]]
	}
	newpage {
	    set result [eval {NewPage $w} $args]
	}
	nextpage {
	    set result [NextPage $w]
	}
	pageconfigure {
	    set result [eval {PageConfigure $w} $args]
	}
	pages {
	    set result [Pages $w]
	}
	default {
	    return -code error "unknown command \"$command\" of the mactabnotebook widget.\
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
	    return -code error "unknown option for the mactabnotebook widget: $name"
	}
    }
    if {[llength $args] == 0} {
	
	# Return all mactabnotebook options.
	foreach opt $tabOptions(nostyle) {
	    set optName [lindex $widgetOptions($opt) 0]
	    set optClass [lindex $widgetOptions($opt) 1]
	    set def [option get $w $optName $optClass]
	    lappend results [list $opt $optName $optClass $def $options($opt)]
	}
	
	# Get all notebook options as well.
	set nbConfig [$widgets(nbframe) configure]
	return [concat $results $nbConfig]
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
	return -code error "value for \"[lindex $args end]\" missing"
    }    

    # Process the new configuration options.
    array set argsarr $args
    set redraw 0
    set notebookArgs {}
    set frameArgs {}

    # Process the configuration options given to us.
    foreach opt [array names argsarr] {
	set newValue $argsarr($opt)
	set oldValue $options($opt)
	
	switch -- $opt {
	    -activetabcolor - -margin1 - -margin2 - -orient - -tabbackground - \
	      -tabcolor - -font {		
		set redraw 1
	    }
	    -borderwidth - -relief {
		lappend frameArgs $opt $newValue
	    }
	    -nbborderwidth - -nbrelief {
		lappend notebookArgs $opt $newValue
	    }
	    -style {
		return -code error "Cannot change style after widget is created"
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
    if {[llength $frameArgs] > 0} {
	eval {$widgets(frame) configure} $frameArgs
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
#       args   ?-text value -image imageName?
# Results:
#       The page widget path.

proc ::mactabnotebook::NewPage {w name args} {
    
    variable widgetGlobals
    variable uid
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::widgets widgets
    upvar ::mactabnotebook::${w}::name2uid name2uid

    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::NewPage w=$w, name=$name"
    }
    if {[lsearch $tnInfo(tabs) $name] >= 0} {
	return -code error "Page \"$name\"already exists"
    }
    eval {ConfigurePage $w $name} $args
    set page [$widgets(nbframe) page $name]
    lappend tnInfo(tabs) $name
    set name2uid($name) "t[incr uid]"
    
    if {$tnInfo(pending) == ""} {
	set id [after idle [list ::mactabnotebook::Build $w]]
	set tnInfo(pending) $id
    }
    return $page
}


proc ::mactabnotebook::PageConfigure {w name args} {

    upvar ::mactabnotebook::${w}::tnInfo tnInfo

    eval {ConfigurePage $w $name} $args
    if {$tnInfo(pending) == ""} {
	set id [after idle [list ::mactabnotebook::Build $w]]
	set tnInfo(pending) $id
    }
}

proc ::mactabnotebook::ConfigurePage {w name args} {

    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    
    foreach {key value} $args {
	switch -- $key {
	    -text {
		set tnInfo($name,$key) $value
	    }
	    -image {
		if {$value == ""} {
		    unset -nocomplain tnInfo($name,$key)
		} else {
		    set tnInfo($name,$key) $value
		}
	    }
	    default {
		return -code error "Unknown option \"$key\" to newpage"
	    }
	}
    }
}

proc ::mactabnotebook::NextPage {w} {
    
    upvar ::mactabnotebook::${w}::tnInfo tnInfo

    set ind [lsearch -exact $tnInfo(tabs) $tnInfo(current)]
    if {$ind >= 0} {
	if {$ind == [expr {[llength $tnInfo(tabs)]-1}]} {
	    set ind 0
	}
	Display $w [lindex $tnInfo(tabs) $ind]
    }
    return $tnInfo(current)
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
    upvar ::mactabnotebook::${w}::name2uid name2uid

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
    set newCurrent $tnInfo(current)
    
    # If we are about to delete the current page, set another current.
    # Best to pick the same is 'notebook'.
    if {[string equal $tnInfo(current) $name]} {
	
	# Set next page to current.
	set newInd [expr {$ind + 1}]
	set newCurrent [lindex $tnInfo(tabs) $newInd]
	if {$newInd >= [llength $tnInfo(tabs)]} {
	    
	    # We are about to delete the last page, set current to next to last.
	    set newCurrent [lindex $tnInfo(tabs) end-1]
	}
	set tnInfo(current) $newCurrent
    }
    if {[string equal $name $tnInfo(previous)]} {
	set tnInfo(previous)  ""
    }
    if {[string equal $newCurrent $tnInfo(previous)]} {
	set tnInfo(previous)  ""
    }
    
    # Actually remove.
    set tnInfo(tabs) [lreplace $tnInfo(tabs) $ind $ind]
    #unset name2uid($name)
    if {$tnInfo(pending) == ""} {
	set id [after idle [list ::mactabnotebook::Build $w]]
	set tnInfo(pending) $id
    }
    return {}
}


proc ::mactabnotebook::GetUniqueName {w name} {
    
    upvar ::mactabnotebook::${w}::tnInfo tnInfo

    if {[lsearch $tnInfo(tabs) $name] < 0} {
	set uname $name
    } else {
	set i 2
	set uname ${name}-${i}
	while {[lsearch -exact $tnInfo(tabs) $uname] >= 0} {
	    incr i
	    set uname ${name}-${i}
	}
    }
    return $uname
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
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    
    switch -- $options(-style) {
	mac {
	    BuildMac $w
	}
	aqua {
	    BuildAqua $w
	}
	winxp {
	    BuildWinxp $w
	}
	default {
	    return -code error "unkonwn style "
	}
    }
    if {[string length $tnInfo(current)]} {
	Display $w $tnInfo(current)
    } else {
	Display $w [lindex $tnInfo(tabs) 0]
    }	
}

proc ::mactabnotebook::BuildMac {w} {
    
    variable toDrawPoly
    variable toDrawLine
    variable widgetGlobals
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::name2uid name2uid

    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::BuildMac w=$w"
    }
    $w.tabs delete all
    set margin1 $options(-margin1)
    set margin2 $options(-margin2)
    set color   $options(-tabcolor)
    set font    $options(-font)
    set x $margin1
    set maxh 0
    set coords {}
    
    foreach name $tnInfo(tabs) {
	set tname $name2uid($name)
	if {[info exists tnInfo($name,-text)]} {
	    set str $tnInfo($name,-text)
	} else {
	    set str $name
	}
	set id [$w.tabs create text \
	  [expr {$x + $margin2 + 2}] [expr {-0.5 * $margin2}]  \
	  -anchor sw -text $str -font $font -tags [list ttxt $tname]]
	
	set bbox [$w.tabs bbox $id]
	set wd [expr {[lindex $bbox 2] - [lindex $bbox 0]}]
	set ht [expr {[lindex $bbox 3] - [lindex $bbox 1]}]
	if {$ht > $maxh} {
	    set maxh $ht
	}
	
	# The actual drawing of the tab here.
	
	set xplm [expr {$x + $margin2}]
	set ymim [expr {-$ht - $margin2}]
	foreach {coords col fill tags} $toDrawPoly {
	    eval $w.tabs create polygon $coords -outline $col -fill $fill \
	      -tags $tags
	}
	foreach {coords col tags} $toDrawLine {
	    eval $w.tabs create line $coords -fill $col -tags $tags
	}
	$w.tabs raise $id	
	$w.tabs bind $tname <ButtonPress-1>  \
	  [list ::mactabnotebook::ButtonPressTab $w $name]
	incr x [expr {$wd + 2 * $margin2 + 3}]
    }
    set height [expr {$maxh + 2 * $margin2}]
    $w.tabs move all 0 $height
    $w.tabs configure -width $x -height [expr {$height + 10}]

    set tnInfo(pending) {}
}

proc ::mactabnotebook::BuildAqua {w} {
    
    variable toDrawPolyAqua
    variable toDraw3DAqua
    variable widgetGlobals
    variable this
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::name2uid name2uid

    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::BuildAqua w=$w"
    }
    $w.tabs delete all
  
    set font        $options(-font)
    set outline     $options(-taboutline)
    set bd          $options(-tabborderwidth)
    set relief      $options(-tabrelief)
    set fill        $options(-tabbackground)
    set activefill  $options(-activetabbackground)
    set foreground  $options(-foreground)
    set ipadx       $options(-ipadx)
    set ipady       $options(-ipady)
    set margin1     $options(-margin1)
    set margin2     $options(-margin2)
    set closebt     $options(-closebutton)
    array set metricsArr [font metrics $font]
    set fontHeight $metricsArr(-linespace)
    if {[string equal $relief "raised"] && ($bd > 0)} {
	set 3ddark  [::colorutils::getdarker $fill]
	set 3dlight [::colorutils::getlighter $fill]
	set toDraw3D $toDraw3DAqua($options(-orient))
	
	# Cache colors since expensive to compute each time.
	set tnInfo(3dcol,tabbg,dark)  $3ddark
	set tnInfo(3dcol,tabbg,light) $3dlight
	set tnInfo(3dcol,acttabbg,dark)  [::colorutils::getdarker $activefill]
	set tnInfo(3dcol,acttabbg,light) [::colorutils::getlighter $activefill]
    }
    if {$closebt} {
	set tnInfo(btcol,dark)    [::colorutils::getdarker $fill]
	set tnInfo(btcol,darker)  [::colorutils::getdarker $tnInfo(btcol,dark)]
	set tnInfo(btcol,light)   [::colorutils::getlighter $fill]
	set tnInfo(btcol,lighter) [::colorutils::getlighter $tnInfo(btcol,light)]
    }
    
    # Find max height of any image.
    set maxh 0
    foreach {key name} [array get tnInfo "*,-image"] {
	set imh [image height $name]
	if {$imh > $maxh} {
	    set maxh $imh
	}
    }
    if {[string match mac* $this(platform)]} {
	set xoff 1
    } else {
	set xoff 0
    }
    set x $margin1
    set yl -$options(-ymargin1)
    set contenth [expr {$fontHeight > $maxh} ? $fontHeight : $maxh]
    set yu [expr {$yl - $contenth - 2 - 2*$ipady}]
    set ym [expr {($yl + $yu)/2}]
    set height [expr {abs($yu - 6)}]
    
    foreach name $tnInfo(tabs) {
	set tname $name2uid($name)
	if {[info exists tnInfo($name,-text)]} {
	    set str $tnInfo($name,-text)
	} else {
	    set str $name
	}
	if {[info exists tnInfo($name,-image)]} {
	    set im $tnInfo($name,-image)
	    set xim [expr {$x + 2 + $ipadx}]
	    $w.tabs create image $xim $ym -anchor w -image $im  \
	      -tags [list tim $tname]
	    set xtext [expr {$xim + [image width $im] + $ipadx}]
	} else {
	    set xtext [expr {int($x + 2 + $ipadx)}]
	}
	set id [$w.tabs create text $xtext $ym -fill $foreground \
	  -anchor w -text $str -font $font -tags [list ttxt $tname]]
	
	set bbox [$w.tabs bbox $id]
	set wd [expr {[lindex $bbox 2] - [lindex $bbox 0]}]
	set ht [expr {[lindex $bbox 3] - [lindex $bbox 1]}]
	set xleft $x
	set xright [expr {$xtext + $wd + $ipadx + 2}]
	if {$closebt} {
	    incr xright [expr {$contenth + 4}]
	}
	
	# Draw tabs.
	foreach {coords ptags} $toDrawPolyAqua {
	    eval {$w.tabs create polygon} $coords  \
	      -fill $fill -outline $outline -tags $ptags
	}
	
	# 3D border.
	if {[string equal $relief "raised"] && ($bd > 0)} {
	    foreach {coords ptags fill} $toDraw3D {
		eval {$w.tabs create line} $coords  \
		  -fill $fill -tags $ptags
	    }
	}
	
	# Any close button.
	if {$closebt} {
	    DrawReliefButton $w $name [expr {$contenth/2-1}]
	    $w.tabs move $tname&&bt [expr {$xright-$contenth/2-4}] \
	      [expr {$ym-1+$xoff}]
	}	
	#DrawAluRect $w.tabs [expr $xleft+1] [expr $yu+1] [expr $xright-1] $yl  \
	#  $fill talu
	
	# New x for next tab.
	set x [expr {$xright + $margin2}]

	$w.tabs bind $tname <ButtonPress-1>  \
	  [list ::mactabnotebook::ButtonPressTab $w $name]
    }
    $w.tabs move all 0 $height
    $w.tabs raise talu
    $w.tabs raise ttxt
    $w.tabs raise tim
    $w.tabs configure -width $x -height $height
    if {[string equal $options(-orient) "hang"]} {
	$w.tabs scale all 0 0 1 -1
	$w.tabs move all 0 $height
	$w.tabs move tsdw 0 2
    }
    set tnInfo(pending) {}
}

proc ::mactabnotebook::BuildWinxp {w} {
    
    variable toDrawPolyWinXP
    variable widgetGlobals
    variable this
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::name2uid name2uid

    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::BuildAqua w=$w"
    }
    $w.tabs delete all

    set font        $options(-font)
    set outline     $options(-taboutline)
    set fill        $options(-tabbackground)
    set foreground  $options(-foreground)
    set accent1     $options(-accent1)
    set accent2     $options(-accent2)
    set ipadx       $options(-ipadx)
    set ipady       $options(-ipady)
    set margin1     $options(-margin1)
    set margin2     $options(-margin2)
    set closebt     $options(-closebutton)
    array set metricsArr [font metrics $font]
    set fontHeight $metricsArr(-linespace)
    
    if {[string match mac* $this(platform)]} {
	set xoff 1
    } else {
	set xoff 0
    }
    
    # Find max height of any image.
    set maxh 0
    foreach {key name} [array get tnInfo "*,-image"] {
	set imh [image height $name]
	if {$imh > $maxh} {
	    set maxh $imh
	}
    }
    set x $margin1
    set yl -$options(-ymargin1)
    set contenth [expr {$fontHeight > $maxh} ? $fontHeight : $maxh]
    set yu [expr {$yl - $contenth - 2 - 2*$ipady}]
    set ym [expr {($yl + $yu + 2)/2}]
    set height [expr {abs($yu) + 6}]

    foreach {r1 g1 b1} [winfo rgb . $options(-tabgradient1)] break
    foreach {r2 g2 b2} [winfo rgb . $options(-tabgradient2)] break
    foreach col {r g b} {
	set k($col) [expr {double([set ${col}1]-[set ${col}2])/($yu-$yl)}]
	set m($col) [expr [set ${col}1]-$k($col)*$yu]
    }
    for {set y $yu} {$y <= $yl} {incr y} {
	set gcol($y) [format "#%02x%02x%02x" \
	  [expr {int($k(r)*$y+$m(r))/256}]  \
	  [expr {int($k(g)*$y+$m(g))/256}]  \
	  [expr {int($k(b)*$y+$m(b))/256}]]
    }
    
    foreach name $tnInfo(tabs) {
	set tname $name2uid($name)
	if {[info exists tnInfo($name,-text)]} {
	    set str $tnInfo($name,-text)
	} else {
	    set str $name
	}
	if {[info exists tnInfo($name,-image)]} {
	    set im $tnInfo($name,-image)
	    set xim [expr {$x + 2 + $ipadx}]
	    $w.tabs create image $xim $ym -anchor w -image $im  \
	      -tags [list tim $tname]
	    set xtext [expr {$xim + [image width $im] + $ipadx}]
	} else {
	    set xtext [expr {int($x + 2 + $ipadx)}]
	}
	set id [$w.tabs create text $xtext $ym -fill $foreground \
	  -anchor w -text $str -font $font -tags [list ttxt $tname]]
	
	set bbox [$w.tabs bbox $id]
	set wd [expr {[lindex $bbox 2] - [lindex $bbox 0]}]
	set ht [expr {[lindex $bbox 3] - [lindex $bbox 1]}]
	set xleft $x
	set xright [expr {$xtext + $wd + $ipadx + 2}]
	set xlplus [expr {$xleft+1}]
	set xrminus [expr {$xright-$xoff}]
	if {$closebt} {
	    incr xright  [expr {$contenth + 4}]
	    incr xrminus [expr {$contenth + 4}]
	}
	
	# Draw tabs.
	foreach {coords ptags} $toDrawPolyWinXP {
	    eval {$w.tabs create polygon} $coords -fill $fill  \
	      -outline $outline -tags $ptags
	}
	
	# Gradient.
	for {set y [expr {$yu+2}]} {$y < $yl} {incr y} { 
	    $w.tabs create line $xlplus $y $xrminus $y -fill $gcol($y) \
	      -tags [list tgrad $tname]
	}
	
	# Accent lines.
	$w.tabs create line [expr {$xleft+2}] $yu [expr {$xright-2}] $yu  \
	  -fill $accent1 -tags [list tacc $tname]
	$w.tabs create line [expr {$xleft+1}] [expr {$yu+1}] \
	  [expr {$xright-1}] [expr {$yu+1}] \
	  -fill $accent2  -tags [list tacc $tname]
	$w.tabs create line $xleft [expr {$yu+2}] $xright [expr {$yu+2}]  \
	  -fill $accent2 -tags [list tacc $tname]
	
	# Any close button.
	if {$closebt} {
	    DrawWinxpButton $w $name [expr {$contenth/2-1}]
	    $w.tabs move $tname&&bt [expr {$xright-$contenth/2-4}]  \
	      [expr {$ym-1+$xoff}]
	}	
	
	# New x for next tab.
	set x [expr {$xright + $margin2}]

	$w.tabs bind $tname <ButtonPress-1>  \
	  [list ::mactabnotebook::ButtonPressTab $w $name]
    }
    $w.tabs move all 0 $height
    $w.tabs lower tacc
    $w.tabs raise tgrad
    $w.tabs raise ttxt
    $w.tabs raise tim
    $w.tabs raise bt
    $w.tabs configure -width $x -height $height
    if {[string equal $options(-orient) "hang"]} {
	$w.tabs scale all 0 0 1 -1
	$w.tabs move all 0 $height
    }
    set tnInfo(pending) {}
}

proc ::mactabnotebook::ButtonPressTab {w name} {
    
    variable widgetGlobals
    upvar ::mactabnotebook::${w}::tnInfo tnInfo

    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::ButtonPressTab name=$name"
    }
    if {[string equal $name $tnInfo(current)]} {
	return
    }
    Display $w $name
    
    # This is important since it stops triggering accidental clicks on the
    # close button if tab is not the current.
    return -code break
}
    
proc ::mactabnotebook::CloseButton {w name} {
    
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    
    if {$options(-closecommand) != {}} {
	set code [catch {uplevel #0 $options(-closecommand) [list $w $name]}]
	if {$code != 0} {                         
	    return
	}
    }
    DeletePage $w $name
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
    
    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::Display w=$w, name=$name"
    }

    # We may have been deleted sionce this is an idle call.
    if {![winfo exists $w]} {
	return
    }
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::widgets widgets
    upvar ::mactabnotebook::${w}::options options
    
    if {![string equal $opt "tabsonly"]} {
	$widgets(nbframe) displaypage $name
    }
    set same 1
    if {![string equal $name $tnInfo(current)]} {
	set tnInfo(previous) $tnInfo(current)
	set same 0
    }
    set tnInfo(current) $name
    
    # Force build if scheduled.
    if {$tnInfo(pending) != ""} {
	Build $w
    }    
    ConfigTabs $w
    if {!$same && [llength $options(-selectcommand)] > 0} {
	uplevel #0 $options(-selectcommand) [list $w $name]
    }
}

proc ::mactabnotebook::ConfigTabs {w} {

    upvar ::mactabnotebook::${w}::options options
    
    switch -- $options(-style) {
	mac {
	    ConfigClassicTabs $w
	}
	aqua {
	    ConfigAquaTabs $w
	}
	winxp {
	    ConfigWinxpTabs $w
	}
    }
}

# mactabnotebook::ConfigClassicTabs --
#
#       Configures the tabs to their correct state: 
#       focusin/focusout/active/normal.
#   
# Arguments:
#       w      the widget.
# Results:
#       none.

proc ::mactabnotebook::ConfigClassicTabs {w} {

    variable tabDefs
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::name2uid name2uid

    set foc out
    set lncol #737373
    if {[string length [focus]] &&  \
      [string equal [winfo toplevel [focus]] [winfo toplevel $w]]} {
	set foc in
	set lncol black
    }
    set current $tnInfo(current)
    set tcurrent $name2uid($current)
    $w.tabs raise $tcurrent

    foreach name $tnInfo(tabs) {
	set tname $name2uid($name)
	if {[string equal $current $name]} {
	    foreach {t col} $tabDefs(active,$foc) {
		$w.tabs itemconfigure ${t}-${tname} -fill $col
	    }
	    $w.tabs itemconfigure ln-$tname -fill $lncol
	} else {
	    foreach {t col} $tabDefs(normal,$foc) {
		$w.tabs itemconfigure ${t}-${tname} -fill $col
	    }
	    $w.tabs itemconfigure ln-$tname -fill $lncol
	}
    }    
    if {[string equal $foc "in"]} {
	$w.tabs itemconfigure tab -fill $options(-tabcolor) -outline $lncol
	$w.tabs itemconfigure tab-$tcurrent -fill $options(-activetabcolor) \
	  -outline black
    } else {
	$w.tabs itemconfigure tab -fill #dedede -outline $lncol
	$w.tabs itemconfigure tab-$tcurrent -fill #efefef -outline $lncol
    }
    $w.tabs itemconfigure ttxt -fill $lncol
}

proc ::mactabnotebook::ConfigAquaTabs {w} {

    variable this
    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::name2uid name2uid
    
    set current  $tnInfo(current)
    set tcurrent $name2uid($current)
    set activebg $options(-activetabbackground)
    set bg       $options(-tabbackground)
    $w.tabs raise $tcurrent
    set 3d 0
    if {[string equal $options(-tabrelief) "raised"] && \
      ($options(-tabborderwidth) > 0)} {
	set 3d 1
    }
    set bt 0
    if {$options(-closebutton)} {
	set bt 1
    }
    set mac 0
    set border -outline
    if {[string match mac* $this(platform)]} {
	set mac 1
	set border -fill
    }
    foreach name $tnInfo(tabs) {
	set tname $name2uid($name)
	if {[string equal $current $name]} {
	    $w.tabs itemconfigure poly-$tname -fill $activebg
	    if {$3d} {
		$w.tabs itemconfigure 3d-dark-$tname \
		  -fill $tnInfo(3dcol,acttabbg,dark)
		$w.tabs itemconfigure 3d-light-$tname \
		  -fill $tnInfo(3dcol,acttabbg,light)
	    }
	    if {$bt} {
		$w.tabs itemconfigure bt&&light&&$tname \
		  $border $tnInfo(btcol,lighter)
	    }
	} else {
	    $w.tabs itemconfigure poly-$tname -fill $bg
	    if {$3d} {
		$w.tabs itemconfigure 3d-dark-$tname \
		  -fill $tnInfo(3dcol,tabbg,dark)
		$w.tabs itemconfigure 3d-light-$tname \
		  -fill $tnInfo(3dcol,tabbg,light)
	    }
	    if {$bt} {
		$w.tabs itemconfigure bt&&light&&$tname \
		  $border $tnInfo(btcol,light)
	    }
	}
    }        
}

proc ::mactabnotebook::ConfigWinxpTabs {w} {

    upvar ::mactabnotebook::${w}::options options
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::name2uid name2uid
        
    set current $tnInfo(current)
    set previous $tnInfo(previous)
    set tcurrent $name2uid($current)
    $w.tabs raise $tcurrent
    $w.tabs lower tacc
    $w.tabs raise tacc&&${tcurrent}
    
    $w.tabs lower tgrad&&${tcurrent}
    if {$previous != ""} {
	set tprevious $name2uid($previous)
	$w.tabs raise tgrad&&${tprevious} poly&&${tprevious}
    }
    
    foreach name $tnInfo(tabs) {
	set tname $name2uid($current)
	if {[string equal $current $name]} {
	    $w.tabs itemconfigure poly-$tname -fill $options(-activetabbackground)
	} else {
	    $w.tabs itemconfigure poly-$tname -fill $options(-tabbackground)
	}
    }        
}

proc ::mactabnotebook::EnterReliefButton {w name} {
    
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::name2uid name2uid

    set tname $name2uid($name)
    $w.tabs itemconfigure bt&&bg&&$tname -fill $tnInfo(btcol,darker)
}

proc ::mactabnotebook::LeaveReliefButton {w name} {
    
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::name2uid name2uid

    set tname $name2uid($name)
    $w.tabs itemconfigure bt&&bg&&$tname -fill $tnInfo(btcol,dark)
}

proc ::mactabnotebook::DrawReliefButton {w name r} {
    
    variable this
    upvar ::mactabnotebook::${w}::name2uid name2uid
    upvar ::mactabnotebook::${w}::tnInfo tnInfo
    upvar ::mactabnotebook::${w}::options options
    
    set tname $name2uid($name)
    set rm [expr {$r-1}]
    set rM [expr {$r-2}]
    set rp [expr {$r+1}]
    set rP [expr {$r+2}]
    set a  [expr {int(($r-2)/1.4)}]
    set am [expr {$a-1}]
    set ap [expr {$a+1}]
    
    set bg      $options(-tabbackground)
    set dark    $tnInfo(btcol,dark)
    set darker  $tnInfo(btcol,darker)
    set light   $tnInfo(btcol,light)
    set lighter $tnInfo(btcol,lighter)
    #puts "bg=$bg\t dark=$dark\t darker=$darker\t light=$light\t lighter=$lighter"

    set tags      [list $tname bt]
    set tagsbg    [list $tname bt bg]
    set tagslight [list $tname bt light]
    
    # Be sure to offset ovals to put center pixel at (1,1).
    if {[string match mac* $this(platform)]} {
	set idw [$w.tabs create oval -$rm -$rm $r $r -tags $tagslight -outline {} -fill $light]
	$w.tabs create oval -$rm -$rm  $r $r -tags $tagsbg -outline {} -fill $dark
	$w.tabs move $idw 0  1
	$w.tabs create line -$a -$a  $am  $am -tags $tags -fill $bg -width 2
	$w.tabs create line -$a  $am $am -$a -tags $tags -fill $bg -width 2
	$w.tabs create line -$a -$a  $a   $a -tags $tags -fill $lighter
	$w.tabs create line -$a  $a  $a  -$a -tags $tags -fill $lighter
    } else {
	set idw [$w.tabs create oval -$rm -$rm $rm $rm -tags $tagslight \
	  -outline $light -fill $light]
	$w.tabs create oval -$rm -$rm  $rm $rm -tags $tagsbg \
	  -outline $dark -fill $dark
	$w.tabs move $idw 0  1
	$w.tabs create line -$a -$a $a   $a  -tags $tags -fill $bg -width 2
	$w.tabs create line -$a  $a $a  -$a  -tags $tags -fill $bg -width 2
	$w.tabs create line -$a -$a $ap  $ap -tags $tags -fill $lighter
	$w.tabs create line -$a  $a $ap -$ap -tags $tags -fill $lighter
    }
    $w.tabs bind bt&&$tname <ButtonPress-1>  \
      [list ::mactabnotebook::CloseButton $w $name]
    $w.tabs bind bt&&$tname <Enter>  \
      [list ::mactabnotebook::EnterReliefButton $w $name]
    $w.tabs bind bt&&$tname <Leave>  \
      [list ::mactabnotebook::LeaveReliefButton $w $name]
}

proc ::mactabnotebook::DrawWinxpButton {w name r} {
    
    variable this
    upvar ::mactabnotebook::${w}::name2uid name2uid
    upvar ::mactabnotebook::${w}::options options

    set tname $name2uid($name)
    set rm [expr {$r-1}]
    set a  [expr {int(($r-2)/1.4)}]
    set ap [expr {$a+1}]

    set red  $options(-closebuttonbg)
    set tags [list $tname bt]
    
    # Be sure to offset ovals to put center pixel at (1,1).
    if {[string match mac* $this(platform)]} {
	$w.tabs create oval -$rm -$rm  $r $r -tags $tags -outline {} -fill $red
	set id1 [$w.tabs create line -$a -$a $a  $a -tags $tags -fill white]
	set id2 [$w.tabs create line -$a  $a $a -$a -tags $tags -fill white]
    } else {
	$w.tabs create oval -$rm -$rm $rm $rm -tags $tags -outline $red -fill $red
	set id1 [$w.tabs create line -$a -$a $ap  $ap -tags $tags -fill white]
	set id2 [$w.tabs create line -$a  $a $ap -$ap -tags $tags -fill white]
    }
    $w.tabs bind bt&&$tname <ButtonPress-1>  \
      [list ::mactabnotebook::CloseButton $w $name]
}

proc ::mactabnotebook::DrawAluRect {wcan x0 y0 x1 y1 col tag} {
        
    foreach {r g b} [winfo rgb . $col] break
    
    set dcol [expr {10*256}]
    set lenmin 10
    set lenmax 40
    set nstrokes [expr {2.0 * ($x1-$x0)/$lenmax}]
    set xleft  [expr {$x0-$lenmin}]
    set xright [expr {$x1+$lenmin}]
    set xlen   [expr {$xright-$xleft}]
    
    # If x is the probability to draw a stroke with given conditions,
    # then <n> = (1-x) sum n x^(n-1), where n is the number of strokes 
    # until failure (included). Then nstrokes = n-1.
    # We get: <n> = 1/(1-x)  ->  x = nstrokes/(1+nstrokes).
    
    set pstroke [expr {$nstrokes/(1+$nstrokes)}]
    puts "nstrokes=$nstrokes, pstroke=$pstroke"
    
    for {set y $y0} {$y < $y1} {incr y} { 
    
	while {[expr {rand() < $pstroke}]} {
	    set rmid [expr {$xleft+rand()*$xlen}]
	    set rlen [expr {$lenmin+rand()*($lenmax-$lenmin)}]
	    set xl [expr {$rmid-$rlen}]
	    set xr [expr {$rmid+$rlen}]
	    set xl [expr {$xl < $x0} ? $x0 : $xl]
	    set xr [expr {$xr > $x1} ? $x1 : $xr]
	    set gray [expr {int($r+2.0*(rand()-0.5)*$dcol)}]
	    set c [eval format "#%04x%04x%04x" $gray $gray $gray]
	    $wcan create line $xl $y $xr $y -fill $c -tags $tag
	}
    }
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

    variable widgetGlobals
    upvar ::mactabnotebook::${w}::tnInfo tnInfo

    if {$widgetGlobals(debug) > 1} {
	puts "::mactabnotebook::DestroyHandler w=$w, pending=$tnInfo(pending)"
    }
    if {$tnInfo(pending) != ""} {
	after cancel $tnInfo(pending)
    }

    # Remove the namespace with the widget.
    if {[string equal [winfo class $w] "MacTabnotebook"]} {
	namespace delete ::mactabnotebook::${w}
    }
}
    
#-------------------------------------------------------------------------------


