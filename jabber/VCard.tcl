#  VCard.tcl ---
#  
#      This file is part of The Coccinella application. 
#      
#  Copyright (c) 2001-2004  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: VCard.tcl,v 1.27 2004-11-10 10:08:44 matben Exp $

package provide VCard 1.0

package require mactabnotebook

namespace eval ::VCard::  {
        
    # Add all event hooks.
    ::hooks::register closeWindowHook    ::VCard::CloseHook

    variable uid 0
}

# VCard::Fetch --
#
#       Gets the vCard from 'jid'. The jid should be a 2-tier for ordinary users.

proc ::VCard::Fetch {type {jid {}}} {
    global  wDlgs
    variable uid

    if {$type == "own"} {
	
	# We must use the 2-tier jid here!
        set jid3 [::Jabber::GetMyJid]
	jlib::splitjid $jid3 jid res
    }
    
    # Keep a separate instance specific namespace for each VCard.
    set nstoken [namespace current]::[incr uid]
    namespace eval $nstoken {
	variable elem
	variable priv
    }
    upvar ${nstoken}::priv priv
    
    set priv(jid)  $jid
    set priv(type) $type
    set priv(w)    $wDlgs(jvcard)${uid}
    
    # We should query the server for this and then fill in.
    ::Jabber::UI::SetStatusMessage [mc vcardget $jid]
    ::Jabber::JlibCmd vcard_get $jid  \
      [list [namespace current]::FetchCallback $nstoken]
}

# VCard::FetchCallback --
#
#       This is our callback from the 'vcard_get' procedure.

proc ::VCard::FetchCallback {nstoken jlibName result theQuery} {
    
    ::Debug 4 "::VCard::FetchCallback"
    
    if {$result == "error"} {
	set errmsg "([lindex $theQuery 0]) [lindex $theQuery 1]"
        tk_messageBox -title [mc Error] -icon error -type ok \
          -message [FormatTextForMessageBox  \
          [mc vcarderrget $errmsg]]
        ::Jabber::UI::SetStatusMessage ""
	Free $nstoken
        return
    }
    ::Jabber::UI::SetStatusMessage [mc vcardrec]
    
    # The 'theQuery' now contains all the vCard data in a xml list.
    if {[llength $theQuery]} {
        ParseXmlList $theQuery ${nstoken}::elem
    }
    Build $nstoken
}

# VCard::ParseXmlList --
#
#       Parses the xml list of the very weird looking vCard xml into an array.

proc ::VCard::ParseXmlList {subiq arrName} {
    
    upvar #0 $arrName arr
    
    foreach c [wrapper::getchildren $subiq] {
        set tag [string tolower [wrapper::gettag $c]]
        switch -- $tag {
            fn - nickname - bday - url - title - role - desc {
                set arr($tag) [wrapper::getcdata $c]     
            }
            n - org {
                foreach sub [wrapper::getchildren $c] {
                    set subt [string tolower [wrapper::gettag $sub]]
                    set arr(${tag}_${subt}) [wrapper::getcdata $sub]
                }
            }
            tel {
                set key "tel"
                set telno [wrapper::getcdata $c]
                foreach sub [wrapper::getchildren $c] {
                    set subt [string tolower [wrapper::gettag $sub]]
                    append key "_$subt"
                }
                set arr($key) $telno
            }
            adr {
                
                # First child must be "home" or "work"
                set where [string tolower \
                  [lindex [wrapper::getchildren $c] 0 0]]
                foreach sub [wrapper::getchildren $c] {
                    if {[wrapper::getisempty $sub]} {
                        continue
                    }
                    set subt [string tolower [wrapper::gettag $sub]]
                    set arr(adr_${where}_${subt}) [wrapper::getcdata $sub]
                }
            }
            email {
                set key "email"
                set mailaddr [wrapper::getcdata $c]
                
                # Label with all (empty) subtags.
                foreach sub [wrapper::getchildren $c] {
                    set subt [string tolower [wrapper::gettag $sub]]
                    append key "_$subt"
                }
                
                # Allow many of theses.
                if {[string equal $key "email_internet"]} {
                    lappend arr($key) $mailaddr
                } else {
                    set arr($key) $mailaddr
                }
            }
        }
    }
}

# VCard::Build --
#
#   
# Arguments:
#       type   "own" or "other"
#       
# Results:
#       shows dialog.

