#  Search.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements search UI parts for jabber.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Search.tcl,v 1.24 2006-05-17 06:35:02 matben Exp $

package provide Search 1.0


namespace eval ::Search:: {

    # Wait for this variable to be set.
    variable finished  

    variable popMenuDefs
    
    set popMenuDefs {
	{command    mAddNewUser  {::Jabber::User::NewDlg -jid $jid} }
	{command    mvCard       {::VCard::Fetch other $jid} }	
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

    variable sstate
    upvar ::Jabber::jstate jstate
    
    set w $wDlgs(jsearch)
    if {[winfo exists $w]} {
	return
    }
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
    wm title $w [mc {Search Service}]
    set sstate(w) $w

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
      -text [mc jasearch]
    pack $wleft.msg -side top -anchor w
    
    set frtop $wleft.top
    ttk::frame $frtop
    pack $frtop -side top -fill x -anchor w
    
    # Button part.
    set frbot     $wleft.frbot
    set wbtsearch $frbot.search
    ttk::frame $frbot
    ttk::button $frbot.search -text [mc Search] \
      -command [namespace current]::DoSearch
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list ::Search::CloseCmd $w]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.search   -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.search   -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    $wbtsearch state {disabled}
    
    # OOB alternative.
    set woob $wleft.foob
    ttk::frame $wleft.foob
    pack $wleft.foob -side bottom -fill x
    
    # Get all (browsed) services that support search.
    set searchServ [::Jabber::JlibCmd disco getjidsforfeature "jabber:iq:search"]
    set wcomboserver $frtop.eserv
    set wbtget       $frtop.btget
    ttk::label    $frtop.lserv -text "[mc {Search Service}]:"
    ttk::button   $frtop.btget -text [mc Get] -default active \
      -command [list ::Search::Get]
    ttk::combobox $frtop.eserv -values $searchServ \
      -textvariable [namespace current]::sstate(server) -state readonly

    grid  $frtop.lserv  $frtop.btget  -sticky w  -pady 2
    grid  $frtop.eserv  -             -sticky ew -pady 2
    grid columnconfigure $frtop 0 -weight 1
    
