#agents JivePhone.tcl --
# 
#       JivePhone bindings for the jive server and Asterisk.
#       
#       Contributions and testing by Antonio Cano damas
#       
# $Id: JivePhone.tcl,v 1.19 2006-02-21 08:40:59 matben Exp $

# My notes on the present "Phone Integration Proto-JEP" document from
# Jive Software:
# 
#   1) server support for this is indicated by the disco child of the server
#      where it should instead be a disco info feature element.
#      
#   2) "The username must be set as the node attribute on the query"
#      when obtaining info if a particular user has support for this.
#      This seems wrong since only a specific instance of a user specified
#      by an additional resource can have specific features.

#    I could imagine a dialer as a tab page, but then we need nice buttons.
#

namespace eval ::JivePhone:: { }

proc ::JivePhone::Init { } {
    
    component::register JivePhone  \
      "Provides support for the VoIP notification in the jive server"
        
    # Add event hooks.
    ::hooks::register presenceHook          ::JivePhone::PresenceHook
    ::hooks::register newMessageHook        ::JivePhone::MessageHook
    ::hooks::register loginHook             ::JivePhone::LoginHook
    ::hooks::register logoutHook            ::JivePhone::LogoutHook
    ::hooks::register rosterPostCommandHook ::JivePhone::RosterPostCommandHook

    ::hooks::register buildChatButtonTrayHook      ::JivePhone::buildChatButtonTrayHook
    
    variable xmlns
    set xmlns(jivephone) "http://jivesoftware.com/xmlns/phone"
    
    # Note the difference!
    variable feature
    set feature(jivephone) "http://jivesoftware.com/phone"
    
    variable statuses {AVAILABLE RING DIALED ON_PHONE HANG_UP}


    #--------------- Variables Uses For PopUP Menus -------------------------
    variable popMenuDef
    set popMenuDef(call) {
	command  mCall     {user available} {::JivePhone::DialJID $jid "DIAL"} {}
    }
    set popMenuDef(forward) {
	command  mForward  {user available} {::JivePhone::DialJID  $jid "FORWARD"} {}
    }

    variable menuDef
    set menuDef  \
      {command  mCall     {::JivePhone::DoDial "DIAL"}    normal {}}


    #--------------- Variables Uses For SpeedDial Addressbook Tab ----------------
    variable wtab -
    variable abline

    set popMenuDef(addressbook,def) {
        mCall          jid       {::JivePhone::DialExtension $jid "DIAL"}
        separator      {}        {}
        mNewAB         jid       {::JivePhone::NewAddressbookDlg}
        mModifyAB      jid       {::JivePhone::ModifyAddressbookDlg  $jid}
        mRemoveAB      jid       {::JivePhone::RemoveAddressbookDlg  $jid}
    }


    InitState
}

proc ::JivePhone::InitState { } {
    variable state
    
    array set state {
	phoneserver     0
	setui           0
	win             .dial
	wstatus         -
	phone		-
        abphonename     -
        abphonenumber   -
    }
}


#----------------------------------------------------------------------------
#-------------------- JEP Messages Function Handlers ------------------------
#----------------------------------------------------------------------------
proc ::JivePhone::LoginHook { } {
    
    set server [::Jabber::GetServerJid]
    ::Jabber::JlibCmd disco get_async items $server ::JivePhone::OnDiscoServer   
}

proc ::JivePhone::OnDiscoServer {jlibname type from subiq args} {
    variable state
    
    Debug "::JivePhone::OnDiscoServer"
        
    # See comments above what my opinion is...
    if {$type eq "result"} {
	set childs [::Jabber::JlibCmd disco children $from]
	foreach service $childs {
	    set name [::Jabber::JlibCmd disco name $service]
	    
	    Debug "\t service=$service, name=$name"

	    if {$name eq "phone"} {
		set state(phoneserver) 1
		set state(service) $service
		break
	    }
	}
    }
    if {$state(phoneserver)} {
	
	# @@@ It is a bit unclear if we shall disco the phone service with
	# the username as each node.
	
	# We may not yet have obtained the roster. Sync issue!
	if {[::Jabber::RosterCmd haveroster]} {
	    DiscoForUsers
	} else {
	    ::hooks::register rosterExit ::JivePhone::RosterHook
	}
    }
}

