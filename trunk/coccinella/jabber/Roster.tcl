#  Roster.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Roster GUI part.
#      
#  Copyright (c) 2001-2006  Mats Bengtsson
#  
# $Id: Roster.tcl,v 1.176 2006-09-02 06:43:38 matben Exp $

package require RosterTree
package require RosterPlain
package require RosterTwo
package require RosterAvatar

package provide Roster 1.0

namespace eval ::Roster:: {
    global  this prefs
    
    # Add all event hooks we need.
    ::hooks::register loginHook              ::Roster::LoginCmd
    ::hooks::register logoutHook             ::Roster::LogoutHook
    ::hooks::register quitAppHook            ::Roster::QuitHook
    ::hooks::register uiMainToggleMinimal    ::Roster::ToggleMinimalHook
    ::hooks::register jabberInitHook         ::Roster::JabberInitHook
    
    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Roster::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Roster::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Roster::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Roster::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Roster::UserDefaultsHook

    # Use option database for customization. 
    # Use priority 50 just to override the widgetDefault values!
    
    # Standard widgets and standard options.
    option add *Roster.borderWidth          0               50
    option add *Roster.relief               flat            50
    option add *Roster*box.borderWidth      1               50
    option add *Roster*box.relief           sunken          50
    
    option add *Roster.padding              4               50
        
    # Specials.
    option add *Roster.waveImage            wave            widgetDefault
    option add *Roster.minimalPadding       {0}             widgetDefault
    option add *Roster.whiteboard12Image    whiteboard12    widgetDefault
    
    variable wtree -
    
    # A unique running identifier.
    variable uid 0
    
    # Keep track of when in roster callback.
    variable inroster 0

    # Mappings from <show> element to displayable text and vice versa.
    # chat away xa dnd
    variable mapShowTextToElem
    variable mapShowElemToText
    
    # Cache messages for efficiency.
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
    
    # Template for the roster popup menu.
    variable popMenuDefs
    
    # General.
    set popMenuDefs(roster,def) {
	command     mMessage       {head group user}  {::NewMsg::Build -to $jid -tolist $jidlist} {}
	command     mChat          {user available}   {::Chat::StartThread $jid3}         {}
	command     mWhiteboard    {wb available}     {::JWB::NewWhiteboardTo $jid3} {}
	command     mSendFile      {user available}   {::FTrans::Send $jid3}             {}
	separator   {}             {}                 {} {}
	command     mAddNewUser    {}                 {::JUser::NewDlg}            {}
	command     mEditUser      {user}             {::JUser::EditDlg $jid}      {}
	command     mUserInfo      {user}             {::UserInfo::Get $jid3}             {}
	command     mChatHistory   {user always}      {::Chat::BuildHistoryForJid $jid}   {}
	command     mRemoveContact {user}             {::Roster::SendRemove $jid}         {}
	separator   {}             {}                 {} {}
	cascade     mShow          {normal}           {
	    check     mOffline     {normal}     {::Roster::ShowOffline}    {-variable ::Jabber::jprefs(rost,showOffline)}
	    check     mTransports  {normal}     {::Roster::ShowTransports} {-variable ::Jabber::jprefs(rost,showTrpts)}
	    check     mBackgroundImage {normal} {::Roster::BackgroundImage} {-variable ::Jabber::jprefs(rost,useBgImage)}
	} {}
	cascade     mSort          {}                 {
	    radio     mIncreasing  {}     {::Roster::Sort}  {-variable ::Jabber::jprefs(rost,sort) -value +1}
	    radio     mDecreasing  {}     {::Roster::Sort}  {-variable ::Jabber::jprefs(rost,sort) -value -1}
	} {}
	cascade     mStyle         {normal}           {@::Roster::StyleMenu} {}
	command     mRefreshRoster {}                 {::Roster::Refresh} {}
    }  

    # Transports.
    set popMenuDefs(roster,trpt,def) {
	command     mLastLogin/Activity {user}        {::Jabber::GetLast $jid}        {}
	command     mvCard         {user}             {::VCard::Fetch other $jid}     {}
	command     mAddNewUser    {}                 {::JUser::NewDlg}        {}
	command     mEditUser      {user}             {::JUser::EditDlg $jid}  {}
	command     mVersion       {user}             {::Jabber::GetVersion $jid3}    {}
	command     mLoginTrpt     {trpt unavailable} {::Roster::LoginTrpt $jid3}     {}
	command     mLogoutTrpt    {trpt available}   {::Roster::LogoutTrpt $jid3}    {}
	separator   {}             {}                 {} {}
	command     mUnregister    {trpt}             {::Register::Remove $jid3}      {}
	command     mRefreshRoster {}                 {::Roster::Refresh}             {}
    }  
    
    # Various time values.
    variable timer
    set timer(msg,ms) 10000
    set timer(exitroster,secs) 0
    set timer(pres,secs) 4
}

proc ::Roster::JabberInitHook {jlibname} {
    
    $jlibname presence_register available [namespace code PresenceEvent]   
    $jlibname presence_register unavailable [namespace code PresenceEvent]   
}

proc ::Roster::GetNameOrjid {jid} {
    upvar ::Jabber::jstate jstate
       
    set name [$jstate(jlib) roster getname $jid]
    if {$name eq ""} {
	set name $jid
    }
    return $name
}

proc ::Roster::GetShortName {jid} {
    upvar ::Jabber::jstate jstate
    
    set name [$jstate(jlib) roster getname $jid]
    if {$name eq ""} {	
	jlib::splitjidex $jid node domain res
	if {$node eq ""} {
	    set name $domain
	} else {
	    if {[string equal [$jstate(jlib) getthis server] $domain]} {
		set name $node
	    } else {
		set name $jid
	    }
	}
    }
    return $name
}

