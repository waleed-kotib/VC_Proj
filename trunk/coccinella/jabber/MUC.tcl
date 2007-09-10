#  MUC.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements parts of the UI for the Multi User Chat protocol.
#      
#      This code is not completed!!!!!!!
#      
#  Copyright (c) 2003-2007  Mats Bengtsson
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
# $Id: MUC.tcl,v 1.90 2007-09-10 12:31:56 matben Exp $

package require jlib::muc
package require ui::comboboxex

package provide MUC 1.0

namespace eval ::MUC:: {
      
    ::hooks::register jabberInitHook     ::MUC::JabberInitHook
    
    # Local stuff
    variable dlguid 0
    variable editcalluid 0
    variable enteruid  0
    
    # Map action to button widget.
    variable mapAction2Bt
    array set mapAction2Bt {
	grant,voice             $wgrant.btvoice 
	grant,member            $wgrant.btmember
	grant,moderator         $wgrant.btmoderator
	grant,admin             $wgrant.btadmin
	grant,owner             $wgrant.btowner
	revoke,voice            $wrevoke.btvoice
	revoke,member           $wrevoke.btmember
	revoke,moderator        $wrevoke.btmoderator
	revoke,admin            $wrevoke.btadmin
	revoke,owner            $wrevoke.btowner
	list,voice              $wlist.btvoice
	list,ban                $wlist.btban
	list,member             $wlist.btmember
	list,moderator          $wlist.btmoderator
	list,admin              $wlist.btadmin
	list,owner              $wlist.btowner
	other,kick              $wother.btkick
	other,ban               $wother.btban
	other,conf              $wother.btconf
	other,dest              $wother.btdest
    }
    
    # List enabled buttons for each role/affiliation privileges.
    variable enabledBtAffList 
    array set enabledBtAffList {
	none        {}
	outcast     {}
	member      {}
	admin       {
	    $wother.btban        $wlist.btban 
	    $wgrant.btmember     $wrevoke.btmember     $wlist.btmember
	    $wgrant.btmoderator  $wrevoke.btmoderator  $wlist.btmoderator}
	owner       {
	    $wother.btban        $wlist.btban 
	    $wgrant.btmember     $wrevoke.btmember     $wlist.btmember
	    $wgrant.btmoderator  $wrevoke.btmoderator  $wlist.btmoderator
	    $wgrant.btowner      $wrevoke.btowner      $wlist.btowner
	    $wgrant.btadmin      $wrevoke.btadmin      $wlist.btadmin
	    $wother.btconf       $wother.btdest}
    }
    
    variable enabledBtRoleList
    array set enabledBtRoleList {
	none        {}
	visitor     {}
	participant {}
	moderator   {
	    $wgrant.btvoice      $wrevoke.btvoice      $wlist.btvoice
	    $wother.btkick}
    }
    
    set ::config(muc,show-head-invite) 1
    set ::config(muc,show-head-info)   1
}


proc ::MUC::JabberInitHook {jlibName} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns
   
    $jstate(jlib) message_register * $xmppxmlns(muc,user) ::MUC::MUCMessage
}

namespace eval ::MUC:: {
    
    variable inviteuid 0

    option add *JMUCInvite.inviteImage         invite         widgetDefault
    option add *JMUCInvite.inviteDisImage      inviteDis      widgetDefault
}

# MUC::Invite --
# 
#       Make an invitation to a room.
#       NB: Keep the 'invite' state array untile we close/cancel or until
#           we get a response.

proc ::MUC::Invite {roomjid {continue ""}} {
    global this wDlgs config
    
    variable inviteuid
    variable dlguid
    upvar ::Jabber::jstate jstate

    # State variable to collect instance specific variables.
    set token [namespace current]::invite[incr inviteuid]
    variable $token
    upvar 0 $token invite
    
    set w $wDlgs(jmucinvite)[incr dlguid]
    ::UI::Toplevel $w -class JMUCInvite \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [list [namespace current]::InviteCloseCmd $token]
    wm title $w [mc {Invite Contact}]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jmucinvite)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jmucinvite)
    }
    jlib::splitjidex $roomjid node domain res
    set jidlist [$jstate(jlib) roster getusers -type available]

    set invite(w)        $w
    set invite(reason)   ""
    set invite(continue) $continue
    set invite(finished) -1
    set invite(roomjid)  $roomjid

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    if {$config(muc,show-head-invite)} {
	set im   [::Theme::GetImage [option get $w inviteImage {}]]
	set imd  [::Theme::GetImage [option get $w inviteDisImage {}]]

	ttk::label $w.frall.head -style Headlabel \
	  -text [mc {Invite Contact}] -compound left \
	  -image [list $im background $imd]
	pack $w.frall.head -side top -anchor w
	
	ttk::separator $w.frall.s -orient horizontal
	pack $w.frall.s -side top -fill x
    }
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    set msg [mc jainvitegchat2 $node]
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text $msg
    pack $wbox.msg -side top -anchor w

    set wmid $wbox.fr
    ttk::frame $wmid
    pack $wmid -side top -fill x -expand 1
    
    ttk::label $wmid.la -text "[mc {Contact ID}]:"
    ui::comboboxex $wmid.ejid -library $jidlist -textvariable $token\(jid)  \
      -values $jidlist
    ttk::label $wmid.lre -text "[mc Reason]:"
    ttk::entry $wmid.ere -textvariable $token\(reason)
    
    grid  $wmid.la   $wmid.ejid  -sticky e -padx 2 -pady 2
    grid  $wmid.lre  $wmid.ere   -sticky e -padx 2 -pady 2
    grid $wmid.ejid $wmid.ere -sticky ew
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK]  \
      -default active -command [list [namespace current]::DoInvite $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::InviteClose $token]
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
    focus $wmid.ejid
}

