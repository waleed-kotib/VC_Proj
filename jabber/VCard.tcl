#  VCard.tcl ---
#  
#      This file is part of the whiteboard application. 
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: VCard.tcl,v 1.3 2003-04-28 13:32:29 matben Exp $

package provide VCard 1.0

package require mactabnotebook

namespace eval ::VCard::  {
    
    variable tmpPrefs
    
    # Variable to be used in tkwait.
    variable finished
    variable uid 1001
    variable elem
}

# VCard::Fetch --
#
#       Gets the vCard from 'jid'.

proc ::VCard::Fetch {w type {jid {}}} {

    variable uid
    upvar ::Jabber::jstate jstate

    if {$type == "own"} {
        set jid $jstate(mejid)
    }
    set wtoplevel ${w}${uid}
    incr uid
        
    # We should query the server for this and then fill in.
    ::Jabber::UI::SetStatusMessage [::msgcat::mc vcardget $jid]
    $jstate(jlib) vcard_get $jid  \
      [list ::VCard::FetchCallback $wtoplevel $type $jid]
}

# VCard::FetchCallback --
#
#       This is our callback from the 'vcard_get' procedure.

proc ::VCard::FetchCallback {w type jid jlibName result theQuery} {
    
    variable elem

    if {$result == "error"} {
        tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
          -message [FormatTextForMessageBox  \
          [::msgcat::mc vcarderrget $theQuery]]
        ::Jabber::UI::SetStatusMessage ""
        return
    }
    ::Jabber::UI::SetStatusMessage [::msgcat::mc vcardrec]
    
    # The 'theQuery' now contains all the vCard data in a xml list.
    catch {unset elem}
    if {[llength $theQuery]} {
        ::VCard::ParseXmlList $theQuery [namespace current]::elem
    }
    Build $w $type $jid
}

# VCard::ParseXmlList --
#
#       Parses the xml list of the very weird looking vCard xml into an array.

