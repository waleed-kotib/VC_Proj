#  Privacy.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the jabber:iq:privacy stuff plus UI.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Privacy.tcl,v 1.1 2004-04-30 12:11:52 matben Exp $

package provide Privacy 1.0

namespace eval ::Privacy:: {
    global  tcl_platform
    
    # Define all hooks for preference settings.
    ::hooks::add prefsInitHook          ::Privacy::InitPrefsHook
    ::hooks::add prefsBuildHook         ::Privacy::BuildPrefsHook
    ::hooks::add prefsSaveHook          ::Privacy::SavePrefsHook
    ::hooks::add prefsCancelHook        ::Privacy::CancelPrefsHook
    ::hooks::add prefsUserDefaultsHook  ::Privacy::UserDefaultsHook
    ::hooks::add closeWindowHook        ::Privacy::List::CloseHook

    # User database options.
    option add *FilterDlg*Radiobutton.background  white
    if {($tcl_platform(platform) == "unix") && \
      ([tk windowingsystem] != "aqua")} {
	option add *FilterDlg.selectBackground    black           widgetDefault
	option add *FilterDlg.selectForeground    white           widgetDefault
    } else {
	option add *FilterDlg.selectBackground    systemHighlight widgetDefault
	option add *FilterDlg.selectForeground    systemHighlightText widgetDefault
    }
}

# Prefs Page ...................................................................

proc ::Privacy::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults... Server stored!

}

proc ::Privacy::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Jabber Filter} -text [::msgcat::mc Filter]
    
    # Blockers page --------------------------------------------------------
    set wpage [$nbframe page {Filter}]    
    ::Privacy::BuildPrefsPage $wpage
}

proc ::Privacy::BuildPrefsPage {page} {
    upvar ::Jabber::jprefs jprefs
    variable statmsg
    variable wtable
    variable wbts
    variable warrows
    variable defaultVar        ""
    variable activeVar         ""
    variable prevDefaultVar    ""
    variable prevActiveVar     ""
    variable iline
    variable selected          ""
    variable selectediline     ""
    variable prevselectediline ""
    variable selectBackground
    variable selectForeground
    
    set xpadbt [option get [winfo toplevel $page] xPadBt {}]
    
    set fpage $page.f
    labelframe $fpage -text [::msgcat::mc Filter] -padx 4 -pady 2
    pack $fpage -side top -anchor w -padx 8 -pady 4
    
    label $fpage.lmsg -wraplength 360 -justify left -text \
      "Each user may administrate zero or many lists. At least one list\
      is the default list which is applied by the server. This can be replaced\
      by the active list, selected from below."
    pack  $fpage.lmsg -side top -anchor w -pady 1
    
    frame  $fpage.bottom
    pack   $fpage.bottom -side bottom -pady 1 -fill x
    set warrows $fpage.bottom.arr
    ::chasearrows::chasearrows $warrows -size 16
    pack $warrows -side left -padx 5 -pady 5
    label $fpage.bottom.lhead -textvariable [namespace current]::statmsg
    pack  $fpage.bottom.lhead -side left -anchor w -pady 1
    
    set   wfr $fpage.fr
    frame $wfr
    pack  $wfr -side top -anchor w -pady 1
    
    set   wtabbox $wfr.ft
    frame $wtabbox -bd 1 -relief sunken -class FilterDlg
    set   wlabfr $wtabbox.lf
    set   wtable $wtabbox.tl
    set   wysc $wtabbox.ysc
    
    set selectBackground [option get $wtabbox selectBackground {}]
    set selectForeground [option get $wtabbox selectForeground {}]
    
    set iline 0
   
    frame $wlabfr -borderwidth 0
    scrollbar $wysc -orient vertical -command [list $wtable yview]
    text $wtable -width 32 -height 8 -borderwidth 1 -exportselection 0 \
      -highlightthickness 0 -state disabled -yscrollcommand [list $wysc set] \
      -insertwidth 0 -padx 0 -pady 0 -state normal -takefocus 0 -wrap none
    
    $wtable tag configure select -background $selectBackground \
      -foreground $selectForeground
    
    bind $wtable <Button-1>        {::Privacy::TableSelect %W %x %y}
    bind $wtable <Double-Button-1> ::Privacy::EditList
    
    label $wlabfr.l1 -bd 1 -relief raised -padx 4 -text [::msgcat::mc Default]
    label $wlabfr.l2 -bd 1 -relief raised -padx 4 -text [::msgcat::mc Active]
    label $wlabfr.l3 -bd 1 -relief raised -padx 4 -text [::msgcat::mc Name] \
      -anchor w
    pack  $wlabfr.l1 $wlabfr.l2 -side left
    pack  $wlabfr.l3 -side left -expand 1 -fill x -anchor w
    
    set width1 [winfo reqwidth $wlabfr.l1]
    set width2 [winfo reqwidth $wlabfr.l2]
    set tabs [list [expr $width1/2] center [expr $width1 + $width2/2] center \
      [expr $width1 + $width2] left]
    $wtable configure -tabs $tabs
        
    grid $wlabfr -column 0 -row 0 -sticky ew
    grid $wtable -column 0 -row 1 -sticky news
    grid $wysc   -column 1 -row 0 -sticky ns -rowspan 2
    grid columnconfigure $wtabbox 0 -weight 1
    grid rowconfigure    $wtabbox 1 -weight 1
    pack $wtabbox -side left -anchor w -pady 1
    
    # Buttons.
    set wfrbt $wfr.bt
    frame $wfrbt
    pack  $wfrbt -side right
    
    set wbts(new)  $wfrbt.new
    set wbts(edit) $wfrbt.edit
    set wbts(del)  $wfrbt.del    
    
    button $wfrbt.new -text [::msgcat::mc New]  \
      -command [namespace current]::NewList
    button $wfrbt.edit -text [::msgcat::mc Edit]  \
      -command [namespace current]::EditList
    button $wfrbt.del -text [::msgcat::mc Delete]  \
      -command [namespace current]::DelList
    pack $wfrbt.new $wfrbt.edit $wfrbt.del -side top -padx 6 -pady 4 \
      -fill x
    
    ::Privacy::Deselected
    if {![::Jabber::IsConnected]} {
	set statmsg [::msgcat::mc {Filter options unavailable while not connected}]
    } else {
	set statmsg [::msgcat::mc {Obtaining filter options}]
	::Privacy::GetLists
    }
    
    #foreach a {mats cool junk} {
#	::Privacy::TableInsertLine $a
    #}
}

