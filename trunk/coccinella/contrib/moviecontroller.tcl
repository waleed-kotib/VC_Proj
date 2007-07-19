#  moviecontroller.tcl ---
#  
#      This file is part of The Coccinella application. It implements a
#      QuickTime look alike movie controller widget.
#      
#  Copyright (c) 2000  Mats Bengtsson
#  
#  This file is distributed under BSD style license.
#  
# $Id: moviecontroller.tcl,v 1.7 2007-07-19 06:28:11 matben Exp $

#  Code idee from Alexander Schoepe's "Progressbar", thank you!
#
# ########################### USAGE ############################################
#
#   NAME
#      moviecontroller - a QuickTime-style controller for movies.
#      
#   SYNOPSIS
#      moviecontroller pathName ?options?
#      
#   OPTIONS
#      -audio, audio, Audio
#      -command, command, Command
#      -percent, percent, Percent
#      -snacksound, snackSound, SnackSound
#      -takefocus, takeFocus, TakeFocus
#      -variable, variable, Variable
#      -volume, volume, Volume
#      -width, width, Width
#      
#   WIDGET COMMANDS
#      pathName cget option
#      pathName configure ?option? ?value option value ...?
#      pathName play
#      pathName stop
#
# ########################### CHANGES ##########################################
#
#       1.0      first release
#       1.01     added package provide

package provide moviecontroller 1.0

namespace eval ::moviecontroller {

    # The public interface.
    namespace export moviecontroller

    # Globals same for all instances of this widget.
    variable widgetGlobals
    
    set widgetGlobals(debug) 0
}

# ::moviecontroller::Init --
#
#       Contains initializations needed for the moviecontroller widget. It is
#       only necessary to invoke it for the first instance of a widget since
#       all stuff defined here are common for all widgets of this type.
#       
# Arguments:
#       none.
# Results:
#       Defines option arrays and icons for movie controllers.

