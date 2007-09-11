#  Roster.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Roster GUI part.
#      
#  Copyright (c) 2001-2007  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: Roster.tcl,v 1.214 2007-09-11 07:07:44 matben Exp $

# @@@ TODO: 1) rewrite the popup menu code to use AMenu!
#           2) abstract all RosterTree calls to allow for any kind of roster

package require ui::openimage
package require RosterTree
package require RosterPlain
package require RosterTwo
package require RosterAvatar
package require UI::TSearch

package provide Roster 1.0

namespace eval ::Roster:: {
    global  this prefs
    
    # Add all event hooks we need.
    ::hooks::register earlyInitHook          ::Roster::EarlyInitHook
    ::hooks::register loginHook              ::Roster::LoginCmd
    ::hooks::register logoutHook             ::Roster::LogoutHook
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
    option add *Roster.padding              4               50
    option add *Roster*WaveLabel.borderWidth  0             50
        
    # Specials.
    option add *Roster.waveImage            wave            widgetDefault
    option add *Roster.minimalPadding       {0}             widgetDefault
    option add *Roster.whiteboard12Image    whiteboard12    widgetDefault
    
    variable wtree -
    
    # A unique running identifier.
    variable uid 0
    
    # Keep track of when in roster callback.
    variable inroster 0

    # Keeps track of all registered menu entries.
    variable regPopMenuDef  [list]
    variable regPopMenuType [list]

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
    
    # Various time values.
    variable timer
    set timer(msg,ms) 10000
    set timer(exitroster,secs) 0
    set timer(pres,secs) 4
}

proc ::Roster::EarlyInitHook {} {
    InitMenus
}

proc ::Roster::InitMenus {} {

    # Template for the roster popup menu.
    variable popMenuDefs
      
    # Standard popup menu.
    set mDefs {
	{command     mMessage         {::NewMsg::Build -to $jid -tolist $jidlist} }
	{command     mChat...         {::Chat::StartThread $jid3} }
	{command     mSendFile...     {::FTrans::Send $jid3} }
	{separator}
	{command     mAddContact...   {::JUser::NewDlg} }
	{command     mEditContact...  {::JUser::EditDlg $jid} }
	{command     mBusinessCard... {::UserInfo::Get $jid3} }
	{command     mChatHistory     {::Chat::BuildHistoryForJid $jid} }
	{command     mRemoveContact   {::Roster::SendRemove $jid} }
	{separator}
	{cascade     mShow            {
	    {check     mOffline       {::Roster::ShowOffline}    {-variable ::Jabber::jprefs(rost,showOffline)} }
	    {check     mTransports    {::Roster::ShowTransports} {-variable ::Jabber::jprefs(rost,showTrpts)} }
	    {command   mBackgroundImage...  {::Roster::BackgroundImage} }
	} }
	{cascade     mSort            {
	    {radio     mIncreasing    {::Roster::Sort}  {-variable ::Jabber::jprefs(rost,sort) -value -increasing} }
	    {radio     mDecreasing    {::Roster::Sort}  {-variable ::Jabber::jprefs(rost,sort) -value -decreasing} }
	} }
	{cascade     mStyle           {@::Roster::StyleMenu} }
	{command     mRefreshRoster   {::Roster::Refresh} }
    }
    set mTypes {
	{mMessage       {head group user}     }
	{mChat...       {user available}      }
	{mWhiteboard    {wb available}        }
	{mSendFile...   {user available}      }
	{mAddContact... {}                    }
	{mEditContact...  {user}              }
	{mBusinessCard... {user}              }
	{mChatHistory   {user always}         }
	{mRemoveContact {user}                }
	{mShow          {normal}           {
	    {mOffline     {normal}            }
	    {mTransports  {normal}            }
	    {mBackgroundImage... {normal}     }
	}}
	{mSort          {}                 {
	    {mIncreasing  {}                  }
	    {mDecreasing  {}                  }
	}}
	{mStyle         {normal}              }
	{mRefreshRoster {}                    }
    }
    if {[::Jabber::HaveWhiteboard]} {
	set mWBDef  {command     mWhiteboard      {::JWB::NewWhiteboardTo $jid3}}
	set mWBType {mWhiteboard    {wb available}        }
	
	# Insert whiteboard menu *after* Chat.
	set idx [lsearch -glob $mDefs "* mChat... *"]
	incr idx
	set mDefs  [linsert $mDefs $idx $mWBDef]
	set mTypes [linsert $mTypes $idx $mWBType]
    }
    set popMenuDefs(roster,def)  $mDefs
    set popMenuDefs(roster,type) $mTypes
    
    # Transports popup menu.
    set mDefs {
	{command     mLastLogin/Activity  {::Jabber::GetLast $jid} }
	{command     mvCard2              {::VCard::Fetch other $jid} }
	{command     mAddContact...       {::JUser::NewDlg} }
	{command     mEditContact...      {::JUser::EditDlg $jid} }
	{command     mVersion             {::Jabber::GetVersion $jid3} }
	{command     mLoginTrpt           {::Roster::LoginTrpt $jid3} }
	{command     mLogoutTrpt          {::Roster::LogoutTrpt $jid3} }
	{separator}
	{command     mUnregister          {::Register::Remove $jid3} }
	{command     mRefreshRoster       {::Roster::Refresh} }
    }  
    set mTypes {
	{mLastLogin/Activity  {user}                }
	{mvCard2              {user}                }
	{mAddContact...       {}                    }
	{mEditContact...      {user}                }
	{mVersion             {user}                }
	{mLoginTrpt           {trpt unavailable}    }
	{mLogoutTrpt          {trpt available}      }
	{mUnregister          {trpt}                }
	{mRefreshRoster       {}                    }
    }  
    set popMenuDefs(roster,trpt,def)  $mDefs
    set popMenuDefs(roster,trpt,type) $mTypes
}

