#  canvasex.tcl ---
#  
#      Extends the original canvas widget in a transparent way.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  This source file is distributed under the BSD license.
#  
# $Id: canvasex.tcl,v 1.6 2006-08-03 07:00:25 matben Exp $
# 
# ########################### USAGE ############################################
#
#   NAME
#      canvasex - an extended canvas widget
#      
#   SYNOPSIS
#      canvasex widgetPath ?options?
#
#      
#   COMMANDS
#      widgetPath group itemOrTag ?itemOrTag ...?
#      
#
# ########################### CHANGES ##########################################

namespace eval ::canvasex:: {

    namespace export canvasex
    
    variable groupRE {^group(:[0-9]+)+$}
}

# ::canvasex::canvasex --
# 
#       Creates a new canvasex widget.

proc ::canvasex::canvasex {w args} {
    
    # Instance specific namespace
    namespace eval ::canvasex::${w} {
	variable priv
    }
    
    # Set simpler variable names.
    upvar ::canvasex::${w}::priv priv
    
    set priv(guid) 0
    set priv(canvas) ::canvasex::${w}::${w}
    eval {canvas $w} $args
    
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $priv(canvas)
    
    # Create the actual widget procedure.
    proc ::${w} {command args}   \
      "eval ::canvasex::WidgetProc {$w} \$command \$args"
    
    return $w
}

# ::canvasex::WidgetProc --
# 
#       Coomand procedure. Calls through to ordinary canvas if not an
#       added command or feature.

proc ::canvasex::WidgetProc {w command args}  {
    upvar ::canvasex::${w}::priv priv
    
    # Any 'current' must be checked for a group id! Replace if exists.
    set ind [lsearch -exact $args current]
    set switchInd [lsearch -regexp $args {-[a-z]+}]
    if {$switchInd == -1} {
	set switchInd $ind
    }
    if {$ind < $switchInd} {
	set gid [lsearch -inline -regexp [$w gettags current] {^group#[0-9]+$}]
	if {$gid != ""} {
	    lset args $ind $gid
	}
    }
    
    switch -- $command {
	coords {
	    set ans [eval {::canvasex::Coords $w} $args]
	}
	create {
	    set ans [eval {::canvasex::Create $w} $args]
	}
	getgroups {
	    set ans [eval {::canvasex::GetGroups $w} $args]
	}
	group {
	    set ans [eval {::canvasex::Group $w} $args]
	}
	type {
	    set ans [eval {::canvasex::Type $w} $args]
	}
	ungroup {
	    set ans [eval {::canvasex::Ungroup $w} $args]
	}
	default {
	    set ans [eval {$priv(canvas) $command} $args]
	}
    }
    return $ans
}

# ::canvasex::Coords --
# 
#       

proc ::canvasex::Coords {w args} {
    upvar ::canvasex::${w}::priv priv
    upvar ::canvasex::${w}::cache cache

    set wcan $priv(canvas)
    set tagOrId [lindex $args 0]
    if {[regexp {^[0-9]+$} $tagOrId]} {
	set id $tagOrId
    } else {
	set id [lindex [$wcan find withtag $tagOrId] 0]
    }
    set ans [eval {$wcan coords} $args]
    return $ans
}

# ::canvasex::Create --
# 
#       The 'canvasPath create' command. Need to catch added options and
#       commands.

proc ::canvasex::Create {w args} {
    upvar ::canvasex::${w}::priv priv
    
    set wcan $priv(canvas)
    set ind [lsearch -exact $args "-group"]
    if {$ind >= 0} {
	set gid [lindex $args [expr $ind + 1]]
	set args [lreplace $args $ind [expr $ind + 1]]
    }
    
    switch -- [lindex $args 0] {
	default {
	    set id [eval {$wcan create} $args]
	}
    }
    if {$ind >= 0} {
	::canvasex::AddGroupTag $w $id $gid
    }
    return $id
}

# Group ------------------------------------------------------------------------

proc ::canvasex::GetGroups {w args} {
    variable groupRE
    upvar ::canvasex::${w}::priv priv

    set wcan $priv(canvas)
    set all {}
    foreach id [$wcan find all] {
	set gid [lsearch -inline -regexp [$w gettags $id] $groupRE]
	if {$gid != ""} {
	    lappend all $gid
	}
    }
    return [lsort -unique $all]
}

proc ::canvasex::Group {w args} {
    variable groupRE
    upvar ::canvasex::${w}::priv priv

    incr priv(guid)
    set guid $priv(guid)
    set wcan $priv(canvas)
    
    # We must be very careful not to create any nested groups.
    # Only hierarchies are acceptable.
    foreach id $args {
	set gid [lsearch -inline -regexp [$w gettags $id] $groupRE]
	if {$gid != ""} {
	    if {![string equal $id $gid]} {
		return -code error "trying to group nested item $id"
	    }
	}
    }
    
    foreach id $args {
	::canvasex::AddGroupTag $w $id $gid
    }
    return group#${gid}
}

proc ::canvasex::Ungroup {w gid} {
    upvar ::canvasex::${w}::priv priv

    set wcan $priv(canvas)
    foreach id [$wcan find withtag $gid] {
	::canvasex::DeleteGroupTag $w $id $gid
    }
    return ""
}

proc ::canvasex::Type {w args} {
    variable groupRE
    upvar ::canvasex::${w}::priv priv
    upvar ::canvasex::${w}::cache cache

    if {[llength $args] != 1} {
	return -code error "Wrong number of arguments"
    }
    set wcan $priv(canvas)
    set tagOrId [lindex $args 0]
    if {[regexp {^[0-9]+$} $tagOrId]} {
	set id $tagOrId
    } else {
	set id [lindex [$wcan find withtag $tagOrId] 0]
    }
    
    # If any group return 'group'.
    if {[lsearch -regexp [$wcan gettags $args] $groupRE]} {
	return group
    } else {
	if {[info exists cache($id,type)]} {
	    return $cache($id,type)
	} else {
	    return [$wcan type $args]
	}
    }
}

# ::canvasex::AddGroupTag, DeleteGroupTag --
# 
#       Adds or removes a group tag respecitvely. Internal use only.

proc ::canvasex::AddGroupTag {w id gid} {
    variable groupRE
    upvar ::canvasex::${w}::priv priv
    
    set wcan $priv(canvas)
    set tags [$wcan gettags $id]
    set gtag [lsearch -inline -regexp $tags $groupRE]
    if {$gtag == ""} {
	$wcan addtag "group#${gid}" withtag $id
    } else {
	$wcan dtag $id $gtag
	$wcan addtag "${gtag}#${gid}" withtag $id
    }
}

proc ::canvasex::DeleteGroupTag {w id gid} {
    variable groupRE
    upvar ::canvasex::${w}::priv priv
    
    set wcan $priv(canvas)
    set tags [$wcan gettags $id]
    set gtag [lsearch -inline -regexp $tags $groupRE]
    if {$gtag != ""} {
	if {[regexp {group(#[0-9]+)*#${gid}$} $gtag match gtagsub]} {
	    $wcan dtag $id $gtag
	    if {![string equal $gtagsub "group"]} {
		$wcan addtag $gtagsub withtag $id
	    }
	} else {
	    return -code error  \
	      "the group tag \"$gid\" is nested: $gtag"
	}
    }
    return ""
}

proc ::canvasex::GetGroupTag {w id} {
    variable groupRE
    upvar ::canvasex::${w}::priv priv
    
    set tags [$priv(canvas) gettags $id]
    return [lsearch -inline -regexp $tags $groupRE]
}

#-------------------------------------------------------------------------------
