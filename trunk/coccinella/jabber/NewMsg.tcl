#  NewMsg.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the new message dialog fo the jabber part.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: NewMsg.tcl,v 1.41 2004-09-28 13:50:18 matben Exp $

package require entrycomp
package provide NewMsg 1.0


namespace eval ::Jabber::NewMsg:: {
    global  wDlgs

    ::hooks::register closeWindowHook    ::Jabber::NewMsg::CloseHook

    # Use option database for customization.
    option add *NewMsg.sendImage            send            widgetDefault
    option add *NewMsg.sendDisImage         sendDis         widgetDefault
    option add *NewMsg.quoteImage           quote           widgetDefault
    option add *NewMsg.quoteDisImage        quoteDis        widgetDefault
    option add *NewMsg.saveImage            save            widgetDefault
    option add *NewMsg.saveDisImage         saveDis         widgetDefault
    option add *NewMsg.printImage           print           widgetDefault
    option add *NewMsg.printDisImage        printDis        widgetDefault

    # Add all event hooks.
    ::hooks::register quitAppHook [list ::UI::SaveWinPrefixGeom $wDlgs(jsendmsg)]

    variable locals
    
    # Running number for unique toplevels.
    set locals(dlguid) 0
    set locals(inited) 0
    set locals(wpopupbase) ._[string range $wDlgs(jsendmsg) 1 end]_trpt
    
    # {subtype popupText entryText}
    variable transportDefs
    array set transportDefs {
	jabber      {Jabber     {Jabber (address):}}
	icq         {ICQ        {ICQ (number):}}
	aim         {AIM        {AIM:}}
	msn         {MSN        {MSN Messenger:}}
	yahoo       {Yahoo      {Yahoo Messenger:}}
	irc         {IRC        {IRC:}}
	smtp        {Email      {Mail address:}}
	x-gadugadu  {Gadu-Gadu  {Address:}}
    }
}

# Jabber::NewMsg::Init --
# 
#       Initialization that is needed once.

proc ::Jabber::NewMsg::Init { } {
    
    variable locals
    
    set locals(inited) 1
    
    # Icons.
    set locals(popupbt)     [::UI::GetIcon popupbt]
    set locals(popupbtpush) [::UI::GetIcon popupbtpush]
}

# Jabber::NewMsg::InitEach --
# 
#       Initializations that are needed each time a send dialog is created.
#       This is because the services from transports must be determined
#       dynamically.

proc ::Jabber::NewMsg::InitEach { } {
    
    variable locals
    variable transportDefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Debug 2 "Jabber::NewMsg::InitEach"
    
    # We must be indenpendent of method; agent, browse, disco.
    set trpts {}
    foreach subtype [lsort [array names transportDefs]] {
	set jids [$jstate(jlib) service gettransportjids $subtype]
	if {[llength $jids]} {
	    lappend trpts $subtype
	    set locals(servicejid,$subtype) [lindex $jids 0]
	}
    }    

    # Disco doesn't return jabber. Make sure it's first.
    set trpts [lsearch -all -not -inline $trpts jabber]
    set trpts [concat jabber $trpts]
    set locals(servicejid,jabber) $jserver(this)
    set locals(ourtransports) $trpts
    
    # Build popup defs. Keep order of transportDefs. Flatten!
    set locals(menuDefs) {}
    foreach trpt $trpts {
	eval {lappend locals(menuDefs)} $transportDefs($trpt)
    }
}

# Jabber::NewMsg::Build --
#
#       The standard send message dialog.
#
# Arguments:
#       args   ?-to jidlist -subject theSubject -quotemessage msg -time time
#              -forwardmessage msg -message msg?
#       
# Results:
#       shows window.