proc ::MUC::InviteClose {token} {    
    global  wDlgs
    variable $token
    upvar 0 $token invite

    ::UI::SaveWinPrefixGeom $wDlgs(jmucinvite)
    destroy $invite(w)
    
    # Be sure to keep state array if sent out an invitation.
    if {$invite(finished) != 1} {
	unset -nocomplain invite
    }
}

proc ::MUC::InviteCloseCmd {token wclose} {
    InviteClose $token
}

proc ::MUC::DoInvite {token} {
    variable $token
    upvar 0 $token invite
    upvar ::Jabber::jstate jstate

    set jid      $invite(jid)
    set reason   $invite(reason)
    set roomjid  $invite(roomjid)
    set continue $invite(continue)

    set invite(finished) 1
    InviteClose $token

    set opts [list -command [list [namespace current]::InviteCB $token]]
    if {$reason ne ""} {
	set opts [list -reason $reason]
    }
    if {$continue ne ""} {
        lappend opts -continue 1 
    }

    eval {$jstate(jlib) muc invite $roomjid $jid} $opts
}

proc ::MUC::InviteCB {token jlibname type args} {
    variable $token
    upvar 0 $token invite
    
    array set argsA $args
    
    if {$type eq "error"} {
	set msg [mc mucErrInvite $invite(jid) $invite(roomjid)]
	if {[info exists argsA(-error)]} {
	    set errcode [lindex $argsA(-error) 0]
	    set errmsg [lindex $argsA(-error) 1]
	    append msg " " [mc mucErrInviteCode $errmsg]
	}
	::UI::MessageBox -icon error -title [mc Error] -type ok -message $msg
    }
    unset -nocomplain invite
}

# MUC::MUCMessage --
# 
#       Handle incoming message tagged with muc namespaced x-element.
#       Invitation?

proc ::MUC::MUCMessage {jlibname xmlns msgElem args} {
   
    # This seems handled by the muc component by sending a message.
    return
   
    array set argsA $args
    if {![info exists argsA(-x)]} {
	return
    }
    set from $argsA(-from)
    set xlist $argsA(-x)
    
    set invite 0
    foreach c [wrapper::getchildren $xlist] {
	
	switch -- [lindex $c 0] {
	    invite {
		set invite 1
		set inviter [wrapper::getattribute $c "from"]
		foreach cc [wrapper::getchildren $c] {
		    if {[string equal [lindex $cc 0] "reason"]} {
			set reason [lindex $cc 3]
		    }
		}		
	    }
	    password {
		set password [lindex $c 3]
	    }	    
	}
    }
    
    if {$invite} {        
	set msg [mc mucInviteText]
	set opts {}
	if {[info exists reason]} {
	    append msg " " [mc mucInviteReason $reason]
	}
	if {[info exists password]} {
	    append msg " " [mc mucInvitePass $password]
	    lappend opts -password $password
	}
	append msg [mc mucInviteQuest]
	set ans [::UI::MessageBox -icon info -type yesno -title [mc mucInvite] \
	  -message $msg]
	if {$ans eq "yes"} {
	    eval {BuildEnter -roomjid $from} $opts
	}
    }
}

#--- The Info Dialog -----------------------------------------------------------

namespace eval ::MUC:: {
    
    option add *JMUCInfo.infoImage         info         widgetDefault
    option add *JMUCInfo.infoDisImage      infoDis      widgetDefault

    option add *JMUCInfo*TButton.style     Small.TButton 50
    option add *JMUCInfo*TLabelframe.style  Small.TLabelframe 50
}

# MUC::BuildInfo --
# 
#       Displays an info dialog for MUC room configuration.