proc ::JivePhone::RosterHook {} {
        
    Debug "::JivePhone::RosterHook"
    ::hooks::deregister rosterExit ::JivePhone::RosterHook
    DiscoForUsers
}

proc ::JivePhone::DiscoForUsers {} {
    variable state
    
    Debug "::JivePhone::DiscoForUsers"
    set users [::Jabber::RosterCmd getusers]
    
    # We add ourselves to this list to figure out if we've got a jive phone.
    lappend users [::Jabber::JlibCmd getthis myjid2]
    
    foreach jid $users {
	jlib::splitjidex $jid node domain -	
	if {[::Jabber::GetServerJid] eq $domain} {
	    ::Jabber::JlibCmd disco get_async info $state(service)  \
	      ::JivePhone::OnDiscoUserNode -node $node
	}
    }
}

proc ::JivePhone::OnDiscoUserNode {jlibname type from subiq args} {
    variable xmlns
    variable state
    variable feature
    
    Debug "::JivePhone::OnDiscoUserNode"
    
    if {$type eq "result"} {
	set node [wrapper::getattribute $subiq "node"]
	set havePhone [::Jabber::JlibCmd disco hasfeature $feature(jivephone)  \
	  $from $node]

	Debug "\t from=$from, node=$node, havePhone=$havePhone"

	if {$havePhone} {
	
	    # @@@ What now?
	    # @@@ But if we've already got phone presence?

	    # Really stupid! It assumes user exist on login server.
	    set server [::Jabber::JlibCmd getserver]
	    set jid [jlib::joinjid $node $server ""]
	    #puts "\t jid=$jid"
	    
	    # Cache this info.
	    #set state(phone,$jid)

	    # Since we added ourselves to the list take action if have phone.
	    set myjid2 [::Jabber::JlibCmd getthis myjid2]
	    if {[jlib::jidequal $jid $myjid2]} {
		WeHavePhone
	    } else {
	    
		# Attempt to set icon only if this user is unavailable since
		# we do not have the full jid!
		# This way we shouldn't interfere with phone presence.
		# We could use [roster isavailable $jid] instead.
		
		set item [::RosterTree::FindWithTag [list jid $jid]]
		if {$item ne ""} {
		    set image [::Rosticons::Get [string tolower phone/available]]
		    ::RosterTree::StyleSetItemAlternative $jid jivephone  \
		      image $image
		}
	    }
	}
    }
}

proc ::JivePhone::WeHavePhone { } {
    variable state
    variable popMenuDef
    variable menuDef

    NewPage    
    if {$state(setui)} {
	return
    }
    ::Jabber::UI::RegisterPopupEntry roster $popMenuDef(call)
    ::Jabber::UI::RegisterMenuEntry  jabber $menuDef
    
    set image [::Rosticons::Get [string tolower phone/available]]
    set win [::Jabber::UI::SetAlternativeStatusImage jivephone $image]
    bind $win <Button-1> [list ::JivePhone::DoDial "DIAL"]
    ::balloonhelp::balloonforwindow $win [mc phoneMakeCall]
    
    set state(wstatus) $win
    set state(setui)   1

}

proc ::JivePhone::LogoutHook { } {
    variable state
    variable wtab
    variable abline

    ::Roster::DeRegisterPopupEntry mCall
    ::Roster::DeRegisterPopupEntry mForward
    ::Jabber::UI::DeRegisterMenuEntry jabber mCall
    ::Jabber::UI::RemoveAlternativeStatusImage jivephone
    
    if {[winfo exists $state(wstatus)]} {
	destroy $state(wstatus)
    }
    unset -nocomplain state

    destroy $wtab
    if { [info exists abline] } {
        unset abline
    }

    InitState
}

