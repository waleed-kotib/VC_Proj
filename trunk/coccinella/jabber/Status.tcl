#  Status.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements various UI parts for setting status (presence).
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Status.tcl,v 1.3 2005-02-02 09:02:22 matben Exp $

package provide Status 1.0

namespace eval ::Jabber::Status:: {

    
    # Mappings from <show> element to displayable text and vice versa.
    # chat away xa dnd
    variable mapShowElemToText
    variable mapShowTextToElem
    
    array set mapShowElemToText [list \
      [mc mAvailable]       available  \
      [mc mAway]            away       \
      [mc mChat]            chat       \
      [mc mDoNotDisturb]    dnd        \
      [mc mExtendedAway]    xa         \
      [mc mInvisible]       invisible  \
      [mc mNotAvailable]    unavailable]
    array set mapShowTextToElem [list \
      available       [mc mAvailable]     \
      away            [mc mAway]          \
      chat            [mc mChat]          \
      dnd             [mc mDoNotDisturb]  \
      xa              [mc mExtendedAway]  \
      invisible       [mc mInvisible]     \
      unavailable     [mc mNotAvailable]]

    variable mapShowMLabelToText
    variable mapShowTextToMLabel
    
    array set mapShowMLabelToText {
	mAvailable        available
	mAway             away
	mChat             chat
	mDoNotDisturb     dnd
	mExtendedAway     xa
	mInvisible        invisible
	mNotAvailable     unavailable
    }
    array set mapShowTextToMLabel {
	available       mAvailable
	away            mAway
	chat            mChat
	dnd             mDoNotDisturb
	xa              mExtendedAway
	invisible       mInvisible
	unavailable     mNotAvailable
    }

}

proc ::Jabber::Status::Widget {w style varName args} {
    
    switch -- $style {
	button {
	    eval {Button $w $varName} $args
	}
	label {
	    eval {Label $w $varName} $args
	}
	menubutton {
	    eval {MenuButton $w $varName} $args
	}
    }
    return $w
}

proc ::Jabber::Status::Configure {w status} {
    
    switch -- [winfo class $w] {
	Button {
	    ConfigButton $w $status
	}
	Label {
	    ConfigLabel $w $status
	}
	MenuButton {
	    # empty
	}
    }
}

# ::Jabber::Status::Button --
# 
#       A few functions to build a megawidget status menu button.
#       
# Arguments:
#       w
#       varName
#       args:     -command procName
#       
# Results:
#       widget path.

proc ::Jabber::Status::Button {w varName args} {
    upvar $varName status
    
    set argsArr(-command) {}
    array set argsArr $args

    set wmenu $w.menu
    button $w -bd 1 -image [::Rosticons::Get status/$status] \
      -width 16 -height 16
    ConfigButton $w $status
    menu $wmenu -tearoff 0
    BuildGenPresenceMenu $wmenu -variable $varName -command  \
      [list [namespace current]::ButtonCmd $w $varName $argsArr(-command)]
    return $w
}

proc ::Jabber::Status::ButtonCmd {w varName cmd} {
    upvar $varName status
	
    ConfigButton $w $status
    if {$cmd != {}} {
	uplevel #0 $cmd $status
    }
}

proc ::Jabber::Status::ConfigButton {w status} {
    
    $w configure -image [::Rosticons::Get status/$status]
    if {[string equal $status "unavailable"]} {
	$w configure -state disabled
	bind $w <Button-1> {}
    } else {
	$w configure -state normal
	bind $w <Button-1> \
	  [list [namespace current]::PostMenu $w.menu %X %Y]
    }
}

proc ::Jabber::Status::PostMenu {wmenu x y} {
    
    tk_popup $wmenu [expr int($x)] [expr int($y)]
}

# Jabber::Status::MenuButton --
# 
#       Makes a menubutton for status that does no action. It only sets
#       the varName.

proc ::Jabber::Status::MenuButton {w varName args} {
    upvar $varName status
    variable mapShowTextToElem

    menubutton $w -indicatoron 1 -menu $w.menu  \
      -relief raised -bd 2 -highlightthickness 2 -anchor c -direction flush
    menu $w.menu -tearoff 0
    BuildGenPresenceMenu $w.menu -variable $varName  \
      -command [list [namespace current]::MenuButtonCmd $w $varName]
    $w configure -text $mapShowTextToElem($status)
    return $w
}