proc ::MUC::BuildInfo {roomjid} {
    global this wDlgs config
    
    variable dlguid
    upvar ::Jabber::jstate jstate

    # Instance specific namespace.
    namespace eval [namespace current]::${roomjid} {
	variable locals
    }
    upvar [namespace current]::${roomjid}::locals locals
    
    if {[info exists locals($roomjid,w)] && [winfo exists $locals($roomjid,w)]} {
	raise $locals($roomjid,w)
	return
    }    
    set w $wDlgs(jmucinfo)[incr dlguid]

    set roomName [$jstate(jlib) disco name $roomjid]
    if {$roomName eq ""} {
	jlib::splitjidex $roomjid roomName x y
    }

    set locals($roomjid,w) $w
    set locals($w,roomjid) $roomjid
    set locals($roomjid,mynick) [$jstate(jlib) muc mynick $roomjid]
    set locals($roomjid,myrole) none
    set locals($roomjid,myaff) none

    ::UI::Toplevel $w -class JMUCInfo \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace current]::InfoCloseHook
    wm title $w "[mc {Info Room}]: $roomName"
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    if {$config(muc,show-head-info)} {
	set im   [::Theme::GetImage [option get $w infoImage {}]]
	set imd  [::Theme::GetImage [option get $w infoDisImage {}]]

	ttk::label $w.frall.head -style Headlabel \
	  -text [mc {Info Room}] -compound left \
	  -image [list $im background $imd]
	pack $w.frall.head -side top -anchor w
	
	ttk::separator $w.frall.s -orient horizontal
	pack $w.frall.s -side top -fill x
    }
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    set msg [mc InfoRoomDesc]
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 12} -wraplength 300 -justify left -text $msg
    pack $wbox.msg -side top -anchor w
        
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btcancel -style TButton \
      -text [mc Close]  \
      -command [list [namespace current]::Close $roomjid]
    pack $frbot.btcancel -side right
    pack $frbot -side bottom -fill x
    
    # A frame.
    set frleft $wbox.fleft
    ttk::frame $frleft
    pack $frleft -side left
    
    # Tablelist with scrollbar ---
    set frtab $frleft.frtab    
    set wysc  $frtab.ysc
    set wtbl  $frtab.tb
    ttk::frame $frtab
    pack $frtab -side top
    set columns [list 0 [mc Nickname] 0 [mc Role] 0 [mc Affiliation]]
    
    tablelist::tablelist $wtbl  \
      -columns $columns -stretch all -selectmode single  \
      -yscrollcommand [list $wysc set] -width 36 -height 8
    ttk::scrollbar $wysc -orient vertical -command [list $wtbl yview]
    ttk::button $frtab.ref -style Small.TButton -text [mc Refresh]  \
      -command [list [namespace current]::Refresh $roomjid]

    grid  $wtbl       $wysc  -sticky news
    grid  $frtab.ref  x      -sticky e -pady 2
    grid columnconfigure $frtab 0 -weight 1
    
    # Special bindings for the tablelist.
    set body [$wtbl bodypath]
    bind $body <Button-1> {+ focus %W}
    bind $body <Double-1> [list [namespace current]::DoubleClickPart $roomjid]
    bind $wtbl <<ListboxSelect>> [list [namespace current]::SelectPart $roomjid]
    
    # Fill in tablelist.
    set locals(wtbl) $wtbl
    FillTable $roomjid
    
    # A frame.
    set frgrantrevoke $frleft.grrev
    ttk::frame $frgrantrevoke -padding {0 8 0 0}
    pack $frgrantrevoke -side top
        
    # Grant buttons ---
    set wgrant $frgrantrevoke.grant
    ttk::labelframe $wgrant -text "[mc Grant]:" \
      -padding [option get . groupSmallPadding {}]
    
    foreach txt {Voice Member Moderator Admin Owner} {
	set stxt [string tolower $txt]
	ttk::button $wgrant.bt$stxt -text [mc $txt]  \
	  -command [list [namespace current]::GrantRevoke $roomjid grant $stxt]
	grid  $wgrant.bt$stxt  -sticky ew -pady 4
    }
    
    # Revoke buttons ---
    set wrevoke $frgrantrevoke.rev
    ttk::labelframe $wrevoke -text "[mc Revoke]:" \
      -padding [option get . groupSmallPadding {}]
    
    foreach txt {Voice Member Moderator Admin Owner} {
	set stxt [string tolower $txt]
	ttk::button $wrevoke.bt$stxt -text [mc $txt]  \
	  -command [list [namespace current]::GrantRevoke $roomjid revoke $stxt]
	grid $wrevoke.bt$stxt -sticky ew -pady 4
    }
    grid  $wgrant  $wrevoke  -padx 8  
    
    # A frame.
    set frmid $wbox.mid
    ttk::frame $frmid
    pack $frmid -side top
    
    # Other buttons ---
    set wother $frmid.fraff
    ttk::frame $wother
    pack $wother -side top

    ttk::button $wother.btkick -text [mc {Kick Participant}]  \
      -command [list [namespace current]::Kick $roomjid]
    ttk::button $wother.btban -text [mc {Ban Participant}]  \
      -command [list [namespace current]::Ban $roomjid]
    ttk::button $wother.btconf -text [mc {Configure Room}]  \
      -command [list [namespace current]::RoomConfig $roomjid]
    ttk::button $wother.btdest -text [mc {Destroy Room}]  \
      -command [list [namespace current]::Destroy $roomjid]

    grid  $wother.btkick  -sticky ew -pady 4
    grid  $wother.btban   -sticky ew -pady 4
    grid  $wother.btconf  -sticky ew -pady 4
    grid  $wother.btdest  -sticky ew -pady 4
    
    # Edit lists ---
    set wlist $frmid.lists
    ttk::labelframe $wlist -text "[mc {Edit Lists}]:" \
      -padding [option get . groupSmallPadding {}]
    pack $wlist -side top -pady 8

    foreach txt {Voice Ban Member Moderator Admin Owner} {
	set stxt [string tolower $txt]	
	ttk::button $wlist.bt$stxt -text "[mc $txt]..."  \
	  -command [list [namespace current]::EditListBuild $roomjid $stxt]
	grid  $wlist.bt$stxt  -sticky ew -pady 4
    }

    # Collect various widget paths.
    set locals(wtbl)    $wtbl
    set locals(wlist)   $wlist
    set locals(wgrant)  $wgrant
    set locals(wrevoke) $wrevoke
    set locals(wother)  $wother
    
    SetButtonsState $roomjid  \
      $locals($roomjid,myrole) $locals($roomjid,myaff) 
    
    wm resizable $w 0 0    
    
    set idleScript [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wbox.msg $w]
    after idle $idleScript
    return
}

proc ::MUC::FillTable {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    set mynick $locals($roomjid,mynick)
    set wtbl $locals(wtbl)
    $wtbl delete 0 end
    
    # Fill in tablelist.
    set jlib $jstate(jlib)
    set resourceL [$jlib roster getresources $roomjid -type available]
    set irow 0
    
    foreach res $resourceL {
	set xelem [$jlib roster getx $roomjid/$res "muc#user"]
	set aff none
	set role none
	foreach elem [wrapper::getchildren $xelem] {
	    if {[string equal [lindex $elem 0] "item"]} {
		unset -nocomplain attrA
		array set attrA [lindex $elem 1]
		if {[info exists attrA(affiliation)]} {
		    set aff $attrA(affiliation)
		}
		if {[info exists attrA(role)]} {
		    set role $attrA(role)
		}
		break
	    }
	}
	set ures [jlib::unescapestr $res]
	$wtbl insert end [list $ures [mc $role] [mc $aff]]
	if {[string equal $res $mynick]} {
	    set locals($roomjid,myaff)  $aff
	    set locals($roomjid,myrole) $role
	    $wtbl rowconfigure $irow -bg #ffa090
	}
	incr irow
    }
}

proc ::MUC::Refresh {roomjid} {

    FillTable $roomjid
}

proc ::MUC::DoubleClickPart {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals

    
}

