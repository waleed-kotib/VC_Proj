#  Privacy.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the jabber:iq:privacy stuff plus UI.
#      
#  Copyright (c) 2004  Mats Bengtsson
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
# $Id: Privacy.tcl,v 1.21 2008-03-29 07:08:41 matben Exp $

package provide Privacy 1.0

namespace eval ::Privacy:: {
    global  tcl_platform
    
    return
    
    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Privacy::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Privacy::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Privacy::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Privacy::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Privacy::UserDefaultsHook

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
    
    variable cache
    set cache(haveprivacy) 0
}

# Prefs Page ...................................................................

proc ::Privacy::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults... Server stored!

}

proc ::Privacy::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {Jabber Filter} [mc Filter]
    
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

    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    set wfi $wc.fi
    ttk::labelframe $wfi -text [mc Filter] \
      -padding [option get . groupSmallPadding {}]
    pack  $wfi  -side top -fill x
	      
    ttk::label $wfi.lmsg -text [mc prefprivmsg] \
      -wraplength 300 -justify left -padding {0 0 0 6}
    pack  $wfi.lmsg -side top -anchor w
    
    set warrows $wfi.bottom.arr
    ttk::frame  $wfi.bottom
    pack $wfi.bottom -side bottom -pady 1 -fill x
    ttk::label $wfi.bottom.lhead -textvariable [namespace current]::statmsg
    ::UI::ChaseArrows $warrows
    pack $wfi.bottom.lhead -side left -anchor w -pady 1
    pack $warrows -side left -padx 5 -pady 5
    
    set  wfr $wfi.fr
    ttk::frame $wfr
    pack $wfr -side top -anchor w -pady 1
    
    set wtabbox $wfr.ft
    set wlabfr $wtabbox.lf
    set wtable $wtabbox.tl
    set wysc $wtabbox.ysc

    frame $wtabbox -bd 1 -relief sunken -class FilterDlg
       
    set selectBackground [option get $wtabbox selectBackground {}]
    set selectForeground [option get $wtabbox selectForeground {}]
    set iline 0
   
    frame $wlabfr -borderwidth 0
    ttk::scrollbar $wysc -orient vertical -command [list $wtable yview]
    text $wtable -width 32 -height 8 -borderwidth 0 -exportselection 0 \
      -highlightthickness 0 -state disabled -yscrollcommand [list $wysc set] \
      -insertwidth 0 -padx 0 -pady 0 -state normal -takefocus 0 -wrap none
    
    $wtable tag configure select -background $selectBackground \
      -foreground $selectForeground
    
    bind $wtable <Button-1>        {::Privacy::TableSelect %W %x %y}
    bind $wtable <Double-Button-1> ::Privacy::EditList
    
    foreach name { def act nam } str { Default Active Name } {
	set f $wlabfr.$name
	frame $f -bd 1 -relief raised
	ttk::label $f.l -text [mc $str] -anchor w -padding {4 0}
	pack $f.l -fill both
	pack $f -side left
    }
    pack $wlabfr.nam -expand 1 -fill x
    
    set width1 [winfo reqwidth $wlabfr.def]
    set width2 [winfo reqwidth $wlabfr.act]
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
    ttk::frame $wfrbt
    
    set wbts(new)  $wfrbt.new
    set wbts(edit) $wfrbt.edit
    set wbts(del)  $wfrbt.del    
    
    ttk::button $wfrbt.new -text [mc New] -state disabled \
      -command [namespace current]::NewList
    ttk::button $wfrbt.edit -text [mc mEdit] -state disabled \
      -command [namespace current]::EditList
    ttk::button $wfrbt.del -text [mc Delete] -state disabled \
      -command [namespace current]::DelList
    pack $wfrbt.new $wfrbt.edit $wfrbt.del -side top -padx 6 -pady 4 \
      -fill x
    pack  $wfrbt -side right
    
    Deselected
    if {[::Jabber::IsConnected]} {
	set statmsg [mc {Obtaining filter options}]
	GetLists
    } else {
	set statmsg [mc prefprivunav]
    }
        
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s.lmsg configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wfi $wfi]    
    after idle $script
    
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
	set selected $name
	Selected $name
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
    variable wbts

    if {![winfo exists $warrows]} {
	return
    }
    $warrows stop
    
    #puts "::Privacy::GetListsCB $type, $subiq, '$args'"
    
    switch -- $type {
	error {
	    set statmsg [mc prefprivnotex]
	    set cache(haveprivacy) 0
	}
	default {
	    set cache(haveprivacy) 1
	    $wbts(new) configure -state normal
	    set statmsg [mc prefprivobtained]
	    
	    # Cache xml.
	    set cache(lists) $subiq
	    $wtable delete 1.0 end
	    set activeVar  ""
	    set defaultVar ""
	    set prevDefaultVar ""
	    foreach wc [winfo children $wtable] {
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
			TableInsertLine $name
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
    
    set token [List::Build]
    List::BuildItem $token
}

proc ::Privacy::EditList { } {
    variable selected
    variable warrows
    
    if {$selected != ""} {	
	$warrows start
	List::GetList $selected
    }
}

proc ::Privacy::Save { } {
    variable activeVar
    variable defaultVar
    variable cache
    
    #puts "::Privacy::Save"
    if {$cache(haveprivacy) && [::Jabber::IsConnected]} {
	SetActiveDefaultList active  $activeVar
	SetActiveDefaultList default $defaultVar
    }
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
	    set statmsg "Error deleting list \"$name\""
	    ::Jabber::AddErrorLog "" $statmsg
	}
	default {
	    set statmsg "List \"$name\" deleted"
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

    #puts "::Privacy::SetListCB type=$type"
    
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
    
    # Need to map from menu entry to actual tag or attribute.
    variable strToTag
    set strToTag(type,[mc JID])          jid
    set strToTag(type,[mc Group])        group
    set strToTag(type,[mc Subscription]) subscription
    set strToTag(block,[mc {Incoming Messages}]) message
    set strToTag(block,[mc {Incoming Presence}]) presence-in
    set strToTag(block,[mc {Outgoing Presence}]) presence-out
    set strToTag(action,[mc Allow]) allow
    set strToTag(action,[mc Deny])  deny
    
    # Labels for the menubuttons.
    variable labels
    set typeList   {jid Group Subscription}
    set blockList  {{Incoming Messages} {Incoming Presence} {Outgoing Presence}}
    set actionList {Allow Deny}
    foreach key {type block action} {
	set labels($key) {}
	foreach str [set ${key}List] {
	    lappend labels($key) [mc $str]
	}
	set labels(max,$key) [eval {::Utils::GetMaxMsgcatString} [set ${key}List]]
    }
}

proc ::Privacy::List::GetList {name} {
    upvar ::Privacy::statmsg statmsg
    upvar ::Jabber::jstate jstate
        
    set statmsg [mc prefprivgetlist $name]
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
    #puts "::Privacy::List::GetListCB name=$name, $type, $subiq, $args"
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
	    
	    # If we get a list from the server we shouldn't be able to change
	    # its name.
	    set state(name) $name
	    $state(wname) configure -state disabled
	    
	    # jabberd2 seems to return the "full monty", not XMPP!
	    foreach listElem [wrapper::getchildren $subiq] {
		
		switch -- [wrapper::gettag $listElem] {
		    list {
			unset -nocomplain attrArr
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
    variable labels
      
    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::Privacy::List::Build token=$token"
        
    set w $wDlgs(jprivacy)${uid}
    set state(w) $w
    
    # Toplevel with class JPrivacy.
    ::UI::Toplevel $w -class JPrivacy \
      -usemacmainmenu 1 -macstyle documentProc \
      -closecommand ::Privacy::List::CloseHook

    wm title $w [mc {Privacy List}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 400 -justify left -text [mc prefprivrules]
    pack $wbox.msg -side top -anchor w
    
    set wfr $wbox.fr
    ttk::frame $wfr
    pack  $wfr -side top -anchor w
    
    set state(wname) $wfr.ename
    ttk::label $wfr.lname -text "[mc {Name of list}]:"
    ttk::entry $wfr.ename -width 16 -textvariable $token\(name)
    pack  $wfr.lname  $wfr.ename  -side left
    
    set wit $wbox.fit
    ttk::frame $wit
    pack  $wit
    
    set state(wit) $wit
    
    set i 0    
    foreach {wtype wval wblk wact wdel}  \
      [list $wit.t$i $wit.v$i $wit.bl$i $wit.a$i $wit.bt$i] break
    ttk::label $wtype -text [mc Type]
    ttk::label $wval  -text [mc Value]
    ttk::label $wblk  -text [mc Block]    
    ttk::label $wact  -text [mc Action]    
    ttk::label $wdel  -text [mc "Delete Rule"]    

    grid  $wtype  $wval  $wblk  $wact  $wdel
    
    # Build a row of empty frames to hold the max size of menubuttons.
    # Fake menubutton to compute max width.
    incr i
    foreach what {type block action} {
	set wtmp $w.frall._tmp
	ttk::menubutton $wtmp -text $labels(max,$what)
	set maxwidth [winfo reqwidth $wtmp]
	destroy $wtmp
	frame ${wit}.${what}$i -width [expr $maxwidth + 20]
    }
    grid $wit.type$i x $wit.block$i $wit.action$i
    
    set state(i) $i
    
    set state(statmsg) ""    
   
    # Button part.
    set frbot $wbox.b
    set warrows $frbot.arr
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] \
      -default active -command [list [namespace current]::Set $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $token]
    ttk::button $frbot.btprof -text [mc {New Rule}]  \
      -command [list [namespace current]::New $token]
    ::UI::ChaseArrows $warrows
    ttk::label $frbot.stat -textvariable $token\(statmsg)

    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot.btprof -side left
    pack $warrows -side left -padx $padx
    pack $frbot.stat -side left
    pack $frbot -side bottom -fill x


    wm resizable $w 0 0
    
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 30]
    } $wbox.msg $w]    
    after idle $script
    
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
    upvar ::Privacy::wtable wtable
    upvar ::Privacy::statmsg statmsg
    
    if {![winfo exists $warrows]} {
	return
    }
    #puts "::Privacy::List::SetListCB type=$type"
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
    variable labels
    
    set wit $state(wit)

    incr state(i)
    set i $state(i)
    foreach {wtype wval wblk wact wdel}  \
      [list $wit.t$i $wit.v$i $wit.bl$i $wit.a$i $wit.bt$i] break
    eval {ttk::optionmenu $wtype $token\(type$i)} $labels(type)
    ttk::entry $wval -width 12 -textvariable $token\(value$i)
    eval {ttk::optionmenu $wblk $token\(block$i)} $labels(block)
    eval {ttk::optionmenu $wact $token\(action$i)} $labels(action)
    ttk::button $wdel -text [mc Delete]  \
      -command [list [namespace current]::Delete $token $i]
    
    grid $wtype $wval $wblk $wact $wdel -sticky e
    
    set state(action$i) [mc Deny]
    set state(value$i)  ""
    set state(block$i)  {Incoming Messages}
    return $state(i)
}

proc ::Privacy::List::FillItem {token itemi xmllist} {
    variable $token
    upvar 0 $token state
    
    #puts "::Privacy::List::FillItem itemi=$itemi, xmllist=$xmllist"
    if {![winfo exists $state(w)]} {
	return
    }
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
    
    #puts "::Privacy::List::Delete i=$i"
    
    set wit $state(wit)
    foreach {wtype wval wblk wact wdel}  \
      [list $wit.t$i $wit.v$i $wit.bl$i $wit.a$i $wit.bt$i] break
    destroy $wtype $wval $wblk $wact $wdel
}

# Privacy::List::ExtractListElement --
# 
# 

proc ::Privacy::List::ExtractListElement {token} {
    variable $token
    upvar 0 $token state
    variable strToTag
    
    set wit  $state(wit)
    set i    $state(i)
    set name $state(name)

    if {$name == ""} {
	::UI::MessageBox -title [mc Error] -message \
	  {You must specify a nonempty list name!} -icon error
	return
    }
    
    set order 1
    set itemlist {}
    for {set j 1} {$j <= $i} {incr j} {
	if {[winfo exists $wit.t${j}]} {
	    set type   $strToTag(type,$state(type${j}))
	    set value  $state(value${j})
	    set block  $strToTag(block,$state(block${j}))
	    set action $strToTag(action,$state(action${j}))
	    
	    # Do some error checking here.
	    if {$value == ""} {
		::UI::MessageBox -title [mc Error] -message \
		  "You must specify a nonempty value for $type!" -icon error
		return
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
    return
}

# Privacy::List::CloseHook --
# 
#       Be sure to cleanup when closing window directly.

proc ::Privacy::List::CloseHook {wclose} {

    set token [::Privacy::List::GetTokenFromToplevel $wclose]
    if {$token != ""} {
	unset $token
    }   
    return
}

#-------------------------------------------------------------------------------
