#  Subscribe.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements subscription parts.
#      
#  Copyright (c) 2001-2008  Mats Bengtsson
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
# $Id: Subscribe.tcl,v 1.75 2008-04-22 12:40:30 matben Exp $

package provide Subscribe 1.0

namespace eval ::Subscribe {

    # Use option database for customization.
    option add *JSubscribe.adduserImage       contact-new         widgetDefault
    option add *JSubscribe.adduserDisImage    contact-new-Dis     widgetDefault    
    option add *JSubscribe.vcardImage         vcard               widgetDefault
    
    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Subscribe::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Subscribe::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Subscribe::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Subscribe::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Subscribe::UserDefaultsHook

    # Store everything in 'locals($uid, ... )'.
    variable locals   
    variable uid 0
    
    # Show head label in subcription dialog.
    set ::config(subscribe,show-head) 1

    # Use name and group in dialog?
    set ::config(subscribe,show-nick-group) 0
    
    # In the normal subscription dialog, where shall the vcard button be?
    # If we don't show nickname then "nqme" wont display either.
    set ::config(subscribe,ui-vcard-pos) "button"  ;# name | button
    
    # Millis to wait for a second subsciption request to show in multi dialog.
    set ::config(subscribe,multi-wait-ms) 2000
    
    # Use the multi dialog for batches of subscription requests.
    set ::config(subscribe,multi-dlg) 1
    
    # Sets a timer in the standard "ask" dialogs to auto accept.
    # NB: some of these options now in jprefs.
    #set ::config(subscribe,auto-accept-std-dlg) 1
    
    # Set a timer dialog instead of just straight auto accepting.
    # This just shows a plain dialog for each request.
    # NB: string catalogs must be updated if using this.
    set ::config(subscribe,auto-accept-plain) 0
    
    # Sets a timer in the standard "ask" dialogs to auto reject.
    #set ::config(subscribe,auto-reject-std-dlg) 1
    
    # Set a timer dialog instead of just straight auto rejecting.
    # This just shows a plain dialog for each request.
    # NB: string catalogs must be updated if using this.
    set ::config(subscribe,auto-reject-plain) 0
       
    # Sets the number of millisecs the dialog starts its countdown.
    set ::config(subscribe,accept-after) 10000
    set ::config(subscribe,reject-after) 10000
    
    # Shall we send a message to user when one of the auto dispatchers done.
    set ::config(subscribe,auto-accept-send-msg) 0
    set ::config(subscribe,auto-reject-send-msg) 0

    set nonAqua [expr {[tk windowingsystem] ne "aqua"}]
    
    # Experimental:
    # NB: buggy on Aqua 8.4.9
    set ::config(subscribe,exp-scrollframe) $nonAqua
    
    variable queue [list]
}

if {0} {
    # Test code:
    # Ask:
    ::Subscribe::HandleAsk "mats@home.se"
    ::Subscribe::HandleAsk "mari@work.se"
    ::Subscribe::HandleAsk "mari.lundberg@someextremelylongname.se"
    ::Subscribe::HandleAsk "donald.duck@disney.com"
    ::Subscribe::HandleAsk "mimmi.duck@disney.com"  
    
    # Auto accept:
    ::SubscribeAuto::HandleAccept "mats@home.se"
    ::SubscribeAuto::HandleAccept "mari@work.se"
    ::SubscribeAuto::HandleAccept "mari.lundberg@someextremelylongname.se"
    ::SubscribeAuto::HandleAccept "donald.duck@disney.com"
    ::SubscribeAuto::HandleAccept "mimmi.duck@disney.com"  
    
    # Auto reject:
    ::SubscribeAuto::HandleReject "mats@home.se"
    ::SubscribeAuto::HandleReject "mari@work.se"
    ::SubscribeAuto::HandleReject "mari.lundberg@someextremelylongname.se"
    ::SubscribeAuto::HandleReject "donald.duck@disney.com"
    ::SubscribeAuto::HandleReject "mimmi.duck@disney.com"  
}

proc ::Subscribe::HandleAsk {jid args} {
    global  config
    
    if {$config(subscribe,multi-dlg)} {
	Queue $jid
    } else {
	NewDlg $jid
    }
}

# Mechanism for queuing subscription events. In situations (transports) when
# we can get several of them at once we show an extended dialog.

proc ::Subscribe::Queue {jid} {
    global  config
    variable queue
    
    # If we already have a 'JSubscribeMulti' dialog, then add a line to that.
    # else add event to queue.
    # If the queu empty, then add a timer event (2 secs).
    # When the timer fires display a 'JSubscribe' dialog if single JID,
    # else a 'JSubscribeMulti' dialog and add all JIDs.
    
    set wList [ui::findalltoplevelwithclass JSubscribeMulti]
    if {[llength $wList]} {
	::SubscribeMulti::AddJID [lindex $wList 0] $jid
    } else {
	if {![llength $queue]} {
	    after $config(subscribe,multi-wait-ms) [namespace code ExecQueue]
	}
	lappend queue $jid
    }
}

proc ::Subscribe::ExecQueue {} {
    variable queue

    set len [llength $queue]
    if {$len == 1} {
	::Subscribe::NewDlg [lindex $queue 0]
    } elseif {$len > 1} {
	set w [::SubscribeMulti::NewDlg]
	foreach jid $queue {
	    ::SubscribeMulti::AddJID $w $jid
	}
    }
    set queue [list]
}

# Subscribe::NewDlg --
#
#       Ask for user response on a subscribe presence element.
#
# Arguments:
#       jid    the jid we receive a 'subscribe' presence element from.
#       args:
#           -auto accept|reject
#       
# Results:
#       widgetPath

