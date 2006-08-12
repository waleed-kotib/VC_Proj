#  NewMsg.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the new message dialog fo the jabber part.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: NewMsg.tcl,v 1.74 2006-08-12 13:48:25 matben Exp $

package require ui::entryex

package provide NewMsg 1.0

namespace eval ::NewMsg:: {
    global this

    # Add all event hooks.
    ::hooks::register quitAppHook        ::NewMsg::QuitAppHook

    # Use option database for customization.
    option add *NewMsg.buttonRowSide        left            widgetDefault
    option add *NewMsg.buttonRowPosition    top             widgetDefault
    option add *NewMsg.topBannerImage       ""              widgetDefault
    option add *NewMsg.bottomBannerImage    ""              widgetDefault

    option add *NewMsg.sendImage            send            widgetDefault
    option add *NewMsg.sendDisImage         sendDis         widgetDefault
    option add *NewMsg.quoteImage           quote           widgetDefault
    option add *NewMsg.quoteDisImage        quoteDis        widgetDefault
    option add *NewMsg.saveImage            save            widgetDefault
    option add *NewMsg.saveDisImage         saveDis         widgetDefault
    option add *NewMsg.printImage           print           widgetDefault
    option add *NewMsg.printDisImage        printDis        widgetDefault

    # Standard widgets.
    
    if {[tk windowingsystem] eq "aqua"} {
	option add *NewMsg*box.padding            {12 10 12 18}   50
    } else {
	option add *NewMsg*box.padding            {10  8 10  8}   50
    }
    option add *NewMsg*frsub.padding              {12  4 12  4}   50
    option add *NewMsg*TMenubutton.padding        {1}             50
    option add *NewMsg*Text.borderWidth           0               50
    option add *NewMsg*Text.relief                flat            50

    option add *JMultiAddress.background        "#999999"         60

    # Specials.
    option add *JMultiAddress.entry1Background  white             20
    option add *JMultiAddress.entry1Foreground  "#333333"         20
    option add *JMultiAddress.entry2Background  white             20
    option add *JMultiAddress.entry2Foreground  black             20
    option add *JMultiAddress.entry3Background  white             20
    option add *JMultiAddress.entry4Background  white             20
    option add *JMultiAddress.popup1Background  "#adadad"         20
    option add *JMultiAddress.popup2Background  "#dedede"         20

    switch -- $this(platform) {
	windows {
	    option add *JMultiAddress.popupImage      xppopupbt  20
	    option add *JMultiAddress.popupImageDown  xppopupbt  20
	}
	default {
	    option add *JMultiAddress.popupImage      reliefpopupbt      20
	    option add *JMultiAddress.popupImageDown  reliefpopupbtpush  20
	}
    }
    variable locals
    
    # Running number for unique toplevels.
    set locals(dlguid) 0
    set locals(inited) 0
    set locals(initedaddr) 0
    
    # {subtype popupText entryText}
    variable transportDefs
    array set transportDefs {
	jabber      {Jabber     {Jabber ID:}          }
	icq         {ICQ        {ICQ number:}         }
	aim         {AIM        {AIM:}                }
	msn         {MSN        {MSN:}                }
	yahoo       {Yahoo      {Yahoo:}              }
	irc         {IRC        {IRC:}                }
	smtp        {Email      {Email address, @->%:}}
	x-gadugadu  {Gadu-Gadu  {Address:}            }
    }
}

# NewMsg::Init --
# 
#       Initialization that is needed once.

proc ::NewMsg::Init {} {
    
    variable locals
    
    set locals(inited) 1
    # empty...
    
}

# NewMsg::InitEach --
# 
#       Initializations that are needed each time a send dialog is created.
#       This is because the services from transports must be determined
#       dynamically.

