#  VCard.tcl ---
#  
#      This file is part of The Coccinella application. 
#      
#  Copyright (c) 2001-2006  Mats Bengtsson
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
# $Id: VCard.tcl,v 1.55 2007-07-19 06:28:17 matben Exp $

package provide VCard 1.0

package require mactabnotebook

namespace eval ::VCard::  {
        
    # Add all event hooks.
    ::hooks::register initHook   ::VCard::InitHook    
    
    variable uid 0
}

proc ::VCard::InitHook { } {    
    variable locals
    
    # Drag and Drop support...
    set locals(haveTkDnD) 0
    if {![catch {package require tkdnd}]} {
	set locals(haveTkDnD) 1
    }       
}

proc ::VCard::OnMenu { } {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "connectfin"} {
	Fetch own
    }   
}

# VCard::Fetch --
#
#       Gets the vCard from 'jid'. The jid should be a 2-tier for ordinary users.

proc ::VCard::Fetch {type {jid {}}} {
    global  wDlgs
    variable uid

    if {$type eq "own"} {
	
	# We must use the 2-tier jid here!
        set jid [::Jabber::JlibCmd myjid2]
    }
    
    # Keep a separate instance specific namespace for each VCard.
    set token [namespace current]::[incr uid]
    namespace eval $token {
	variable elem
	variable priv
    }
    upvar ${token}::priv priv
    
    set priv(jid)  $jid
    set priv(type) $type
    set priv(w)    $wDlgs(jvcard)$uid
    
    # We should query the server for this and then fill in.
    ::JUI::SetStatusMessage [mc vcardget $jid]
    if {$type eq "own"} {
	::Jabber::JlibCmd vcard send_get_own  \
	  [list [namespace current]::FetchCallback $token]
    } else {
	::Jabber::JlibCmd vcard send_get $jid  \
	  [list [namespace current]::FetchCallback $token]
    }
}

# VCard::FetchCallback --
#
#       This is our callback from the 'vcard send_get' procedure.

proc ::VCard::FetchCallback {token jlibName result theQuery} {
    
    ::Debug 4 "::VCard::FetchCallback"
    
    if {$result eq "error"} {
	set errmsg "([lindex $theQuery 0]) [lindex $theQuery 1]"
        ::UI::MessageBox -title [mc Error] -icon error -type ok \
          -message [mc vcarderrget $errmsg]
        ::JUI::SetStatusMessage ""
	Free $token
        return
    }
    ::JUI::SetStatusMessage [mc vcardrec]
    
    # The 'theQuery' now contains all the vCard data in a xml list.
    if {[llength $theQuery]} {
        ParseXmlList $theQuery ${token}::elem
    }
    Build $token
    Fill $token
}

# VCard::ParseXmlList --
#
#       Parses the xml list of the very weird looking vCard xml into an array.