proc ::Subscribe::NewDlg {jid args} {
    global  this prefs wDlgs config

    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Subscribe::NewDlg jid=$jid"
    
    # -auto ""|accept|reject
    array set argsA {
	-auto ""
    }
    array set argsA $args

    set w $wDlgs(jsubsc)[incr uid]

    # Initialize the state variable, an array.    
    set token [namespace current]::$w
    variable $w
    upvar 0 $w state
    
    set state(w)        $w
    set state(jid)      $jid
    set state(finished) -1
    set state(name)     ""
    set state(group)    ""

    ::UI::Toplevel $w -macstyle documentProc -macclass {document closeBox} \
      -closecommand [list [namespace current]::CloseCmd $w] \
      -usemacmainmenu 1 -class JSubscribe
    wm title $w [mc "Presence Subscription"]  
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jsubsc)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jsubsc)
    }
  
    set jlib $jstate(jlib)

    # Find all our groups for any jid.
    set allGroups [$jlib roster getgroups]
    set subscription [$jlib roster getsubscription $jid]
    
    switch -- $subscription none - from {
	set havesubsc 0
    } default {
	set havesubsc 1
    }

    # In order to do the "auto" states we keep a list of widgets that shall
    # not be disabled.
    set wkeepL [list]

    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill both -expand 1

    if {$config(subscribe,show-head)} {
	set im  [::Theme::Find32Icon $w adduserImage]
	set imd [::Theme::Find32Icon $w adduserDisImage]

	ttk::label $wall.head -style Headlabel \
	  -text [mc "Presence Subscription"] -compound left \
	  -image [list $im background $imd]
	pack $wall.head -side top -fill both -expand 1
	
	ttk::separator $wall.s -orient horizontal
	pack $wall.s -side top -fill x
	
	lappend wkeepL $wall.head
    }
    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set name [::Roster::GetDisplayName $jid]
    
    set str [mc jasubwant2 $name]
    if {!$havesubsc && $config(subscribe,show-nick-group)} {
	append str " [mc jasubopts2]"
    }
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 200 -justify left -text $str
    pack $wbox.msg -side top -anchor w
    
    set wrapL $wbox.msg
    
    set imvcard [::Theme::Find32Icon $w vcardImage]

    if {$argsA(-auto) eq "accept"} {
	
	#set secs [expr {$config(subscribe,accept-after)/1000}]
	set secs $jprefs(subsc,timer-secs)
	set msg [mc jamesssubscautoacc $secs]
	ttk::label $wbox.accept -style Small.TLabel \
	  -text $msg -wraplength 200 -justify left
	ttk::button $wbox.pause -style Url -text [mc Pause] \
	  -command [namespace code [list Pause $w]]
	
	pack $wbox.accept -side top -anchor w	
	pack $wbox.pause -side top -anchor e -padx 12	
	lappend wrapL $wbox.accept
	set state(waccept) $wbox.accept
	set state(wpause)  $wbox.pause
	
	lappend wkeepL $wbox.accept $wbox.pause
	
	set state(timer-id) [after 1000 [namespace code [list AcceptTimer $w $secs]]]

    } elseif {$argsA(-auto) eq "reject"} {

	#set secs [expr {$config(subscribe,reject-after)/1000}]
	set secs $jprefs(subsc,timer-secs)
	set msg [mc jamesssubscautorej $secs]
	ttk::label $wbox.reject -style Small.TLabel \
	  -text $msg -wraplength 200 -justify left
	ttk::button $wbox.pause -style Url -text [mc Pause] \
	  -command [namespace code [list Pause $w]]
	
	pack $wbox.reject -side top -anchor w	
	pack $wbox.pause -side top -anchor e -padx 12	
	lappend wrapL $wbox.reject
	set state(wreject) $wbox.reject
	set state(wpause)  $wbox.pause

	lappend wkeepL $wbox.reject $wbox.pause
	
	set state(timer-id) [after 1000 [namespace code [list RejectTimer $w $secs]]]
    }

    # If we already have a subscription we've already got the opportunity
    # to select nickname and group. Do not repeat that.
    if {!$havesubsc} {
	set frmid $wbox.frmid
	ttk::frame $frmid
	pack $frmid -side top -fill both -expand 1
	
	ttk::label $frmid.lnick -text "[mc {Nickname}]:" -anchor e
	ttk::entry $frmid.enick -width 22 -textvariable $token\(name)
	ttk::label $frmid.lgroup -text "[mc Group]:" -anchor e
	ttk::combobox $frmid.egroup -values [concat [list [mc None]] $allGroups] \
	  -textvariable $token\(group)
	
	if {$config(subscribe,ui-vcard-pos) eq "name"} {
	    ttk::button $frmid.bvcard -style Plain \
	      -compound image -image $imvcard \
	      -command [list ::VCard::Fetch other $jid]
	    ::balloonhelp::balloonforwindow $frmid.bvcard [mc "View business card"]
	}
	
	if {$config(subscribe,show-nick-group)} {
	    if {$config(subscribe,ui-vcard-pos) eq "name"} {
		grid  $frmid.lnick   $frmid.enick   $frmid.bvcard  -sticky e -pady 0
		grid  $frmid.lgroup  $frmid.egroup  -  -sticky e -pady 0
	    } else {
		grid  $frmid.lnick   $frmid.enick   -sticky e -pady 2
		grid  $frmid.lgroup  $frmid.egroup  -sticky e -pady 2
	    }
	    grid $frmid.enick $frmid.egroup -sticky ew		    
	}
	
    }
        
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Yes] -default active \
      -command [list [namespace current]::Accept $w]
    ttk::button $frbot.btcancel -text [mc No]  \
      -command [list [namespace current]::Deny $w]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    if {$config(subscribe,ui-vcard-pos) eq "button"} {
	ttk::button $frbot.bvcard -style Plain \
	  -compound image -image $imvcard \
	  -command [list ::VCard::Fetch other $jid]
	pack $frbot.bvcard -side left -padx 4
	::balloonhelp::balloonforwindow $frbot.bvcard [mc "View business card"]
    }

    pack $frbot -side top -fill x
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    lappend wkeepL $frbot.btok $frbot.btcancel

    set state(btaccept) $frbot.btok
    set state(btdeny)   $frbot.btcancel
    set state(wkeepL)   $wkeepL
        
    if {$argsA(-auto) eq "accept"} {
	SetAutoState $w on
    } elseif {$argsA(-auto) eq "reject"} {
	SetAutoState $w on
    }
    
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	set length [expr {[winfo reqwidth %s] - 30}]
	foreach win [list %s] {
	    $win configure -wraplength $length
	}
    } $w $wrapL]    
    after idle $script

    return $w
}

proc ::Subscribe::SetAutoState {w which} {
    variable $w
    upvar 0 $w state

    if {$which eq "on"} {
	SetAllWidgetStates $w {disabled background}
	foreach win $state(wkeepL) {
	    $win state {!background !disabled}
	}
    } else {
	SetAllWidgetStates $w {!background !disabled}
	if {[info exists state(waccept)]} {
	    $state(waccept) state {disabled background}
	}
	if {[info exists state(wreject)]} {
	    $state(wreject) state {disabled background}
	}
    }
}

proc ::Subscribe::SetAllWidgetStates {w thestate} {
    
    set Q $w
    while {[llength $Q]} {
	set QN [list]
	foreach win $Q {	 
 	    switch [winfo class $win] \
	      TEntry - TLabel - TButton - TCombobox - TCheckbutton - TRadiobutton \
	      {$win state $thestate}
	    foreach child [winfo children $win] {
		lappend QN $child
	    }
	}
	set Q $QN
    }    
}

proc ::Subscribe::AcceptTimer {w secs} {
    variable $w
    upvar 0 $w state
            
    if {[info exists state(w)]} {
	set w $state(w)
	incr secs -1
	set name [GetDisplayName $state(jid)]
	if {$secs <= 0} {
	    set msg [mc jamessautoaccepted2 $name]
	    ::ui::dialog -title [mc Info] -icon info -type ok -message $msg
	    $state(btaccept) invoke
	} else {
	    set msg [mc jamesssubscautoacc $secs]
	    $state(waccept) configure -text $msg
	    set state(timer-id) [after 1000 [namespace code [list AcceptTimer $w $secs]]]
	}
    }    
}