proc ::NewMsg::InitEach { } {
    
    variable locals
    variable transportDefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Debug 2 "NewMsg::InitEach"
    
    set trpts {}
    foreach subtype [lsort [array names transportDefs]] {
	set jids [$jstate(jlib) disco getjidsforcategory "gateway/$subtype"]
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
    
    # Build popup defs. Keep order of transportDefs.
    set locals(menuDefs) {}
    foreach trpt $trpts {
	lappend locals(menuDefs) $trpt [lindex $transportDefs($trpt) 0]
    }
}

proc ::NewMsg::InitMultiAddress {wmulti} {
    
    variable locals
    
    # Icons.
    set locals(popupbt)     [::Theme::GetImage [option get $wmulti popupImage {}]]
    set locals(popupbtpush) [::Theme::GetImage [option get $wmulti popupImageDown {}]]
    set locals(minheight) [image height $locals(popupbt)]
    set locals(initedaddr) 1
}

# NewMsg::Build --
#
#       The standard send message dialog.
#
# Arguments:
#       args   ?-to jid -subject theSubject -quotemessage msg -time time
#              -forwardmessage msg -message msg -tolist jidlist?
#       
# Results:
#       shows window.

proc ::NewMsg::Build {args} {
    global  this prefs wDlgs
    
    variable locals  
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::NewMsg::Build args='$args'"

    # One shot initialization (static) and dynamic initialization.
    if {!$locals(inited)} {
	NewMsg::Init
    }
    NewMsg::InitEach
   
    set w $wDlgs(jsendmsg)[incr locals(dlguid)]
    set locals($w,num) $locals(dlguid)
    if {[winfo exists $w]} {
	return
    }
    array set opts {
	-to             ""
	-tolist         ""
	-subject        ""
	-quotemessage   ""
	-forwardmessage ""
	-time           ""
	-message        ""
    }
    array set opts $args
    set locals($w,subject) $opts(-subject)
    if {$opts(-quotemessage) == ""} {
	set quotestate "disabled"
    } else {
	set quotestate "normal"
    }
    
    # Toplevel of class NewMsg.
    ::UI::Toplevel $w -class NewMsg \
      -usemacmainmenu 1 -macstyle documentProc -closecommand ::NewMsg::CloseHook
    wm title $w [mc {New Message}]
    
    # Toplevel menu for mac only.
    if {[string match "mac*" $this(platform)]} {
	$w configure -menu [::Jabber::UI::GetRosterWmenu]
    }
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    # Button part.
    set iconSend      [::Theme::GetImage [option get $w sendImage {}]]
    set iconSendDis   [::Theme::GetImage [option get $w sendDisImage {}]]
    set iconQuote     [::Theme::GetImage [option get $w quoteImage {}]]
    set iconQuoteDis  [::Theme::GetImage [option get $w quoteDisImage {}]]
    set iconSave      [::Theme::GetImage [option get $w saveImage {}]]
    set iconSaveDis   [::Theme::GetImage [option get $w saveDisImage {}]]
    set iconPrint     [::Theme::GetImage [option get $w printImage {}]]
    set iconPrintDis  [::Theme::GetImage [option get $w printDisImage {}]]

    set buttonRowPosition [option get $w buttonRowPosition {}]
    set buttonRowSide     [option get $w buttonRowSide {}]
    set topBannerImage    [::Theme::GetImage [option get $w topBannerImage {}]]
    set botBannerImage    [::Theme::GetImage [option get $w bottomBannerImage {}]]
    
    switch -- $buttonRowSide {
	right {
	    set buttonAnchor e
	}
	left {
	    set buttonAnchor w
	}
	default {
	    set buttonAnchor c
	}
    }

    set wtop $w.frall.top
    set wbot $w.frall.bot
    ttk::frame $wtop
    ttk::frame $wbot
    pack $wtop -side top -fill x
    pack $wbot -side bottom -fill x
    
    switch -- $buttonRowPosition {
	top {
	    set wtray $wtop.tray
	    ::ttoolbar::ttoolbar $wtray
	    pack $wtray -side $buttonRowSide -fill y
	    if {$topBannerImage == ""} {
		pack $wtray -fill both -expand 1
	    }
	}
	bottom {
	    set wtray $wbot.tray
	    ::ttoolbar::ttoolbar $wtray
	    pack $wtray -side $buttonRowSide -fill y
	    if {$botBannerImage == ""} {
		pack $wtray -fill both -expand 1
	    }
	}
    }
    if {$topBannerImage != ""} {
	ttk::label $wtop.banner -anchor $buttonAnchor -image $topBannerImage
	pack  $wtop.banner -side $buttonRowSide -fill x -expand 1
    }
    if {$botBannerImage != ""} {
	ttk::label $wbot.banner -anchor $buttonAnchor -image $botBannerImage
	pack  $wbot.banner -side $buttonRowSide -fill x -expand 1
    }

    $wtray newbutton send  -text [mc Send]  \
      -image $iconSend -disabledimage $iconSendDis  \
      -command [list ::NewMsg::DoSend $w]
    $wtray newbutton quote -text [mc Quote]  \
      -image $iconQuote -disabledimage $iconQuoteDis  \
      -command [list ::NewMsg::DoQuote $w $opts(-quotemessage) $opts(-to) $opts(-time)] \
      -state $quotestate
    $wtray newbutton save  -text [mc Save]  \
      -image $iconSave -disabledimage $iconSaveDis  \
      -command [list ::NewMsg::SaveMsg $w]
    $wtray newbutton print -text [mc Print]  \
      -image $iconPrint -disabledimage $iconPrintDis  \
      -command [list ::NewMsg::DoPrint $w]
    
    ::hooks::run buildNewMsgButtonTrayHook $wtray

    # D =
    ttk::separator $w.frall.divt -orient horizontal
    pack $w.frall.divt -side top -fill x
    
    # D =
    set wbox $w.frall.box
    ttk::frame $wbox
    pack $wbox -side top -fill both -expand 1
    
    # Address list. D =
    set   fradd $wbox.fradd
    frame $fradd
    pack $fradd -side top -fill x 
    ttk::scrollbar $fradd.ysc -command [list $fradd.can yview]
    pack $fradd.ysc -side right -fill y
    set waddcan $fradd.can
    canvas $waddcan -bd 0 -highlightthickness 1 \
      -yscrollcommand [list $fradd.ysc set]
    pack $waddcan -side left -fill both -expand 1
    
    # Make new class since easier to set resources. 
    # D = -bg gray60
    set waddr $fradd.can.fr
    frame $waddr -class JMultiAddress
    set bg [$waddr cget -bg]
    set wspacer [frame $waddr.sp -height 1 -bg $bg]
    grid $wspacer -sticky ew -columnspan 2
    if {!$locals(initedaddr)} { 
	InitMultiAddress $waddr
    }
    set nmaxlines 4
    for {set n 1} {$n <= $nmaxlines} {incr n} {
	NewAddrLine $w $waddr $n
    }
    FillAddrLine $w $waddr 1
    set id [$waddcan create window 0 0 -anchor nw -window $waddr]
            
    # Text.
    set wtxt  $wbox.frtxt
    set wtext $wtxt.text
    set wysc  $wtxt.ysc
    
    # Subject.
    set   frsub $wbox.frsub
    set   wsubject $frsub.esub
    # D =
    ttk::frame $frsub
    pack  $frsub -side top -fill x
    ttk::label $frsub.lsub -style Small.TLabel \
      -text "[mc Subject]:" -anchor e -takefocus 0 -padding {2 0}
    ttk::entry $wsubject -font CociSmallFont \
      -textvariable [namespace current]::locals($w,subject)
    pack  $frsub.lsub -side left
    pack  $frsub.esub -side left -fill x -expand 1 -padx 6
    pack  [::Emoticons::MenuButton $frsub.smile -text $wtext] -side right
    pack  [ttk::frame $frsub.space] -side right
    
    # Text.
    frame $wtxt -bd 1 -relief sunken
    pack  $wtxt -side top -fill both -expand 1
    text $wtext -height 8 -width 48 -wrap word \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns]]
    ttk::scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid  $wtext  -column 0 -row 0 -sticky news
    grid  $wysc   -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1

    set locals($w,w)        $w
    set locals($w,wtext)    $wtext
    set locals($w,waddcan)  $waddcan
    set locals($w,wfradd)   $fradd
    set locals($w,wfrport)  $waddr
    set locals($w,wspacer)  $wspacer
    set locals($w,wsubject) $wsubject
    set locals($w,finished) 0
    set locals($w,wtray)    $wtray
    
    if {$opts(-forwardmessage) != ""} {
	$wtext insert end "\nForwarded message from $opts(-to) written at $opts(-time)\n\
--------------------------------------------------------------------\n\
$opts(-forwardmessage)"
    }
    if {$opts(-message) != ""} {
	$wtext insert end $opts(-message)
    }
    
    # Fix geometry stuff after idle.
    set script [format {
	update idletasks
	set waddr %s
	set waddcan %s
	set wspacer %s
	set width  [winfo reqwidth $waddr]
	set height [winfo reqheight $waddr]
	set canwidth [winfo reqwidth $waddcan]
	set bbox [grid bbox $waddr 0 1] 
	set hline [expr [lindex $bbox 3] - [lindex $bbox 0]]
	$waddcan configure -width $width -height $height -yscrollincrement $hline
    } $waddr $waddcan $wspacer]
    after idle $script
    bind $waddr   <Configure> [list [namespace current]::AddrResize $w]
    bind $waddcan <Configure> [list [namespace current]::ResizeCan $w]
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jsendmsg)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jsendmsg)
    }
    wm minsize $w 300 260
    wm maxsize $w 1200 1000
    
    bind $w <$this(modkey)-Return> \
      [list [namespace current]::CommandReturnKeyPress $w]
    wm protocol $w WM_DELETE_WINDOW [list [namespace current]::CloseDlg $w]
    
    focus $waddr.addr1
    
    # We need to fill in addresses after the geometry handling!
    if {[llength $opts(-tolist)]} {
	set jidlist $opts(-tolist)
    } elseif {$opts(-to) ne ""} {
	set jidlist [list $opts(-to)]
    } else {
	set jidlist {}
    }
    if {[llength $jidlist]} {
	after 200 [list ::NewMsg::FillInAddresses $w $jidlist]
    }
}