# JivePhone::PresenceHook --
# 
#       A user's presence is updated when on a phone call.

proc ::JivePhone::PresenceHook {jid type args} {
    variable xmlns
    variable state

    Debug "::JivePhone::PresenceHook jid=$jid, type=$type, $args"
    
    if {$type ne "available"} {
	return
    }

    array set argsArr $args
    if {[info exists argsArr(-xmldata)]} {
	set xmldata $argsArr(-xmldata)
	set elems [wrapper::getchildswithtagandxmlns $xmldata  \
	  phone-status $xmlns(jivephone)]
	if {$elems ne ""} {
	    set from [wrapper::getattribute $xmldata from]
	    set elem [lindex $elems 0]
	    set status [wrapper::getattribute $elem "status"]
	    if {$status eq ""} {
		set status available
	    }
	    # Cache this info. 
	    # @@@ How do we get unavailable status?
	    # Must check for "normal" presence info.
	    set state(status,$from) $status

	    set image [::Rosticons::Get [string tolower phone/$status]]
	    ::RosterTree::StyleSetItemAlternative $from jivephone image $image
	    eval {::hooks::run jivePhonePresence $from $type} $args
	}
    }
    return
}

# JivePhone::MessageHook --
#
#       Events are sent to the user when their phone is ringing, ...
#       ... message packets are used to send events for the time being. 

proc ::JivePhone::MessageHook {body args} {    
    variable xmlns
    variable popMenuDef
    variable state
    variable callID

    Debug "::JivePhone::MessageHook $args"
    
    array set argsArr $args
    if {[info exists argsArr(-xmldata)]} {
	set elem [wrapper::getfirstchildwithtag $argsArr(-xmldata) "phone-event"]
	if {$elem != {}} {
	    set status [wrapper::getattribute $elem "status"]
	    if {$status eq ""} {
		set status available
	    }
	    set cidElem [wrapper::getfirstchildwithtag $elem callerID]
	    if {$cidElem != {}} {
		set cid [wrapper::getcdata $cidElem]
	    } else {
		set cid [mc {Unknown}]
	    }
	    set image [::Rosticons::Get [string tolower phone/$status]]
	    
	    set win [::Jabber::UI::SetAlternativeStatusImage jivephone $image]
	    set type [wrapper::getattribute $elem "type"]

	    # @@@ What to do more?
	    if {$type eq "RING" } {
		set callID [wrapper::getattribute $elem "callID"]

		::Jabber::UI::RegisterPopupEntry roster $popMenuDef(forward)
		bind $win <Button-1> [list ::JivePhone::DoDial "FORWARD"]
		::balloonhelp::balloonforwindow $win [mc phoneMakeForward]
		eval {::hooks::run jivePhoneEvent $type $cid $callID} $args
	    }
	    if {$type eq "HANG_UP"} {
		::Roster::DeRegisterPopupEntry mForward

		bind $win <Button-1> [list ::JivePhone::DoDial "DIAL"]
		::balloonhelp::balloonforwindow $win [mc phoneMakeCall]
		eval {::hooks::run jivePhoneEvent $type $cid ""} $args
	    }
	    
	    # Provide a default notifier?
#	    if {[hooks::info jivePhoneEvent] eq {}} {
#		NotifyCall::InboundCall{ $cid }
#		set title [mc phoneRing]
#		set msg [mc phoneRingFrom $cid]
#		ui::dialog -icon info -buttons {} -title $title  \
#		  -message $msg -timeout 4000
#	    }
	}
    }
    return
}