proc ::Subscribe::RejectTimer {w secs} {
    variable $w
    upvar 0 $w state
	    
    if {[info exists state(w)]} {
	set w $state(w)
	incr secs -1
	set name [GetDisplayName $state(jid)]
	if {$secs <= 0} {
	    set msg [mc jamessautoreject2 $name]
	    ::ui::dialog -title [mc Info] -icon info -type ok -message $msg
	    $state(btdeny) invoke
	} else {
	    set msg [mc jamesssubscautorej $secs]
	    $state(wreject) configure -text $msg
	    set state(timer-id) [after 1000 [namespace code [list RejectTimer $w $secs]]]
	}
    }    
}

proc ::Subscribe::Pause {w} {
    variable $w
    upvar 0 $w state

    SetAutoState $w off
    $state(wpause) state {disabled}
    if {[info exists state(timer-id)]} {
	after cancel $state(timer-id)
	unset state(timer-id)
    }
}

proc ::Subscribe::GetDisplayName {jid} {
    upvar ::Jabber::jstate jstate
    
    set name ""
    set nickE [$jstate(jlib) roster getextras $jid "http://jabber.org/protocol/nick"]
    if {[llength $nickE]} {
	set name [wrapper::getcdata $nickE]
    }
    if {$name eq ""} {
	set name [jlib::unescapejid $jid]
    }
    return $name
}

# Subscribe::Deny --
# 
#       Deny the subscription request.

proc ::Subscribe::Deny {w} {
    global  wDlgs
    variable $w
    upvar 0 $w state
    upvar ::Jabber::jstate jstate

    # Deny presence to this user.
    $jstate(jlib) send_presence -to $state(jid) -type "unsubscribed"
    
    # This doesn't work with ejabberd!
    # http://www.xmpp.org/rfcs/rfc3921.html#int-sub-alt :
    # Note: If the contact's server previously added the user to the contact's
    # roster for tracking purposes, it MUST remove the relevant item at this time.

    $jstate(jlib) roster send_remove $state(jid)
    
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    set state(finished) 0
    destroy $state(w)
    unset state
}

# Subscribe::Accept --
# 
#       Accept the subscription request.

proc ::Subscribe::Accept {w} {
    global  wDlgs
    variable $w
    upvar 0 $w state
    
    Subscribe $state(jid) $state(name) $state(group)

    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    set state(finished) 0
    destroy $state(w)
    unset state
}

# Subscribe::Subscribe --
# 
#       Generic way to handle a subscription acception.

proc ::Subscribe::Subscribe {jid name group} {
    upvar ::Jabber::jstate jstate
    
    set jlib $jstate(jlib)
    set subscription [$jlib roster getsubscription $jid]
  
    switch -- $subscription none - from {
	set sendsubsc 1
	set havesubsc 0
    } default {
	set sendsubsc 0
	set havesubsc 1
    }

    # Accept (allow) subscription.
    $jlib send_presence -to $jid -type "subscribed"
	
    # Add user to my roster. Send subscription request.	
    if {$sendsubsc} {
	set opts [list]
	if {[string length $name]} {
	    lappend opts -name $name
	}
	if {($group ne "") && ($group ne "None") && ($group ne [mc None])} {
	    lappend opts -groups [list $group]
	}
	eval {$jlib roster send_set $jid  \
	  -command [namespace current]::ResProc} $opts
	
	set opts [list]
	set nickname [::Profiles::GetSelected -nickname]
	if {$nickname ne ""} {
	    lappend opts -xlist [list [::Nickname::Element $nickname]]
	}
	eval {$jlib send_presence -to $jid -type "subscribe"} $opts
    }  
}

proc ::Subscribe::CloseCmd {w w} {
    global  wDlgs
    variable $w
    upvar 0 $w state
        
    # Deny presence to this user.
    ::Jabber::Jlib send_presence -to $state(jid) -type "unsubscribed"
    ::Jabber::Jlib roster send_remove $state(jid)

    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    unset -nocomplain state
}

# Subscribe::ResProc --
#
#       This is our callback proc when setting the roster item from the
#       subscription dialog. Catch any errors here.

proc ::Subscribe::ResProc {type queryE} {
        
    ::Debug 2 "::Subscribe::ResProc: type=$type"

    if {[string equal $type "error"]} {
	::UI::MessageBox -type ok \
	  -message "We got an error from the Subscribe::ResProc callback"
    }   
}

#-------------------------------------------------------------------------------
#
# Handle the auto accept & reject situations.

namespace eval ::SubscribeAuto {
    
    ui::dialog button accept -text [mc Accept]
    ui::dialog button reject -text [mc Reject]

    # We have different queues for ask/auto-accept/auto-reject (timers).
    variable queue
    set queue(accept) [list]
    set queue(reject) [list]
    
    # Queues for the plain auto confirmation dialogs.
    # This is kept for the lifetime of the dialog.
    variable queueConfirm
    set queueConfirm(accept) [list]
    set queueConfirm(reject) [list]

    # We use a constant name for the plain auto confirmation dialogs.
    variable wconfirm
    set wconfirm(accept) [ui::autoname]
    set wconfirm(reject) [ui::autoname]
    set confirmDlgJidL(reject) [list]
}

# SubscribeAuto::HandleAccept --
# 
#       Dispatches an auto-accept request to the configured dialog if any.

proc ::SubscribeAuto::HandleAccept {jid} {
    global  config
    upvar ::Jabber::jprefs jprefs

    # Was: config(subscribe,auto-accept-std-dlg)
    if {$jprefs(subsc,timer)} {
	if {$config(subscribe,multi-dlg)} {
	    Queue accept $jid
	} else {
	    ::Subscribe::NewDlg $jid -auto accept
	}
    } elseif {$config(subscribe,auto-accept-plain)} {
	::SubscribeAuto::AcceptAfter $jid
    } else {
	::Jabber::Jlib send_presence -to $jid -type "subscribed"

	# Auto subscribe to subscribers to me.
	SendSubscribe $jid
	if {$config(subscribe,multi-dlg)} {
	    QueueConfirm accept $jid
	} else {
	    set name [::Roster::GetDisplayName $jid]
	    set msg [mc jamessautoaccepted2 $name]
	    ::ui::dialog -title [mc Info] -icon info -type ok -message $msg
	}
	if {$config(subscribe,auto-accept-send-msg)} {
	    SendAcceptMsg $jid
	}
    }
}

# SubscribeAuto::HandleReject --
# 
#       Dispatches an auto-reject request to the configured dialog if any.

