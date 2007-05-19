#  Adhoc.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements XEP-0050: Ad-Hoc Commands
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# $Id: Adhoc.tcl,v 1.3 2007-05-19 06:48:24 matben Exp $

# @@@ Maybe all this should be a component?

package provide Adhoc 1.0

namespace eval ::Adhoc {

    ::hooks::register discoInfoHook                   ::Adhoc::DiscoInfoHook
    ::hooks::register discoPostCommandHook            ::Adhoc::PostMenuHook
    
    variable prefs
    set prefs(autoDisco) 1
    
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

proc ::Adhoc::GetCommandList {jid cmd} {
    variable xmlns
    ::Jabber::JlibCmd disco get_async items $jid $cmd -node $xmlns(commands)
}

proc ::Adhoc::GetCommandListCB {jlibname type from queryE args} {
    # empty
}

proc ::Adhoc::PostMenuHook {m clicked jid node} {
    variable xmlns
    
    if {![::Jabber::JlibCmd disco hasfeature $xmlns(commands) $jid $node]} {
	return
    }
    set name mAdHocCommands
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

proc ::Adhoc::FindLabelForJIDNode {jid node} {
    variable xmlns

    set label $jid
    set xmllist [::Jabber::JlibCmd disco getxml items $jid $xmlns(commands)]
    set queryE [wrapper::getfirstchildwithtag $xmllist query]
    foreach itemE [::wrapper::getchildren $queryE] {
	if {[wrapper::gettag $itemE] eq "item"} {
	    set xjid  [wrapper::getattribute $itemE jid]
	    set xnode [wrapper::getattribute $itemE node]
	    if {($jid eq $xjid) && ($node eq $xnode)} {
		set name [wrapper::getattribute $itemE name]
		set label $name
		if {$label eq ""} {
		    set label $jid
		}
		break
	    }
	}
    }
    return $label
}

# Adhoc::GetActions --
# 
#       Extract any action element from the commands element:
#           <actions execute='complete'>
#               <prev/>
#               <complete/>
#           </actions> 

proc ::Adhoc::GetActions {queryE} {
    
    set actions [list]
    set execute ""
    set commandE [wrapper::getfirstchildwithtag $queryE command]
    if {[llength $commandE]} {
	set actionsE [wrapper::getfirstchildwithtag $commandE actions]
	if {[llength $actionsE]} {
	    set execute [wrapper::getattribute $actionsE execute]
	    foreach E [wrapper::getchildren $actionsE] {
		lappend actions [wrapper::gettag $E]
	    }
	}
    }
    return [list $actions $execute]
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
	set label [FindLabelForJIDNode $jid $node]
	ui::dialog -icon error -title [mc Error] \
	  -message "Ad-Hoc command for \"$label\" at $jid failed because: $errmsg"
    } else {
	BuildDlg $jid $node $subiq
    }
}

proc ::Adhoc::BuildDlg {jid node queryE} {
    global  wDlgs
    variable uid

    # Collect some useful attributes.
    set sessionid [wrapper::getattribute $queryE sessionid]
    set status    [wrapper::getattribute $queryE status]
    
    set w $wDlgs(jadhoc)[incr uid]
    ::UI::Toplevel $w -class AdHoc  \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace code Close]
    wm title $w "Ad-Hoc for $jid"

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jadhoc)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jadhoc)
    }

    ttk::frame $w.all -padding [option get . dialogPadding {}]
    pack $w.all -side top -fill both -expand 1
    
    # Duplicates the form, typically.
    # set label [FindLabelForJIDNode $jid $node]
    # ttk::label $w.all.lbl -text $label
    # pack $w.all.lbl -side top
    
    set wform $w.all.form
    set ftoken [::JForms::Build $wform $queryE -width 300]
    pack $wform -side top -fill both -expand 1

    set bot $w.all.bot
    ttk::frame $bot -padding [option get . okcancelTopPadding {}]

    if {$status eq "completed"} {
	
	# completed: The command has completed. The command session has ended.
	# Typical if a command does not require any interaction.
	ttk::button $bot.close -text [mc Close] -default active \
	  -command [namespace code [list Close $w]]
	pack $bot.close -side right
	
	::JForms::SetState $ftoken disabled
    } else {
	ttk::button $bot.next -text [mc Next] -default active \
	  -command [namespace code [list Action $w execute]]
	ttk::button $bot.prev -text [mc Previous] \
	  -command [namespace code [list Action $w prev]]
	$bot.prev state {disabled}
	set padx [option get . buttonPadX {}]
	pack $bot.next -side right
	pack $bot.prev -side right -padx $padx
    }
    ::chasearrows::chasearrows $bot.arr -size 16
    pack $bot.arr -side left -padx 5 -pady 5
    
    pack $bot -side bottom -fill x
    
    # Keep instance specific state array.
    variable $w
    upvar 0 $w state    

    set state(w)          $w
    set state(wform)      $wform
    set state(wclose)     $bot.close
    set state(wnext)      $bot.next
    set state(wprev)      $bot.prev
    set state(warrows)    $bot.arr
    set state(ftoken)     $ftoken
    set state(jid)        $jid
    set state(node)       $node
    set state(sessionid)  $sessionid
    set state(status)     $status
    
}

proc ::Adhoc::Action {w action} {
    variable $w
    upvar 0 $w state
    variable xmlns

    $state(warrows) start
    $state(wprev) state {disabled}
    $state(wnext) state {disabled}
    
    set xdataEs [::JForms::GetXML $state(ftoken)]
    set attr [list xmlns $xmlns(commands) node $state(node) action $action \
      sessionid $state(sessionid)]
    set commandE [wrapper::createtag command \
      -attrlist $attr -subtags $xdataEs]
    ::Jabber::JlibCmd send_iq set [list $commandE] -to $state(jid) \
      -command [namespace code [list ActionCB $w]] \
      -xml:lang [jlib::getlang]
}

proc ::Adhoc::ActionCB {w type queryE args} {
    
    if {![winfo exists $w]} {
	return
    }
    variable $w
    upvar 0 $w state

    $state(warrows) stop
 
    set status [wrapper::getattribute $queryE status]
    
    if {$type eq "error"} {
	set errcode [lindex $subiq 0]
	set errmsg  [lindex $subiq 1]
	set label [FindLabelForJIDNode $state(jid) $state(node)]
	ui::dialog -icon error -title [mc Error] \
	  -message "Ad-Hoc command for \"$label\" at $jid failed because: $errmsg"
	Close $w
    } elseif {$status eq "completed"} {
	Close $w
    } else {
	set wform $state(wform)
	destroy $wform
	set state(ftoken) [::JForms::Build $wform $queryE -width 300]
	pack $wform -side top -fill both -expand 1

	$state(wprev) -default normal
	$state(wnext) -default normal
	if {$status eq "completed"} {
	    $state(wnext) state {!disabled}
	    $state(wnext) configure -text [mc Close] -default active \
	      -command [namespace code [list Close $w]]
	} else {
	    lassign [GetActions $queryE] actions execute
	    foreach action $actions {
		switch -- $action {
		    next - prev {
			$state(w$action) state {!disabled}
			$state(w$action) configure \
			  -command [namespace code [list Action $w $action]]
		    }
		    complete {
			$state(wnext) state {!disabled}
			$state(wnext) configure -text [mc Finish] \
			  -default active \
			  -command [namespace code [list Close $w]]
		    }
		}
	    }
	    switch -- $execute {
		next - prev {
		    $state(w$execute) -default active
		}
	    }
	}	
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

