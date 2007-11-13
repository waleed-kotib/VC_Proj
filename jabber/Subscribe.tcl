#  Subscribe.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements subscription parts.
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
# $Id: Subscribe.tcl,v 1.56 2007-11-13 15:39:33 matben Exp $

package provide Subscribe 1.0

namespace eval ::Subscribe:: {

    # Use option database for customization.
    option add *JSubscribe.adduserImage           adduser         widgetDefault
    option add *JSubscribe.adduserDisImage        adduserDis      widgetDefault

    
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
    
    # Millis to wait for a second subsciption request to show in multi dialog.
    set ::config(subscribe,multi-wait-ms) 2000
    
    # Use the multi dialog for batches of subscription requests.
    set ::config(subscribe,multi-dlg) 1
    
    variable queue [list]
}

proc ::Subscribe::HandleAsk {jid} {
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
    
    # If we already have a 'JSubscribeEx' dialog, then add a line to that.
    # else add event to queue.
    # If the queu empty, then add a timer event (2 secs).
    # When the timer fires display a 'JSubscribe' dialog if single JID,
    # else a 'JSubscribeEx' dialog and add all JIDs.
    
    set wList [ui::findalltoplevelwithclass JSubscribeEx]
    if {[llength $wList]} {
	::SubscribeEx::AddJID [lindex $wList 0] $jid
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
	set w [::SubscribeEx::NewDlg]
	foreach jid $queue {
	    ::SubscribeEx::AddJID $w $jid
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
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jsubsc)$uid
    set state(w)        $w
    set state(jid)      $jid
    set state(finished) -1
    set state(name)     ""
    set state(group)    ""

    ::UI::Toplevel $w -macstyle documentProc -macclass {document closeBox} \
      -closecommand [list [namespace current]::CloseCmd $token] \
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

    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill both -expand 1

    if {$config(subscribe,show-head)} {
	set im  [::Theme::GetImage [option get $w adduserImage {}]]
	set imd [::Theme::GetImage [option get $w adduserDisImage {}]]

	ttk::label $wall.head -style Headlabel \
	  -text [mc "Presence Subscription"] -compound left \
	  -image [list $im background $imd]
	pack $wall.head -side top -fill both -expand 1
	
	ttk::separator $wall.s -orient horizontal
	pack $wall.s -side top -fill x
    }
    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set name [GetDisplayName $jid]
    
    set str [mc jasubwant2 $name]
    if {!$havesubsc} {
	append str " [mc jasubopts2]"
    }
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 200 -justify left -text $str
    pack $wbox.msg -side top -anchor w
    
    set wrapL $wbox.msg

    # If we already have a subscription we've already got the opportunity
    # to select nickname and group. Do not repeat that.
    if {!$havesubsc} {
	set frmid $wbox.frmid
	ttk::frame $frmid
	pack $frmid -side top -fill both -expand 1
	
	ttk::label $frmid.lnick -text "[mc {Nickname}]:" -anchor e
	ttk::entry $frmid.enick -width 24 -textvariable $token\(name)
	ttk::label $frmid.lgroup -text "[mc Group]:" -anchor e
	ttk::combobox $frmid.egroup -values [concat [list [mc None]] $allGroups] \
	  -textvariable $token\(group)

	grid  $frmid.lnick   $frmid.enick  -sticky e -pady 2
	grid  $frmid.lgroup  $frmid.egroup -sticky e -pady 2
	grid  $frmid.enick   $frmid.egroup -sticky ew	
    }
    if {$argsA(-auto) eq "accept"} {
	set secs [expr {$config(subscribe,accept-after)/1000}]
	set msg [mc jamesssubscautoacc $name $secs]
	ttk::label $wbox.accept -style Small.TLabel \
	  -text $msg -wraplength 200 -justify left
	ttk::button $wbox.pause -style Url -text [mc Pause] \
	  -command [namespace code [list Pause $token]]
	
	pack $wbox.accept -side top -anchor w	
	pack $wbox.pause -side top -anchor e -padx 12	
	lappend wrapL $wbox.accept
	set state(waccept) $wbox.accept
	
	set secs [expr {$config(subscribe,accept-after)/1000}]
	set state(timer-id) [after 1000 [namespace code [list AcceptTimer2 $token $secs]]]
    } elseif {$argsA(-auto) eq "reject"} {
	
    }
    
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Yes] -default active \
      -command [list [namespace current]::Accept $token]
    ttk::button $frbot.btcancel -text [mc No]  \
      -command [list [namespace current]::Deny $token]
    ttk::button $frbot.bvcard -text "[mc {View Business Card}]..." \
      -command [list ::VCard::Fetch other $jid]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
	pack $frbot.bvcard -side left -padx 4
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
	pack $frbot.bvcard -side left -padx 4
    }
    pack $frbot -side top -fill x
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    set state(btaccept) $frbot.btok
    set state(btdeny)   $frbot.btcancel

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