proc ::SubscribeAuto::HandleReject {jid} {
    global  config
    upvar ::Jabber::jprefs jprefs

    # Was: config(subscribe,auto-reject-std-dlg)
    if {$jprefs(subsc,timer)} {
	if {$config(subscribe,multi-dlg)} {
	    Queue reject $jid
	} else {
	    ::Subscribe::NewDlg $jid -auto reject
	}
    } elseif {$config(subscribe,auto-reject-plain)} {
	RejectAfter $jid
    } else {
	::Jabber::Jlib send_presence -to $jid -type "unsubscribed"
	::Jabber::Jlib roster send_remove $jid
	
	if {$config(subscribe,multi-dlg)} {
	    QueueConfirm reject $jid
	} else {
	    set name [::Roster::GetDisplayName $jid]
	    set msg [mc jamessautoreject2 $name]
	    ::ui::dialog -title [mc Info] -icon info -type ok -message $msg
	}
	if {$config(subscribe,auto-reject-send-msg)} {
	    SendRejectMsg $jid
	}
    }
}

proc ::SubscribeAuto::Queue {type jid} {
    global  config
    variable queue
    
    # If we already have a 'JSubscribeMulti' dialog, then add a line to that.
    # else add event to queue.
    # If the queu empty, then add a timer event (2 secs).
    # When the timer fires display a 'JSubscribe' dialog if single JID,
    # else a 'JSubscribeMulti' dialog and add all JIDs.
    
    set Type [string totitle $type]
    set wList [ui::findalltoplevelwithclass JSubscribeMultiA$Type]
    if {[llength $wList]} {
	::SubscribeMulti::AddJID [lindex $wList 0] $jid
    } else {
	if {![llength $queue($type)]} {
	    set ms $config(subscribe,multi-wait-ms)
	    after $ms [namespace code [list ExecQueue $type]]
	}
	
	# Add to queue.
	lappend queue($type) $jid
    }
}

proc ::SubscribeAuto::ExecQueue {type} {
    variable queue

    set len [llength $queue($type)]
    if {$len == 1} {
	::Subscribe::NewDlg [lindex $queue($type) 0] -auto $type
    } elseif {$len > 1} {
	set Type [string totitle $type]
	set w [::SubscribeMulti::NewDlg -auto $type -class JSubscribeMultiA$Type]
	foreach jid $queue($type) {
	    ::SubscribeMulti::AddJID $w $jid
	}
    }
    
    # Empty queue.
    set queue($type) [list]
}

# SubscribeAuto::QueueConfirm --
#
#       Same as above but this time only for the plain confirmation dialog.

proc ::SubscribeAuto::QueueConfirm {type jid} {
    global  config
    variable queueConfirm
    variable wconfirm

    set w $wconfirm($type)
    if {[lsearch [winfo children .] $w] >= 0} {
	lappend confirmDlgJidL($type) $jid
	lappend queueConfirm($type) $jid
	$w configure -message [QueueConfirmMsg $type]
    } else {
	if {![llength $queueConfirm($type)]} {
	    set ms $config(subscribe,multi-wait-ms)
	    after $ms [namespace code [list ExecQueueConfirm $type]]
	}
	
	# Add to queue.
	lappend queueConfirm($type) $jid
    }
}

proc ::SubscribeAuto::ExecQueueConfirm {type} {
    variable wconfirm
    
    ui::dialog $wconfirm($type) -title [mc Info] -icon info -type ok \
      -message [QueueConfirmMsg $type] \
      -command [namespace code [list ConfirmOnDestroy $type]]
}

proc ::SubscribeAuto::QueueConfirmMsg {type} {
    variable queueConfirm
    
    set names [list]
    foreach jid $queueConfirm($type) {
	lappend names [::Roster::GetDisplayName $jid]
    }	
    if {$type eq "accept"} {
	set key jamessautoaccepted2
    } else {
	set key jamessautoreject2
    }
    return [mc $key [join $names ", "]]
}

proc ::SubscribeAuto::ConfirmOnDestroy {type w bt} {
    variable queueConfirm
    
    set queueConfirm($type) [list]
    destroy $w
}

# Some simple dialogs for auto accept/reject -----------------------------------

proc ::SubscribeAuto::AcceptAfter {jid} {
    global  config
    
    set secs [expr {$config(subscribe,accept-after)/1000}]
    set msg [mc jamesssubscautoacc $secs]
    set w [ui::dialog -message $msg -buttons {accept reject} -default accept \
      -command [namespace code [list AcceptCmd $jid]]]    
    after 1000 [namespace code [list AcceptTimer $w $jid $secs]]
}

proc ::SubscribeAuto::AcceptTimer {w jid secs} {
    
    if {[winfo exists $w]} {
	incr secs -1
	if {$secs <= 0} {
	    $w invoke accept
	    set name [::Roster::GetDisplayName $jid]
	    set msg [mc jamessautoaccepted2 $name]
	    ::ui::dialog -title [mc Info] -icon info -type ok -message $msg
	} else {
	    set msg [mc jamesssubscautoacc $secs]
	    $w configure -message $msg
	    after 1000 [namespace code [list AcceptTimer $w $jid $secs]]
	}
    }
}

proc ::SubscribeAuto::AcceptCmd {jid w button} {
    global  config
    upvar ::Jabber::jprefs jprefs
    
    if {$button eq "accept" || $button eq ""} {
	::Jabber::Jlib send_presence -to $jid -type "subscribed"
	SendSubscribe $jid

	if {$config(subscribe,auto-accept-send-msg)} {
	    SendAcceptMsg $jid
	}
    } else {
	::Jabber::Jlib send_presence -to $jid -type "unsubscribed"
	::Jabber::Jlib roster send_remove $jid
    }
}

# SubscribeAuto::SendSubscribe --
# 
#       Must automatically subscribed to users we have accepted and to whom
#       we have no previous subscription to.

proc ::SubscribeAuto::SendSubscribe {jid} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    set jlib $jstate(jlib)
    set subscription [$jlib roster getsubscription $jid]

    switch -- $subscription none - from {
	
	# Explicitly set the users group.
	if {$jprefs(subsc,auto) && [string length $jprefs(subsc,group)]} {
	    $jlib roster send_set $jid -groups [list $jprefs(subsc,group)]
	}
	$jlib send_presence -to $jid -type "subscribe"
	#set msg [mc jamessautosubs2 $jid]
	#::ui::dialog -title [mc Info] -icon info -type ok -message $msg
    }    
}

proc ::SubscribeAuto::RejectAfter {jid} {
    global  config
    
    set secs [expr {$config(subscribe,reject-after)/1000}]
    set msg [mc jamesssubscautorej $secs]
    set w [ui::dialog -message $msg -buttons {reject accept} -default reject \
      -command [namespace code [list RejectCmd $jid]]]    
    after 1000 [namespace code [list RejectTimer $w $jid $secs]]
}

