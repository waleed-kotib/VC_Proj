#  UserInfo.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the user info dialog with help of VCard etc.
#      
#  Copyright (c) 2005-2008  Mats Bengtsson
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
# $Id: UserInfo.tcl,v 1.38 2008-08-04 13:05:29 matben Exp $

package provide UserInfo 1.0

package require VCard

namespace eval ::UserInfo::  {
        
    # Add all event hooks.
    ::hooks::register menuUserInfoFilePostHook   ::UserInfo::FileMenuPostHook
    ::hooks::register onMenuVCardExport          ::UserInfo::OnMenuExportHook

    variable uid
    
    set ::config(userinfo,disco) 0
}

proc ::UserInfo::GetJIDList {jidL} {
    foreach jid $jidL {
	Get $jid
    }
}

# UserInfo::Get --
# 
#       Builds the combined user info page. Makes the necessary requests.
#       
# Arguments:
#       jid         this is the jid in the roster tree, with or without
#                   resource part depending on if online or not.
#                   
# Results:
#       token.

proc ::UserInfo::Get {jid {node ""}} {
    global  wDlgs config
    variable uid
   
    set jid2 [jlib::barejid $jid]
    # Keep a separate instance specific namespace for each request.
    set uid [join [split $jid2 "@."] ""]
    set token [namespace current]::$uid
    namespace eval $token {
	variable priv
    }
    upvar ${token}::priv  priv
    

    set avail [::Jabber::RosterCmd isavailable $jid]
    set room  [::Jabber::Jlib service isroom $jid2]
    
    set priv(w)       $wDlgs(juserinfo)${uid}
    set priv(jid)     $jid
    set priv(jid2)    $jid2
    set priv(avail)   $avail
    set priv(ncount)  0
    set priv(erruid)  0
    
    set jlib [::Jabber::GetJlib]
    if {[$jlib roster isitem $jid2]} {
	set priv(type) "user"
    } else {
	set priv(type) "item"
    }

    # jabber:iq:last
    $jlib get_last $jid [list [namespace current]::LastCB $token]
    incr priv(ncount)

    # jabber:iq:time
    $jlib get_time $jid [list [namespace current]::TimeCB $token]
    incr priv(ncount)

    $jlib get_entity_time $jid [list [namespace current]::EntityTimeCB $token]
    incr priv(ncount)
    
    # vCard
    if {$room} {
	$jlib vcard send_get $jid [list [namespace current]::VCardCB $token]
    } else {
	$jlib vcard send_get $jid2 [list [namespace current]::VCardCB $token]
    }
    incr priv(ncount)
    
    # jabber:iq:version
    set version 0
    if {($priv(type) eq "user") && $avail} {
	set version 1
    } elseif {$priv(type) eq "item"} {
	set version 1
    }
    if {$version} {
	$jlib get_version $jid [list [namespace current]::VersionCB $token]
	incr priv(ncount)
    }
    
    # disco
    if {$config(userinfo,disco) && [::Disco::HaveTree]} {
	set opts {}
	if {$node != ""} {
	    lappend opts -node $node
	}
	set discoCB [list [namespace current]::DiscoCB $token]
	eval {$jlib disco send_get info $jid $discoCB} $opts
	incr priv(ncount)
    }
    
    Build $token
    NotesPage $token
    
    if {[::Jabber::IsConnected]} {
	set ujid [jlib::unescapejid $jid]
	::JUI::SetAppMessage [mc "Downloading business card from %s" $ujid]...
	# need to check here for the existence of the vcard subwindow
	# only start the rotating arrow if it not yet exists, for some 
	# reason a $priv(warrow) stop in the beginning of ::Build did not worked 
	if (![winfo exists $priv(wnb).fbas]) {
	  $priv(warrow) start
	}
    }
    
    ::hooks::run buildUserInfoDlgHook $jid $priv(wnb)
    
    return $token
}

proc ::UserInfo::DiscoCB {token disconame type from subiq args} {
    
    if {![Exists $token]} {
	return
    }
    upvar ${token}::priv priv    

    incr priv(ncount) -1
    if {$priv(ncount) <= 0} {
	$priv(warrow) stop
    }
    if {$type eq "error"} {
	
	
	return
    }
    
    set wnb $priv(wnb)

    $wnb add [ttk::frame $wnb.di] -text [mc "Discover"] -sticky news

    set wpage $wnb.di.f
    ttk::frame $wpage -padding [option get . notebookPagePadding {}]
    pack  $wpage  -side top -anchor [option get . dialogAnchor {}]
    
    ::Disco::BuildInfoPage $wpage.f $from
    pack $wpage.f -fill both -expand 1

}

