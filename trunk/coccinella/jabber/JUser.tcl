#  JUser.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the UI for adding and editing users.
#      
#  Copyright (c) 2004-2008  Mats Bengtsson
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
# $Id: JUser.tcl,v 1.62 2008-04-24 13:45:24 matben Exp $

package provide JUser 1.0

namespace eval ::JUser {
	
    option add *JUser.adduserImage              contact-new         widgetDefault
    option add *JUser.adduserDisImage           contact-new-Dis     widgetDefault
    option add *JUser.vcardImage                vcard               widgetDefault

    # A unique running identifier.
    variable uid 0

    # Hooks for add user dialog.
    ::hooks::register quitAppHook  ::JUser::QuitAppHook 

    # Configurations:
    # Details of how to handle menubutton selection for non-xmpp systems.
    set ::config(adduser,warn-non-xmpp-onselect) 0
    set ::config(adduser,add-non-xmpp-onselect)  1
    set ::config(adduser,dlg-type-ask-register)  yesnocancel
    
    # How transports are listed and handled in menubutton.
    set ::config(adduser,trpt-spec-type)         single ;# multi|single
    
    # Show head label in dialog.
    set ::config(adduser,show-head)              1
    
    # Use name and group in dialog?
    set ::config(adduser,show-nick-group)        0
}

