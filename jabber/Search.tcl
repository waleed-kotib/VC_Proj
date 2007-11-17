#  Search.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements search UI parts for jabber.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
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
# $Id: Search.tcl,v 1.40 2007-11-17 14:15:05 matben Exp $

package provide Search 1.0


namespace eval ::Search:: {

    # Wait for this variable to be set.
    variable finished  

    variable popMenuDefs
    
    set popMenuDefs {
	{command    mAddContact...      {::JUser::NewDlg -jid $jid} }
	{command    mBusinessCard...    {::VCard::Fetch other $jid} }	
    }

    option add *SearchSlot.padding       {4 2 2 2}     50
    option add *SearchSlot.box.padding   {4 2 8 2}     50
    option add *SearchSlot*TLabel.style  Small.TLabel  widgetDefault
    option add *SearchSlot*TEntry.font   CociSmallFont widgetDefault
    
    variable widgets
    set widgets(all) [list]

    # ::hooks::register initHook
    ::JUI::SlotRegister search ::Search::SlotBuild
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
    upvar ::Jabber::jstate jstate
    
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
    set searchServ [$jstate(jlib) disco getjidsforfeature "jabber:iq:search"]
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
    ::chasearrows::chasearrows $wfrstatus.arr -size 16
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
    upvar ::Jabber::jstate jstate
    
    lassign [tablelist::convEventFields $w $x $y] wtb xtb ytb
    set ind [$wtb containing $ytb]
        
    if {$ind >= 0} {
	set row [$wtb get $ind]
	set jid [string trim [lindex $row 0]]

	# Warn if already in our roster.
	if {[$jstate(jlib) roster isitem $jid]} {
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
    upvar ::Jabber::jstate jstate

    if {[$jstate(jlib) roster isitem $jid]} {
	set midx [::AMenu::GetMenuIndex $m mAddContact...]
	$m entryconfigure $midx -state disabled
    }
}

proc ::Search::Get {w} {    
    variable $w
    upvar 0 $w state    
    upvar ::Jabber::jstate jstate
    
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
    $jstate(jlib) search_get $state(server) [namespace code [list GetCB $w]]
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
    variable $w
    upvar 0 $w state    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
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
    variable $w
    upvar 0 $w state    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    $state(wsearrows) start
    $state(wtb) delete 0 end
    set state(status) "Waiting for search result..."

    # Returns the hierarchical xml list starting with the <x> element.
    set subelements [::JForms::GetXML $state(formtoken)]
    set server $state(server)
    ::Jabber::JlibCmd search_set $server  \
      [namespace code [list ResultCallback $w $server]] -subtags $subelements
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
    variable $w
    upvar 0 $w state    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Search::ResultCallback server=$server, type=$type, \
      subiq='$subiq'"
    
    if {![info exists $state(w)]} {
	return
    }
    $state(wsearrows) stop
    set state(status) ""
    if {[string equal $type "error"]} {
	foreach {ecode emsg} [lrange $subiq 0 1] break
	if {$ecode eq "406"} {
	    set msg [mc jamesssearchinval2]
	    append msg "\n[mc Message]: $emsg"
	} else {
	    set msg [mc jamesssearcherr]
	    append msg "\n" "[mc {Error code}]: $ecode"
	    append msg "\n" "[mc Message]: $emsg"
	}
	::UI::MessageBox -type ok -title [mc Error] -icon error -message $msg
	return
    } else {
	
	# This returns the search result and sets the reported stuff.
	set columnSpec [list]
	set wtb $state(wtb)
	set formtoken $state(formtoken)
	set resultList [::JForms::ResultList $formtoken $subiq]
	foreach {var label} [::JForms::GetReported $formtoken] {
	    lappend columnSpec 0 $label	    
	}
	$wtb configure -columns $columnSpec
	if {[llength $resultList] == 0} {
	    $wtb insert end {{No matches found}}
	} else {
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

#--- Roster Slot --------------------------------------------------------------

proc ::Search::SlotBuild {w} {
    variable widgets

    ttk::frame $w -class SearchSlot
    
    if {1} {
	set widgets(collapse) 0
	ttk::checkbutton $w.arrow -style Arrow.TCheckbutton \
	  -command [list [namespace current]::SlotCollapse $w] \
	  -variable [namespace current]::widgets(collapse)
	pack $w.arrow -side left -anchor n	
	bind $w.arrow <<ButtonPopup>> [list [namespace current]::SlotPopup $w %x %y]

	set subPath [file join images 16]
	set im  [::Theme::GetImage closeAqua $subPath]
	set ima [::Theme::GetImage closeAquaActive $subPath]
	ttk::button $w.close -style Plain  \
	  -image [list $im active $ima] -compound image  \
	  -command [namespace code [list SlotClose $w]]
	pack $w.close -side right -anchor n	
    }    
    set box $w.box
    set widgets(box) $w.box
    ttk::frame $box
    pack $box -fill x -expand 1
    
    ttk::label $box.l -text "Search JUD:"
    ttk::entry $box.e
    
    grid  $box.l  $box.e
    grid $box.e -sticky ew
    grid columnconfigure $box 1 -weight 1
    
    return $w
}

proc ::Search::SlotCollapse {w} {
    variable widgets

    if {$widgets(collapse)} {
	pack forget $widgets(box)
    } else {
	pack $widgets(box) -fill both -expand 1
    }
    event generate $w <<Xxx>>
}

proc ::Search::SlotPopup {w x y} {
    variable widgets
    
    set m $w.m
    destroy $m
    menu $m -tearoff 0
    
    foreach field {Name JID "First Name"} {
	$m add checkbutton -label $field \
	  -command [namespace code [list SlotMenuCmd $w $field]] \
	  -variable [namespace current]::widgets($field,display)
    }
    
    update idletasks
    
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    tk_popup $m [expr {int($X) - 0}] [expr {int($Y) - 0}]   
    
    return -code break
}

proc ::Search::SlotMenuCmd {w field} {
    
    
}

proc ::Search::SlotClose {w} {
    ::JUI::SlotClose search
}

#-------------------------------------------------------------------------------
