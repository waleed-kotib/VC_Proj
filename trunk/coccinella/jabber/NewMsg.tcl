#  NewMsg.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements the new message dialog fo the jabber part.
#      
#  Copyright (c) 2001-2002  Mats Bengtsson
#  
# $Id: NewMsg.tcl,v 1.3 2003-02-06 17:23:32 matben Exp $

package provide NewMsg 1.0

namespace eval ::Jabber::NewMsg:: {

    variable locals
    
    # Running number for unique toplevels.
    set locals(num) 0
    set locals(inited) 0
    set locals(wpopupbase) .jsndtrpt
    set locals(transports) {jabber icq aim msn yahoo irc smtp}
    
    variable popupDefs
    array set popupDefs {
	jabber    {Jabber    {Jabber (address):}}
	icq       {ICQ       {ICQ (number):}}
	aim       {AIM       {AIM:}}
	msn       {MSN       {Messenger:}}
	yahoo     {Yahoo     {Yahoo (screen name):}}
	irc       {IRC       {IRC:}}
	smtp      {Email     {Mail address:}}
    }
    
    # Icons.
    set popupbt {
R0lGODdhEAAOALMAAP///+/v797e3s7Ozr29va2trZycnJSUlIyMjHl5eXR0
dHNzc2NjY1JSUkJCQgAAACwAAAAAEAAOAAAEYLDIIqoYg5A5iQhVthkGR4HY
JhkI0gWgphUkspRn5ey8Yy+S0CDRcxRsjOAlUzwuGkERQcGjGZ6S1IxHWjCS
hZkEcTC2vEAOieRDNlyrNevMaKQnrIXe+71zkF8MC3ASEQA7}

    set popupbtpush {
R0lGODdhEAAOAMQAAP///9DQ0M7Ozr29va2trZycnI2NjYyMjHZ2dnV1dXR0
dHNzc29vb2NjY1JSUkJCQgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAEAAOAAAFbqAgCsTSOGhTjMLgmk0s
O4s7EGW8HEVxHKYDjnCI8Vy4HnBoWhBsN+WigIsVBoGHdvtQCAm0qwDBfRAS
TvDUVjYs0g6VjbEluL/WIWELnOKKPD0FdAQKbzc4b4EHBg9vUyRDP5N9kFGC
UjtULT0hADs=}

    set whiterect {
R0lGODdhEAAOAIAAAP///wAAACwAAAAAEAAOAAACDYSPqcvtD6OctNqLZQEA
Ow==}

    set locals(popupbt) [image create photo -data $popupbt]
    set locals(popupbtpush) [image create photo -data $popupbtpush]
    set locals(whiterect) [image create photo -data $whiterect]
}