proc ::Jabber::Status::MenuButtonCmd {w varName} {
    upvar $varName status
    variable mapShowTextToElem
    
    $w configure -text $mapShowTextToElem($status)
}

# ::Jabber::Status::Label --
# 
#       A few functions to build a megawidget status menu button.
#       
# Arguments:
#       w
#       varName
#       args:     -command procName + label options
#       
# Results:
#       widget path.

proc ::Jabber::Status::Label {w varName args} {
    upvar $varName status
    
    set argsArr(-command) {}
    array set argsArr $args
    set cmd $argsArr(-command)
    unset argsArr(-command)

    eval {label $w} [array get argsArr]
    ConfigLabel $w $status
    set wmenu $w.menu
    menu $wmenu -tearoff 0
    BuildGenPresenceMenu $wmenu -variable $varName -command  \
      [list [namespace current]::LabelCmd $w $varName $cmd]
    return $w
}

proc ::Jabber::Status::LabelCmd {w varName cmd} {
    upvar $varName status
	
    ConfigLabel $w $status
    if {$cmd != {}} {
	uplevel #0 $cmd $status
    }
}

proc ::Jabber::Status::ConfigLabel {w status} {
    variable mapShowTextToElem
    
    $w configure -text "$mapShowTextToElem($status) "
    
    #$w configure -image [::Rosticons::Get status/$type]
    if {[string equal $status "unavailable"]} {
	#$w configure -state disabled
	bind $w <Button-1> {}
    } else {
	$w configure -state normal
	bind $w <Button-1> \
	  [list [namespace current]::PostMenu $w.menu %X %Y]
    }
}

# Jabber::Status::BuildMenu --
# 
#       Adds all presence menu entries to menu.
#       
# Arguments:
#       mt          menu widget
#       
# Results:
#       none.

proc ::Jabber::Status::BuildMenu {mt} {

    set varName ::Jabber::jstate(status)
    BuildGenPresenceMenu $mt -variable $varName \
      -command [list [namespace current]::MenuCmd $varName]      
}

proc ::Jabber::Status::MenuCmd {varName} {
    upvar $varName status
    
    ::Jabber::SetStatus $status
}

# Jabber::Status::BuildGenPresenceMenu --
# 
#       As above but a more general form.

proc ::Jabber::Status::BuildGenPresenceMenu {mt args} {
    global  this
    variable mapShowTextToElem
    
    set entries {available {} away chat dnd xa invisible {} unavailable}

    foreach name $entries {
	if {$name == {}} {
	    $mt add separator
	} else {
	    set opts {}
	    if {![string match "mac*" $this(platform)]} {
		set opts [list -compound left \
		  -image [::Rosticons::Get status/$name]]
	    }
	    eval {
		$mt add radio -label $mapShowTextToElem($name) -value $name
	    } $args $opts
	}
    }
    $mt add separator
    $mt add command -label [mc mAttachMessage] \
      -command ::Jabber::SetStatusWithMessage
}

# Jabber::Status::BuildStatusMenuDef --
# 
#       Builds a menuDef list for the status menu.
#       
# Arguments:
#       
# Results:
#       menuDef list.

proc ::Jabber::Status::BuildStatusMenuDef { } {
    global  this
    variable mapShowTextToElem
    variable mapShowTextToMLabel
    
    set entries {available {} away chat dnd xa invisible {} unavailable}
    set statMenuDef {}

    foreach name $entries {
	if {$name == {}} {
	    lappend statMenuDef {separator}
	} else {
	    set mName $mapShowTextToMLabel($name)
	    if {[string match "mac*" $this(platform)]} {
		lappend statMenuDef [list radio $mName  \
		  [list ::Jabber::SetStatus $name] normal {}  \
		  [list -variable ::Jabber::jstate(status) -value $name]]
	    } else {
		lappend statMenuDef [list radio $mName  \
		  [list ::Jabber::SetStatus $name] normal {}  \
		  [list -variable ::Jabber::jstate(status) -value $name  \
		  -compound left -image [::Rosticons::Get status/$name]]]
	    }
	}
    }
    lappend statMenuDef {separator}  \
      {command mAttachMessage {::Jabber::SetStatusWithMessage}  normal {}}
    
    return $statMenuDef
}

#-------------------------------------------------------------------------------
