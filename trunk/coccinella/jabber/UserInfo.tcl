#  UserInfo.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the user info dialog with help of VCard etc.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: UserInfo.tcl,v 1.1 2005-02-27 14:11:07 matben Exp $

package provide UserInfo 1.0

package require VCard

namespace eval ::UserInfo::  {
        
    # Add all event hooks.
    ::hooks::register closeWindowHook    ::UserInfo::CloseHook

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
#       none.

proc ::UserInfo::Get {jid} {
    global  wDlgs
    variable uid
   
    # Keep a separate instance specific namespace for each request.
    set token [namespace current]::[incr uid]
    namespace eval $token {
	variable priv
	variable velem
    }
    upvar ${token}::priv  priv
    upvar ${token}::velem velem
    
    jlib::splitjid $jid jid2 res

    set avail [::Jabber::RosterCmd isavailable $jid]
    
    set priv(w)       $wDlgs(juserinfo)${uid}
    set priv(jid)     $jid
    set priv(jid2)    $jid2
    set priv(avail)   $avail
    set priv(ncount)  2
    set velem(jid)    $jid

    ::Jabber::JlibCmd get_last  $jid  [list ::UserInfo::LastCB $token]
    ::Jabber::JlibCmd vcard_get $jid2 [list ::UserInfo::VCardCB $token]
    if {$avail} {
	::Jabber::JlibCmd get_version $jid [list ::UserInfo::VersionCB $token]
	incr priv(ncount)
    }
    Build $token
    NotesPage $token
    
    if {[::Jabber::IsConnected]} {
	::Jabber::UI::SetStatusMessage [mc vcardget $jid]
	$priv(warrow) start
    }
    
    return $token
}

proc ::UserInfo::VersionCB {token jlibname type subiq} {
    upvar ${token}::priv priv    
    
    if {![Exists $token]} {
	return
    }
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
    } else {
	set str [mc {Version Info}]
	append str ":"
	set f $priv(wpageversion)
	set i 0
	foreach c [wrapper::getchildren $subiq] {
	    label $f.l$i -text "[wrapper::gettag $c]:" \
	      -wraplength 300 -justify left
	    label $f.t$i -text [wrapper::getcdata $c] \
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
    upvar ${token}::priv priv    
    
    if {![Exists $token]} {
	return
    }
    if {![info exists priv(wpageversion)]} {
	LastAndVersionPage $token
    }
    incr priv(ncount) -1
    if {$priv(ncount) <= 0} {
	$priv(warrow) stop
    }
    
    set jid $priv(jid)
    
    if {$type == "error"} {
	set str [mc {Last Activity}]
	append str "\n"
	set str1 [mc jamesserrlastactive $jid [lindex $subiq 1]]
	append str $str1
	::Jabber::AddErrorLog $jid $str1
    } else {
	array set attrArr [wrapper::getattrlist $subiq]
	if {![info exists attrArr(seconds)]} {
	    set str [mc jamesserrnotimeinfo $jid]
	} else {
	    set secs [expr [clock seconds] - $attrArr(seconds)]
	    set uptime [clock format $secs -format "%a %b %d %H:%M:%S"]
	    if {[wrapper::getcdata $subiq] != ""} {
		set msg "The message: [wrapper::getcdata $subiq]"
	    } else {
		set msg ""
	    }
	    
	    # Time interpreted differently for different jid types.
	    if {$jid != ""} {
		jlib::splitjidex $jid node domain resource
		if {($node == "") && ($resource == "")} {
		    set msg1 [mc jamesstimeservstart $jid]
		} elseif {$resource == ""} {
		    set msg1 [mc jamesstimeconn $jid]
		} else {
		    set msg1 [mc jamesstimeused $jid]
		}
	    } else {
		set msg1 [mc jamessuptime]
	    }
	    set str "$msg1 $uptime. $msg"
	}
    }
    set priv(strlast) $str
}

proc ::UserInfo::VCardCB {token jlibname type subiq} {
    upvar ${token}::priv priv    
    
    if {![Exists $token]} {
	return
    }
    incr priv(ncount) -1
    if {$priv(ncount) <= 0} {
	$priv(warrow) stop
    }

    if {$type == "error"} {
	set errmsg "([lindex $subiq 0]) [lindex $subiq 1]"
	set str [mc vcarderrget $errmsg]
	::Jabber::AddErrorLog $priv(jid) $str
	VCardErrorPage $token $str
    } else {
	::VCard::ParseXmlList $subiq ${token}::velem
	::VCard::Pages $priv(wnb) ${token}::velem "other"
    }
}

proc ::UserInfo::Build {token} {
    global  this prefs wDlgs
    upvar ${token}::priv priv    
    
    set w   $priv(w)
    set jid $priv(jid)
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w "[mc {User Info}]: $jid"
    
    # Global frame.
    set   frall $w.frall
    frame $frall -borderwidth 0 -relief raised
    pack  $frall -fill both -expand 1
    frame $frall.pad
    pack  $frall.pad -fill both -expand 1 -padx 0 -pady 0
    
    set wnb [::mactabnotebook::mactabnotebook $frall.pad.tn]
    pack $wnb

    set priv(wnb) $wnb

    # Button part.
    pack [frame $w.frall.frbot -borderwidth 0]  \
      -side top -fill x -expand 1 -padx 8 -pady 6
    set fr $w.frall.frbot
    pack [button $fr.btsave -text [mc Save] \
      -command [list [namespace current]::Save $token]]  \
      -side right -padx 5 -pady 5
    pack [button $fr.btcancel -text [mc Close] \
      -command [list [namespace current]::Close $token]]  \
      -side right -padx 5 -pady 5
    set warrow $fr.arr
    pack [::chasearrows::chasearrows $warrow -size 16] \
      -side left -padx 5 -pady 5

    set priv(warrow) $warrow

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(juserinfo)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(juserinfo)
    }
    wm resizable $w 0 0
    focus $w
}

proc ::UserInfo::Exists {token} {
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
    return ""
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
    
    set wpage [$priv(wnb) newpage {Notes} -text [mc {Notes}]] 
    frame $wpage.f
    pack  $wpage.f -padx 8 -pady 6 -fill both -expand 1
    
    label $wpage.f.l -text [mc jauserinnote]
    pack  $wpage.f.l -side bottom -anchor w
    
    set wtext $wpage.f.t
    set wysc  $wpage.f.s
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    text $wtext -wrap word -width 40 -height 12 \
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
    
    set wpage [$priv(wnb) newpage {Client} -text [mc {Client}]] 
    frame $wpage.f
    pack  $wpage.f -padx 6 -pady 4 -side top -anchor w

    label $wpage.f.last -textvariable ${token}::priv\(strlast) \
      -wraplength 300 -justify left
    label $wpage.f.vers -textvariable ${token}::priv\(strvers) \
      -wraplength 300 -justify left
    
    grid $wpage.f.last -sticky w -pady 2 -columnspan 2
    grid $wpage.f.vers -sticky w -pady 2 -columnspan 2
    
    set priv(wpageversion) $wpage.f
    
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	set wpage %s
	$wpage.f.last configure -wraplength [expr [winfo reqwidth $wpage] - 10]
	$wpage.f.vers configure -wraplength [expr [winfo reqwidth $wpage] - 10]
    } $wpage]    
    after idle $script
}

proc ::UserInfo::VCardErrorPage {token str} {
    global  this
    upvar ${token}::priv priv
    
    set wpage [$priv(wnb) newpage {Error} -text [mc {Error}]] 
    frame $wpage.f
    pack  $wpage.f -padx 6 -pady 4 -side top -anchor w

    label $wpage.f.err -text $str -wraplength 200 -justify left
    grid $wpage.f.err -sticky w -pady 2
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
    global  wDlgs
    
    if {[string match $wDlgs(juserinfo)* $wclose]} {
	set token [::VCard::GetTokenFrom w $wclose]
	if {$token != ""} {
	    Close $token
	}
    }   
}

proc ::UserInfo::Free {token} {
    
    namespace delete $token    
}