proc ::Jabber::NewMsg::Build {args} {
    global  this prefs wDlgs
    
    variable locals  
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::NewMsg::Build args='$args'"

    # One shot initialization (static) and dynamic initialization.
    if {!$locals(inited)} {
	Jabber::NewMsg::Init
    }
    Jabber::NewMsg::InitEach
   
    set w $wDlgs(jsendmsg)[incr locals(dlguid)]
    set locals($w,num) $locals(dlguid)
    if {[winfo exists $w]} {
	return
    }
    array set opts {
	-to             ""
	-subject        ""
	-quotemessage   ""
	-forwardmessage ""
	-time           ""
	-message        ""
    }
    array set opts $args
    set locals($w,subject) $opts(-subject)
    if {[string length $opts(-quotemessage)] > 0} {
	set quotestate "normal"
    } else {
	set quotestate "disabled"
    }
    
    # Toplevel of class NewMsg.
    ::UI::Toplevel $w -class NewMsg -usemacmainmenu 1 -macstyle documentProc
    wm title $w [mc {New Message}]
    
    # Toplevel menu for mac only.
    if {[string match "mac*" $this(platform)]} {
	$w configure -menu [::Jabber::UI::GetRosterWmenu]
    }
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4
    
    # Button part.
    set iconSend      [::Theme::GetImage [option get $w sendImage {}]]
    set iconSendDis   [::Theme::GetImage [option get $w sendDisImage {}]]
    set iconQuote     [::Theme::GetImage [option get $w quoteImage {}]]
    set iconQuoteDis  [::Theme::GetImage [option get $w quoteDisImage {}]]
    set iconSave      [::Theme::GetImage [option get $w saveImage {}]]
    set iconSaveDis   [::Theme::GetImage [option get $w saveDisImage {}]]
    set iconPrint     [::Theme::GetImage [option get $w printImage {}]]
    set iconPrintDis  [::Theme::GetImage [option get $w printDisImage {}]]
    
    set wtray $w.frall.frtop
    ::buttontray::buttontray $wtray 50
    pack $wtray -side top -fill x -padx 4 -pady 2

    $wtray newbutton send Send $iconSend $iconSendDis  \
      [list ::Jabber::NewMsg::DoSend $w]
    $wtray newbutton quote Quote $iconQuote $iconQuoteDis  \
      [list ::Jabber::NewMsg::DoQuote $w $opts(-quotemessage) $opts(-to) $opts(-time)] \
       -state $quotestate
     $wtray newbutton save Save $iconSave $iconSaveDis  \
      [list ::Jabber::NewMsg::SaveMsg $w]
    $wtray newbutton print Print $iconPrint $iconPrintDis  \
      [list ::Jabber::NewMsg::DoPrint $w]
    
    ::hooks::run buildNewMsgButtonTrayHook $wtray

    pack [frame $w.frall.divt -bd 2 -relief sunken -height 2] -fill x -side top
    
    # Address list.    
    set fradd [frame $w.frall.fradd -borderwidth 1 -relief sunken]
    pack $fradd -side top -fill x -padx 6 -pady 4
    scrollbar $fradd.ysc -command [list $fradd.can yview]
    pack $fradd.ysc -side right -fill y
    set waddcan [canvas $fradd.can -bd 0 -highlightthickness 1 \
      -yscrollcommand [list $fradd.ysc set]]
    pack $waddcan -side left -fill both -expand 1
    
    set frport [frame $fradd.can.fr -bg gray60]
    set wspacer [frame $frport.sp -height 1]
    grid $wspacer -sticky ew -columnspan 2 
    foreach n {1 2 3 4} {
	::Jabber::NewMsg::NewAddrLine $w $frport $n
    }
    ::Jabber::NewMsg::FillAddrLine $w $frport 1
    set id [$waddcan create window 0 0 -anchor nw -window $frport]
    
    # If -to option. This can have jid's with and without any resource.
    # Be careful to treat this according to the XMPP spec!

    if {$opts(-to) != ""} {
	set n 1
	foreach jid $opts(-to) {
	    if {$n > 1} {
		::Jabber::NewMsg::FillAddrLine $w $frport $n
	    }	    
	    set locals($w,addr$n) [::Jabber::JlibCmd getrecipientjid $jid]
	    incr n
	}
    }
    # Text.
    set wtxt  $w.frall.frtxt
    set wtext ${wtxt}.text
    set wysc  ${wtxt}.ysc
    
    # Subject.
    set   frsub $w.frall.frsub
    frame $frsub -borderwidth 0
    pack  $frsub -side top -fill x -padx 6 -pady 0
    label $frsub.lsub -text "[mc Subject]:" -font $fontSB -anchor e \
      -takefocus 0
    set   wsubject $frsub.esub
    entry $wsubject -textvariable [namespace current]::locals($w,subject)
    pack  $frsub.lsub -side left -padx 2
    pack  $frsub.esub -side left -padx 2 -fill x -expand 1
    
    pack [::Emoticons::MenuButton $frsub.smile -text $wtext]  \
      -side right -padx 16 -pady 0
    
    # Text.
    pack [frame $wtxt] -side top -fill both -expand 1 -padx 6 -pady 2
    text $wtext -height 8 -width 48 -wrap word \
      -borderwidth 1 -relief sunken  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns]]
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1
    if {[string match "mac*" $this(platform)]} {
	pack [frame $w.frall.pad -height 14] -side bottom
    }
    set locals($w,w)        $w
    set locals($w,wtext)    $wtext
    set locals($w,waddcan)  $waddcan
    set locals($w,wfradd)   $fradd
    set locals($w,wfrport)  $frport
    set locals($w,wspacer)  $wspacer
    set locals($w,wsubject) $wsubject
    set locals($w,finished) 0
    set locals($w,wtray)    $wtray
    
    if {[string length $opts(-forwardmessage)] > 0} {
	$wtext insert end "\nForwarded message from $opts(-to) written at $opts(-time)\n\
--------------------------------------------------------------------\n\
$opts(-forwardmessage)"
    }
    if {[string length $opts(-message)] > 0} {
	$wtext insert end $opts(-message)
    }
    
    # Fix geometry stuff after idle.
    set script [format {
	update idletasks
	set frport %s
	set waddcan %s
	set wspacer %s
	set width [winfo reqwidth $frport]
	set height [winfo reqheight $frport]
	set canwidth [winfo reqwidth $waddcan]
	set bbox [grid bbox $frport 0 1] 
	set hline [expr [lindex $bbox 3] - [lindex $bbox 0]]
	$waddcan configure -width $width -height $height -yscrollincrement $hline
    } $frport $waddcan $wspacer]
    after idle $script
    bind $frport <Configure> [list [namespace current]::AddrResize $w]
    bind $waddcan <Configure> [list [namespace current]::ResizeCan $w]
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jsendmsg)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jsendmsg)
    }
    wm minsize $w 300 260
    wm maxsize $w 1200 1000
    
    #bind $w <Destroy> [list [namespace current]::CloseDlg $w]
    wm protocol $w WM_DELETE_WINDOW [list [namespace current]::CloseDlg $w]
    
    focus $frport.addr1
}

