#  JUser.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the UI for adding and editing users.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: JUser.tcl,v 1.7 2004-11-27 08:41:20 matben Exp $

package provide JUser 1.0

namespace eval ::Jabber::User:: {
	
    # A unique running identifier.
    variable uid 0

    # Hooks for add user dialog.
    ::hooks::register quitAppHook  ::Jabber::User::QuitAppHook 
}

proc ::Jabber::User::QuitAppHook { } {
    global  wDlgs
    
    ::UI::SaveWinGeom $wDlgs(jrostadduser)    
}

# Jabber::User::NewDlg --
# 
#       Add new user dialog.

proc ::Jabber::User::NewDlg { } {
    global  this prefs wDlgs

    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jrostadduser)${uid}
    set state(w) $w
    set state(finished) -1

    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} -closecommand [namespace current]::CloseCmd
    wm title $w [mc {Add New User}]
    
    # Find all our groups for any jid.
    set allGroups [$jstate(roster) getgroups]
    set allTypes  [::Jabber::Roster::GetTransportNames $token]
    
    # Global frame.
    set wall $w.fr
    frame $wall -borderwidth 1 -relief raised
    pack  $wall -fill both -expand 1 -ipadx 2 -ipady 4

    ::headlabel::headlabel $wall.head -text [mc {Add New User}]
    pack $wall.head -side top -fill both -expand 1
       
    label $wall.msg -wraplength 280 -justify left -text [mc jarostadd]
    pack  $wall.msg -side top -fill both -expand 1 -padx 10

    set wbox $wall.fbox
    frame $wbox
    pack  $wbox -side top

    label $wbox.ltype -text "[mc {Contact Type}]:"
    eval {tk_optionMenu $wbox.type $token\(type)} $allTypes
    label $wbox.ljid -text "[mc {Jabber user id}]:" -anchor e
    entry $wbox.ejid -textvariable $token\(jid)
    label $wbox.lnick -text "[mc {Nick name}]:" -anchor e
    entry $wbox.enick -width 24 -textvariable $token\(name)
    label $wbox.lgroup -text "[mc Group]:" -anchor e
    ::combobox::combobox $wbox.egroup -width 12  \
      -textvariable $token\(group)
    eval {$wbox.egroup list insert end} "None $allGroups"
    
    grid $wbox.ltype  $wbox.type   -sticky e
    grid $wbox.ljid   $wbox.ejid   -sticky e
    grid $wbox.lnick  $wbox.enick  -sticky e
    grid $wbox.lgroup $wbox.egroup -sticky e
    grid $wbox.type $wbox.ejid $wbox.enick $wbox.egroup -sticky ew

    # Cache state variables for the dialog.
    set state(wjid)   $wbox.ejid
    set state(wnick)  $wbox.enick
    set state(wgroup) $wbox.egroup
    
    # Button part.
    set frbot [frame $wall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Add] -default active \
      -command [list [namespace current]::DoAdd $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelAdd $token]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6    
    
    trace add variable $token\(type) write \
      [list [namespace current]::TypeCmd $token]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jrostadduser)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jrostadduser)
    }
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 10]
    } $wall.msg $w]    
    after idle $script

    #::balloonhelp::balloonforwindow $wbox.ltype [mc jarostadd]
    #::balloonhelp::balloonforwindow $wbox.type [mc jarostadd]
        
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    set ans [expr {($state(finished) <= 0) ? "cancel" : "add"}]
    ::Jabber::User::Free $token
    
    return $ans
}

proc ::Jabber::User::CancelAdd {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    ::UI::SaveWinPrefixGeom $wDlgs(jrostadduser)
    set state(finished) 0
    destroy $state(w)
}

proc ::Jabber::User::DoAdd {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    set jid   $state(jid)
    set name  $state(name)
    set group $state(group)

    # In any case the jid should be well formed.
    if {![jlib::jidvalidate $jid]} {
	set ans [tk_messageBox -message [FormatTextForMessageBox  \
	  [mc jamessbadjid $jid]] \
	  -icon error -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }
    
    # Warn if already in our roster.
    set allUsers [$jstate(roster) getusers]
    if {[lsearch -exact $allUsers $jid] >= 0} {
	set ans [tk_messageBox -message [FormatTextForMessageBox  \
	  [mc jamessalreadyinrost $jid]] \
	  -icon error -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }

    # Check the jid we are trying to add.
    if {![catch {jlib::splitjidex $jid node host res}]} {

	# Exclude jabber services.
	if {[lsearch [::Jabber::Roster::GetAllTransportJids] $host] >= 0} {	    
	
	    # If this requires a transport component we must be registered.
	    set transport [lsearch -inline -regexp $allUsers "^${host}.*"]
	    if {$transport == "" } {
		
		# Seems we are not registered.
		set ans [tk_messageBox -type yesno -icon error \
		  -parent $state(w) -message [mc jamessaddforeign $host]]
		if {$ans == "yes"} {
		    ::Jabber::GenRegister::NewDlg -server $host -autoget 1
		    return
		} else {
		    return
		}
	    }
	}
    }
    
    set opts {}
    if {[string length $name]} {
	lappend opts -name $name
    }
    if {($group != "None") && ($group != "")} {
	lappend opts -groups [list $group]
    }
    
    # This is the only (?) situation when a client "sets" a roster item.
    # The actual roster item is pushed back to us, and not set from here.
    eval {$jstate(jlib) roster_set $jid   \
      [list [namespace current]::SetCB $jid]} $opts

    # Send subscribe request.
    $jstate(jlib) send_presence -type "subscribe" -to $jid \
      -command [namespace current]::PresError
        
    ::UI::SaveWinPrefixGeom $wDlgs(jrostadduser)
    set state(finished) 1
    destroy $state(w)
}

# Jabber::User::SetCB --
#
#       This is our callback procedure to the roster set command.
#
# Arguments:
#       jid
#       type        "result" or "error"
#       args

proc ::Jabber::User::SetCB {jid type args} {
    
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} [lindex $args 0] break
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [mc jamessfailsetnick $jid $errcode $errmsg]]
    }	
}

