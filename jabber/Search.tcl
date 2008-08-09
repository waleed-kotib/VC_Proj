#  Search.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements search UI parts for jabber.
#      
#  Copyright (c) 2001-2008  Mats Bengtsson
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
# $Id: Search.tcl,v 1.54 2008-08-09 13:15:04 matben Exp $

package provide Search 1.0

namespace eval ::Search {

    # Wait for this variable to be set.
    variable finished  

    variable popMenuDefs    
    set popMenuDefs {
	{command    mAddContact...      {::JUser::NewDlg -jid $jid} }
	{command    mBusinessCard...    {::VCard::Fetch other $jid} }	
    }
}

proc ::Search::OnMenu {} {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "connectfin"} {
	Build
    }
}

# Search::Build --
#
#       Initiates the process of searching a service.
#       
# Arguments:
#       args   -server, -autoget 0/1
#       
# Results:
#       .
     
proc ::Search::Build {args} {
    global  this prefs wDlgs
    
    set w $wDlgs(jsearch)
    if {[winfo exists $w]} {
	return
    }

    # Keep instance specific state array. (Even though this is a singleton)
    set token [namespace current]::$w
    variable $w
    upvar 0 $w state    

    array set argsArr {
	-server         ""
	-autoget        0
    }
    array set argsArr $args
    set finished -1
    set wraplength 200
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document {closeBox resizable}}  \
      -closecommand ::Search::CloseCmd
    wm title $w [mc Search]
    set state(w) $w

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jsearch)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jsearch)
    }

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    # Left half.
    set wleft $wbox.fl
    ttk::frame $wleft -padding {0 0 12 0}
    pack $wleft -side left -fill y
    
    # Right half.
    set wright $wbox.fr
    ttk::frame $wright
    pack $wright -side right -expand 1 -fill both
    
    ttk::label $wleft.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength $wraplength -justify left \
      -text [mc jasearch2]
    pack $wleft.msg -side top -anchor w
    
    set frtop $wleft.top
    ttk::frame $frtop
    pack $frtop -side top -fill x -anchor w
    
    # Button part.
    set frbot $wleft.frbot
    set wsearch $frbot.search
    
    ttk::frame $frbot
    ttk::button $frbot.search -text [mc Search] \
      -command [namespace code [list DoSearch $w]]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [namespace code [list CloseCmd $w]]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.search   -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.search   -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    $wsearch state {disabled}
    
    # OOB alternative.
    set woob $wleft.foob
    ttk::frame $wleft.foob
    pack $wleft.foob -side bottom -fill x
    
    # Get all (browsed) services that support search.
    set searchServ [::Jabber::Jlib disco getjidsforfeature "jabber:iq:search"]
    set wservice $frtop.eserv
    set wbtget       $frtop.btget
    ttk::label    $frtop.lserv -text "[mc Service]:"
    ttk::button   $frtop.btget -text [mc "New Form"] -default active \
      -command [namespace code [list Get $w]]
    ttk::combobox $frtop.eserv -values $searchServ \
      -textvariable $token\(server)

    grid  $frtop.lserv  $frtop.eserv  -sticky w  -pady 2
    grid  $frtop.btget  -             -sticky ew -pady 2
    grid columnconfigure $frtop 0 -weight 1
    
    # Find the default search server.
    set state(server) ""
    if {[llength $searchServ]} {
	set state(server) [lindex $searchServ 0]
    } else {
	$wbtget state {disabled}
    }
    if {$argsArr(-server) ne ""} {
	set state(server) $argsArr(-server)
    }
    
    set wscrollframe $wleft.frsc
     ::UI::ScrollFrame $wscrollframe -padding {8 12} -bd 1 -relief sunken \
       -propagate 0 -width $wraplength
