# canvasx.tcl --
# 
#       Extended canvas. 
#       @@@ first sketch!
# 
# Copyright (c) 2005 Mats Bengtsson
#       
# $Id: canvasex.tcl,v 1.1 2005-09-19 06:37:20 matben Exp $

package require snit 1.0
package require tile
package require msgcat
package require ui::util

package provide ui::canvasex 0.1

interp alias {} ui::canvasex {} ui::canvasex::widget

# ui::canvasex --
# 
#       Extended canvas widget.

snit::widgetadaptor ui::canvasex::widget {

    delegate option * to hull
    delegate method * to hull except {group ungroup getgroups}
    
    typevariable groupRE {^group(:[0-9]+)+$}

    variable guid 0
    variable group

    constructor {args} {
	$self configurelist $args
	installhull using canvas

	
	return
    }
    
    # Private methods:
    
    method AddGroupTag {id gid} {
	set tags [$win gettags $id]
	set gtag [lsearch -inline -regexp $tags $groupRE]
	if {[llength $gtag]} {
	    $win dtag $id $gtag
	    $win addtag ${gtag}:${gid} withtag $id
	} else {
	    $win addtag group:${gid} withtag $id
	}
	lappend group($gid) $id
    }
    
    method RemoveGroupTag {id gid} {
	
    }
    
    # Public methods:

    method group {args} {	
	set gid [incr guid]
	
	# We must be very careful not to create any nested groups.
	# Thus, if an item already has a group tag we can never use its
	# ordinary item id when grouping.
	foreach id $args {
	    set gtag [lsearch -inline -regexp [$win gettags $id] $groupRE]
	    if {[llength $gtag]} {
		if {![string equal $id $gid]} {
		    incr guid -1
		    return -code error "trying to group nested item $id"
		}
	    }
	}
	foreach id $args {
	    $self AddGroupTag $id $gid
	}
	return $gid
    }
    
    method ungroup {gid} {
	
    }
	
    method getgroups {} {
	
    }

}

#-------------------------------------------------------------------------------