proc ::Jabber::NewMsg::NewAddrLine {w wfr n} {
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    set fontSB [option get . fontSmallBold {}]
    
    set jidlist [$jstate(roster) getusers]
    set num $locals($w,num)
    frame $wfr.f${n} -bd 0
    entry $wfr.f${n}.trpt -width 18 -font $fontSB -bd 0 -highlightthickness 0 \
      -state disabled -textvariable [namespace current]::locals($w,poptrpt$n)
    label $wfr.f${n}.la -bd 0
    pack $wfr.f${n}.trpt -side left -fill y -anchor w
    pack $wfr.f${n}.la -side right -fill y
    
    set wentry $wfr.addr${n}
    ::entrycomp::entrycomp $wentry $jidlist -bd 0 -highlightthickness 0 \
      -textvariable [namespace current]::locals($w,addr$n) -state disabled
    
    set m [menu $locals(wpopupbase)${num}_${n} -tearoff 0]
    foreach {name desc} $locals(menuDefs) {
	$m add radiobutton -label $name -value $desc  \
	  -variable [namespace current]::locals($w,poptrpt$n)  \
	  -command [list ::Jabber::NewMsg::PopupCmd $w $n]
    }
    
    bind $wentry <Button-1> [list ::Jabber::NewMsg::ButtonInAddr $w $wfr $n]
    bind $wentry <Tab>      [list ::Jabber::NewMsg::TabInAddr $w $wfr $n]
    bind $wentry <BackSpace> "+ ::Jabber::NewMsg::BackSpaceInAddr $w $wfr $n"
    bind $wentry <Return>   [list ::Jabber::NewMsg::ReturnInAddr $w $wfr $n]
    bind $wentry <Key-Up>   [list ::Jabber::NewMsg::KeyUpDown -1 $w $wfr $n]
    bind $wentry <Key-Down> [list ::Jabber::NewMsg::KeyUpDown 1 $w $wfr $n]
    
    grid $wfr.f${n} -padx 1 -pady 1 -column 0 -row $n -sticky news
    grid $wentry -padx 1 -pady 1 -column 1 -row $n -sticky news
    grid columnconfigure $wfr 1 -weight 1
    grid rowconfigure $wfr $n -minsize 16
    set locals($w,addrline) $n
}