proc ::SubscribeAuto::RejectTimer {w jid secs} {

    if {[winfo exists $w]} {
	incr secs -1
	if {$secs <= 0} {
	    $w invoke reject
	    set name [::Roster::GetDisplayName $jid]
	    set msg [mc jamessautoreject2 $name]
	    ::ui::dialog -title [mc Info] -icon info -type ok -message $msg
	} else {
	    set msg [mc jamesssubscautorej $secs]
	    $w configure -message $msg
	    after 1000 [namespace code [list RejectTimer $w $jid $secs]]
	}
    }
}

proc ::SubscribeAuto::RejectCmd {jid w button} {
    global  config
    
    if {$button eq "reject" || $button eq ""} {
	::Jabber::Jlib send_presence -to $jid -type "unsubscribed"
	::Jabber::Jlib roster send_remove $jid
	if {$config(subscribe,auto-reject-send-msg)} {
	    SendRejectMsg $jid
	}
    } else {
	::Jabber::Jlib send_presence -to $jid -type "subscribed"
    }
}

proc ::SubscribeAuto::SendRejectMsg {jid} {
    
    set autoRejectMsg "Your request has been automatically refused by the peers IM client software. It wasn't an action taken by your party"
    
    ::Jabber::Jlib send_message $jid -subject "Auto rejection" \
      -message $autoRejectMsg
}

proc ::SubscribeAuto::SendAcceptMsg {jid} {
    
    set autoAcceptMsg "Your request has been automatically accepted by the peers IM client software. It wasn't an action taken by your party"
    
    ::Jabber::Jlib send_message $jid -subject "Auto acception" \
      -message $autoAcceptMsg
}

#-------------------------------------------------------------------------------

# SubscribeMulti... --
# 
#       A dialog to handle multiple subscription requests.
#       There should only be a single copy of this dialog (singleton).

namespace eval ::SubscribeMulti {
    
    # Use option database for customization.
    option add *JSubscribeMulti.adduserImage           contact-new         widgetDefault
    option add *JSubscribeMulti.adduserDisImage        contact-new-Dis      widgetDefault
    option add *JSubscribeMulti.vcardImage             vcard           widgetDefault

    option add *JSubscribeMultiAAccept.adduserImage           contact-new         widgetDefault
    option add *JSubscribeMultiAAccept.adduserDisImage        contact-new-Dis      widgetDefault
    option add *JSubscribeMultiAAccept.vcardImage             vcard           widgetDefault

    option add *JSubscribeMultiAReject.adduserImage           contact-new         widgetDefault
    option add *JSubscribeMultiAReject.adduserDisImage        contact-new-Dis      widgetDefault
    option add *JSubscribeMultiAReject.vcardImage             vcard           widgetDefault

    variable uid 0
}

# SubscribeMulti::NewDlg --
# 
#       Dialog to handle > 1 simultaneous subscription requests.
# 
# Arguments:
#       args:
#           -auto accept|reject
#           -class windowClassName
#       
# Results:
#       widgetPath

proc ::SubscribeMulti::NewDlg {args} {
    global  this prefs wDlgs config

    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::SubscribeMulti::NewDlg"
 
    array set argsA {
	-auto  ""
	-class JSubscribeMulti
    }
    array set argsA $args
    set w $wDlgs(jsubsc)ex[incr uid]

    # Initialize the state variable, an array.    
    set token [namespace current]::$w
    variable $w
    upvar 0 $w state
    
    set state(w)        $w
    set state(finished) -1
    set state(nusers)   0
    set state(all)      1
    set state(auto)     $argsA(-auto)

    ::UI::Toplevel $w -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace current]::CloseCmd \
      -usemacmainmenu 1 -class $argsA(-class)
    wm title $w [mc "Presence Subscription"]  
    #wm withdraw $w
  
    set jlib $jstate(jlib)
    
    # In order to do the "auto" states we keep a list of widgets that shall
    # not be disabled.
    set wkeepL [list]
    
    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill both -expand 1

    if {$config(subscribe,show-head)} {
	set im  [::Theme::Find32Icon $w adduserImage]
	set imd [::Theme::Find32Icon $w adduserDisImage]

	ttk::label $wall.head -style Headlabel \
	  -text [mc "Presence Subscription"] -compound left \
	  -image [list $im background $imd]
	pack $wall.head -side top -fill both -expand 1
	
	ttk::separator $wall.s -orient horizontal
	pack $wall.s -side top -fill x
	
	lappend wkeepL $wall.head
    }
    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 320 -justify left \
      -text [mc jasubmulti $state(nusers)]
    pack $wbox.msg -side top -anchor w

    if {$state(auto) eq "accept"} {
	
	#set secs [expr {$config(subscribe,accept-after)/1000}]
	set secs $jprefs(subsc,timer-secs)
	set msg [mc jamesssubscautoacc $secs]
	ttk::label $wbox.accept -style Small.TLabel \
	  -text $msg -wraplength 320 -justify left
	ttk::button $wbox.pause -style Url -text [mc Pause] \
	  -command [namespace code [list Pause $w]]
	
	pack $wbox.accept -side top -anchor w	
	pack $wbox.pause -side top -anchor e -padx 12	
	lappend wrapL $wbox.accept
	set state(waccept) $wbox.accept
	set state(wpause)  $wbox.pause

	lappend wkeepL $wbox.accept $wbox.pause
	
	set state(timer-id) [after 1000 [namespace code [list AcceptTimer $w $secs]]]

    } elseif {$state(auto) eq "reject"} {

	#set secs [expr {$config(subscribe,reject-after)/1000}]
	set secs $jprefs(subsc,timer-secs)
	set msg [mc jamesssubscautorej $secs]
	ttk::label $wbox.reject -style Small.TLabel \
	  -text $msg -wraplength 320 -justify left
	ttk::button $wbox.pause -style Url -text [mc Pause] \
	  -command [namespace code [list Pause $w]]
	
	pack $wbox.reject -side top -anchor w	
	pack $wbox.pause -side top -anchor e -padx 12	
	lappend wrapL $wbox.reject
	set state(wreject) $wbox.reject
	set state(wpause)  $wbox.pause

	lappend wkeepL $wbox.reject $wbox.pause
	
	set state(all) 0

	set state(timer-id) [after 1000 [namespace code [list RejectTimer $w $secs]]]
    }

    if {!$config(subscribe,exp-scrollframe)} {
	set wframe $wbox.f
	ttk::frame $wframe
	pack $wframe -side top -anchor w -fill both -expand 1    
    } else {
 	::UI::ScrollFrame $wbox.f -padding {0 0 6 0}
 	pack $wbox.f -side top -anchor w -fill both -expand 1
 	set wframe [::UI::ScrollFrameInterior $wbox.f]
    }
    
    ttk::label $wframe.allow -text [mc Allow]
    ttk::label $wframe.jid   -text [mc "Contact ID"]
    ttk::checkbutton $wframe.all \
      -command [namespace code [list All $w]] \
      -variable $token\(all)
    ttk::label $wframe.lall -text [mc All]
    
    grid  $wframe.allow  x  $wframe.jid -padx 0 -pady 4
    grid  $wframe.all    x  $wframe.lall
    grid $wframe.jid -sticky w
    grid $wframe.all -sticky w
    grid $wframe.lall -sticky w
    grid columnconfigure $wframe 0 -minsize 36
    grid columnconfigure $wframe 2 -minsize 220 -weight 1
    
    set state(frame) $wframe
    set state(label) $wbox.msg
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] -default active \
      -command [list [namespace current]::Accept $w]
    pack $frbot.btok -side right

    pack $frbot -side top -fill x
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    set state(btok) $frbot.btok
    
    lappend wkeepL $frbot.btok
    set state(wkeepL) $wkeepL
    
    #wm deiconify $w
    if {!$config(subscribe,exp-scrollframe)} {
	set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jsubsc)]]
	if {$nwin == 1} {
	    ::UI::SetWindowPosition $w $wDlgs(jsubsc)
	}
    }
    if {$state(auto) eq "accept"} {
	SetAutoState $w on
    } elseif {$state(auto) eq "reject"} {
	SetAutoState $w on
    }
    return $w
}