proc ::MUC::SelectPart {roomjid} {
    upvar ::Jabber::jstate jstate
    upvar [namespace current]::${roomjid}::locals locals

    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    return 
    if {[string length $item] == 0} {
	DisableAll $roomjid
    } else {
    	SetButtonsState $roomjid  \
    	  $locals($roomjid,myrole) $locals($roomjid,myaff) 
    }  
}

proc ::MUC::SetButtonsState {roomjid role affiliation} {
    variable enabledBtAffList 
    variable enabledBtRoleList
    upvar [namespace current]::${roomjid}::locals locals
    
    set wtbl    $locals(wtbl)
    set wlist   $locals(wlist)
    set wgrant  $locals(wgrant)
    set wrevoke $locals(wrevoke)
    set wother  $locals(wother)
    
    DisableAll $roomjid

    foreach wbt $enabledBtRoleList($role) {
	set wbt [subst -nobackslashes -nocommands $wbt]
	$wbt state {!disabled}
    }
    foreach wbt $enabledBtAffList($affiliation) {
	set wbt [subst -nobackslashes -nocommands $wbt]
	$wbt state {!disabled}
    }
}

proc ::MUC::DisableAll {roomjid} {
    variable mapAction2Bt
    upvar [namespace current]::${roomjid}::locals locals

    set wlist $locals(wlist)
    set wgrant $locals(wgrant)
    set wrevoke $locals(wrevoke)
    set wother $locals(wother)

    foreach {action wbt} [array get mapAction2Bt] {
	set wbt [subst -nobackslashes -nocommands $wbt]
    	$wbt state {!disabled}
    }
}

proc ::MUC::GrantRevoke {roomjid which type} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    set dlgDefs(grant,voice) {
	{Grant Voice}  \
	{Grant voice to the participant "$nick" in the room "$roomName"}  \
    }
    set dlgDefs(grant,member) {
	{Grant Membership}  \
	{Grant membership to "$nick" in the room "$roomName"}  \
    }
    set dlgDefs(grant,moderator) {
	{Grant Moderator}  \
	{Grant moderator privileges to "$nick" for the room "$roomName"}  \
    }
    set dlgDefs(grant,admin) {
	{Grant Administrator}  \
	{Grant administrator privileges to "$nick" for the room "$roomName"}  \
    }
    set dlgDefs(grant,owner) {
	{Grant Owner}  \
	{Grant "$nick" to be the owner of the room "$roomName"}  \
    }
    set dlgDefs(revoke,voice) {
	{Revoke Voice}  \
	{Revoke voice from the participant "$nick" in the room "$roomName"}  \
    }
    set dlgDefs(revoke,member) {
	{Revoke Membership}  \
	{Revoke membership from "$nick" in the room "$roomName"}  \
    }
    set dlgDefs(revoke,moderator) {
	{Revoke Moderator}  \
	{Revoke moderator privileges from "$nick" for the room "$roomName"}  \
    }
    set dlgDefs(revoke,admin) {
	{Revoke Administrator}  \
	{Revoke administrator privileges from "$nick" for the room "$roomName"}  \
    }
    set dlgDefs(revoke,owner) {
	{Revoke Owner}  \
	{Revoke owner privileges from "$nick" in the room "$roomName"}  \
    }
    array set actionDefs {
	grant,voice,cmd         setrole 
	grant,voice,what        participant 
	grant,member,cmd        setaffiliation 
	grant,member,what       member 
	grant,moderator,cmd     setrole 
	grant,moderator,what    moderator 
	grant,admin,cmd         setaffiliation 
	grant,admin,what        admin 
	grant,owner,cmd         setaffiliation 
	grant,owner,what        owner 
	revoke,voice,cmd        setrole
	revoke,voice,what       visitor
	revoke,member,cmd       setaffiliation 
	revoke,member,what      none 
	revoke,moderator,cmd    setrole 
	revoke,moderator,what   participant 
	revoke,admin,cmd        setaffiliation 
	revoke,admin,what       member 
	revoke,owner,cmd        setaffiliation 
	revoke,owner,what       admin 
    }
    
    # Need selected line here. $item = numerical index.
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    lassign $row unick role aff
    set nick [jlib::escapestr $unick]
    jlib::splitjidex $roomjid roomName - -
    
    set sdef [subst $dlgDefs($which,$type)]
    set title [lindex $sdef 0]
    set msg   [lindex $sdef 1]
    set ans [ui::megaentry -label "[mc {Profile name}]:" -icon "" \
      -geovariable prefs(winGeom,jmucact) -title $title -message $msg]

    if {$ans ne ""} {
	set reason [ui::megaentrytext $ans]
	set opts [list]
	if {$reason ne ""} {
	    lappend opts -reason $reason
	}
	eval {$jstate(jlib) muc $actionDefs($which,$type,cmd) $roomjid  \
	  $nick $actionDefs($which,$type,what)  \
	  -command [list [namespace current]::IQCallback $roomjid]} $opts
    }
}

proc ::MUC::Kick {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    # Need selected line here. $item = numerical index.
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    lassign $row unick role aff
    set nick [jlib::escapestr $unick]
    jlib::splitjidex $roomjid roomName - -
    
    set title [mc {Kick Participant}]
    set msg [mmc mucKick $unick $roomName]
    set ans [ui::megaentry -label "[mc Reason]:" -icon "" \
      -geovariable prefs(winGeom,jmucact) -title $title -message $msg]

    if {$ans ne ""} {
	set reason [ui::megaentrytext $ans]
	set opts [list]
	if {$reason ne ""} {
	    lappend opts -reason $reason
	}
	eval {$jstate(jlib) muc setrole $roomjid $nick "none" \
	  -command [list [namespace current]::IQCallback $roomjid]} $opts
    }
}

