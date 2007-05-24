#  Adhoc.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements XEP-0050: Ad-Hoc Commands
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# $Id: Adhoc.tcl,v 1.9 2007-05-24 13:22:37 matben Exp $

# @@@ Maybe all this should be a component?

package provide Adhoc 1.0

namespace eval ::Adhoc {

    ::hooks::register discoInfoHook                   ::Adhoc::DiscoInfoHook
    ::hooks::register discoPostCommandHook            ::Adhoc::PostMenuHook
    
    variable prefs
    set prefs(autoDisco) 1
    
    variable xmlns
    set xmlns(commands) "http://jabber.org/protocol/commands"
    set xmlns(xdata)    "jabber:x:data"
    set xmlns(oob)      "jabber:x:oob"
    
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

proc ::Adhoc::BuildDlg {jid node subiq} {
    global  wDlgs
    variable uid

    # Collect some useful attributes.
    set sessionid [wrapper::getattribute $subiq sessionid]
    set status    [wrapper::getattribute $subiq status]
    
    set w $wDlgs(jadhoc)[incr uid]
        
    # Keep instance specific state array.
    variable $w
    upvar 0 $w state    

    ::UI::Toplevel $w -class AdHoc  \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace code CloseCmd]
    set label [FindLabelForJIDNode $jid $node]
    wm title $w "Ad-Hoc for \"$label\""

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
    #set xtoken [::JForms::Build $wform $subiq -width 300]
    PayloadFrame $w $wform $subiq
    pack $wform -side top -fill both -expand 1

    set xtoken $state(xtoken)
    set bot $w.all.bot
    ttk::frame $bot -padding [option get . okcancelTopPadding {}]

    if {$status eq "completed"} {
	
	# completed: The command has completed. The command session has ended.
	# Typical if a command does not require any interaction.
	ttk::button $bot.close -text [mc Close] -default active \
	  -command [namespace code [list CloseCmd $w]]
	pack $bot.close -side right
	
	bind $w <Return> [list $bot.close invoke]
	::JForms::SetState $xtoken disabled
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

    set state(w)          $w
    set state(wform)      $wform
    set state(wclose)     $bot.close
    set state(wnext)      $bot.next
    set state(wprev)      $bot.prev
    set state(warrows)    $bot.arr
    set state(xtoken)     $xtoken
    set state(jid)        $jid
    set state(node)       $node
    set state(sessionid)  $sessionid
    set state(status)     $status
    
    if {$status ne "completed"} {
	SetActionButtons $w $subiq
    }   
    return $w
}

# Adhoc::PayloadFrame --
# 
#       Build the payload frame from the xml payload of the command element.
#       Normally a single jabber:x:data element but can also be jabber:x:oob
#       elements.
#       
#       XEP-0050: When the precedence of these payload elements becomes 
#       important (such as when both "jabber:x:data" and "jabber:x:oob" 
#       elements are present), the order of the elements SHOULD be used. 
#       Those elements that come earlier in the child list take precedence 
#       over those later in the child list. 

proc ::Adhoc::PayloadFrame {w wform subiq} {
    variable $w
    upvar 0 $w state
    variable xmlns
    
    foreach E [wrapper::getchildren $subiq] {
	if {([wrapper::gettag $E] eq "x") && \
	  ([wrapper::getattribute $E xmlns] eq $xmlns(xdata))} {
	    set state(xtoken) [::JForms::XDataFrame $wform $E -width 300]
	    break
	} elseif {([wrapper::gettag $E] eq "query") && \
	  ([wrapper::getattribute $E xmlns] eq $xmlns(oob))} {
	    
	    # @@@ It is unclear what this looks like.
	}
    }
    
}

# Adhoc::GetActions --
# 
#       Extract any action element from the commands element:
#           <actions execute='complete'>
#               <prev/>
#               <complete/>
#           </actions> 

proc ::Adhoc::GetActions {subiq} {
    
    set actions [list]
    set execute ""
    if {[wrapper::gettag $subiq] eq "command"} {
	set commandE $subiq
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

proc ::Adhoc::Action {w action} {
    variable $w
    upvar 0 $w state
    variable xmlns
    
    $state(warrows) start
    $state(wprev) state {disabled}
    $state(wnext) state {disabled}
    
    set xdataEs [::JForms::GetXML $state(xtoken)]
    set attr [list xmlns $xmlns(commands) node $state(node) action $action \
      sessionid $state(sessionid)]
    set commandE [wrapper::createtag command \
      -attrlist $attr -subtags $xdataEs]
    ::Jabber::JlibCmd send_iq set [list $commandE] -to $state(jid) \
      -command [namespace code [list ActionCB $w]] \
      -xml:lang [jlib::getlang]
}

proc ::Adhoc::ActionCB {w type subiq args} {
    
    if {![winfo exists $w]} {
	return
    }
    variable $w
    upvar 0 $w state

    $state(warrows) stop
 
    set status [wrapper::getattribute $subiq status]
    set state(status) $status
    
    if {$type eq "error"} {
	set errcode [lindex $subiq 0]
	set errmsg  [lindex $subiq 1]
	set label [FindLabelForJIDNode $state(jid) $state(node)]
	ui::dialog -icon error -title [mc Error] \
	  -message "Ad-Hoc command for \"$label\" at $jid failed because: $errmsg"
	Close $w
    } else {
	set wform $state(wform)
	destroy $wform
	set state(xtoken) [::JForms::Build $wform $subiq -width 300]
	pack $wform -side top -fill both -expand 1

	if {$status eq "completed"} {
	    $state(wprev) configure -default normal
	    $state(wnext) configure -default normal
	    $state(wnext) state {!disabled}
	    $state(wnext) configure -text [mc Close] -default active \
	      -command [namespace code [list Close $w]]
	} else {
	    SetActionButtons $w $subiq
	}	
	
	# There can be one or many jabber:iq:oob elements as well.
	
    }
}

proc ::Adhoc::SetActionButtons {w subiq} {
    variable $w
    upvar 0 $w state
    
    $state(wprev) configure -default normal
    $state(wnext) configure -default normal
    bind $w <Return> {}

    lassign [GetActions $subiq] actions execute
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
		  -command [namespace code [list Action $w complete]]
	    }
	}
    }
    switch -- $execute {
	next - prev {
	    $state(w$execute) configure -default active
	    bind $w <Return> [list $state(w$execute) invoke]
	}
	complete {
	    $state(wnext) configure -default active
	    bind $w <Return> [list $state(wnext) invoke]
	}
    }
}

proc ::Adhoc::Cancel {w} {
    variable $w
    upvar 0 $w state
    variable xmlns

    set attr [list xmlns $xmlns(commands) node $state(node) action cancel \
      sessionid $state(sessionid)]
    set commandE [wrapper::createtag command -attrlist $attr]
    ::Jabber::JlibCmd send_iq set [list $commandE] -to $state(jid) \
      -xml:lang [jlib::getlang]
}

proc ::Adhoc::CloseCmd {w} {
    variable $w
    upvar 0 $w state
    
    if {$state(status) ne "completed"} {
	Cancel $w
    }
    Close $w
}

proc ::Adhoc::Close {w} {
    global  wDlgs

    ::UI::SaveWinGeom $wDlgs(jadhoc) $w
    unset -nocomplain state
    destroy $w
    return
}