proc ::Privacy::TableInsertLine {name} {
    variable wtable
    variable iline
    
    $wtable configure -state normal
    
    # Be sure to keep a newline between lines. Widget always keeps an extra \n!
    set tline "tiline:$iline"
    $wtable insert end \t $tline
    radiobutton $wtable.rd$iline -variable [namespace current]::defaultVar \
      -value $name -command [namespace current]::DefaultCmd -padx 0 -pady 0
    $wtable window create end -window $wtable.rd$iline -padx 0 -pady 0 \
      -align center
    $wtable insert end \t $tline
    radiobutton $wtable.ra$iline -variable [namespace current]::activeVar \
      -value $name -command [namespace current]::ActiveCmd -padx 0 -pady 0
    $wtable window create end -window $wtable.ra$iline -padx 0 -pady 0 \
      -align center
    $wtable insert end \t $tline
    $wtable insert end $name [list tname $tline]
    $wtable insert end \n $tline
    incr iline

    $wtable configure -state disabled
}

proc ::Privacy::TableDeleteLine {name} {
    variable wtable
    
    set w $wtable
    $w configure -state normal
    foreach {start end} [$w tag ranges tname] {
	#puts "name='$name' start=$start, end=$end, '[$w get $start $end]'"
	if {[string equal $name [$w get $start $end]]} {
	    $w delete "$start linestart" "$end lineend +1 char"
	    break
	}
    }
    $w configure -state disabled
}