proc ::SubscribeMulti::AcceptTimer {w secs} {
    variable $w
    upvar 0 $w state
	    
    if {[info exists state(w)]} {
	set w $state(w)
	incr secs -1
	if {$secs <= 0} {
	    $state(btok) invoke
	} else {
	    set msg [mc jamesssubscautoacc $secs]
	    $state(waccept) configure -text $msg
	    set state(timer-id) [after 1000 [namespace code [list AcceptTimer $w $secs]]]
	}
    }    
}

proc ::SubscribeMulti::RejectTimer {w secs} {
    variable $w
    upvar 0 $w state
	    
    if {[info exists state(w)]} {
	set w $state(w)
	incr secs -1
	if {$secs <= 0} {
	    $state(btok) invoke
	} else {
	    set msg [mc jamesssubscautorej $secs]
	    $state(wreject) configure -text $msg
	    set state(timer-id) [after 1000 [namespace code [list RejectTimer $w $secs]]]
	}
    }    
}

proc ::SubscribeMulti::Pause {w} {
    variable $w
    upvar 0 $w state

    SetAutoState $w off
    $state(wpause) state {disabled}
    if {[info exists state(timer-id)]} {
	after cancel $state(timer-id)
	unset state(timer-id)
    }
}

proc ::SubscribeMulti::SetAutoState {w which} {
    variable $w
    upvar 0 $w state

    if {$which eq "on"} {
	::Subscribe::SetAllWidgetStates $w {disabled background}
	foreach win $state(wkeepL) {
	    $win state {!background !disabled}
	}
    } else {
	::Subscribe::SetAllWidgetStates $w {!background !disabled}
	if {[info exists state(waccept)]} {
	    $state(waccept) state {disabled background}
	}
	if {[info exists state(wreject)]} {
	    $state(wreject) state {disabled background}
	}
    }
}

proc ::SubscribeMulti::All {w} {
    variable $w
    upvar 0 $w state
    
    foreach {key value} [array get state *,allow] {
	set state($key) $state(all)
    }
}

proc ::SubscribeMulti::AddJID {w jid} {
    variable $w
    upvar 0 $w state
    upvar ::Jabber::jstate jstate

    set token [namespace current]::$w

    set f $state(frame)
        
    incr state(nusers)
    $state(label) configure -text [mc jasubmulti $state(nusers)]
    
    set name   [$jstate(jlib) roster getname $jid]
    set groups [$jstate(jlib) roster getgroups $jid]
    set group [lindex $groups 0]

    lassign [grid size $f] columns rows

    set row $rows
    set state($row,more)  0
    set state($row,allow) $state(all)
    set state($row,jid)   $jid
    set state($row,name)  $name
    set state($row,group) $group
    
    set jstr [::Roster::GetDisplayName $jid]
    set jlen [font measure CociDefaultFont $jstr]
    if {$jlen > 240} {
	set len [string length $jstr]
	set n [expr {($len * 240)/$jlen - 2}]
	set jstr [string range $jstr 0 $n]
	append jstr "..."
    }
    
    ttk::checkbutton $f.m$row -style ArrowText.TCheckbutton \
      -onvalue 0 -offvalue 1 -variable $token\($row,more) \
      -command [list [namespace current]::More $w $row]
    ttk::checkbutton $f.c$row -variable $token\($row,allow)
    ttk::label $f.l$row -text $jstr
    ttk::frame $f.f$row
    
    grid  $f.c$row  $f.m$row  $f.l$row
    grid  x         x         $f.f$row
    grid $f.c$row -sticky e
    grid $f.l$row $f.f$row -sticky w
    
    if {[info exists state(timer-id)]} {
	$f.m$row state {disabled}
	$f.c$row state {disabled}
	$f.l$row state {disabled}
    }
    return $row
}

proc ::SubscribeMulti::More {w row} {
    variable $w
    upvar 0 $w state
    set token [namespace current]::$w
   
    set f $state(frame)
    set wcont $f.f$row
    set jid $state($row,jid)

    if {$state($row,more)} {
	set imvcard [::Theme::Find32Icon $w vcardImage]

	# Find all our groups for any jid.
	set allGroups [::Jabber::Jlib roster getgroups]
	set values [concat [list [mc None]] $allGroups]
		
	ttk::label $wcont.lnick -text "[mc {Nickname}]:" -anchor e
	ttk::entry $wcont.enick -width 1 -textvariable $token\($row,name)
	ttk::label $wcont.lgroup -text "[mc Group]:" -anchor e
	ttk::combobox $wcont.egroup -width 1 -values $values \
	  -textvariable $token\($row,group)
	ttk::button $wcont.vcard -style Plainer \
	  -compound image -image $imvcard \
	  -command [list ::VCard::Fetch other $jid]

	grid  $f.f$row  -row [expr {$row+1}] -columnspan 1 -column 2
	grid $f.f$row -sticky ew

	grid  $wcont.lnick   $wcont.enick  $wcont.vcard  -sticky e -pady 0
	grid  $wcont.lgroup  $wcont.egroup -  -sticky e -pady 0
	grid $wcont.enick $wcont.egroup -sticky ew
	grid columnconfigure $wcont 1 -weight 1

	::balloonhelp::balloonforwindow $wcont.vcard [mc "View business card"]
    } else {
	eval destroy [winfo children $wcont]
	grid forget $wcont
    }
}

proc ::SubscribeMulti::GetContent {w} {
    variable $w
    upvar 0 $w state

    set contentL [list]
    foreach {key jid} [array get state *,jid] {
	set row [string map {",jid" ""} $key]
	set content [list $jid $state($row,allow)]
	
	if {[info exists state($row,name)]} {
	    set value [string trim $state($row,name)]
	    if {$value ne ""} {
		lappend content -name $value
	    }
	}
	if {[info exists state($row,group)]} {
	    set value [string trim $state($row,group)]
	    set value [string map [list [mc None] ""] $value]
	    if {$value ne ""} {
		lappend content -group $value
	    }
	}
	lappend contentL $content
    }
    return $contentL
}