#     ::UI::ScrollFrame $wscrollframe -padding {8 12} -bd 1 -relief sunken

    pack $wscrollframe -fill both -expand 1 -pady 4

    
    # Status part.
    set wfrstatus $wleft.stat
    set wsearrows $wfrstatus.arr
    ttk::frame $wleft.stat
    ::UI::ChaseArrows $wfrstatus.arr
    ttk::label $wfrstatus.la -style Small.TLabel \
      -textvariable $token\(status)

    pack  $wfrstatus.arr  $wfrstatus.la  -side left -padx 2
    pack  $wfrstatus  -side top -anchor w
    
    # The Search result tablelist widget.
    set frsearch $wright.se
    set wtb      $frsearch.tb
    set wxsc     $frsearch.xsc
    set wysc     $frsearch.ysc
    frame $wright.se -bd 1 -relief sunken
    pack $wright.se -side top -fill both -expand 1
    tablelist::tablelist $wtb \
      -width 60 -height 20  \
      -columns [list 60 [mc {Search results}]]  \
      -xscrollcommand [list $wxsc set]  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns]]
    
    ttk::scrollbar $wysc -command [list $wtb yview] -orient vertical
    ttk::scrollbar $wxsc -command [list $wtb xview] -orient horizontal
    grid  $wtb   -column 0 -row 0 -sticky news
    grid  $wysc  -column 1 -row 0 -sticky ns
    grid  $wxsc  -column 0 -row 1 -sticky ew -columnspan 2
    grid rowconfigure    $frsearch 0 -weight 1
    grid columnconfigure $frsearch 0 -weight 1
    
    bind [$wtb bodytag] <Double-Button-1> { ::Search::TableCmd %W %x %y }
    bind [$wtb bodytag] <<ButtonPopup>>   { ::Search::TablePopup %W %x %y }
    
    wm minsize $w 400 320

    set state(wsearrows)     $wsearrows
    set state(wservice)      $wservice
    set state(wbtget)        $wbtget
    set state(wtb)           $wtb
    set state(wscrollframe)  $wscrollframe
    set state(wsearch)       $wsearch
    set state(wraplength)    $wraplength
    set state(status)        ""
	        
    # If only a single search service, or if specified as argument.
    set search 0
    if {[llength $searchServ] == 1} {
	set search 1
    } elseif {$argsArr(-autoget)} {
	set search 1
    }
    if {$search} {
	Get $w
    }
    bind $w <Destroy> \
      +[subst { if {"%W" eq "$w"} { [namespace code [list Free %W]] } }]
    
    return $w
}

proc ::Search::TableCmd {w x y} {
    
    lassign [tablelist::convEventFields $w $x $y] wtb xtb ytb
    set ind [$wtb containing $ytb]
        
    if {$ind >= 0} {
	set row [$wtb get $ind]
	set jid [string trim [lindex $row 0]]

	# Warn if already in our roster.
	if {[::Jabber::Jlib roster isitem $jid]} {
	    set ans [::UI::MessageBox -message [mc jamessalreadyinrost2 $jid] \
	      -icon error -title [mc Error] -type ok]
	} else {
	    ::JUser::NewDlg -jid $jid
	}
    }
}

proc ::Search::TablePopup {w x y} {
    variable popMenuDefs
    
    lassign [tablelist::convEventFields $w $x $y] wtb xtb ytb
    set ind [$wtb containing $ytb]
	
    if {$ind >= 0} {
	set row [$wtb get $ind]
	set jid [string trim [lindex $row 0]]

	
	
	# Make the appropriate menu.
	set m .popup_search
	catch {destroy $m}
	menu $m -tearoff 0  \
	  -postcommand [list ::Search::PostMenuCmd $m $jid]
	
	::AMenu::Build $m $popMenuDefs -varlist [list jid $jid]
	
	# This one is needed on the mac so the menu is built before it is posted.
	update idletasks
	
	# Post popup menu.	
	set X [expr [winfo rootx $w] + $x]
	set Y [expr [winfo rooty $w] + $y]
	tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
    }
}

proc ::Search::PostMenuCmd {m jid} {

    if {[::Jabber::Jlib roster isitem $jid]} {
	set midx [::AMenu::GetMenuIndex $m mAddContact...]
	$m entryconfigure $midx -state disabled
    }
}

proc ::Search::Get {w} {    
    variable $w
    upvar 0 $w state    
    
    # Verify.
    if {$state(server) eq ""} {
	::UI::MessageBox -type ok -icon error -title [mc Error] \
	  -message [mc jamessregnoserver2]
	return
    }	
    $state(wservice) state {disabled}
    $state(wbtget)   state {disabled}
    set state(status) "[mc jawaitserver]..."
    
    # Send get register.
    ::Jabber::Jlib search_get $state(server) [namespace code [list GetCB $w]]
    $state(wsearrows) start
    
    $state(wtb) configure -columns [list 60 [mc {Search results}]]
    $state(wtb) delete 0 end
}