proc ::Roster::JabberInitHook {jlibname} {
    
    $jlibname presence_register available [namespace code PresenceEvent]   
    $jlibname presence_register unavailable [namespace code PresenceEvent]   
}

# Roster::GetNameOrJID, GetShortName, GetDisplayName --
# 
#       Utilities to get JID identifiers for UI display.
#       Priorities:
#         1) name attribute in roster item
#         2) user nickname
#         3) node part if on login server
#         4) JID

proc ::Roster::GetNameOrJID {jid} {
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
	set name [::Nickname::Get [jlib::barejid $jid]]
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
    }
    return $name
}

proc ::Roster::GetDisplayName {jid} {
    upvar ::Jabber::jstate jstate
    
    set name [$jstate(jlib) roster getname $jid]
    if {$name eq ""} {
	set name [::Nickname::Get [jlib::barejid $jid]]
	if {$name eq ""} {	
	    jlib::splitjidex $jid node domain res
	    if {$node eq ""} {
		set name $domain
	    } else {
		set name [jlib::unescapestr $node]
	    }
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
    set wwave   $w.wa
    set rstyle  "normal"
    
    # DIdn't help the grid bug.
    #ttk::label $w.pad -compound image -image [::UI::GetIcon blank-1x1]
    #pack $w.pad -side bottom -fill x    
    
    set waveImage [::Theme::GetImage [option get $w waveImage {}]]  
    ::wavelabel::wavelabel $wwave -type image -image $waveImage
    pack $wwave -side bottom -fill x -padx 8 -pady 2
        
    # @@@ We shall have a more generic interface here than just a tree.
    set wtree [::RosterTree::New $wbox]
    pack $wbox -side top -fill both -expand 1
    
    # Cache any expensive stuff.
    set icons(whiteboard12) [::Theme::GetImage [option get $w whiteboard12Image {}]]
   
    # Handle the prefs "Show" state.
    if {$jprefs(ui,main,show,minimal)} {
	StyleMinimal
    }
    return $w
}

proc ::Roster::GetTree {} {
    variable wtree    
    return $wtree
}

proc ::Roster::Find {} {
    ::RosterTree::Find
}

proc ::Roster::FindAgain {dir} {
    ::RosterTree::FindAgain $dir
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

proc ::Roster::StyleMinimal {} {
    variable wroster
    variable wbox
    variable wwave
    variable rstyle
    
    $wroster configure -padding [option get $wroster minimalPadding {}]
    $wbox configure -bd 0
    pack forget $wwave
    set rstyle "minimal"
}

proc ::Roster::StyleNormal {} {
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

proc ::Roster::StyleGet {} {
    variable rstyle

    return $rstyle
}

proc ::Roster::GetRosterWindow {} {
    variable wroster
    
    return $wroster
}

proc ::Roster::BackgroundImage {} {
    ::RosterTree::BackgroundImageCmd
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

proc ::Roster::CancelTimedMessage {} {

    Message ""
}

proc ::Roster::SetPresenceMessage {jid presence args} {
    
    array set argsA $args
    set show $presence
    if {[info exists argsA(-show)]} {
	set show $argsA(-show)
    }
    set name [GetDisplayName $jid]
    TimedMessage "$name [mc $show]"
}

# Roster::LoginCmd --
# 
#       The login hook command.

proc ::Roster::LoginCmd {} {
    upvar ::Jabber::jstate jstate

    $jstate(jlib) roster send_get

    set server [::Jabber::GetServerJid]
}

proc ::Roster::LogoutHook {} {
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

proc ::Roster::Refresh {} {
    variable wwave
    upvar ::Jabber::jstate jstate

    ::RosterTree::GetClosed
    
    # Get my roster.
    $jstate(jlib) roster send_get
    $wwave animate 1
}

proc ::Roster::SortAtIdle {{item root}} {
    upvar ::Jabber::jprefs jprefs

    ::RosterTree::SortAtIdle $item $jprefs(rost,sort)
}

proc ::Roster::Sort {{item root}} {
    upvar ::Jabber::jprefs jprefs

    ::RosterTree::Sort $item $jprefs(rost,sort)
}

# Roster::SendRemove --
#
#       Method to remove another user from my roster.

proc ::Roster::SendRemove {jidrm} {    
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Roster::SendRemove jidrm=$jidrm"

    set jid $jidrm

    set ans [::UI::MessageBox -title [mc {Remove Contact}] \
      -message [mc jamesswarnremove2] -icon warning -type yesno -default no]
    if {[string equal $ans "yes"]} {
	$jstate(jlib) roster send_remove $jid
    }
}
    
# Roster::RegisterPopupEntry --
# 
#       Components or plugins can add their own menu entries here.
#       Only for the standard popup menu.

proc ::Roster::RegisterPopupEntry {menuDef menuType} {
    variable regPopMenuDef
    variable regPopMenuType
    
    lappend regPopMenuDef  $menuDef
    lappend regPopMenuType $menuType
}

proc ::Roster::DeRegisterPopupEntry {mLabel} {
    variable regPopMenuDef
    variable regPopMenuType
    
    set idx [lsearch -glob $regPopMenuDef "* $mLabel *"]
    if {$idx >= 0} {
	set regPopMenuDef [lreplace $regPopMenuDef $idx $idx]
    }
    set idx [lsearch -glob $regPopMenuType "$mLabel *"]
    if {$idx >= 0} {
	set regPopMenuType [lreplace $regPopMenuType $idx $idx]
    }
}

# Roster::DoPopup --
#
#       Handle popup menu in roster.
#       
# Arguments:
#       jidL        this is a list of actual jid's, can be any form
#       clicked
#       status      'available', 'unavailable'
#       group       name of group if any
#       
# Results:
#       popup menu displayed

proc ::Roster::DoPopup {jidL clicked status group x y} {
    global  wDlgs
    variable popMenuDefs
    variable regPopMenuDef
    variable regPopMenuType
    variable wtree
        
    ::Debug 2 "::Roster::DoPopup jidL=$jidL, clicked=$clicked, status=$status, group=$group"

    # We always get a list of jids, typically with only one element.
    set jid3 [lindex $jidL 0]
    set jid2 [jlib::barejid $jid3]
    set jid $jid2

    # The jidlist is expected to be with no resource part.
    set jidlist [list]
    foreach u $jidL {
	lappend jidlist [jlib::barejid $u]
    }

    set specialMenu 0
    foreach click $clicked {
	if {[info exists popMenuDefs(roster,$click,def)]} {
	    set mDef  $popMenuDefs(roster,$click,def)
	    set mType $popMenuDefs(roster,$click,type)
	    set specialMenu 1
	    break
	}
    }
    if {!$specialMenu} {
    
	# Insert any registered popup menu entries.
	set mDef  $popMenuDefs(roster,def)
	set mType $popMenuDefs(roster,type)
	if {[llength $regPopMenuDef]} {
	    set idx [lindex [lsearch -glob -all $mDef {sep*}] end]
	    if {$idx eq ""} {
		set idx end
	    }
	    foreach line $regPopMenuDef {
		set mDef [linsert $mDef $idx $line]
	    }
	    set mDef [linsert $mDef $idx {separator}]
	}
	set mType [concat $mType $regPopMenuType]
    }
    
    # Make the appropriate menu.
    set m $wDlgs(jpopuproster)
    set i 0
    destroy $m
    menu $m -tearoff 0 \
      -postcommand [list ::Roster::PostMenuCmd $m $mType $clicked $jidL $status]
        
    ::AMenu::Build $m $mDef \
      -varlist [list jid $jid jid3 $jid3 jidlist $jidlist clicked $clicked group $group]

    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks
        
    # Post popup menu.
    set X [expr [winfo rootx $wtree] + $x]
    set Y [expr [winfo rooty $wtree] + $y]
    tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
}

proc ::Roster::PostMenuCmd {m mType clicked jidL status} {

    # Special handling of transport login/logout. Hack!
    if {([llength $jidL] == 1) && ([lsearch $clicked trpt] >= 0)} {
	set midx [::AMenu::GetMenuIndex $m mLoginTrpt]
	if {$midx ne ""} {
	    set jid [lindex $jidL 0]
	    set types [::Jabber::JlibCmd disco types $jid]
	    if {[regexp {gateway/([^ ]+)} $types - trpt]} {
		if {[HaveNameForTrpt $trpt]} {
		    set tname [GetNameFromTrpt $trpt]
		    $m entryconfigure $midx -label [mc mLoginTo $tname]

		    set midx [::AMenu::GetMenuIndex $m mLogoutTrpt]
		    $m entryconfigure $midx -label [mc mLogoutFrom $tname]
		}
	    }
	}
    }
    
    foreach mspec $mType {
	lassign $mspec name type subType
	
	# State of menu entry. 
	# We use the 'type' and 'clicked' lists to set the state.
	set state disabled
	if {$type eq "normal"} {
	    set state normal
	} elseif {$type eq "disabled"} {
	    set state disabled
	} elseif {![::Jabber::IsConnected] && ([lsearch $type always] < 0)} {
	    set state disabled
	} elseif {[listintersectnonempty $type $clicked]} {
	    set state normal
	} elseif {$type eq ""} {
	    set state normal
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

	set midx [::AMenu::GetMenuIndex $m $name]
	if {[string equal $state "disabled"]} {
	    $m entryconfigure $midx -state disabled
	}
	if {[llength $subType]} {
	    set mt [$m entrycget $midx -menu]
	    PostMenuCmd $mt $subType $clicked $jidL $status
	}
    }
    ::hooks::run rosterPostCommandHook $m $jidL $clicked $status  
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

proc ::Roster::RepopulateTree {} {
    upvar ::Jabber::jstate jstate
    
    ::RosterTree::GetClosed
    ::RosterTree::StyleInit
    set jlib $jstate(jlib)
    
    foreach jid [$jlib roster getusers] {
	eval {SetItem $jid} [$jlib roster getrosteritem $jid]
    }
    SortAtIdle
    #Sort
}

proc ::Roster::ExitRoster {} {
    variable wwave
    variable timer

    SortAtIdle
    #Sort
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

    ::Debug 2 "::Roster::SetItem jid=$jid, args='$args'"
    
    # Remove any old items first:
    # 1) If we 'get' the roster, the roster is cleared, so we can be
    #    sure that we don't have any "old" item???
    # 2) Must remove all resources for this jid first, and then add back.
    #    Remove also jid2.

    set jlib $jstate(jlib)

    if {!$inroster} {
    	set resList [$jlib roster getresources $jid]
	if {[llength $resList]} {
	    foreach res $resList {
		::RosterTree::StyleDeleteItem $jid/$res
	    }
	} else {
	    ::RosterTree::StyleDeleteItem $jid
	}
    }
    
    set add 1
    if {!$jprefs(rost,showSubNone)} {
	
	# Do not add items with subscription='none'.
	if {[set idx [lsearch $args "-subscription"]] >= 0} {
	    if {[string equal [lindex $args [incr idx]] "none"]} {
		set add 0
	    }
	}
    }
    if {$add} {
    
	# Add only the one with highest priority.
	set jid2 [jlib::barejid $jid]
	set res [$jlib roster gethighestresource $jid2]
	array set presA [$jlib roster getpresence $jid2 -resource $res]

	# For online users we replace the actual resource with max priority one.
	# Make sure we do not duplicate resource for jid3 roster items!
	if {$res ne ""} {
	    set jid $jid2/$res
	}
	
	# Put in our roster tree. Append any resource if available.
	set items [eval {
	    ::RosterTree::StyleCreateItem $jid $presA(-type)
	} $args [array get presA]]

	if {!$inroster && [llength $items]} {

	    # If more than one item pick the parent of the first (group).
	    set pitem [::RosterTree::GetParent [lindex $items 0]]
	    ::RosterTree::SortAtIdle $pitem $jprefs(rost,sort)
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
    variable icons
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Roster::Presence jid=$jid, presence=$presence"
    array set argsA $args

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

    set items [list]
    
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
    if {[llength $items]} {

	# If more than one item pick the parent of the first (group).
	set pitem [::RosterTree::GetParent [lindex $items 0]]
	::RosterTree::SortAtIdle $pitem $jprefs(rost,sort)
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
    array set argsA $pres
    array set argsA $rost
    
    return [eval {GetPresenceIcon $jid $argsA(-type)} [array get argsA]]
}

# Roster::GetPresenceIcon --
#
#       Returns the image appropriate for 'presence', and any 'show' attribute.
#       If presence is to make sense, the jid shall be a 3-tier jid?

proc ::Roster::GetPresenceIcon {jid presence args} {    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    array set argsA $args
    
    ::Debug 6 "GetPresenceIcon jid=$jid, presence=$presence, args=$args"
    
    # Construct the 'type/sub' specifying the icon.
    set itype status
    set isub  $presence
    
    # Then see if any <show/> element
    if {$presence eq "available"} {
	if {[info exists argsA(-show)]} {
	    set isub $argsA(-show)
	}
    } elseif {[info exists argsA(-subscription)] &&   \
      [string equal $argsA(-subscription) "none"]} {
	set isub "ask"
    } elseif {[info exists argsA(-ask)] &&   \
      [string equal $argsA(-ask) "subscribe"]} {
	set isub "ask"
    }
    
    # Foreign IM systems.
    set foreign 0
    jlib::splitjidex $jid user host res
    if {![jlib::jidequal $host $jstate(server)]} {
	
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

proc ::Roster::GetMyPresenceIcon {} {
    set status [::Jabber::GetMyStatus]
    return [::Rosticons::Get status/$status]
}

proc ::Roster::LoginTrpt {jid3} {
    ::Jabber::SetStatus available -to $jid3
}

proc ::Roster::LogoutTrpt {jid3} {
    ::Jabber::SetStatus unavailable -to $jid3    
}

proc ::Roster::ShowOffline {} {
    RepopulateTree
}

proc ::Roster::ShowTransports {} {
    RepopulateTree
}

#--- Transport utilities -------------------------------------------------------

# @@@ These should eventually move to Gateway!

namespace eval ::Roster:: {
    
    # name description ...
    # Excluding smtp since it works differently.
    variable trptToAddressName {
	jabber      {Jabber ID}
	xmpp        {Jabber ID}
	icq         {ICQ (number)}
	aim         {AIM}
	msn         {MSN}
	yahoo       {Yahoo}
	irc         {IRC}
	x-gadugadu  {Gadu-Gadu}
	gadu-gadu   {Gadu-Gadu}
    }
    variable trptToName {
	jabber      {Jabber}
	xmpp        {Jabber}
	icq         {ICQ}
	aim         {AIM}
	msn         {MSN}
	yahoo       {Yahoo}
	irc         {IRC}
	gadugadu    {Gadu-Gadu}
	gadu-gadu   {Gadu-Gadu}
	x-gadugadu  {Gadu-Gadu}
    }
    variable nameToTrpt {
	{Jabber}           xmpp
	{ICQ}              icq
	{AIM}              aim
	{MSN}              msn
	{Yahoo}            yahoo
	{IRC}              irc
	{Gadu-Gadu}        x-gadugadu
	{Gadu-Gadu}        gadu-gadu
    }
    
    variable  trptToNameArr
    array set trptToNameArr $trptToName
    
    variable  nameToTrptArr
    array set nameToTrptArr $nameToTrpt
    
    variable allTransports [list]
    foreach {name spec} $trptToName {
	lappend allTransports $name
    }
    set allTransports [lsearch -all -inline -not $allTransports "jabber"]
}

proc ::Roster::HaveNameForTrpt {type} {
    variable  trptToNameArr
   
    return [info exists trptToNameArr($type)]
}

proc ::Roster::GetNameFromTrpt {type} {
    variable  trptToNameArr
   
    if {[info exists trptToNameArr($type)]} {
	return $trptToNameArr($type)
    } else {
	return $type
    }
}

proc ::Roster::GetTrptFromName {name} {
    variable nameToTrptArr
   
    if {[info exists nameToTrptArr($name)]} {
	return $nameToTrptArr($name)
    } else {
	return $name
    }
}

# Roster::GetAllTransportJids --
# 
#       Method to get the jids of all services that are not jabber.

proc ::Roster::GetAllTransportJids {} {
    upvar ::Jabber::jstate jstate
    
    set alltrpts [$jstate(jlib) disco getjidsforcategory "gateway/*"]
    set xmppjids [$jstate(jlib) disco getjidsforcategory "gateway/xmpp"]
    
    # Exclude jabber services and login server.
    foreach jid $xmppjids {
	set alltrpts [lsearch -all -inline -not $alltrpts $jid]
    }
    return [lsearch -all -inline -not $alltrpts $jstate(server)]
}

# Roster::GetTransportNames --
# 
#       Utility to get a flat array of 'jid type name' for each transports.

proc ::Roster::GetTransportNames {} {
    variable trptToName
    variable allTransports
    upvar ::Jabber::jstate jstate
    
    set trpts [list]
    foreach type $allTransports {
	if {$type eq "xmpp"} {
	    continue
	}
	set jidL [$jstate(jlib) disco getjidsforcategory "gateway/$type"]
	foreach jid $jidL {
	    lappend trpts [list $jid $type [GetNameFromTrpt $type]]
	}
    }    

    # Disco doesn't return jabber. Make sure it's first.
    return [concat [list [list $jstate(server) xmpp [GetNameFromTrpt jabber]]] $trpts]
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
    
    # Some transports (icq) have a jid = icq.jabber.se/registered and
    # yahoo.jabber.ru/registered
    # Others, like MSN, have a jid = msn.jabber.ccc.de.
    set transport 0
    if {![catch {jlib::splitjidex $jid node host res}]} {
	if {$node eq ""} {
	    if {$res eq "registered"} {
		set transport 1
	    } else {
		
		# Search for matching  msn.$jstate(server)  etc.
		set idx [string first . $host]
		if {$idx > 0} {
		    set phost [string range $host [expr {$idx+1}] end]
		    if {$phost eq $jstate(server)} {
			set cname [string range $host 0 [expr {$idx-1}]]
			switch -- $cname {
			    aim - gg - gadugadu - icq - msn - smtp - yahoo {			
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

#-------------------------------------------------------------------------------

proc ::Roster::GetUsersWithSameHost {jid} {
    upvar ::Jabber::jstate jstate

    set jidL [list]
    jlib::splitjidex $jid - host -

    foreach ujid [$jstate(jlib) roster getusers] {
	jlib::splitjidex $ujid - uhost -
	if {$host eq $uhost} {
	    lappend jidL $ujid
	}
    }
    return $jidL
}

proc ::Roster::RemoveUsers {jidlist} {
    upvar ::Jabber::jstate jstate

    foreach jid $jidlist {
	$jstate(jlib) roster send_remove $jid
    }
}

proc ::Roster::ExportRoster {} {
    set fileName [tk_getSaveFile -defaultextension .xml -initialfile roster.xml]
    if {$fileName ne ""} {
	SaveRosterToFile $fileName
    }
}

proc ::Roster::SaveRosterToFile {fileName} {    
    upvar ::Jabber::jstate jstate
    
    set jlib $jstate(jlib)
    set fd [open $fileName w]
    fconfigure $fd -encoding utf-8

    puts $fd "<?xml version='1.0' encoding='UTF-8'?>"
    puts $fd "<query xmlns='jabber:iq:roster'>"
    foreach jid [$jlib roster getusers] {
	set item [$jlib roster getitem $jid]
	set xml [wrapper::createxml $item]
	puts $fd \t$xml
    }
    puts $fd "</query>"
    close $fd
}

# Prefs page ...................................................................

proc ::Roster::InitPrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...
    set jprefs(rost,rmIfUnsub)      1
    set jprefs(rost,clrLogout)      1
    set jprefs(rost,dblClk)         chat
    set jprefs(rost,showOffline)    1
    set jprefs(rost,showTrpts)      1
    set jprefs(rost,showSubNone)    1
    set jprefs(rost,sort)           -increasing
    
    set jprefs(rost,useWBrosticon)  0
    
    # The rosters background image is partly controlled by option database.
    set jprefs(rost,useBgImage)     1
    set jprefs(rost,defaultBgImage) 1
    
    # Keep track of all closed tree items. Default is all open.
    set jprefs(rost,closedItems) [list]
	
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(rost,clrLogout)   jprefs_rost_clrRostWhenOut $jprefs(rost,clrLogout)]  \
      [list ::Jabber::jprefs(rost,dblClk)      jprefs_rost_dblClk       $jprefs(rost,dblClk)]  \
      [list ::Jabber::jprefs(rost,rmIfUnsub)   jprefs_rost_rmIfUnsub    $jprefs(rost,rmIfUnsub)]  \
      [list ::Jabber::jprefs(rost,showSubNone) jprefs_rost_showSubNone  $jprefs(rost,showSubNone)]  \
      [list ::Jabber::jprefs(rost,showOffline) jprefs_rost_showOffline  $jprefs(rost,showOffline)]  \
      [list ::Jabber::jprefs(rost,showTrpts)   jprefs_rost_showTrpts    $jprefs(rost,showTrpts)]  \
      [list ::Jabber::jprefs(rost,closedItems) jprefs_rost_closedItems  $jprefs(rost,closedItems)]  \
      [list ::Jabber::jprefs(rost,useBgImage)  jprefs_rost_useBgImage   $jprefs(rost,useBgImage)]  \
      [list ::Jabber::jprefs(rost,defaultBgImage) jprefs_rost_defaultBgImage  $jprefs(rost,defaultBgImage)]  \
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
	rmIfUnsub showSubNone clrLogout dblClk showOffline showTrpts
    } {
	set tmpJPrefs(rost,$key) $jprefs(rost,$key)
    }

    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    ttk::checkbutton $wc.rmifunsub -text [mc prefrorm]  \
      -variable [namespace current]::tmpJPrefs(rost,rmIfUnsub)
    ttk::checkbutton $wc.clrout -text [mc prefroclr]  \
      -variable [namespace current]::tmpJPrefs(rost,clrLogout)
    ttk::checkbutton $wc.dblclk -text [mc prefrochat] \
      -variable [namespace current]::tmpJPrefs(rost,dblClk)  \
      -onvalue chat -offvalue normal
    ttk::checkbutton $wc.showoff -text [mc "Show offline users"] \
      -variable [namespace current]::tmpJPrefs(rost,showOffline)
    ttk::checkbutton $wc.showtrpt -text [mc "Show transports"] \
      -variable [namespace current]::tmpJPrefs(rost,showTrpts)
    ttk::checkbutton $wc.showsubno -text [mc prefroshowsubno]  \
      -variable [namespace current]::tmpJPrefs(rost,showSubNone)
    
    grid  $wc.rmifunsub  -sticky w
    grid  $wc.clrout     -sticky w
    grid  $wc.dblclk     -sticky w
    grid  $wc.rmifunsub  -sticky w
    grid  $wc.showoff    -sticky w
    grid  $wc.showtrpt   -sticky w
    grid  $wc.showsubno  -sticky w
    
}

proc ::Roster::SavePrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    #::Avatar::PrefsSave
    
    # Need to repopulate the roster?
    if {$jprefs(rost,showOffline) != $tmpJPrefs(rost,showOffline)} {
	set jprefs(rost,showOffline) $tmpJPrefs(rost,showOffline)
	RepopulateTree
    }
    array set jprefs [array get tmpJPrefs]
    unset tmpJPrefs
}

proc ::Roster::CancelPrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
    
    #::Avatar::PrefsCancel
}

proc ::Roster::UserDefaultsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
