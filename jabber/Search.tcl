#  Search.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements search UI parts for jabber.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Search.tcl,v 1.8 2004-01-14 14:27:30 matben Exp $

package provide Search 1.0


namespace eval ::Jabber::Search:: {

    # Wait for this variable to be set.
    variable finished  
}

# Jabber::Search::Build --
#
#       Initiates the process of searching a service.
#       
# Arguments:
#       args   -server, -autoget 0/1
#       
# Results:
#       .
     
proc ::Jabber::Search::Build {args} {
    global  this prefs wDlgs

    variable wtop
    variable wbox
    variable wbtsearch
    variable wbtget
    variable wcomboserver
    variable wtb
    variable wxsc
    variable wysc
    variable woob
    variable server
    variable wsearrows
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    set w $wDlgs(jsearch)
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    set finished -1
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1
    wm title $w [::msgcat::mc {Search Service}]
    set wtop $w
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 6 -ipady 4
    
    # Left half.
    set wleft $w.frall.fl
    pack [frame $wleft] -side left -fill y
    
    # Right half.
    set wright $w.frall.fr
    pack [frame $wright] -side right -expand 1 -fill both
    
    message $wleft.msg -width 200  \
      -text [::msgcat::mc jasearch] -anchor w
    pack $wleft.msg -side top -fill x -anchor w -padx 4 -pady 2
    set frtop $wleft.top
    pack [frame $frtop] -side top -fill x -anchor w -padx 4 -pady 2
    label $frtop.lserv -text "[::msgcat::mc {Search Service}]:" -font $fontSB
    
    # Button part.
    set frbot [frame $wleft.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtsearch $frbot.btenter
    pack [button $wbtsearch -text [::msgcat::mc Search] -width 8 -state disabled \
      -command [namespace current]::DoSearch]  \
      -side right -padx 5 -pady 2
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command "destroy $w"]  \
      -side right -padx 5 -pady 2
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 2
    pack $frbot -side bottom -fill x -padx 8 -pady 6
    
    # OOB alternative.
    set woob [frame $wleft.foob]
    pack $woob -side bottom -fill x -padx 8 -pady 0
    
    # Get all (browsed) services that support search.
    set searchServ [::Jabber::InvokeJlibCmd service getjidsfor "search"]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20   \
      -textvariable [namespace current]::server -editable 0
    eval {$frtop.eserv list insert end} $searchServ
    
    # Find the default search server.
    if {[llength $searchServ]} {
	set server [lindex $searchServ 0]
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    
    # Get button.
    set wbtget $frtop.btget
    button $wbtget -text [::msgcat::mc Get] -width 6 -default active \
      -command [list ::Jabber::Search::Get]

    grid $frtop.lserv -sticky w
    grid $wcomboserver -row 1 -column 0 -sticky ew
    grid $wbtget -row 1 -column 1 -sticky e -padx 2

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
    set wfr $wleft.frlab
    set wcont [::mylabelframe::mylabelframe $wfr [::msgcat::mc {Search Specifications}]]
    pack $wfr -side top -fill both -padx 2 -pady 2

    set wbox [frame $wcont.box]
    pack $wbox -side left -fill both -padx 4 -pady 4 -expand 1
    pack [label $wbox.la -textvariable "[namespace current]::stattxt"]  \
      -padx 0 -pady 10 -side left
    set stattxt "-- [::msgcat::mc jasearchwait] --"
    
    # The Search result tablelist widget.
    set frsearch $wright.se
    pack [frame $frsearch -borderwidth 1 -relief sunken] -side top -fill both \
      -expand 1 -padx 4 -pady 4
    set wtb $frsearch.tb
    set wxsc $frsearch.xsc
    set wysc $frsearch.ysc
    tablelist::tablelist $wtb \
      -columns [list 60 [::msgcat::mc {Search results}]]  \
      -xscrollcommand [list $wxsc set] -yscrollcommand [list $wysc set]  \
      -width 60 -height 20
    #-labelcommand "[namespace current]::LabelCommand"  \
    
    scrollbar $wysc -orient vertical -command [list $wtb yview]
    scrollbar $wxsc -orient horizontal -command [list $wtb xview]
    grid $wtb $wysc -sticky news
    grid $wxsc -sticky ew -column 0 -row 1
    grid rowconfigure $frsearch 0 -weight 1
    grid columnconfigure $frsearch 0 -weight 1
    
    wm minsize $w 400 320
	    
    # If only a single search service, or if specified as argument.
    if {([llength $searchServ] == 1) ||  \
      [info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	::Jabber::Search::Get
    }
}

proc ::Jabber::Search::Get { } {    
    variable server
    variable wsearrows
    variable wcomboserver
    variable wbtget
    variable wtb
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    # Verify.
    if {[string length $server] == 0} {
	tk_messageBox -type ok -icon error  \
	  -message [::msgcat::mc jamessregnoserver]
	return
    }	
    $wcomboserver configure -state disabled
    $wbtget configure -state disabled
    set stattxt "-- [::msgcat::mc jawaitserver] --"
    
    # Send get register.
    ::Jabber::InvokeJlibCmd search_get $server ::Jabber::Search::GetCB    
    $wsearrows start
    
    $wtb configure -columns [list 60 [::msgcat::mc {Search results}]]
    $wtb delete 0 end
}

# Jabber::Search::GetCB --
#
#       This is the 'get' iq callback.
#       It should be possible to receive multiple callbacks for a single
#       search, but this is untested.

proc ::Jabber::Search::GetCB {jlibName type subiq} {
    
    variable wtop
    variable wbox
    variable wtb
    variable wxsc
    variable wysc
    variable woob
    variable wsearrows
    variable wbtsearch
    variable wbtget
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Search::GetCB type=$type, subiq='$subiq'"
    
    if {![winfo exists $wtop]} {
	return
    }
    $wsearrows stop
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrsearch [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }
    catch {destroy $wbox}
    catch {destroy $woob.oob}
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
    ::Jabber::Forms::Build $wbox $subiqChildList -template "search" -width 160
    pack $wbox -side left -padx 2 -pady 10
    if {$hasOOBForm} {
	set woobtxt [::Jabber::OOB::BuildText ${woob}.oob $xmlOOBElem]
	pack $woobtxt -side top -fill x
    }
    $wbtsearch configure -state normal -default active
    $wbtget configure -state normal -default disabled   
}

proc ::Jabber::Search::DoSearch { } {    
    variable server
    variable wsearrows
    variable wbox
    variable wtb
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    $wsearrows start
    $wtb delete 0 end

    # Returns the hierarchical xml list starting with the <x> element.
    set subelements [::Jabber::Forms::GetXML $wbox]    
    ::Jabber::InvokeJlibCmd search_set $server  \
      [list [namespace current]::ResultCallback $server] -subtags $subelements
}

# Jabber::Search::ResultCallback --
#
#       This is the 'result' and 'set' iq callback We may get a number of server
#       pushing 'set' elements, finilized by the 'result' element.
#       
#       Update: the situation with jabber:x:data seems unclear here.
#       
# Arguments:
#       server:
#       type:       "ok", "error", or "set"
#       subiq:

proc ::Jabber::Search::ResultCallback {server type subiq} {   
    variable wtop
    variable wtb
    variable wbox
    variable wsearrows
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Search::ResultCallback server=$server, type=$type, \
      subiq='$subiq'"
    
    if {![winfo exists $wtop]} {
	return
    }
    $wsearrows stop
    if {[string equal $type "error"]} {
	foreach {ecode emsg} [lrange $subiq 0 1] break
	if {$ecode == "406"} {
	    set msg "There was an invalid field. Please correct it: $emsg"
	} else {
	    set msg "Failed searching service. Error code $ecode with message: $emsg"
	}
	tk_messageBox -type ok -icon error -message [FormatTextForMessageBox $msg]
	return
    } elseif {[string equal $type "ok"]} {
	
	# This returns the search result and sets the reported stuff.
	set columnSpec {}
	set resultList [::Jabber::Forms::ResultList $wbox $subiq]
	foreach {var label} [::Jabber::Forms::GetReported $wbox] {
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

#-------------------------------------------------------------------------------