proc ::MUC::Ban {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    # Need selected line here. $item = numerical index.
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    lassign $row unick role aff
    set nick [jlib::escapestr $unick]
    jlib::splitjidex $roomjid roomName - -

    set title [mc {Ban User}]
    set msg [mc mucBan $unick $roomName]
    set ans [ui::megaentry -label "[mc Reason]:" -icon "" \
      -geovariable prefs(winGeom,jmucact) -title $title -message $msg]
        
    if {$ans ne ""} {
	set reason [ui::megaentrytext $ans]
	set opts [list]
	if {$reason ne ""} {
	    lappend opts -reason $reason
	}
	eval {$jstate(jlib) muc setaffiliation $roomjid $nick "outcast" \
	  -command [list [namespace current]::IQCallback $roomjid]} $opts
    }
}

namespace eval ::MUC:: {
    

}

# MUC::EditListBuild --
#
#       Shows and handles a dialog for edit various lists of room content.
#       
# Arguments:
#       roomjid
#       type        voice, ban, member, moderator, admin, owner
#       
# Results:
#       "cancel" or "result".

proc ::MUC::EditListBuild {roomjid type} {
    global this wDlgs
    
    upvar ::Jabber::jstate jstate
    variable dlguid
    variable editcalluid
    variable setListDefs
    
    # Customize according to the $type.
    array set editmsg {
	voice     {Edit the privilege to speak in the room, the voice.}
	ban       {Edit the ban list}
	member    {Edit the member list}
	moderator {Edit the moderator list}
	admin     {Edit the admin list}
	owner     {Edit the owner list}
    }
    array set setListDefs {
	voice     {nick affiliation role jid reason}
	ban       {jid reason}
	member    {nick affiliation role jid reason}
	moderator {nick role jid reason}
	admin     {jid affiliation reason}
	owner     {jid reason}
    }
    foreach what {voice ban member moderator admin owner} {
	foreach txt $setListDefs($what) {
	    lappend columns($what) 0 [string totitle $txt]
	}
    }

    # State variable to collect instance specific variables.
    set token [namespace current]::edtlst[incr dlguid]
    variable $token
    upvar 0 $token state

    set titleType [string totitle $type]
    set tblwidth [expr 10 + 12 * [llength $setListDefs($type)]]
    set roomName [$jstate(jlib) disco name $roomjid]
    if {$roomName eq ""} {
	jlib::splitjidex $roomjid roomName x y
    }
    
    set w $wDlgs(jmucedit)[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} \
      -closecommand ::MUC::EditListCloseHook
    wm title $w "Edit List $titleType: $roomName"
        
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    ttk::label $wbox.msg  \
      -padding {0 0 0 6} -wraplength 300 -justify left -text [mc $editmsg($type)]
    pack $wbox.msg -side top -anchor w
    
    #
    set wmid $wbox.fr
    ttk::frame $wmid
    pack $wmid -side top -fill x -expand 1
    
    # Tablelist with scrollbar ---
    set frtab $wmid.tab    
    set wysc  $frtab.ysc
    set wtbl  $frtab.tb
    frame $frtab
    pack  $frtab -side left
    tablelist::tablelist $wtbl -width $tblwidth -height 8 \
      -columns $columns($type) -stretch all -selectmode single  \
      -yscrollcommand [list $wysc set]  \
      -editendcommand [list [namespace current]::VerifyEditEntry $token] \
      -listvariable $token\(listvar)
    ttk::scrollbar $wysc -orient vertical -command [list $wtbl yview]

    grid  $wtbl  $wysc  -sticky news
    grid columnconfigure $frtab 0 -weight 1

    option add *$wtbl*selectBackground		navy      widgetDefault
    option add *$wtbl*selectForeground		white     widgetDefault

    $wtbl columnconfigure end -editable yes

    switch -- $type {
	voice {
	}
	ban {
	    $wtbl columnconfigure 0 -editable yes
	}
	member {
	}
	moderator {
	}
	admin {
	    $wtbl columnconfigure end -editable yes
	}
	owner {    
	    $wtbl columnconfigure 0 -editable yes
	} 
    }
    
    # Special bindings for the tablelist.
    set body [$wtbl bodypath]
    bind $body <Button-1> {+ focus %W}
    bind $wtbl <<ListboxSelect>> \
      [list [namespace current]::EditListSelect $token]
    
    # Action buttons.
    set wbts    $wmid.fr
    set wbtadd  $wbts.add
    set wbtedit $wbts.edit
    set wbtrm   $wbts.rm
    ttk::frame $wbts
    pack $wbts -side right -anchor n -padx 4 -pady 4
    
    ttk::button $wbtadd -text [mc Add] \
      -command [list [namespace current]::EditListDoAdd $token]
    ttk::button $wbtedit -text [mc Edit] \
      -command [list [namespace current]::EditListDoEdit $token]
    ttk::button $wbtrm -text [mc Remove] \
      -command [list [namespace current]::EditListDoRemove $token]
    
    grid  $wbtadd   -pady 8 -sticky ew
    grid  $wbtedit  -pady 8 -sticky ew
    grid  $wbtrm    -pady 8 -sticky ew
    
    $wbtadd  state {disabled}
    $wbtedit state {disabled}
    $wbtrm   state {disabled}
    
    # Button part.
    set frbot     $wbox.b
    set warrows   $frbot.arr
    set wbtok     $frbot.btok
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    pack $frbot  -side bottom -fill x -padx 10 -pady 8
    ttk::button $frbot.btok -text [mc OK] \
      -default active -command [list [namespace current]::EditListOK $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::EditListCancel $token]
    ::chasearrows::chasearrows $frbot.arr -size 16
    ttk::button $frbot.btres -text [mc Reset]  \
      -command [list [namespace current]::EditListReset $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot.arr -side left -padx 8
    pack $frbot.btres -side left
    pack $frbot -side bottom -fill x
    
    $frbot.btok state {disabled}
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    set oldFocus [focus]
    
    # Cache local variables.
    set state(w)           $w
    set state(wtbl)        $wtbl
    set state(warrows)     $warrows
    set state(wbtok)       $wbtok  
    set state(type)        $type
    set state(wbtadd)      $wbtadd
    set state(wbtedit)     $wbtedit
    set state(wbtrm)       $wbtrm
    set state(origlistvar) {}
    set state(listvar)     {}
    set state(finished)    -1
    
    # How and what to get.
    switch -- $type {
	voice {
	   set getact getrole
	   set setact setrole
	   set what participant
	}
	ban {
	   set getact getaffiliation
	   set setact setaffiliation
	   set what outcast
	}
	member {
	   set getact getaffiliation
	   set setact setaffiliation
	   set what member
	}
	moderator {
	   set getact getrole
	   set setact setrole
	   set what moderator
	}
	admin {
	   set getact getaffiliation
	   set setact setaffiliation
	   set what admin
	}
	owner {    
	   set getact getaffiliation
	   set setact setaffiliation
	   set what owner
	} 
	default {
	    return -code error "Unrecognized type \"$type\""
	}
    }
    set state(getact) $getact
    set state(setact) $setact
    
    # Now, go and get it!
    $warrows start
    set state(callid) [incr editcalluid]
    $jstate(jlib) muc $getact $roomjid $what \
      [list [namespace current]::EditListGetCB $token $state(callid)]
    
    # Wait here for a button press.
    tkwait variable $token\(finished)

    ::UI::SaveWinPrefixGeom $wDlgs(jmucedit)
    catch {destroy $w}
    catch {focus $oldFocus}

    if {$state(finished) > 0} {
	EditListSet $token
    }
    set finished $state(finished)
    unset state
    return [expr {($finished <= 0) ? "cancel" : "ok"}]
}

proc ::MUC::EditListCloseHook {token wclose} {
    global  wDlgs
    variable $token
    upvar 0 $token state
	
    ::UI::SaveWinPrefixGeom $wDlgs(jmucedit)
    set state(finished) 0
}

proc ::MUC::EditListOK {token} {
    variable $token
    upvar 0 $token state
    
    set state(finished) 1
}

proc ::MUC::EditListCancel {token} {
    variable $token
    upvar 0 $token state
    
    set state(finished) 0
}

proc ::MUC::EditListGetCB {token callid jlibname type subiq} {
    variable $token
    upvar 0 $token state

    upvar ::Jabber::jstate jstate
    
    # SInce we get this async we may have been already destroyed.
    if {![info exists state(w)]} {
	return
    }

    set atype     $state(type)
    set w         $state(w)
    set wtbl      $state(wtbl)
    set warrows   $state(warrows)
    set wbtok     $state(wbtok)
    set wbtadd    $state(wbtadd)
    set wbtedit   $state(wbtedit)
    set wbtrm     $state(wbtrm)

    # Verify that this callback does indeed be the most recent.
    if {$callid != $state(callid)} {
	return
    }
    if {![winfo exists $w]} {
	return
    }
    
    $warrows stop
    if {$type eq "error"} {
	set state(finished) 0
	update idletasks
	lassign $subiq errkey errmsg
	::UI::MessageBox -type ok -icon error -message $errmsg
	return
    }
    
    set state(subiq) $subiq

    # Fill tablelist.
    FillEditList $token
    $wbtok configure -default active
    $wbtok state {!disabled}

    switch -- $atype {
	voice {
	    $wbtrm state {!disabled}
	}
	ban {
	    $wbtadd state {!disabled}
	    $wbtrm  state {!disabled}
	}
	member {
	    $wbtrm state {!disabled}
	}
	moderator {
	    $wbtrm state {!disabled}
	}
	admin {
	    $wbtadd state {!disabled}
	    $wbtrm  state {!disabled}
	}
	owner {    
	    $wbtedit state {!disabled}
	} 
    }
}

proc ::MUC::FillEditList {token} {
    variable $token
    upvar 0 $token state

    variable setListDefs

    set wtbl      $state(wtbl)
    set warrows   $state(warrows)
    set wbtok     $state(wbtok)
    set type      $state(type)
    
    set queryE $state(subiq)
    set tmplist {}
        
    foreach itemE [wrapper::getchildren $queryE] {
	set row {}
	array set val {nick "" role none affiliation none jid "" reason ""}
	array set val [wrapper::getattrlist $itemE]
	foreach c [wrapper::getchildren $itemE] {
	    set tag [wrapper::gettag $c]
	    if {[string equal $tag "reason"]} {
		set val(reason) [wrapper::getcdata $c]
		break
	    }
	}
	foreach key $setListDefs($type) {
	    lappend row $val($key)
	}
	lappend $tmplist $row
    }
    
    # Fill table. Cache orig result.
    set state(origlistvar) $tmplist
    set state(listvar) $tmplist
}

proc ::MUC::VerifyEditEntry {token wtbl row col text} {
    variable $token
    upvar 0 $token state
    variable setListDefs

    set type $state(type)

    # Is this a jid entry?
    if {[lsearch $setListDefs($type) jid] != $col} {
	return
    }
    
    if {![jlib::jidvalidate $text]} {
	bell
	::UI::MessageBox -icon error -message "Illegal jid \"$text\"" \
	  -parent [winfo toplevel $wtbl] -type ok
	$wtbl rejectinput
	return
    }
}

proc ::MUC::EditListSelect {token} {
    variable $token
    upvar 0 $token state
    
    set wtbl $state(wtbl)
    
}

proc ::MUC::EditListDoAdd {token} {
    variable $token
    upvar 0 $token state
    variable setListDefs

    set wtbl $state(wtbl)
    set type $state(type)
    set len [llength $setListDefs($type)]
    for {set i 0} {$i < $len} {incr i} {
	lappend empty {}
    }
    lappend state(listvar) $empty
    set indjid [lsearch $setListDefs($type) jid]
    array set indColumnFocus [list  \
	voice      end      \
	ban        $indjid  \
	member     end      \
	moderator  end      \
	admin      $indjid  \
	owner      end      \
    ]
    
    # Set focus.
    $wtbl editcell end,$indColumnFocus($type)
    focus [$wtbl entrypath]
}

proc ::MUC::EditListDoEdit {token} {
    variable $token
    upvar 0 $token state

    set wtbl $state(wtbl)
    set type $state(type)

    switch -- $type {
	owner {
	    $wtbl editcell end,0
	}
    }
}

proc ::MUC::EditListDoRemove {token} {
    variable $token
    upvar 0 $token state
    variable setListDefs

    set wtbl $state(wtbl)
    set type $state(type)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return 
    }
    
    switch -- $type {
	voice {
	    set ind [lsearch $setListDefs($type) "role"]
	    $wtbl cellconfigure $item,$ind -text "visitor"
	}
	ban {
	}
	member {
	    set ind [lsearch $setListDefs($type) "affiliation"]
	    $wtbl cellconfigure $item,$ind -text "none"
	}
	moderator {
	    set ind [lsearch $setListDefs($type) "role"]
	    $wtbl cellconfigure $item,$ind -text "participant"
	}
	admin {
	    set ind [lsearch $setListDefs($type) "affiliation"]
	    $wtbl cellconfigure $item,$ind -text "none"
	}
	owner {
	}
    }
}