proc ::JivePhone::RosterPostCommandHook {wmenu jidlist clicked status} {
    variable state
    
    set jid3 [lindex $jidlist 0]
    jlib::splitjid $jid3 jid2 -
    set jid $jid2
    
    Debug "RosterPostCommandHook $jidlist $clicked $status"

    if {$clicked ne "user"} {
	return
    }
    if {$status ne "available"} {
	return
    }
    if {[info exists state(phone,$jid]} {	
	if {[info exists state(status,$jid)]} {
	    
	    switch -- $state(status,$jid3) {
		AVAILABLE - HANG_UP {
		    ::Roster::SetMenuEntryState $wmenu mCall normal
		}
		XXXX {
		    # @@@ ???
		    ::Roster::SetMenuEntryState $wmenu mForward normal
		}
	    }
	}
    }
}

#-----------------------------------------------------------------------
#------------------------ JivePhone Dialer Window ----------------------
#---------------------- (Dial/Forward - Extension/Jid) -----------------
#-----------------------------------------------------------------------


# JivePhone::DoDial --
# 
#       type: FORWARD | DIAL

proc ::JivePhone::DoDial {type {jid ""}} {
    variable state
    variable phoneNumber
    
    set win $state(win)
    if {$jid eq ""} {
	BuildDialer $win $type
    } else {
	jlib::splitjidex $jid node domain -
	if {[::Jabber::GetServerJid] eq $domain} {
	    set phoneNumber ""
	    OnDial $win $type $jid
	} else {
	    BuildDialer $win $type
	}
    }
}

# JivePhone::BuildDialer --
# 
#       A toplevel dialer.
       
proc ::JivePhone::BuildDialer {w type} {
    variable state
    variable phoneNumber
    
    # Make sure only single instance of this dialog.
    if {[winfo exists $w]} {
	raise $w
	return
    }

    ::UI::Toplevel $w -class PhoneDialer \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace current]::CloseDialer

    if {$type eq "DIAL"} {
	wm title $w [mc phoneDialerCall]
    } else {
	wm title $w [mc phoneDialerForward]
    }

    ::UI::SetWindowPosition $w
    set phoneNumber ""

    # Global frame.
    ttk::frame $w.f
    pack  $w.f  -fill x
				 
    ttk::label $w.f.head -style Headlabel -text [mc {Phone}]
    pack  $w.f.head  -side top -fill both -expand 1

    ttk::separator $w.f.s -orient horizontal
    pack  $w.f.s  -side top -fill x

    set wbox $w.f.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1
    
    set box $wbox.b
    ttk::frame $box
    pack $box -side bottom -fill x
    
    ttk::label $box.l -text "[mc phoneNumber]:"
    ttk::entry $box.e -textvariable [namespace current]::phoneNumber  \
      -width 18
    ttk::button $box.dial -text [mc phoneDial]  \
      -command [list [namespace current]::OnDial $w $type]
    
    grid  $box.l  $box.e  $box.dial -padx 1 -pady 4
 
    focus $box.e
    wm resizable $w 0 0
}

proc ::JivePhone::CloseDialer {w} {
    
    ::UI::SaveWinGeom $w   
}

#-------------------------------------------------------------------------
#------------------- JivePhone Send IQ Actions ---------------------------
#-------------------------------------------------------------------------

proc ::JivePhone::OnDial {w type {jid ""}} {
    variable phoneNumber
    variable xmlns
    variable state
    variable callID
    
    Debug "::JivePhone::OnDial w=$w, type=$type, phoneNumber=$phoneNumber"
    
    if {!$state(phoneserver)} {
	return
    }

    if {$jid ne ""} {
	set dnid $jid
	set extensionElem [wrapper::createtag "jid" -chdata $jid]
    } elseif {$phoneNumber ne ""} {
	set extensionElem [wrapper::createtag "extension" -chdata $phoneNumber]
	set dnid $phoneNumber
    } else {
	Debug "\t return"
	return
    }
    
    if {$type eq "DIAL"} {
	set command "DIAL"
	set attr [list xmlns $xmlns(jivephone) type $command]
    } else {
	set command "FORWARD"
	set attr [list xmlns $xmlns(jivephone) id $callID type $command]
    }
    set phoneElem [wrapper::createtag "phone-action"  \
      -attrlist $attr -subtags [list $extensionElem]]

    ::Jabber::JlibCmd send_iq set [list $phoneElem]  \
      -to $state(service) -command [list ::JivePhone::DialCB $dnid]

    eval {::hooks::run jivePhoneEvent $command $dnid $callID}

    destroy $w
}