proc ::UserInfo::VersionCB {token jlibname type subiq} {
    
    if {![Exists $token]} {
	return
    }
    upvar ${token}::priv priv    
    

    if ([info exists priv(wpageversion)]) {
        if ([winfo exists $priv(wpageversion).l0]) {
            return
        }
    }
    if {![info exists priv(wpageversion)]} {
	LastAndVersionPage $token
    }
    incr priv(ncount) -1
    if {$priv(ncount) <= 0} {
	$priv(warrow) stop
    }

    set jid $priv(jid)
    set ujid [jlib::unescapejid $jid]
    
    if {$type == "error"} {
	set str [mc "Version"]
	append str "\n"
	append str  [mc "Cannot query %s's version." $ujid]
	append str "\n"
	append str [mc "Error"]
	append str ": [lindex $subiq 1]"

	::Jabber::AddErrorLog $jid $str
    } else {
	set str [mc "Version"]:
	set f $priv(wpageversion)
	set i 0
	set version [dict create]
	dict set version name [mc "Name"]
	dict set version version [mc "Version"]
	dict set version os [mc "Operating system"]
	foreach c [wrapper::getchildren $subiq] {	    
	    set key [dict get $version [wrapper::gettag $c]]
	    ttk::label $f.l$i -text $key: \
	      -wraplength 300 -justify left
	    ttk::label $f.t$i -text [wrapper::getcdata $c] \
	      -wraplength 300 -justify left
	    grid  $f.l$i $f.t$i
	    grid  $f.l$i -sticky e
	    grid  $f.t$i -sticky w
	    incr i
	}
    }
    set priv(strvers) $str
}

proc ::UserInfo::LastCB {token jlibname type subiq} {
    
    if {![Exists $token]} {
	return
    }
    upvar ${token}::priv priv    
    if ([winfo exists $priv(wnb).fbas]) {
	return
    }

    incr priv(ncount) -1
    if {$priv(ncount) <= 0} {
	$priv(warrow) stop
    }
    
    set jid $priv(jid)
    set ujid [jlib::unescapejid $jid]
    
    if {$type eq "error"} {
	set str [mc "Last Activity"]
	append str "\n"
	append str [mc "Cannot query %s's last activity." $ujid]
	append str "\n"
	append str [mc "Error"]
	append str ": [lindex $subiq 1]"

	::Jabber::AddErrorLog $jid $str
    } else {
	if {![info exists priv(wpageversion)]} {
	    LastAndVersionPage $token
	}
	set priv(strlast) [::Jabber::GetLastString $jid $subiq]
    }
}

proc ::UserInfo::TimeCB {token jlibname type subiq} {
    
    if {![Exists $token]} {
	return
    }
    upvar ${token}::priv priv    

    incr priv(ncount) -1
    if {$priv(ncount) <= 0} {
	$priv(warrow) stop
    }
    
    set jid $priv(jid)
    set ujid [jlib::unescapejid $jid]

    if {$type eq "error"} {
	set str [mc "Local Time"]
	append str "\n"
	append str  [mc "Cannot query %s's local time." $ujid]
	append str "\n"
	append str [mc "Error"]
	append str ": [lindex $subiq 1]"

	::Jabber::AddErrorLog $jid $str
    } else {
	set str [::Jabber::GetTimeString $subiq]
	set priv(strtime) [mc "%s's local time is: %s" $ujid $str]
    }    
}

proc ::UserInfo::EntityTimeCB {token jlibname type subiq} {
    
    if {![Exists $token]} {
	return
    }
    upvar ${token}::priv priv    

    incr priv(ncount) -1
    if {$priv(ncount) <= 0} {
	$priv(warrow) stop
    }
    
    set jid $priv(jid)
    set ujid [jlib::unescapejid $jid]

    if {$type eq "error"} {
	set str [mc "Local Time"]
	append str "\n"
	append str [mc "Cannot query %s's local time." $ujid]\n
	append str [mc "Error"]
	append str ": [lindex $subiq 1]"

	::Jabber::AddErrorLog $jid $str
    } else {
	set str [::Jabber::GetEntityTimeString $subiq]
	set priv(strtime) [mc "%s's local time is: %s" $ujid $str]
    }    
}