# Search::GetCB --
#
#       This is the 'get' iq callback.
#       It should be possible to receive multiple callbacks for a single
#       search, but this is untested.

proc ::Search::GetCB {w jlibName type subiq} {
    global jprefs
    variable $w
    upvar 0 $w state    
    
    ::Debug 2 "::Search::GetCB type=$type, subiq='$subiq'"
    
    if {![info exists $state(w)]} {
	return
    }
    $state(wsearrows) stop
    $state(wservice) state {!disabled}
    $state(wbtget)   state {!disabled}
    set state(status) ""
    
    if {$type eq "error"} {
	set str [mc jamesserrsearch2]
	append str "\n" "[mc {Error code}]: [lindex $subiq 0]\n"
	append str "[mc Message]: [lindex $subiq 1]"
	::UI::MessageBox -type ok -icon error -title [mc Error] -message $str
	return
    }
    set subiqChildList [wrapper::getchildren $subiq]
    
    # We must figure out if we have an oob thing.
    set hasOOBForm 0
    foreach c $subiqChildList {
	if {[string equal [lindex $c 0] "x"]} {
	    array set cattrArr [lindex $c 1]
	    if {[info exists cattrArr(xmlns)] &&  \
	      [string equal $cattrArr(xmlns) "jabber:x:oob"]} {
		set hasOOBForm 1
		set xmlOOBElem $c
	    }
	}
    }
	
    # Build form dynamically from XML.
    set frint [::UI::ScrollFrameInterior $state(wscrollframe)]
    set wform $frint.f
    if {[winfo exists $wform]} {
	destroy $wform
    }
    set width [expr {$state(wraplength) - 40}]
    set formtoken [::JForms::Build $wform $subiq -tilestyle Small -width $width]
    pack $wform -fill both -expand 1
    
    ::JForms::BindEntry $wform <Return> +[list $state(wsearch) invoke]

    set state(formtoken) $formtoken

    if {0 && $hasOOBForm} {
	set woobtxt [::OOB::BuildText $woob.oob $xmlOOBElem]
	pack $woobtxt -side top -fill x
    }

    $state(wservice) state {!disabled}
    $state(wsearch)  configure -default active
    $state(wbtget)   configure -default disabled   
    $state(wsearch)  state {!disabled}
    $state(wbtget)   state {!disabled}
}

proc ::Search::DoSearch {w} {    
    global jprefs
    variable $w
    upvar 0 $w state    
    
    $state(wsearrows) start
    $state(wtb) delete 0 end
    set state(status) "Waiting for search result..."

    # Returns the hierarchical xml list starting with the <x> element.
    set subelements [::JForms::GetXML $state(formtoken)]
    set server $state(server)
    ::Jabber::Jlib search_set $server  \
      [namespace code [list ResultCallback $w $server]] -subtags $subelements
}

proc ::Search::HandleSetError {subiq} {
    
    foreach {ecode emsg} [lrange $subiq 0 1] break
    if {$ecode eq "406"} {
	set msg [mc jamesssearchinval2]
	append msg "\n[mc Message]: $emsg"
    } else {
	set msg [mc jamesssearcherr]
	append msg "\n" "[mc {Error code}]: $ecode"
	append msg "\n" "[mc Message]: $emsg"
    }
    ui::dialog -type ok -title [mc Error] -icon error -message $msg
}

# Search::ResultCallback --
#
#       This is the 'result' and 'set' iq callback We may get a number of server
#       pushing 'set' elements, finilized by the 'result' element.
#       
#       Update: the situation with jabber:x:data seems unclear here.
#       
# Arguments:
#       server:
#       type:       "result", "error", or "set"
#       subiq:

proc ::Search::ResultCallback {w server type subiq} {   
    global jprefs
    variable $w
    upvar 0 $w state    
    
    ::Debug 2 "::Search::ResultCallback server=$server, type=$type, subiq='$subiq'"
    
    if {![info exists $state(w)]} {
	return
    }
    $state(wsearrows) stop
    set state(status) ""
    if {[string equal $type "error"]} {
	HandleSetError $subiq
    } else {
	
	# This returns the search result and sets the reported stuff.
	set columnSpec [list]
	set wtb $state(wtb)
	set formtoken $state(formtoken)
	set resultList [::JForms::ResultList $formtoken $subiq]
	if {![llength $resultList]} {
	    $wtb insert end {{No matches found}}
	} else {
	    foreach {var label} [::JForms::GetReported $formtoken] {
		lappend columnSpec 0 $label	    
	    }
	    $wtb configure -columns $columnSpec
	    foreach row $resultList {
		$wtb insert end $row
	    }
	}
    }
}