proc ::Roster::GetDisplayName {jid} {
    upvar ::Jabber::jstate jstate
    
    set name [$jstate(jlib) roster getname $jid]
    if {$name eq ""} {
	jlib::splitjidex $jid node domain res
	if {$node eq ""} {
	    set name $domain
	} else {
	    set name $node
	}
    }
    return $name
}

proc ::Roster::MapShowToText {show} {
    variable mapShowElemToText
    
    if {[info exists mapShowElemToText($show)]} {
	return $mapShowElemToText($show)
    } else {
	return $show
    }
}

# Roster::Show --
#
#       Show the roster window.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       shows window.

proc ::Roster::Show {w} {
    upvar ::Jabber::jstate jstate

    if {$jstate(rosterVis)} {
	if {[winfo exists $w]} {
	    catch {wm deiconify $w}
	} else {
	    BuildToplevel $w
	}
    } else {
	catch {wm withdraw $w}
    }
}

# Roster::BuildToplevel --
#
#       Build the toplevel roster window.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       shows window.

proc ::Roster::BuildToplevel {w} {
    global  prefs

    variable wtop
    variable servtxt
    upvar ::UI::menuDefs menuDefs

    if {[winfo exists $w]} {
	return
    }
    set wtop $w
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1
    wm title $w {Roster (Contact list)}
    wm protocol $w WM_DELETE_WINDOW [list [namespace current]::CloseDlg $w]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Top frame for info.
    set frtop $w.frall.frtop
    pack [frame $frtop] -fill x -side top -anchor w -padx 10 -pady 4
    label $frtop.la -text {Connected to:} -font CociSmallBoldFont
    label $frtop.laserv -textvariable [namespace current]::servtxt
    pack $frtop.la $frtop.laserv -side left -pady 4
    set servtxt {not connected}

    # And the real stuff.
    pack [Build $w.frall.br] -side top -fill both -expand 1
    
    wm maxsize $w 320 800
    wm minsize $w 180 240
}

# Roster::Build --
#
#       Makes mega widget to show the roster.
#
# Arguments:
#       w           frame window with everything.
#       
# Results:
#       w

proc ::Roster::Build {w} {
    global  this prefs
        
    variable wtree    
    variable wroster
    variable wbox
    variable wwave
    variable rstyle
    variable icons
    upvar ::Jabber::jprefs jprefs
        
    # The frame of class Roster.
    ttk::frame $w -class Roster
        
    # Tree frame with scrollbars.
    set wroster $w
    set wbox    $w.box
    set wxsc    $wbox.xsc
    set wysc    $wbox.ysc
    set wtree   $wbox.tree
    set wwave   $w.wa
    set rstyle  "normal"
    
    set waveImage [::Theme::GetImage [option get $w waveImage {}]]  
    ::wavelabel::wavelabel $wwave -relief groove -bd 2 \
      -type image -image $waveImage
    pack $wwave -side bottom -fill x -padx 8 -pady 2
    
    # D = -border 1 -relief sunken
    frame $wbox
    pack  $wbox -side top -fill both -expand 1
        
    ::RosterTree::New $wtree $wxsc $wysc
    ::RosterTree::StyleConfigure $wtree
    ::RosterTree::StyleInit

    ttk::scrollbar $wxsc -command [list $wtree xview] -orient horizontal
    ttk::scrollbar $wysc -command [list $wtree yview] -orient vertical

    grid  $wtree  -row 0 -column 0 -sticky news
    grid  $wysc   -row 0 -column 1 -sticky ns
    grid  $wxsc   -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure    $wbox 0 -weight 1
    
    # Cache any expensive stuff.
    set icons(whiteboard12) [::Theme::GetImage [option get $w whiteboard12Image {}]]
   
    # Handle the prefs "Show" state.
    if {$jprefs(ui,main,show,minimal)} {
	StyleMinimal
    }
    return $w
}

proc ::Roster::ToggleMinimalHook {minimal} {
    variable wroster
    variable rstyle
    
    if {[winfo exists $wroster]} {
	if {$minimal && ($rstyle eq "normal")} {
	    StyleMinimal
	} elseif {!$minimal && ($rstyle eq "minimal")} {
	    StyleNormal
	}
    }
}

proc ::Roster::StyleMinimal { } {
    variable wroster
    variable wbox
    variable wwave
    variable rstyle
    
    $wroster configure -padding [option get $wroster minimalPadding {}]
    $wbox configure -bd 0
    pack forget $wwave
    set rstyle "minimal"
}

proc ::Roster::StyleNormal { } {
    variable wroster
    variable wbox
    variable wwave
    variable rstyle
    
    set padding [option get $wroster padding {}]
    $wroster configure -padding $padding
    set bd [option get $wbox borderWidth {}]
    $wbox configure -bd $bd
    pack $wwave -side bottom -fill x -padx 8 -pady 2
    set rstyle "normal"
}

proc ::Roster::StyleGet { } {
    variable rstyle

    return $rstyle
}

proc ::Roster::GetRosterWindow { } {
    variable wroster
    
    return $wroster
}

proc ::Roster::GetWtree { } {
    variable wtree
    
    return $wtree
}

proc ::Roster::BackgroundImage { } {
    upvar ::Jabber::jprefs jprefs
    
    if {$jprefs(rost,useBgImage)} {
	set image [::RosterTree::BackgroundImage]
    } else {
	set image ""
    }
    ::RosterTree::ConfigBgImage $image
}

proc ::Roster::Animate {{step 1}} {
    variable wwave
    
    $wwave animate $step
}

proc ::Roster::Message {str} {
    variable wwave
    
    $wwave message $str
}

proc ::Roster::TimedMessage {str} {
    variable timer
    
    if {[info exists timer(msg)]} {
	after cancel $timer(msg)
    }
    Message $str
    after $timer(msg,ms) [namespace current]::CancelTimedMessage
}