proc ::moviecontroller::Init {  }  {
    
    variable widgetGlobals
    variable widgetOptions
    variable widgetCommands
    
    if {$widgetGlobals(debug) > 1}  {
	puts "::moviecontroller::Init"
    }
    
    # List all allowed options with their database names and class names.
    
    array set widgetOptions {
	-audio         {audio         Audio      }      \
	-command       {command       Command    }      \
	-percent       {percent       Percent    }      \
	-snacksound    {snackSound    SnackSound }      \
	-takefocus     {takeFocus     TakeFocus  }      \
	-variable      {variable      Variable   }      \
	-volume        {volume        Volume     }      \
	-width         {width         Width      }      \
    }
  
    # The legal widget commands.
    set widgetCommands {cget configure play stop}

    if {[info tclversion] >= 8.3}  {
	set widgetGlobals(milliSecs) 1
    } else {
	set widgetGlobals(milliSecs) 0
    }
    
    # MIME translated gifs for the actual widget.
    # The volume buttons: off, normal, and full.    

    set qtmc_vol_off {
R0lGODdhDwAOAOMAAMzMzN3d3bu7u+7u7qqqqpmZmYiIiERERHd3d2ZmZlVVVf//////////
/////////ywAAAAADwAOAAAEXhDIQIMUQl4RBgUYURSYQHQWYBBsYayEMHjqYY4GUpxeYBwH
gMiFQJwCwKQQh0gck8AlUXECQIOiF4J6qdmYCWeIhfhqE0bWsIAQnBWwkdxATCjSrVyxGcbP
+X10chEAOw==}

    set qtmc_vol {
R0lGODdhDwAOALMAAP///+/v797e3s7Ozr29va2trZycnIyMjHNzc2NjY1JSUkJCQjExMQAA
AAAAAAAAACwAAAAADwAOAAAEYXBIQYUkRF4iAh1YYRgYUXTWcBSscawFEXjqYo4HYpyecCyL
wQKHQJwEwOSgMMwljkng0pZTnITRaaFauNRswwIi8QyxELad08gSjRCE11gBG9kPrjm7lSuO
yXt3f4B4dhEAOw==}

    set qtmc_vol_full {
R0lGODdhDwAOAOMAAMzMzN3d3bu7u+7u7qqqqpmZmYiIiERERHd3d2ZmZlVVVf//////////
/////////ywAAAAADwAOAAAEZBDIQIMUQl4RBgUYURSYQHQWYBBsYayEMHjqYR4uUpxeYBwH
gOhgQCBOAaASgDsQEAmkEsgUOBGKE3NavWYvNRvJmYiGWAgxsZA4skQjhOBFSChgo7whZ3e3
ikZQZX56goN7eREAOw==}

    set qtmc_vol_off_push {
R0lGODdhDwAOAOMAAMzMzKqqqnd3d2ZmZlVVVZmZmbu7u4iIiERERP//////////////////
/////////ywAAAAADwAOAAAEYhDIIAa5o0hpTB1gSAidQYHCURTHUR1BcIBqJwSrG1e3ARwI
HEtQCIAKPmAwlzISEVCo0HUbPKPLlqCawSJyLlilSIGyqMWZaiVAaLcmSio3oBIBMVlrv72b
VoBUKgEABisRADs=}

    set qtmc_vol_push {
R0lGODdhDwAOAOMAAMzMzKqqqnd3d2ZmZlVVVZmZmbu7u4iIiERERP//////////////////
/////////ywAAAAADwAOAAAEYhDIIAa5o0hpTB1gSAidQYHCURTHUR1BcIBqJwSrG1e3ARwI
HEtQCIAKPmAQMYQNiIhoFIdw3Z4F6TRrNWa0TG7qVKRExUTZQLUSVK2kXSq3Ftg1MVlrbycC
TCuBVioBfysRADs=}

    set qtmc_vol_full_push {
R0lGODdhDwAOAOMAAMzMzKqqqnd3d2ZmZlVVVZmZmbu7u4iIiERERP//////////////////
/////////ywAAAAADwAOAAAEYxDIIAa5o0hpTB1gSAidQYHCURTHUR1BcIBqJwSrG1e3ARwI
HMJVCIAKPmBwhUgFRgWEVBpARAU36JQ6bGYzW2vXedxJWUBBcaZaCYZp0i6VG7iwmpisxceq
ASYrgncqAYArEQA7}

    # The play button.
    set qtmc_play {
R0lGODdhFgAOALMAAP///+/v797e3s7Ozr29va2trZycnIyMjHNzc2NjY1JSUkJCQgAAAAAA
AAAAAAAAACwAAAAAFgAOAAAEfXBIQYUkROp9iQjUgBWGgZ0oUXyWWLzGcbx0TQTgcozlgRi1
GkuwKM56CEQQoViEBsXoz5eoIRaKxDPK9SlqCgXiYMFwdS8mOHEwdKI7ggGRqNIObJOqoBvJ
6Eo1MjMwJiR/CQqEQYUlMYhijEExSUl1CYGSJEiXmG2OoI4RADs=}
    set qtmc_play {
R0lGODdhDgAOAOMAAM7Ozt7e3r29ve/v762trZycnIyMjEJCQnNzc2NjY1JSUv//////////
/////////ywAAAAADgAOAAAEWhDIQIMUQgIcBt0CURQY0VkboRaGQQiDdxjlaCDFGRy8ayOI
D4BHxN0SQqLyprBglDMVQnEREGmCAiKRKBFmpdYWoRKRROKEwjeypRXk1Q245cbbR24CYWhH
AAA7}

    set qtmc_play_push {
R0lGODdhDgAOAOMAAP///wAAAMzMzKqqqnd3d2ZmZlVVVZmZmbu7u4iIiERERMDAwP//////
/////////ywAAAAADgAOAAAEWlDIQYq55UiBUC1gaBAdBRLJcSRJlQwJmJaD2prEgCgJUq+E
A+iAECiOQWBiRDQekS0Cs/OsEqQZarXQimUGgycquuKqFEHWlURB2dRXDZhFjwY5qnw0NcBH
AAA7}

    # The stop button.
    set qtmc_stop {
R0lGODdhDgAOALMAAP///+/v797e3s7Ozr29va2trZycnIyMjHNzc2NjY1JSUkJCQjExMQAA
AAAAAAAAACwAAAAADgAOAAAEWnBIQYUkRA4sAt1EYRhY0VlboRrHURCBtyzEPB6IcQrzMBMs
BOLjWxSBuASx9wsqLBgmrYVQXGrGXzJRKvxmhSRCJSIBVYiEwjVqt5KK8QonTCcScrf9jji0
IwA7}

    set qtmc_stop_push {
R0lGODdhDgAOAOMAAMzMzKqqqnd3d2ZmZlVVVZmZmbu7u4iIiERERP//////////////////
/////////ywAAAAADgAOAAAEXBDIIAa5o0hgTB1gSAgdBQpHURxHdQQHmJaB2ppCYCDIjqyC
AqhgAPB8wMOIaEQEeEDBssN7IlgCaYbq5GFjmYC14M2uBinyj5clUVA2rBkgZtlbc4Nqj08F
OAURADs=}

    # The left end of the ruler.
    set qtmc_left {
R0lGODdhCAAOAOMAAM7Ozr29va2trXNzc1JSUkJCQmNjY4yMjJycnP//////////////////
/////////ywAAAAACAAOAAAEIhDIKYO9VujNux9EwQ0FYXAEMRyocSDc4cLxwXp4riF8z0cA
Ow==}

    # The slider button.
    set qtmc_drag {
R0lGODdhDAAOALMAAP///+/v797e3s7Ozr29va2trZycnIyMjHNzc2NjY1JSUkJCQjExMQAA
AAAAAAAAACwAAAAADAAOAAAEV3AMYs5ByBBJiilEVyVgtYUiklSFwImHgg3ugAiekciSdOcI
BqJH+BkMweGkiKskUYXb8ZBgrApYqUWxoB6/lmomkThULomF4qNTJFQKhuKQo8YZi/IxAgA7}

    set qtmc_drag_push {
R0lGODdhDAAOAOMAAMzMzLu7u4iIiHd3d2ZmZpmZmaqqqkRERFVVVTMzMyIiIv//////////
/////////ywAAAAADAAOAAAEWhCAIMQgowQZjChGIRAHonlGWF2lCBaiRSAJIYRiElzIcQw4
gY4wOygyFWGA2FMQYoNh0WkZRJcImtNK1GUPicTgQGT2Es5CL9sDKw4gAS0BRh9usJHxbYNF
AAA7}

    # The rewind button.
    set qtmc_rew {
R0lGODdhFQAOALMAAP///+/v797e3s7Ozr29va2trZycnIyMjHNzc2NjY1JSUkJCQjExMQAA
AAAAAAAAACwAAAAAFQAOAAAEc3DISYUVkpCpuxeBNWiFYZBFqhYgNqrGcawrEYTDsRDLEiOG
xGzVEugWgx7hgGgmDETMEalkCmXRKXXHVJiGKcyyty10TbTMeNcrIBJPWgHlZi/cCYR8ZYIu
UwkKYDR9XzJvCnp7KT9Nb3CKhZI/cJAHfREAOw==}

    set qtmc_rew_push {
R0lGODdhDgAOAOMAAMzMzKqqqnd3d2ZmZlVVVZmZmbu7u4iIiERERP//////////////////
/////////ywAAAAADgAOAAAEXBDIIAa5o0hgTB1gSAgdBQpHURxHdQQHmJaB2ppCYAAHEiCI
VgFU2PV8wNZhVDwigwIB0/lsSTMeIKKQRBEDFCAXEV0NUipBEBg1UFA2VlSgAbPuVjpHxbem
AnsRADs=}

    # The fast forward button.
    set qtmc_ff {
R0lGODdhDwAOALMAAP///+/v797e3s7Ozr29va2trZycnIyMjHNzc2NjY1JSUkJCQjExMQAA
AAAAAAAAACwAAAAADwAOAAAEYXDIIaqQhMxMRKhDVhiGWHhXWKzGcaxEECzLsCRjixjnRwu0
BOmAQJwuP9pNhwMllQmi4hSi2YIjxBRjDRIKiARORCPcvsSEcTXKlAppxStHarnCijWLWAyL
13VMYmoHdREAOw==}

    set qtmc_ff_push {
R0lGODdhDwAOAOMAAMzMzKqqqnd3d2ZmZlVVVZmZmbu7u4iIiERERP//////////////////
/////////ywAAAAADwAOAAAEXhBIEMQgeJRpuh1gSAhdUIHCURTHYR3mAaplsLqmJQQIYiAa
lqAQABV+vp7GBRsde0gEwbVzInk9qaCquWanqaIGiwUPAzJVryClknKpW2s7pMRaePrGsOoL
4wEAfBEAOw==}

    set qtmcvol_drag {
R0lGODdhEQAMAOMAAMzMzLu7u5mZmYiIiHd3d2ZmZqqqqt3d3VVVVTMzM0RERP//////////
/////////ywAAAAAEQAMAAAEYRCEIAa5twxhuJDGYACkJBSF4AFdcBxl0KErV5JTNyDiN0wx
WeeE6AB+EwymQkgYCYbJa3qoFJwfAsfA5aosCMVzoypXBlfo50Qgn9EKnnGGKGAKiARvJRMQ
8gmBClodHREAOw==}

    # The complete volume window.
    set qtmcvol_win {
R0lGODlhEwBLAOMAAAAAAMzMzLu7u5mZmaqqqnd3d1VVVYiIiERERGZmZt3d3TMzM///////
/////////yH+Dk1hZGUgd2l0aCBHSU1QACwAAAAAEwBLAAAE8BDISWsNOOuNZRBgKI6DJxBo
qqol8K1w2r4xPJ9pYezHeueIXSLRk5lSu0LhwGQdUQjiYTAoon7Q5bTqdOEICC3VSsCCxVyj
NxVmjru0szt9fcq3ZHMbD//u32pxf3RldoN5hmiIa1lzi4KKfWyRgX6UdYx3gJiQjpKNfJWT
nqKgm4WZh5+ahHqXqJ2hnJaks6OysLS4rrW5t6e8u4m9wcDDwqmvxa3HxsnEzczPyLHO1dLX
j7rW29jd2r/e4eCm4uXkrOiqpemr67bn7srR6AloA6sHUlQ+dmVMZODVWDVQYEFfBzlRWciw
IRULECFGAAA7}

    # Make the actual images in tk. 
    set widgetGlobals(qtmc_left)     [image create photo -data $qtmc_left]
    set widgetGlobals(qtmc_vol_off)  [image create photo -data $qtmc_vol_off]
    set widgetGlobals(qtmc_vol)      [image create photo -data $qtmc_vol]
    set widgetGlobals(qtmc_vol_full) [image create photo -data $qtmc_vol_full]
    set widgetGlobals(qtmc_vol_off_push) \
      [image create photo -data $qtmc_vol_off_push]
    set widgetGlobals(qtmc_vol_push) [image create photo -data $qtmc_vol_push]
    set widgetGlobals(qtmc_vol_full_push) \
      [image create photo -data $qtmc_vol_full_push]
    set widgetGlobals(qtmc_play)     [image create photo -data $qtmc_play]
    set widgetGlobals(qtmc_play_push)    \
      [image create photo -data $qtmc_play_push]
    set widgetGlobals(qtmc_stop)     [image create photo -data $qtmc_stop]
    set widgetGlobals(qtmc_stop_push)    \
      [image create photo -data $qtmc_stop_push]
    set widgetGlobals(qtmc_drag)     [image create photo -data $qtmc_drag]
    set widgetGlobals(qtmc_drag_push)    \
      [image create photo -data $qtmc_drag_push]
    set widgetGlobals(qtmc_rew)      [image create photo -data $qtmc_rew]
    set widgetGlobals(qtmc_rew_push)     \
      [image create photo -data $qtmc_rew_push]
    set widgetGlobals(qtmc_ff)       [image create photo -data $qtmc_ff]
    set widgetGlobals(qtmc_ff_push)  [image create photo -data $qtmc_ff_push]
    set widgetGlobals(qtmcvol_win)   [image create photo -data $qtmcvol_win]
    set widgetGlobals(qtmcvol_drag)  [image create photo -data $qtmcvol_drag]
    
    # Unset the base64 coded gif data to save some space.
#    unset qtmc_vol_off qtmc_vol qtmc_vol_full qtmc_play qtmc_stop   \
#      qtmc_drag qtmc_rew qtmc_ff qtmcvol_drag qtmcvol_top qtmcvol_bot
    unset qtmc_vol_off qtmc_vol qtmc_vol_full qtmc_play qtmc_stop   \
      qtmc_drag qtmc_rew qtmc_ff qtmcvol_drag

    # Define coordinates for the images; only x coords needed; anchor nw.
    set widgetGlobals(w_vol)    15
    set widgetGlobals(w_play)   22
    set widgetGlobals(w_stop)   14
    set widgetGlobals(w_rew)    21
    set widgetGlobals(w_ff)     15
    
    # The volume control popup widget. Hardcoded values.
    set widgetGlobals(vol_w)       19
    set widgetGlobals(vol_h)       75
    set widgetGlobals(vol_bg)      #adadad
    set widgetGlobals(hvol_top)    8
    set widgetGlobals(hvol_bot)    7
    set widgetGlobals(hvol_scaleh) [expr $widgetGlobals(vol_h) -  \
      $widgetGlobals(hvol_top) - $widgetGlobals(hvol_bot)]
    
    # Depending on the volume percentage, show different loud speakers on the
    # volume button. Here are the boundaries in pixels found from the 
    # percentages. Pixels relative top of volume canvas. Limits at 25% and 75%.
    
    set widgetGlobals(hvol_off) [expr int($widgetGlobals(hvol_top) +  \
      0.75 * $widgetGlobals(hvol_scaleh))]
    set widgetGlobals(hvol_full) [expr int($widgetGlobals(hvol_top) +  \
      0.25 * $widgetGlobals(hvol_scaleh))]
    
    # The slide ruler as canvas drawing commands plus black frame.
    set widgetGlobals(todraw) {
	line tline1 #cecece {$lmark 1 $rmark 1}  \
	line tline2 #bdbdbd {$lmark 2 $rmark 2}  \
	line tline3 #adadad {$lmark 3 $rmark 3}  \
	line tline4 #adadad {$lmark 4 $rmark 4}  \
	line tline5 #424242 {$lmark 5 $rmark 5}  \
	line tline6 #737373 {$lmark 6 $rmark 6}  \
	line tline7 #8c8c8c {$lmark 7 $rmark 7}  \
	line tline8 #9c9c9c {$lmark 8 $rmark 8}  \
	line tline9 #9c9c9c {$lmark 9 $rmark 9}  \
	line tline10 #8c8c8c {$lmark 10 $rmark 10}  \
	line tline11 #adadad {$lmark 11 $rmark 11}  \
	line tline12 #adadad {$lmark 12 $rmark 12}  \
	line tline13 #adadad {$lmark 13 $rmark 13}  \
	line tline14 #9c9c9c {$lmark 14 $rmark 14}  \
	line tfr0 #000000 {0 0 [expr $width-1] 0 [expr $width-1] 15 0 15 0 0} \
    }
    
    # The icons to draw. Note that 'qtmc_vol' is drawn last on top of the other.
    set widgetGlobals(drawimages) {
	image tvoloff       qtmc_vol_off       {1 1}      nw \
	image tvolfull      qtmc_vol_full      {1 1}      nw \
	image tvoloffpu     qtmc_vol_off_push  {1 1}      nw \
	image tvolpu        qtmc_vol_push      {1 1}      nw \
	image tvolfullpu    qtmc_vol_full_push {1 1}      nw \
	image tvol          qtmc_vol           {1 1}      nw \
	image tstoppu       qtmc_stop_push     {$xplay 1} nw \
	image tstop         qtmc_stop          {$xplay 1} nw \
	image tplaypu       qtmc_play_push     {$xplay 1} nw \
	image tplay         qtmc_play          {$xplay 1} nw \
	image tleft         qtmc_left          {[expr $xplay+14] 1} nw \
	image trewpu        qtmc_rew_push      {[expr $rmark+7] 1} nw \
	image trew          qtmc_rew           {$rmark 1} nw \
	image tffpu         qtmc_ff_push       {[expr $rmark+21] 1} nw \
	image tff           qtmc_ff            {[expr $rmark+21] 1} nw \
	image tdragpu       qtmc_drag_push     {$xmark 1} n  \
	image tdrag         qtmc_drag          {$xmark 1} n  \
    }
        
    # Options for this widget
    option add *MovieController.audio         1         widgetDefault
    option add *MovieController.command       {}        widgetDefault
    option add *MovieController.percent       0         widgetDefault
    option add *MovieController.snackSound    {}        widgetDefault
    option add *MovieController.takeFocus     0         widgetDefault
    option add *MovieController.variable      {}        widgetDefault
    option add *MovieController.volume        50        widgetDefault
    option add *MovieController.width         160       widgetDefault

    # This allows us to clean up some things when we go away.
    bind MovieController <Destroy> [list ::moviecontroller::DestroyHandler %W]
}