proc ::JivePhone::DialJID {jid type {callID ""}} {
    variable state
    variable xmlns
   
    if {!$state(phoneserver)} {
	return
    }
    set extensionElem [wrapper::createtag "jid" -chdata $jid]

    if {$type eq "DIAL"} {
	set command "DIAL"
	set attr [list xmlns $xmlns(jivephone) type $command]
    } else {
	# @@@ Where comes callID from?
	set command "FORWARD"
	set attr [list xmlns $xmlns(jivephone) id $callID type $command]
    }
    set phoneElem [wrapper::createtag "phone-action"  \
      -attrlist $attr -subtags [list $extensionElem]]

    ::Jabber::JlibCmd send_iq set [list $phoneElem]  \
      -to $state(service) -command [list ::JivePhone::DialCB $jid]

    eval {::hooks::run jivePhoneEvent $command $jid $callID}    
}

proc ::JivePhone::DialExtension {extension type {callID ""}} {
    variable state
    variable xmlns

    if {!$state(phoneserver)} {
        return
    }
    set extensionElem [wrapper::createtag "extension" -chdata $extension]

    if {$type eq "DIAL"} {
        set command "DIAL"
        set attr [list xmlns $xmlns(jivephone) type $command]
    } else {
        # @@@ Where comes callID from?
        set command "FORWARD"
        set attr [list xmlns $xmlns(jivephone) id $callID type $command]
    }

    set phoneElem [wrapper::createtag "phone-action"  \
      -attrlist $attr -subtags [list $extensionElem]]

    ::Jabber::JlibCmd send_iq set [list $phoneElem]  \
      -to $state(service) -command [list ::JivePhone::DialCB $extension]

    eval {::hooks::run jivePhoneEvent $command $extension $callID}
}

proc ::JivePhone::DialCB {dnid type subiq args} {
    
    if {$type eq "error"} {
	ui::dialog -icon error -type ok -message [mc phoneFailedCalling $dnid] \
	  -detail $subiq
    }
}


#---------------------------------------------------------------------------
#------------------- JivePhone Addressbook SpeedDial Tab -------------------
#---------------------------------------------------------------------------

proc ::JivePhone::NewPage { } {
    variable wtab

    set wnb [::Jabber::UI::GetNotebook]
    set wtab $wnb.ab
    if {![winfo exists $wtab]} {
        set im [::Theme::GetImage \
          [option get [winfo toplevel $wnb] browser16Image {}]]
        set imd [::Theme::GetImage \
          [option get [winfo toplevel $wnb] browser16DisImage {}]]
        set imSpec [list $im disabled $imd background $imd]
        Build $wtab
        $wnb add $wtab -text [mc AddressBook] -image $imSpec -compound left
    }
}

# JivePhone::Build --
#
#       This is supposed to create a frame which is pretty object like,
#       and handles most stuff internally without intervention.
#
# Arguments:
#       w           frame for everything
#       args
#
# Results:
#       w