proc ::Jabber::NewMsg::FillAddrLine {w wfr n} {
    
    variable locals
    variable transportDefs
    
    $wfr.f${n}.la configure -image $locals(popupbt) -bg #adadad
    $wfr.addr${n} configure -state normal
    
    bind $wfr.f${n}.la <Button-1> [list ::Jabber::NewMsg::TrptPopup $w $n %X %Y]
    bind $wfr.f${n}.la <ButtonRelease-1> [list ::Jabber::NewMsg::TrptPopupRelease $w $n]
    set locals($w,fillline) $n
    set locals($w,poptrpt$n) [lindex $transportDefs(jabber) 1]
}

proc ::Jabber::NewMsg::ButtonInAddr {w wfr n} {
    
    variable locals
    
    if {$n > $locals($w,fillline)} {
	set new [expr $locals($w,fillline) + 1]
	::Jabber::NewMsg::FillAddrLine $w $wfr $new
	focus $wfr.addr$new
    }
}

proc ::Jabber::NewMsg::TabInAddr {w wfr n} {
    
    variable locals
 
    set can $locals($w,waddcan)
    set wsubject $locals($w,wsubject)

    # If last line then insert new line.
    if {$n == $locals($w,addrline)} {
	::Jabber::NewMsg::NewAddrLine $w $wfr [expr $n + 1]
	if {$n >= 4} {
	    ::Jabber::NewMsg::FillAddrLine $w $wfr [expr $n + 1]
	}
	update idletasks
	focus "$wfr.addr[expr $n + 1]"
	::Jabber::NewMsg::SeeLine $w [expr $n + 1]
    } else {
	focus $wsubject
    }
}

#       If last line, fill a new one, else set focus to the one below.
#       Crete new line if not there.

proc ::Jabber::NewMsg::ReturnInAddr {w wfr n} {
    
    variable locals
    
    if {$n == $locals($w,fillline)} {
	set new [expr $locals($w,fillline) + 1]

	# If last line then insert new line.
	if {$n == $locals($w,addrline)} {
	    ::Jabber::NewMsg::NewAddrLine $w $wfr $new
	}
	::Jabber::NewMsg::FillAddrLine $w $wfr $new
	focus $wfr.addr$new
    } elseif {$n < $locals($w,fillline)} {
	focus $wfr.addr[expr $n + 1]
    }
    ::Jabber::NewMsg::SeeLine $w [expr $n + 1]
}

#       Remove this line if empty and shift all lines below up.

proc ::Jabber::NewMsg::BackSpaceInAddr {w wfr n} {
    
    variable locals
    
    # Don't do anything if first line.
    if {$n == 1} {
	return
    }
    if {[string length $locals($w,addr$n)] == 0} {
	
	# Shift all lines below this one up one step, empty last one,
	# and if more than 4 lines, delete it completely.
	set last $locals($w,fillline)
	if {$n > 1} {
	    focus "$wfr.addr[expr $n - 1]"
	}
	for {set i $n} {$i < $last} {incr i} {
	    set to $i
	    set from [expr $i + 1]
	    set locals($w,poptrpt$to) $locals($w,poptrpt$from)
	    set locals($w,addr$to) $locals($w,addr$from)
	}	
	::Jabber::NewMsg::EmptyAddrLine $w $wfr $last
	if {$last > 4} {
	    # Can't make it work :-(
	    #after idle ::Jabber::NewMsg::DeleteLastAddrLine $w $wfr
	}
    }
}

proc ::Jabber::NewMsg::EmptyAddrLine {w wfr n} {
    
    variable locals
    
    $wfr.f${n}.la configure -image {}
    $wfr.addr${n} configure -state disabled
    set locals($w,poptrpt$n) {}
    set locals($w,addr$n) {}
    set locals($w,fillline) [expr $n - 1]
    bind $wfr.f${n}.la <Button-1> {}
    bind $wfr.f${n}.la <ButtonRelease-1> {}    
}

proc ::Jabber::NewMsg::DeleteLastAddrLine {w wfr} {
    
    variable locals
    
    set n $locals($w,addrline)
    set num $locals($w,num)
    eval {grid forget} [grid slaves $wfr -row $n]
    destroy $wfr.f${n}
    destroy $wfr.f${n}.trpt
    destroy $wfr.f${n}.la
    destroy $wfr.addr${n}
    destroy $locals(wpopupbase)${num}_${n}
}

proc ::Jabber::NewMsg::SeeLine {w n} {
    
    variable locals

    set totlines $locals($w,addrline)
    set can $locals($w,waddcan)
    set top [expr [lindex [$can yview] 0] * $totlines + 1]
    set bot [expr $top + 3]

    if {$n > $bot} {
	$can yview moveto [expr ($n - 4.0)/$totlines]
    } elseif {$n < $top} {
	$can yview moveto [expr ($n - 1.0)/$totlines]
    }
}

