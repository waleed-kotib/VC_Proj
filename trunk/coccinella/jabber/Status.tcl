#  Status.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements various UI parts for setting status (presence).
#      
#  Copyright (c) 2004-2006  Mats Bengtsson
#  
# $Id: Status.tcl,v 1.23 2006-12-02 15:19:48 matben Exp $

package provide Status 1.0

namespace eval ::Status:: {

    ::hooks::register rosterIconsChangedHook    ::Status::RosticonsHook
    ::hooks::register prefsInitHook             ::Status::ExInitPrefsHook
    
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

namespace eval ::Status:: {
    
    set ::config(status,menu,len) 8
}

proc ::Status::ExInitPrefsHook {} {
    upvar ::Jabber::jprefs jprefs
   
    set jprefs(status,menu) {}
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(status,menu) jprefs_status_menu $jprefs(status,menu)]]
}

# Status::ExMainButton --
# 
#       Make a status menu button for login status only.

proc ::Status::ExMainButton {w varName} {
    upvar $varName showStatus
    
    # We cannot use jstate(show+status) directly here due to the special use
    # of the "available" entry for login.
    set menuVar [namespace current]::menuVar($w)
    set $menuVar $showStatus
    ExButton $w $menuVar -command [list ::Status::ExMainCmd $w]  \
      -postcommand [list ::Status::ExMainPostCmd $w]

    trace add variable $varName write [list ::Status::ExMainTrace $w]
    bind $w <Destroy> +[list ::Status::ExMainFree %W $varName]
    return $w
}

proc ::Status::ExMainPostCmd {w} {
    
    puts "::Status::ExMainPostCmd"
    if {[::Jabber::GetMyStatus] eq "unavailable"} {
	set state disabled
    } else {
	set state normal
    }
    ExMenuSetState [ExGetMenu $w] all $state
    ExMenuSetState [ExGetMenu $w] available normal
}

proc ::Status::ExMainCmd {w} {
    
    puts "::Status::ExMainCmd"
    set menuVar [namespace current]::menuVar($w)
    upvar $menuVar showStatus
    
    puts "\t showStatus=$showStatus"
    set show   [lindex $showStatus 0]
    set status [lindex $showStatus 1]
    
    if {[::Jabber::IsConnected]} {
	::Jabber::SetStatus $show -status $status
    } else {

	# Status "available" is special since used for login.
	set menuVar [namespace current]::menuVar($w)
	set $menuVar "unavailable"
	::Login::Dlg
    }
}

proc ::Status::ExMainTrace {w varName index op} {
    upvar $varName var
    
    puts "::Status::ExMainTrace"
    
    # This is just to sync the menuVar after the statusVar.
    set value $var($index)
    set menuVar [namespace current]::menuVar($w)
    set $menuVar $value
}

proc ::Status::ExMainFree {w statusVar} {

    trace remove variable $statusVar write [list ::Status::ExMainTrace $w]
    set menuVar [namespace current]::menuVar($w)
    unset -nocomplain $menuVar
}

# Status::ExButton --
# 
#       Generic way to set any status.
#        
# Arguments:
#       w         button widget
#       varName   variable to sync with; list value {show status}
#       args      anything for the menu entries
#                 -postcommand
#       
# Results:
#       widget path

proc ::Status::ExButton {w varName args} {    
    upvar $varName showStatus
        
    set show [lindex $showStatus 0]	
    ttk::menubutton $w -style MiniMenubutton  \
      -compound image -image [::Rosticons::Get status/$show]
    set wmenu $w.menu
    menu $wmenu -tearoff 0  \
      -postcommand [list ::Status::ExPostCmd $wmenu $varName $args]
    $w configure -menu $wmenu
    
    trace add variable $varName write [list [namespace current]::ExTrace $w]
    bind $w <Destroy> +[list ::Status::ExFree %W $varName]
    return $w
}

proc ::Status::ExGetMenu {w} {
    return $w.menu
}

proc ::Status::ExTrace {w varName index op} {
    
    puts "::Status::ExTrace"
    if {[winfo exists $w]} {
	upvar $varName var

	if {$index eq ""} {
	    set showStatus $var
	} else {
	    set showStatus $var($index)
	}
	set show [lindex $showStatus 0]
	$w configure -image [::Rosticons::Get status/$show]
    }
}

proc ::Status::ExFree {w varName} {
    variable $w    
    unset -nocomplain $w
    trace remove variable $varName write [list [namespace current]::ExTrace $w]
}

proc ::Status::ExPostCmd {m varName opts} {
    $m delete 0 end
    eval {ExBuildMenu $m $varName} $opts
}

# Status::ExBuildMenu --
# 
# 
# Arguments:
#       m         menu widget
#       varName   variable to sync with; list value {show status}
#       args      anything for the menu entries
#                 -postcommand
#       
# Results:
#       menu widget