proc Jabber::NewMsg::Init { } {
    
    variable locals
    variable popupDefs
    upvar ::Jabber::jstate jstate
    
    set locals(inited) 1
    
    # Get all transports from our browse object.
    set alltypes [$jstate(browse) getalltypes service/*]
    
    # Sort out the transports from the services.
    set trpts {}
    foreach subtype $locals(transports) {	
	set ind [lsearch -exact $alltypes "service/$subtype"]
	if {$ind >= 0} {
	    lappend trpts $subtype
	}
    }
    set locals(ourtransports) $trpts
    
    # Build popup defs. Keep order of popupDefs. Flatten!
    set locals(menuDefs) {}
    foreach trpt $trpts {
	eval {lappend locals(menuDefs)} $popupDefs($trpt)
    }
}

# Jabber::NewMsg::Build --
#
#       The standard send message dialog.
#
# Arguments:
#       wbase  the base for the toplevel window.
#       args   ?-to jidlist -subject theSubject -quotemessage msg -time time
#              -forwardmessage msg?
#       
# Results:
#       shows window.

proc ::Jabber::NewMsg::Build {wbase args} {
    global  this sysFont prefs
    
    variable locals  
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    upvar ::UI::icons icons
    
    ::Jabber::Debug 2 "::Jabber::NewMsg::Build args='$args'"

    if {!$locals(inited)} {
	Jabber::NewMsg::Init
    }
    set w "$wbase[incr locals(num)]"
    set locals($w,num) $locals(num)
    if {[winfo exists $w]} {
	return
    }
    array set opts {
	-to             {}
	-subject        {}
	-quotemessage   {}
	-forwardmessage {}
	-time           {}
    }
    array set opts $args
    set locals($w,subject) $opts(-subject)
    if {[string length $opts(-quotemessage)] > 0} {
	set quotestate "normal"
    } else {
	set quotestate "disabled"
    }
    toplevel $w -class NewMsg
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	#wm transient $w .
    }
    wm title $w [::msgcat::mc {New Message}]
    wm protocol $w WM_DELETE_WINDOW [list [namespace current]::CloseDlg $w]
    
    # Toplevel menu for mac only. Only when multiinstance.
    if {0 && [string match "mac*" $this(platform)]} {
	set wmenu ${w}.menu
	menu $wmenu -tearoff 0
	::UI::MakeMenu $w ${wmenu}.apple   {}      $::UI::menuDefs(main,apple)
	::UI::MakeMenu $w ${wmenu}.file    mFile   $::UI::menuDefs(min,file)
	::UI::MakeMenu $w ${wmenu}.edit    mEdit   $::UI::menuDefs(min,edit)	
	::UI::MakeMenu $w ${wmenu}.jabber  mJabber $::UI::menuDefs(main,jabber)
	$w configure -menu ${wmenu}
    }
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 4
    
    # Button part.
    set frtop [frame $w.frall.frtop -borderwidth 0]
    pack $frtop -side top -fill x -padx 4 -pady 2
    ::UI::InitShortcutButtonPad $w $frtop 50
    ::UI::NewButton $w send $icons(btsend) $icons(btsenddis)  \
      [list ::Jabber::NewMsg::DoSend $w]
    ::UI::NewButton $w quote $icons(btquote) $icons(btquotedis)  \
      [list ::Jabber::NewMsg::DoQuote $w $opts(-quotemessage) $opts(-to) $opts(-time)] \
       -state $quotestate
    ::UI::NewButton $w save $icons(btsave) $icons(btsavedis)  \
      [list ::Jabber::NewMsg::SaveMsg $w]
    ::UI::NewButton $w print $icons(btprint) $icons(btprintdis)  \
      [list ::Jabber::NewMsg::DoPrint $w]
    
    pack [frame $w.frall.divt -bd 2 -relief sunken -height 2] -fill x -side top
    set wccp $w.frall.ccp
    pack [::UI::NewCutCopyPaste $wccp] -padx 10 -pady 2 -side top \
      -anchor w
    ::UI::CutCopyPasteConfigure $wccp cut -state disabled
    ::UI::CutCopyPasteConfigure $wccp copy -state disabled
    ::UI::CutCopyPasteConfigure $wccp paste -state disabled
    pack [frame $w.frall.div2 -bd 2 -relief sunken -height 2] -fill x -side top

    # Address list.    
    set fradd [frame $w.frall.fradd -borderwidth 1 -relief sunken]
    pack $fradd -side top -fill x -padx 6 -pady 4
    scrollbar $fradd.ysc -command [list $fradd.can yview]
    pack $fradd.ysc -side right -fill y
    set waddcan [canvas $fradd.can -highlightcolor #6363CE -bd 0  \
      -highlightthickness 1 -highlightbackground $prefs(bgColGeneral) \
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
    # Generally we shouldn't care having the resource, except for groupchats.
    if {$opts(-to) != ""} {
	set n 1
	foreach jid $opts(-to) {
	    if {$n > 1} {
		::Jabber::NewMsg::FillAddrLine $w $frport $n
	    }	    
	    regexp {^([^/]+)(/.+)?$} $jid match jidNoRes x
	    set isroom [$jstate(jlib) service isroom $jidNoRes]
	    if {$isroom} {
		set tojid $jid
	    } else {
		set tojid $jidNoRes
	    }
	    set locals($w,addr$n) $tojid
	    incr n
	}
    }
    
    # Subject.
    set frsub [frame $w.frall.frsub -borderwidth 0]
    pack $frsub -side top -fill x -padx 6 -pady 0
    label $frsub.lsub -text "[::msgcat::mc Subject]:" -font $sysFont(sb) -anchor e
    set wsubject $frsub.esub
    entry $wsubject  \
      -textvariable [namespace current]::locals($w,subject)
    pack $frsub.lsub -side left -padx 2
    pack $frsub.esub -side top -padx 2 -fill x
    
    # Text.
    set wtxt $w.frall.frtxt
    pack [frame $wtxt] -side top -fill both -expand 1 -padx 6 -pady 4
    set wtext $wtxt.text
    set wysc $wtxt.ysc
    text $wtext -height 8 -width 48 -font $sysFont(s) -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set]
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1
    if {[string match "mac*" $this(platform)]} {
	pack [frame $w.frall.pad -height 14] -side bottom
    }
    set locals($w,w) $w
    set locals($w,wtext) $wtext
    set locals($w,waddcan) $waddcan
    set locals($w,wfradd) $fradd
    set locals($w,wfrport) $frport
    set locals($w,wspacer) $wspacer
    set locals($w,wsubject) $wsubject
    set locals($w,wccp) $wccp
    set locals($w,finished) 0
    
    if {[string length $opts(-forwardmessage)] > 0} {
	$wtext insert end "\nForwarded message from $opts(-to) written at $opts(-time)\n\
--------------------------------------------------------------------\n\
$opts(-forwardmessage)"
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
    bind $frport <Configure> [list ::Jabber::NewMsg::AddrResize $w]
    bind $waddcan <Configure> [list ::Jabber::NewMsg::ResizeCan $w]
    
    if {[info exists prefs(winGeom,$w)]} {
	wm geometry $w $prefs(winGeom,$w)
    }
    wm minsize $w 300 260
    wm maxsize $w 1200 1000
    
    focus $frport.addr1
    
    # Wait here for a button press.
    tkwait variable [namespace current]::locals($w,finished)
    
    catch {destroy $w}    
}

proc ::Jabber::NewMsg::NewAddrLine {w wfr n} {
    global  sysFont
    
    variable locals
    
    set num $locals($w,num)
    frame $wfr.f${n} -bd 0
    entry $wfr.f${n}.trpt -width 18 -font $sysFont(sb) -bd 0 -highlightthickness 0 \
      -state disabled -textvariable [namespace current]::locals($w,poptrpt$n)
    label $wfr.f${n}.la -image $locals(whiterect) -bd 0 -bg white
    pack $wfr.f${n}.trpt $wfr.f${n}.la -side left -fill y
    entry $wfr.addr${n} -bd 0 -highlightthickness 0  \
      -textvariable [namespace current]::locals($w,addr$n) -state disabled
    
    set m [menu $locals(wpopupbase)${num}_${n} -tearoff 0]
    foreach {name desc} $locals(menuDefs) {
	$m add radiobutton -label $name -value $desc  \
	  -variable [namespace current]::locals($w,poptrpt$n)  \
	  -command [list ::Jabber::NewMsg::PopupCmd $w $n]
    }
    
    bind $wfr.addr$n <Button-1> [list ::Jabber::NewMsg::ButtonInAddr $w $wfr $n]
    bind $wfr.addr$n <Tab> [list ::Jabber::NewMsg::TabInAddr $w $wfr $n]
    bind $wfr.addr$n <BackSpace> "+ ::Jabber::NewMsg::BackSpaceInAddr $w $wfr $n"
    bind $wfr.addr$n <Return> [list ::Jabber::NewMsg::ReturnInAddr $w $wfr $n]
    bind $wfr.addr$n <Key-Up> [list ::Jabber::NewMsg::KeyUpDown -1 $w $wfr $n]
    bind $wfr.addr$n <Key-Down> [list ::Jabber::NewMsg::KeyUpDown 1 $w $wfr $n]
    
    grid $wfr.f${n} -padx 1 -pady 1 -column 0 -row $n -sticky ns
    grid $wfr.addr$n -padx 1 -pady 1 -column 1 -row $n -sticky news
    grid columnconfigure $wfr 1 -weight 1
    grid rowconfigure $wfr $n -minsize 16
    set locals($w,addrline) $n
}

proc ::Jabber::NewMsg::FillAddrLine {w wfr n} {
    
    variable locals
    variable popupDefs
    
    $wfr.f${n}.la configure -image $locals(popupbt) -bg #adadad
    $wfr.addr${n} configure -state normal
    
    bind $wfr.f${n}.la <Button-1> [list ::Jabber::NewMsg::TrptPopup $w $n %X %Y]
    bind $wfr.f${n}.la <ButtonRelease-1> [list ::Jabber::NewMsg::TrptPopupRelease $w $n]
    set locals($w,fillline) $n
    set locals($w,poptrpt$n) [lindex $popupDefs(jabber) 1]
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
	#puts "focus wsubject=$wsubject"
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
    
    #puts "BackSpaceInAddr: n=$n"
    
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
    
    #puts "EmptyAddrLine: n=$n"
    $wfr.f${n}.la configure -image $locals(whiterect) -bg white
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
    #puts "yview=[$can yview], n=$n, top=$top, bot=$bot"
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
    
    set num $locals($w,num)
    set wfrport $locals($w,wfrport)
    set pick $locals($w,poptrpt$n)
    #puts "::Jabber::NewMsg::PopupCmd pick=$pick"
    
    switch -glob -- $pick {
	*Jabber* {
	    #set locals($w,addr$n) "UsersName@$jserver(this)"
	    #set locals($w,addr$n) "UsersName@athlon.se"
	    #$wfrport.addr${n} selection from 0
	    #$wfrport.addr${n} selection to 9
	}
	*AIM* {
	    
	}
	*Yahoo* {
	    
	}
    }
}

#       Callback for the Configure scrollable canvas.

proc ::Jabber::NewMsg::ResizeCan {w } {
    
    variable locals
 
    set can $locals($w,waddcan)
    set wspacer $locals($w,wspacer)
    set canwidth [winfo width $can]
    #puts "::Jabber::NewMsg::ResizeCan canwidth=$canwidth"
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
    global  prefs
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	tk_messageBox -type ok -icon error -parent $w \
	  -title [::msgcat::mc {Not Connected}] \
	  -message [::msgcat::mc jamessnotconnected]
	return
    }
    
    # Loop through address list. 
    set addrList {}
    for {set i 1} {$i <= $locals($w,addrline)} {incr i} {
	set addr $locals($w,addr$i)
	if {[string length $addr] > 0} {
	    if {![::Jabber::IsWellFormedJID $addr]} {
		if {$locals($w,addrline) > 1} {
		    set msg [::msgcat::mc jamessskipsendq $addr]
		    set type yesnocancel
		} else {
		    set msg [::msgcat::mc jamessillformresend $addr]
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
	tk_messageBox -title [::msgcat::mc {No Address}]  \
	  -icon error -type ok -parent $w \
	  -message [FormatTextForMessageBox [::msgcat::mc jamessaddrmiss]]
	return
    }
    set wtext $locals($w,wtext)
    set allText [$wtext get 1.0 "end - 1 char"]
    if {[string length $locals($w,subject)] > 0} {
	set subopt [list -subject $locals($w,subject)]
    } else {
	set subopt {}
    }
    if {[string length $allText]} {
	foreach jid $addrList {
	    eval {$jstate(jlib) send_message $jid} $subopt {-body $allText}
	}
    }
    set locals($w,finished) 1
}

proc ::Jabber::NewMsg::DoQuote {w message to time} {
    
    variable locals
    upvar ::Jabber::jstate jstate

    set wtext $locals($w,wtext)
    regsub -all "\n" $message "\n> " quoteMsg
    set quoteMsg "\nAt $time, $to wrote:\n> $quoteMsg"
    $wtext insert end $quoteMsg
    
    # Quote only once.
    ::UI::ButtonConfigure $w quote -state disabled
}

proc ::Jabber::NewMsg::SaveMsg {w} {
    global this
    
    variable locals
    
    set wtext $locals($w,wtext)
    set ans [tk_getSaveFile -title [::msgcat::mc {Save Message}] \
      -initialfile Untitled.txt]
    if {[string length $ans]} {
	#set allText [$wtext get 1.0 "end - 1 char"]
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
	if {[string match "mac*" $this(platform)]} {
	    file attributes $ans -type TEXT -creator ttxt
	}
    }
}

proc ::Jabber::NewMsg::DoPrint {w} {
    global  sysFont
    
    variable locals
    upvar ::Jabber::jstate jstate

    set allText [::Text::TransformToPureText $locals($w,wtext)]    
    ::UserActions::DoPrintText $locals($w,wtext)  \
      -data $allText -font $sysFont(s)    
}

proc ::Jabber::NewMsg::CloseDlg {w} {

    variable locals

    set wtext $locals($w,wtext)
    set allText [$wtext get 1.0 "end - 1 char"]
    set doDestroy 0
    if {[string length $allText] > 0} {
	set ans [tk_messageBox -title [::msgcat::mc {To Send or Not}]  \
	  -icon warning -type yesnocancel -default "no" -parent $w \
	  -message [::msgcat::mc jamesssavemsg]]
	if {$ans == "yes"} {
	    set ansFile [tk_getSaveFile -title [::msgcat::mc {Save Message}] \
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
	if {[regexp {(\.[a-z]+)[0-9]+} $w match wbase]} {
	    ::UI::SaveWinGeom $wbase $w
	}
	unset locals($w,w)
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