proc ::SubscribeMulti::Accept {w} {
    variable $w
    upvar 0 $w state
    upvar ::Jabber::jstate jstate

    set jlib $jstate(jlib)
    
    foreach line [GetContent $w] {
	set jid [lindex $line 0]
	set allow [lindex $line 1]
	array set opts [list -name "" -group ""]
	array set opts [lrange $line 2 end]
	
	if {$allow} {
	    ::Subscribe::Subscribe $jid $opts(-name) $opts(-group)
	} else {
	    # @@@ Do we need to remove roster item as well? See above.
	    $jlib send_presence -to $jid -type "unsubscribed"
	    $jlib roster send_remove $jid
	}
    }
    Free $w
}

proc ::SubscribeMulti::CloseCmd {w} {    
    Accept $w
}

proc ::SubscribeMulti::Free {w} {
    global  wDlgs
    variable $w
    upvar 0 $w state
	
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    destroy $state(w)
    unset -nocomplain state
}

#--- Subscribed ----------------------------------------------------------------

# Mechanism for queuing subscription confirmations. In situations (transports) 
# when we can get several of them at once we show an single dialog.

namespace eval ::Subscribed {
    
    # Millis to wait for a second subsciption request to show in multi dialog.
    set ::config(subscribed,multi-wait-ms) 4000

    # Use the multi dialog for batches of subscription requests.
    set ::config(subscribed,multi-dlg) 1
    
    # Use a fancy dialog for queued 'subscribed' events.
    # The "unfancy" one doesn't have its text in catalog.
    set ::config(subscribed,fancy-dlg) 1

    variable queue [list]
    
    option add *vcard22Image      vcard     widgetDefault
}

if {0} {
    # Test code:
    ::Subscribed::Queue "mats@home.se"
    ::Subscribed::Queue "mari@work.se"
    ::Subscribed::Queue "mari.lundberg@someextremelylongname.se"
    ::Subscribed::Queue "donald.duck@disney.com"
    ::Subscribed::Queue "mimmi.duck@disney.com"
}

proc ::Subscribed::Handle {jid} {
    global  config
    
    if {$config(subscribed,multi-dlg)} {
	Queue $jid
    } else {
	set name [::Roster::GetDisplayName $jid]
	::ui::dialog -title [mc "Presence Subscription"] -icon info -type ok \
	  -message [mc jamessallowsub2 $name]
    }
}

proc ::Subscribed::Queue {jid} {
    global  wDlgs config
    variable queue
    
    set w $wDlgs(jsubsced)
    if {[winfo exists $w]} {
	AddJID $jid
    } else {
	if {![llength $queue]} {
	    after $config(subscribed,multi-wait-ms) [namespace code ExecQueue]
	}
	lappend queue $jid
    }
}

proc ::Subscribed::ExecQueue {} {
    global  wDlgs config
    variable queue
    
    set len [llength $queue]
    if {$len == 1} {
	set jid [lindex $queue 0]
	set name [::Roster::GetDisplayName $jid]
	::ui::dialog -title [mc "Presence Subscription"] -icon info -type ok \
	  -message [mc jamessallowsub2 $name]
    } elseif {$len > 1} {
	set w $wDlgs(jsubsced)
	if {$config(subscribed,fancy-dlg)} {
	    FancyDlg
	} else {
	    # This string is not in catalog by default.
	    set str [mc "The following contacts can see your presence"]
	    ::ui::dialog $w -title [mc "Presence Subscription"] -icon info \
	      -type ok -message "[mc jasubmultians]:\n"
	}
	AddJID [lindex $queue 0] 1
	foreach jid [lrange $queue 1 end] {
	    AddJID $jid
	}
    }
    set queue [list]
}

proc ::Subscribed::AddJID {jid {first 0}} {
    global  wDlgs config
    
    set w $wDlgs(jsubsced)
    if {[winfo exists $w]} {
	if {$config(subscribed,fancy-dlg)} {
	    AddJIDFancy $w $jid $first
	} else {
	    AddJIDPlain $w $jid $first
	}
    }    
}

proc ::Subscribed::AddJIDPlain {w jid {first 0}} {
    
    set msg [$w cget -message]
    if {!$first} {
	append msg ", "
    }
    append msg [::Roster::GetDisplayName $jid]
    $w configure -message $msg
}

proc ::Subscribed::FancyDlg {} {
    global  wDlgs
    
    set w $wDlgs(jsubsced)

    variable $w
    upvar 0 $w state
    set token [namespace current]::$w

    set msg [mc jamesssubscedfancy 0]
    ::ui::dialog $w -title [mc "Presence Subscription"] -icon info -type ok \
      -expandclient 1
    set fr [$w clientframe]
    
    set state(check) 1
    
    ttk::checkbutton $fr.c -style Arrow.TCheckbutton \
      -command [namespace code [list ExpandFancy $w]] -variable $token\(check)
    ttk::label $fr.l -text $msg
    ttk::frame $fr.f
    
    grid  $fr.c  $fr.l  -sticky nw -padx 2
    grid $fr.c -pady 2
    grid columnconfigure $fr 1 -weight 1
    grid rowconfigure    $fr 0 -weight 1
    
    raise $fr.c

    set state(frame) $fr.f
    set state(label) $fr.l
    
    bind $w <Destroy> [subst { if {"%W" eq "$w"} { unset -nocomplain $token } }]
    
    return $w
}

proc ::Subscribed::ExpandFancy {w} {
    variable $w
    upvar 0 $w state

    set fr $state(frame)
    if {$state(check)} {
	grid forget $fr
    } else {
	grid  $fr  -column 1 -row 1 -sticky news -pady 4
    }
}

proc ::Subscribed::AddJIDFancy {w jid {first 0}} {
    variable $w
    upvar 0 $w state

    set fr $state(frame)
    lassign [grid size $fr] ncol nrow
    
    set nusers [expr {$nrow + 1}]
    $state(label) configure -text [mc jamesssubscedfancy $nusers]
  
    set jstr [::Roster::GetDisplayName $jid]
    set jlen [font measure CociSmallFont $jstr]
    if {$jlen > 220} {
	set len [string length $jstr]
	set n [expr {($len * 220)/$jlen - 2}]
	set jstr [string range $jstr 0 $n]
	append jstr "..."
    }
    set imvcard [::Theme::FindIconSize 22 [option get . vcard22Image {}]]

    set box $fr.f$nrow
    ttk::frame $box
    grid  $box  -sticky ew
    
    ttk::label $box.l -style Small.TLabel -text $jstr
    ttk::button $box.b -style Plainer \
      -compound image -image $imvcard \
      -command [list ::VCard::Fetch other $jid]

    pack $box.l -side left -padx 2 -pady 0
    pack $box.b -side right -padx 2 -pady 0
    
    ::balloonhelp::balloonforwindow $box.b [mc "View business card"]
}