proc ::JUser::QuitAppHook {} {
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
#       
# Arguments:
#       args:   -jid JID to add
#               -transportjid JID
#                 
#       

proc ::JUser::NewDlg {args} {
    global  this prefs wDlgs config

    variable uid
    upvar ::Jabber::jstate jstate
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token state
    
    array set argsA $args
    
    set w $wDlgs(jrostadduser)$uid
    set state(w) $w
    set state(finished) -1

    ::UI::Toplevel $w -class JUser \
      -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} -closecommand [namespace current]::CloseCmd
    wm title $w [mc "Add Contact"]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jrostadduser)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jrostadduser)
    }

    # Find all our groups for any jid.
    set allGroups [$jstate(jlib) roster getgroups]
    set groupValues [concat [list [mc None]] $allGroups]
    
    # Design the menu.
    set menuDef [list]
    if {$config(adduser,trpt-spec-type) eq "multi"} {
	set trpts [::Roster::GetTransportSpec "%name (%jid)"]
	foreach spec $trpts {
	    lassign $spec jid type name
	    set state(servicejid,$type) $jid
	    set state(servicetype,$jid) $type
	    set imtrpt [::Servicons::Get gateway/$type]
	    lappend menuDef [list $name -value $jid -image $imtrpt]
	}
    } else {
	set trpts [::Roster::GetTransportSpec "%name"]
	foreach spec $trpts {
	    lassign $spec jid type name
	    set state(servicejid,$type) $jid
	    set state(servicetype,$jid) $type
	    
	    # We only list one of each.
	    if {($type ne "xmpp") && [info exists added($type)]} { 
		continue
	    }
	    set imtrpt [::Servicons::Get gateway/$type]
	    lappend menuDef [list $name -value $jid -image $imtrpt]
	    set added($type) 1
	}
	unset -nocomplain added
    }
    set defaultJID [lindex $trpts 0 0]
        
    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill both -expand 1

    if {$config(adduser,show-head)} {
	set im  [::Theme::Find32Icon $w adduserImage]
	set imd [::Theme::Find32Icon $w adduserDisImage]

	ttk::label $wall.head -style Headlabel \
	  -text [mc "Add Contact"] -compound left \
	  -image [list $im background $imd]
	pack $wall.head -side top -fill both -expand 1
	
	ttk::separator $wall.s -orient horizontal
	pack $wall.s -side top -fill x
    }
    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set str [mc jarostadd3]
    if {$config(adduser,show-nick-group)} {
	append str " " [mc jarostaddopt]
    }
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 280 -justify left -text $str
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    # NB: the state(jid) is actually the prompt which is a real JID
    # on xmpp systems and the native ID on foreign IM systems.
    ttk::label $frmid.ltype -text "[mc {Chat system}]:"
    ui::optionmenu $frmid.type -menulist $menuDef -direction flush  \
      -variable $token\(gjid) -command [namespace code [list TrptCmd $token]]
    ttk::label $frmid.ljid -text "[mc {Contact ID}]:" -anchor e
    ttk::entry $frmid.ejid -textvariable $token\(jid)
    ttk::label $frmid.lnick -text "[mc Nickname]:" -anchor e
    ttk::entry $frmid.enick -textvariable $token\(name)
    ttk::label $frmid.lgroup -text "[mc Group]:" -anchor e
    ttk::combobox $frmid.egroup  \
      -textvariable $token\(group) -values $groupValues
    
    grid  $frmid.ltype   $frmid.type   -sticky e -pady 2
    grid  $frmid.ljid    $frmid.ejid   -sticky e -pady 2
    grid $frmid.type $frmid.ejid -sticky ew
    grid columnconfigure $frmid 1 -minsize [$frmid.type maxwidth]

    ::balloonhelp::balloonforwindow $frmid.ejid [mc tooltip-contactid]

    if {$config(adduser,show-nick-group)} {
	grid  $frmid.lnick   $frmid.enick  -sticky e -pady 2
	grid  $frmid.lgroup  $frmid.egroup -sticky e -pady 2
	grid $frmid.enick $frmid.egroup -sticky ew

	::balloonhelp::balloonforwindow $frmid.enick [mc registration-nick]
	::balloonhelp::balloonforwindow $frmid.egroup [mc tooltip-group]
    }

    set state(gjid)  $defaultJID
    set state(jid)   ""
    set state(name)  ""
    set state(group) ""
    if {[info exists argsA(-jid)]} {
	set state(jid) [jlib::unescapejid $argsA(-jid)]
    }
    if {[info exists argsA(-transportjid)]} {
	set trptjid $argsA(-transportjid)
	if {[info exists state(servicetype,$trptjid)]} {
	    set type $state(servicetype,$trptjid)
	    set state(gjid) $trptjid
	    set state(jid) [::Gateway::GetPrompt $type]
	}
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
    
    focus $frmid.ejid
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    bind $state(wjid) <Map> { focus %W }
    bind $w <Destroy> \
      +[subst { if {"%W" eq "$w"} { [namespace code [list Free $token]] } }]
    
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 30]
    } $wbox.msg $w]    
    after idle $script
    
    return $token
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
    global  wDlgs config
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    set jlib $jstate(jlib)

    # We MUST use the bare JID else hell breaks lose.
    set state(jid) [jlib::barejid $state(jid)]
    set gjid $state(gjid)
    set type $state(servicetype,$gjid)

    
    # The user inputs the chat systems native ID typically. Get JID.
    set jid [::Gateway::GetJIDFromPromptHeuristics $state(jid) $type]        
    set name  $state(name)
    set group $state(group)
    
    Debug 2 "::JUser::DoAdd type=$type, jid=$state(jid), gjid=$state(gjid), jid=$jid"

    # In any case the jid should be well formed.
    if {![jlib::jidvalidate $jid]} {
	set ans [::UI::MessageBox -message [mc jamessjidinvalid2 $jid] \
	  -icon error -title [mc Error] -parent $state(w)]
	return
    }
    
    # Warn if already in our roster.
    set users [$jlib roster getusers]
    if {[$jlib roster isitem $jid]} {
	set ans [::UI::MessageBox -message [mc jamessalreadyinrost2 $jid] \
	  -icon error -title [mc Error] -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }

    # Check the jid we are trying to add.
    if {![catch {jlib::splitjidex $jid node host res}]} {

	# Exclude jabber services.
	if {[lsearch [::Roster::GetAllTransportJids] $host] >= 0} {	    
	
	    # If this requires a transport component we must be registered.
	    set transport [lsearch -inline -regexp $users "^${host}.*"]
	    if {![llength $transport]} {
		
		# Seems we are not registered.
		set ans [::UI::MessageBox \
		  -type $config(adduser,dlg-type-ask-register) -icon error \
		  -title [mc Error] \
		  -parent $state(w) -message [mc jamessaddforeign2 $host]]

	      if {$ans eq "yes"} {
		    ::GenRegister::NewDlg -server $host -autoget 1
		    return
		} elseif {$ans eq "cancel"} {
		    # Destroy also add dialog?
		    return
		}
	    }
	}
    }
    
    # If 'name' not set then set it to the foreign system ID.
    if {($type ne "xmpp") && ($name eq "")} {
	set name $state(jid)
    }
    
    set opts [list]
    if {[string length $name]} {
	lappend opts -name $name
    }
    if {($group ne [mc None]) && ($group ne "")} {
	lappend opts -groups [list $group]
    }
    
    # This is the only (?) situation when a client "sets" a roster item.
    # The actual roster item is pushed back to us, and not set from here.
    set cb [list [namespace code SetCB] $jid]
    eval {$jlib roster send_set $jid -command $cb} $opts    

    # Send subscribe request.
    set opts [list]
    set nickname [::Profiles::GetSelected -nickname]
    if {$nickname ne ""} {
	lappend opts -xlist [list [::Nickname::Element $nickname]]
    }
    eval {$jlib send_presence -to $jid -type "subscribe" \
      -command [namespace current]::PresError} $opts
        
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
	set ujid [jlib::unescapejid $jid]
	set str [mc jamessfailsetnick2 $ujid]
	append str "\n" "[mc {Error code}]: $errcode\n"
	append str "[mc Message]: $errmsg"
	::UI::MessageBox -icon error -title [mc Error] -type ok -message $str
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
	    set ujid [jlib::unescapejid $from]
	    set str "We received an error when (un)subscribing to $ujid.\
	      The error is: $errmsg ($errcode).\
	      Do you want to remove it from your roster?"
	    set ans [::UI::MessageBox -icon error -title [mc Error] -type yesno \
	      -message $str]
	    if {$ans eq "yes"} {
		$jstate(jlib) roster send_remove $from
	    }
	}
    }
}