proc ::Privacy::TableSelect {w x y} {
    variable selectediline
    variable prevselectediline
    variable selectBackground
    variable selectForeground
    variable selected
    
    $w tag remove select 1.0 end
    set ind [$w index @$x,$y]
    #puts "x=$x, y=$y, ind=$ind"
    set prevselectediline $selectediline
    set textBackground [$w cget -background]
    
    # Deselect the radiobuttons as well.
    if {$prevselectediline != ""} {
	if {[winfo exists $w.rd$prevselectediline]} {
	    $w.rd$prevselectediline configure -background $textBackground
	    $w.ra$prevselectediline configure -background $textBackground
	}
    }
    if {[$w compare $ind < "end -1 char"]} {
	$w tag add select "$ind linestart" "$ind lineend +1 char"
    
	# Find the name.
	set range [::Privacy::TextGetRange $w tname "$ind lineend"]
	set name [eval $w get $range]
	#puts "name=$name"
	set selected $name
	::Privacy::Selected $name
	set tiline [lsearch -glob -inline [$w tag names $ind] tiline:*]
	if {$tiline != ""} {
	    set iline [string map {tiline: ""} $tiline]
	    set selectediline $iline
	    $w.rd$iline configure -background $selectBackground
	    $w.ra$iline configure -background $selectBackground
	}
    } else {
	set selected ""
	::Privacy::Deselected
    }
}

proc ::Privacy::Selected {name} {
    variable wbts
    
    if {[::Jabber::IsConnected]} {
	foreach {key bt} [array get wbts] {
	    $bt configure -state normal
	}
    }
}

proc ::Privacy::Deselected { } {    
    variable wbts
    
    foreach {key bt} [array get wbts] {
	$bt configure -state disabled
    }
    if {[::Jabber::IsConnected]} {
	$wbts(new) configure -state normal
    }
}

proc ::Privacy::TextGetRange {w tag ind} {
    
    set range [$w tag prevrange $tag $ind]
    set end [lindex $range 1]
    if {[llength $range] == 0 || [$w compare $end < $ind]} {
	set range [$w tag nextrange $tag $ind]
	if {[llength $range] == 0 || [$w compare $ind < [lindex $range 0]]} {
	    return {}
	}
    }
    return $range
}

proc ::Privacy::TableGetAllNames {w} {
    
    set names {}
    foreach {start end} [$w tag ranges tname] {
	lappend names [$w get $start $end]
    }
    return $names
}

#       We must have a state where all buttons are unselected.
#       
#       The button's global variable (-variable option) will be updated before
#       the command is invoked. 

proc ::Privacy::DefaultCmd { } {
    variable defaultVar
    variable prevDefaultVar

    #puts "::Privacy::DefaultCmd defaultVar=$defaultVar, prevDefaultVar=$prevDefaultVar"
    if {$defaultVar == $prevDefaultVar} {
	# Deselect all.
	set defaultVar ""
    }
    set prevDefaultVar $defaultVar
}

proc ::Privacy::ActiveCmd { } {
    variable activeVar
    variable prevActiveVar

    if {$activeVar == $prevActiveVar} {
	# Deselect all.
	set activeVar ""
    }
    set prevActiveVar $activeVar
}
    
proc ::Privacy::GetLists { } {
    upvar ::Jabber::jstate jstate
    variable warrows

    $warrows start
    $jstate(jlib) iq_get jabber:iq:privacy -command [namespace current]::GetListsCB
}

proc ::Privacy::GetListsCB {jlibname type subiq args} {
    variable statmsg
    variable cache
    variable wtable
    variable activeVar
    variable defaultVar
    variable prevDefaultVar
    variable prevActiveVar
    variable warrows

    if {![winfo exists $warrows]} {
	return
    }
    $warrows stop
    
    puts "::Privacy::GetListsCB $type, $subiq, '$args'"
    
    switch -- $type {
	error {
	    set statmsg [::msgcat::mc {Filter options unavailable at this server}]
	}
	default {
	    set statmsg [::msgcat::mc {Filter lists obtained from server}]
	    
	    # Cache xml.
	    set cache(lists) $subiq
	    $wtable delete 1.0 end
	    set activeVar  ""
	    set defaultVar ""
	    set prevDefaultVar ""
	    foreach wc [winfo children $wtable] {
		puts "wc=$wc"
		destroy $wc
	    }
	    
	    # Fill in table.
	    foreach c [wrapper::getchildren $subiq] {
		set tag [wrapper::gettag $c]
		array set attrArr [wrapper::getattrlist $c]
		set name $attrArr(name)
		
		switch -- $tag {
		    active {
			set cache(active) $name			
		    }
		    default {
			
			# Be sure this is not last!
			set cache(default) $name
		    }
		    list {
			::Privacy::TableInsertLine $name
			set cache(xml,$name) $c
		    }
		}
	    }
	    if {[info exists cache(active)]} {
		set activeVar $cache(active)
		set prevActiveVar $activeVar
	    }
	    if {[info exists cache(default)]} {
		set defaultVar $cache(default)
		set prevDefaultVar $defaultVar
	    }
	}
    }
}