proc ::MUC::EditListReset {token} {
    variable $token
    upvar 0 $token state

    set state(listvar) $state(origlistvar)
}

# MUC::EditListSet --
# 
#       Set (send) the edited list to the muc service.

proc ::MUC::EditListSet {token} {
    variable $token
    upvar 0 $token state
    variable setListDefs
    upvar ::Jabber::jstate jstate
    
    tk_messageBox -icon error -message "Not yet implemented. Sorry!"
    return

    # Original and present content of tablelist.
    set origlist $state(origlistvar)
    set thislist $state(listvar)
    set type     $state(type)
    set setact   $state(setact)
    
    # Only the 'diff' is necessary to send.
    # Loop through each row in the tablelist.
    foreach row $thislist {
	
	
	
	
    }
    
    switch -- $type {
	voice {

	}
	ban {

	}
	member {

	}
	moderator {

	}
	admin {

	}
	owner {

	}
    }

    
    
    eval {$jstate(jlib) muc $setact $roomjid xxx \
	  -command [list [namespace current]::IQCallback $roomjid]} $opts
}
    
# End edit lists ---------------------------------------------------------------

# Unfinished...

namespace eval ::MUC:: {
    
    ::hooks::register closeWindowHook    ::MUC::RoomConfigCloseHook
}