proc ::VCard::ParseXmlList {subiq arrName} {
    
    upvar #0 $arrName arr
    
    foreach c [wrapper::getchildren $subiq] {
        set tag [string tolower [wrapper::gettag $c]]
	
        switch -- $tag {
            fn - nickname - bday - url - title - role - desc - jabberid {
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
	    photo {
		foreach sub [wrapper::getchildren $c] {
		    set subt [string tolower [wrapper::gettag $sub]]
		    set arr(photo_$subt) [wrapper::getcdata $sub]
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

proc ::VCard::Build {token} {
    global  this prefs wDlgs
    
    upvar ${token}::elem elem
    upvar ${token}::priv priv
    
    ::Debug 4 "::VCard::Build token=$token"

    set anyChange 0
    set w    $priv(w)
    set jid  $priv(jid)
    set type $priv(type)
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} -closecommand ::VCard::CloseHook
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jvcard)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jvcard)
    }

    if {$type eq "own"} {
	wm title $w [mc {My vCard}]
    } else {
	set djid [::Roster::GetDisplayName $jid]
	wm title $w "[mc {vCard Info}]: $djid"
    }
    set priv(vcardjid) $jid
    set elem(jid) [jlib::unescapejid $jid]
    
    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill both -expand 1

    set wnb $wall.nb
    ttk::notebook $wnb -padding [option get . dialogNotebookPadding {}]
    pack $wnb -side top
        
    Pages $wnb ${token}::elem $type
	
    # Button part.
    set frbot $wall.b
    ttk::frame $frbot -padding [option get . okcancelNoTopPadding {}]
    set padx [option get . buttonPadX {}]
    if {$type eq "own"} {
	ttk::button $frbot.btok -text [mc Save]  \
	  -default active -command [list [namespace current]::SetVCard $token]
	ttk::button $frbot.btcancel -text [mc Cancel]  \
	  -command [list [namespace current]::Close $token]
	if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	    pack $frbot.btok -side right
	    pack $frbot.btcancel -side right -padx $padx
	} else {
	    pack $frbot.btcancel -side right
	    pack $frbot.btok -side right -padx $padx
	}
    } else {
	ttk::button $frbot.btcancel -text [mc Close] \
	  -command [list [namespace current]::Close $token]
	pack $frbot.btcancel -side right
    }
    pack $frbot -side bottom -fill x
    
    ttk::notebook::enableTraversal $wnb
    wm resizable $w 0 0
    focus $w
}

# VCard::Pages --
# 
#       Make the notebook pages.

proc ::VCard::Pages {nbframe etoken type} {
    
    variable locals
    upvar $etoken elem
        
    ::Debug 4 "::VCard::Pages etoken=$etoken, type=$type"
    
    # Start with the Basic Info -------------------------------------------------
   
    $nbframe add [ttk::frame $nbframe.fbas] -text [mc {Basic Info}] -sticky news

    set pbi $nbframe.fbas.f
    ttk::frame $pbi -padding [option get . notebookPagePadding {}]
    pack  $pbi  -side top -anchor [option get . dialogAnchor {}]

    # Name part.
    ttk::label $pbi.first  -text "[mc {First name}]:"
    ttk::label $pbi.middle -text "[mc Middle]:  "
    ttk::label $pbi.fam    -text "[mc {Last name}]:"
    ttk::entry $pbi.efirst  -width 16 -textvariable $etoken\(n_given)
    ttk::entry $pbi.emiddle -width 2 -textvariable $etoken\(n_middle)
    ttk::entry $pbi.efam    -width 18 -textvariable $etoken\(n_family)

    grid  $pbi.first   $pbi.middle   $pbi.fam   -sticky w
    grid  $pbi.efirst  $pbi.emiddle  $pbi.efam  -sticky ew -padx 1 -pady 2
    
    # Other part.
    ttk::label $pbi.nick   -text "[mc {Nick name}]:"
    ttk::label $pbi.email  -text "[mc {Email address}]:"
    ttk::label $pbi.jid    -text "[mc {Jabber ID}]:"
    ttk::entry $pbi.enick  -textvariable $etoken\(nickname)
    ttk::entry $pbi.eemail -textvariable $etoken\(email_internet_pref)
    ttk::entry $pbi.ejid   -textvariable $etoken\(jid)
    
    grid  $pbi.nick   $pbi.enick   -sticky e -pady 2
    grid  $pbi.email  $pbi.eemail  -sticky e -pady 2
    grid  $pbi.jid    $pbi.ejid    -sticky e -pady 2
    
    grid  $pbi.enick  $pbi.eemail  $pbi.ejid  -sticky news -columnspan 2
    
    $pbi.ejid state {readonly}
        
    # Description part.
    set wdesctxt $pbi.tdes
    ttk::label $pbi.ldes -text "[mc Description]:"    

    set wdesctxt $pbi.fde.t
    set wdysc    $pbi.fde.y
    frame $pbi.fde -bd 1 -relief sunken
    #frame $pbi.fde
    text $wdesctxt -height 8 -wrap word -width 20 -bd 0 -relief sunken \
      -yscrollcommand [list $wdysc set]
    ttk::scrollbar $wdysc -orient vertical -command [list $wdesctxt yview]
    pack $wdysc   -side right -fill y
    pack $wdesctxt -fill both -expand 1

    grid  $pbi.ldes  -sticky w  -pady 2
    grid  $pbi.fde   -sticky ew -columnspan 3
            
    # Personal Info page -------------------------------------------------------
    
    $nbframe add [ttk::frame $nbframe.fp] -text [mc {Personal Info}] -sticky news

    set pbp $nbframe.fp.f
    ttk::frame $pbp -padding [option get . notebookPagePadding {}]
    pack  $pbp  -side top -anchor [option get . dialogAnchor {}]

    set wtop $pbp.t
    ttk::frame $wtop
    pack $wtop -fill x -expand 1

    foreach {name tag} {
        {Personal URL}    url
        Occupation        role
        Birthday          bday
    } {
	ttk::label $wtop.l$tag -text "[mc $name]:"
	if {$tag eq "url" && $type ne "own"} {
	    if {[info exists elem(url)]} {
		set url $elem(url)
	    } else {
		set url ""
	    }
	    ttk::button $wtop.e$tag -style Url -class TUrl  \
	      -text $url -command [list ::Text::UrlButton $url]
	} else {
	    ttk::entry $wtop.e$tag -width 28 -textvariable $etoken\($tag)
	}
        grid  $wtop.l$tag  $wtop.e$tag -sticky e -pady 2
	if {[winfo class $wtop.e$tag] eq "TEntry"} {
	    grid  $wtop.e$tag  -sticky ew
	} else {
	    grid  $wtop.e$tag  -sticky w	    
	}
    }
    ttk::label $wtop.frmt -style Small.TLabel -text [mc {Format mm/dd/yyyy}]
    grid  x  $wtop.frmt  -sticky w
    grid columnconfigure $wtop 1 -weight 1
    
    set wmid $pbp.m
    ttk::frame $wmid
    pack $wmid -fill x -expand 1 -pady 8

    ttk::label $wmid.email -text "[mc {Email addresses}]:"
    grid  $wmid.email  -  -sticky w
    
    set  wemails $wmid.emails
    text $wemails -wrap none -bd 1 -relief sunken -width 32 -height 3
    grid $wmid.emails  -  -sticky ew
    grid columnconfigure $wmid 1 -weight 1

    set wbot $pbp.b
    ttk::frame $wbot
    pack $wbot -anchor w -pady 4

    set wp1 $wbot.1
    ttk::frame $wp1
    pack $wp1 -side left -padx 4 -fill y

    ttk::label $wp1.l -text "[mc {Users Avatar}]:"
    ttk::button $wp1.b -text [mc {Select Photo}]  \
      -command [list ::VCard::SelectPhoto $etoken]
    ttk::button $wp1.br -text [mc {Remove Photo}] \
      -command [list ::VCard::DeletePhoto $etoken]
        
    grid  $wp1.l   -sticky ne
    grid  $wp1.b   -sticky se -pady 8
    grid  $wp1.br  -sticky se
    grid rowconfigure $wp1 0 -weight 1

    set wp2 $wbot.2
    ::Avatar::Widget $wp2
    pack  $wp2 -side left

    set pbptop $wtop
    set pbpmid $wmid
    set wbtphoto $wp1.b
    set wbtphrem $wp1.br
    set wfrphoto $wp2
    
    # Fill in any image.
    if {[info exists elem(photo_binval)]} {
	set mimetype ""
	if {[info exists elem(photo_type)]} {
	    set mimetype $elem(photo_type)
	}
	set im [::Utils::ImageFromData $elem(photo_binval) $mimetype]
	if {$im ne ""} {
	    ::Avatar::WidgetSetPhoto $wp2 $im
	}
    }
    
    # Home page --------------------------------------------------------------

    $nbframe add [ttk::frame $nbframe.fh] -text [mc Home] -sticky news

    set pbh $nbframe.fh.f
    ttk::frame $pbh -padding [option get . notebookPagePadding {}]
    pack  $pbh  -side top -anchor [option get . dialogAnchor {}]
        
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
	ttk::label $pbh.l$tag -text "[mc $name]:"
	ttk::entry $pbh.e$tag -width 28 -textvariable $etoken\($tag)
        grid  $pbh.l$tag  $pbh.e$tag -sticky e -pady 2
    }
    
    # Work page ----------------------------------------------------------

    $nbframe add [ttk::frame $nbframe.fw] -text [mc Work] -sticky news

    set pbw $nbframe.fw.f
    ttk::frame $pbw -padding [option get . notebookPagePadding {}]
    pack  $pbw  -side top -anchor [option get . dialogAnchor {}]

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
	ttk::label $pbw.l$tag -text "[mc $name]:"
	ttk::entry $pbw.e$tag -width 28 -textvariable $etoken\($tag)
        grid  $pbw.l$tag  $pbw.e$tag  -sticky e -pady 2
    }

    # If not our card, all entries readonly.
    if {$type eq "other"} {
        foreach wpar [list $pbi $pbp $pbh $pbw $pbptop $pbpmid] {
            foreach win [winfo children $wpar] {
                if {[winfo class $win] eq "TEntry"} {
                    $win state {readonly}
                }
            }
        }
        $wemails  configure -state disabled
        $wdesctxt configure -state disabled
	$wbtphoto state {disabled}
	$wbtphrem state {disabled}
    }

    set elem(w,frphoto) $wfrphoto
    set elem(w,emails)  $wemails
    set elem(w,desctxt) $wdesctxt
    
    if {$locals(haveTkDnD)} {
	InitDnD $etoken
    }
}