proc ::Roster::CancelTimedMessage { } {

    Message ""
}

proc ::Roster::SetPresenceMessage {jid presence args} {
    
    array set argsArr $args
    set show $presence
    if {[info exists argsArr(-show)]} {
	set show $argsArr(-show)
    }
    set name [GetDisplayName $jid]
    TimedMessage "$name [mc $show]"
}

# Roster::LoginCmd --
# 
#       The login hook command.

proc ::Roster::LoginCmd { } {
    upvar ::Jabber::jstate jstate

    $jstate(jlib) roster send_get

    set server [::Jabber::GetServerJid]
}

proc ::Roster::LogoutHook { } {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
        
    ::RosterTree::GetClosed

    # Here?
    $jstate(jlib) roster reset
    
    # Clear roster and browse windows.
    if {$jprefs(rost,clrLogout)} {
	::RosterTree::StyleInit
	::RosterTree::FreeAllAltImagesCache
    }
}

proc ::Roster::QuitHook { } {
    variable wtree    
    
    if {[info exists wtree] && [winfo exists $wtree]} {
	::RosterTree::GetClosed
    }
}

proc ::Roster::CloseDlg {w} {    

    catch {wm withdraw $w}
    set jstate(rosterVis) 0
}

proc ::Roster::Refresh { } {
    variable wwave
    upvar ::Jabber::jstate jstate

    ::RosterTree::GetClosed
    
    # Get my roster.
    $jstate(jlib) roster send_get
    $wwave animate 1
}

# Doing 'after idle' is not perfect since it is executed after the items have
# been drawn.

proc ::Roster::SortIdle {item} {
    variable sortID
    variable wtree
        
    unset -nocomplain sortID
    if {[$wtree item id $item] ne ""} {
	Sort $item
    }
}

proc ::Roster::Sort {{item root}} {
    upvar ::Jabber::jprefs jprefs
	
    if {$jprefs(rost,sort) == 1} {
	set order -increasing
    } else {
	set order -decreasing
    }
    ::RosterTree::Sort $item $order
}

# Roster::SendRemove --
#
#       Method to remove another user from my roster.
#
#

proc ::Roster::SendRemove {jidrm} {    
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Roster::SendRemove jidrm=$jidrm"

    set jid $jidrm

    set ans [::UI::MessageBox -title [mc {Remove Item}] \
      -message [mc jamesswarnremove] -icon warning -type yesno -default no]
    if {[string equal $ans "yes"]} {
	$jstate(jlib) roster send_remove $jid
    }
}
    
# Roster::RegisterPopupEntry --
# 
#       Components or plugins can add their own menu entries here.

proc ::Roster::RegisterPopupEntry {menuSpec} {
    variable popMenuDefs
    
    # Keeps track of all registered menu entries.
    variable regPopMenuSpec
    
    # Index of last separator.
    set ind [lindex [lsearch -all $popMenuDefs(roster,def) "separator"] end]
    if {![info exists regPopMenuSpec]} {
	
	# Add separator if this is the first addon entry.
	incr ind 5
	set popMenuDefs(roster,def) \
	  [linsert $popMenuDefs(roster,def) $ind separator {} {} {} {}]
	set regPopMenuSpec {}
	set ind [lindex [lsearch -all $popMenuDefs(roster,def) "separator"] end]
    }
    
    # Add new entry just before the last separator
    set v $popMenuDefs(roster,def)
    set popMenuDefs(roster,def) \
      [concat [lrange $v 0 [expr $ind-1]] $menuSpec [lrange $v $ind end]]
    set regPopMenuSpec [concat $regPopMenuSpec $menuSpec]
}

proc ::Roster::DeRegisterPopupEntry {mLabel} {
    variable popMenuDefs
    variable regPopMenuSpec
    
    if {[info exists regPopMenuSpec]} {
	
	# First remove from the 'regPopMenuSpec' list.
	set idx [lsearch $regPopMenuSpec $mLabel]
	set rem [expr {$idx % 5}]
	if {$idx > 0 && $rem == 1} {
	    set midx [expr {$idx/5}]
	    set i0 [expr {5 * $midx}]
	    set i1 [expr {$i0 + 4}]
	    set regPopMenuSpec [lreplace $regPopMenuSpec $i0 $i1]	    
	}
	
	# Then remove from 'popMenuDefs'.
	set v $popMenuDefs(roster,def)
	set idx [lsearch $v $mLabel]
	if {$idx > 0 && $rem == 1} {
	    set midx [expr {$idx/5}]
	    set i0 [expr {5 * $midx}]
	    set i1 [expr {$i0 + 4}]
	    set popMenuDefs(roster,def) [lreplace $v $i0 $i1]	    
	}
    }
}

# Roster::DoPopup --
#
#       Handle popup menu in roster.
#       
# Arguments:
#       jidlist     this is a list of actual jid's, can be any form
#       clicked
#       status      'available', 'unavailable', 'transports', or 'pending'
#       group       name of group if any
#       
# Results:
#       popup menu displayed

proc ::Roster::DoPopup {jidlist clicked status group x y} {
    variable popMenuDefs
    variable wtree
    
    upvar ::Jabber::jstate jstate
    
    # Keep a temporary array that maps from mLabel to menu index.
    variable tmpMenuIndex
        
    ::Debug 2 "::Roster::DoPopup jidlist=$jidlist, clicked=$clicked, status=$status"
        
    # Make the appropriate menu.
    set m $jstate(wpopup,roster)
    set i 0
    catch {destroy $m}
    menu $m -tearoff 0
    
    set menuDef $popMenuDefs(roster,def)	
    foreach click $clicked {
	if {[info exists popMenuDefs(roster,$click,def)]} {
	    set menuDef $popMenuDefs(roster,$click,def)
	}
    }
    
    # We build menus using this proc to be able to make cascades.
    BuildMenu $m $menuDef $jidlist $clicked $status $group
    
    ::hooks::run rosterPostCommandHook $m $jidlist $clicked $status  
    array unset tmpMenuIndex

    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks
        
    # Post popup menu.
    set X [expr [winfo rootx $wtree] + $x]
    set Y [expr [winfo rooty $wtree] + $y]
    tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
}