# JUser::TrptCmd --
#
#       Callback from the transports menu button.

proc ::JUser::TrptCmd {token gjid} {
    global  config

    if {$config(adduser,trpt-spec-type) eq "multi"} {
	TrptMultiCmd $token $gjid
    } else {
	TrptSingleCmd $token $gjid
    }
}

proc ::JUser::TrptMultiCmd {token gjid} {
    global  config
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
	
    set wjid $state(wjid)
    set type $state(servicetype,$gjid)
    
    # Seems to be necessary to achive any selection.
    focus $wjid
    #set state(jid) [format [::Gateway::GetTemplateJID $type] $gjid]
    set state(jid) [::Gateway::GetPrompt $type]
    set ind [string first @ $state(jid)]
    if {$ind > 0} {
	#$wjid selection range 0 $ind
    }
    $wjid selection range 0 end
    
    # @@@ NB: While the service JID is a bare JID any roster item may
    #         have a resource part: icq.jabber.cz/registered
    #         Must find any matches!
    
    set rjid [$jstate(jlib) roster getrosterjid $gjid]
    set isitem [string length $rjid]
    
    set alert 0
    if {$type eq "xmpp"} {
	if {![jlib::jidequal $gjid $jstate(server)]} {
	    set alert 1
	}
    } elseif {!$isitem} {
	set alert 1
    }
    
    # If this requires a transport component we must be registered.
    if {$alert} {
	if {$config(adduser,warn-non-xmpp-onselect)} {
	    set str "You are currently not registered with this transport and if you proceed you will be asked to register with your own account on this system."
	    tk_messageBox -icon warning -parent $state(w) -message $str
	} elseif {$config(adduser,add-non-xmpp-onselect)} {
	    set ans [::UI::MessageBox -type yesno -icon warning \
	      -parent $state(w) -message [mc jamessaddforeign2 $gjid]]
	    if {$ans eq "yes"} {
		::GenRegister::NewDlg -server $gjid -autoget 1
	    }
	}
    }
}

