#  Adhoc.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements XEP-0050: Ad-Hoc Commands
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# $Id: Adhoc.tcl,v 1.1 2007-05-17 14:42:16 matben Exp $

package provide Adhoc 1.0

namespace eval ::Adhoc {

    ::hooks::register discoInfoHook                   ::Adhoc::DiscoInfoHook
    ::hooks::register discoPostCommandHook            ::Adhoc::PostMenuHook
    ::hooks::register logoutHook                      ::Adhoc::LogoutHook
    
    variable prefs
    set prefs(autoDisco) 1
    
    variable state
    
    variable xmlns
    set xmlns(commands) "http://jabber.org/protocol/commands"
    
    variable uid 0
}

proc ::Adhoc::DiscoInfoHook {type from queryE args} {
    variable xmlns
    variable prefs

    if {!$prefs(autoDisco)} {
	return
    }
    if {$type eq "error"} {
	return
    }
    set node [wrapper::getattribute $queryE node]
    if {[::Jabber::JlibCmd disco hasfeature $xmlns(commands) $from]} {
	GetCommandList $from [namespace code GetCommandListCB]
    }
}

proc ::Adhoc::LogoutHook {} {
    variable state

    unset -nocomplain state
}

proc ::Adhoc::GetCommandList {jid cmd} {
    variable xmlns
    ::Jabber::JlibCmd disco get_async items $jid $cmd -node $xmlns(commands)
}

proc ::Adhoc::GetCommandListCB {jlibname type from queryE args} {
    
    return
    if {$type eq "error"} {
	return
    }
    unset -nocomplain state($from,items)
    foreach itemE [wrapper::wrapper::getchildren $queryE] {
	if {[wrapper::gettag $itemE] eq "item"} {
	    
	    
	    
	}
    }
    
}

proc ::Adhoc::PostMenuHook {m clicked jid node} {
    variable xmlns
    
    #puts "::Adhoc::PostMenuHook m=$m, clicked=$clicked, jid=$jid, node=$node"
    
    if {![::Jabber::JlibCmd disco hasfeature $xmlns(commands) $jid $node]} {
	return
    }
    set name "Ad-Hoc Commands"
    set midx [::AMenu::GetMenuIndex $m $name]
    if {$midx eq ""} {
	# Probably a submenu.
	return
    }
    $m entryconfigure $midx -state normal
    set mt [$m entrycget $midx -menu]
    set xmllist [::Jabber::JlibCmd disco getxml items $jid $xmlns(commands)]
    set queryE [wrapper::getfirstchildwithtag $xmllist query]
    foreach itemE [::wrapper::getchildren $queryE] {
	if {[wrapper::gettag $itemE] eq "item"} {
	    set jid  [wrapper::getattribute $itemE jid]
	    set node [wrapper::getattribute $itemE node]
	    set name [wrapper::getattribute $itemE name]
	    set label $name
	    if {$label eq ""} {
		set label $jid
	    }
	    $mt add command -label "$label..." \
	      -command [namespace code [list Execute $jid $node]]
	}
    }
}

proc ::Adhoc::Execute {jid node} {
    variable xmlns

    set commandE [wrapper::createtag command \
      -attrlist [list xmlns $xmlns(commands) node $node action execute]]
    ::Jabber::JlibCmd send_iq set [list $commandE] -to $jid \
      -command [namespace code [list ExecuteCB $jid $node]] \
      -xml:lang [jlib::getlang]
}

proc ::Adhoc::ExecuteCB {jid node type subiq args} {

    if {$type eq "error"} {
	set errcode [lindex $subiq 0]
	set errmsg  [lindex $subiq 1]
	ui::dialog -icon error -title [mc Error] \
	  -message "Ad-Hoc command to $jid ($node) failed because: $errmsg"
    } else {
	BuildDlg $jid $node $subiq
    }
}

proc ::Adhoc::BuildDlg {jid node queryE} {
    global  wDlgs
    variable uid
    
    set w $wDlgs(jadhoc)[incr uid]
    ::UI::Toplevel $w -class AdHoc  \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace code Close]
    wm title $w "Ad-Hoc for $jid and $node"

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jadhoc)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jadhoc)
    }

    ttk::frame $w.all -padding [option get . dialogPadding {}]
    pack $w.all -side top -fill both -expand 1

    set wform $w.all.form
    set ftoken [::JForms::Build $wform $queryE -width 300]
    pack $wform -side top -fill both -expand 1

    set bot $w.all.bot
    ttk::frame $bot -padding [option get . okcancelTopPadding {}]
    ttk::button $bot.close -text [mc Close] -default active \
      -command [namespace code [list Close $w]]
    ttk::button $bot.next -text [mc Next] \
      -command [namespace code [list Next $w]]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $bot.close -side right
	pack $bot.next -side right -padx $padx
    } else {
	pack $bot.next -side right
	pack $bot.close -side right -padx $padx
    }
    ::chasearrows::chasearrows $bot.arr -size 16
    pack $bot.arr -side left -padx 5 -pady 5
    
    pack $bot -side bottom -fill x
    

    variable $w
    upvar 0 $w state    

    # Collect some useful attributes.
    set sessionid [wrapper::getattribute $queryE sessionid]
    set status    [wrapper::getattribute $queryE status]

    set state(w)          $w
    set state(wform)      $wform
    set state(wclose)     $bot.close
    set state(wnext)      $bot.next
    set state(warrows)    $bot.arr
    set state(ftoken)     $ftoken
    set state(jid)        $jid
    set state(node)       $node
    set state(sessionid)  $sessionid
    set state(status)     $status
    
    if {$status eq "completed"} {
	$bot.next state {disabled}
    }
}

proc ::Adhoc::Next {w} {
    variable $w
    upvar 0 $w state
    variable xmlns
    
    $state(warrows) start
    $state(wnext) state {disabled}
    
    set commandE [wrapper::createtag command \
      -attrlist [list xmlns $xmlns(commands) node $node action execute]]
    ::Jabber::JlibCmd send_iq set [list $commandE] -to $jid \
      -command [namespace code [list NextCB $w]] \
      -xml:lang [jlib::getlang]
}

proc ::Adhoc::NextCB {w type queryE args} {
    
    if {![winfo exists $w]} {
	return
    }
    $state(warrows) stop
    $state(wnext) state {!disabled}
    
    if {$type eq "error"} {
	set errcode [lindex $subiq 0]
	set errmsg  [lindex $subiq 1]
	ui::dialog -icon error -title [mc Error] \
	  -message "Ad-Hoc command to $jid ($node) failed because: $errmsg"
    } else {

    }
}

proc ::Adhoc::Close {w} {
    global  wDlgs
    variable $w
    upvar 0 $w state
    
    ::UI::SaveWinGeom $wDlgs(jadhoc) $w
    unset -nocomplain state
    destroy $w
    return
}