# Roster::BuildMenu --
# 
#       Build popup menu recursively if necessary.

proc ::Roster::BuildMenu {m menuDef _jidlist clicked status group} {
    variable tmpMenuIndex
    
    # We always get a list of jids, typically with only one element.
    set jid3 [lindex $_jidlist 0]
    jlib::splitjid $jid3 jid2 -
    set jid $jid2

    # The jidlist is expected to be with no resource part.
    set jidlist {}
    foreach u $_jidlist {
	jlib::splitjid $u jid2 -
	lappend jidlist $jid2
    }
    
    set i 0
    
    foreach {op item type cmd opts} $menuDef {	
	set locname [mc $item]
	# If need sudstitutions in opts:
	#set opts [eval list $opts]

	switch -- $op {
	    command {
    
		# Substitute the jid arguments. Preserve list structure!
		set cmd [eval list $cmd]
		eval {$m add command -label $locname -command [list after 40 $cmd]  \
		  -state disabled} $opts
	    }
	    radio {
		set cmd [eval list $cmd]
		eval {$m add radiobutton -label $locname -command [list after 40 $cmd]  \
		  -state disabled} $opts
	    }
	    check {
		set cmd [eval list $cmd]
		eval {$m add checkbutton -label $locname -command [list after 40 $cmd]  \
		  -state disabled} $opts
	    }
	    separator {
		$m add separator
		continue
	    }
	    cascade {
		set mt [menu $m.sub$i -tearoff 0]
		eval {$m add cascade -label $locname -menu $mt -state disabled} $opts
		if {[string index $cmd 0] eq "@"} {
		    eval [string range $cmd 1 end] $mt
		} else {
		    BuildMenu $mt $cmd $_jidlist $clicked $status $group
		}		
		incr i
	    } 
	    default {
		return -code error "the op $op should never happen!"
	    }
	}
	set tmpMenuIndex($item) [$m index $locname]
	
	if {$type eq "normal"} {
	    set state normal
	} else {
	    if {![::Jabber::IsConnected] && ([lsearch $type always] < 0)} {
		continue
	    }
	    
	    # State of menu entry. 
	    # We use the 'type' and 'clicked' lists to set the state.
	    if {[listintersectnonempty $type $clicked]} {
		set state normal
	    } elseif {$type eq ""} {
		set state normal
	    } else {
		set state disabled
	    }
	    
	    # If any available/unavailable these must also be fulfilled.
	    if {[lsearch $type available] >= 0} {
		if {$status ne "available"} {
		    set state disabled
		}
	    } elseif {[lsearch $type unavailable] >= 0} {
		if {$status ne "unavailable"} {
		    set state disabled
		}
	    }
	}
	if {[string equal $state "normal"]} {
	    $m entryconfigure $locname -state normal
	}
    }
}

proc ::Roster::SetMenuEntryState {m mLabel state} {
    variable tmpMenuIndex
    
    if {[info exists tmpMenuIndex($mLabel)]} {
	set idx $tmpMenuIndex($mLabel)
	$m entryconfigure $idx -state $state
    }
}

proc ::Roster::StyleMenu {m} {
    variable styleName
    
    set styleName [::RosterTree::GetStyle]
    foreach {name label} [::RosterTree::GetAllStyles] {
	$m add radiobutton -label $label  \
	  -variable ::Roster::styleName -value $name  \
	  -command [list ::RosterTree::LoadStyle $name]
    }
}

# Roster::PushProc --
#
#       Our callback procedure for roster pushes.
#       Populate our roster tree.
#
# Arguments:
#       jlibname
#       what        any of "remove", "set", "enterroster",
#                   "exitroster"
#       jid         'user@server' without any /resource usually.
#                   Some transports keep a resource part in jid.
#       args        list of '-key value' pairs where '-key' can be
#                   -resource, -from, -type...
#       
# Results:
#       updates the roster UI.

proc ::Roster::PushProc {jlibname what {jid {}} args} {    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    variable inroster
    
    ::Debug 2 "---roster-> what=$what, jid=$jid, args='$args'"

    # Extract the args list as an array.
    array set attrArr $args
    
    set jlib $jstate(jlib)
        
    switch -- $what {
	remove {
	    
	    # Must remove all resources, and jid2 if no resources.
    	    set resList [$jlib roster getresources $jid]
	    foreach res $resList {
		::RosterTree::StyleDeleteItem $jid/$res
	    }
	    if {$resList eq {}} {
		::RosterTree::StyleDeleteItem $jid
	    }
	}
	set {
	    eval {SetItem $jid} $args
	}
	enterroster {
	    set inroster 1
	    ::RosterTree::StyleInit	    
	    ::hooks::run rosterEnter
	}
	exitroster {
	    set inroster 0
	    ExitRoster
	    ::hooks::run rosterExit
	}
    }
}

# Roster::PresenceEvent --
# 
#       Registered jlib presence handler for (un)available events only.
#       This is the application main organizer for presence stanzas and
#       takes care of calling functions to update roster, run hooks etc.