# JUser::TrptSingleCmd --
#
#       Since each transport, except xmpp, is listed only once 'gjid' is just
#       any JID of that type. For 'xmpp' it is the true JID.

proc ::JUser::TrptSingleCmd {token gjid} {
    global  config
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
	
    set wjid $state(wjid)
    set type $state(servicetype,$gjid)

    # Seems to be necessary to achive any selection.
    focus $wjid
    set state(jid) [::Gateway::GetPrompt $type]
    $wjid selection range 0 end
 	
    set jidL [$jstate(jlib) disco getjidsforcategory "gateway/$type"]
   
    set alert 0
    if {$type eq "xmpp"} {
	if {![jlib::jidequal $gjid $jstate(server)]} {
	    set alert 1
	}
    } else {
	set count [llength $jidL]
	set isregistered 0
	foreach j $jidL {
	    set rjid [$jstate(jlib) roster getrosterjid $j]
	    set isitem [string length $rjid]
	    if {$isitem} {
		set isregistered 1
		set regJID $j
		break
	    }
	}
	if {!$isregistered} {
	    set alert 1
	}
    }
    
    if {$alert} {
	if {$config(adduser,warn-non-xmpp-onselect)} {
	    set str "You are currently not registered with this transport and if you proceed you will be asked to register with your own account on this system."
	    tk_messageBox -icon warning -parent $state(w) -message $str
	} elseif {$config(adduser,add-non-xmpp-onselect)} {
	    set ans [::UI::MessageBox -type yesno -icon warning \
	      -parent $state(w) -message [mc jamessaddforeign2 $gjid]]
	    if {$ans eq "yes"} {
		
		if {[llength $jidL] > 1} {
		    ::GenRegister::NewDlg -serverlist $jidL
		} else {
		    ::GenRegister::NewDlg -server $gjid -autoget 1
		}
	    }
	}
    }
}

proc ::JUser::CloseCmd {wclose} {
    global  wDlgs
    
    ::UI::SaveWinPrefixGeom $wDlgs(jrostadduser)
}

#--- The Edit section ----------------------------------------------------------

proc ::JUser::EditJIDList {jidL} {
    foreach jid $jidL {
	EditDlg $jid
    }
}

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
    set ujid [jlib::unescapejid $jid3]
    set msg [mc jamessowntrpt2 $typename $ujid $subscription]

    ::ui::dialog -title [mc Info] -type ok -message $msg -icon info
}

proc ::JUser::EditGetAllTokens {} {    
    return [info vars [namespace current]::dlg*]
}

proc ::JUser::EditHaveDlgForJID {jid} {
    return [llength [EditGetTokenForJID $jid]]
}

proc ::JUser::EditGetTokenForJID {jid} {
    foreach token [EditGetAllTokens] {
	variable $token
	upvar 0 $token state	
	if {[info exists state(jid)] && [jlib::jidequal $jid $state(jid)]} {
	    return $token
	}
    }
    return
}

# JUser::EditUserDlg --
# 
#       Edit user dialog.