# ::moviecontroller::moviecontroller --
#
#       The constructor of this class; it creates an instance named 'w' of the
#       moviecontroller. 
#       
# Arguments:
#       w       the widget path.
#       args    (optional) list of key value pairs for the widget options.
# Results:
#       The widget path or an error. Calls the necessary procedures to make a 
#       complete movie controller widget.

proc ::moviecontroller::moviecontroller { w {args {}} }  {

    variable widgetGlobals
    variable widgetOptions

    if {$widgetGlobals(debug) > 1}  {
	puts "::moviecontroller::moviecontroller w=$w, args=$args"
    }
    
    # We need to make Init at least once.
    if {![info exists widgetOptions]}  {
	Init
    }
    
    # Error checking.
    foreach {name value} $args  {
	if {![info exists widgetOptions($name)]}  {
	    error "unknown option for the moviecontroller: $name"
	}
    }
    
    # Continues in the 'Build' procedure.
    set wans [eval Build $w $args]
    return $wans
}

# ::moviecontroller::Build --
#
#       Parses options, creates widget command, and calls the Configure 
#       procedure to do the rest.
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#       The widget path or an error.

proc ::moviecontroller::Build { w args }  {

    variable widgetGlobals
    variable widgetOptions

    if {$widgetGlobals(debug) > 1}  {
	puts "::moviecontroller::Build w=$w, args=$args"
    }

    # Instance specific namespace
    namespace eval ::moviecontroller::${w} {
	variable options
	variable widgets
	variable wlocals
    }
    
    # Set simpler variable names.
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::widgets widgets

    # We use a frame for this specific widget class.
    set widgets(this) [frame $w -class MovieController]
    
    # Set only the name here.
    set widgets(canvas) $w.mc
    set widgets(frame) ::moviecontroller::${w}::${w}
    
    # Need to get a unique toplevel name for our volume control.
    regsub -all {\.} $w {_} unpath
    set widgets(volctrltop) .__mc_vol$unpath
    set widgets(volctrlcan) $widgets(volctrltop).can
    
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
    proc ::${w} { command args }   \
      "eval ::moviecontroller::WidgetProc {$w} \$command \$args"
    
    # The actual drawing takes place from 'Configure' which calls
    # the 'Draw' procedure when necessary.
    eval Configure $widgets(this) [array get options]

    return $w
}