proc ::Roster::PresenceEvent {jlibname xmldata} {
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "---presence->"
    
    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {$type eq ""} {
	set type "available"
    }

    # We don't handle subscription types (remove?).
    if {$type ne "available" && $type ne "unavailable"} {
	return
    }
    set jlib $jstate(jlib)
        
    set jid3 $from
    jlib::splitjid $from jid2 res
    set jid $jid2
    
    # @@@ So far we preprocess the presence element to an option list.
    #     In the future it is better not to.
    set opts [list -from $from -type $type -resource $res -xmldata $xmldata]
    set x {}
    set extras {}
    foreach E [wrapper::getchildren $xmldata] {
	set tag [wrapper::gettag $E]
	set chdata [wrapper::getcdata $E]
	
	switch -- $tag {
	    status - priority {
		lappend opts -$tag $chdata
	    }
	    show {
		lappend opts -$tag [string tolower $chdata]
	    }
	    x {
		lappend x $E
	    }
	    default {
		lappend extras $E
	    }
	}
    }
    if {[llength $x]} {
	lappend opts -x $x
    }
    if {[llength $extras]} {
	lappend opts -extras $extras
    }
    
    # This 'isroom' gives wrong answer if a gateway also supports
    # conference (groupchat).
    if {0} {
	if {![$jlib service isroom $jid]} {
	    eval {Presence $jid3 $type} $opts
	}
    }
    
    # We get presence also for rooms etc which are not roster items.
    # Some transports have /registered resource.
    if {[$jlib roster isitem $jid]} {
	eval {Presence $jid3 $type} $opts
    } elseif {[$jlib roster isitem $jid3]} {
	eval {Presence $jid3 $type} $opts
    }
    
    # Specific type presence hooks.
    eval {::hooks::run presence[string totitle $type]Hook $jid $type} $opts
    
    # Hook to run only for new presence/show/status.
    # This is helpful because of some x-elements can be broadcasted.
    array set oldPres [$jlib roster getoldpresence $jid3]
    set same [arraysequalnames attrArr oldPres {-type -show -status}]
    if {!$same} {
	eval {::hooks::run presenceNewHook $jid $type} $opts
    }
    
    # General type presence hooks.
    eval {::hooks::run presenceHook $jid $type} $opts
    
    # Make an additional call for delayed presence.
    # This only happend when type='available'.
    if {[info exists attrArr(-x)]} {
	set delayElem [wrapper::getnamespacefromchilds  \
	  $attrArr(-x) x "jabber:x:delay"]
	if {[llength $delayElem]} {
	    eval {::hooks::run presenceDelayHook $jid $type} $opts
	}
    }
}

proc ::Roster::RepopulateTree { } {
    variable wtree
    upvar ::Jabber::jstate jstate
    
    ::RosterTree::GetClosed
    ::RosterTree::StyleInit
    
    foreach jid [$jstate(jlib) roster getusers] {
	eval {SetItem $jid} [$jstate(jlib) roster getrosteritem $jid]
    }
    Sort
}

proc ::Roster::ExitRoster { } {
    variable wwave
    variable timer

    Sort
    ::JUI::SetStatusMessage [mc jarostupdate]
    $wwave animate -1
    set timer(exitroster,secs) [clock seconds]
}

# Roster::SetItem --
#
#       Callback from roster pushes when getting <item .../>.
#       Adds a jid item to the tree.
#
# Arguments:
#       jid         2-tier jid with no /resource part usually, not icq/reg.
#       args        list of '-key value' pairs where '-key' can be
#                   -name
#                   -groups   Note, PLURAL!
#                   -ask
#       
# Results:
#       updates tree.

proc ::Roster::SetItem {jid args} {    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    variable inroster
    variable sortID

    ::Debug 2 "::Roster::SetItem jid=$jid, args='$args'"
    
    # Remove any old items first:
    # 1) If we 'get' the roster, the roster is cleared, so we can be
    #    sure that we don't have any "old" item???
    # 2) Must remove all resources for this jid first, and then add back.
    #    Remove also jid2.

    set jlib $jstate(jlib)
    
    if {!$inroster} {
    	set resList [$jlib roster getresources $jid]
	if {$resList ne {}} {
	    foreach res $resList {
		::RosterTree::StyleDeleteItem $jid/$res
	    }
	} else {
	    ::RosterTree::StyleDeleteItem $jid
	}
    }
    
    set add 1
    if {!$jprefs(rost,allowSubNone)} {
	
	# Do not add items with subscription='none'.
	if {[set idx [lsearch $args "-subscription"]] >= 0} {
	    if {[string equal [lindex $args [incr idx]] "none"]} {
		set add 0
	    }
	}
    }
    
    if {$add} {
    
	# Add only the one with highest priority.
	jlib::splitjid $jid jid2 res
	set res [$jlib roster gethighestresource $jid2]
	array set pres [$jlib roster getpresence $jid2 -resource $res]
	
	if {$res ne ""} {
	    set jid $jid/$res
	}
	
	# Put in our roster tree. Append any resource if available.
	set items [eval {
	    ::RosterTree::StyleCreateItem $jid $pres(-type)
	} $args [array get pres]]
	
	if {!$inroster && ![info exists sortID] && [llength $items]} {
	    set pitem [::RosterTree::GetParent [lindex $items end]]
	    set sortID [after idle [namespace current]::SortIdle $pitem]
       }
    }
}

# Roster::Presence --
#
#       Sets the presence of the jid in our UI.
#
# Arguments:
#       jid         the JID as reported by the presence 'from' attribute.
#       presence    "available", "unavailable"
#       args        list of '-key value' pairs of presence attributes.
#       
# Results:
#       roster tree updated.