proc ::Search::CloseCmd {w} {
    variable $w
    upvar 0 $w state    
    global  wDlgs
    
    ::UI::SaveWinPrefixGeom $wDlgs(jsearch)
    destroy $w
}

proc ::Search::Free {w} {
    variable $w
    unset -nocomplain $w
}

# Experiment: make a generic megawidget for displaying search results
# using xdata forms.

proc ::Search::BuildResultWidget {w} {
        
    set T $w.t
    set ysc $w.ysc
    
    ttk::frame $w
    ttk::scrollbar $ysc -orient vertical -command [list $T yview]
    
    treectrl $T -selectmode extended -showroot 0 \
      -showrootbutton 0 -showbuttons 0 -showheader 1 \
      -showrootlines 0 -showlines 0 \
      -yscrollcommand [list ::UI::ScrollSet $ysc     \
      [list grid $ysc -row 0 -column 1 -sticky ns]]  \
      -borderwidth 0 -highlightthickness 0            \
      -height 200 -width 300

    grid  $T    -column 0 -row 0 -sticky news
    grid  $ysc  -column 1 -row 0 -sticky ns -padx 2
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure    $w 0 -weight 1

    # The columns.
    $T column create -resize 0 -expand 1

    # The elements.
    $T element create eText text
    
    # Styles collecting the elements.
    set S [$T style create styUser]
    $T style elements $S {eText}
    $T style layout $S eText -squeeze x -expand ns -pady 2 -padx 4
    
    return $w 
}

proc ::Search::FillResultWidget {w xdataE} {
    
    set T $w.t
    
    $T item delete all
    $T column delete all
    $T item delete all
    
    set reportedE [wrapper::getfirstchildwithtag $xdataE reported]
    if {![llength $reportedE]} {
	# Error
	return
    }
    set reportedL [list]
    set styleSpecL [list]
    foreach fieldE [wrapper::getchildren $reportedE] {
	set var   [wrapper::getattribute $fieldE var]	    
	set label [wrapper::getattribute $fieldE label]
	set text $label
	if {$text eq ""} {
	    set text $var
	}
	set C [$T column create -text $text -tags $var -itemstyle styUser]
	lappend reportedL $var
	lappend styleSpecL $C styUser
    }
    foreach itemE [wrapper::getchildren $xdataE] {
	if {[wrapper::gettag $itemE] ne "item"} { continue }
	
	set id [$T item create -parent root]
	
	foreach fieldE [wrapper::getchildren $itemE] {
	    set var [wrapper::getattribute $fieldE var]
	    set valueE [lindex [wrapper::getchildren $fieldE] 0]
	    set text [wrapper::getcdata $valueE]
	    
	    $T item element configure $id $var eText -text $text
	}	
    }

    bind $T <<ButtonPopup>>   { ::Search::ResultOnPopup %W %x %y }
}

proc ::Search::ResultOnPopup {T x y} {
    variable popMenuDefs    
    
    set id [$T identify $x $y] 
    if {[lindex $id 0] eq "item"} {
	set item [lindex $id 1]
	set cid [$T column id jid]
	if {$cid eq ""} { return }
	set jid [$T item element cget $item $cid eText -text]
	if {$jid eq ""} { return }
	
	set m $T.m
	destroy $m
	menu $m -tearoff 0
	
	::AMenu::Build $m $popMenuDefs -varlist [list jid $jid]
	
	# This one is needed on the mac so the menu is built before it is posted.
	update idletasks
	
	# Post popup menu.
	set X [expr [winfo rootx $T] + $x]
	set Y [expr [winfo rooty $T] + $y]
	tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
    }
}

#--- Roster Slot --------------------------------------------------------------

namespace eval ::Search {
    
    variable slot
    set slot(all) [list]

    option add *SearchSlot.padding       {4 2 2 2}     50
    option add *SearchSlot.box.padding   {4 2 8 2}     50
    option add *SearchSlot*TLabel.style  Small.TLabel  widgetDefault
    option add *SearchSlot*TEntry.font   CociSmallFont widgetDefault

    ::JUI::SlotRegister search ::Search::SlotBuild