# ::moviecontroller::WidgetProc --
#
#       This implements the methods; only two: cget and configure.
#       
# Arguments:
#       w       the widget path.
#       command the actual command; cget or configure.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::moviecontroller::WidgetProc { w command args }  {
    
    variable widgetGlobals
    variable widgetOptions
    variable widgetCommands
    upvar ::moviecontroller::${w}::widgets widgets
    upvar ::moviecontroller::${w}::options options
    
    if {$widgetGlobals(debug) > 1}  {
	puts "::moviecontroller::WidgetProc w=$w, command=$command, args=$args"
    }
    
    # Error checking.
    if {[lsearch -exact $widgetCommands $command] == -1}  {
	error "unknown moviecontroller command: $command"
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
	play {
	    $widgets(canvas) raise tstop
	}
	stop {
	    $widgets(canvas) raise tplay
	}
    }
    return $result
}

# ::moviecontroller::Configure --
#
#       Implements the "configure" widget command (method). 
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::moviecontroller::Configure { w args }  {
    
    variable widgetGlobals
    variable widgetOptions
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::widgets widgets
    upvar ::moviecontroller::${w}::wlocals wlocals
    
    if {$widgetGlobals(debug) > 1}  {
	puts "::moviecontroller::Configure w=$w, args=$args"
    }
    
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
    set needsRedraw 0
    array set opts $args
    
    # If we have specified a snack sound object, always set percent at 0.
    # Perhaps this is not the best solution.
    
    if {[info exists opts(-snacksound)]} {
	set opts(-percent) 0
    }
    
    foreach opt [array names opts] {
	set newValue $opts($opt)
	if {[info exists options($opt)]}  {
	    set oldValue $options($opt)
	} else  {
	    set oldValue {}
	}
	set options($opt) $newValue
	if {$widgetGlobals(debug) > 1}  {
	    puts "::moviecontroller::Configure opt=$opt, n=$newValue, o=$oldValue"
	}
	
	# Some options need action from the widgets side.
	switch -- $opt {
	    -audio     {
		if {[winfo exists $widgets(canvas)] && \
			($newValue != $oldValue)}  {
		    set needsRedraw 1
		}
	    }
	    -width     {
		if {[winfo exists $widgets(canvas)]}  {
		    eval $widgets(frame) configure -width $newValue
		    eval $widgets(canvas) configure -width $newValue
		}
		set needsRedraw 1
	    }
	    -percent   {
		if {[winfo exists $widgets(canvas)]}  {
		    ConfigurePercent $w $newValue
		}
	    }
	    -snacksound {
		
		# Make bindings to a snack sound object.
		
		if {[string length $newValue] > 0}  {
		    ::moviecontroller::InitSnackSound $w $newValue
		}
	    }
	    -variable  {
		
		# Remove any remaining old traces.
		if {[info procs Trace($w)] != ""} {
		    uplevel 3 trace vdelete $oldValue wu   \
		      ::moviecontroller::Trace($w)
		}
		
		# First, need to define a trace procedure,
		# second, set the trace on the traced variable.
		
		if {[string length $newValue] > 0}  {
		    
		    proc ::moviecontroller::Trace($w) {name elem op}  { 
			
			# Tricky part: we need the widget path 'w' here.
			# Either use quotes instead of braces for the 
			# procedure body, or as here, parse [info level 0] 
			# to get 'w' via the procedure name.
			
			set procName [lindex [info level 0] 0]
			regexp {::moviecontroller::Trace\(([^ ]+)\)}  \
			  $procName match wMatch
			switch -- $op {
			    w   {
				if {$elem != ""} {
				    upvar 1 ${name}(${elem}) val
				    catch {ConfigurePercent $wMatch $val}
				} else  {
				    upvar 1 $name val
				    catch {ConfigurePercent $wMatch $val}
				}
			    }
			    u   {
				after idle "catch {rename Trace($wMatch) {}}"
			    }
			}
		    }
		    
		    # Install the actual trace to the procedure above.
		    # Check level by [info level] to get it right.
		    uplevel 3 trace variable $newValue wu   \
		      ::moviecontroller::Trace($w)
		    		    
		    # Need to find out the correct namespace for the variable.
		    # If beginning with :: it is already fully qualified so do 
		    # nothing.
		    
		    set varName $options(-variable)
		    if {![string match "::*" $varName]} {
			
			# Get caller's namespace; make sure we have absolute 
			# paths.
			set ns [uplevel 3 namespace current]
			if {$ns != "::"} {
			    append ns "::"
			}
			set varName "$ns$varName"
			#puts "level=[info level], ns=$ns, new varName=$varName"
			set wlocals(varFull) $varName
			
			# Initialize it or overwrite it.
			set $varName 0
		    }
		}
	    }
	}
    }
    
    # And finally...
    if {$needsRedraw}  {
	Draw $w
    }
    
    # The time period for scheduling updating the drag; exactly one pixel at
    # a time. 
    # Only for the snack sound binding. Necessary to do after 'Draw' since
    # we need the 'maxmin' value.
    if {[llength $options(-snacksound)] > 0}  {
	set wlocals(afterms) [expr int((1000. * $wlocals(lengthSecs))/ \
		$wlocals(maxmin))]
	if {$wlocals(afterms) < 500} {
	    set wlocals(afterms) 500
	}
    }
}

# ::moviecontroller::ConfigurePercent --
# 
#       This is a 'lite' version of Configure to set just the -percent option.
#       It should only be used internally as a shortcut to reduce overhead.
#
# Arguments:
#       w       the widget path.
#       per     the percentage value.
# Results:
#       none.