proc ::Roster::Presence {jid presence args} {
    variable timer
    variable sortID
    variable icons
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Roster::Presence jid=$jid, presence=$presence"
    array set argsArr $args

    # All presence have a 3-tier jid as 'from' attribute:
    # presence = 'available'   => remove jid2 + jid3,  add jid3
    # presence = 'unavailable' => remove jid2 + jid3,  add jid2
    #                                                  if no jid2/* available
    # Wrong! We may have 2-tier jids from transports:
    # <presence from='user%hotmail.com@msn.myserver' ...
    # Or 3-tier (icq) with presence = 'unavailable' !
    # 
    # New: For available JID always use the JID as reported in the
    #      presence 'from' attribute.
    #      For unavailable JID always us the roster item JID.

    set jlib $jstate(jlib)
    set rjid [$jlib roster getrosterjid $jid]
        
    # This gets a list '-name ... -groups ...' etc. from our roster.
    set itemAttr [$jlib roster getrosteritem $rjid]
    
    # First remove if there, then add in the right tree dir.
    ::RosterTree::StyleDeleteItem $jid

    set items {}
    
    # Put in our roster tree.
    if {[string equal $presence "unavailable"]} {
	
	# XMPP specifies that an 'unavailable' element is sent *after* 
	# we've got a subscription='remove' element. Skip it!
	# Problems with transports that have /registered?
	
	::RosterTree::FreeItemAlternatives $jid
	
	# Add only to offline if no other jid2/* available.
	# If not in roster we don't get 'isavailable'.
	set isavailable [$jlib roster isavailable $rjid]
	if {!$isavailable} {
	    set items [eval {
		::RosterTree::StyleCreateItem $rjid $presence
	    } $itemAttr $args]
	}
    } elseif {[string equal $presence "available"]} {
	if {[IsCoccinella $jid]} {
	    ::RosterTree::StyleCacheAltImage $jid whiteboard $icons(whiteboard12)
	}
	set items [eval {
	    ::RosterTree::StyleCreateItem $jid $presence
	} $itemAttr $args]
    }
    
    # This minimizes the cost of sorting.
    if {[llength $items] && ![info exists sortID]} {
	set pitem [::RosterTree::GetParent [lindex $items end]]
	set sortID [after idle [namespace current]::SortIdle $pitem]
    }
    
    # We set timed messages for presences only if significantly after login.
    if {[expr [clock seconds] - $timer(exitroster,secs)] > $timer(pres,secs)} {
	eval {SetPresenceMessage $jid $presence} $args
    }
}

proc ::Roster::InRoster {} {
    variable inroster

    return $inroster
}

# Roster::IsCoccinella --
# 
#       Utility function to figure out if we have evidence that jid3 is a 
#       Coccinella.
#       NOTE: some entities (transports) return private presence elements
#       when sending their presence! Workaround! BAD!!!

proc ::Roster::IsCoccinella {jid3} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns
    upvar ::Jabber::xmppxmlns xmppxmlns
    
    set ans 0
    if {![IsTransportHeuristics $jid3]} {
	set node [$jstate(jlib) roster getcapsattr $jid3 node]
	if {[string equal $node $coccixmlns(caps)]} {
	    set ans 1
	}
    }
    return $ans
}

proc ::Roster::GetPresenceIconFromKey {key} {

    return [::Rosticons::Get status/$key]
}

# Roster::GetPresenceIconFromJid --
# 
#       Returns presence icon from jid, typically a full jid.

proc ::Roster::GetPresenceIconFromJid {jid} {
    upvar ::Jabber::jstate jstate
    
    set jlib $jstate(jlib)
    jlib::splitjid $jid jid2 res
    if {$res eq ""} {
	set pres [lindex [$jlib roster getpresence $jid2] 0]
    } else {
	set pres [$jlib roster getpresence $jid2 -resource $res]
    }
    set rost [$jlib roster getrosteritem $jid2]
    array set argsArr $pres
    array set argsArr $rost
    
    return [eval {GetPresenceIcon $jid $argsArr(-type)} [array get argsArr]]
}

# Roster::GetPresenceIcon --
#
#       Returns the image appropriate for 'presence', and any 'show' attribute.
#       If presence is to make sense, the jid shall be a 3-tier jid.

proc ::Roster::GetPresenceIcon {jid presence args} {    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    array set argsArr $args
    
    ::Debug 4 "GetPresenceIcon jid=$jid, presence=$presence, args=$args"
    
    # Construct the 'type/sub' specifying the icon.
    set itype status
    set isub  $presence
    
    # Then see if any <show/> element
    if {$presence eq "available"} {
	if {[info exists argsArr(-show)]} {
	    set isub $argsArr(-show)
	}
    } elseif {[info exists argsArr(-subscription)] &&   \
      [string equal $argsArr(-subscription) "none"]} {
	set isub "ask"
    } elseif {[info exists argsArr(-ask)] &&   \
      [string equal $argsArr(-ask) "subscribe"]} {
	set isub "ask"
    }
    
    # Foreign IM systems.
    set foreign 0
    jlib::splitjidex $jid user host res
    if {![string equal $host $jserver(this)]} {
	
	# If empty we have likely not yet browsed etc.
	set cattype [lindex [$jstate(jlib) disco types $host] 0]
	set subtype [lindex [split $cattype /] 1]
	if {[lsearch -exact [::Rosticons::GetTypes] $subtype] >= 0} {
	    set itype $subtype
	    set foreign 1
	}
    }
    
    # If whiteboard:
    if {!$foreign && $jprefs(rost,useWBrosticon) &&  \
      ($presence eq "available") && [IsCoccinella $jid]} {
	set itype "whiteboard"
    }
    
    return [::Rosticons::Get $itype/$isub]
}

proc ::Roster::GetMyPresenceIcon { } {

    set status [::Jabber::GetMyStatus]
    return [::Rosticons::Get status/$status]
}

