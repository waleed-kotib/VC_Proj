#  VCard.tcl ---
#  
#      This file is part of The Coccinella application. 
#      
#  Copyright (c) 2001-2007  Mats Bengtsson
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
# $Id: VCard.tcl,v 1.76 2007-10-21 13:27:47 matben Exp $

package provide VCard 1.0

namespace eval ::VCard::  {
        
    # Add all event hooks.
    ::hooks::register initHook               ::VCard::InitHook    
    ::hooks::register menuVCardFilePostHook  ::VCard::FileMenuPostHook
    ::hooks::register onMenuVCardExport      ::VCard::OnMenuExportHook

    variable uid 0
}

proc ::VCard::InitHook {} {    
    variable locals
    
    # Drag and Drop support...
    set locals(haveTkDnD) 0
    if {[tk windowingsystem] ne "aqua"} {
	if {![catch {package require tkdnd}]} {
	    set locals(haveTkDnD) 1
	}      
    }
}

proc ::VCard::OnMenu {} {
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
    
    # @@@ Should use a named array as token instead of using namespaces.
    
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
    ::JUI::SetStatusMessage "[mc vcardget2 $jid]..."
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
    upvar ${token}::priv priv
    
    ::Debug 4 "::VCard::FetchCallback"
    
    if {$result eq "error"} {
	set str [mc vcarderrget2]
	append str "\n" "[mc Error]: ([lindex $theQuery 0]) [lindex $theQuery 1]"
	::UI::MessageBox -title [mc Error] -icon error -type ok -message $str
        ::JUI::SetStatusMessage ""
	Free $token
        return
    }
    ::JUI::SetStatusMessage [mc vcardrec2]
    
    # The 'theQuery' now contains all the vCard data in a xml list.
    if {[llength $theQuery]} {
        ParseXmlList $theQuery ${token}::elem
    }
    set priv(theQuery) $theQuery
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
    
    ::UI::Toplevel $w -class VCard \
      -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} -closecommand ::VCard::CloseHook
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jvcard)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jvcard)
    }

    if {$type eq "own"} {
	wm title $w [mc {Edit Business Card}]
    } else {
	set djid [::Roster::GetDisplayName $jid]
	wm title $w "[mc {Business Card}]: $djid"
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
	ttk::button $frbot.btcancel -text [mc Cancel] \
	  -command [list [namespace current]::Close $token]
	pack $frbot.btcancel -side right
    }
    ttk::button $frbot.export -text "[mc Export]..." \
      -command [list [namespace current]::Export $token]
    pack $frbot.export -side left
    
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
   
    $nbframe add [ttk::frame $nbframe.fbas] -text [mc General] -sticky news

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
    ttk::label $pbi.nick   -text "[mc Nickname]:"
    ttk::label $pbi.email  -text "[mc Email]:"
    ttk::label $pbi.jid    -text "[mc {Contact ID}]:"
    ttk::entry $pbi.enick  -textvariable $etoken\(nickname)
    ttk::entry $pbi.eemail -textvariable $etoken\(email_internet_pref)
    ttk::entry $pbi.ejid   -textvariable $etoken\(jid)
    
    grid  $pbi.nick   $pbi.enick   -sticky e -pady 2
    grid  $pbi.email  $pbi.eemail  -sticky e -pady 2
    grid  $pbi.jid    $pbi.ejid    -sticky e -pady 2
    
    grid  $pbi.enick  $pbi.eemail  $pbi.ejid  -sticky news -columnspan 2
    
    $pbi.ejid state {readonly}
        
    ::balloonhelp::balloonforwindow $pbi.ejid [mc tooltip-contactid]
    ::balloonhelp::balloonforwindow $pbi.enick [mc registration-nick]
    ::balloonhelp::balloonforwindow $pbi.eemail [mc registration-email]

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
    
    $nbframe add [ttk::frame $nbframe.fp] -text [mc Personal] -sticky news

    set pbp $nbframe.fp.f
    ttk::frame $pbp -padding [option get . notebookPagePadding {}]
    pack  $pbp  -side top -anchor [option get . dialogAnchor {}]

    set wtop $pbp.t
    ttk::frame $wtop
    pack $wtop -fill x -expand 1

    foreach {name tag} {
        Website           url
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
    ttk::label $wtop.frmt -style Small.TLabel -text [mc "Format: mm/dd/yyyy"]
    grid  x  $wtop.frmt  -sticky w
    grid columnconfigure $wtop 1 -weight 1

    ::balloonhelp::balloonforwindow $wtop.eurl [mc registration-url]

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

    ttk::label $wp1.l -text "[mc Avatar]:"
    ttk::button $wp1.b -text "[mc {Select Avatar}]..."  \
      -command [list ::VCard::SelectPhoto $etoken]
    ttk::button $wp1.br -text [mc "Remove Avatar"] \
      -command [list ::VCard::DeletePhoto $etoken]
        
    grid  $wp1.l   -sticky ne
    grid  $wp1.b   -sticky ew -pady 8
    grid  $wp1.br  -sticky ew
    grid rowconfigure $wp1 0 -weight 1

    set wp2 $wbot.2
    set wavatar [::Avatar::Widget $wp2]
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
	    
	    if {$locals(haveTkDnD)} {
		InitAvatarDnD $wavatar $etoken
	    }
	}
    }
    
    # Home page --------------------------------------------------------------

    $nbframe add [ttk::frame $nbframe.fh] -text [mc Home] -sticky news

    set pbh $nbframe.fh.f
    ttk::frame $pbh -padding [option get . notebookPagePadding {}]
    pack  $pbh  -side top -anchor [option get . dialogAnchor {}]
        
    foreach {name tag} {
        Address           adr_home_street
        Address           adr_home_extadd
        City              adr_home_locality
        Region            adr_home_region
        "Postal code"     adr_home_pcode
        Country           adr_home_country
        "Tel (voice)"     tel_voice_home
        "Tel (fax)"       tel_fax_home
    } {
	if {$tag eq "adr_home_street"} {
	    append name " 1"
	} elseif {$tag eq "adr_home_extadd"} {
	    append name " 2"
	}
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
        Company           org_orgname 
        Department        org_orgunit
        Title             title
        Address           adr_work_street
        Address           adr_work_extadd
        City              adr_work_locality
        Region            adr_work_region
        "Postal code"     adr_work_pcode
        Country           adr_work_country
        "Tel (voice)"     tel_voice_work
        "Tel (fax)"       tel_fax_work
    } {
	if {$tag eq "adr_home_street"} {
	    append name " 1"
	} elseif {$tag eq "adr_home_extadd"} {
	    append name " 2"
	}
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

proc ::VCard::InitAvatarDnD {win etoken} {
 
    dnd bindsource $win text/uri-list \
	[list ::VCard::AvatarDnDFileSource $etoken %W]
    
    # We trigger on Leave in order to not interfere with the drop target.
    bind $win <Button1-Leave> { dnd drag %W }
}

proc ::VCard::AvatarDnDFileSource {etoken win} {
    global  this
    upvar $etoken elem
    
    if {[info exists elem(photo_type)] && [info exists elem(photo_binval)]} {

	set tail [uriencode::quote $elem(jid)]
	set suff [::Types::GetSuffixListForMime $elem(photo_type)]
	set fileName [file join $this(tmpPath) $tail]$suff
	set fd [open $fileName w]
 	fconfigure $fd -translation binary
	puts -nonewline $fd [::base64::decode $elem(photo_binval)]
	close $fd
	
	# @@@ Do I need a "file://" prefix?
	return [list $fileName]
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
    set fileName [tk_getOpenFile -title [mc "Select Avatar"] -filetypes $types]
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

proc ::VCard::CreateList {token} {
    
    upvar ${token}::elem elem
    
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

    # Collect all non empty entries, and send a vCard set.
    set argList [list]
    foreach {key value} [array get elem] {
	if {![string match w,* $key] && [string length $value]} {
	    lappend argList -$key $value
	}
    }
    return $argList
}

proc ::VCard::SetVCard {token}  {

    eval {::Jabber::JlibCmd vcard send_set ::VCard::SetVCardCallback} \
      [CreateList $token]
    
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

proc ::VCard::GetTokenList {} {
    return [namespace children [namespace current]]
}

proc ::VCard::GetTokenFrom {key pattern} {
    foreach ns [GetTokenList] {
	set val [set ${ns}::priv($key)]
	if {[string match $pattern $val]} {
	    return $ns
	}
    }
    return
}

proc ::VCard::GetFrontToken {} {
    if {[winfo exists [focus]]} {
	if {[winfo class [winfo toplevel [focus]]] eq "VCard"} {
	    set w [winfo toplevel [focus]]
	    return [GetTokenFrom w $w]
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

proc ::VCard::FileMenuPostHook {wmenu} {
    
    puts "::VCard::FileMenuPostHook"
    if {[tk windowingsystem] eq "aqua"} {
	
	# Need to have a different one for aqua due to the menubar.
	set m [::UI::MenuMethod $wmenu entrycget mExport -menu]
	set token [GetFrontToken]
	if {$token ne ""} {
	    ::UI::MenuMethod $m entryconfigure mBC... -state normal
	}
    }
}

proc ::VCard::Export {token} {    
    upvar ${token}::priv priv
    ExportXML $token $priv(jid)
}

# VCard::OnMenuExport --
# 
#       We do this event based since also the UserInfo dialog may export
#       a vCard. If we can export we must return "stop".

proc ::VCard::OnMenuExport {} {
    ::hooks::run onMenuVCardExport
}

proc ::VCard::OnMenuExportHook {} {
    set token [GetFrontToken]
    if {$token ne ""} {
	upvar ${token}::priv priv
	ExportXML $token $priv(jid)
	return stop
    }
    return
}

proc ::VCard::ExportXMLFromJID {jid} {
    set f [uriencode::quote $jid].xml
    set fileName [tk_getSaveFile -defaultextension .xml -initialfile $f]
    if {$fileName ne ""} {
	::Jabber::JlibCmd vcard send_get $jid \
	  [namespace code [list ExportJIDCB $jid $fileName]]
    }
}

proc ::VCard::ExportJIDCB {jid fileName jlib type vcardE} {
    
    if {$type eq "result"} {
	SaveElementToFile $fileName $jid $vcardE
    } else {
	set errmsg "([lindex $vcardE 0]) [lindex $vcardE 1]"
	ui::dialog -title [mc Error] -icon error -type ok \
	  -message [mc vcarderrget $errmsg]
    }
}

proc ::VCard::ExportXML {token jid} {
    set f [uriencode::quote $jid].xml
    set fileName [tk_getSaveFile -defaultextension .xml -initialfile $f]
    if {$fileName ne ""} {
	SaveToFile $token $fileName $jid
    }
}

proc ::VCard::SaveToFile {token fileName jid} {
    
    set vcardE [eval {::Jabber::JlibCmd vcard create} [CreateList $token]]
    SaveElementToFile $fileName $jid $vcardE
}

proc ::VCard::SaveElementToFile {fileName jid vcardE} {
    
    if {[llength $vcardE]} {
	set xml [wrapper::formatxml $vcardE]
    } else {
	set xml ""
    }
    set fd [open $fileName w]
    fconfigure $fd -encoding utf-8

    puts $fd "<?xml version='1.0' encoding='UTF-8'?>"
    puts $fd "<!-- vCard for $jid -->"
    puts $fd $xml
    close $fd
}

proc ::VCard::Import {} {
    
    set ans [tk_messageBox -icon question -type yesno \
      -message "This will replace your current business card. Do you actually want this?"]
    if {$ans ne "yes"} {
	return
    }
    set fileName [tk_getOpenFile -defaultextension .xml \
      -title [mc "Open Business Card"] -filetypes {{"vCard" ".xml"}}]
    if {$fileName ne ""} {
	if {[file extension $fileName] ne ".xml"} {
	    tk_messageBox -icon error -title [mc Error] \
	      -message "File must have an extension \".xml\""
	    return
	}
	ImportFromFile $fileName
    }
}

proc ::VCard::ImportFromFile {fileName} {
    
    set fd [open $fileName r]
    fconfigure $fd -encoding utf-8
    set xml [read $fd]
    close $fd
    
    # Just check that the root element looks OK.
    set token [tinydom::parse $xml]
    set xmllist [tinydom::documentElement $token]
    
    if {([tinydom::tagname $xmllist] ne "vCard") || \
      ([tinydom::getattribute $xmllist xmlns] ne "vcard-temp")} {
	tk_messageBox -icon error -title [mc Error] \
	  -message "Not a proper vCard XML format"
	return
    }
    ::Jabber::JlibCmd send_iq "set" [list $xmllist]
    tinydom::cleanup $token
}

# VCard::ImportVCFtoXML --
# 
#       Import a vcf file. Incomplete! Untested!
# 
#       http://en.wikipedia.org/wiki/VCard
#       http://tools.ietf.org/html/rfc2426
# 

proc ::VCard::ImportVCFtoXML {fileName} {
    
    set opts [list]
    
    # In case of multiple contacts per file pick only the first one.
    # Encoding?
    set fd [open $fileName r]
    while {[gets $fd line] != -1} {
	set idx1 [string first ":" $line]
	set idx2 [string first ";" $line]
	set idx [expr {($idx1 > $idx2) ? $idx1 : $idx2}]
	if {$idx == -1} {
	    continue
	}
	set type [string tolower [string range $line 0 [expr {$idx - 1}]]]
	set value [string range $line [expr {$idx + 1}] end]
	
	switch -- $type {
	    begin {
		
	    }
	    end {
		break
	    }
	    fn - nickname - bday {
		lappend opts -$type $value
	    }
	    n {
		set valueL [split $value ";"]
		lassign $valueL family given add pref suff
		foreach n {family given} {
		    set v [set $name]
		    if {$v ne ""} {
			lappend opts -${type}_${n}
		    }
		}
	    }
	    photo {
		# @@@ TODO
	    }
	    adr {
		
		
	    }
	    tel {
		
		
	    }
	    
	    
	}	
    }    
    close $fd

    
    set vcardE [eval {::Jabber::JlibCmd vcard create} $opts]
    
}

proc ::VCard::Free {token} {
    
    namespace delete $token
}

#-------------------------------------------------------------------------------