proc ::MUC::RoomConfig {roomjid} {
    global  this wDlgs
    
    variable wscrollframe
    variable warrows
    variable wbtok
    variable dlguid
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    set w $wDlgs(jmuccfg)[incr dlguid]
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} -class MUCConfig
    wm title $w [mc {Configure Room}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
            
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Button part.
    set frbot     $wbox.b
    set warrows   $frbot.arr
    set wbtok     $frbot.btok
    set wbtcancel $frbot.btcancel
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] -default active \
      -command [list [namespace current]::DoRoomConfig $roomjid $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelConfig $roomjid $w]
    ::chasearrows::chasearrows $warrows -size 16
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $warrows -side left
    pack $frbot -side bottom -fill x
    
    $frbot.btok state {disabled}
    
    # The form part.
    set wscrollframe $wbox.scform
    ::UI::ScrollFrame $wscrollframe -padding {8 12} -bd 1 -relief sunken
    pack $wscrollframe
        
    # Now, go and get it!
    $warrows start
    $jstate(jlib) muc getroom $roomjid  \
      [list [namespace current]::ConfigGetCB $roomjid]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    
    # Wait here for a button press and window to be destroyed. BAD?
    tkwait window $w
    
    ::UI::SaveWinGeom $w
    catch {focus $oldFocus}
    return
}

proc ::MUC::RoomConfigCloseHook {wclose} {
    global  wDlgs

    #wm protocol $w WM_DELETE_WINDOW  \
    #  [list [namespace current]::CancelConfig $roomjid $w]

    if {[string match $wDlgs(jmuccfg)* $wclose]} {

	
    }   
}

proc ::MUC::CancelConfig {roomjid w} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    $jstate(jlib) muc setroom $roomjid cancel
    destroy $w
}

proc ::MUC::ConfigGetCB {roomjid jlibname type subiq} {
    variable wscrollframe
    variable warrows
    variable wbtok
    variable wform
    variable formtoken
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    if {![winfo exists $warrows]} {
	return
    }
    $warrows stop
    
    if {$type eq "error"} {
	destroy [winfo toplevel $wscrollframe]
	lassign $subiq errcode errmsg
	::UI::MessageBox -icon error -type ok -title [mc Error] -message $errmsg
    } else {
	set frint [::UI::ScrollFrameInterior $wscrollframe]
	set wform $frint.f
	set formtoken [::JForms::Build $wform $subiq -tilestyle Small -width 200]
	pack $wform
	$wbtok configure -default active
	$wbtok state {!disabled}
    }
}

proc ::MUC::DoRoomConfig {roomjid w} {
    variable wform
    variable formtoken
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    set subelements [::JForms::GetXML $formtoken]
    
    $jstate(jlib) muc setroom $roomjid submit -form $subelements \
      -command [list [namespace current]::RoomConfigResult $roomjid]
    destroy $w
}

proc ::MUC::RoomConfigResult {roomjid jlibname type subiq} {

    if {$type eq "error"} {
	regexp {^([^@]+)@.*} $roomjid match roomName
	::UI::MessageBox -type ok -icon error  \
	  -message "We failed trying to configurate room \"$roomName\".\
	  [lindex $subiq 0] [lindex $subiq 1]"
    }
}

# MUC::SetNick --
# 
# 

