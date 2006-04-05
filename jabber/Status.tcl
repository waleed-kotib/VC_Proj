#  Status.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements various UI parts for setting status (presence).
#      
#  Copyright (c) 2004-2006  Mats Bengtsson
#  
# $Id: Status.tcl,v 1.15 2006-04-05 07:46:22 matben Exp $

package provide Status 1.0

namespace eval ::Jabber::Status:: {

    ::hooks::register rosterIconsChangedHook    ::Jabber::Status::RosticonsHook
    
    # Mappings from <show> element to displayable text and vice versa.
    # chat away xa dnd
    variable mapShowTextToElem
    variable mapShowElemToText
    
    array set mapShowTextToElem [list  \
      [mc mAvailable]       available  \
      [mc mAway]            away       \
      [mc mChat]            chat       \
      [mc mDoNotDisturb]    dnd        \
      [mc mExtendedAway]    xa         \
      [mc mInvisible]       invisible  \
      [mc mNotAvailable]    unavailable]
    array set mapShowElemToText [list     \
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

# Jabber::Status::MainButton --
# 
#       Make a status menu button for login status only.

proc ::Jabber::Status::MainButton {w statusVar} {
    upvar $statusVar status
    
    # We cannot use jstate(status) directly here due to the special use
    # of the "available" entry for login.
    set menuVar [namespace current]::menuVar($w)
    set $menuVar $status
    Button $w $menuVar -command [list [namespace current]::MainCmd $w]

    trace add variable $statusVar write [list [namespace current]::MainTrace $w]
    bind $w <Destroy> +[list ::Jabber::Status::MainFree %W $statusVar]

    return $w
}

proc ::Jabber::Status::MainCmd {w status} {
    
    if {[::Jabber::IsConnected]} {
	::Jabber::SetStatus $status
    } else {

	# Status "available" is special since used for login.
	set menuVar [namespace current]::menuVar($w)
	set $menuVar "unavailable"
	::Login::Dlg
    }
}

proc ::Jabber::Status::MainTrace {w varName index op} {
    upvar $varName var
    
    # This is just to sync the menuVar after the statusVar.
    set value $var($index)
    set menuVar [namespace current]::menuVar($w)
    set $menuVar $value
}

proc ::Jabber::Status::MainFree {w statusVar} {

    trace remove variable $statusVar write [list [namespace current]::MainTrace $w]
    set menuVar [namespace current]::menuVar($w)
    unset -nocomplain $menuVar
}

# Jabber::Status::BuildMainMenu --
#
#       Builds a main status menu only. Hardcoded variable jstate(status).

proc ::Jabber::Status::BuildMainMenu {mt} {
    
    set statusVar ::Jabber::jstate(status)
    upvar $statusVar status

    set menuVar [namespace current]::menuVar($mt)
    set $menuVar $status
    BuildGenericMenu $mt -variable $menuVar \
      -command [list [namespace current]::MainMenuCmd $mt $menuVar]   

    trace add variable $statusVar write  \
      [list [namespace current]::MainTrace $mt]
    bind $mt <Destroy> +[list ::Jabber::Status::MainFree %W $statusVar]

    return $mt
}

proc ::Jabber::Status::MainMenuCmd {mt varName} {
    upvar $varName status
    MainCmd $mt $status
}

# ::Jabber::Status::Button --
# 
#       A few functions to build a megawidget status menu button.
#       This shall work independent of situation; login status or room status.
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
    variable menuBuildCmd
        
    set argsArr(-command) {}
    array set argsArr $args

    set wmenu $w.menu
    ttk::menubutton $w -style MiniMenubutton  \
      -compound image -image [::Rosticons::Get status/$status]
    ConfigImage $w $status
    menu $wmenu -tearoff 0
    set menuBuildCmd($w) [list BuildGenericMenu $wmenu -variable $varName  \
      -command [list [namespace current]::ButtonCmd $w $varName $argsArr(-command)]]
    eval $menuBuildCmd($w)
    $w configure -menu $wmenu
    
    trace add variable $varName write [list [namespace current]::Trace $w]
    bind $w <Destroy> +[list ::Jabber::Status::Free %W $varName]

    return $w
}

proc ::Jabber::Status::ButtonCmd {w varName cmd} {
    upvar $varName status
	
    if {$cmd != {}} {
	uplevel #0 $cmd $status
    }
}

proc ::Jabber::Status::Trace {w varName index op} {
    upvar $varName var
    
    if {$index eq ""} {
	set status $var
    } else {
	set status $var($index)
    }
    if {[winfo exists $w]} {
	ConfigImage $w $status
    }
}

proc ::Jabber::Status::ConfigImage {w status} {
        
    # Status "available" is special since used for login.
    # You have to set the state for the button itself yourself since
    # this varies with usage.
    if {($status eq "available") && ![::Jabber::IsConnected]} {
	# empty
    } else {
	$w configure -image [::Rosticons::Get status/$status]
    }
}

proc ::Jabber::Status::PostMenu {wmenu x y} {
    
    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks

    tk_popup $wmenu [expr int($x)] [expr int($y)]
}

# Jabber::Status::BuildGenericMenu --
# 
#       Builds a generic status menu.

proc ::Jabber::Status::BuildGenericMenu {mt args} {
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
    $mt configure -postcommand [list [namespace current]::PostCmd $mt]
}

proc ::Jabber::Status::PostCmd {m} {
    variable mapShowTextToElem
    
    if {[::Jabber::GetMyStatus] eq "unavailable"} {
	set state disabled
    } else {
	set state normal
    }
    foreach name [array names mapShowTextToElem] {
	$m entryconfigure [$m index $name] -state $state
    }
    $m entryconfigure [$m index [mc mAttachMessage]] -state $state

    # This wont work for rooms why the menu shall never be posted while offline.
    $m entryconfigure [$m index [mc mAvailable]] -state normal
}

proc ::Jabber::Status::RosticonsHook { } {
    variable menuBuildCmd
    
    foreach w [array names menuBuildCmd] {
	
	# Note that we cannot configure the status image since we don't
	# know which status (login or room etc.).
	destroy $w.menu
	menu $w.menu -tearoff 0
	eval $menuBuildCmd($w)
    }
}

proc ::Jabber::Status::Free {w varName} {
    variable menuBuildCmd
    
    trace remove variable $varName write [list [namespace current]::Trace $w]
    unset -nocomplain menuBuildCmd($w)
}

# Jabber::Status::BuildStatusMenuDef --
# 
#       Builds a menuDef list for the main status menu.
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

#-------------------------------------------------------------------------------