proc ::Jabber::NewMsg::KeyUpDown {updown w wfr n} {
    
    variable locals

    set newfocus [expr $n + $updown]
    if {$newfocus < 1} {
	set newfocus 1
    } elseif {$newfocus > $locals($w,fillline)} {
	set newfocus $locals($w,fillline)
    }
    focus $wfr.addr$newfocus
    ::Jabber::NewMsg::SeeLine $w $newfocus
}

proc ::Jabber::NewMsg::PopupCmd {w n} {
    
    variable locals
    upvar ::Jabber::jserver jserver
    
    set num     $locals($w,num)
    set wfrport $locals($w,wfrport)
    set pick    $locals($w,poptrpt$n)

    # Seems to be necessary to achive any selection.
    set wentry $wfrport.addr${n}
    focus $wentry

    switch -glob -- $pick {
	*Jabber* {
	    set locals($w,addr$n) "userName@$locals(servicejid,jabber)"
	}
	*AIM* {
	    set locals($w,addr$n) "usersName@$locals(servicejid,aim)"
	    
	}
	*Yahoo* {
	    set locals($w,addr$n) "usersName@$locals(servicejid,yahoo)"
	}
	*ICQ* {
	    set locals($w,addr$n) "screeNumber@$locals(servicejid,icq)"
	}
	*MSN* {
	    set locals($w,addr$n) "userName%hotmail.com@$locals(servicejid,msn)"
	}
	default {
	    set locals($w,addr$n) ""
	}
    }
    set ind [string first @ $locals($w,addr$n)]
    if {$ind > 0} {
	$wentry selection range 0 $ind
    }
}

#       Callback for the Configure scrollable canvas.

proc ::Jabber::NewMsg::ResizeCan {w } {
    
    variable locals
 
    set can $locals($w,waddcan)
    set wspacer $locals($w,wspacer)
    set canwidth [winfo width $can]
    $wspacer configure -width [expr $canwidth - 2]
}

#       Callback for the Configure address frame.

proc ::Jabber::NewMsg::AddrResize {w} {
    
    variable locals
 
    set can $locals($w,waddcan)
    set form $locals($w,wfrport)
    set bbox [$can bbox all]
    set width [winfo width $form]
    $can configure -scrollregion $bbox
}

# Post popup menu.

proc ::Jabber::NewMsg::TrptPopup {w n x y} {
    global  this
    
    variable locals

    set num $locals($w,num)
    set wfr $locals($w,wfrport)
    set ind 0
    if {$ind > 0} {
	set ind [expr ($ind - 1)/2]
    } else {
	set ind 0
    }
    
    # For some reason does we never get a ButtonRelease event here.
    if {![string equal $this(platform) "unix"]} {
	$wfr.f${n}.la configure -image $locals(popupbtpush)
    }
    #tk_popup $locals(wpopupbase)${num}_${n} [expr int($x)] [expr int($y)] $ind
    tk_popup $locals(wpopupbase)${num}_${n} [expr int($x)] [expr int($y)]
}

proc ::Jabber::NewMsg::TrptPopupRelease {w n} {
    
    variable locals

    set wfr $locals($w,wfrport)
    $wfr.f${n}.la configure -image $locals(popupbt)
}

# Jabber::NewMsg::DoSend --
#
#       Send the message. Validate addresses in address list.

