#  headlabel.tcl ---
#  
#      This file is just a wrapper for the label widget.
#      Needed to make a separate widget since theming is easier.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  This source file is distributed under the BSD licens.
#  
# $Id: headlabel.tcl,v 1.5 2004-09-13 09:05:18 matben Exp $
#

package provide headlabel 0.1

namespace eval ::headlabel:: {

    # The public interface.
    namespace export headlabel
    
    option add *HeadLabel.font          {Helvetica -18}     widgetDefault
    option add *HeadLabel.anchor        w                   widgetDefault
    option add *HeadLabel.background    #cecece             widgetDefault
    option add *HeadLabel.padX          10                  widgetDefault
    option add *HeadLabel.padY          4                   widgetDefault
                                        
    variable widgetOptions
    array set widgetOptions {
	-anchor     {anchor          Anchor}
	-font       {font            Font}
	-background {background      Background}
	-padx       {padX            Pad}
	-pady       {padY            Pad}
    }
}

# ::headlabel::headlabel --
#
#       Creates a headlabel widget
#       
# Arguments:
#       w           widget path
#       args        options for the label widget
#       
# Results:
#       Widget path

proc ::headlabel::headlabel {w args} {
    variable widgetOptions
    
    frame $w -class HeadLabel
    
    # Replace label defaults with our own.
    foreach name [array names widgetOptions] {
	set optName [lindex $widgetOptions($name) 0]
	set optClass [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
    }
    if {[llength $args] > 0}  {
	array set options $args
    }
    
    eval {label $w.l} [array get options]
    pack $w.l -fill both -expand 1
    return $w
}

#-------------------------------------------------------------------------------
