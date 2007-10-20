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
# $Id: Subscribe.tcl,v 1.47 2007-10-20 13:04:57 matben Exp $

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
    
    variable queue [list]
}

if {0} {
    ::Subscribe::Queue "mats@home.se"
    ::Subscribe::Queue "mari@work.se"
    ::Subscribe::Queue "mari.lundberg@somelongname.se"
    ::Subscribe::Queue "donald.duck@disney.com"
}

# Mechanism for queuing subscription events. In situations (transports) when
# we can get several of them at once we show an extended dialog.

proc ::Subscribe::Queue {jid} {
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
	    after 2000 [namespace code ExecQueue]
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
#       none

proc ::Subscribe::NewDlg {jid} {
    global  this prefs wDlgs config

    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Subscribe::NewDlg jid=$jid"
    
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

    set ujid [jlib::unescapejid $jid]
    set str [mc jasubwant2 $ujid]
    if {!$havesubsc} {
	append str " [mc jasubopts2]"
    }
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 200 -justify left -text $str
    pack $wbox.msg -side top -anchor w

    # If we already have a subscription we've already got the opportunity
    # to select nickname and group. Do not repeat that.
    if {!$havesubsc} {
	set frmid $wbox.frmid
	ttk::frame $frmid
	pack $frmid -side top -fill both -expand 1
	
	ttk::label $frmid.lnick -text "[mc {Nickname}]:" -anchor e
	ttk::entry $frmid.enick -width 24 -textvariable $token\(name)
	ttk::label $frmid.lgroup -text "[mc Group]:" -anchor e
	ttk::combobox $frmid.egroup -values [concat None $allGroups] \
	  -textvariable $token\(group)

	grid  $frmid.lnick   $frmid.enick  -sticky e -pady 2
	grid  $frmid.lgroup  $frmid.egroup -sticky e -pady 2
	grid  $frmid.enick   $frmid.egroup -sticky ew	
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

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 30]
    } $wbox.msg $w]    
    after idle $script

    return
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
    upvar ::Jabber::jstate jstate
    
    set jid $state(jid)
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
	if {[string length $state(name)]} {
	    lappend opts -name $state(name)
	}
	if {($state(group) ne "") && ($state(group) ne "None")} {
	    lappend opts -groups [list $state(group)]
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
    
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    set state(finished) 0
    destroy $state(w)
    unset state
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
    set state(name)     ""
    set state(group)    ""

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

    set str "A number of contacts want to see your presence. You can allow\
 all of them or deselect any one of them. If you cancel you deny all of them."

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 320 -justify left -text $str
    pack $wbox.msg -side top -anchor w

    set wframe $wbox.f
    ttk::frame $wframe
    pack $wframe -side top -anchor w -fill both -expand 1    
    
    #ttk::label $wframe.more  -text [mc More]
    ttk::label $wframe.allow -text [mc Allow]
    ttk::label $wframe.jid   -text [mc "Contact ID"]
    
    #grid  $wframe.more  $wframe.allow  $wframe.jid -padx 4 -pady 4
    grid  $wframe.allow  x  $wframe.jid -padx 4 -pady 4
    grid $wframe.jid -sticky w
    grid columnconfigure $wframe 2 -minsize 220
    
    set state(wframe) $wframe    
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Allow] -default active \
      -command [list [namespace current]::Accept $w]
    ttk::button $frbot.btcancel -text [mc Deny]  \
      -command [list [namespace current]::Deny $w]
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
    bind $w <Return> [list $frbot.btok invoke]

    return $w
}

proc ::SubscribeEx::AddJID {w jid} {
    variable $w
    upvar 0 $w state
    set token [namespace current]::$w

    set wframe $state(wframe)
    
    lassign [grid size $wframe] columns rows
    puts "grid size=[grid size $wframe]"
    
    set row $rows
    set state($row,more)  0
    set state($row,allow) 1
    set state($row,jid)   $jid
    
    ttk::checkbutton $wframe.m$row -style ArrowText.TCheckbutton \
      -onvalue 0 -offvalue 1 -variable $token\($row,more) \
      -command [list [namespace current]::More $w $row]
    ttk::checkbutton $wframe.c$row -variable $token\($row,allow)
    ttk::label $wframe.l$row -text $jid
    ttk::frame $wframe.f$row
    
    #grid  $wframe.m$row  $wframe.c$row  $wframe.l$row
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
   
    puts "::SubscribeEx::More row=$row"
    
    set wframe $state(wframe)
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
	  -command [list ::VCard::Fetch other $jid]

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
    foreach {key jid} [array get state jid,*] {
	set row [string map {"jid," ""} $key]
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

    foreach line [GetContent $w] {
	set jid [lindex $line 0]
	set allow [lindex $line 1]
	set opts [lrange $ine 2 end]
	
	
	
    }
    
    
    Free $w
}

proc ::SubscribeEx::Deny {w} {
    variable $w
    upvar 0 $w state

    foreach line [GetContent $w] {
	set jid [lindex $line 0]

    }
    
    Free $w
}

proc ::SubscribeEx::CloseCmd {w} {
    variable $w
    
    puts "::SubscribeEx::CloseCmd w=$w"
    
    Free $w
}

proc ::SubscribeEx::Free {w} {
    global  wDlgs
    variable $w
    upvar 0 $w state
	
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    destroy $state(w)
    unset -nocomplain state
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
