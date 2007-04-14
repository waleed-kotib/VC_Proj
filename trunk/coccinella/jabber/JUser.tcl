#  JUser.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the UI for adding and editing users.
#      
#  Copyright (c) 2004-2005  Mats Bengtsson
#  
# $Id: JUser.tcl,v 1.27 2007-04-14 12:32:16 matben Exp $

package provide JUser 1.0

namespace eval ::JUser:: {
	
    option add *JUser.adduserImage                adduser         widgetDefault
    option add *JUser.adduserDisImage             adduserDis      widgetDefault

    # A unique running identifier.
    variable uid 0

    # Hooks for add user dialog.
    ::hooks::register quitAppHook  ::JUser::QuitAppHook 
}

proc ::JUser::QuitAppHook { } {
    global  wDlgs
    
    ::UI::SaveWinGeom $wDlgs(jrostadduser)    
}

proc ::JUser::OnMenu {} {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "connectfin"} {
	NewDlg
    }   
}

# JUser::NewDlg --
# 
#       Add new user dialog.

proc ::JUser::NewDlg {args} {
    global  this prefs wDlgs

    variable uid
    upvar ::Jabber::jstate jstate
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token state
    
    array set argsA $args
    
    set w $wDlgs(jrostadduser)${uid}
    set state(w) $w
    set state(finished) -1

    ::UI::Toplevel $w -class JUser \
      -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} -closecommand [namespace current]::CloseCmd
    wm title $w [mc {Add New User}]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jrostadduser)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jrostadduser)
    }

    set im  [::Theme::GetImage [option get $w adduserImage {}]]
    set imd [::Theme::GetImage [option get $w adduserDisImage {}]]

    # Find all our groups for any jid.
    set allGroups [$jstate(jlib) roster getgroups]
    set trpts [::Roster::GetTransportNames]
    
    set menuDef [list]
    foreach spec $trpts {
	lassign $spec jid type name
	set state(servicejid,$type) $jid
	set state(servicetype,$jid) $type
	set imtrpt [::Servicons::Get gateway/$type]
	lappend menuDef [list $name -value $jid -image $imtrpt]
    }
    
    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill both -expand 1

    ttk::label $wall.head -style Headlabel \
      -text [mc {Add New User}] -compound left \
      -image [list $im background $imd]
    pack $wall.head -side top -fill both -expand 1

    ttk::separator $wall.s -orient horizontal
    pack $wall.s -side top -fill x

    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 280 -justify left -text [mc jarostadd]
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.ltype -text "[mc {Contact Type}]:"
    ui::optionmenu $frmid.type -menulist $menuDef -direction flush  \
      -variable $token\(type) -command [namespace code [list TrptCmd $token]]
    ttk::label $frmid.ljid -text "[mc {Jabber user ID}]:" -anchor e
    ttk::entry $frmid.ejid -textvariable $token\(jid)
    ttk::label $frmid.lnick -text "[mc {Nick name}]:" -anchor e
    ttk::entry $frmid.enick -textvariable $token\(name)
    ttk::label $frmid.lgroup -text "[mc Group]:" -anchor e
    ttk::combobox $frmid.egroup  \
      -textvariable $token\(group) -values [concat None $allGroups]
    
    grid  $frmid.ltype   $frmid.type   -sticky e -pady 2
    grid  $frmid.ljid    $frmid.ejid   -sticky e -pady 2
    grid  $frmid.lnick   $frmid.enick  -sticky e -pady 2
    grid  $frmid.lgroup  $frmid.egroup -sticky e -pady 2

    grid $frmid.type $frmid.ejid $frmid.enick $frmid.egroup -sticky ew

    set state(jid)   ""
    set state(name)  ""
    set state(group) ""
    if {[info exists argsA(-jid)]} {
	set state(jid) $argsA(-jid)
    }
    
    # Cache state variables for the dialog.
    set state(wjid)   $frmid.ejid
    set state(wnick)  $frmid.enick
    set state(wgroup) $frmid.egroup
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Add] -default active \
      -command [list [namespace current]::DoAdd $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelAdd $token]
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
    
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 30]
    } $wbox.msg $w]    
    after idle $script

    #::balloonhelp::balloonforwindow $wbox.ltype [mc jarostadd]
    #::balloonhelp::balloonforwindow $wbox.type [mc jarostadd]
        
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    set ans [expr {($state(finished) <= 0) ? "cancel" : "add"}]
    Free $token
    
    return $ans
}