proc ::NewMsg::FillInAddresses {w jidlist} {
    variable locals
    variable transportDefs
    upvar ::Jabber::jstate jstate
    
    # If -tolist option. This can have jid's with and without any resource.
    # Be careful to treat this according to the XMPP spec!

    foreach {key value} [array get locals servicejid,*] {
	set type [lindex [split $key ,] 1]
	set host2type($value) $type
    }
    set waddr $locals($w,wfrport)
    set n 1
    foreach jid $jidlist {
	if {$n > 4} {
	    NewAddrLine $w $waddr $n
	}
	if {$n > 1} {
	    FillAddrLine $w $waddr $n
	}	    
	set locals($w,addr$n) [$jstate(jlib) getrecipientjid $jid]
	
	# Set popup if transport.
	jlib::splitjidex $jid node host res
	if {[info exists host2type($host)]} {
	    set type $host2type($host)
	    set locals($w,poptrpt$n) $type
	    set locals($w,enttrpt$n) [lindex $transportDefs($type) 1]
	}
	incr n
    }
}

proc ::NewMsg::NewAddrLine {w wfr n} {
    global  wDlgs
    variable locals
    upvar ::Jabber::jstate jstate
    
    set bg1   [option get $wfr entry1Background {}]
    set fg1   [option get $wfr entry1Foreground {}]
    set bg2   [option get $wfr entry2Background {}]
    set fg2   [option get $wfr entry2Foreground {}]
    set bg3   [option get $wfr entry3Background {}]
    set bg4   [option get $wfr entry4Background {}]
    set bgpop [option get $wfr popup2Background {}]
    
    set locals(wpopupbase) ._[string range $wDlgs(jsendmsg) 1 end]_trpt
    
    set jidlist [$jstate(jlib) roster getusers]
    set num $locals($w,num)
    frame $wfr.f$n -bd 0
    entry $wfr.f$n.trpt -width 18 -bd 0 -highlightthickness 0 \
      -state disabled -textvariable [namespace current]::locals($w,enttrpt$n) \
      -disabledforeground $fg1 -disabledbackground $bg3
    label $wfr.f$n.la -bd 0 -bg $bgpop
    pack  $wfr.f$n.trpt -side left -fill y -anchor w
    pack  $wfr.f$n.la -side right -fill both -expand 1
    
    set wentry $wfr.addr$n
    ui::entryex $wentry -type tk  \
      -library $jidlist -bd 0 -highlightthickness 0 \
      -textvariable [namespace current]::locals($w,addr$n) -state disabled \
      -bg $bg2 -fg $fg2 -disabledbackground $bg4
    
    set m [menu $locals(wpopupbase)${num}_${n} -tearoff 0]
    foreach {type name} $locals(menuDefs) {
	$m add radiobutton -label $name -value $type  \
	  -variable [namespace current]::locals($w,poptrpt$n)  \
	  -command [list ::NewMsg::PopupCmd $w $n]
    }
    
    bind $wentry <Button-1>   [list ::NewMsg::ButtonInAddr $w $wfr $n]
    bind $wentry <Tab>        [list ::NewMsg::TabInAddr $w $wfr $n]
    bind $wentry <BackSpace> +[list ::NewMsg::BackSpaceInAddr $w $wfr $n]
    bind $wentry <Return>     [list ::NewMsg::ReturnInAddr $w $wfr $n]
    bind $wentry <Key-Up>     [list ::NewMsg::KeyUpDown -1 $w $wfr $n]
    bind $wentry <Key-Down>   [list ::NewMsg::KeyUpDown 1 $w $wfr $n]
    
    grid  $wfr.f$n  -padx 1 -pady 1 -column 0 -row $n -sticky news
    grid  $wentry   -padx 1 -pady 1 -column 1 -row $n -sticky news
    grid columnconfigure $wfr 1 -weight 1
    grid rowconfigure $wfr $n -minsize [expr $locals(minheight) + 2]
    set locals($w,addrline) $n
}