    # Find the default search server.
    set sstate(server) ""
    if {$searchServ != {}} {
	set sstate(server) [lindex $searchServ 0]
    }
    if {$argsArr(-server) != ""} {
	set sstate(server) $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    if {$searchServ eq {}} {
	$wbtget       state {disabled}
	$wcomboserver state {disabled}
    }
    
    set wscrollframe $wleft.frsc
    ::UI::ScrollFrame $wscrollframe -padding {8 12} -bd 1 -relief sunken \
      -propagate 0 -width $wraplength
    pack $wscrollframe -fill both -expand 1 -pady 4

    
    # Status part.
    set wfrstatus $wleft.stat
    set wsearrows $wfrstatus.arr
    ttk::frame $wleft.stat
    ::chasearrows::chasearrows $wfrstatus.arr -size 16
    ttk::label $wfrstatus.la -style Small.TLabel \
      -textvariable [namespace current]::sstate(status)

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

    set sstate(wsearrows)     $wsearrows
    set sstate(wcomboserver)  $wcomboserver
    set sstate(wbtget)        $wbtget
    set sstate(wtb)           $wtb
    set sstate(wscrollframe)  $wscrollframe
    set sstate(wbtsearch)     $wbtsearch
    set sstate(wraplength)    $wraplength
    set sstate(status)        ""
	        
    # If only a single search service, or if specified as argument.
    set search 0
    if {[llength $searchServ] == 1} {
	set search 1
    } elseif {$argsArr(-autoget)} {
	set search 1
    }
    if {$search} {
	::Search::Get
    }
}

proc ::Search::TableCmd {w x y} {
    upvar ::Jabber::jstate jstate
    
    lassign [tablelist::convEventFields $w $x $y] wtb xtb ytb
    set ind [$wtb containing $ytb]
        
    if {$ind >= 0} {
	set row [$wtb get $ind]
	set jid [string trim [lindex $row 0]]

	# Warn if already in our roster.
	if {[$jstate(roster) isitem $jid]} {
	    set ans [::UI::MessageBox -message [mc jamessalreadyinrost $jid] \
	      -icon error -type ok]
	} else {
	    ::Jabber::User::NewDlg -jid $jid
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

    if {[$jstate(roster) isitem $jid]} {
	set midx [::AMenu::GetMenuIndex $m mAddNewUser]
	$m entryconfigure $midx -state disabled
    }
}

proc ::Search::Get { } {    
    variable sstate
    upvar ::Jabber::jstate jstate
    
    # Verify.
    if {$sstate(server) eq ""} {
	::UI::MessageBox -type ok -icon error  \
	  -message [mc jamessregnoserver]
	return
    }	
    $sstate(wcomboserver) state {disabled}
    $sstate(wbtget)       state {disabled}
    set sstate(status) [mc jawaitserver]
    
    # Send get register.
    ::Jabber::JlibCmd search_get $sstate(server) ::Search::GetCB    
    $sstate(wsearrows) start
    
    $sstate(wtb) configure -columns [list 60 [mc {Search results}]]
    $sstate(wtb) delete 0 end
}

# Search::GetCB --
#
#       This is the 'get' iq callback.
#       It should be possible to receive multiple callbacks for a single
#       search, but this is untested.

proc ::Search::GetCB {jlibName type subiq} {
    variable sstate
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Search::GetCB type=$type, subiq='$subiq'"
    
    if {![winfo exists $sstate(w)]} {
	return
    }
    $sstate(wsearrows) stop
    set sstate(status) ""
    
    if {$type eq "error"} {
	::UI::MessageBox -type ok -icon error  \
	  -message [mc jamesserrsearch [lindex $subiq 0] [lindex $subiq 1]]
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
    set frint [::UI::ScrollFrameInterior $sstate(wscrollframe)]
    set wform $frint.f
    if {[winfo exists $wform]} {
	destroy $wform
    }
    set width [expr {$sstate(wraplength) - 40}]
    set formtoken [::JForms::Build $wform $subiq -tilestyle Small -width $width]
    pack $wform -fill both -expand 1
    
    ::JForms::BindEntry $wform <Return> +[list $sstate(wbtsearch) invoke]

    set sstate(formtoken) $formtoken

    if {0 && $hasOOBForm} {
	set woobtxt [::OOB::BuildText $woob.oob $xmlOOBElem]
	pack $woobtxt -side top -fill x
    }

    $sstate(wbtsearch) configure -default active
    $sstate(wbtget)    configure -default disabled   
    $sstate(wbtsearch) state {!disabled}
    $sstate(wbtget)    state {!disabled}
}

proc ::Search::DoSearch { } {    
    variable sstate
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    $sstate(wsearrows) start
    $sstate(wtb) delete 0 end
    set sstate(status) "Waiting for search result..."

    # Returns the hierarchical xml list starting with the <x> element.
    set subelements [::JForms::GetXML $sstate(formtoken)]
    set server $sstate(server)
    ::Jabber::JlibCmd search_set $server  \
      [list [namespace current]::ResultCallback $server] -subtags $subelements
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

proc ::Search::ResultCallback {server type subiq} {   
    variable sstate
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Search::ResultCallback server=$server, type=$type, \
      subiq='$subiq'"
    
    if {![winfo exists $sstate(w)]} {
	return
    }
    $sstate(wsearrows) stop
    set sstate(status) ""
    if {[string equal $type "error"]} {
	foreach {ecode emsg} [lrange $subiq 0 1] break
	if {$ecode eq "406"} {
	    set msg "There was an invalid field. Please correct it: $emsg"
	} else {
	    set msg "Failed searching service. Error code $ecode with message: $emsg"
	}
	::UI::MessageBox -type ok -icon error -message $msg
	return
    } else {
	
	# This returns the search result and sets the reported stuff.
	set columnSpec {}
	set wtb $sstate(wtb)
	set formtoken $sstate(formtoken)
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
    global  wDlgs
    
    ::UI::SaveWinPrefixGeom $wDlgs(jsearch)
    destroy $w
}

#-------------------------------------------------------------------------------