# Jabber::User::PresError --
# 
#       Callback when sending presence to user for (un)subscription requests.

proc ::Jabber::User::PresError {jlibName type args} {
    upvar ::Jabber::jstate jstate
    
    array set argsArr {
	-from       unknown
	-error      {{} Unknown}
	-from       ""
    }
    array set argsArr $args
    
    ::Debug 2 "::Jabber::User::PresError type=$type, args=$args"

    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $argsArr(-error) break
	set ans [tk_messageBox -icon error -type yesno -message  \
	  "We received an error when (un)subscribing to $argsArr(-from).\
	  The error is: $errmsg ($errcode).\
	  Do you want to remove it from your roster?"]
	if {$ans == "yes"} {
	    $jstate(jlib) roster_remove $argsArr(-from) [namespace current]::PushProc
	}
    }
}

proc ::Jabber::User::TypeCmd {token name1 name2 op} {
    variable $token
    upvar 0 $token state
        
    set wjid $state(wjid)
    set type $state(type)
    set trpt [::Jabber::Roster::GetTrptFromName $type]

    # Seems to be necessary to achive any selection.
    focus $wjid

    switch -- $trpt {
	jabber - aim - yahoo {
	    set state(jid) "userName@$state(servicejid,$trpt)"
	}
	icq {
	    set state(jid) "screeNumber@$state(servicejid,icq)"
	}
	msn {
	    set state(jid) "userName%hotmail.com@$state(servicejid,msn)"
	}
	default {
	    set state(jid) "userName@$state(servicejid,$trpt)"
	}
    }
    set ind [string first @ $state(jid)]
    if {$ind > 0} {
	$wjid selection range 0 $ind
    }
}

proc ::Jabber::User::CloseCmd {wclose} {
    global  wDlgs
    
    ::UI::SaveWinPrefixGeom $wDlgs(jrostadduser)
}

#--- The Edit section ----------------------------------------------------------

# Jabber::User::EditDlg --
# 
#       Dispatcher for edit dialog.

proc ::Jabber::User::EditDlg {jid} {

    if {[::Jabber::Roster::IsTransport $jid]} {
	EditTransportDlg $jid
    } else {
	EditUserDlg $jid
    }
}

proc ::Jabber::User::EditTransportDlg {jid} {
    upvar ::Jabber::jstate jstate
    
    # We get jid2 here. For transports we need the full jid!
    set res [$jstate(roster) getresources $jid]
    set jid3 $jid/$res
    set subscription [$jstate(roster) getsubscription $jid3]
    jlib::splitjidex $jid node host x
    set trpttype [$jstate(jlib) service gettype $host]
    set subtype [lindex [split $trpttype /] 1]
    set typename [::Jabber::Roster::GetNameFromTrpt $subtype]
    set msg [mc jamessowntrpt $typename $jid3 $subscription]

    tk_messageBox -title [mc {Transport Info}] -type ok -message $msg \
      -icon info
}

# Jabber::User::EditUserDlg --
# 
#       Edit user dialog.