proc ::JUser::EditUserDlg {jid} {
    global  this prefs wDlgs

    variable uid
    upvar ::Jabber::jstate jstate
    
    # Guarantee only single dialog per JID.
    if {[llength [set token [EditGetTokenForJID $jid]]]} {
	variable $token
	upvar 0 $token state	
	raise $state(w)
	return
    }
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jrostedituser)$uid
    set state(w) $w
    set state(finished) -1
    
    set istransport [::Roster::IsTransport $jid]
    if {$istransport} {
	set title [mc "Transport Info"]
    } else {
	set title [mc "Edit Contact"]
    }

    ::UI::Toplevel $w -class JUser \
      -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} -closecommand [namespace current]::CloseCmd
    wm title $w $title
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jrostedituser)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jrostedituser)
    }
    set im  [::Theme::Find32Icon $w adduserImage]
    set imd [::Theme::Find32Icon $w adduserDisImage]
    
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
    
    set ujid [jlib::unescapejid $jid]
    if {$istransport} {
	jlib::splitjidex $jid node host res
	set trpttype [lindex [$jlib disco types $host] 0]
	set subtype [lindex [split $trpttype /] 1]
	set msg [mc jamessowntrpt2 $subtype $ujid $subscription]
    } else {
	set msg [mc jarostset2 $ujid]
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

    ttk::label $frmid.lnick -text "[mc {Nickname}]:" -anchor e
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
		  -text [mc jarostsub2]  \
		  -variable $token\(subscribe)
	    }
	    both - to {
		ttk::checkbutton $frmid.csubs -style Small.TCheckbutton \
		  -text [mc jarostunsub2]  \
		  -variable $token\(unsubscribe)
	    }
	}
	
	# Present subscription.
	set str [mc subscription[string totitle $subscription]]
	ttk::label $frmid.lsub -style Small.TLabel -text $str -anchor e
	    
	# Presence presence subscription in a userfriendly way. Not sure if this is a good idea, but what about using $frmid.lsub in a balloon help string for $frmid.csubs instead of a label?
	# Other idea to improve this dialog: change checkbox item in a button that do not close the dialog, but just update the string $frmid.lsub. So, maybe:
	# $frmid.lsub2 = what will happen when the user clicks in this button, in the same terms as $frmid.lsub
	# Nickname: <field>
	#    Group: <field>
	# Presence: $frmid.lsub <button balloon="$frmid.lsub2">Remove Subscription</button>
	# When people click on this button, they get an "are you sure? dialog" first, if yes, $frmid.lsub and $frmid.lsub2 are updated in the dialog, but the dialog is not closed
	
	# last related idea: maybe move annotation tab from the business card dialog to the edit contact dialog. Add to the edit contact dialog 3 tabs in this order: General, Annotations, Presence. In the future you also can move buddy pouncing to this edit contact dialog. Also, you can add a feature to the presence dialog to allow people to synchronise global presence with this specific contact, enabled by default for all contacts (and then add a presence icon button in all chat dialogs, similar to how you did in the groupchat dialog) 
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
    ttk::button $frbot.btok -text [mc Save] -default active \
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
	set imvcard [::Theme::Find32Icon $w vcardImage]
	ttk::button $frbot.bvcard -style Plain \
	  -compound image -image $imvcard \
	  -command [list ::VCard::Fetch other $jid]
	pack $frbot.bvcard -side left
	::balloonhelp::balloonforwindow $frbot.bvcard [mc "View business card"]
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

    bind $w <Destroy> \
      +[subst { if {"%W" eq "$w"} { [namespace code [list Free $token]] } }]
    
    return $token
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

    set haveName 0
    set haveGroup 0
	
    # This is the only situation when a client "sets" a roster item.
    # The actual roster item is pushed back to us, and not set from here.
    set opts [list]
    if {[string length $name]} {
	lappend opts -name $name
	set haveName 1
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
	set haveGroup 1
    }
    set jlib $jstate(jlib)

    if {$haveName || $haveGroup} {
	set cb [list [namespace code SetCB] $jid]
	eval {$jlib roster send_set $jid -command $cb} $opts    
    }
    
    # Send (un)subscribe request.
    if {$subscribe} {
	set opts [list]
	set nickname [::Profiles::GetSelected -nickname]
	if {$nickname ne ""} {
	    lappend opts -xlist [list [::Nickname::Element $nickname]]
	}
	eval {$jlib send_presence -to $jid -type "subscribe" \
	  -command [namespace current]::PresError} $opts
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