proc ::moviecontroller::ConfigurePercent  { w per }  {

    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::widgets widgets
    upvar ::moviecontroller::${w}::wlocals wlocals

    if {$per < 0} {
	set per 0
    } elseif {$per > 100} {
	set per 100
    }
    set options(-percent) $per
    set xmark [expr $wlocals(min) + $wlocals(maxmin) * $per/100.0]
    eval $widgets(canvas) coords tdrag $xmark 1
    eval $widgets(canvas) coords tdragpu $xmark 1

    # If we have a variable to set, set it.
    # This is like master and slave: the variable controls the slider,
    # and the slider controls the variable.
    if {[llength $options(-variable)] > 0}  {
	
	# Need to get the correct namespace for the variable. This is done
	# previously in 'Configure' and then kept in 'wlocals(varFull)'.

	set varName $wlocals(varFull)
	
	# It is important to temporarily switch off the trace before setting
	# the variable, and then add it again.
	
	set cmd ::moviecontroller::Trace($w)
	trace vdelete $varName wu $cmd
	set $varName $options(-percent)
	trace variable $varName wu $cmd
    }
}
		
# ::moviecontroller::Draw --
#
#       This is the actual drawing routine.
#       
# Arguments:
#       w       the widget path.
# Results:
#       none.

proc ::moviecontroller::Draw { w }  {

    variable widgetGlobals
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::widgets widgets
    upvar ::moviecontroller::${w}::wlocals wlocals

    if {$widgetGlobals(debug) > 1}  {
	puts "::moviecontroller::Draw w=$w"
    }
    set width $options(-width)
    set percent $options(-percent)
    
    if {$options(-audio)}  {
	set xplay [expr $widgetGlobals(w_vol) + 1]
    } else  {
	set xplay 1
    }
    set lmark [expr $xplay + $widgetGlobals(w_play)]
    set rmark [expr $width - ($widgetGlobals(w_rew) + $widgetGlobals(w_ff) + 1)]
    set xmark [expr $lmark + ($rmark - $lmark)*$percent/100.0]
    set wlocals(min) $lmark
    set wlocals(max) $rmark
    set wlocals(xmark) $xmark
    set wlocals(maxmin) [expr $wlocals(max) - $wlocals(min)]

    # ...and finally, the actual drawing. Only first time.
    if {![winfo exists $widgets(canvas)]}  {
	canvas $widgets(canvas) -width $width -height 16 -bd 0  \
	  -highlightthickness 0
	pack $widgets(canvas) -side left -fill both -anchor nw

	# Draw horizontal scale.
	foreach {type tag color coords} $widgetGlobals(todraw) {
	    eval $widgets(canvas) create $type $coords -tag $tag -fill $color
	}
	
	# Add all buttons as mime encoded gifs.
	foreach {type tag im coords anch} $widgetGlobals(drawimages) {
	    eval $widgets(canvas) create $type $coords -tag $tag -anchor $anch  \
	      -image $widgetGlobals($im)
	}
	set wlocals(plays) 0
	
	# We need bindings to the drag scale, to the volume button, play and stop
	# button, rewind and fast forward button.
	
	$widgets(canvas) bind tdrag <Button-1>  \
	  [list ::moviecontroller::DragInit $w %x]
	$widgets(canvas) bind tdrag <B1-Motion>  \
	  [list ::moviecontroller::Drag $w %x]
	$widgets(canvas) bind tdrag <ButtonRelease>  \
	  [list ::moviecontroller::DragRelease $w %x]
	$widgets(canvas) bind tplay <Button-1>  \
	  [list ::moviecontroller::PlayStop $w play 1]
	$widgets(canvas) bind tplay <ButtonRelease>  \
	  [list ::moviecontroller::PlayStop $w play 0]
	$widgets(canvas) bind tstop <Button-1>  \
	  [list ::moviecontroller::PlayStop $w stop 1]
	$widgets(canvas) bind tstop <ButtonRelease>  \
	  [list ::moviecontroller::PlayStop $w stop 0]
	$widgets(canvas) bind tvol <Button-1>  \
	  [list ::moviecontroller::Volume $w %y 1]
	$widgets(canvas) bind tvol <B1-Motion>  \
	  [list ::moviecontroller::VolDrag $w %y]
	$widgets(canvas) bind tvol <ButtonRelease>  \
	  [list ::moviecontroller::Volume $w %y 0]
	$widgets(canvas) bind tvoloff <Button-1>  \
	  [list ::moviecontroller::Volume $w %y 1]
	$widgets(canvas) bind tvoloff <B1-Motion>  \
	  [list ::moviecontroller::VolDrag $w %y]
	$widgets(canvas) bind tvoloff <ButtonRelease>  \
	  [list ::moviecontroller::Volume $w %y 0]
	$widgets(canvas) bind tvolfull <Button-1>  \
	  [list ::moviecontroller::Volume $w %y 1]
	$widgets(canvas) bind tvolfull <B1-Motion>  \
	  [list ::moviecontroller::VolDrag $w %y]
	$widgets(canvas) bind tvolfull <ButtonRelease>  \
	  [list ::moviecontroller::Volume $w %y 0]
	$widgets(canvas) bind trew <Button-1>  \
	  [list ::moviecontroller::RewFF $w rew 1]
	$widgets(canvas) bind trew <ButtonRelease>  \
	  [list ::moviecontroller::RewFF $w rew 0]
	$widgets(canvas) bind tff <Button-1>  \
	  [list ::moviecontroller::RewFF $w ff 1]
	$widgets(canvas) bind tff <ButtonRelease>  \
	  [list ::moviecontroller::RewFF $w ff 0]

	# It is also time to create our volume scale for the first time.
	DrawVolumeScale $w
    
    } else {

	# The widget is just configured. Only for the -width and
	# -audio options.
	
	foreach {type tag color coords} $widgetGlobals(todraw) {
	    eval $widgets(canvas) coords $tag $coords
	}
	foreach {type tag im coords anch} $widgetGlobals(drawimages) {
	    eval $widgets(canvas) coords $tag $coords
	}
    }
}

# ::moviecontroller::DrawVolumeScale --
#
#       Draws the vertical volume scale in a separate toplevel window.
#       Only needed once.
#
# Arguments:
#       w       the widget path.
# Results:
#       none.

proc ::moviecontroller::DrawVolumeScale { w }  {

    variable widgetGlobals
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::widgets widgets
    upvar ::moviecontroller::${w}::wlocals wlocals

    set volume $options(-volume)
    set ytop $widgetGlobals(hvol_top)
    set ybot [expr $widgetGlobals(vol_h) - $widgetGlobals(hvol_bot)]
     
    toplevel $widgets(volctrltop) -bg $widgetGlobals(vol_bg)
    wm overrideredirect $widgets(volctrltop) 1
    wm withdraw $widgets(volctrltop)
    pack [canvas $widgets(volctrlcan) -bd 0 -highlightthickness 0  \
      -bg $widgetGlobals(vol_bg) -width $widgetGlobals(vol_w)  \
      -height $widgetGlobals(vol_h)] -fill both
    
    # The loud speaker icon on the volume button is coded as:
    # 0: vol_off, 1: vol, 2: vol_full, in order to keep track of the present
    # icon to show.
    set wlocals(vol_icon) 1
    
    $widgets(volctrlcan) create image 0 0  \
      -image $widgetGlobals(qtmcvol_win) -anchor nw
    $widgets(volctrlcan) create image 1 [expr $widgetGlobals(vol_h)/2]  \
      -image $widgetGlobals(qtmcvol_drag) -tags tdrag -anchor w
    $widgets(volctrlcan) bind tdrag <B1-Motion>  \
      [list ::moviecontroller::VolDrag $w %x]
}