proc ::JivePhone::Build {w args} {
    global  prefs this

    variable waddressbook
    variable wtree
    variable wwave
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    variable abline

    ::Debug 2 "::JivePhone::Build w=$w"
    set jstate(wpopup,addressbook)    .jpopupab
    set waddressbook $w
    set wwave   $w.fs
    set wbox    $w.box
    set wtree   $wbox.tree
    set wxsc    $wbox.xsc
    set wysc    $wbox.ysc

    # The frame.
    ttk::frame $w -class AddressBook 

#    set waveImage [::Theme::GetImage [option get $w waveImage {}]]
#    ::wavelabel::wavelabel $wwave -relief groove -bd 2 \
#      -type image -image $waveImage
#    pack $wwave -side bottom -fill x -padx 8 -pady 2
   
    # D = -border 1 -relief sunken
    frame $wbox
    pack  $wbox -side top -fill both -expand 1

    set bgimage [::Theme::GetImage [option get $w backgroundImage {}]]
    ttk::scrollbar $wxsc -orient horizontal -command [list $wtree xview]
    ttk::scrollbar $wysc -orient vertical -command [list $wtree yview]

    ::ITree::New $wtree $wxsc $wysc   \
      -buttonpress ::JivePhone::Popup         \
      -buttonpopup ::JivePhone::Popup         \
      -backgroundimage $bgimage

    grid  $wtree  -row 0 -column 0 -sticky news
    grid  $wysc   -row 0 -column 1 -sticky ns
    grid  $wxsc   -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1

    #--------- Load Entries of AddressBook into NewPage Tab ---------
    LoadEntries
    if { $abline ne "" } {
        foreach {name phone} $abline {
            set opts {-text "$name ($phone)"}
            if {$name ne ""} {
               lappend opts -text "$name ($phone)"
               eval {::ITree::Item $wtree $phone} $opts
            }
        }
    }
    return $w
}

proc ::JivePhone::LoadEntries {} {
    variable abline
    global  prefs this
    
    # @@@ Mats
    #set fileName "$this(prefsPath)/addressbook.csv"
    set fileName [file join $this(prefsPath) addressbook.csv]

    if { [ file exists $fileName ] } {
        set hFile [open $fileName "r"]
        while {[eof $hFile] <= 0} {
           gets $hFile line
           set temp [split $line ":"]
           foreach i $temp {
               lappend abline $i
           }
        }

        close $hFile
    } else {
        set abline ""
    }
}

# JivePhone::Popup --
#
#       Handle popup menus in JivePhone, typically from right-clicking.
#
# Arguments:
#       w           widget that issued the command: tree or text
#       v           for the tree widget it is the item path,
#                   for text the jidhash.
#
# Results:
#       popup menu displayed

proc ::JivePhone::Popup {w v x y} {
    global  wDlgs this
    variable popMenuDef

    upvar ::Jabber::jstate jstate

    ::Debug 2 "::JivePhone::Popup w=$w, v='$v', x=$x, y=$y"

    # The last element of $v is either a jid, (a namespace,)
    # a header in roster, a group, or an agents xml tag.
    # The variables name 'jid' is a misnomer.
    # Find also type of thing clicked, 'typeClicked'.

    set typeClicked ""

    set jid [lindex $v end]
    set jid3 $jid
    set childs [::ITree::Children $w $v]

    if {$jid ne ""} {
        set typeClicked jid
    }

    if {[string length $jid] == 0} {
        set typeClicked ""     
    }
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]

    ::Debug 2 "\t jid=$jid, typeClicked=$typeClicked"

    # Mads Linden's workaround for menu post problem on mac:
    # all in menubutton commands i add "after 40 the_command"
    # this way i can never have to posting error.
    # it is important after the tk_popup f.ex to
    #
    # destroy .mb
    # update
    #
    # this way the .mb is destroyd before the next window comes up, thats how I
    # got around this.

    # Make the appropriate menu.
    set m $jstate(wpopup,addressbook)
    set i 0
    catch {destroy $m}
    menu $m -tearoff 0

    foreach {item type cmd} $popMenuDef(addressbook,def) {
        if {[string index $cmd 0] == "@"} {
            set mt [menu ${m}.sub${i} -tearoff 0]
            set locname [mc $item]
            $m add cascade -label $locname -menu $mt -state disabled
            eval [string range $cmd 1 end] $mt
            incr i
        } elseif {[string equal $item "separator"]} {
            $m add separator
            continue
        } else {

            # Substitute the jid arguments. Preserve list structure!
            set cmd [eval list $cmd]
            set locname [mc $item]
            $m add command -label $locname -command [list after 40 $cmd]  \
              -state disabled
        }

        # If a menu should be enabled even if not connected do it here.

        if {![::Jabber::IsConnected]} {
            continue
        }
        if {[string equal $type "any"]} {
            $m entryconfigure $locname -state normal
            continue
        }

        # State of menu entry. We use the 'type' and 'typeClicked' to sort
        # out which capabilities to offer for the clicked item.
        set state disabled

	if {[string equal $item "mNewAB"]} {
	    set state normal
	}

        if {[string equal $type $typeClicked]} {
            set state normal
        } 
        if {[string equal $state "normal"]} {
            $m entryconfigure $locname -state normal
        }
    }  

    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks

    # Post popup menu.
    tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]

    # Mac bug... (else can't post menu while already posted if toplevel...)
    if {[string equal "macintosh" $this(platform)]} {
        catch {destroy $m}
        update
    }
}