proc ::UserInfo::VCardCB {token jlibname type subiq} {
    
    if {![Exists $token]} {
	return
    }
    upvar ${token}::priv priv    

    if ([winfo exists $priv(wnb).fbas]) {
       return
    } 

    incr priv(ncount) -1
    if {$priv(ncount) <= 0} {
	$priv(warrow) stop
    }
    set jid $priv(jid)
    set ujid [jlib::unescapejid $jid]

    if {$type eq "error"} {
	set errmsg "([lindex $subiq 0]) [lindex $subiq 1]"
	set str [mc "Cannot download business card." $errmsg]
	::Jabber::AddErrorLog $jid $str
    } else {
	set priv(subiq) $subiq
	set ${token}::elem(jid) [jlib::unescapejid $priv(jid)]
	::VCard::ParseXmlList $subiq ${token}::elem
	::VCard::Pages $priv(wnb) ${token}::elem "other"
    }
}

proc ::UserInfo::Build {token} {
    global  this prefs wDlgs
    upvar ${token}::priv priv    
    
    set w   $priv(w)
    set jid $priv(jid)
    
    if ([winfo exists $w]) {
	raise $w
	focus $w
	return
    }

    ::UI::Toplevel $w -class UserInfo \
      -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} \
      -closecommand ::UserInfo::CloseHook
    set djid [::Roster::GetDisplayName $jid]
    wm title $w [mc "Business Card: %s" $djid]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(juserinfo)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(juserinfo)
    }
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall

    set wnb $wbox.nb
    ttk::notebook $wnb -padding [option get . dialogNotebookPadding {}]
    pack $wnb -side top

    set priv(wnb) $wnb

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelNoTopPadding {}]
    ttk::button $frbot.btok -text [mc "Save"] \
      -command [list [namespace current]::Save $token]
    ttk::button $frbot.btcancel -text [mc "Cancel"] \
      -command [list [namespace current]::Close $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    ttk::button $frbot.export -text [mc "Export"]... \
      -command [list [namespace current]::Export $token]
    pack $frbot.export -side left

    set warrow $frbot.arr
    pack [::UI::ChaseArrows $warrow] -side left -padx 6

    pack $frbot -side bottom -fill x

    set priv(warrow) $warrow
    wm resizable $w 0 0
    focus $w
}

proc ::UserInfo::Exists {token} {
    
    if {![namespace exists $token]} {
	return 0
    }
    upvar ${token}::priv priv    

    if {![info exists priv]} {
	return 0
    } elseif {![winfo exists $priv(w)]} {
	return 0
    } else {
	return 1
    }
}

proc ::UserInfo::Save {token} {    
    SaveNotes $token
    Close $token
}

proc ::UserInfo::Close {token} {
    global  wDlgs
    upvar ${token}::priv priv    
    
    ::UI::SaveWinGeom $wDlgs(juserinfo) $priv(w)
    destroy $priv(w)
    Free $token
}

proc ::UserInfo::NotesPage {token} {
    global  this
    upvar ${token}::priv priv    
    
    set wnb $priv(wnb)

    if ([winfo exists $wnb.not]) {
	return
    }

    # TRANSLATORS: in the business card dialog, there can be made notes about each contact
    $wnb add [ttk::frame $wnb.not] -text [mc "Notes"] -sticky news

    set wpage $wnb.not.f
    ttk::frame $wpage -padding [option get . notebookPagePadding {}]
    pack  $wpage  -side top -fill x -anchor [option get . dialogAnchor {}]
    
    ttk::label $wpage.l -style Small.TLabel -text [mc "Add your personal notes about this contact."]
    pack  $wpage.l -side bottom -anchor w
    
    set wtext $wpage.t
    set wysc  $wpage.s
    ttk::scrollbar $wysc -orient vertical -command [list $wtext yview]
    text $wtext -wrap word -width 40 -height 12 -bd 1 -relief sunken \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list pack $wysc  -side right -fill y]]
    
    pack $wysc  -side right -fill y
    pack $wtext -side left -fill both -expand 1
    
    set priv(wnotes) $wtext
    
    if {[file exists $this(notesFile)]} {
	source $this(notesFile)
	set jid2 $priv(jid2)
	if {[info exists notes($jid2)]} {
	    $wtext insert end $notes($jid2)
	}
    }
}