proc ::VCard::Build {nstoken} {
    global  this prefs wDlgs
    
    upvar ${nstoken}::elem elem
    upvar ${nstoken}::priv priv
    
    ::Debug 4 "::VCard::Build"

    set anyChange 0
    set w    $priv(w)
    set jid  $priv(jid)
    set type $priv(type)
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    if {$type == "own"} {
	wm title $w [mc {vCard Info}]
    } else {
	wm title $w "[mc {vCard Info}]: $jid"
    }
    set priv(vcardjid) $jid
    
    # Global frame.
    set   frall $w.frall
    frame $frall -borderwidth 0 -relief raised
    pack  $frall -fill both -expand 1
    
    set nbframe [::mactabnotebook::mactabnotebook ${frall}.tn]
    pack $nbframe
    
    # Make the notebook pages.
    # Start with the Basic Info -------------------------------------------------
    
    if {$type == "own"} {
        set ltxt [mc {My vCard}]
    } else {
        set ltxt $jid
    }
    set frbi [$nbframe newpage {Basic Info} -text [mc {Basic Info}]] 

    set lfr $frbi.fr
    labelframe $lfr -text $ltxt
    pack $lfr -side top -anchor w -padx 8 -pady 4

    set   pbi $lfr.frin
    frame $pbi
    pack  $pbi -padx 10 -pady 6 -side left
    
    # Name part.
    label $pbi.first -text [mc {First name}]
    label $pbi.middle -text [mc Middle]
    label $pbi.fam -text [mc {Last name}]
    entry $pbi.efirst -width 16 -textvariable ${nstoken}::elem(n_given)
    entry $pbi.emiddle -width 4 -textvariable ${nstoken}::elem(n_middle)
    entry $pbi.efam -width 18   -textvariable ${nstoken}::elem(n_family)

    grid $pbi.first $pbi.middle $pbi.fam -sticky w
    grid $pbi.efirst $pbi.emiddle $pbi.efam -sticky ew
    
    # Other part.
    label $pbi.nick   -text "[mc {Nick name}]:"
    label $pbi.email  -text "[mc {Email address}]:"
    label $pbi.jid    -text "[mc {Jabber Id}]:"
    entry $pbi.enick  -textvariable ${nstoken}::elem(nickname)
    entry $pbi.eemail -textvariable ${nstoken}::elem(email_internet_pref)
    entry $pbi.ejid   -textvariable ${nstoken}::priv(vcardjid) -state disabled
    
    grid $pbi.nick   -column 0 -row 2 -sticky e
    grid $pbi.enick  -column 1 -row 2 -sticky news -columnspan 2
    grid $pbi.email  -column 0 -row 3 -sticky e
    grid $pbi.eemail -column 1 -row 3 -sticky news -columnspan 2
    grid $pbi.jid    -column 0 -row 4 -sticky e
    grid $pbi.ejid   -column 1 -row 4 -sticky news -columnspan 2
    
    # Description part.
    label $pbi.ldes -text "[mc Description]:"    
    frame $pbi.fdes
    set wdesctxt $pbi.fdes.t
    set wdysc $pbi.fdes.ysc
    text $wdesctxt -height 4 -yscrollcommand [list $wdysc set] -wrap word \
      -borderwidth 1 -relief sunken -width 38
    scrollbar $wdysc -orient vertical -command [list $wdesctxt yview]
    grid $wdesctxt -column 0 -row 0 -sticky news
    grid $wdysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wdesctxt 0 -weight 1
    grid rowconfigure $wdesctxt 0 -weight 1
    grid $pbi.ldes -column 0 -row 5 -sticky w -padx 2 -pady 2
    grid $pbi.fdes -column 0 -row 6 -sticky w -columnspan 3 -padx 2
    if {[info exists elem(desc)]} {
        $wdesctxt insert end $elem(desc)
    }
    
    # Personal Info page -------------------------------------------------------
    set frppers [$nbframe newpage {Personal Info}  \
      -text [mc {Personal Info}]]
    set pbp [frame $frppers.frin]
    pack $pbp -padx 10 -pady 6 -side left -anchor n

    foreach {name tag} {
        {Personal URL}    url
        Occupation        role
        Birthday          bday
    } {
        label $pbp.l$tag -text "[mc $name]:"
        entry $pbp.e$tag -width 28  \
          -textvariable ${nstoken}::elem($tag)
        grid $pbp.l$tag $pbp.e$tag -sticky e
    }
    label $pbp.frmt -text [mc {Format mm/dd/yyyy}]
    grid $pbp.frmt -column 1 -sticky w

    label $pbp.email -text "[mc {Email addresses}]:"
    grid $pbp.email -column 0 -sticky w
    set wemails $pbp.emails
    text $wemails -wrap none -bd 1 -relief sunken \
      -width 32 -height 8
    grid $pbp.emails -columnspan 2 -sticky w
    if {[info exists elem(email_internet)]} {
        foreach email $elem(email_internet) {
            $wemails insert end "$email\n"
        }
    }
    
    # Home page --------------------------------------------------------------
    set frprost [$nbframe newpage {Home} -text [mc Home]]
    set pbh [frame $frprost.frin]
    pack $pbh -padx 10 -pady 6 -side left -anchor n
    
    foreach {name tag} {
        {Address 1}       adr_home_street
        {Address 2}       adr_home_extadd
        City              adr_home_locality
        State/Region      adr_home_region
        {Postal Code}     adr_home_pcode
        Country           adr_home_country
        {Tel (voice)}     tel_voice_home
        {Tel (fax)}       tel_fax_home
    } {
        label $pbh.l$tag -text "[mc $name]:"
        entry $pbh.e$tag -width 28  \
          -textvariable ${nstoken}::elem($tag)
        grid $pbh.l$tag $pbh.e$tag -sticky e
    }
    
    # Work page ----------------------------------------------------------
    set frpgroup [$nbframe newpage {Work} -text [mc Work]]
    set pbw [frame $frpgroup.frin]
    pack $pbw -padx 10 -pady 6 -side left -anchor n
    
    foreach {name tag} {
        {Company Name}    org_orgname 
        Department        org_orgunit
        Title             title
        {Address 1}       adr_work_street
        {Address 2}       adr_work_extadd
        City              adr_work_locality
        State/Region      adr_work_region
        {Postal Code}     adr_work_pcode
        Country           adr_work_country
        {Tel (voice)}     tel_voice_work
        {Tel (fax)}       tel_fax_work
    } {
        label $pbw.l$tag -text "[mc $name]:"
        entry $pbw.e$tag -width 28 -textvariable ${nstoken}::elem($tag)
        grid $pbw.l$tag $pbw.e$tag -sticky e
    }

    # If not our card, disable all entries.
    if {$type == "other"} {
        foreach wpar [list $pbi $pbp $pbh $pbw] {
            foreach win [winfo children $wpar] {
                if {[winfo class $win] == "Entry"} {
                    $win configure -state disabled
                }
            }
        }
        $wemails  configure -state disabled
        $wdesctxt configure -state disabled
    }
        
    # Button part.
    pack [frame $w.frall.frbot -borderwidth 0]  \
      -side top -fill x -expand 1 -padx 8 -pady 6
    set fr $w.frall.frbot
    if {$type == "own"} {
        pack [button $fr.btsave -text [mc Save]  \
          -default active -command [list [namespace current]::SetVCard $nstoken]] \
	  -side right -padx 5 -pady 5
        pack [button $fr.btcancel -text [mc Cancel]  \
          -command [list [namespace current]::Close $nstoken]]  \
	  -side right -padx 5 -pady 5
    } else {
        pack [button $fr.btcancel -text [mc Close] \
          -command [list [namespace current]::Close $nstoken]]  \
	  -side right -padx 5 -pady 5
    }

    set priv(wemails)  $wemails
    set priv(wdesctxt) $wdesctxt
    
    #bind $nbframe <Control-Tab-Key> [list $nbframe nextpage]
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jvcard)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jvcard)
    }
    wm resizable $w 0 0
    focus $w
}