    ::hooks::register logoutHook    ::Search::SlotLogoutHook
    ::hooks::register discoInfoDirectoryUserHook  ::Search::SlotDiscoHook
}

proc ::Search::SlotBuild {w} {
    variable slot

    ttk::frame $w -class SearchSlot
    
    if {1} {
	set slot(collapse) 0
	ttk::checkbutton $w.arrow -style Arrow.TCheckbutton \
	  -command [list [namespace current]::SlotCollapse $w] \
	  -variable [namespace current]::slot(collapse)
	pack $w.arrow -side left -anchor n	
	bind $w       <<ButtonPopup>> [list [namespace current]::SlotPopup $w %x %y]
	bind $w.arrow <<ButtonPopup>> [list [namespace current]::SlotPopup $w %x %y]

	set im  [::Theme::FindIconSize 16 close-aqua]
	set ima [::Theme::FindIconSize 16 close-aqua-active]
	ttk::button $w.close -style Plain  \
	  -image [list $im active $ima] -compound image  \
	  -command [namespace code [list SlotClose $w]]
	pack $w.close -side right -anchor n	

        ::balloonhelp::balloonforwindow $w.arrow [mc "Right click to get the selector"]
	::balloonhelp::balloonforwindow $w.close [mc "Close Slot"]
    }    
    set imsearch [::Theme::FindIconSize 16 service-directory-user]
    set box $w.box
    ttk::frame $box
    pack $box -fill x -expand 1

    ttk::label $box.l -compound image -image $imsearch
    ttk::entry $box.e -style Small.Search.TEntry -font CociSmallFont \
      -textvariable [namespace current]::slot(text)
    
    grid  $box.l  $box.e
    grid  $box.e  -sticky ew
    grid columnconfigure $box 1 -weight 1
    
    $box.e state {disabled}

    bind $box.e <Return>   [namespace code SlotSearch]
    bind $box.e <KP_Enter> [namespace code SlotSearch]
    bind $box.e <FocusIn>  [namespace code SlotEntryFocusIn]

    bind $box.l <<ButtonPopup>> [list [namespace current]::SlotPopup $w %x %y]
    bind $box.e <<ButtonPopup>> [list [namespace current]::SlotPopup $w %x %y]
    
    set slot(w)     $w
    set slot(box)   $w.box
    set slot(entry) $box.e
    set slot(show)  1
    set slot(dtext) "Search People in Directory"
    set slot(text)  [mc $slot(dtext)]
    
    # Hardcoded :-( See comments below. Just to pick some.
    set slot(fields) [list user fn given email]
    set slot(label,user)  [mc "User"]
    set slot(label,fn)    [mc "Full Name"]
    set slot(label,given) [mc "Name"]
    set slot(label,email) [mc "Email"]

    set slot(display,user)  1
    set slot(display,fn)    0
    set slot(display,given) 0
    set slot(display,email) 0

    ::balloonhelp::balloonforwindow $box   $slot(text)
    ::balloonhelp::balloonforwindow $box.l $slot(text)
    ::balloonhelp::balloonforwindow $box.e $slot(text)

    foreach m [::JUI::SlotGetAllMenus] {
	$m add checkbutton -label [mc "Directory Search"] \
	  -variable [namespace current]::slot(show) \
	  -command [namespace code SlotCmd]
    }    
    return $w
}

proc ::Search::SlotCollapse {w} {
    variable slot

    if {$slot(collapse)} {
	pack forget $slot(box)
    } else {
	pack $slot(box) -fill both -expand 1
    }
    #event generate $w <<Xxx>>
}

proc ::Search::SlotPopup {w x y} {
    variable slot
    
    # NB: only <field type='text-single' .../> are considered.

    set m $w.m
    destroy $m
    menu $m -tearoff 0
    
    foreach field $slot(fields) {
	$m add checkbutton -label $slot(label,$field) \
	  -command [namespace code [list SlotMenuCmd $w $field]] \
	  -variable [namespace current]::slot(display,$field)
    }
    
    update idletasks
    
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    tk_popup $m [expr {int($X) - 0}] [expr {int($Y) - 0}]   
    
    return -code break
}

proc ::Search::SlotCmd {} {
    if {[::JUI::SlotShowed search]} {
	::JUI::SlotClose search
    } else {
	::JUI::SlotShow search
    }    
}