proc ::NewMsg::FillAddrLine {w wfr n} {
    
    variable locals
    variable transportDefs
    
    set bg1   [option get $wfr entry1Background {}]
    set bgpop [option get $wfr popup1Background {}]

    $wfr.f${n}.trpt configure -disabledbackground $bg1
    # D = -bg #adadad
    $wfr.f${n}.la configure -image $locals(popupbt) -bg $bgpop
    $wfr.addr${n} configure -state normal
    
    bind $wfr.f${n}.la <Button-1> [list ::NewMsg::TrptPopup $w $n %X %Y]
    bind $wfr.f${n}.la <ButtonRelease-1> [list ::NewMsg::TrptPopupRelease $w $n]
    set locals($w,fillline) $n
    set locals($w,poptrpt$n) jabber
    set locals($w,enttrpt$n) [lindex $transportDefs(jabber) 1]
}

proc ::NewMsg::ButtonInAddr {w wfr n} {
    
    variable locals
    
    if {$n > $locals($w,fillline)} {
	set new [expr $locals($w,fillline) + 1]
	FillAddrLine $w $wfr $new
	focus $wfr.addr$new
    }
}

proc ::NewMsg::TabInAddr {w wfr n} {
    
    variable locals
 
    set can $locals($w,waddcan)
    set wsubject $locals($w,wsubject)

    # If last line then insert new line.
    if {$n == $locals($w,addrline)} {
	NewAddrLine $w $wfr [expr $n + 1]
	if {$n >= 4} {
	    FillAddrLine $w $wfr [expr $n + 1]
	}
	update idletasks
	focus "$wfr.addr[expr $n + 1]"
	SeeLine $w [expr $n + 1]
    } else {
	focus $wsubject
    }
}

