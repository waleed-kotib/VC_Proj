#  Status.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements various UI parts for setting status (presence).
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Status.tcl,v 1.8 2005-11-16 13:30:15 matben Exp $

package provide Status 1.0

namespace eval ::Jabber::Status:: {

    ::hooks::register rosterIconsChangedHook    ::Jabber::Status::RosticonsHook
    
    # Mappings from <show> element to displayable text and vice versa.
    # chat away xa dnd
    variable mapShowTextToElem
    variable mapShowElemToText
    
    array set mapShowTextToElem [list \
      [mc mAvailable]       available  \
      [mc mAway]            away       \
      [mc mChat]            chat       \
      [mc mDoNotDisturb]    dnd        \
      [mc mExtendedAway]    xa         \
      [mc mInvisible]       invisible  \
      [mc mNotAvailable]    unavailable]
    array set mapShowElemToText [list \
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

proc ::Jabber::Status::GetStatusTextArray { } {
    variable mapShowElemToText
    
    return [array get mapShowElemToText]
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
	TButton {
	    ConfigButton $w $status
	}
	TLabel {
	    ConfigLabel $w $status
	}
	TMenubutton {
	    ConfigButton $w $status
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
    variable menuBuild
        
    set argsArr(-command) {}
    array set argsArr $args

    set wmenu $w.menu
    ttk::menubutton $w -style Toolbutton \
      -compound image -image [::Rosticons::Get status/$status]
    ConfigButton $w $status
    menu $wmenu -tearoff 0
    set menuBuild($w) [list  \
      BuildGenPresenceMenu $wmenu -variable $varName  \
      -command [list [namespace current]::ButtonCmd $w $varName $argsArr(-command)]]
    eval $menuBuild($w)
    $w configure -menu $wmenu
    
    bind $w <Destroy> {+::Jabber::Status::Free %W}

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
	$w state {disabled}
    } else {
	$w state {!disabled}
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
    variable mapShowElemToText
    variable menuBuild

    menubutton $w -indicatoron 1 -menu $w.menu  \
      -relief raised -bd 2 -highlightthickness 2 -anchor c -direction flush
    menu $w.menu -tearoff 0
    set menuBuild($w) [list  \
      BuildGenPresenceMenu $w.menu -variable $varName  \
      -command [list [namespace current]::MenuButtonCmd $w $varName]]
    eval $menuBuild($w)
    $w configure -text $mapShowElemToText($status)

    bind $w <Destroy> {+::Jabber::Status::Free %W}

    return $w
}

proc ::Jabber::Status::MenuButtonCmd {w varName} {
    upvar $varName status
    variable mapShowElemToText
    
    $w configure -text $mapShowElemToText($status)
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
    variable menuBuild
    
    set argsArr(-command) {}
    array set argsArr $args
    set cmd $argsArr(-command)
    unset argsArr(-command)

    eval {ttk::label $w} [array get argsArr]
    ConfigLabel $w $status
    set wmenu $w.menu
    menu $wmenu -tearoff 0
    set menuBuild($w) [list  \
      BuildGenPresenceMenu $wmenu -variable $varName -command  \
      [list [namespace current]::LabelCmd $w $varName $cmd]]
    eval $menuBuild($w)
    
    bind $w <Destroy> {+::Jabber::Status::Free %W}

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
    variable mapShowElemToText
    
    $w configure -text "$mapShowElemToText($status) "
    
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
    variable mapShowElemToText
    
    set entries {available {} away chat dnd xa invisible {} unavailable}

    foreach name $entries {
	if {$name == {}} {
	    $mt add separator
	} else {
	    set opts {}
	    if {[tk windowingsystem] ne "aqua"} {
		set opts [list -compound left \
		  -image [::Rosticons::Get status/$name]]
	    }
	    eval {
		$mt add radio -label $mapShowElemToText($name) -value $name
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
    variable mapShowElemToText
    variable mapShowTextToMLabel
    upvar ::Jabber::jprefs jprefs
    
    set entries {available {} away chat dnd xa invisible {} unavailable}
    set statMenuDef {}

    foreach name $entries {
	if {$name == {}} {
	    lappend statMenuDef {separator}
	} else {
	    set mName $mapShowTextToMLabel($name)
	    set cmd [list ::Jabber::SetStatus $name]
	    if {[string match "mac*" $this(platform)]} {
		set opts [list -variable ::Jabber::jstate(status) -value $name]
	    } else {
		set opts [list -variable ::Jabber::jstate(status) -value $name \
		  -compound left -image [::Rosticons::Get status/$name]]
	    }
	    lappend statMenuDef [list radio $mName $cmd normal {} $opts]
	}
    }
    lappend statMenuDef {separator}  \
      {command mAttachMessage {::Jabber::SetStatusWithMessage}  normal {}}
    
    return $statMenuDef
}

proc ::Jabber::Status::RosticonsHook { } {
    variable menuBuild
    
    foreach w [array names menuBuild] {
	
	# Note that we cannot configure the status image since we don't
	# know which status (login or room etc.).
	destroy $w.menu
	menu $w.menu -tearoff 0
	eval $menuBuild($w)
    }
}

proc ::Jabber::Status::Free {w} {
    variable menuBuild
    
    unset -nocomplain menuBuild($w)
}

#-------------------------------------------------------------------------------