proc ::Roster::DirectedPresenceDlg {jid} {
    global  this wDlgs
    
    variable uid
    
    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::dirpres[incr uid]
    variable $token
    upvar 0 $token state

    set w $wDlgs(jdirpres)$uid
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {Set Directed Presence}]
    set state(finished) -1
    set state(w)        $w
    set state(jid)      $jid
    set state(status) available
    bind $w <Destroy> [list [namespace current]::DirectedPresenceFree $token %W]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1

    label $w.frall.lmsg -wraplength 200 -justify left -text  \
      [mc jadirpresmsg $jid]
    pack  $w.frall.lmsg -side top -anchor w -padx 4 -pady 1
    
    set fr $w.frall.fstat
    pack [frame $fr -bd 0] -side top -fill x
    pack [label $fr.l -text "[mc Status]:"] -side left -padx 8
    set wmb $fr.mb

    ::Jabber::Status::Button $wmb $token\(status)
    
    pack $wmb -side left -padx 2 -pady 2
    
    # Any status message.   
    pack [label $w.frall.lstat -text "[mc {Status message}]:"]  \
      -side top -anchor w -padx 8 -pady 2
    set wtext $w.frall.txt
    text $wtext -width 40 -height 2 -wrap word
    pack $wtext -side top -padx 8 -pady 2
    set state(wtext) $wtext
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Set] -default active \
      -command [list [namespace current]::SetDirectedPresence $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list destroy $w]] \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> {}
	
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $w.frall.lmsg $w]    
    after idle $script
}

proc ::Roster::SetDirectedPresence {token} {
    variable $token
    upvar 0 $token state
    
    set opts {}
    set allText [string trim [$state(wtext) get 1.0 end] " \n"]
    if {[string length $allText]} {
	set opts [list -status $allText]
    }  
    eval {::Jabber::SetStatus $state(status) -to $state(jid)} $opts
    destroy $state(w)
}

proc ::Roster::DirectedPresenceFree {token w} {
    variable $token
    upvar 0 $token state
    
    if {[string equal [winfo toplevel $w] $w]} {
	unset state
    }
}

proc ::Roster::LoginTrpt {jid3} {
    
    ::Jabber::SetStatus available -to $jid3
}

proc ::Roster::LogoutTrpt {jid3} {
    
    ::Jabber::SetStatus unavailable -to $jid3    
}

proc ::Roster::ShowOffline {} {

    # Need to repopulate the roster?
    RepopulateTree
}

proc ::Roster::ShowTransports {} {
    
    # Need to repopulate the roster?
    RepopulateTree
}

#--- Transport utilities -------------------------------------------------------

namespace eval ::Roster:: {
    
    # name description ...
    # Excluding smtp since it works differently.
    variable trptToAddressName {
	jabber      {Jabber ID}
	icq         {ICQ (number)}
	aim         {AIM}
	msn         {MSN}
	yahoo       {Yahoo}
	irc         {IRC}
	x-gadugadu  {Gadu-Gadu}
    }
    variable trptToName {
	jabber      {Jabber}
	icq         {ICQ}
	aim         {AIM}
	msn         {MSN}
	yahoo       {Yahoo}
	irc         {IRC}
	gadugadu    {Gadu-Gadu}
	x-gadugadu  {Gadu-Gadu}
    }
    variable nameToTrpt {
	{Jabber}           jabber
	{ICQ}              icq
	{AIM}              aim
	{MSN}              msn
	{Yahoo}            yahoo
	{IRC}              irc
	{Gadu-Gadu}        x-gadugadu
    }
    
    variable  trptToNameArr
    array set trptToNameArr $trptToName
    
    variable  nameToTrptArr
    array set nameToTrptArr $nameToTrpt
    
    variable allTransports {}
    foreach {name spec} $trptToName {
	lappend allTransports $name
    }
}

proc ::Roster::GetNameFromTrpt {trpt} {
    variable  trptToNameArr
   
    if {[info exists trptToNameArr($trpt)]} {
	return $trptToNameArr($trpt)
    } else {
	return $trpt
    }
}

proc ::Roster::GetTrptFromName {type} {
    variable nameToTrptArr
   
    if {[info exists nameToTrptArr($type)]} {
	return $nameToTrptArr($type)
    } else {
	return $type
    }
}

# Roster::GetAllTransportJids --
# 
#       Method to get the jids of all services that are not jabber.

proc ::Roster::GetAllTransportJids { } {
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jstate jstate
    
    set alltrpts [$jstate(jlib) disco getjidsforcategory "gateway/*"]
    set jabbjids [$jstate(jlib) disco getjidsforcategory "gateway/jabber"]
    
    # Exclude jabber services and login server.
    foreach jid $jabbjids {
	set alltrpts [lsearch -all -inline -not $alltrpts $jid]
    }
    return [lsearch -all -inline -not $alltrpts $jserver(this)]
}

proc ::Roster::GetTransportNames {token} {
    variable $token
    upvar 0 $token state
    variable trptToName
    variable allTransports
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    set trpts {}
    foreach subtype $allTransports {
	set jids [$jstate(jlib) disco getjidsforcategory "gateway/$subtype"]
	if {[llength $jids]} {
	    lappend trpts $subtype
	    set state(servicejid,$subtype) [lindex $jids 0]
	}
    }    

    # Disco doesn't return jabber. Make sure it's first.
    set trpts [lsearch -all -not -inline $trpts jabber]
    set trpts [concat jabber $trpts]
    set state(servicejid,jabber) $jserver(this)

    array set arr $trptToName
    set names {}
    foreach name $trpts {
	lappend names $arr($name)
    }
    return $names
}

proc ::Roster::IsTransport {jid} {
    upvar ::Jabber::jstate jstate
    
    # Some transports (icq) have a jid = icq.jabber.se/registered
    # in the roster, but where we get the 2-tier part. Get 3-tier jid.
    set transport 0
    if {![catch {jlib::splitjidex $jid node host res}]} {
	if {([lsearch [GetAllTransportJids] $host] >= 0) && ($node eq "")} {    
	    set transport 1
	}
    }    
    return $transport
}