proc ::Search::SlotMenuCmd {w field} {
    
    ::balloonhelp::balloonforwindow $w [mc $field]
    
}

proc ::Search::SlotDiscoHook {type from queryE args} {
    variable slot
    
    if {$type eq "result"} {
	$slot(entry) state {!disabled}
    }
}

proc ::Search::SlotLogoutHook {} {
    variable slot
    $slot(entry) state {disabled}
}

proc ::Search::SlotEntryFocusIn {} {
    variable slot
    
    if {[$slot(entry) get] eq [mc $slot(dtext)]} {
	set slot(text) ""
    }
}

proc ::Search::SlotClose {w} {
    variable slot
    set slot(show) 0
    ::JUI::SlotClose search
}

proc ::Search::SlotSearch {} {
    variable slot
   
    # Select service. Preferrably on the same domain as the server.
    set servicesL [::Jabber::Jlib disco getjidsforfeature "jabber:iq:search"]
    set server [::Jabber::Jlib getserver]
    set jud [lsearch -inline -glob $servicesL *.$server]
    if {$jud eq ""} {
	set jud [lindex $servicesL 0]
    }
    set slot(jud) $jud
    
    # Keep a dict on the stack for some data.
    set slotD [dict create]
    dict set slotD jud $jud
    
    ::Jabber::Jlib search_get $jud [namespace code [list SlotGetCB $slotD]]
}

proc ::Search::SlotGetCB {slotD jlibname type queryE} {
    variable slot
    
    # Try match up the search criteria with what the service supports.
    # MB: It should have been the other way around but I don't want to
    #     do a search get for every login. Maybe I just cache it here?
        
    set xE [wrapper::getfirstchild $queryE x "jabber:x:data"]
    if {![llength $xE]} {
	ui::dialog -icon error -message "Search service \"$slot(jud)\" didn't return expected search elements."
	return
    }
    set slot(queryE) $queryE
    
    set xmllist [list]
    set text [string trim $slot(text)]
    set type "text-single"

    foreach E [wrapper::getchildren $xE] {
	if {[wrapper::gettag $E] eq "field"} {
	    set var [wrapper::getattribute $E var]
	    if {$var in $slot(fields)} {
		if {$slot(display,$var)} {
		    set valueE [wrapper::createtag value -chdata $text]
		    set fieldE [wrapper::createtag field \
		      -attrlist [list type $type var $var] \
		      -subtags [list $valueE]]
		    lappend xmllist $fieldE
		}
	    }	    
	}
    }
    set searchE [wrapper::createtag x  \
      -attrlist {xmlns jabber:x:data type submit} -subtags $xmllist]
    
    ::Jabber::Jlib search_set $slot(jud) [namespace code [list SlotSetCB $slotD]] \
      -subtags [list $searchE]
}

proc ::Search::SlotSetCB {slotD type queryE} {
    variable slot

    if {$type eq "error"} {
	HandleSetError $subiq
    } else {
	set xE [wrapper::getfirstchild $queryE x "jabber:x:data"]
	if {![llength $xE]} {
	    ui::dialog -icon error -message "Search service \"$slot(jud)\" didn't return expected search elements."
	    return
	}
	set w .search_slot
	if {![winfo exists $w]} {
	    SlotBuildResult $w $slotD
	}
	set wres [SlotResultGetWidget $w]
	FillResultWidget $wres $xE
    }
}

proc ::Search::SlotBuildResult {w slotD} {
    
    set jud [dict get $slotD jud]
        
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document {closeBox resizable}}  \
      -closecommand [namespace code SlotResultCloseCmd]
    wm title $w "[mc Search]: $jud"

    ::UI::SetWindowGeometry $w

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set wres $wbox.res
    
    BuildResultWidget $wres
    
    pack $wres -side top -fill both -expand 1
    
    set wbot $wbox.bot
    
    ttk::frame $wbot -padding [option get . okcancelTopPadding {}]
    ttk::button $wbot.close -text [mc Close] \
      -command [namespace code [list SlotResultCloseCmd $w]]
    
    pack $wbot -side bottom -fill x
    pack $wbot.close  -side right

}

proc ::Search::SlotResultGetWidget {w} {
    return $w.frall.f.res
}

proc ::Search::SlotResultCloseCmd {w} {
    ::UI::SaveWinGeom $w
    destroy $w
}

#-------------------------------------------------------------------------------