# ::moviecontroller::DragInit --
#
#       Invoked when the scale button is clicked. Sets the initial x 
#       coordinate.
# 
# Arguments:
#       w       the widget path.
#       x       the x coordinate of the mouse.
# Results:
#       none.

proc ::moviecontroller::DragInit { w x }  {

    variable widgetGlobals
    upvar ::moviecontroller::${w}::widgets widgets
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::wlocals wlocals

    if {$widgetGlobals(debug) > 1}  {
	puts "::moviecontroller::DragInit w=$w, x=$x"
    }
    
    # Toggle the button icons.
    $widgets(canvas) raise tdragpu

    # Keep track of the latest position of the mouse.
    set wlocals(anchor) $x
    
    # Save the x offset between the mouse and the center of the mark 
    # (a few pixels).
    set wlocals(xoff) [expr $x - $wlocals(xmark)]
    
    # If we've got a snack sound playing, cancel the scheduling of the drag
    # button.
    if {([llength $options(-snacksound)] > 0) && $wlocals(plays)} {
	catch {after cancel $wlocals(afterid)}
	$wlocals(sound) stop
    }
}

# ::moviecontroller::Drag --
#
#       Dragging the scale button. 
#    
# Arguments:
#       w       the widget path.
#       x       the x coordinate of the mouse.
# Results:
#       none.

proc ::moviecontroller::Drag { w x }  {

    upvar ::moviecontroller::${w}::widgets widgets
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::wlocals wlocals

    # Mouse moved by 'dx' without any min/max constraints.
    set xanch $wlocals(anchor)
    set dx [expr $x - $xanch]
    set wlocals(anchor) $x
    
    # The new mark position.
    set wlocals(xmark) [lindex [$widgets(canvas) coords tdrag] 0]
    set newxmark [expr $wlocals(xmark) + $dx]
    
    # Take care of the max/min values.
    
    if {$newxmark > $wlocals(max)}  {
	set dx [expr $wlocals(max) - $wlocals(xmark)]
	set wlocals(anchor) [expr $wlocals(max) + $wlocals(xoff)]
    } elseif {$newxmark < $wlocals(min)}  {
	set dx [expr $wlocals(min) - $wlocals(xmark)]
	set wlocals(anchor) [expr $wlocals(min) + $wlocals(xoff)]
    }
    
    # Move both the normal and the highlighted knob.
    $widgets(canvas) move tdrag $dx 0
    $widgets(canvas) move tdragpu $dx 0
    set options(-percent) [expr   \
      100.0 * ($wlocals(xmark) - $wlocals(min))/$wlocals(maxmin)]
    
    # Any command should be evaluated in the global namespace.   
    if {[llength $options(-command)] > 0} {
	uplevel #0 $options(-command) $w percent $options(-percent)
    }
    
    # If we have a variable to set, set it.
    # This is like master and slave: the variable controls the slider,
    # and the slider controls the variable.
    if {[llength $options(-variable)] > 0}  {
	
	# Need to get the correct namespace for the variable. This is done
	# previously in 'Configure' and then kept in 'wlocals(varFull)'.

	set varName $wlocals(varFull)
	
	# It is important to temporarily switch off the trace before setting
	# the variable, and then add it again.
	
	set cmd ::moviecontroller::Trace($w)
	trace vdelete $varName wu $cmd
	set $varName $options(-percent)
	trace variable $varName wu $cmd
    }
}

# ::moviecontroller::DragRelease --
#
#       Bindings when drag knob released.
#       
# Arguments:
#       w       the widget path.
#       x       the x coordinate (unused).
# Results:
#       none.

proc ::moviecontroller::DragRelease { w x }  {

    variable widgetGlobals
    upvar ::moviecontroller::${w}::widgets widgets
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::wlocals wlocals
    
    # Toggle the button icons.
    $widgets(canvas) raise tdrag
   
    if {[llength $options(-snacksound)] > 0} {
	if {$widgetGlobals(milliSecs)}  {
	    set wlocals(movieTime)  \
		    [expr $wlocals(lengthMilliSecs) * $options(-percent)/100.0]
	} else {
	    set wlocals(movieTime)  \
		    [expr $wlocals(lengthSecs) * $options(-percent)/100.0]
	}
	set wlocals(movieTimeStart) $wlocals(movieTime)
	
	# If playing start play from this point.
	if {$wlocals(plays)} {
	    $wlocals(sound) play -start  \
	      [expr int($wlocals(lengthSamp) * $options(-percent)/100.0)]  \
	      -command [list ::moviecontroller::SnackEnd $w $wlocals(sound)] 
	    if {$widgetGlobals(milliSecs)}  {
		set wlocals(startTime) [clock clicks -milliseconds]
	    } else {
		set wlocals(startTime) [clock seconds]
	    }

	    # Reschedule updating the drag.
	    set wlocals(afterid)   \
	      [after $wlocals(afterms) ::moviecontroller::PlayCallback $w]
	}
    }
}

    
# ::moviecontroller::PlayStop --
#
#       Toggle play/stop button and evals any command we have registered.
#       
# Arguments:
#       w       the widget path.
#       what    is "play" or "stop".
#       btDown  1 if button pressed, 0 when released.
# Results:
#       none.

proc ::moviecontroller::PlayStop  { w what btDown }  {

    variable widgetGlobals
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::widgets widgets
    upvar ::moviecontroller::${w}::wlocals wlocals

    if {$widgetGlobals(debug) > 1}  {
	puts "::moviecontroller::PlayStop w=$w, what=$what, btDown=$btDown"
    }
    if {[string equal $what "play"]}  {
	
	# Show stop button
	if {$btDown} {
	    $widgets(canvas) raise tplaypu
	} else {
	    $widgets(canvas) raise tstop
	}
	set wlocals(plays) 1
    } elseif {[string equal $what "stop"]}  {
	
	# Show play button.
	if {$btDown} {
	    $widgets(canvas) raise tstoppu
	} else {
	    $widgets(canvas) raise tplay
	}
	set wlocals(plays) 0
    }

    # If we have a snack sound, call the corresponding procedure.
    if {$btDown} {
	if {[llength $options(-snacksound)] > 0}  {
	    SnackCmd $w $options(-snacksound) $what 
	}
    }

    # It should be evaluated in the global namespace.
    set cmd $options(-command)
    if {[llength $cmd] > 0}  {
	uplevel #0 $cmd $w $what $btDown
    }
}

# ::moviecontroller::RewFF --
#
#       Rewind of fast forward; evaluates any command registered.
#       
# Arguments:
#       w       the widget path.
#       what    is "rew" or "ff".
#       btDown  1 if button pressed, 0 when released.
# Results:
#       none.

proc ::moviecontroller::RewFF  { w what btDown }  {

    variable widgetGlobals
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::widgets widgets

    if {$widgetGlobals(debug) > 1}  {
	puts "::moviecontroller::RewFF w=$w, what=$what, btDown=$btDown"
    }

    # Toggle the push button icons.
    if {[string equal $what "rew"]} {
	if {$btDown} {
	    $widgets(canvas) raise trewpu
	} else {
	    $widgets(canvas) raise trew
	    $widgets(canvas) raise tdrag
	}
    } else {
	if {$btDown} {
	    $widgets(canvas) raise tffpu
	} else {
	    $widgets(canvas) raise tff
	}
    }    
    
    # It should be evaluated in the global namespace.
    set cmd $options(-command)
    if {[llength $cmd] > 0}  {
	uplevel #0 $cmd $w $what $btDown
    }

    # If we have a snack sound, call the corresponding procedure.
    if {[llength $options(-snacksound)] > 0}  {
	SnackCmd $w $options(-snacksound) $what $btDown
    }
}