proc ::MUC::SetNick {roomjid} {
    variable locals
    upvar ::Jabber::jstate jstate
        
    set title [mc {Set New Nickname}]
    set msg   [mc {Select a new nickname}]
    set ans [ui::megaentry -label "[mc {New Nickname}]:" -icon question \
      -geovariable prefs(winGeom,jmucnick) -title $title -message $msg]
	
    if {$ans ne ""} {
	set nickname [ui::megaentrytext $ans]
	if {$nickname ne ""} {
	    $jstate(jlib) muc setnick $roomjid $nickname \
	      -command [namespace current]::PresCallback
	}
    }
}

namespace eval ::MUC:: {
    

}

proc ::MUC::Destroy {roomjid} {
    global this wDlgs
    
    upvar ::Jabber::jstate jstate
    variable findestroy -1
    variable destroyAltJID ""
    variable destroyRoomJID $roomjid
    variable destroyreason ""
    variable dlguid
    variable wdestroyjid
    
    set w $wDlgs(jmucdestroy)[incr dlguid]
    ::UI::Toplevel $w \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand ::MUC::DestroyCloseCmd
    set roomName [$jstate(jlib) disco name $roomjid]
    if {$roomName eq ""} {
	jlib::splitjidex $roomjid roomName x y
    }
    wm title $w "[mc {Destroy Room}]: $roomName"
    ::UI::SetWindowPosition $w $wDlgs(jmucdestroy)
    set findestroy -1
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    set msg [mc mucDestroy $roomName]
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text $msg
    pack $wbox.msg -side top -anchor w
    
    set wmid $wbox.fr
    ttk::frame $wmid
    pack $wmid -side top -fill x -expand 1
    
    ttk::label $wmid.la -text [mc {Alternative Room JID}]
    ttk::combobox $wmid.ejid -textvariable [namespace current]::destroyAltJID
    ttk::button $wmid.browse -text [mc Browse] \
      -command [namespace code DestroyBrowse]
    ttk::label $wmid.lre -text "[mc Reason]:"
    ttk::entry $wmid.ere -textvariable [namespace current]::destroyreason
    
    grid  $wmid.la   $wmid.ejid  $wmid.browse  -pady 2
    grid  $wmid.lre  $wmid.ere   -             -pady 2
    grid columnconfigure $wmid 1 -weight 1
    grid $wmid.la $wmid.lre -sticky e
    grid $wmid.ejid $wmid.ere -sticky ew
    
    set wdestroyjid $wmid.ejid
        
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK]  \
      -default active -command [list set [namespace current]::findestroy 1]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list set [namespace current]::findestroy 0]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $wmid.ejid
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::findestroy
    
    ::UI::SaveWinPrefixGeom $wDlgs(jmucdestroy)

    catch {grab release $w}
    catch {destroy $w}
    catch {focus $oldFocus}

    set opts [list]
    if {$destroyreason ne ""} {
	set opts [list -reason $destroyreason]
    }
    if {$destroyAltJID ne ""} {
	set opts [list -alternativejid $destroyAltJID]
    }

    if {$findestroy > 0} {
	eval {$jstate(jlib) muc destroy $roomjid  \
	  -command [list [namespace current]::IQCallback $roomjid]} $opts
    }
    return [expr {($findestroy <= 0) ? "cancel" : "ok"}]
}

proc ::MUC::DestroyBrowse {} {
    upvar ::Jabber::jstate jstate
    variable destroyRoomJID
    
    jlib::splitjidex $destroyRoomJID - service -
    $jstate(jlib) disco get_async items $service \
      [namespace code DestroyBrowseCB]
}

proc ::MUC::DestroyBrowseCB {jlibname type jid subiq args} {
    upvar ::Jabber::jstate jstate
    variable wdestroyjid
    variable destroyRoomJID
    variable destroyAltJID
  
    if {[winfo exists $wdestroyjid] && ($type eq "result")} {
	jlib::splitjidex $destroyRoomJID - service -
	set allRooms [$jstate(jlib) disco children $service]
	$wdestroyjid configure -values $allRooms
	set destroyAltJID [lindex $allRooms 0]
    }    
}

proc ::MUC::DestroyCloseCmd {wclose} {
    global  wDlgs
    variable findestroy
	
    ::UI::SaveWinPrefixGeom $wDlgs(jmucdestroy)
    set findestroy 0
}

# MUC::IQCallback, PresCallback --
# 
#       Generic callbacks when setting things via <iq/> or <presence/>

proc ::MUC::IQCallback {roomjid jlibname type subiq} {
    
    if {[string equal $type "error"]} {
	jlib::splitjidex $roomjid roomName - -
	::UI::MessageBox -type ok -icon error -title [mc Error]  \
	  -message [mc mucIQError $roomName $subiq]
    }
}


proc ::MUC::PresCallback {jlibname xmldata} {
    
    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {$type eq ""} {
	set type "available"
    }    
    if {[string equal $type "error"]} {
	set errspec [jlib::getstanzaerrorspec $xmldata]
	set errmsg ""
	if {[llength $errspec]} {
	    set errcode [lindex $errspec 0]
	    set errmsg  [lindex $errspec 1]
	}
	jlib::splitjidex $from roomName - -
	::UI::MessageBox -type ok -icon error -title [mc Error]  \
	  -message [mc mucIQError $roomName $errmsg]
    }
}

proc ::MUC::InfoCloseHook {wclose} {
    global  wDlgs
	
    if {[string match $wDlgs(jmucinfo)* $wclose]} {

	# Need to find roomjid from toplevel widget.
	foreach ns [namespace children [namespace current]] {
	    set roomjid [namespace tail $ns]
	    if {[string equal [set ${ns}::locals($roomjid,w)] $wclose]} {
		Close $roomjid
	    }
	}
    }   
}

proc ::MUC::Close {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals

    catch {destroy $locals($roomjid,w)}
    namespace delete [namespace current]::${roomjid}
}

#-------------------------------------------------------------------------------