proc ::Privacy::NewList { } {
    
    set token [::Privacy::List::Build]
    ::Privacy::List::BuildItem $token
}

proc ::Privacy::EditList { } {
    variable selected
    variable warrows
    
    if {$selected != ""} {	
	$warrows start
	::Privacy::List::GetList $selected
    }
}

proc ::Privacy::Save { } {
    variable activeVar
    variable defaultVar
    
    puts "::Privacy::Save"
        
    ::Privacy::SetActiveDefaultList active  $activeVar
    ::Privacy::SetActiveDefaultList default $defaultVar
}

proc ::Privacy::DelList { } {
    variable selected
    variable warrows
    upvar ::Jabber::jstate jstate
    
    if {$selected != ""} {
	$warrows start
	set subtags [list [wrapper::createtag "list" -attrlist [list name $selected]]]
	
	$jstate(jlib) iq_set "jabber:iq:privacy" -sublists $subtags \
	  -command [list [namespace current]::DelListCB $selected]
    }
}

proc ::Privacy::DelListCB {name jlibname type subiq args} {
    variable statmsg
    variable warrows
    
    if {![winfo exists $warrows]} {
	return
    }
    $warrows stop
    
    switch -- $type {
	error {
	    set statmsg "Error deleting list $name"
	}
	default {
	    set statmsg "List $name deleted"
	    ::Privacy::TableDeleteLine $name
	}
    }
}

proc ::Privacy::SetActiveDefaultList {which name} {
    upvar ::Jabber::jstate jstate
    
    # name may be empty which means the active list should be unset.
    if {$name == ""} {
	set subtags [list [wrapper::createtag $which]]
    } else {
	set subtags [list [wrapper::createtag $which -attrlist [list name $name]]]
    }
    $jstate(jlib) iq_set "jabber:iq:privacy" -sublists $subtags \
      -command [namespace current]::SetListCB
}

proc ::Privacy::SetListCB {jlibname type subiq args} {

    puts "::Privacy::SetListCB type=$type"
    
    if {$type == "error"} {
	
	
    }
}

# Hooks for prefs panel --------------------------------------------------------

proc ::Privacy::SavePrefsHook { } {

    ::Privacy::Save
}

proc ::Privacy::CancelPrefsHook { } {

#    ::Preferences::HasChanged

}

proc ::Privacy::UserDefaultsHook { } {

}

# Code for new/edit dialogs. ---------------------------------------------------

namespace eval ::Privacy::List:: {
    
    # Uid for token,
    variable uid 0
    
    variable blockStrToTag
    array set blockStrToTag {
	{Incoming Messages}   message
	{Incoming Presence}   presence-in
	{Outgoing Presence}   presence-out
    }
}

proc ::Privacy::List::GetList {name} {
    upvar ::Privacy::statmsg statmsg
    upvar ::Jabber::jstate jstate
        
    set statmsg "Getting filter list \"$name\""
    set subtags [list [wrapper::createtag "item"  -attrlist [list name $name]]]    
    $jstate(jlib) iq_get "jabber:iq:privacy" -sublists $subtags \
      -command [list [namespace current]::GetListCB $name]
}

proc ::Privacy::List::GetListCB {name jlibname type subiq args} {
    variable cache
    variable wtable
    upvar ::Privacy::warrows warrows
    upvar ::Privacy::statmsg statmsg
    
    if {![winfo exists $warrows]} {
	return
    }
    puts "::Privacy::List::GetListCB name=$name, $type, $subiq, $args"
    $warrows stop
    
    switch -- $type {
	error {
	    
	    # Display error somewhere...
	    set statmsg "Failed obtaining list \"$name\""
	}
	default {
	    
	    # Build dialog and fill in info.
	    set statmsg ""
	    set token [::Privacy::List::Build]
	    variable $token
	    upvar 0 $token state
	    
	    set state(name) $name
	    # $state(wname) configure -state disabled
	    
	    # jabberd2 seems to return the "full monty", not XMPP!
	    foreach listElem [wrapper::getchildren $subiq] {
		
		switch -- [wrapper::gettag $listElem] {
		    list {
			catch {unset attrArr}
			array set attrArr [wrapper::getattrlist $listElem]
			
			# Pick only the list we have requested.
			if {$attrArr(name) == $name} {
			    foreach c [wrapper::getchildren $listElem] {
				set itemi [::Privacy::List::BuildItem $token]
				::Privacy::List::FillItem $token $itemi $c
			    }		    
			}
		    }
		    default {
			# empty
		    }
		}
	    }
	}
    }
}

