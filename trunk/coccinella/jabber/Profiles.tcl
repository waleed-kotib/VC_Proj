#  Profiles.tcl ---
#  
#      This file implements code for handling profiles.
#      
#  Copyright (c) 2003-2004  Mats Bengtsson
#  
# $Id: Profiles.tcl,v 1.12 2004-03-16 15:09:08 matben Exp $

package provide Profiles 1.0

namespace eval ::Profiles:: {
    
    # Define all hooks that are needed.
    ::hooks::add prefsInitHook          ::Profiles::InitHook
    ::hooks::add prefsBuildHook         ::Profiles::BuildHook
    ::hooks::add prefsUserDefaultsHook  ::Profiles::UserDefaultsHook
    ::hooks::add prefsSaveHook          ::Profiles::SaveHook
    ::hooks::add prefsCancelHook        ::Profiles::CancelHook
    ::hooks::add initHook               ::Profiles::ImportIfNecessary
    ::hooks::add closeWindowHook        ::Profiles::CloseDlgHook
    
    # Internal storage:
    #   {name1 {server1 username1 password1 ?-key value ...?} \
    #    name2 {server2 username2 password2 ?-key value ...?} ... }
    variable profiles
    
    # Profile name of selected profile.
    variable selected
}

proc ::Profiles::InitHook { } {
    variable profiles
    variable selected
    
    set profiles {jabber.org {jabber.org myUsername myPassword}}
    set selected [lindex $profiles 0]

    ::PreferencesUtils::Add [list  \
      [list ::Profiles::profiles   profiles          $profiles   userDefault] \
      [list ::Profiles::selected   selected_profile  $selected   userDefault]]
}

# Profiles::Set --
#
#       Sets or replaces a user profile.
#       
# Arguments:
#       name        if empty, make a new unique profile, else, create this,
#                   possibly replace if exists already.
#       server      Jabber server name.
#       username
#       password
#       args:       -resource, -ssl, -priority, -invisible, -ip, -scramble, ...
#       
# Results:
#       none.

proc ::Profiles::Set {name server username password args} {    
    variable profiles
    variable selected
    
    ::Jabber::Debug 2 "name=$name, s=$server, u=$username, p=$password, '$args'"

    array set profArr $profiles
    set allNames [::Profiles::GetAllNames]
    
    # Create a new unique profile name.
    if {[string length $name] == 0} {
	set name $server

	# Make sure that 'profile' is unique.
	if {[lsearch -exact $allNames $name] >= 0} {
	    set i 2
	    set tmpprof $name
	    set name ${tmpprof}-${i}
	    while {[lsearch -exact $allNames $name] >= 0} {
		incr i
		set name ${tmpprof}-${i}
	    }
	}
    }
    set profArr($name) [concat [list $server $username $password] $args]
    set profiles [array get profArr]
    set selected $name
    
    # Keep them sorted.
    ::Profiles::SortProfileList
    return ""
}


proc ::Profiles::Remove {name} {
    variable profiles
    variable selected
    
    ::Jabber::Debug 2 "::Profiles::Remove name=$name"
    
    # Don't remove the last one.
    if {[llength $profiles] <= 2} {
	return
    }
    set ind [lsearch -exact $profiles $name]
    if {$ind >= 0} {
	if {[string equal $selected $name]} {
	    set selected [lindex $profiles 0]
	}
	set profiles [lreplace $profiles $ind [incr ind]]
    }
    return ""
}

# Profiles::FindProfileNameFromJID --
# 
#       Returns first matching 'profile' for jid.
#       It makes only sence for jid2's.
#       
# Arguments:
#       jid        any jid, 2 or 3-tier
#       
# Results:
#       matching profile name or empty.

proc ::Profiles::FindProfileNameFromJID {jid} {
    variable profiles
    
    set profilename ""
    
    # If jid2 the resource == "". Find any match.
    if {[regexp {(^.+)@([^/]+)(/(.*))?} $jid m username server x resource]} {    
	foreach {prof spec} $profiles {
	    
	    foreach {serv user pass} $spec break
	    catch {unset opts}
	    set opts(-resource) ""
	    array set opts [lrange $spec 3 end]
	    
	    if {($serv == $server) && ($user == $username)} {
		if {$resource != ""} {
		    if {$resource == $opts(-resource)} {
			set profilename $prof
			break
		    }
		} else {
		    set profilename $prof
		    break
		}
	    }
	}
    }
    return $profilename
}

proc ::Profiles::Get { } {
    variable profiles
 
    return $profiles
}

proc ::Profiles::GetProfile {name} {
    variable profiles
 
    array set profArr $profiles
    if {[info exists profArr($name)]} {
	return $profArr($name)
    } else {
	return ""
    }
    return $profiles
}