# ::moviecontroller::Volume --
#
#       Show or hide the volume control.
#       
# Arguments:
#       w       the widget path.
#       y       is the y coordinate local to the original mc widget.
#       show    1 if the volume button pressed, 0 when released.
# Results:
#       None.

proc ::moviecontroller::Volume  { w y show }  {
    
    variable widgetGlobals
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::widgets widgets
    upvar ::moviecontroller::${w}::wlocals wlocals

    set volume $options(-volume)

    if {$widgetGlobals(debug) > 1}  {
	puts "::moviecontroller::Volume w=$w, y=$y, show=$show"
    }
    
    # Show volume scale.
    if {$show}  {
		
	# Set volume icon to the pushed one.
	if {$wlocals(vol_icon) == 0} {
	    $widgets(canvas) raise tvoloffpu
	} elseif {$wlocals(vol_icon) == 1} {
	    $widgets(canvas) raise tvolpu
	} elseif {$wlocals(vol_icon) == 2} {
	    $widgets(canvas) raise tvolfullpu
	}

	# Position the scale so that the volume control is centralized.
	set yposlow [expr int($widgetGlobals(hvol_bot) +  \
	  $volume/100.0 * $widgetGlobals(hvol_scaleh))]
	
	# Keep track of the relative y position of the mc canvas and the
	# pop up volume canvas; necessary when dragging volume control.
	
	set wlocals(yvolrel) [expr $widgetGlobals(vol_h) - $yposlow - 7]
	set xnw [expr [winfo rootx $w] - 20]
	set ynw [expr [winfo rooty $w] - $wlocals(yvolrel)]
	wm geometry $widgets(volctrltop) +${xnw}+${ynw}
	wm deiconify $widgets(volctrltop)
	raise $widgets(volctrltop)

	# Set anchor point for the volume drag.
	set wlocals(volanch) $y	
    } else  {
	wm withdraw $widgets(volctrltop)
	
	# Reset volume icon to the non pushed one.
	if {$wlocals(vol_icon) == 0} {
	    $widgets(canvas) raise tvoloff
	} elseif {$wlocals(vol_icon) == 1} {
	    $widgets(canvas) raise tvol
	} elseif {$wlocals(vol_icon) == 2} {
	    $widgets(canvas) raise tvolfull
	}
    }
}

# ::moviecontroller::VolDrag --
#
#       Dragging the volume control button. Raises the loud speaker icon of
#       the volume button depending on present volume.
#    
# Arguments:
#       w       the widget path.
#       y       the y coordinate of the mouse relative the original mc canvas.
# Results:
#       none.

proc ::moviecontroller::VolDrag  { w y }  {

    variable widgetGlobals
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::widgets widgets
    upvar ::moviecontroller::${w}::wlocals wlocals

    # Mouse moved by 'dy'.
    set yanch $wlocals(volanch)
    set dy [expr $y - $yanch]

    # Set new anchor point for the volume drag.
    set wlocals(volanch) $y
    
    # Get actual position of the volume drag button.
    set ypos [lindex [$widgets(volctrlcan) coords tdrag] 1]
    set ybot [expr $widgetGlobals(hvol_top) + $widgetGlobals(hvol_scaleh)]
    set newymark [expr $ypos + $dy]

    # Impose min and max constraints. Note: y-axis upside down.
    # It is necessary to translate anchor point to mc canvas coords.
    
    if {$newymark < $widgetGlobals(hvol_top)}  {
	set dy [expr $widgetGlobals(hvol_top) - $ypos]
	set wlocals(volanch) \
	  [expr $widgetGlobals(hvol_top) - $wlocals(yvolrel)]
    } elseif {$newymark > $ybot}  {
	set dy [expr $ybot - $ypos]
	set wlocals(volanch) [expr $ybot - $wlocals(yvolrel)]
    }
    $widgets(volctrlcan) move tdrag 0 $dy    
    
    # Check to see if volume icon needs to be raised to indicate the present
    # volume setting.
    
    set yvol_off [expr $widgetGlobals(hvol_off) - $wlocals(yvolrel)]
    set yvol_full [expr $widgetGlobals(hvol_full) - $wlocals(yvolrel)]
    if {($y > $yvol_off) && ($wlocals(vol_icon) != 0)} {
	$widgets(canvas) raise tvoloffpu
	set wlocals(vol_icon) 0
    } elseif {($y < $yvol_full) && ($wlocals(vol_icon) != 2)} {
	$widgets(canvas) raise tvolfullpu
	set wlocals(vol_icon) 2
    } elseif {($y < $yvol_off) && ($y > $yvol_full) &&  \
      ($wlocals(vol_icon) != 1)} {
	$widgets(canvas) raise tvolpu
	set wlocals(vol_icon) 1
    }
    
    # Set the actual volume option variable.
    set options(-volume)   \
      [expr 100.0 * ($ybot - $ypos)/$widgetGlobals(hvol_scaleh)]
    
    # Any command should be evaluated in the global namespace.   
    if {[llength $options(-command)] > 0} {
	uplevel #0 $options(-command) $w volume $options(-volume)
    }

    # If we have a snack sound, call the corresponding procedure.
    if {[llength $options(-snacksound)] > 0}  {
	SnackCmd $w $options(-snacksound) volume $options(-volume)
    }
}

# ::moviecontroller::PlayCallback --
# 
#       Scheduled callback to update the drag knob etc when playing.
#    
# Arguments:
#       w       the widget path.
# Results:
#       none.

proc ::moviecontroller::PlayCallback  { w }  {

    variable widgetGlobals
    upvar ::moviecontroller::${w}::wlocals wlocals

    # The best would be to query the actual playtime here from snack,
    # or whatever we are binding to...
    
    # From 'wlocals(startTime)' find out how long we have been running,
    # and find the percentage from that.
    
    if {$widgetGlobals(milliSecs)}  {
	set runTime [expr [clock clicks -milliseconds] - $wlocals(startTime)]
	set wlocals(movieTime) [expr $wlocals(movieTimeStart) + $runTime]
	set percentage [expr (100.0 * $wlocals(movieTime))/  \
		$wlocals(lengthMilliSecs)]
    } else {
	set runTime [expr [clock seconds] - $wlocals(startTime)]
	set wlocals(movieTime) [expr $wlocals(movieTimeStart) + $runTime]
	set percentage [expr (100.0 * $wlocals(movieTime))/$wlocals(lengthSecs)]
    }
    ConfigurePercent $w $percentage
    
    # Reschedule updating the drag.
    set wlocals(afterid)   \
      [after $wlocals(afterms) ::moviecontroller::PlayCallback $w]

}

# ::moviecontroller::FFRewCallback --
#
#       Scheduled callback to update the drag knob etc when FF or Rew.
#    
# Arguments:
#       w       the widget path.
#       direction  -1 if rew and +1 if ff.
# Results:
#       none.