proc ::Privacy::List::Build { } {
    global  wDlgs
    variable uid
      
    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::Privacy::List::Build token=$token"
        
    set w $wDlgs(jprivacy)${uid}
    set state(w) $w
    
    # Toplevel with class JPrivacy.
    ::UI::Toplevel $w -class JPrivacy -usemacmainmenu 1 -macstyle documentProc

    wm title $w "[::msgcat::mc {Privacy List}]"
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4

    message $w.frall.msg -width 300 -text "Each list contains one or many rules,\
      each rule specify..."
    pack    $w.frall.msg -side top -anchor w
    
    set wfr $w.frall.fr
    frame $wfr
    pack  $wfr -side top -anchor w
    
    set state(wname) $wfr.ename
    label $wfr.lname -text [::msgcat::mc {Name of list}]:
    entry $wfr.ename -width 16 -textvariable $token\(name)
    pack $wfr.lname $wfr.ename -side left
    
    set wit $w.frall.fit
    frame $wit
    pack  $wit
    
    set state(wit) $wit
    
    set i 0    
    foreach {wtype wval wblk wact wdel}  \
      [list $wit.t${i} $wit.v${i} $wit.bl${i} $wit.a${i} $wit.bt${i}] break
    label $wtype -text [::msgcat::mc {Type}]
    label $wval  -text [::msgcat::mc {Value}]
    label $wblk  -text [::msgcat::mc {Block}]    
    label $wact  -text [::msgcat::mc {Action}]    
    label $wdel  -text [::msgcat::mc {Delete Rule}]    
    grid $wtype $wval $wblk $wact $wdel -sticky w
    
    set state(i) $i
    
    set state(statmsg) ""    
   
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set warrows $frbot.arr
    pack [button $frbot.btok -text [::msgcat::mc Set] \
      -default active -command [list [namespace current]::Set $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::Cancel $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btprof -text [::msgcat::mc {New Rule}]  \
      -command [list [namespace current]::New $token]]  \
      -side left -padx 5 -pady 5
    pack [::chasearrows::chasearrows $warrows -size 16] \
      -side left -padx 5 -pady 0
    pack [label $frbot.stat -textvariable $token\(statmsg)] \
      -side left -padx 5 -pady 0
    pack $frbot -side bottom -fill both -expand 1 -padx 8 -pady 6


    return $token
}

proc ::Privacy::List::Set {token} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Privacy::warrows warrows
    upvar ::Privacy::statmsg statmsg
    upvar ::Privacy::wtable wtable
    
    set xmllist [::Privacy::List::ExtractListElement $token]
    if {$xmllist == ""} {
	# error
	return
    }
    $warrows start
    set statmsg "Setting filter list \"$state(name)\""
    $jstate(jlib) iq_set "jabber:iq:privacy" -sublists [list $xmllist] \
      -command [list [namespace current]::SetListCB $state(name)]
    
    destroy $state(w)
    unset state
}

proc ::Privacy::List::SetListCB {name jlibname type subiq args} {    
    upvar ::Privacy::warrows warrows
    upvar ::Privacy::statmsg statmsg
    
    if {![winfo exists $warrows]} {
	return
    }
    puts "::Privacy::List::SetListCB type=$type"
    $warrows stop
    
    switch -- $type {
	error {
	    
	    # Display error somewhere...
	    set statmsg "Error setting list \"$name\""
	}
	default {
	    set statmsg "Filter list \"$name\" set"
	    
	    # Add new entry in filter dialog if it was a new one!
	    if {[lsearch [::Privacy::TableGetAllNames $wtable] $name] < 0} {
		::Privacy::TableInsertLine $name
	    }
	}
    }
}

proc ::Privacy::List::Cancel {token} {
    variable $token
    upvar 0 $token state
    
    destroy $state(w)
    unset state
}

proc ::Privacy::List::New {token} {   
    variable $token
    upvar 0 $token state
 
    BuildItem $token
}