proc ::Profiles::GetSelectedName { } {
    variable selected
 
    set all [::Profiles::GetAllNames]
    if {[lsearch -exact $all $selected] < 0} {
	return [lindex $all 0]
    } else {
	return $selected
    }
}

proc ::Profiles::SetSelectedName {name} {
    variable selected
    
    set selected $name
}

# Profiles::GetAllNames --
# 
#       Utlity function to get a list of the names of all profiles. Sorted!

proc ::Profiles::GetAllNames { } {
    variable profiles

    set names {}
    foreach {name spec} $profiles {
	lappend names $name
    }    
    return [lsort -dictionary $names]
}

# Profiles::SortProfileList --
# 
#       Just sorts the profiles list using names only.

proc ::Profiles::SortProfileList { } {
    variable profiles

    set tmp {}
    array set profArr $profiles
    foreach name [::Profiles::GetAllNames] {
	lappend tmp $name $profArr($name)
    }
    set profiles $tmp
}

proc ::Profiles::ImportIfNecessary { } {
    variable profiles
    variable selected
    upvar ::Jabber::jserver jserver
    
    #puts "::Profiles::ImportIfNecessary"

    if {[info exists jserver(profile)] && [info exists jserver(profile,selected)]} {

	# Use ad hoc method to figure out if want to import profiles.
	if {[string equal [lindex $profiles 1 1] "myUsername"] && \
	  ([llength $profiles] == 2)} {
	    ::Profiles::ImportFromJserver
	}
    }
}

proc ::Profiles::ImportFromJserver { } {
    variable profiles
    variable selected
    upvar ::Jabber::jserver jserver
    
    #puts "::Profiles::ImportFromJserver"
    
    #  jserver(profile,selected)  profile picked in user info
    #  jserver(profile):   {profile1 {server1 username1 password1 resource1}}
    #  
    set profiles {}
    foreach {name spec} $jserver(profile) {
	foreach {se us pa re} $spec break
	set plist [list $se $us $pa]
	if {$re != ""} {
	    lappend plist -resource $re
	}
	lappend profiles $name $plist
    }
    set selected $jserver(profile,selected)
}

# User Profiles Page ...........................................................

proc ::Profiles::BuildHook {wtree nbframe} {
    
    $wtree newitem {Jabber {User Profiles}}  \
      -text [::msgcat::mc {User Profiles}]

    set wpage [$nbframe page {User Profiles}]    
    ::Profiles::BuildPage $wpage
}

proc ::Profiles::BuildPage {page} {
    global  prefs
    
    variable profiles
    variable selected
    
    variable wcombo    
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable wuserinfofocus
    variable tmpProfArr
    variable tmpSelected
    
    set fontS [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]

    set lfr $page.fr
    labelframe $lfr -text [::msgcat::mc {User Profiles}]
    pack $lfr -side top -anchor w -padx 8 -pady 4
    
    message $lfr.msg -text [::msgcat::mc prefprof] -aspect 800
    pack $lfr.msg -side top -anchor w -fill x

    set pui $lfr.fr
    pack [frame $pui] -side left  
    
    # Make temp array for servers.
    ::Profiles::MakeTmpProfArr
    set tmpSelected $selected
	
    # Verify that the selected also in array.
    #if {[lsearch -exact $tmpJServer(profile) $profile] < 0} {
#	set profile [lindex $tmpJServer(profile) 0]
    #}
	
    # Init textvariables.
    set profile  $tmpSelected
    set server   $tmpProfArr($profile,server)
    set username $tmpProfArr($profile,username)
    set password $tmpProfArr($profile,password)
    set resource $tmpProfArr($profile,-resource)
    set allNames [::Profiles::GetAllNames]

    # Option menu for the servers.
    label $pui.lpop -text "[::msgcat::mc Profile]:" -anchor e
    
    set wcombo $pui.popup
    ::combobox::combobox $wcombo   \
      -textvariable [namespace current]::profile  \
      -command [namespace current]::SetCmd
    eval {$wcombo list insert end} $allNames
	
    grid $pui.lpop -column 0 -row 0 -sticky e
    grid $wcombo -column 1 -row 0 -sticky ew
    
    label $pui.lserv -text "[::msgcat::mc {Jabber Server}]:" -anchor e
    entry $pui.eserv -width 22   \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $pui.luser -text "[::msgcat::mc Username]:" -anchor e
    entry $pui.euser -width 22  \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $pui.lpass -text "[::msgcat::mc Password]:" -anchor e
    entry $pui.epass -width 22 -show {*}  \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $pui.lres -text "[::msgcat::mc Resource]:" -anchor e
    entry $pui.eres -width 22   \
      -textvariable [namespace current]::resource -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    set wuserinfofocus $wcombo

    grid $pui.lserv -column 0 -row 1 -sticky e
    grid $pui.eserv -column 1 -row 1 -sticky w
    grid $pui.luser -column 0 -row 2 -sticky e
    grid $pui.euser -column 1 -row 2 -sticky w
    grid $pui.lpass -column 0 -row 3 -sticky e
    grid $pui.epass -column 1 -row 3 -sticky w
    grid $pui.lres  -column 0 -row 4 -sticky e
    grid $pui.eres  -column 1 -row 4 -sticky w

    set puibt [frame $lfr.frbt]
    pack $puibt -padx 8 -pady 6 -side left -fill y
    pack [button $puibt.new -font $fontS -text [::msgcat::mc New]  \
      -command [namespace current]::NewCmd]   \
      -side top -fill x -pady 4
    pack [button $puibt.app -font $fontS -text [::msgcat::mc Apply] \
      -command [namespace current]::ApplyCmd]   \
      -side top -fill x -pady 4
    pack [button $puibt.del -font $fontS -text [::msgcat::mc Delete]  \
      -command [namespace current]::DeleteCmd]   \
      -side top -fill x -pady 4
}