proc ::Jabber::User::EditUserDlg {jid} {
    global  this prefs wDlgs

    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jrostedituser)${uid}
    set state(w) $w
    set state(finished) -1
    
    set istransport [::Jabber::Roster::IsTransport $jid]
    if {$istransport} {
	set title [mc {Transport Info}]
    } else {
	set title [mc {Edit User}]
    }

    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} -closecommand [namespace current]::CloseCmd
    wm title $w $title
    
    # Find all our groups for any jid.
    set allGroups [$jstate(roster) getgroups]

    # Get 'name' and 'group(s)'.
    set name ""
    set groups {}
    set subscribe 0
    set unsubscribe 0
    set subscription "none"
    foreach {key value} [$jstate(roster) getrosteritem $jid] {
	set keym [string trimleft $key "-"]
	set $keym $value
    }
    set group [lindex $groups 0]
    
    set state(jid)         $jid
    set state(name)        $name
    set state(group)       $group
    set state(origname)    $name
    set state(origgroup)   $group
    set state(subscribe)   $subscribe
    set state(unsubscribe) $unsubscribe
    if {$istransport} {
	jlib::splitjidex $jid node host res
	set trpttype [$jstate(jlib) service gettype $host]
	set subtype [lindex [split $trpttype /] 1]
	set msg [mc jamessowntrpt $subtype $jid $subscription]
    } else {
	set msg [mc jarostset $jid]
    }

    # Global frame.
    set wall $w.fr
    frame $wall -borderwidth 1 -relief raised
    pack  $wall -fill both -expand 1 -ipadx 2 -ipady 4

    ::headlabel::headlabel $wall.head -text $title
    pack $wall.head -side top -fill both -expand 1
       
    label $wall.msg -wraplength 280 -justify left -text $msg
    pack  $wall.msg -side top -fill both -expand 1 -padx 10

    set wbox $wall.fbox
    frame $wbox
    pack  $wbox -side top

    label $wbox.lnick -text "[mc {Nick name}]:" -anchor e
    entry $wbox.enick -width 24 -textvariable $token\(name)
    label $wbox.lgroup -text "[mc Group]:" -anchor e
    ::combobox::combobox $wbox.egroup -width 12  \
      -textvariable $token\(group)
    eval {$wbox.egroup list insert end} "None $allGroups"

    if {!$istransport} {

	# Give user an opportunity to subscribe/unsubscribe other jid.
	switch -- $subscription {
	    from - none {
		checkbutton $wbox.csubs -text "  [mc jarostsub]"  \
		  -variable $token\(subscribe)
	    }
	    both - to {
		checkbutton $wbox.csubs -text "  [mc jarostunsub]" \
		  -variable $token\(unsubscribe)
	    }
	}
	
	# Present subscription.
	set str "[mc Subscription]: [mc [string totitle $subscription]]"
	label $wbox.lsub -text $str -anchor e
    }
    
    grid $wbox.lnick  $wbox.enick  -sticky e
    grid $wbox.lgroup $wbox.egroup -sticky e
    if {!$istransport} {
	grid x            $wbox.csubs  -sticky w
	grid x            $wbox.lsub   -sticky w
    }
    grid $wbox.enick  $wbox.egroup -sticky ew
    
    # Cache state variables for the dialog.
    set state(wjid)   $wbox.ejid
    set state(wnick)  $wbox.enick
    set state(wgroup) $wbox.egroup
    
    # Button part.
    set frbot [frame $wall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Set] -default active \
      -command [list [namespace current]::DoEdit $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelEdit $token]]  \
      -side right -padx 5 -pady 5
    if {!$istransport} {
	pack [button $frbot.bvcard -text " [mc {Get vCard}]..."  \
	  -command [list ::VCard::Fetch other $jid]]  \
	  -side right -padx 5 -pady 5
    }
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6    
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jrostedituser)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jrostedituser)
    }
    wm resizable $w 0 0
    	
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 10]
    } $wall.msg $w]    
    after idle $script

    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    set ans [expr {($state(finished) <= 0) ? "cancel" : "edit"}]
    ::Jabber::User::Free $token
    
    return $ans
}

proc ::Jabber::User::CancelEdit {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    ::UI::SaveWinPrefixGeom $wDlgs(jrostedituser)
    set state(finished) 0
    destroy $state(w)
}

proc ::Jabber::User::DoEdit {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    set jid         $state(jid)
    set name        $state(name)
    set group       $state(group)
    set origname    $state(origname)
    set origgroup   $state(origgroup)
    set subscribe   $state(subscribe)
    set unsubscribe $state(unsubscribe)
    
    # This is the only situation when a client "sets" a roster item.
    # The actual roster item is pushed back to us, and not set from here.
    set opts {}
    if {[string length $name]} {
	lappend opts -name $name
    }
    if {$group != $origgroup} {
	if {$group == "None"} {
	    set group ""
	}
	lappend opts -groups [list $group]
    }
    eval {$jstate(jlib) roster_set $jid   \
      [list [namespace current]::SetCB $jid]} $opts

    # Send (un)subscribe request.
    if {$subscribe} {
	$jstate(jlib) send_presence -type "subscribe" -to $jid \
	  -command [namespace current]::PresError
    } elseif {$unsubscribe} {
	$jstate(jlib) send_presence -type "unsubscribe" -to $jid \
	  -command [namespace current]::PresError
    }
    
    ::UI::SaveWinPrefixGeom $wDlgs(jrostedituser)
    set state(finished) 1
    destroy $state(w)
}

proc ::Jabber::User::Free {token} {
    variable $token
    upvar 0 $token state
	
    unset -nocomplain state
}

#-------------------------------------------------------------------------------