proc ::Privacy::List::BuildItem {token} {
    variable $token
    upvar 0 $token state
    variable blockStrToTag
    
    set wit $state(wit)

    incr state(i)
    set i $state(i)
    foreach {wtype wval wblk wact wdel}  \
      [list $wit.t${i} $wit.v${i} $wit.bl${i} $wit.a${i} $wit.bt${i}] break
    tk_optionMenu $wtype $token\(type${i}) jid group subscription
    entry         $wval -width 12 -textvariable $token\(value${i})
    tk_optionMenu $wblk $token\(block${i}) {Incoming Messages} \
      {Incoming Presence} {Outgoing Presence}
    tk_optionMenu $wact $token\(action${i}) Allow Deny
    button        $wdel -text Delete  \
      -command [list [namespace current]::Delete $token $i]
    
    grid $wtype $wval $wblk $wact $wdel -sticky w
    
    set state(action${i}) Deny
    set state(value${i})    ""
    set state(block${i})  {Incoming Messages}
    return $state(i)
}

proc ::Privacy::List::FillItem {token itemi xmllist} {
    variable $token
    upvar 0 $token state
    
    puts "::Privacy::List::FillItem itemi=$itemi, xmllist=$xmllist"
    if {![winfo exists $state(w)]} {
	return
    }
    #<item type='jid'
    #		value='tybalt@example.com'
    #		action='deny'
    #		order='1'/> 
    array set attrArr [wrapper::getattrlist $xmllist]
    foreach {key value} [array get attrArr] {
	
	switch -- $key {
	    action {
		set state(action${itemi}) [string totitle $value]
	    }
	    type - value {
		set state(${key}${itemi}) $value
	    }
	}
    }
}

proc ::Privacy::List::Delete {token i} {
    variable $token
    upvar 0 $token state
    
    puts "::Privacy::List::Delete i=$i"
    
    set wit $state(wit)
    foreach {wtype wval wblk wact wdel}  \
      [list $wit.t${i} $wit.v${i} $wit.bl${i} $wit.a${i} $wit.bt${i}] break
    destroy $wtype $wval $wblk $wact $wdel
}

proc ::Privacy::List::ExtractListElement {token} {
    variable $token
    upvar 0 $token state
    variable blockStrToTag
    
    set wit  $state(wit)
    set i    $state(i)
    set name $state(name)

    if {$name == ""} {
	tk_messageBox -title [::msgcat::mc Error] -message \
	  {You must specify a nonempty list name!} -icon error
	return ""
    }
    
    set order 1
    set itemlist {}
    for {set j 1} {$j <= $i} {incr j} {
	if {[winfo exists $wit.t${j}]} {
	    set type   $state(type${j})
	    set value  $state(value${j})
	    set block  $blockStrToTag($state(block${j}))
	    set action [string tolower $state(action${j})]
	    
	    # Do some error checking here.
	    if {$value == ""} {
		tk_messageBox -title [::msgcat::mc Error] -message \
		  "You must specify a nonempty value for $type!" -icon error
		return ""
	    }
	    
	    set attrlist [list type $type value $value action $action order $order]
	    set blockelem [wrapper::createtag $block]
	    lappend itemlist [wrapper::createtag "item" -attrlist $attrlist \
	      -subtags [list $blockelem]]
	    incr order
	}
    }
    
    set listelem [wrapper::createtag "list" -attrlist [list name $name] \
      -subtags $itemlist]
    
    return $listelem
}

proc ::Privacy::List::GetTokenFromToplevel {w} {
    
    set ns [namespace current]
    set tokenList [concat  \
      [info vars ${ns}::\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]]]
    
    foreach token $tokenList {
	variable $token
	upvar 0 $token state
	
	if {[info exists state(w)] && [string equal $w $state(w)] && \
	  [winfo exists $w]} {
	    return $token
	}
    }
    return ""
}

# Privacy::List::CloseHook --
# 
#       Be sure to cleanup when closing window directly.

proc ::Privacy::List::CloseHook {wclose} {
    global  wDlgs
    
    if {[string match $wDlgs(jprivacy)* $wclose]} {
	set token [::Privacy::List::GetTokenFromToplevel $wclose]
	if {$token != ""} {
	    unset $token
	}
    }   
    return ""
}

#-------------------------------------------------------------------------------