# Profiles::MakeTmpProfArr --
#
#       Make temp array for profiles.

proc ::Profiles::MakeTmpProfArr { } {
    
    variable profiles
    variable tmpProfArr
    
    # New... Profiles
    catch {unset tmpProfArr}
    
    foreach {name spec} $profiles {
	set tmpProfArr($name,name) $name
	foreach [list \
	  tmpProfArr($name,server)   \
	  tmpProfArr($name,username) \
	  tmpProfArr($name,password)] $spec break
	set tmpProfArr($name,-resource) ""
	foreach {key value} [lrange $spec 3 end] {
	    set tmpProfArr($name,$key) $value
	}
    }
}

# Profiles::SetCmd --
#
#       Callback for the combobox when a new item is selected.

proc ::Profiles::SetCmd {wcombo profile} {
    
    variable tmpProfArr
    variable tmpSelected
    variable server
    variable username
    variable password
    variable resource
    
    #puts "::Profiles::SetCmd profile=$profile"
    
    # In case this is a new profile.
    if {[info exists tmpProfArr($profile,server)]} {
	#puts "   $profile is set"
	set server   $tmpProfArr($profile,server)
	set username $tmpProfArr($profile,username)
	set password $tmpProfArr($profile,password)
	if {[info exists tmpProfArr($profile,-resource)]} {
	    set resource $tmpProfArr($profile,-resource)
	} else {
	    set resource ""
	}
	set tmpSelected $profile  
    }
}

proc ::Profiles::NewCmd { } {
    
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable wuserinfofocus

    set profile   ""
    set server    ""
    set username  ""
    set password  ""
    set resource  ""
    focus $wuserinfofocus
}

proc ::Profiles::ApplyCmd { } {
    global  prefs
    
    variable tmpProfArr
    variable tmpSelected
    variable wcombo
    variable profile
    variable server
    variable username
    variable password
    variable resource

    #puts "::Profiles::ApplyCmd profile=$profile"
    
    # Check that necessary entries are non-empty, at least.
    if {($server == "") || ($username == "")} {
	tk_messageBox -type ok -icon error -parent [winfo toplevel $wcombo] \
	  -title [::msgcat::mc Error] -message [FormatTextForMessageBox \
	  [::msgcat::mc messfillserveruser]]
	return
    }
    
    # Create a unique profile name if not given.
    set allNames [::Profiles::GetAllTmpNames]
    if {$profile == ""} {
	set profile $server

	# Make sure that 'profile' is unique.
	if {[lsearch -exact $allNames $profile] >= 0} {
	    set i 2
	    set tmpprof $profile
	    set profile ${tmpprof}-${i}
	    while {[lsearch -exact $allNames $profile] >= 0} {
		incr i
		set profile ${tmpprof}-${i}
	    }
	}
    }
    if {$resource == ""} {
	set resource "coccinella"
    }
    
    # Handle duplicate servers. Is this good???
    if {[lsearch -exact $allNames $profile] >= 0} {
	
	# It's there already!
	set ans [tk_messageBox -type yesno -default yes -icon warning  \
	  -parent [winfo toplevel $wcombo]  \
	  -title [::msgcat::mc Warning] -message [FormatTextForMessageBox \
	  [::msgcat::mc messprofinuse]]]
	if {$ans == "no"} {
	    ::Profiles::SetCmd $wcombo [lindex $allNames 0]
	    return
	}
    } else {
	$wcombo list insert end $profile
    }
    
    # Store it the temporary array.
    set tmpProfArr($profile,name)     $profile
    set tmpProfArr($profile,server)   $server
    set tmpProfArr($profile,username) $username
    set tmpProfArr($profile,password) $password
    if {$resource != ""} {
	set tmpProfArr($profile,-resource) $resource
    }
    set tmpSelected $profile  
}