proc ::Subscribe::AcceptTimer2 {token secs} {
    variable $token
    upvar 0 $token state
            
    if {[info exists state(w)]} {
	set w $state(w)
	incr secs -1
	set name [GetDisplayName $state(jid)]
	if {$secs <= 0} {
	    set msg [mc jamessautoaccepted2 $name]
	    ::ui::dialog -title [mc Info] -icon info -type ok -message $msg
	    $state(btaccept) invoke
	} else {
	    set msg [mc jamesssubscautoacc $name $secs]
	    $state(waccept) configure -text $msg
	    set state(timer-id) [after 1000 [namespace code [list AcceptTimer2 $token $secs]]]
	}
    }    
}

proc ::Subscribe::Pause {token} {
    variable $token
    upvar 0 $token state

    if {[info exists state(timer-id)]} {
	after cancel $state(timer-id)
	unset state(timer-id)
    }
}

proc ::Subscribe::GetDisplayName {jid} {
    upvar ::Jabber::jstate jstate
    
    set name ""
    set nickE [$jstate(jlib) roster getextras $jid \
      "http://jabber.org/protocol/nick"]
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

proc ::Subscribe::Deny {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    # Deny presence to this user.
    $jstate(jlib) send_presence -to $state(jid) -type "unsubscribed"
    
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    set state(finished) 0
    destroy $state(w)
    unset state
}

# Subscribe::Accept --
# 
#       Accept the subscription request.

proc ::Subscribe::Accept {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    Subscribe $state(jid) $state(name) $state(group)

    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    set state(finished) 0
    destroy $state(w)
    unset state
}

proc ::Subscribe::Subscribe {jid name group} {
    upvar ::Jabber::jstate jstate
    
    set subscription [$jstate(jlib) roster getsubscription $jid]
  
    switch -- $subscription none - from {
	set sendsubsc 1
	set havesubsc 0
    } default {
	set sendsubsc 0
	set havesubsc 1
    }
    set jlib $jstate(jlib)

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

proc ::Subscribe::CloseCmd {token w} {
    global  wDlgs
    variable $token
    upvar 0 $token state
        
    # Deny presence to this user.
    ::Jabber::JlibCmd send_presence -to $state(jid) -type "unsubscribed"
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
	::UI::MessageBox -type ok -message "We got an error from the\
	  Subscribe::ResProc callback"
    }   
}

#-------------------------------------------------------------------------------
#
# Experimental code which count downs on auto accept & reject.

namespace eval ::Subscribe {
       
    # Sets the number of millisecs the dialog starts its countdown.
    set ::config(subscribe,accept-after) 10000
    set ::config(subscribe,reject-after) 10000
    
    ui::dialog button accept -text [mc Accept]
    ui::dialog button reject -text [mc Reject]

}

::msgcat::mcset en jamesssubscautoacc {Subscription request of %s will be accepted in: %s secs. If you don't do anything this dialog will be closed and the request will be accepted.}
::msgcat::mcset sv jamesssubscautoacc {Subscription request of %s will be accepted in: %s secs. If you don't do anything this dialog will be closed and the request will be accepted.}
::msgcat::mcset pl jamesssubscautoacc {Subscription request of %s will be accepted in: %s secs. If you don't do anything this dialog will be closed and the request will be accepted.}
::msgcat::mcset nl jamesssubscautoacc {Subscription request of %s will be accepted in: %s secs. If you don't do anything this dialog will be closed and the request will be accepted.}

::msgcat::mcset en jamesssubscautorej {Subscription request of %s will be rejected in: %s secs. If you don't do anything this dialog will be closed and the request will be rejected.}
::msgcat::mcset sv jamesssubscautorej {Subscription request of %s will be rejected in: %s secs. If you don't do anything this dialog will be closed and the request will be rejected.}
::msgcat::mcset pl jamesssubscautorej {Subscription request of %s will be rejected in: %s secs. If you don't do anything this dialog will be closed and the request will be rejected.}
::msgcat::mcset nl jamesssubscautorej {Subscription request of %s will be rejected in: %s secs. If you don't do anything this dialog will be closed and the request will be rejected.}

proc ::Subscribe::AcceptAfter {jid} {
    global  config
    
    set name [GetDisplayName $jid]
    set secs [expr {$config(subscribe,accept-after)/1000}]
    set msg [mc jamesssubscautoacc $name $secs]
    set w [ui::dialog -message $msg -buttons {accept reject} -default accept \
      -command [namespace code [list AcceptCmd $jid]]]    
    after 1000 [namespace code [list AcceptTimer $w $jid $secs]]
}

proc ::Subscribe::AcceptTimer {w jid secs} {
    
    if {[winfo exists $w]} {
	incr secs -1
	set name [GetDisplayName $jid]
	if {$secs <= 0} {
	    ::Jabber::JlibCmd send_presence -to $jid -type "subscribed"
	    destroy $w
	    set msg [mc jamessautoaccepted2 $name]
	    ::ui::dialog -title [mc Info] -icon info -type ok -message $msg
	} else {
	    set msg [mc jamesssubscautoacc $name $secs]
	    $w configure -message $msg
	    after 1000 [namespace code [list AcceptTimer $w $jid $secs]]
	}
    }
}

proc ::Subscribe::AcceptCmd {jid w button} {
    global  config
    
    if {$button eq "accept" || $button eq ""} {
	::Jabber::JlibCmd send_presence -to $jid -type "subscribed"
	if {$config(subscribe,auto-accept-send-msg)} {
	    SendAutoAcceptMsg $jid
	}
    } else {
	::Jabber::JlibCmd send_presence -to $jid -type "unsubscribed"
    }
}

proc ::Subscribe::RejectAfter {jid} {
    global  config
    
    set name [GetDisplayName $jid]
    set secs [expr {$config(subscribe,reject-after)/1000}]
    set msg [mc jamesssubscautorej $name $secs]
    set w [ui::dialog -message $msg -buttons {reject accept} -default reject \
      -command [namespace code [list RejectCmd $jid]]]    
    after 1000 [namespace code [list RejectTimer $w $jid $secs]]
}

proc ::Subscribe::RejectTimer {w jid secs} {

    if {[winfo exists $w]} {
	incr secs -1
	set name [GetDisplayName $jid]
	if {$secs <= 0} {
	    ::Jabber::JlibCmd send_presence -to $jid -type "unsubscribed"
	    destroy $w
	    set msg [mc jamessautoreject2 $name]
	    ::ui::dialog -title [mc Info] -icon info -type ok -message $msg
	} else {
	    set msg [mc jamesssubscautorej $name $secs]
	    $w configure -message $msg
	    after 1000 [namespace code [list RejectTimer $w $jid $secs]]
	}
    }
}

proc ::Subscribe::RejectCmd {jid w button} {
    global  config
    
    if {$button eq "reject" || $button eq ""} {
	::Jabber::JlibCmd send_presence -to $jid -type "unsubscribed"
	if {$config(subscribe,auto-reject-send-msg)} {
	    SendAutoRejectMsg $jid
	}
    } else {
	::Jabber::JlibCmd send_presence -to $jid -type "subscribed"
    }
}

#-------------------------------------------------------------------------------

proc ::Subscribe::SendAutoRejectMsg {jid} {
    
    set autoRejectMsg "Your request has been automatically refused by the peers IM client software. It wasn't an action taken by your party"
    
    ::Jabber::JlibCmd send_message $jid -subject "Auto rejection" \
      -message $autoRejectMsg
}

proc ::Subscribe::SendAutoAcceptMsg {jid} {
    
    set autoAcceptMsg "Your request has been automatically accepted by the peers IM client software. It wasn't an action taken by your party"
    
    ::Jabber::JlibCmd send_message $jid -subject "Auto acception" \
      -message $autoAcceptMsg
}

#-------------------------------------------------------------------------------

if {0} {
    ::Subscribe::Queue "mats@home.se"
    ::Subscribe::Queue "mari@work.se"
    ::Subscribe::Queue "mari.lundberg@someextremelylongname.se"
    ::Subscribe::Queue "donald.duck@disney.com"
    ::Subscribe::Queue "mimmi.duck@disney.com"
}

# SubscribeEx... --
# 
#       A dialog to handle multiple subscription requests.
#       There should only be a single copy of this dialog (singleton).

namespace eval ::SubscribeEx {
    
    # Use option database for customization.
    option add *JSubscribeEx.adduserImage           adduser         widgetDefault
    option add *JSubscribeEx.adduserDisImage        adduserDis      widgetDefault

    variable uid 0
}

proc ::SubscribeEx::NewDlg {} {
    global  this prefs wDlgs config

    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::SubscribeEx::NewDlg"
 
    set w $wDlgs(jsubsc)ex[incr uid]

    # Initialize the state variable, an array.    
    set token [namespace current]::$w
    variable $w
    upvar 0 $w state
    
    set state(w)        $w
    set state(finished) -1
    set state(nusers)   0
    set state(all)      1

    ::UI::Toplevel $w -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace current]::CloseCmd \
      -usemacmainmenu 1 -class JSubscribeEx
    wm title $w [mc "Presence Subscription"]  
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jsubsc)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jsubsc)
    }
  
    set jlib $jstate(jlib)
    
    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill both -expand 1

    if {$config(subscribe,show-head)} {
	set im  [::Theme::GetImage [option get $w adduserImage {}]]
	set imd [::Theme::GetImage [option get $w adduserDisImage {}]]

	ttk::label $wall.head -style Headlabel \
	  -text [mc "Presence Subscription"] -compound left \
	  -image [list $im background $imd]
	pack $wall.head -side top -fill both -expand 1
	
	ttk::separator $wall.s -orient horizontal
	pack $wall.s -side top -fill x
    }
    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 320 -justify left \
      -text [mc jasubmulti $state(nusers)]
    pack $wbox.msg -side top -anchor w

    set wframe $wbox.f
    ttk::frame $wframe
    pack $wframe -side top -anchor w -fill both -expand 1    
    
    ttk::label $wframe.allow -text [mc Allow]
    ttk::label $wframe.jid   -text [mc "Contact ID"]
    ttk::checkbutton $wframe.all \
      -command [namespace code [list All $w]] \
      -variable $token\(all)
    ttk::label $wframe.lall -text [mc All]
    
    grid  $wframe.allow  x  $wframe.jid -padx 0 -pady 4
    grid  $wframe.all    x  $wframe.lall
    grid $wframe.jid -sticky w
    grid $wframe.all -sticky e
    grid $wframe.lall -sticky w
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

    return $w
}

proc ::SubscribeEx::All {w} {
    variable $w
    upvar 0 $w state
    
    foreach {key value} [array get state *,allow] {
	set state($key) $state(all)
    }
}

proc ::SubscribeEx::AddJID {w jid} {
    variable $w
    upvar 0 $w state
    upvar ::Jabber::jstate jstate

    set token [namespace current]::$w

    set wframe $state(frame)
        
    incr state(nusers)
    $state(label) configure -text [mc jasubmulti $state(nusers)]
    
    set name   [$jstate(jlib) roster getname $jid]
    set groups [$jstate(jlib) roster getgroups $jid]
    set group [lindex $groups 0]

    lassign [grid size $wframe] columns rows

    set row $rows
    set state($row,more)  0
    set state($row,allow) $state(all)
    set state($row,jid)   $jid
    set state($row,name)  $name
    set state($row,group) $group
    
    set jstr [::Subscribe::GetDisplayName $jid]
    set jlen [font measure CociDefaultFont $jstr]
    if {$jlen > 220} {
	set len [string length $jstr]
	set n [expr {($len * 220)/$jlen - 2}]
	set jstr [string range $jstr 0 $n]
	append jstr "..."
    }
    
    ttk::checkbutton $wframe.m$row -style ArrowText.TCheckbutton \
      -onvalue 0 -offvalue 1 -variable $token\($row,more) \
      -command [list [namespace current]::More $w $row]
    ttk::checkbutton $wframe.c$row -variable $token\($row,allow)
    ttk::label $wframe.l$row -text $jstr
    ttk::frame $wframe.f$row
    
    grid  $wframe.c$row  $wframe.m$row  $wframe.l$row
    grid  x              x              $wframe.f$row
    grid $wframe.c$row -sticky e
    grid $wframe.l$row $wframe.f$row -sticky w

    return $row
}

proc ::SubscribeEx::More {w row} {
    variable $w
    upvar 0 $w state
    set token [namespace current]::$w
   
    set wframe $state(frame)
    set wcont $wframe.f$row
    set jid $state($row,jid)

    if {$state($row,more)} {

	# Find all our groups for any jid.
	set allGroups [::Jabber::JlibCmd roster getgroups]
	set values [concat [list [mc None]] $allGroups]
		
	ttk::label $wcont.lnick -text "[mc {Nickname}]:" -anchor e
	ttk::entry $wcont.enick -textvariable $token\($row,name)
	ttk::label $wcont.lgroup -text "[mc Group]:" -anchor e
	ttk::combobox $wcont.egroup -values $values \
	  -textvariable $token\($row,group)
	ttk::button $wcont.vcard -text "[mc {View Business Card}]..." \
	  -command [list ::VCard::Fetch other $jid] -style Small.TButton

	grid  $wframe.f$row  -row [expr {$row+1}] -columnspan 1 -column 2
	grid $wframe.f$row -sticky w

	grid  $wcont.lnick   $wcont.enick  -sticky e -pady 2
	grid  $wcont.lgroup  $wcont.egroup -sticky e -pady 2
	grid  x              $wcont.vcard  -pady 2
	grid $wcont.enick $wcont.egroup -sticky ew	
    } else {
	eval destroy [winfo children $wcont]
	grid forget $wcont
    }
}

proc ::SubscribeEx::GetContent {w} {
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

proc ::SubscribeEx::Accept {w} {
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
	    $jlib send_presence -to $jid -type "unsubscribed"
	}
    }
    Free $w
}

proc ::SubscribeEx::CloseCmd {w} {    
    Accept $w
}

proc ::SubscribeEx::Free {w} {
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
    set ::config(subscribed,fancy-dlg) 1

    variable queue [list]
}

if {0} {
    ::Subscribed::Queue "mats@home.se"
    ::Subscribed::Queue "mari@work.se"
    ::Subscribed::Queue "mari.lundberg@someextremelylongname.se"
    ::Subscribed::Queue "donald.duck@disney.com"
    ::Subscribed::Queue "mimmi.duck@disney.com"
}

proc ::Subscribed::Handle {jid} {
    global  config
    
    if {$config(subscribe,multi-dlg)} {
	Queue $jid
    } else {
	::ui::dialog -title [mc "Presence Subscription"] -icon info -type ok \
	  -message [mc jamessallowsub2 $jid]
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
	::ui::dialog -title [mc "Presence Subscription"] -icon info -type ok \
	  -message [mc jamessallowsub2 $jid]
    } elseif {$len > 1} {
	set w $wDlgs(jsubsced)
	if {$config(subscribed,fancy-dlg)} {
	    FancyDlg
	} else {
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
    append msg [::Subscribe::GetDisplayName $jid]
    $w configure -message $msg
}

::msgcat::mcset en jamesssubscedfancy {%s additional contacts can see your presence.}
::msgcat::mcset sv jamesssubscedfancy {%s additional contacts can see your presence.}

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
    
    set box $fr.f$nrow
    ttk::frame $box
    grid  $box  -sticky ew
    
    ttk::label $box.l -style Small.TLabel \
      -text [::Subscribe::GetDisplayName $jid]
    ttk::button $box.b -style Small.TButton \
      -text "[mc {View Business Card}]..." \
      -command [list ::VCard::Fetch other $jid]

    pack $box.l -side left -padx 2 -pady 2
    pack $box.b -side right -padx 2 -pady 2
}

if {0} {
    ::Subscribed::FancyDlg
    ::Subscribed::AddJID "mats@home.se"
    ::Subscribed::AddJID "mari@work.se"
    ::Subscribed::AddJID "mari.lundberg@someextremelylongname.se"
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
	
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(subsc,inrost)     jprefs_subsc_inrost      $jprefs(subsc,inrost)]  \
      [list ::Jabber::jprefs(subsc,notinrost)  jprefs_subsc_notinrost   $jprefs(subsc,notinrost)]  \
      [list ::Jabber::jprefs(subsc,auto)       jprefs_subsc_auto        $jprefs(subsc,auto)]  \
      [list ::Jabber::jprefs(subsc,group)      jprefs_subsc_group       $jprefs(subsc,group)]  \
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
    variable tmpJPrefs
    
    foreach key {inrost notinrost auto group} {
	set tmpJPrefs(subsc,$key) $jprefs(subsc,$key)
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

    set wsubs $wc.fr
    ttk::frame $wsubs

    ttk::label $wsubs.la1 -text "[mc prefsuif2]..."
    ttk::label $wsubs.lin -text "...[mc prefsuis2]:"
    ttk::label $wsubs.lnot -text "...[mc prefsuisnot2]:"

    ttk::separator $wsubs.s -orient vertical
    
    grid  $wsubs.la1  -         -            -sticky w
    grid  $wsubs.lin  -         $wsubs.lnot  -sticky w
    grid  x           $wsubs.s  x            -sticky ns -padx 16
    
    foreach  \
      val { accept        reject        ask }   \
      txt { "Auto-accept" "Auto-reject" "Always ask" } {
	foreach val2 {inrost notinrost} {
	    ttk::radiobutton $wsubs.$val2$val \
	      -text [mc $txt] -value $val  \
	      -variable [namespace current]::tmpJPrefs(subsc,$val2)	      
	}
	grid  $wsubs.inrost$val  ^  $wsubs.notinrost$val  -sticky w
    }
    
    set wauto $wc.auto
    ttk::frame $wauto
    ttk::checkbutton $wauto.sub -text "[mc prefsuauto2]:" \
      -variable [namespace current]::tmpJPrefs(subsc,auto)
    ttk::label $wauto.la -text [mc {Default group}]:
    ttk::entry $wauto.ent -font CociSmallFont \
      -textvariable [namespace current]::tmpJPrefs(subsc,group)
    
    grid  $wauto.sub  -           -
    grid  x           $wauto.la   $wauto.ent
    grid $wauto.sub -sticky w
    grid $wauto.ent -sticky ew
    grid columnconfigure $wauto 0 -minsize 32
    grid columnconfigure $wauto 2 -weight 1
    
    pack  $wsubs  -side top -fill x
    pack  $wauto  -side top -fill x -pady 12
}

proc ::Subscribe::SavePrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    array set jprefs [array get tmpJPrefs]
    unset tmpJPrefs
}

proc ::Subscribe::CancelPrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::Subscribe::UserDefaultsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