proc ::JUser::CancelAdd {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    ::UI::SaveWinPrefixGeom $wDlgs(jrostadduser)
    set state(finished) 0
    destroy $state(w)
}

proc ::JUser::DoAdd {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    set jid   $state(jid)
    set name  $state(name)
    set group $state(group)

    # In any case the jid should be well formed.
    if {![jlib::jidvalidate $jid]} {
	set ans [::UI::MessageBox -message [mc jamessbadjid $jid] \
	  -icon error -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }
    set jlib $jstate(jlib)
    
    # Warn if already in our roster.
    set allUsers [$jlib roster getusers]
    if {[$jlib roster isitem $jid]} {
	set ans [::UI::MessageBox -message [mc jamessalreadyinrost $jid] \
	  -icon error -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }

    # Check the jid we are trying to add.
    if {![catch {jlib::splitjidex $jid node host res}]} {

	# Exclude jabber services.
	if {[lsearch [::Roster::GetAllTransportJids] $host] >= 0} {	    
	
	    # If this requires a transport component we must be registered.
	    set transport [lsearch -inline -regexp $allUsers "^${host}.*"]
	    if {$transport eq "" } {
		
		# Seems we are not registered.
		set ans [::UI::MessageBox -type yesnocancel -icon error \
		  -parent $state(w) -message [mc jamessaddforeign $host]]
		if {$ans eq "yes"} {
		    ::GenRegister::NewDlg -server $host -autoget 1
		    return
		} elseif {$ans eq "cancel"} {
		    return
		}
	    }
	}
    }
    
    set opts [list]
    if {[string length $name]} {
	lappend opts -name $name
    }
    if {($group ne "None") && ($group ne "")} {
	lappend opts -groups [list $group]
    }
    
    # This is the only (?) situation when a client "sets" a roster item.
    # The actual roster item is pushed back to us, and not set from here.
    set cb [list [namespace code SetCB] $jid]
    eval {$jlib roster send_set $jid -command $cb} $opts    

    # Send subscribe request.
    $jlib send_presence -type "subscribe" -to $jid \
      -command [namespace current]::PresError
        
    ::UI::SaveWinPrefixGeom $wDlgs(jrostadduser)
    set state(finished) 1
    destroy $state(w)
}

# JUser::SetCB --
#
#       This is our callback procedure to the roster set command.
#
# Arguments:
#       jid
#       type        "result" or "error"
#       args

proc ::JUser::SetCB {jid type queryE} {
    
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $queryE break
	::UI::MessageBox -icon error -type ok -message \
	  [mc jamessfailsetnick $jid $errcode $errmsg]
    }	
}

# JUser::PresError --
# 
#       Callback when sending presence to user for (un)subscription requests.

proc ::JUser::PresError {jlibname xmldata} {
    upvar ::Jabber::jstate jstate
    
    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {$type eq ""} {
	set type "available"
    }    
    if {[string equal $type "error"]} {
	set errspec [jlib::getstanzaerrorspec $xmldata]
	if {[llength $errspec]} {
	    set errcode [lindex $errspec 0]
	    set errmsg  [lindex $errspec 1]
	    set str "We received an error when (un)subscribing to $from.\
	      The error is: $errmsg ($errcode).\
	      Do you want to remove it from your roster?"
	    set ans [::UI::MessageBox -icon error -type yesno -message $str]
	    if {$ans eq "yes"} {
		$jstate(jlib) roster send_remove $from
	    }
	}
    }
}

proc ::JUser::TrptCmd {token jid} {
    variable $token
    upvar 0 $token state
	
    set wjid $state(wjid)
    set type $state(servicetype,$jid)

    # Seems to be necessary to achive any selection.
    focus $wjid
    set state(jid) [format [::Gateway::GetTemplateJID $type] $jid]
    set ind [string first @ $state(jid)]
    if {$ind > 0} {
	$wjid selection range 0 $ind
    }
}

proc ::JUser::CloseCmd {wclose} {
    global  wDlgs
    
    ::UI::SaveWinPrefixGeom $wDlgs(jrostadduser)
}

#--- The Edit section ----------------------------------------------------------

# JUser::EditDlg --
# 
#       Dispatcher for edit dialog.

proc ::JUser::EditDlg {jid} {

    if {[::Roster::IsTransport $jid]} {
	EditTransportDlg $jid
    } else {
	EditUserDlg $jid
    }
}

proc ::JUser::EditTransportDlg {jid} {
    upvar ::Jabber::jstate jstate
    
    set jlib $jstate(jlib)
    
    # We get jid2 here. For transports we need the full jid!
    set res [lindex [$jlib roster getresources $jid] 0]
    if {$res eq ""} {
	set jid3 $jid
    } else {
	set jid3 $jid/$res
    }
    set subscription [$jlib roster getsubscription $jid3]
    jlib::splitjidex $jid node host x
    set trpttype [lindex [$jlib disco types $host] 0]
    set subtype [lindex [split $trpttype /] 1]
    set typename [::Roster::GetNameFromTrpt $subtype]
    set msg [mc jamessowntrpt $typename $jid3 $subscription]

    ::UI::MessageBox -title [mc {Transport Info}] -type ok -message $msg \
      -icon info
}

# JUser::EditUserDlg --
# 
#       Edit user dialog.

proc ::JUser::EditUserDlg {jid} {
    global  this prefs wDlgs

    variable uid
    upvar ::Jabber::jstate jstate
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jrostedituser)${uid}
    set state(w) $w
    set state(finished) -1
    
    set istransport [::Roster::IsTransport $jid]
    if {$istransport} {
	set title [mc {Transport Info}]
    } else {
	set title [mc {Edit User}]
    }

    ::UI::Toplevel $w -class JUser \
      -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} -closecommand [namespace current]::CloseCmd
    wm title $w $title
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jrostedituser)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jrostedituser)
    }
    set im  [::Theme::GetImage [option get $w adduserImage {}]]
    set imd [::Theme::GetImage [option get $w adduserDisImage {}]]
    
    set jlib $jstate(jlib)

    # Find all our groups for any jid.
    set allGroups [$jlib roster getgroups]

    # Get 'name' and 'group(s)'.
    set name ""
    set groups [list]
    set subscribe 0
    set unsubscribe 0
    set subscription "none"
    foreach {key value} [$jlib roster getrosteritem $jid] {
	
	# 'groups', 'subscription',...
	set keym [string trimleft $key "-"]
	set $keym $value
    }
    set groups [lsort -unique $groups]
    set group [lindex $groups 0]

    # We need at least one entry here even if no groups.
    if {$groups eq {}} {
	set groups "None"
    }

    set state(jid)         $jid
    set state(name)        $name
    set state(group)       $group
    set state(origname)    $name
    set state(origgroup)   $group
    set state(origgroups)  $groups
    set state(ngroups)     [llength $groups]
    set state(subscribe)   $subscribe
    set state(unsubscribe) $unsubscribe
    if {$istransport} {
	jlib::splitjidex $jid node host res
	set trpttype [lindex [$jlib disco types $host] 0]
	set subtype [lindex [split $trpttype /] 1]
	set msg [mc jamessowntrpt $subtype $jid $subscription]
    } else {
	set msg [mc jarostset $jid]
    }

    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill both -expand 1

    ttk::label $wall.head -style Headlabel \
      -text $title -compound left \
      -image [list $im background $imd]
    pack $wall.head -side top -fill both -expand 1

    ttk::separator $wall.s -orient horizontal
    pack $wall.s -side top -fill x

    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 280 -justify left -text $msg
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.lnick -text "[mc {Nick name}]:" -anchor e
    ttk::entry $frmid.enick -textvariable $token\(name)
    grid  $frmid.lnick   $frmid.enick   -pady 2
    grid  $frmid.lnick  -sticky e
    grid  $frmid.enick  -sticky ew

    set igroup 0
    foreach group $groups {
	set wglabel $frmid.lgroup${igroup}
	set wgcombo $frmid.egroup${igroup}
	ttk::label $wglabel -text "[mc Group]:" -anchor e
	ttk::combobox $wgcombo  \
	  -textvariable $token\(group${igroup}) -values [concat None $allGroups]
	set state(group${igroup}) $group
	grid  $wglabel  $wgcombo  -pady 2 -sticky e
	grid  $wgcombo  -sticky ew
	incr igroup
    }

    if {!$istransport} {

	# Give user an opportunity to subscribe/unsubscribe other jid.
	switch -- $subscription {
	    from - none {
		ttk::checkbutton $frmid.csubs -style Small.TCheckbutton \
		  -text [mc jarostsub]  \
		  -variable $token\(subscribe)
	    }
	    both - to {
		ttk::checkbutton $frmid.csubs -style Small.TCheckbutton \
		  -text [mc jarostunsub]  \
		  -variable $token\(unsubscribe)
	    }
	}
	
	# Present subscription.
	set str "[mc Subscription]: "
	append str [mc [string totitle $subscription]]
	ttk::label $frmid.lsub -style Small.TLabel \
	  -text $str -anchor e
    }
    
    if {!$istransport} {
	grid  x  $frmid.csubs  -sticky w -pady 2
	grid  x  $frmid.lsub   -sticky w -pady 2
    }
    
    # Cache state variables for the dialog.
    set state(wjid)   $frmid.ejid
    set state(wnick)  $frmid.enick
    set state(wgroup) $frmid.egroup
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Set] -default active \
      -command [list [namespace current]::DoEdit $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelEdit $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    if {!$istransport} {
	ttk::button $frbot.bvcard -text "[mc {Get vCard}]..."  \
	  -command [list ::VCard::Fetch other $jid]
	pack $frbot.bvcard -side right
    }
    pack $frbot -side top -fill x
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    	
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 40]
    } $wbox.msg $w]    
    after idle $script

    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    set ans [expr {($state(finished) <= 0) ? "cancel" : "edit"}]
    ::JUser::Free $token
    
    return $ans
}