proc ::Status::ExBuildMenu {m varName args} {
    upvar ::Jabber::jprefs jprefs
    variable mapShowElemToText

    upvar $varName showStatus
    puts "::Status::ExBuildMenu varName=$varName, showStatus=$showStatus, args=$args"
    
    # We must intersect all actions in order to keep the status list uptodate.
    array set argsA {
	-command      {}
	-postcommand  {}
    }
    array set argsA $args
    set argsA(-command) [list ::Status::ExMenuCmd $m $varName $argsA(-command)]
    set postCommand $argsA(-postcommand)
    unset -nocomplain argsA(-postcommand)
    set args [array get argsA]
    
    set statusA(available)   {}
    set statusA(unavailable) {}
    set statusA(away)        {}
    foreach {show status} $jprefs(status,menu) {
	lappend statusA($show) $status
    }
    foreach show [array names statusA] {
	set statusA($show) [lsort -unique $statusA($show)]
    }
    
    # available and show shall always be there. Add other if exists.
    set showManifestL {available away unavailable}
    set showL {available away}
    foreach show {chat dnd xa invisible} {
	if {[info exists statusA($show)]} {
	    lappend showL $show	    
	}
    }
    lappend showL unavailable
    
    foreach show $showL {
	#puts "\t show=$show"
	set opts {}
	if {[tk windowingsystem] ne "aqua"} {
	    set opts [list -compound left \
	      -image [::Rosticons::Get status/$show]]
	}
	if {[lsearch $showManifestL $show] >= 0} {
	    set value [list $show {}]
	    eval {$m add radio -label $mapShowElemToText($show)  \
	      -variable $varName -value $value} $opts $args
	}
	foreach status $statusA($show) {
	    #puts "\t\t status=$status"
	    if {[string length $status] > 20} {
		set str [string range $status 0 18]
		append str "..."
	    } else {
		set str $status
	    }
	    set value [list $show $status]
	    set label $mapShowElemToText($show)
	    append label " " $str
	    eval {$m add radio -label $label  \
	      -variable $varName -value $value} $opts $args
	}
	$m add separator
    }
    $m add command -label mCustomStatus  \
      -command [concat ::Status::ExCustomDlg $varName $args]
    update idletasks
    
    if {[llength $postCommand]} {
	uplevel #0 $postCommand
    }
    return $m
}

proc ::Status::ExMenuSetState {m which state} {
    variable mapShowTextToElem
    variable mapShowElemToText
    
    if {$which eq "all"} {
	set iend [$m index end]
	for {set i 0} {$i <= $iend} {incr i} {
	    if {[$m type $i] ne "separator"} {
		$m entryconfigure $i -state $state
	    }
	}
    } else {
	$m entryconfigure [$m index $mapShowElemToText($which)*] -state $state
    }
}

proc ::Status::ExMenuCmd {m varName cmd} {    
    upvar $varName showStatus
    puts "::Status::ExMenuCmd"

    set show   [lindex $showStatus 0]
    set status [lindex $showStatus 1]
    if {$status ne ""} {
	ExAddMessage $show $status
    }
    if {[llength $cmd]} {
	uplevel #0 $cmd
    }
}

proc ::Status::ExAddMessage {show status} {
    global  config
    upvar ::Jabber::jprefs jprefs
    
    set len $config(status,menu,len)
    
    set statusL [linsert $jprefs(status,menu) 0 $show $status]
    if {[llength $statusL] > [expr {2*$len}]} {
	set statusL [lrange $statusL 0 [expr {2*$len-1}]]
    }
    set jprefs(status,menu) $statusL
}

proc ::Status::ExCustomDlg {varName args} {
    global  wDlgs

    set w $wDlgs(jpresmsg)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    variable $w
    upvar 0 $w state

    upvar $varName showStatus

    set state(varName)  $varName
    set state(show)     [lindex $showStatus 0]
    set state(status)   [lindex $showStatus 1]
    set state(-command) ""
    array set state $args
    
    # @@@ -image ?
    set menuDef [list  \
	[list [mc mAvailable]       -value available]  \
	[list [mc mAway]            -value away]       \
	[list [mc mChat]            -value chat]       \
	[list [mc mDoNotDisturb]    -value dnd]        \
	[list [mc mExtendedAway]    -value xa]         \
	[list [mc mInvisible]       -value invisible]  \
	[list [mc mNotAvailable]    -value unavailable]]

    set str "Set your status message for any of the presence states"
    set dtl "The most frequent states and status messages are easily reachable as menu entries"
    ui::dialog $w -type okcancel -message $str -detail $dtl -icon info  \
      -command ::Status::ExCustomDlgCmd -geovariable prefs(winGeom,$w)
    set fr [$w clientframe]
    ui::optionmenu $fr.m -menulist $menuDef -direction flush  \
      -variable [namespace current]::$w\(show)
    ttk::entry $fr.e -textvariable [namespace current]::$w\(status)
    
    grid  $fr.m  $fr.e  -sticky ew -padx 2
    grid columnconfigure $fr 1 -weight 1
    
    bind $w <Destroy> +[list ::Status::ExCustomDlgFree $w]
}

proc ::Status::ExCustomDlgCmd {w button} {
    variable $w
    upvar 0 $w state

    puts "::Status::ExCustomDlgCmd button=$button"

    if {$button eq "ok"} {
	upvar $state(varName) showStatus
	
	if {$state(status) ne ""} {
	    ExAddMessage $state(show) $state(status)
	}
	set showStatus [list $state(show) $state(status)]
	if {[llength $state(-command)]} {
	    uplevel #0 $state(-command)
	}
    }
}

proc ::Status::ExCustomDlgFree {w} {
    variable $w
    unset -nocomplain $w
}

proc ::Status::TestCmd {} {puts "::Status::TestCmd"}
proc ::Status::TestPostCmd {} {puts "::Status::TestPostCmd"}

#-------------------------------------------------------------------------------