proc ::VCard::Fill {etoken} {

    upvar $etoken elem
    
    if {[info exists elem(desc)]} {
	$elem(w,desctxt) insert end $elem(desc)
    }    
    if {[info exists elem(email_internet)]} {
	foreach email $elem(email_internet) {
	    $elem(w,emails) insert end "$email\n"
	}
    }
}

proc ::VCard::InitDnD {etoken} {
    
    upvar $etoken elem

    set win $elem(w,frphoto)
    
    dnd bindtarget $win text/uri-list <Drop>      \
      [list [namespace current]::DnDDrop $etoken %W %D %T]   
    dnd bindtarget $win text/uri-list <DragEnter> \
      [list [namespace current]::DnDEnter $etoken %W %A %D %T]   
    dnd bindtarget $win text/uri-list <DragLeave> \
      [list [namespace current]::DnDLeave $etoken %W %D %T]       
}

proc ::VCard::DnDDrop {etoken w data type} {

    # Take only first file.
    set f [lindex $data 0]
	
    # Strip off any file:// prefix.
    set f [string map {file:// ""} $f]
    set f [uriencode::decodefile $f]
    if {[VerifyPhotoFile $f]} {
	SetPhotoFile $etoken $f
    }
}

proc ::VCard::DnDEnter {etoken w action data type} {
    
    ::Debug 2 "::VCard::DnDEnter action=$action, data=$data, type=$type"

    set act "none"
    set f [lindex $data 0]
    if {[VerifyPhotoFile $f]} {
	set act $action
    }
    return $act
}

proc ::VCard::DnDLeave {etoken w data type} {
    
    # empty
}

proc ::VCard::VerifyPhotoFile {f} {
    
    set ok 0
    set suff [file extension $f]
    if {[regexp {(.gif|.jpg|.jpeg|.png)} $suff]} {
	set ok [::Media::HaveImporterForMime [::Types::GetMimeTypeForFileName $f]]
    }
    return $ok
}

proc ::VCard::SelectPhoto {etoken} {
    
    upvar $etoken elem
    
    set mimeL {image/gif image/png image/jpeg}
    set suffL [::Types::GetSuffixListForMimeList $mimeL]
    set types [concat [list [list {Image Files} $suffL]] \
      [::Media::GetDlgFileTypesForMimeList $mimeL]]
    set fileName [tk_getOpenFile -title [mc {Pick Image File}] -filetypes $types]
    if {[file exists $fileName]} {
	SetPhotoFile $etoken $fileName   
    }
}

proc ::VCard::SetPhotoFile {etoken fileName} {
    
    upvar $etoken elem
    
    if {[::Avatar::CreateAndVerifyPhoto $fileName name]} {
	::Avatar::WidgetSetPhoto $elem(w,frphoto) $name
	set elem(w,photoFile) $fileName
	
	# Store as element if we want to send it off.
	set fd [open $fileName {RDONLY}]
	fconfigure $fd -translation binary
	set elem(photo_binval) [::base64::encode [read $fd]]
	set elem(photo_type)   [Types::GetMimeTypeForFileName $fileName]
	close $fd
    }
}

proc ::VCard::DeletePhoto {etoken} {
    
    upvar $etoken elem
    
    ::Avatar::WidgetSetPhoto $elem(w,frphoto) ""
    unset -nocomplain elem(photo_binval)
}

proc ::VCard::SetVCard {token}  {

    upvar ${token}::elem elem
    upvar ${token}::priv priv
    
    set wemails  $elem(w,emails)
    set wdesctxt $elem(w,desctxt)

    if {[info exists elem(n_given)] && [info exists elem(n_family)]} {
	if {($elem(n_given) ne "") && ($elem(n_family) ne "")} {
	    set elem(fn) "$elem(n_given) $elem(n_family)"
	}
    }
    set elem(email_internet) \
      [regsub -all "(\[^ \n\t]+)(\[ \n\t]*)" [$wemails get 1.0 end] {\1 } tmp]
    set elem(email_internet) [string trim $tmp]
    set elem(desc) [string trim [$wdesctxt get 1.0 end]]
        
    array unset  elem w,*
    
    # Collect all non empty entries, and send a vCard set.
    set argList {}
    foreach {key value} [array get elem] {
	if {[string length $value]} {
	    lappend argList -$key $value
	}
    }
    eval {::Jabber::JlibCmd vcard send_set ::VCard::SetVCardCallback} $argList
    
    # Sync the photo (also empty) with our avatar.
    SyncAvatar $token
    
    Close $token
}

# VCard::SyncAvatar --
# 
#       @@@ Having avatar both as server stored vcard and locally stored file
#           is a problem!

proc ::VCard::SyncAvatar {token} {
    
    upvar ${token}::elem elem
    upvar ${token}::priv priv

    # @@@ Update presence hashes only if changed photo. TODO check.
    if {[info exists elem(photo_binval)]} {
	::Jabber::JlibCmd avatar set_data $elem(photo_binval) $elem(photo_type)
	::Avatar::SetShareOption 1
	::Avatar::SetMyAvatarFromBase64 $elem(photo_binval) $elem(photo_type)

	# Need to do this ourselves.
	::Jabber::JlibCmd send_presence -keep 1
    } else {
	::Jabber::JlibCmd avatar unset_data
	::Avatar::UnsetAndUnshareMyAvatar
    }
}

proc ::VCard::CloseHook {wclose} {

    set token [GetTokenFrom w $wclose]
    if {$token ne ""} {
	Close $token
    }   
}

proc ::VCard::GetTokenFrom {key pattern} {
    
    foreach ns [namespace children [namespace current]] {
	set val [set ${ns}::priv($key)]
	if {[string match $pattern $val]} {
	    return $ns
	}
    }
    return
}

proc ::VCard::Close {token} {
    global  wDlgs
    
    upvar ${token}::priv priv
    
    ::UI::SaveWinGeom $wDlgs(jvcard) $priv(w)
    destroy $priv(w)
    Free $token
}

# VCard::SetVCardCallback --
#
#       This is our callback from the 'vcard send_set' procedure.

proc ::VCard::SetVCardCallback {jlibName type theQuery} {

    if {$type eq "error"} {
	::UI::MessageBox -title [mc Error] -icon error -type ok \
	  -message "Failed setting the vCard. The result was: $theQuery"
	return
    }
}

proc ::VCard::Free {token} {
    
    namespace delete $token
}

#-------------------------------------------------------------------------------
