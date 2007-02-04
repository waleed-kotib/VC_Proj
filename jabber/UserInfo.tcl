#  UserInfo.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the user info dialog with help of VCard etc.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: UserInfo.tcl,v 1.16 2007-02-04 15:27:59 matben Exp $

package provide UserInfo 1.0

package require VCard

namespace eval ::UserInfo::  {
        
    # Add all event hooks.

    variable uid 0
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
    global  wDlgs
    variable uid
    upvar ::Jabber::jstate jstate
   
    # Keep a separate instance specific namespace for each request.
    set token [namespace current]::[incr uid]
    namespace eval $token {
	variable priv
    }
    upvar ${token}::priv  priv
    
    jlib::splitjid $jid jid2 res

    set avail [::Jabber::RosterCmd isavailable $jid]
    set room  [::Jabber::JlibCmd service isroom $jid2]
    
    set priv(w)       $wDlgs(juserinfo)${uid}
    set priv(jid)     $jid
    set priv(jid2)    $jid2
    set priv(avail)   $avail
    set priv(ncount)  0
    set priv(erruid)  0
    
    set jlib $jstate(jlib)
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

    # Entity time XEP-0202. Switch on when accepted and in common use.
    if {0} {
	$jlib get_entity_time $jid [list [namespace current]::EntityTimeCB $token]
	incr priv(ncount)
    }
    
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
    if {[::Disco::HaveTree]} {
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
	::JUI::SetStatusMessage [mc vcardget $jid]
	$priv(warrow) start
    }
    
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
    if {$type == "error"} {
	
	
	return
    }
    
    set wnb $priv(wnb)

    $wnb add [ttk::frame $wnb.di] -text [mc {Disco}] -sticky news

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

    if {![info exists priv(wpageversion)]} {
	LastAndVersionPage $token
    }
    incr priv(ncount) -1
    if {$priv(ncount) <= 0} {
	$priv(warrow) stop
    }

    set jid $priv(jid)
    
    if {$type == "error"} {
	set str [mc {Version Info}]
	append str "\n"
	append str [mc jamesserrvers $jid [lindex $subiq 1]]
	::Jabber::AddErrorLog $jid $str
	AddError $token $str
    } else {
	set str [mc {Version Info}]:
	set f $priv(wpageversion)
	set i 0
	foreach c [wrapper::getchildren $subiq] {	    
	    set key [mc version-[wrapper::gettag $c]]
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

    incr priv(ncount) -1
    if {$priv(ncount) <= 0} {
	$priv(warrow) stop
    }
    
    set jid $priv(jid)
    
    if {$type eq "error"} {
	set str [mc {Last Activity}]
	append str "\n"
	set str1 [mc jamesserrlastactive $jid [lindex $subiq 1]]
	append str $str1
	::Jabber::AddErrorLog $jid $str1
	AddError $token $str1
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

    if {$type eq "error"} {
	set str [mc {Local Time}]
	append str "\n"
	set str1 [mc jamesserrtime $jid [lindex $subiq 1]]
	append str $str1
	::Jabber::AddErrorLog $jid $str1
	AddError $token $str1
    } else {
	set str [::Jabber::GetTimeString $subiq]
	set priv(strtime) [mc jamesslocaltime $jid $str]
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

    if {$type eq "error"} {
	set str [mc {Local Time}]
	append str "\n"
	set str1 [mc jamesserrtime $jid [lindex $subiq 1]]
	append str $str1
	::Jabber::AddErrorLog $jid $str1
	AddError $token $str1
    } else {
	set str [::Jabber::GetEntityTimeString $subiq]
	set priv(strtime) [mc jamesslocaltime $jid $str]
    }    
}

proc ::UserInfo::VCardCB {token jlibname type subiq} {
    
    if {![Exists $token]} {
	return
    }
    upvar ${token}::priv priv    

    incr priv(ncount) -1
    if {$priv(ncount) <= 0} {
	$priv(warrow) stop
    }

    if {$type eq "error"} {
	set errmsg "([lindex $subiq 0]) [lindex $subiq 1]"
	set str [mc vcarderrget $errmsg]
	::Jabber::AddErrorLog $priv(jid) $str
	AddError $token $str
    } else {
	set ${token}::elem(jid) $priv(jid)
	::VCard::ParseXmlList $subiq ${token}::elem
	::VCard::Pages $priv(wnb) ${token}::elem "other"
    }
}

proc ::UserInfo::Build {token} {
    global  this prefs wDlgs
    upvar ${token}::priv priv    
    
    set w   $priv(w)
    set jid $priv(jid)
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} \
      -closecommand ::UserInfo::CloseHook
    wm title $w "[mc {User Info}]: $jid"

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
    ttk::button $frbot.btok -text [mc Save] \
      -command [list [namespace current]::Save $token]
    ttk::button $frbot.btcancel -text [mc Close] \
      -command [list [namespace current]::Close $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    set warrow $frbot.arr
    pack [::chasearrows::chasearrows $warrow -size 16] -side left

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

proc ::UserInfo::GetTokenFrom {key pattern} {
    
    foreach ns [namespace children [namespace current]] {
	set val [set ${ns}::priv($key)]
	if {[string match $pattern $val]} {
	    return $ns
	}
    }
    return
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

    $wnb add [ttk::frame $wnb.not] -text [mc {Notes}] -sticky news

    set wpage $wnb.not.f
    ttk::frame $wpage -padding [option get . notebookPagePadding {}]
    pack  $wpage  -side top -fill x -anchor [option get . dialogAnchor {}]
    
    ttk::label $wpage.l -style Small.TLabel -text [mc jauserinnote]
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
	set name [mc {Client}]
    } else {
	set name [mc {Service}]
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

    $wnb add [ttk::frame $wnb.err] -text [mc {Error}] -sticky news

    set wpage $wnb.err.f
    ttk::frame $wpage -padding [option get . notebookPagePadding {}]
    pack  $wpage  -side top -anchor [option get . dialogAnchor {}]
    
    set priv(wpageerr) $wpage
}

proc ::UserInfo::AddError {token str} {
    global  this
    upvar ${token}::priv priv
    
    set wnb $priv(wnb)

    if {[lsearch [$wnb tabs] $wnb.err] < 0} {
	BuildErrorPage $token
    }
    set wpage $priv(wpageerr)
    set uid [incr priv(erruid)]
    ttk::label $wpage.$uid -text $str -wraplength 300 -justify left
    grid $wpage.$uid -sticky w -pady 2
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

proc ::UserInfo::CloseHook {wclose} {

    set token [GetTokenFrom w $wclose]
    if {$token != ""} {
	Close $token
    }   
}

proc ::UserInfo::Free {token} {
    
    namespace delete $token    
}

