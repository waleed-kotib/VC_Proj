#  mylabelframe.tcl ---
#  
#      Implements a frame with label.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
# $Id: mylabelframe.tcl,v 1.1 2003-12-16 08:22:03 matben Exp $
#

package provide mylabelframe 0.1

namespace eval ::mylabelframe:: {

    # The public interface.
    namespace export mylabelframe
    
    option add *MyLabelFrame.Font          system
    option add *MyLabelFrame.padX          10
    option add *MyLabelFrame.padY          4
					
    variable widgetOptions
    array set widgetOptions {
	-font       {font            Font}
	-padx       {padX            Pad}
	-pady       {padY            Pad}
    }
}

# ::mylabelframe::mylabelframe --
#
#       A small utility that makes a nice frame with a label.
#       The return value is the widget path to the interior of the container.
#       
# Arguments:
#       w           widget path
#       args        options for the label widget
#       
# Results:
#       widget path of contained frame!

proc ::mylabelframe::mylabelframe {w str args} {
    variable widgetOptions
        
    frame $w -borderwidth 0 -class MyLabelFrame

    # Replace label defaults with our own.
    foreach name [array names widgetOptions] {
	set optName [lindex $widgetOptions($name) 0]
	set optClass [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
    }
    if {[llength $args] > 0}  {
	array set options $args
    }
    
    pack [frame $w.pad] -side top
    pack [frame $w.cont -relief groove -bd 2] -side top -fill both -expand 1
    place [label $w.l -text $str -font $options(-font) -bd 0 -padx 4]  \
      -x 16 -y 0 -anchor nw
    set h [winfo reqheight $w.l]
    $w.pad configure -height [expr $h-4]
    return $w.cont
}

#-------------------------------------------------------------------------------