proc ::VCard::ParseXmlList {subiq arrName} {
    
    upvar #0 $arrName arr
    
    foreach c [wrapper::getchildren $subiq] {
        set tag [string tolower [lindex $c 0]]
        switch -- $tag {
            fn - nickname - bday - url - title - role - desc {
                set arr($tag) [lindex $c 3]     
            }
            n - org {
                foreach sub [wrapper::getchildren $c] {
                    set subt [string tolower [lindex $sub 0]]
                    set arr(${tag}_${subt}) [lindex $sub 3]
                }
            }
            tel {
                set key "tel"
                set telno [lindex $c 3]
                foreach sub [wrapper::getchildren $c] {
                    set subt [string tolower [lindex $sub 0]]
                    append key "_$subt"
                }
                set arr($key) $telno
            }
            adr {
                
                # First child must be "home" or "work"
                set where [string tolower \
                  [lindex [lindex [wrapper::getchildren $c] 0] 0]]
                foreach sub [wrapper::getchildren $c] {
                    if {[lindex $sub 2]} {
                        continue
                    }
                    set subt [string tolower [lindex $sub 0]]
                    set arr(adr_${where}_${subt}) [lindex $sub 3]
                }
            }
            email {
                set key "email"
                set mailaddr [lindex $c 3]
                
                # Label with all (empty) subtags.
                foreach sub [wrapper::getchildren $c] {
                    set subt [string tolower [lindex $sub 0]]
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
#       w      the toplevel window.
#       type   "own" or "other"
#       
# Results:
#       shows dialog.

proc ::VCard::Build {w type jid} {
    global  this sysFont prefs
    
    variable finished
    variable tmpPrefs
    variable elem
    variable wemails
    variable vcardjid
    variable wdesctxt
    upvar ::Jabber::jstate jstate
    
    set finished 0
    set anyChange 0
    
    if {[winfo exists $w]} {
        return
    }
    toplevel $w -background $prefs(bgColGeneral)
    if {[string match "mac*" $this(platform)]} {
        eval $::macWindowStyle $w documentProc
    } else {

    }    
    wm title $w [::msgcat::mc {vCard Info}]
    
    # Toplevel menu for mac only.
    if {[string match "mac*" $this(platform)]} {
	$w configure -menu [::Jabber::UI::GetRosterWmenu]
    }
    set vcardjid $jid
    
    # Global frame.
    pack [frame $w.frall -borderwidth 0 -relief raised] -fill both -expand 1
    set frall $w.frall
    
    set nbframe [::mactabnotebook::mactabnotebook $frall.tn]
    pack $nbframe
    
    # Make the notebook pages.
    # Start with the Basic Info -------------------------------------------------
    
    if {$type == "own"} {
        set ltxt [::msgcat::mc {My vCard}]
    } else {
        set ltxt {What is this}
    }
    set frbi [$nbframe newpage {Basic Info} -text [::msgcat::mc {Basic Info}]]    
    set labfrbi [LabeledFrame2 $frbi.fr $ltxt]
    pack $frbi.fr -side left -anchor n
    set pbi [frame $labfrbi.frin]
    pack $pbi -padx 10 -pady 6 -side left
    
    # Name part.
    label $pbi.first -text [::msgcat::mc {First name}]
    label $pbi.middle -text [::msgcat::mc Middle]
    label $pbi.fam -text [::msgcat::mc {Last name}]
    entry $pbi.efirst -width 16  \
      -textvariable [namespace current]::elem(n_given)
    entry $pbi.emiddle -width 4  \
      -textvariable [namespace current]::elem(n_middle)
    entry $pbi.efam -width 18  \
      -textvariable [namespace current]::elem(n_family)
    grid $pbi.first $pbi.middle $pbi.fam -sticky w
    grid $pbi.efirst $pbi.emiddle $pbi.efam -sticky ew
    
    # Other part.
    label $pbi.nick -text "[::msgcat::mc {Nick name}]:"
    label $pbi.email -text "[::msgcat::mc {Email address}]:"
    label $pbi.jid -text "[::msgcat::mc {Jabber address}]:"
    entry $pbi.enick -textvariable [namespace current]::elem(nickname)
    entry $pbi.eemail  \
      -textvariable [namespace current]::elem(email_internet_pref)
    entry $pbi.ejid -state disabled \
      -textvariable [namespace current]::vcardjid
    grid $pbi.nick -column 0 -row 2 -sticky e
    grid $pbi.enick -column 1 -row 2 -sticky news -columnspan 2
    grid $pbi.email -column 0 -row 3 -sticky e
    grid $pbi.eemail -column 1 -row 3 -sticky news -columnspan 2
    grid $pbi.jid -column 0 -row 4 -sticky e
    grid $pbi.ejid -column 1 -row 4 -sticky news -columnspan 2
    
    # Description part.
    label $pbi.ldes -text "[::msgcat::mc Description]:"    
    frame $pbi.fdes
    set wdesctxt $pbi.fdes.t
    set wdysc $pbi.fdes.ysc
    text $wdesctxt -height 4 -yscrollcommand [list $wdysc set] -wrap word \
      -borderwidth 1 -relief sunken -font $sysFont(s) -width 38
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
      -text [::msgcat::mc {Personal Info}]]
    set pbp [frame $frppers.frin]
    pack $pbp -padx 10 -pady 6 -side left -anchor n

    foreach {name tag} {
        {Personal URL}    url
        Occupation        role
        Birthday          bday
    } {
        label $pbp.l$tag -text "[::msgcat::mc $name]:"
        entry $pbp.e$tag -width 28  \
          -textvariable [namespace current]::elem($tag)
        grid $pbp.l$tag $pbp.e$tag -sticky e
    }
    label $pbp.frmt -text {Format mm/dd/yyyy}
    grid $pbp.frmt -column 1 -sticky w

    label $pbp.email -text "[::msgcat::mc {Email addresses}]:"
    grid $pbp.email -column 0 -sticky w
    set wemails $pbp.emails
    text $wemails -wrap none -bd 1 -relief sunken \
      -font $sysFont(s) -width 32 -height 8
    grid $pbp.emails -columnspan 2 -sticky w
    if {[info exists elem(email_internet)]} {
        foreach email $elem(email_internet) {
            $wemails insert end "$email\n"
        }
    }
    
    # Home page --------------------------------------------------------------
    set frprost [$nbframe newpage {Home} -text [::msgcat::mc Home]]
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
        label $pbh.l$tag -text "[::msgcat::mc $name]:"
        entry $pbh.e$tag -width 28  \
          -textvariable [namespace current]::elem($tag)
        grid $pbh.l$tag $pbh.e$tag -sticky e
    }
    
    # Work page ----------------------------------------------------------
    set frpgroup [$nbframe newpage {Work} -text [::msgcat::mc Work]]
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
        label $pbw.l$tag -text "[::msgcat::mc $name]:"
        entry $pbw.e$tag -width 28  \
          -textvariable [namespace current]::elem($tag)
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
        $wemails configure -state disabled
        $wdesctxt configure -state disabled
    }
        
    # Button part.
    frame $w.frbot -borderwidth 0
    if {$type == "own"} {
        pack [button $w.btsave -text [::msgcat::mc Save] -width 8  \
          -default active -command [namespace current]::PushBtSetVCard] \
          -in $w.frbot -side right -padx 5 -pady 5
        pack [button $w.btcancel -text [::msgcat::mc Cancel] -width 8   \
          -command "set [namespace current]::finished 0"]  \
          -in $w.frbot -side right -padx 5 -pady 5
    } else {
        pack [button $w.btcancel -text [::msgcat::mc Close] -width 8 \
          -command "set [namespace current]::finished 0"]  \
          -in $w.frbot -side right -padx 5 -pady 5
    }
    pack $w.frbot -side top -fill both -expand 1 -in $frall -padx 8 -pady 6

    wm resizable $w 0 0
    focus $w
    catch {grab $w}
    #bind $w <Return> "$w.btsave invoke"
    tkwait variable [namespace current]::finished
    
    # Clean up.
    catch {grab release $w}
    destroy $w

}

proc ::VCard::PushBtSetVCard { }  {

    variable finished
    variable elem
    variable wemails
    variable wdesctxt
    upvar ::Jabber::jstate jstate
    
    if {($elem(n_given) != "") && ($elem(n_family) != "")} {
        set elem(fn) "$elem(n_given) $elem(n_family)"
    }
    set elem(email_internet) \
      [regsub -all "(\[^ \n\t]+)(\[ \n\t]*)" [$wemails get 1.0 end] {\1 } tmp]
    set elem(email_internet) [string trim $tmp]
    set elem(desc) [$wdesctxt 1.0 end]
    
    # Collect all non empty entries, and send a vCard set.
    set argList {}
    foreach key [array names elem] {
	if {$elem($key) != ""} {
	    lappend argList -$key $elem($key)
	}
    }
    eval {$jstate(jlib) vcard_set ::VCard::SetVCardCallback} $argList
    set finished 1
}

# VCard::SetVCardCallback --
#
#       This is our callback from the 'vcard_set' procedure.

proc ::VCard::SetVCardCallback {jlibName type theQuery} {

    #puts "::VCard::SetVCardCallback:  type=$type, theQuery='$theQuery'"
    if {$type == "error"} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox \
	  "Failed setting the vCard. The result was: $theQuery"]	  
	return
    }
}

#-------------------------------------------------------------------------------