if {0} {
    ::Subscribed::FancyDlg
    ::Subscribed::AddJID "mats@home.se"
    ::Subscribed::AddJID "mari@work.se"
    ::Subscribed::AddJID "mari.lundberg@someextremelylongnamexxxxxxxxxxx.se"
    ::Subscribed::AddJID "donald.duck@disney.com"
    ::Subscribed::AddJID "mimmi.duck@disney.com"
}

# Prefs page ...................................................................

proc ::Subscribe::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...
    set jprefs(subsc,inrost)        ask
    set jprefs(subsc,notinrost)     ask
    set jprefs(subsc,auto)          0
    set jprefs(subsc,group)         {}
    set jprefs(subsc,timer)         0
    set jprefs(subsc,timer-secs)    10
	
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(subsc,inrost)     jprefs_subsc_inrost      $jprefs(subsc,inrost)]  \
      [list ::Jabber::jprefs(subsc,notinrost)  jprefs_subsc_notinrost   $jprefs(subsc,notinrost)]  \
      [list ::Jabber::jprefs(subsc,auto)       jprefs_subsc_auto        $jprefs(subsc,auto)]  \
      [list ::Jabber::jprefs(subsc,group)      jprefs_subsc_group       $jprefs(subsc,group)]  \
      [list ::Jabber::jprefs(subsc,timer)      jprefs_subsc_timer       $jprefs(subsc,timer)]  \
      [list ::Jabber::jprefs(subsc,timer-secs) jprefs_subsc_timer-secs  $jprefs(subsc,timer-secs)]  \
      ]
    
}

proc ::Subscribe::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {Jabber Subscription} [mc "Presence Subscription"]
    
    # Subscriptions page ---------------------------------------------------
    set wpage [$nbframe page {Subscription}]
    ::Subscribe::BuildPageSubscriptions $wpage    
}

proc ::Subscribe::BuildPageSubscriptions {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpp
    
    foreach key {inrost notinrost auto group timer timer-secs} {
	set tmpp(subsc,$key) $jprefs(subsc,$key)
    }

    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    ttk::frame $wc.head -padding {0 0 0 6}
    ttk::label $wc.head.l -text [mc "Presence Subscription"]
    ttk::separator $wc.head.s -orient horizontal

    grid  $wc.head.l  $wc.head.s
    grid $wc.head.s -sticky ew
    grid columnconfigure $wc.head 1 -weight 1
    pack  $wc.head  -side top -fill x

    # Subscription actions:
    set wsubs $wc.fr
    ttk::frame $wsubs -padding {0 0 0 12}
    pack  $wsubs  -side top -fill x
    
    array set strA {
	ask     "Always ask"
	accept  "Auto-accept"
	reject  "Auto-reject"
    }

    ttk::label $wsubs.la1  -text "[mc prefsuif2]..."
    ttk::label $wsubs.lnot -text "...[mc prefsuisnot2]:"
    ttk::label $wsubs.lin  -text "...[mc prefsuis2]:"

    set mDef [list \
      [list [mc $strA(ask)] -value ask] \
      [list [mc $strA(accept)] -value accept] \
      [list [mc $strA(reject)] -value reject] ]
    
    ui::optionmenu $wsubs.min -menulist $mDef \
      -variable [namespace current]::tmpp(subsc,inrost)
    ui::optionmenu $wsubs.mnot -menulist $mDef \
      -variable [namespace current]::tmpp(subsc,notinrost)
    set minsize [$wsubs.min maxwidth]
    
    grid  $wsubs.la1   -  -         -sticky w
    grid  x  $wsubs.lnot  $wsubs.mnot  -padx 2 -pady 2
    grid  x  $wsubs.lin   $wsubs.min   -padx 2 -pady 2
    grid $wsubs.lin $wsubs.lnot -sticky e
    grid $wsubs.min $wsubs.mnot -sticky ew
    grid columnconfigure $wsubs 0 -minsize 24
    grid columnconfigure $wsubs 2 -weight 1 -minsize $minsize
        
    # Auto dialogs:
    set wtimer $wc.timer
    ttk::frame $wtimer -padding {0 0 0 12}
    pack  $wtimer -side top -fill x
    
    set autoCmd [list PrefsSetEntryState $wtimer.e tmpp(subsc,timer)]
    
    ttk::checkbutton $wtimer.c -text "[mc prefsuaatimer]:" \
      -variable [namespace current]::tmpp(subsc,timer) \
      -command [namespace code $autoCmd]
    ttk::label $wtimer.l -text "[mc prefsuaasecs]:"
    ttk::entry $wtimer.e -width 3 \
      -textvariable [namespace current]::tmpp(subsc,timer-secs) \
      -validate key -validatecommand [namespace code {ValidSecs %S}]
    
    grid  $wtimer.c  -          -  -sticky w
    grid  x          $wtimer.l  $wtimer.e  -sticky w

    grid columnconfigure $wtimer 0 -minsize 24
    grid columnconfigure $wtimer 2 -weight 1    
    
    eval $autoCmd
    
    # Default group:
    set wauto $wc.auto
    ttk::frame $wauto
    pack  $wauto  -side top -fill x

    set groupCmd [list PrefsSetEntryState $wauto.ent tmpp(subsc,auto)]

    ttk::checkbutton $wauto.sub -text "[mc prefsuauto2]:" \
      -variable [namespace current]::tmpp(subsc,auto) \
      -command [namespace code $groupCmd]
    ttk::label $wauto.la -text [mc "Default group"]:
    ttk::entry $wauto.ent -font CociSmallFont \
      -textvariable [namespace current]::tmpp(subsc,group)
    
    grid  $wauto.sub  -           -
    grid  x           $wauto.la   $wauto.ent
    grid $wauto.sub -sticky w
    grid $wauto.ent -sticky ew
    grid columnconfigure $wauto 0 -minsize 24
    grid columnconfigure $wauto 2 -weight 1
    
    eval $groupCmd
    
    return $page
}

proc ::Subscribe::PrefsSetEntryState {winL varName} {
    upvar $varName var
    if {$var} {
	foreach w $winL {
	    $w state {!disabled}
	}
    } else {
	foreach w $winL {
	    $w state {disabled}
	}
    }   
}

proc ::Subscribe::ValidSecs {s} {
    if {[regexp {^[0-9]*$} $s]} {
	return 1
    } else {
	bell
	return 0
    }
}

proc ::Subscribe::SavePrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpp
    
    array set jprefs [array get tmpp]
    unset tmpp
}

proc ::Subscribe::CancelPrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpp
	
    foreach key [array names tmpp] {
	if {![string equal $jprefs($key) $tmpp($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::Subscribe::UserDefaultsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpp
	
    foreach key [array names tmpp] {
	set tmpp($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