#       If last line, fill a new one, else set focus to the one below.
#       Crete new line if not there.

proc ::NewMsg::ReturnInAddr {w wfr n} {
    
    variable locals
    
    if {$n == $locals($w,fillline)} {
	set new [expr $locals($w,fillline) + 1]

	# If last line then insert new line.
	if {$n == $locals($w,addrline)} {
	    NewAddrLine $w $wfr $new
	}
	FillAddrLine $w $wfr $new
	focus $wfr.addr$new
    } elseif {$n < $locals($w,fillline)} {
	focus $wfr.addr[expr $n + 1]
    }
    SeeLine $w [expr $n + 1]
}

#       Remove this line if empty and shift all lines below up.

proc ::NewMsg::BackSpaceInAddr {w wfr n} {
    
    variable locals
    
    # Don't do anything if first line.
    if {$n == 1} {
	return
    }
    if {$locals($w,addr$n) == ""} {
	
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
	EmptyAddrLine $w $wfr $last
	if {$last > 4} {
	    # Can't make it work :-(
	    #after idle ::NewMsg::DeleteLastAddrLine $w $wfr
	}
    }
}

proc ::NewMsg::EmptyAddrLine {w wfr n} {
    
    variable locals
    
    set bg3 [option get $wfr entry3Background {}]
    set bgpop [option get $wfr popup2Background {}]

    $wfr.f$n.trpt configure -disabledbackground $bg3
    $wfr.f$n.la configure -image "" -bg $bgpop
    $wfr.addr$n configure -state disabled
    set locals($w,poptrpt$n) ""
    set locals($w,addr$n) ""
    set locals($w,enttrpt$n) ""
    set locals($w,fillline) [expr $n - 1]
    bind $wfr.f$n.la <Button-1> {}
    bind $wfr.f$n.la <ButtonRelease-1> {}    
}

