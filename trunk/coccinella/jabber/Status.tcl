#  Status.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements various UI parts for setting status (presence).
#      
#  Copyright (c) 2004-2006  Mats Bengtsson
#  
# $Id: Status.tcl,v 1.21 2006-11-16 14:28:55 matben Exp $

package provide Status 1.0

namespace eval ::Status:: {

    ::hooks::register rosterIconsChangedHook    ::Status::RosticonsHook
    
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

proc ::Status::GetStatusTextArray { } {
    variable mapShowElemToText
    
    return [array get mapShowElemToText]
}

# Status::MainButton --
# 
#       Make a status menu button for login status only.

proc ::Status::MainButton {w statusVar} {
    upvar $statusVar status
    
    # We cannot use jstate(status) directly here due to the special use
    # of the "available" entry for login.
    set menuVar [namespace current]::menuVar($w)
    set $menuVar $status
    Button $w $menuVar -command [list [namespace current]::MainCmd $w]

    trace add variable $statusVar write [list [namespace current]::MainTrace $w]
    bind $w <Destroy> +[list ::Status::MainFree %W $statusVar]

    return $w
}

proc ::Status::MainCmd {w status args} {
    
    if {[::Jabber::IsConnected]} {
	eval {::Jabber::SetStatus $status} $args
    } else {

	# Status "available" is special since used for login.
	set menuVar [namespace current]::menuVar($w)
	set $menuVar "unavailable"
	::Login::Dlg
    }
}

proc ::Status::MainTrace {w varName index op} {
    upvar $varName var
    
    # This is just to sync the menuVar after the statusVar.
    set value $var($index)
    set menuVar [namespace current]::menuVar($w)
    set $menuVar $value
}

proc ::Status::MainFree {w statusVar} {

    trace remove variable $statusVar write [list [namespace current]::MainTrace $w]
    set menuVar [namespace current]::menuVar($w)
    unset -nocomplain $menuVar
}

# Status::BuildMainMenu --
#
#       Builds a main status menu only. Hardcoded variable jstate(status).

proc ::Status::BuildMainMenu {mt} {
    
    set statusVar ::Jabber::jstate(status)
    upvar $statusVar status

    set menuVar [namespace current]::menuVar($mt)
    set $menuVar $status
    BuildGenericMenu $mt $menuVar \
      -command [list [namespace current]::MainMenuCmd $mt $menuVar]   

    trace add variable $statusVar write  \
      [list [namespace current]::MainTrace $mt]
    bind $mt <Destroy> +[list ::Status::MainFree %W $statusVar]

    return $mt
}

proc ::Status::MainMenuCmd {mt varName} {
    upvar $varName status
    
    MainCmd $mt $status
}

# ::Status::Button --
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

proc ::Status::Button {w varName args} {
    upvar $varName status
    variable menuBuildCmd
        
    set argsA(-command) {}
    array set argsA $args

    set wmenu $w.menu
    ttk::menubutton $w -style MiniMenubutton  \
      -compound image -image [::Rosticons::Get status/$status]
    menu $wmenu -tearoff 0
    set menuBuildCmd($w) [list BuildGenericMenu $wmenu $varName  \
      -command [list [namespace current]::ButtonCmd $w $varName $argsA(-command)]]
    eval $menuBuildCmd($w)
    $w configure -menu $wmenu
    
    trace add variable $varName write [list [namespace current]::Trace $w]
    bind $w <Destroy> +[list ::Status::Free %W $varName]

    return $w
}

proc ::Status::ButtonCmd {w varName cmd args} {
    upvar $varName show
	
    if {[llength $cmd]} {
	uplevel #0 $cmd $show $args
    }
}

proc ::Status::Trace {w varName index op} {
    upvar $varName var
    
    if {$index eq ""} {
	set show $var
    } else {
	set show $var($index)
    }
    if {[winfo exists $w]} {
	ConfigImage $w $show
    }
}

proc ::Status::ConfigImage {w show} {
        
    # Status "available" is special since used for login.
    # You have to set the state for the button itself yourself since
    # this varies with usage.
    if {($show eq "available") && ![::Jabber::IsConnected]} {
	# empty
    } else {
	$w configure -image [::Rosticons::Get status/$show]
    }
}

proc ::Status::PostMenu {wmenu x y} {
    
    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks

    tk_popup $wmenu [expr int($x)] [expr int($y)]
}

# Status::BuildGenericMenu --
# 
#       Builds a generic status menu.

proc ::Status::BuildGenericMenu {mt varName args} {
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
		$mt add radio -label $mapShowElemToText($name)  \
		  -variable $varName -value $name} $args $opts
	}
    }
    $mt add separator
    $mt add command -label [mc mAttachMessage] \
      -command [concat ::Status::SetWithMessage $varName $args]
}

proc ::Status::MenuConfig {w args} {
    
    eval {$w.menu configure} $args
}

proc ::Status::MenuSetState {w which state} {
    variable mapShowTextToElem
    variable mapShowElemToText
    
    set m $w.menu
    if {$which eq "all"} {
	foreach name [array names mapShowTextToElem] {
	    $m entryconfigure [$m index $name] -state $state
	}
	$m entryconfigure [$m index [mc mAttachMessage]] -state $state
    } else {
	$m entryconfigure [$m index $mapShowElemToText($which)] -state normal
    }
}