# This is a really BAD thing to do but I there seems to be no robust method.
# I really hate do do this!
# Use 'IsTransport' to get a true answer.

proc ::Roster::IsTransportHeuristics {jid} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    # Some transports (icq) have a jid = icq.jabber.se/registered and
    # yahoo.jabber.ru/registered
    # Others, like MSN, have a jid = msn.jabber.ccc.de.
    set transport 0
    if {![catch {jlib::splitjidex $jid node host res}]} {
	if {$node eq ""} {
	    if {$res eq "registered"} {
		set transport 1
	    } else {
		
		# Search for matching  msn.$jserver(this)  etc.
		set idx [string first . $host]
		if {$idx > 0} {
		    set phost [string range $host [expr {$idx+1}] end]
		    if {$phost eq $jserver(this)} {
			set cname [string range $host 0 [expr {$idx-1}]]
			switch -- $cname {
			    aim - gadugadu - icq - msn - smtp - yahoo {			
				set transport 1
			    }
			}
		    }
		}
	    }
	}
    }
    if {!$transport} {
	set transport [IsTransport $jid]
    }
    return $transport
}

proc ::Roster::GetUsersWithSameHost {jid} {
    upvar ::Jabber::jstate jstate

    set jidlist {}
    jlib::splitjidex $jid - host -

    foreach ujid [$jstate(jlib) roster getusers] {
	jlib::splitjidex $ujid - uhost -
	if {$host eq $uhost} {
	    lappend jidlist $ujid
	}
    }
    return $jidlist
}

proc ::Roster::RemoveUsers {jidlist} {
    upvar ::Jabber::jstate jstate

    foreach jid $jidlist {
	$jstate(jlib) roster send_remove $jid
    }
}

# Prefs page ...................................................................

proc ::Roster::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...
    set jprefs(rost,rmIfUnsub)      1
    set jprefs(rost,allowSubNone)   1
    set jprefs(rost,clrLogout)      1
    set jprefs(rost,dblClk)         chat
    set jprefs(rost,showOffline)    1
    set jprefs(rost,showTrpts)      1
    set jprefs(rost,sort)          +1
    
    set jprefs(rost,useWBrosticon)  0
    
    # Keep track of all closed tree items. Default is all open.
    set jprefs(rost,closedItems) {}
	
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(rost,clrLogout)   jprefs_rost_clrRostWhenOut $jprefs(rost,clrLogout)]  \
      [list ::Jabber::jprefs(rost,dblClk)      jprefs_rost_dblClk       $jprefs(rost,dblClk)]  \
      [list ::Jabber::jprefs(rost,rmIfUnsub)   jprefs_rost_rmIfUnsub    $jprefs(rost,rmIfUnsub)]  \
      [list ::Jabber::jprefs(rost,allowSubNone) jprefs_rost_allowSubNone $jprefs(rost,allowSubNone)]  \
      [list ::Jabber::jprefs(rost,showOffline) jprefs_rost_showOffline  $jprefs(rost,showOffline)]  \
      [list ::Jabber::jprefs(rost,showTrpts)   jprefs_rost_showTrpts    $jprefs(rost,showTrpts)]  \
      [list ::Jabber::jprefs(rost,closedItems) jprefs_rost_closedItems  $jprefs(rost,closedItems)]  \
      ]
    
}

proc ::Roster::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {Jabber Roster} [mc Roster]
        
    # Roster page ----------------------------------------------------------
    set wpage [$nbframe page {Roster}]
    BuildPageRoster $wpage
}

proc ::Roster::BuildPageRoster {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    foreach key {
	rmIfUnsub allowSubNone clrLogout dblClk showOffline showTrpts
    } {
	set tmpJPrefs(rost,$key) $jprefs(rost,$key)
    }

    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    ttk::checkbutton $wc.rmifunsub -text [mc prefrorm]  \
      -variable [namespace current]::tmpJPrefs(rost,rmIfUnsub)
    ttk::checkbutton $wc.allsubno -text [mc prefroallow]  \
      -variable [namespace current]::tmpJPrefs(rost,allowSubNone)
    ttk::checkbutton $wc.clrout -text [mc prefroclr]  \
      -variable [namespace current]::tmpJPrefs(rost,clrLogout)
    ttk::checkbutton $wc.dblclk -text [mc prefrochat] \
      -variable [namespace current]::tmpJPrefs(rost,dblClk)  \
      -onvalue chat -offvalue normal
    ttk::checkbutton $wc.hideoff -text [mc prefrohideoff] \
      -variable [namespace current]::tmpJPrefs(rost,showOffline) \
      -onvalue 0 -offvalue 1
    ttk::checkbutton $wc.hidetrpt -text [mc prefrohidetrpt] \
      -variable [namespace current]::tmpJPrefs(rost,showTrpts) \
      -onvalue 0 -offvalue 1
    
    # My avatar.
    ::Avatar::PrefsFrame $wc.ava

    grid  $wc.rmifunsub  -sticky w
    grid  $wc.allsubno   -sticky w
    grid  $wc.clrout     -sticky w
    grid  $wc.dblclk     -sticky w
    grid  $wc.hideoff    -sticky w
    grid  $wc.rmifunsub  -sticky w
    grid  $wc.hidetrpt   -sticky w
    
    grid  $wc.ava        -sticky ew -pady 4
    
}

proc ::Roster::SavePrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    ::Avatar::PrefsSave
    
    # Need to repopulate the roster?
    if {$jprefs(rost,showOffline) != $tmpJPrefs(rost,showOffline)} {
	set jprefs(rost,showOffline) $tmpJPrefs(rost,showOffline)
	RepopulateTree
    }
    array set jprefs [array get tmpJPrefs]
    unset tmpJPrefs
}

proc ::Roster::CancelPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
    
    ::Avatar::PrefsCancel
}

proc ::Roster::UserDefaultsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