proc ::moviecontroller::FFRewCallback  { w direction }  {
    
    variable widgetGlobals
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::wlocals wlocals
 
    # Find new percentage.
    set percentage [expr $options(-percent) +  \
      $direction * $wlocals(ffrewSpeed) * $wlocals(ffrewAfterms)/1000.0]
    if {$percentage < 0} {
	set percentage 0
    } elseif {$percentage > 100} {
	set percentage 100
    }
    ConfigurePercent $w $percentage
    if {$widgetGlobals(milliSecs)}  {
	set wlocals(movieTime) [expr $wlocals(lengthMilliSecs) * $percentage/100.0]
    } else {
	set wlocals(movieTime) [expr $wlocals(lengthSecs) * $percentage/100.0]
    }

    # Reschedule updating the drag.
    set wlocals(ffrewAfterid) [after $wlocals(ffrewAfterms)   \
      ::moviecontroller::FFRewCallback $w $direction]
}

# ::moviecontroller::InitSnackSound --
#
#       Inits binding for a sound object from the snack extension.
#    
# Arguments:
#       w       the widget path.
#       snd     the snack sound object.
# Results:
#       none.

proc ::moviecontroller::InitSnackSound  { w snd }  {
    
    upvar ::moviecontroller::${w}::wlocals wlocals
    
    # Check first that we've got the snack package.
    if {[catch {package present snack}]} {
	if {[catch {package present sound}]} {
	    error "we need the snack package to make bindings to it"
	}
    }
    
    # Perhaps we should also check that the sound object really exists.
    # We should also collect some useful stuff for this specific sound object.
    
    set wlocals(lengthSecs) [$snd length -units seconds]
    set wlocals(lengthSamp) [$snd length]
    set wlocals(lengthMilliSecs) [expr (1000.0 * $wlocals(lengthSamp))/  \
	    [$snd cget -frequency]]
    set wlocals(sampPerSec) [expr $wlocals(lengthSamp)/$wlocals(lengthSecs)]
    set wlocals(movieTime) 0
    set wlocals(movieTimeStart) 0
    
    # FF and Rew speed as percentage per second.
    set wlocals(ffrewSpeed) 10
    set wlocals(ffrewAfterms) 300
    
    # Relate the widget path to the sound object.
    set wlocals(sound) $snd
    
    # The time period for scheduling updating the drag; roughly one pixel at
    # a time.
    set wlocals(afterms) [expr int(1000 * $wlocals(lengthSecs)/120.)]
    if {$wlocals(afterms) < 500} {
	set wlocals(afterms) 500
    }
    
}

# ::moviecontroller::SnackCmd --
#
#       Should be called whenever we want snack to do something.
#       It is important for the sync between the movie's time
#       and the percentage that the movie time determine the percentage.
#    
# Arguments:
#       w       the widget path.
#       snd     the snack sound object.
#       args    the cmd such as play, stop, volume, etc.
# Results:
#       none.

proc ::moviecontroller::SnackCmd  { w snd args }  {
    
    upvar ::moviecontroller::${w}::options options
    upvar ::moviecontroller::${w}::wlocals wlocals
    variable widgetGlobals

    if {$widgetGlobals(debug) > 1}  {
	puts "::moviecontroller::SnackCmd  w=$w, snd=$snd, args=$args"
    }
    set cmd [lindex $args 0]
    switch -exact -- $cmd  {
	play  {
	    
	    # If already have reached the end (100%) then start from the 
	    # beginning.
	    
	    if {$options(-percent) > 99.9} {
		ConfigurePercent $w 0
		set wlocals(movieTime) 0
		set wlocals(movieTimeStart) $wlocals(movieTime)
	    }
	    
	    # Schedule updating the drag.
	    set wlocals(afterid)   \
	      [after $wlocals(afterms) ::moviecontroller::PlayCallback $w]
	    if {$widgetGlobals(milliSecs)}  {
		set wlocals(startTime) [clock clicks -milliseconds]
	    } else {
		set wlocals(startTime) [clock seconds]
	    }
	    set wlocals(movieTimeStart) $wlocals(movieTime)
	    $snd play -command [list ::moviecontroller::SnackEnd $w $snd]  \
	      -start [expr int($wlocals(lengthSamp) * $options(-percent)/100.0)]
	}
	stop  {
	    $snd stop
	    catch {after cancel $wlocals(afterid)}

	    if {$widgetGlobals(milliSecs)}  {
		set wlocals(movieTime) [expr $wlocals(movieTimeStart) +  \
			[clock clicks -milliseconds] - $wlocals(startTime)]
	    } else {
		set wlocals(movieTime) [expr $wlocals(movieTimeStart) +  \
			[clock seconds] - $wlocals(startTime)]
	    }

	    # Need to find the exact percentage and configure percent with it.
	    if {$widgetGlobals(milliSecs)}  {
		set percent [expr (100.0 * $wlocals(movieTime))/  \
			$wlocals(lengthMilliSecs)]
	    } else {
		set percent [expr (100.0 * $wlocals(movieTime))/  \
			$wlocals(lengthSecs)]
	    }
	    ConfigurePercent $w $percent
	}
	volume  {
	    set theVol [lindex $args 1]
	    
	    # How to set the sound volume?
	    # only a test...
	    snack::audio play_gain [expr int($theVol)]
	}
	rew          -
	ff           {
	    set btDown [lindex $args 1]
	    switch -exact -- $cmd  {
		rew  {set direction -1}
		ff   {set direction  1}
	    }
	    if {$btDown == 1} {
		
		# Button pressed. If running then stop temporarily.
		# Cancel the scheduling of the drag button.
		
		if {$wlocals(plays)} {
		    catch {after cancel $wlocals(afterid)}
		    $snd stop
		}
		set wlocals(ffrewAfterid) [after $wlocals(ffrewAfterms)   \
		  ::moviecontroller::FFRewCallback $w $direction]
		
	    } else {

		if {$widgetGlobals(milliSecs)}  {
		    set wlocals(startTime) [clock clicks -milliseconds]
		} else {
		    set wlocals(startTime) [clock seconds]
		}
		set wlocals(movieTimeStart) $wlocals(movieTime)
		
		# Button released. If running then start again.
		if {$wlocals(plays)} {
		    $snd play -command  \
		      [list ::moviecontroller::SnackEnd $w $snd]  \
		      -start [expr int($wlocals(lengthSamp) *   \
		      $options(-percent)/100.0)]
	    
		    # Reschedule updating the drag.
		    set wlocals(afterid)   \
		      [after $wlocals(afterms) ::moviecontroller::PlayCallback $w]
		}
		catch {after cancel $wlocals(ffrewAfterid)}
	    }
	}
    }
}

# ::moviecontroller::SnackEnd --
# 
#       Command from snack when sound has come to an end.
#       Fix up a few things.
#    
# Arguments:
#       w       the widget path.
#       snd     the snack sound object.
# Results:
#       none.

proc ::moviecontroller::SnackEnd  { w snd }  {
    
    upvar ::moviecontroller::${w}::wlocals wlocals

    catch {after cancel $wlocals(afterid)}
    ConfigurePercent $w 100
    ::moviecontroller::PlayStop $w stop 0
}

proc ::moviecontroller::DestroyHandler {w} {

    upvar ::moviecontroller::${w}::wlocals wlocals
 
    catch {after cancel $wlocals(afterid)}
    catch {after cancel $wlocals(ffrewAfterid)}
     
    # Remove the namespace with the widget.
    namespace delete ::moviecontroller::${w}
}

#-------------------------------------------------------------------------------