proc ::VCard::SetVCard {nstoken}  {

    upvar ${nstoken}::elem elem
    upvar ${nstoken}::priv priv
    
    set wemails  $priv(wemails)
    set wdesctxt $priv(wdesctxt)

    if {($elem(n_given) != "") && ($elem(n_family) != "")} {
        set elem(fn) "$elem(n_given) $elem(n_family)"
    }
    set elem(email_internet) \
      [regsub -all "(\[^ \n\t]+)(\[ \n\t]*)" [$wemails get 1.0 end] {\1 } tmp]
    set elem(email_internet) [string trim $tmp]
    set elem(desc) [$wdesctxt get 1.0 end]
    
    # Collect all non empty entries, and send a vCard set.
    set argList {}
    foreach {key value} [array get elem] {
	if {[string length $value]} {
	    lappend argList -$key $value
	}
    }
    eval {::Jabber::JlibCmd vcard_set ::VCard::SetVCardCallback} $argList
    ::VCard::Close $nstoken
}

proc ::VCard::CloseHook {wclose} {
    global  wDlgs
    
    if {[string match $wDlgs(jvcard)* $wclose]} {
	set nstoken [::VCard::GetNSTokenFrom w $wclose]
	if {$nstoken != ""} {
	    ::VCard::Close $nstoken
	}
    }   
}

proc ::VCard::GetNSTokenFrom {key pattern} {
    
    foreach ns [namespace children [namespace current]] {
	set val [set ${ns}::priv($key)]
	if {[string match $pattern $val]} {
	    return $ns
	}
    }
    return ""
}

proc ::VCard::Close {nstoken} {
    global  wDlgs
    
    upvar ${nstoken}::priv priv
    
    ::UI::SaveWinGeom $wDlgs(jvcard) $priv(w)
    destroy $priv(w)
    ::VCard::Free $nstoken
}

# VCard::SetVCardCallback --
#
#       This is our callback from the 'vcard_set' procedure.

proc ::VCard::SetVCardCallback {jlibName type theQuery} {

    if {$type == "error"} {
	tk_messageBox -title [mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox \
	  "Failed setting the vCard. The result was: $theQuery"]	  
	return
    }
}

proc ::VCard::Free {nstoken} {
    
    namespace delete $nstoken
}

#-------------------------------------------------------------------------------