proc ::JUser::CancelEdit {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    ::UI::SaveWinPrefixGeom $wDlgs(jrostedituser)
    set state(finished) 0
    destroy $state(w)
}

proc ::JUser::DoEdit {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    set jid         $state(jid)
    set name        $state(name)
    set group       $state(group)
    set origname    $state(origname)
    set origgroup   $state(origgroup)
    set origgroups  $state(origgroups)
    set subscribe   $state(subscribe)
    set unsubscribe $state(unsubscribe)
	
    # This is the only situation when a client "sets" a roster item.
    # The actual roster item is pushed back to us, and not set from here.
    set opts [list]
    if {[string length $name]} {
	lappend opts -name $name
    }
    set groups [list]
    for {set igroup 0} {$igroup < $state(ngroups)} {incr igroup} { 
	if {[info exists state(group${igroup})]} {
	    set group $state(group${igroup})
	    if {($group ne "None") && ($group ne "")} {
		lappend groups $group
	    }
	}
    }
    set groups [lsort -unique $groups]
    if {$groups ne $origgroups} {
	lappend opts -groups $groups
    }
    set jlib $jstate(jlib)

    set cb [list [namespace code SetCB] $jid]
    eval {$jlib roster send_set $jid -command $cb} $opts    
    
    # Send (un)subscribe request.
    if {$subscribe} {
	$jlib send_presence -type "subscribe" -to $jid \
	  -command [namespace current]::PresError
    } elseif {$unsubscribe} {
	$jlib send_presence -type "unsubscribe" -to $jid \
	  -command [namespace current]::PresError
    }
    
    ::UI::SaveWinPrefixGeom $wDlgs(jrostedituser)
    set state(finished) 1
    destroy $state(w)
}

proc ::JUser::Free {token} {
    variable $token
    upvar 0 $token state
	
    unset -nocomplain state
}

#-------------------------------------------------------------------------------