proc ::Status::RosticonsHook { } {
    variable menuBuildCmd
    
    foreach w [array names menuBuildCmd] {
	
	# Note that we cannot configure the status image since we don't
	# know which status (login or room etc.).
	destroy $w.menu
	menu $w.menu -tearoff 0
	eval $menuBuildCmd($w)
    }
}

proc ::Status::Free {w varName} {
    variable menuBuildCmd
    
    trace remove variable $varName write [list [namespace current]::Trace $w]
    unset -nocomplain menuBuildCmd($w)
}

# Status::BuildMenuDef --
# 
#       Builds a menuDef list for the main status menu.
#       
# Arguments:
#       
# Results:
#       menuDef list.

proc ::Status::BuildMenuDef { } {
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
	    if {[tk windowingsystem] eq "aqua"} {
		set opts [list -variable ::Jabber::jstate(status) -value $name]
	    } else {
		set opts [list -variable ::Jabber::jstate(status) -value $name \
		  -compound left -image [::Rosticons::Get status/$name]]
	    }
	    lappend statMenuDef [list radio $mName $cmd {} $opts]
	}
    }
    lappend statMenuDef {separator}  \
      {command mAttachMessage {::Status::SetWithMessage ::Jabber::jstate(status)} {}}
    
    return $statMenuDef
}

proc ::Status::MainWithMessage {} {
    upvar ::Jabber::jstate jstate
    
    set status [::Jabber::JlibCmd mypresencestatus]

    return [SetWithMessage -show $jstate(status) -status $status]
}

#-- Generic status dialog ------------------------------------------------------

# Status::SetWithMessage --
#
#       Dialog for setting user's status with message.
#       
# Arguments:
#       
# Results:
#       "cancel" or "set".

proc ::Status::SetWithMessage {varName args} {
    global  wDlgs

    upvar $varName show

    set w $wDlgs(jpresmsg)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    # Keep instance specific state array.
    variable $w
    upvar #0 $w state
    
    set state(finished) -1
    set state(varName)  $varName
    set state(args)     $args
    set state(-to)      ""
    set state(-status)  ""
    set state(-command) ""
    array set state $args
    
    # We must work with a temporary varName for status.
    set state(show) $show
    
    ::UI::Toplevel $w -macstyle documentProc \
      -macclass {document closeBox} -closecommand [namespace current]::CloseStatus
    wm title $w [mc {Set Status}]

    ::UI::SetWindowPosition $w
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Top frame.
    set wtop $wbox.top
    ttk::labelframe $wtop -text [mc {My Status}] \
      -padding [option get . groupPadding {}]
    pack $wtop -side top -fill x

    foreach val {available chat away xa dnd invisible} {
	ttk::radiobutton $wtop.$val -style Small.TRadiobutton \
	  -compound left -text [mc jastat${val}]          \
	  -image [::Roster::GetPresenceIconFromKey $val]  \
	  -variable $w\(show) -value $val \
	  -command [list [namespace current]::StatusMsgRadioCmd $w]
	grid  $wtop.$val  -sticky w
    }
        
    ttk::label $wbox.lbl -text "[mc {Status message}]:" \
      -padding [option get . groupTopPadding {}]
    pack $wbox.lbl -side top -anchor w -padx 6

    set wtext $wbox.txt
    text $wtext -height 4 -width 36 -wrap word -bd 1 -relief sunken
    pack $wtext -expand 1 -fill both
	
    # Any existing presence status?
    $wtext insert end $state(-status)
	
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Set] -default active \
      -command [list [namespace current]::BtSetStatus $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::SetStatusCancel $w]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side top -fill x
    
    wm resizable $w 0 0
    bind $w <Return> {}
    
    set state(wtext) $wtext
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
    set finished $state(finished)
    unset -nocomplain state
    return [expr {($finished <= 0) ? "cancel" : "set"}]
}

proc ::Status::StatusMsgRadioCmd {w} {
    upvar ::Jabber::jprefs jprefs

    variable $w
    upvar #0 $w state

    # We could have an option here to set default status message if any.
    if {0} {
	if {$jprefs(statusMsg,bool,$show) && ($jprefs(statusMsg,msg,$show) ne "")} {
	    set wtext $state(wtext)
	    set show $state(-show)
	    $wtext delete 1.0 end
	    $wtext insert end $jprefs(statusMsg,msg,$show)
	}
    }
}

proc ::Status::CloseStatus {w} {
    
    ::UI::SaveWinGeom $w
}

proc ::Status::SetStatusCancel {w} {    
    variable $w
    upvar #0 $w state

    ::UI::SaveWinGeom $w
    set state(finished) 0
    destroy $w
}

proc ::Status::BtSetStatus {w} {
    variable $w
    upvar #0 $w state
        
    set $state(varName) $state(show)
    
    parray state

    set text [string trim [$state(wtext) get 1.0 end]]
    set opts [list -status $text]
    if {$state(-to) ne ""} {
	lappend opts -to $state(-to)
    }
    
    # Set present status.
    if {$state(-command) ne ""} {
	uplevel #0 $state(-command) $opts
    } else {
	eval {::Jabber::SetStatus $state(show)} $opts
    }
    ::UI::SaveWinGeom $w
    set state(finished) 1
    destroy $w
}

#-------------------------------------------------------------------------------