proc ::Profiles::GetAllTmpNames { } {
    variable tmpProfArr
    
    set allNames {}
    foreach {key name} [array get tmpProfArr *,name] {
	lappend allNames $name
    }    
    return [lsort -dictionary $allNames]
}

proc ::Profiles::DeleteCmd { } {
    global  prefs
    
    variable tmpProfArr
    variable tmpSelected
    variable profile
    variable wcombo
    
    #puts "::Profiles::DeleteCmd profile=$profile"
    
    # The present state may be something that has not been stored by pressing
    # the Apply button.
    if {[info exists tmpProfArr($profile,server)]} {
	
	set ans [tk_messageBox -title [::msgcat::mc Warning]  \
	  -type yesno -icon warning -default yes  \
	  -parent [winfo toplevel $wcombo] \
	  -message [FormatTextForMessageBox [::msgcat::mc messremoveprofile]]]
	if {$ans == "yes"} {
	    set allNames [::Profiles::GetAllTmpNames]
	    set ind [lsearch -exact $allNames $profile]
	    if {$ind >= 0} {
		$wcombo list delete $ind
	    }
	    array unset tmpProfArr "$profile,*"
	    set allNames [::Profiles::GetAllTmpNames]
	    set profile [lindex $allNames 0]
	    ::Profiles::SetCmd $wcombo $profile
	}
    } else {
	set allNames [::Profiles::GetAllTmpNames]
	set profile [lindex $allNames 0]
	::Profiles::SetCmd $wcombo $profile
    }
}

proc ::Profiles::UserDefaultsHook { } {
        
}

proc ::Profiles::SaveHook { } {
    variable profiles
    variable selected
    variable tmpSelected

    set profiles [::Profiles::GetTmpProfiles]
    set selected $tmpSelected
    
    # Update the Login dialog if any.
    ::Jabber::Login::LoadProfiles
}

proc ::Profiles::GetTmpProfiles { } {
    variable tmpProfArr
    
    set tmpProfiles {}
    foreach name [::Profiles::GetAllTmpNames] {
	set plist [list $tmpProfArr($name,server) $tmpProfArr($name,username) \
	  $tmpProfArr($name,password)]
	if {[info exists tmpProfArr($name,-resource)]} {
	    lappend plist -resource $tmpProfArr($name,-resource)
	}
	lappend tmpProfiles $name $plist
    }
    return $tmpProfiles
}

proc ::Profiles::CancelHook { } {
    variable profiles
    variable selected
    variable tmpProfArr
    variable tmpSelected
    
    # Detect any changes.
    if {![string equal $selected $tmpSelected]} {
	::Preferences::HasChanged
	return
    }
    set tmpProfiles [::Profiles::GetTmpProfiles]
    if {![string equal $profiles $tmpProfiles]} {
	::Preferences::HasChanged
	return
    }
}

# Standalone dialog --

proc ::Profiles::BuildDialog { } {
    global  wDlgs
    
    set w $wDlgs(jprofiles)
    if {[winfo exists $w]} {
	return
    }
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [::msgcat::mc Profiles]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4

    set wpage $w.frall.page
    pack [frame $wpage] -padx 4 -pady 4
    ::Profiles::BuildPage $wpage
    
    # Button part.
    set btwidth [expr [::Utils::GetMaxMsgcatWidth Save Cancel] + 2]
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Save] -width $btwidth \
      -default active -command [list [namespace current]::SaveDlg $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::CancelDlg $w] -width $btwidth]  \
      -side right -padx 5 -pady 5
    pack $frbot -side bottom -fill both -expand 1 -padx 8 -pady 6
    
    ::UI::SetWindowPosition $w
    wm resizable $w 0 0
}

proc ::Profiles::CloseDlgHook {wclose} {
    global  wDlgs

    if {[string equal $wclose $wDlgs(jprofiles)]} {
	::Profiles::CancelDlg $wclose
    }
}

proc ::Profiles::SaveDlg {w} {
    
    ::UI::SaveWinGeom $w
    ::Profiles::SaveHook
    destroy $w
}

proc ::Profiles::CancelDlg {w} {
    
    ::UI::SaveWinGeom $w
    destroy $w
}

#-------------------------------------------------------------------------------