proc ::UserInfo::LastAndVersionPage {token} {
    global  this
    upvar ${token}::priv priv
    
    set wnb $priv(wnb)

    if {$priv(type) eq "user"} {
	set name [mc "Client"]
    } else {
	set name [mc "Service"]
    }
    $wnb add [ttk::frame $wnb.ver] -text $name -sticky news

    set wpage $wnb.ver.f
    ttk::frame $wpage -padding [option get . notebookPagePadding {}]
    pack  $wpage  -side top -anchor [option get . dialogAnchor {}]

    ttk::label $wpage.last -textvariable ${token}::priv\(strlast) \
      -wraplength 300 -justify left
    ttk::label $wpage.time -textvariable ${token}::priv\(strtime) \
      -wraplength 300 -justify left
    ttk::label $wpage.vers -textvariable ${token}::priv\(strvers) \
      -wraplength 300 -justify left
    
    grid $wpage.last -sticky w -pady 2 -columnspan 2
    grid $wpage.time -sticky w -pady 2 -columnspan 2
    grid $wpage.vers -sticky w -pady 2 -columnspan 2
    
    set priv(wpageversion) $wpage
    
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	set wpage %s
	$wpage.last configure -wraplength [expr [winfo reqwidth $wpage] - 10]
	$wpage.time configure -wraplength [expr [winfo reqwidth $wpage] - 10]
	$wpage.vers configure -wraplength [expr [winfo reqwidth $wpage] - 10]
    } $wpage]    
    after idle $script
}

proc ::UserInfo::BuildErrorPage {token} {
    global  this
    upvar ${token}::priv priv
    
    set wnb $priv(wnb)

    $wnb add [ttk::frame $wnb.err] -text [mc "Error"] -sticky news

    set wpage $wnb.err.f
    ttk::frame $wpage -padding [option get . notebookPagePadding {}]
    pack  $wpage  -side top -anchor [option get . dialogAnchor {}]
    
    set priv(wpageerr) $wpage
}

proc ::UserInfo::SaveNotes {token} {
    global  this
    upvar ${token}::priv priv    
    
    if {[file exists $this(notesFile)]} {
	source $this(notesFile)
    }    
    set str [string trim [$priv(wnotes) get 1.0 end]]
    set jid2 $priv(jid2)
    set notes($jid2) $str
    
    # Work on a temporary file and switch later.
    set tmp $this(notesFile).tmp
    if {![catch {open $tmp w} fd]} {
	#fconfigure $fd -encoding utf-8
	puts $fd "# Notes file"
	puts $fd "# The data written at: [clock format [clock seconds]]\n#"
	foreach {jid str} [array get notes] {
	    puts $fd [list set notes($jid) $notes($jid)]
	}
	close $fd
	catch {file rename -force $tmp $this(notesFile)}
    }
}

proc ::UserInfo::GetTokenFrom {key pattern} {    
    foreach ns [namespace children [namespace current]] {
	set val [set ${ns}::priv($key)]
	if {[string match $pattern $val]} {
	    return $ns
	}
    }
    return
}

proc ::UserInfo::CloseHook {wclose} {
    set token [GetTokenFrom w $wclose]
    if {$token != ""} {
	Close $token
    }   
}

proc ::UserInfo::GetFrontToken {} {
    if {[winfo exists [focus]]} {
	if {[winfo class [winfo toplevel [focus]]] eq "UserInfo"} {
	    set w [winfo toplevel [focus]]
	    return [GetTokenFrom w $w]
	}
    }   
    return
}

proc ::UserInfo::FileMenuPostHook {wmenu} {
    
    if {[tk windowingsystem] eq "aqua"} {
	
	# Need to have a different one for aqua due to the menubar.
	set m [::UI::MenuMethod $wmenu entrycget mExport -menu]
	set token [GetFrontToken]
	if {$token ne ""} {
	    ::UI::MenuMethod $m entryconfigure mBC... -state normal -label [mc "&Business Card"]...
	}
    }
}

proc ::UserInfo::Export {token} {
    upvar ${token}::priv priv    
    ::VCard::ExportXML $token $priv(jid)
}

proc ::UserInfo::OnMenuExportHook {} {
    set token [GetFrontToken]
    if {$token ne ""} {
	upvar ${token}::priv priv    
	::VCard::ExportXML $token $priv(jid)
	return stop
    }
    return
}

proc ::UserInfo::Free {token} {
    
    namespace delete $token    
}