proc ::JivePhone::RemoveAddressbookDlg {jid} {
    variable abline
    variable wtree

    set index [lsearch -exact $abline $jid]

    set tmp [lreplace $abline [expr $index-1] $index]
    set abline $tmp

    eval {::ITree::DeleteItem $wtree $jid} 

    SaveEntries

}


proc ::JivePhone::NewAddressbookDlg {} {
    global  this wDlgs

    variable abName
    variable abPhoneNumber

    set abName ""
    set abPhoneNumber ""

    set w ".nadbdlg" 
    ::UI::Toplevel $w \
      -macstyle documentProc -macclass {document closeBox} -usemacmainmenu 1 \
      -closecommand [namespace current]::CloseCmd
    wm title $w [mc {newAddressbookDlg}]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jmucenter)]]
    if {$nwin == 1} {
        ::UI::SetWindowPosition $w ".nadbdlg" 
    }

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
   
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 260 -justify left -text [mc newAddressbook ]
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.lname -text "[mc {abName}]:"
    ttk::entry $frmid.ename -textvariable [namespace current]::abName

    ttk::label $frmid.lphone -text "[mc {abPhone}]:"
    ttk::entry $frmid.ephone -textvariable [namespace current]::abPhoneNumber

    grid  $frmid.lname    $frmid.ename        -  -sticky e -pady 2
    grid  $frmid.lphone    $frmid.ephone   -  -sticky e -pady 2
    grid  $frmid.ephone  $frmid.ename  -sticky ew
    grid columnconfigure $frmid 1 -weight 1

    # Button part.
    set frbot $wbox.b
    set wenter  $frbot.btok
    ttk::frame $frbot
    ttk::button $wenter -text [mc Enter] \
      -default active -command [list [namespace current]::addItemAddressBook $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelEnter $w]

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

    bind $w <Return> [list $wenter invoke]

    # Trick to resize the labels wraplength.
    set script [format {
        update idletasks
        %s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wbox.msg $w]   
    after idle $script
}

proc ::JivePhone::ModifyAddressbookDlg {jid} {
    global  this wDlgs

    variable abName
    variable abPhoneNumber
    variable abline

    #Get Entry data from abline list
    set index [lsearch -exact $abline $jid]
    set abName [lindex $abline [expr $index-1]]
    set abPhoneNumber [lindex $abline [expr $index]]
    set oldPhoneNumber $abPhoneNumber

    set w ".madbdlg"
    ::UI::Toplevel $w \
      -macstyle documentProc -macclass {document closeBox} -usemacmainmenu 1 \
      -closecommand [namespace current]::CloseCmd
    wm title $w [mc {modifyAddressbookDlg}]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jmucenter)]]
    if {$nwin == 1} {
        ::UI::SetWindowPosition $w ".madbdlg"
    }

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 260 -justify left -text [mc modifyAddressbook ]
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.lname -text "[mc {abName}]:"
    ttk::entry $frmid.ename -textvariable [namespace current]::abName

    ttk::label $frmid.lphone -text "[mc {abPhone}]:"
    ttk::entry $frmid.ephone -textvariable [namespace current]::abPhoneNumber

    grid  $frmid.lname    $frmid.ename        -  -sticky e -pady 2
    grid  $frmid.lphone    $frmid.ephone   -  -sticky e -pady 2
    grid  $frmid.ephone  $frmid.ename  -sticky ew
    grid columnconfigure $frmid 1 -weight 1

    # Button part.
    set frbot $wbox.b
    set wenter  $frbot.btok
    ttk::frame $frbot
    ttk::button $wenter -text [mc Enter] \
      -default active -command [list [namespace current]::modifyItemAddressBook $w $oldPhoneNumber]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelEnter $w]

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

    bind $w <Return> [list $wenter invoke]

    # Trick to resize the labels wraplength.
    set script [format {
        update idletasks
        %s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wbox.msg $w]
    after idle $script
}