proc ::Jabber::NewMsg::DoSend {w} {
    global  prefs wDlgs
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	tk_messageBox -type ok -icon error -parent $w \
	  -title [mc {Not Connected}] \
	  -message [mc jamessnotconnected]
	return
    }
    
    # Loop through address list. 
    set addrList {}
    for {set i 1} {$i <= $locals($w,addrline)} {incr i} {
	set addr $locals($w,addr$i)
	if {[string length $addr] > 0} {
	    if {![jlib::jidvalidate $addr]} {
		if {$locals($w,addrline) > 1} {
		    set msg [mc jamessskipsendq $addr]
		    set type yesnocancel
		} else {
		    set msg [mc jamessillformresend $addr]
		    set type ok
		}
		set ans [tk_messageBox -type $type -parent $w \
		  -message [FormatTextForMessageBox $msg]]
		if {$ans == "yes"} {
		    continue
		} elseif {$ans == "no"} {
		    return
		} elseif {$ans == "cancel"} {
		    return
		} elseif {$ans == "ok"} {
		    return
		}
	    }
	    lappend addrList $addr
	}
    }
    
    # Be sure there are at least one jid.
    if {[llength $addrList] == 0} {
	tk_messageBox -title [mc {No Address}]  \
	  -icon error -type ok -parent $w \
	  -message [FormatTextForMessageBox [mc jamessaddrmiss]]
	return
    }
    set wtext $locals($w,wtext)
    set allText [::Text::TransformToPureText $wtext]
    
    if {[string length $locals($w,subject)] > 0} {
	set subopt [list -subject $locals($w,subject)]
    } else {
	set subopt {}
    }
    if {[string length $allText]} {
	foreach jid $addrList {
	    eval {::Jabber::JlibCmd send_message $jid} $subopt {-body $allText}
	}
    }
    set locals($w,finished) 1
    ::UI::SaveWinGeom $wDlgs(jsendmsg) $w
    destroy $w
}

proc ::Jabber::NewMsg::DoQuote {w message to time} {
    
    variable locals
    upvar ::Jabber::jstate jstate

    set wtext $locals($w,wtext)
    regsub -all "\n" $message "\n> " quoteMsg
    set quoteMsg "\nAt $time, $to wrote:\n> $quoteMsg"
    $wtext insert end $quoteMsg
    $wtext insert end \n
    
    # Quote only once.
    $locals($w,wtray) buttonconfigure quote -state disabled
}

proc ::Jabber::NewMsg::SaveMsg {w} {
    global this
    
    variable locals
    
    set wtext $locals($w,wtext)
    set ans [tk_getSaveFile -title [mc {Save Message}] \
      -initialfile Untitled.txt]
    if {[string length $ans]} {
	set allText [::Text::TransformToPureText $wtext]
	set fd [open $ans w]
	for {set i 1} {$i <= $locals($w,addrline)} {incr i} {
	    set addr $locals($w,addr$i)
	    if {[string length $addr] > 0} {
		puts $fd "To:     \t$addr"
	    }
	}
	puts $fd "Subject:\t$locals($w,subject)"
	puts $fd "\n"
	puts $fd $allText	
	close $fd
	if {[string equal $this(platform) "macintosh"]} {
	    file attributes $ans -type TEXT -creator ttxt
	}
    }
}

proc ::Jabber::NewMsg::DoPrint {w} {
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    set fontS [option get . fontSmall {}]
    
    set allText [::Text::TransformToPureText $locals($w,wtext)]    
    ::UserActions::DoPrintText $locals($w,wtext)  \
      -data $allText -font $fontS    
}

proc ::Jabber::NewMsg::CloseHook {wclose} {
    global  wDlgs
    variable locals
	
    if {[string match $wDlgs(jsendmsg)* $wclose]} {
	::Jabber::NewMsg::CloseDlg $wclose
    }   
}

proc ::Jabber::NewMsg::CloseDlg {w} {
    global  wDlgs
    variable locals
    
    set wtext $locals($w,wtext)
    set allText [$wtext get 1.0 "end - 1 char"]
    set doDestroy 0
    if {[string length $allText] > 0} {
	set ans [tk_messageBox -title [mc {To Send or Not}]  \
	  -icon warning -type yesnocancel -default "no" -parent $w \
	  -message [mc jamesssavemsg]]
	if {$ans == "yes"} {
	    set ansFile [tk_getSaveFile -title [mc {Save Message}] \
		-initialfile Untitled.txt]
	    if {[string length $ansFile] > 0} {
		set doDestroy 1
	    }
	} elseif {$ans == "no"} {
	    set doDestroy 1
	} elseif {$ans == "cancel"} {
	}
    } else {
	set doDestroy 1
    }
    if {$doDestroy} {
	::UI::SaveWinGeom $wDlgs(jsendmsg) $w
	array unset locals $w,*
	destroy $w
    }
}

proc ::Jabber::NewMsg::GetAllCCP { } {
    
    variable locals
    
    set res {}
    foreach key [array names locals "*,wccp"] {
	if {[winfo exists $locals($key)]} {
	    lappend res $locals($key)
	}
    }
    return $res
}

proc ::Jabber::NewMsg::GetCCP {w} {
    
    variable locals
    
    if {[info exists locals($w,wccp)]} {
	return $locals($w,wccp)
    } else {
	return {}
    }
}

#-------------------------------------------------------------------------------