proc ::NewMsg::DeleteLastAddrLine {w wfr} {
    
    variable locals
    
    set n $locals($w,addrline)
    set num $locals($w,num)
    eval {grid forget} [grid slaves $wfr -row $n]
    destroy $wfr.f$n
    destroy $wfr.f$n.trpt
    destroy $wfr.f$n.la
    destroy $wfr.addr$n
    destroy $locals(wpopupbase)${num}_$n
}

proc ::NewMsg::SeeLine {w n} {
    
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

proc ::NewMsg::KeyUpDown {updown w wfr n} {
    
    variable locals

    set newfocus [expr $n + $updown]
    if {$newfocus < 1} {
	set newfocus 1
    } elseif {$newfocus > $locals($w,fillline)} {
	set newfocus $locals($w,fillline)
    }
    focus $wfr.addr$newfocus
    SeeLine $w $newfocus
}

proc ::NewMsg::PopupCmd {w n} {
    
    variable locals
    variable transportDefs
    upvar ::Jabber::jserver jserver
    
    set num     $locals($w,num)
    set wfrport $locals($w,wfrport)
    set trpt    $locals($w,poptrpt$n)
    if {[info exists transportDefs($trpt)]} {
	set locals($w,enttrpt$n) [lindex $transportDefs($trpt) 1]
    }
    
    # Seems to be necessary to achive any selection.
    set wentry $wfrport.addr$n
    focus $wentry

    switch -- $trpt {
	jabber {
	    set locals($w,addr$n) "userName@$locals(servicejid,jabber)"
	}
	aim {
	    set locals($w,addr$n) "usersName@$locals(servicejid,aim)"
	}
	yahoo {
	    set locals($w,addr$n) "usersName@$locals(servicejid,yahoo)"
	}
	icq {
	    set locals($w,addr$n) "screeNumber@$locals(servicejid,icq)"
	}
	msn {
	    set locals($w,addr$n) "userName%hotmail.com@$locals(servicejid,msn)"
	}
	email - smtp {
	    set locals($w,addr$n) "userName%emailserver@$locals(servicejid,smtp)"
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

proc ::NewMsg::ResizeCan {w} {
    
    variable locals
 
    set can     $locals($w,waddcan)
    set waddr   $locals($w,wfrport)
    set wspacer $locals($w,wspacer)
    set width [expr [winfo width $can] - 2*[$waddr cget -padx] - \
      2*[$can cget -highlightthickness]]
    $wspacer configure -width $width
}

#       Callback for the Configure address frame.

proc ::NewMsg::AddrResize {w} {
    
    variable locals
 
    set can   $locals($w,waddcan)
    set waddr $locals($w,wfrport)
    set bbox [$can bbox all]
    set width [winfo width $waddr]
    $can configure -scrollregion $bbox
}

# Post popup menu.

proc ::NewMsg::TrptPopup {w n x y} {
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
    
    # For some reason we do never get a ButtonRelease event here.
    if {![string equal $this(platform) "unix"]} {
	$wfr.f${n}.la configure -image $locals(popupbtpush)
    }
    #tk_popup $locals(wpopupbase)${num}_${n} [expr int($x)] [expr int($y)] $ind
    tk_popup $locals(wpopupbase)${num}_${n} [expr int($x)] [expr int($y)]
}

proc ::NewMsg::TrptPopupRelease {w n} {
    
    variable locals

    set wfr $locals($w,wfrport)
    $wfr.f${n}.la configure -image $locals(popupbt)
}

proc ::NewMsg::CommandReturnKeyPress {w} {
    
    DoSend $w
}

# NewMsg::DoSend --
#
#       Send the message. Validate addresses in address list.

proc ::NewMsg::DoSend {w} {
    global  prefs wDlgs
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	::UI::MessageBox -type ok -icon error -parent $w \
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
		set ans [::UI::MessageBox -type $type -parent $w -message $msg]
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
	::UI::MessageBox -title [mc {No Address}]  \
	  -icon error -type ok -parent $w -message [mc jamessaddrmiss]
	return
    }
    set wtext $locals($w,wtext)
    set str [string trimright [::Text::TransformToPureText $wtext]]
    
    if {[string length $locals($w,subject)] > 0} {
	set subopt [list -subject $locals($w,subject)]
    } else {
	set subopt {}
    }
    if {[string length $str] || [llength $subopt]} {
	foreach jid $addrList {
	    eval {::Jabber::JlibCmd send_message $jid} $subopt {-body $str}
	}
    }
    set locals($w,finished) 1
    ::UI::SaveWinGeom $wDlgs(jsendmsg) $w
    destroy $w
}

proc ::NewMsg::DoQuote {w message to time} {
    
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

proc ::NewMsg::SaveMsg {w} {
    global this
    
    variable locals
    
    set wtext $locals($w,wtext)
    set ans [tk_getSaveFile -title [mc {Save Message}] \
      -initialfile Untitled.txt]
    if {[string length $ans]} {
	set allText [::Text::TransformToPureText $wtext]
	set fd [open $ans w]
	fconfigure $fd -encoding utf-8
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

proc ::NewMsg::DoPrint {w} {
    
    variable locals
    upvar ::Jabber::jstate jstate
        
    set allText [::Text::TransformToPureText $locals($w,wtext)]    
    ::UserActions::DoPrintText $locals($w,wtext)  \
      -data $allText -font CociSmallFont    
}

proc ::NewMsg::CloseHook {wclose} {
    variable locals
	
    return [CloseDlg $wclose]
}

proc ::NewMsg::QuitAppHook { } {
    global  wDlgs
    variable locals
    
    # Any open windows with unsaved message?
    foreach {key w} [array get locals *,w] {
	if {[winfo exists $w]} {
	    set wtext $locals($w,wtext)
	    set allText [$wtext get 1.0 "end - 1 char"]
	    if {$allText != ""} {
		set str "There are unsaved messages. Do you still want to quit?"
		set ans [::UI::MessageBox -title [mc {To Send or Not}]  \
		  -icon warning -type yesno -default "no" \
		  -message $str]
		if {$ans == "no"} {
		    # @@@ mising return check here!
		    return 
		}
		break
	    }
	}
    }
    
    ::UI::SaveWinPrefixGeom $wDlgs(jsendmsg)
}

proc ::NewMsg::CloseDlg {w} {
    global  wDlgs
    variable locals
    
    set wtext $locals($w,wtext)
    set allText [$wtext get 1.0 "end - 1 char"]
    set doDestroy 0
    if {$allText != ""} {
	set ans [::UI::MessageBox -title [mc {To Send or Not}]  \
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
	destroy $w
	array unset locals $w,*
	return
    } else {
	return "stop"
    }
}

#-------------------------------------------------------------------------------