proc ::JivePhone::addItemAddressBook {w} {
    variable abName
    variable abPhoneNumber
    variable abline
    variable wtree

    if { $abName ne "" && $abPhoneNumber ne ""} {
        lappend abline $abName
        lappend abline $abPhoneNumber

        set opts {-text "$abName ($abPhoneNumber)"}
        eval {::ITree::Item $wtree $abPhoneNumber} $opts
        SaveEntries 
 
        ::UI::SaveWinGeom $w
        destroy $w    
    }
}

proc ::JivePhone::modifyItemAddressBook {w oldPhoneNumber} {
    variable abName
    variable abPhoneNumber
    variable abline
    variable wtree

    if { $abName ne "" && $abPhoneNumber ne "" } {
        #---------- Updates Memory Addressbook -----------------
        set index [lsearch -exact $abline $oldPhoneNumber]

        set tmp [lreplace $abline [expr $index-1] $index $abName $abPhoneNumber]
        set abline $tmp

        #----- Updates GUI ---------
        eval {::ITree::DeleteItem $wtree $oldPhoneNumber}
        set opts {-text "$abName ($abPhoneNumber)"}
        eval {::ITree::Item $wtree $abPhoneNumber} $opts

        #----- Updates Database -------
        SaveEntries

        ::UI::SaveWinGeom $w
        destroy $w
    }
}

proc ::JivePhone::CancelEnter {w} {

    ::UI::SaveWinGeom $w
    destroy $w
}

proc ::JivePhone::CloseCmd {w} {

    ::UI::SaveWinGeom $w
}

proc ::JivePhone::SaveEntries {} {
    variable abline
    global  prefs this

    # @@@ Mats
    set hFile [open [file join $this(prefsPath) addressbook.csv] "w"]

    foreach {name phonenumber} $abline {
       if {$name ne ""} {
           puts $hFile "$name:$phonenumber"
       }
    }

    close $hFile
}

proc ::JivePhone::Debug {msg} {
    
    if {0} {
	puts "-------- $msg"
    }
}

proc ::JivePhone::buildChatButtonTrayHook {wtray dlgtoken args} {
    global  this prefs wDlgs
    variable state

    if { $state(phoneserver) == 1 } {
	# @@@ Mats
	if {0} {
	    set dlgtokenLength [string length $dlgtoken]
	    set dlgtokenUid [string first "g" $dlgtoken ]
	    set dlgtokenFirst [expr $dlgtokenUid+1]
	    set uiddlg [string range $dlgtoken $dlgtokenFirst $dlgtokenLength]
	    set w $wDlgs(jchat)${uiddlg}
	}
	variable $dlgtoken
	upvar 0 $dlgtoken dlgstate

	set w $dlgstate(w)
	
        option add *Chat*callImage           call                 widgetDefault
        option add *Chat*callDisImage        callDis              widgetDefault
        set iconCall       [::Theme::GetImage [option get $w callImage {}]]
        set iconCallDis    [::Theme::GetImage [option get $w callDisImage {}]]

        $wtray newbutton call  \
          -text [mc phoneMakeCall] -image $iconCall  \
          -disabledimage $iconCallDis   \
          -command [list [namespace current]::chatCall $dlgtoken]
    }
}

proc ::JivePhone::chatCall {dlgtoken} {
    set chattoken [::Chat::GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate
    set jid $chatstate(fromjid)

    DialJID $jid "DIAL"
}

#-------------------------------------------------------------------------------
