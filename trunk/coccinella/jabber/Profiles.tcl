#  Profiles.tcl ---
#  
#      This file implements code for handling profiles.
#      
#  Copyright (c) 2003-2004  Mats Bengtsson
#  
# $Id: Profiles.tcl,v 1.19 2004-06-11 07:44:44 matben Exp $

package provide Profiles 1.0

namespace eval ::Profiles:: {
    
    # Define all hooks that are needed.
    ::hooks::add prefsInitHook          ::Profiles::InitHook
    ::hooks::add prefsBuildHook         ::Profiles::BuildHook         20
    ::hooks::add prefsUserDefaultsHook  ::Profiles::UserDefaultsHook
    ::hooks::add prefsSaveHook          ::Profiles::SaveHook
    ::hooks::add prefsCancelHook        ::Profiles::CancelHook
    ::hooks::add prefsUserDefaultsHook  ::Profiles::UserDefaultsHook
    
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
    
    ::Debug 2 "::Profiles::Set: name=$name, s=$server, u=$username, p=$password, '$args'"

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
    
    ::Debug 2 "::Profiles::Remove name=$name"
    
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
    
    variable wmenubt
    variable wmenu
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable ssl
    variable sasl
    variable wuserinfofocus
    variable tmpProfArr
    variable tmpSelected
    variable wpage $page
    
    set fontS  [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]

    set lfr $page.fr
    labelframe $lfr -text [::msgcat::mc {User Profiles}]
    pack $lfr -side top -anchor w -padx 8 -pady 4
    
    label $lfr.msg -text [::msgcat::mc prefprof] -wraplength 200 -justify left
    pack  $lfr.msg -side top -anchor w -fill x
    
    # Need to pack options here to get the complete bottom slice.
    set  popt [frame $lfr.fropt]
    pack $popt -padx 8 -pady 2 -side bottom -fill y

    set pui $lfr.fr
    pack [frame $pui] -side left  
    
    # Make temp array for servers.
    ::Profiles::MakeTmpProfArr
    set tmpSelected $selected
		
    # Init textvariables.
    set profile  $tmpSelected
    set server   $tmpProfArr($profile,server)
    set username $tmpProfArr($profile,username)
    set password $tmpProfArr($profile,password)
    foreach key {resource ssl sasl} {
	if {[info exists tmpProfArr($profile,-$key)]} {
	    set $key $tmpProfArr($profile,-$key)
	} else {
	    switch -- $key {
		resource {
		    set $key ""
		}
		ssl - tasl {
		    set $key 0
		}
	    }
	}
    }
    set allNames [::Profiles::GetAllNames]

    # Option menu for the servers.
    label $pui.lpop -text "[::msgcat::mc Profile]:" -anchor e
    
    set wmenubt $pui.popup
    set wmenu [eval {tk_optionMenu $wmenubt [namespace current]::profile} \
      $allNames]
    trace variable [namespace current]::profile w  \
      [namespace current]::TraceMenuVar

    grid $pui.lpop -column 0 -row 0 -sticky e
    grid $wmenubt -column 1 -row 0 -sticky ew
    
    label $pui.lserv -text "[::msgcat::mc {Jabber Server}]:" -anchor e
    entry $pui.eserv -width 22   \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateDomainStr %S}
    label $pui.luser -text "[::msgcat::mc Username]:" -anchor e
    entry $pui.euser -width 22  \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    label $pui.lpass -text "[::msgcat::mc Password]:" -anchor e
    entry $pui.epass -width 22 -show {*}  \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    label $pui.lres -text "[::msgcat::mc Resource]:" -anchor e
    entry $pui.eres -width 22   \
      -textvariable [namespace current]::resource -validate key  \
      -validatecommand {::Jabber::ValidateResourceStr %S}
    set wuserinfofocus $pui.eserv

    grid $pui.lserv  -column 0 -row 1 -sticky e
    grid $pui.eserv  -column 1 -row 1 -sticky w
    grid $pui.luser  -column 0 -row 2 -sticky e
    grid $pui.euser  -column 1 -row 2 -sticky w
    grid $pui.lpass  -column 0 -row 3 -sticky e
    grid $pui.epass  -column 1 -row 3 -sticky w
    grid $pui.lres   -column 0 -row 4 -sticky e
    grid $pui.eres   -column 1 -row 4 -sticky w

    set  puibt [frame $lfr.frbt]
    pack $puibt -padx 8 -pady 6 -side right -fill y
    pack [button $puibt.new -font $fontS -text [::msgcat::mc New]  \
      -command [namespace current]::NewCmd]   \
      -side top -fill x -pady 4
    pack [button $puibt.del -font $fontS -text [::msgcat::mc Delete]  \
      -command [namespace current]::DeleteCmd]   \
      -side top -fill x -pady 4

    checkbutton $popt.cssl -text "  [::msgcat::mc {Use SSL for security}]"  \
      -variable [namespace current]::ssl   
    grid $popt.cssl

    if {!$prefs(tls)} {
	set ssl 0
	$popt.cssl configure -state disabled
    }

    # This allows us to clean up some things when we go away.
    bind $lfr <Destroy> [list [namespace current]::DestroyHandler]

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s.msg configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $lfr $lfr]    
    after idle $script
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

proc ::Profiles::TraceMenuVar {name key op} {
    variable profile

    # puts "TraceMenuVar name=$name"
    #puts "\t set name=[set $name]"
    ::Profiles::SetCmd [set $name]
}

# Profiles::SetCmd --
#
#       Callback when a new item is selected in the menu.

proc ::Profiles::SetCmd {profName} {
    
    variable tmpProfArr
    variable tmpSelected
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable ssl
    variable sasl
    
    # The 'profName' is here the new profile, and 'tmpSelected' the
    # previous one.
    # puts "::Profiles::SetCmd profName=$profName, tmpSelected=$tmpSelected"

    set previousExists [info exists tmpProfArr($tmpSelected,name)]
    # puts "\t previousExists=$previousExists"
    if {$previousExists} {
	
	# Check if there are any empty fields.
	if {![::Profiles::VerifyNonEmpty]} {
	    set profile $tmpSelected
	    # puts "***::Profiles::VerifyNonEmpty: set profile $tmpSelected"
	    return
	}
	
	# Save previous state in tmp before setting the new one.
	::Profiles::SaveStateToTmpProfArr $tmpSelected
    }
    
    # In case this is a new profile.
    if {[info exists tmpProfArr($profName,server)]} {
	set server   $tmpProfArr($profName,server)
	set username $tmpProfArr($profName,username)
	set password $tmpProfArr($profName,password)
	foreach key {resource ssl sasl} {
	    if {[info exists tmpProfArr($profName,-$key)]} {
		set $key $tmpProfArr($profName,-$key)
	    } else {
		switch -- $key {
		    resource {
			set $key ""
		    }
		    ssl - tasl {
			set $key 0
		    }
		}
	    }
	}
	set tmpSelected $profName  
    }
}

proc ::Profiles::SaveStateToTmpProfArr {profName} {
    global  prefs
    
    variable tmpProfArr    
    variable server
    variable username
    variable password
    variable resource
    variable ssl
    variable sasl
    
    # puts "::Profiles::SaveStateToTmpProfArr profName=$profName"
    
    # Store it in the temporary array. 
    # But only of the profile already exists since we may have just deleted it!
    if {[info exists tmpProfArr($profName,name)]} {
	# puts "\t  exists tmpProfArr($profName,name)"
	set tmpProfArr($profName,name)     $profName
	set tmpProfArr($profName,server)   $server
	set tmpProfArr($profName,username) $username
	set tmpProfArr($profName,password) $password
	if {$resource != ""} {
	    set tmpProfArr($profName,-resource) $resource
	}
	foreach key {resource ssl sasl} {
	    switch -- $key {
		resource {
		    if {$resource != ""} {
			set tmpProfArr($profName,-$key) [set $key]
		    }
		}
		ssl - tasl {
		    set tmpProfArr($profName,-$key) [set $key]
		}
	    }
	}
	set tmpSelected $profName  
    }
}

proc ::Profiles::VerifyNonEmpty { } {
    variable server
    variable username
    variable wpage

    set ans 1
    
    # Check that necessary entries are non-empty, at least.
    if {($server == "") || ($username == "")} {
	tk_messageBox -type ok -icon error -parent [winfo toplevel $wpage] \
	  -title [::msgcat::mc Error] -message [FormatTextForMessageBox \
	  [::msgcat::mc messfillserveruser]]
	set ans 0
    }
    return $ans
}

proc ::Profiles::MakeUniqueProfileName {name} {
    variable server
    
    # Create a unique profile name if not given.
    set allNames [::Profiles::GetAllTmpNames]
    if {$name == ""} {
	set name $server
    }

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
    return $name
}
    
proc ::Profiles::GetAllTmpNames { } {
    variable tmpProfArr
    
    set allNames {}
    foreach {key name} [array get tmpProfArr *,name] {
	lappend allNames $name
    }    
    return [lsort -dictionary $allNames]
}

proc ::Profiles::NewCmd { } {
    
    variable tmpProfArr
    variable tmpSelected
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable ssl
    variable sasl
    variable wuserinfofocus
    variable wmenu
    
    set newProfile ""
    
    # First get a unique profile name.
    set ans [::UI::MegaDlgMsgAndEntry \
      [::msgcat::mc Profile] [::msgcat::mc prefprofname] \
      "[::msgcat::mc {Profile Name}]:" newProfile \
      [::msgcat::mc Cancel] [::msgcat::mc OK]]
    if {$ans == "cancel"} {
	return
    }
    # puts "::Profiles::NewCmd tmpSelected=$tmpSelected, newProfile=$newProfile"

    set uniqueName [::Profiles::MakeUniqueProfileName $newProfile]
    # puts "\t uniqueName=$uniqueName"
    $wmenu add radiobutton -label $uniqueName  \
      -variable [namespace current]::profile

    set tmpSelected $uniqueName
    set profile   $uniqueName
    set server    ""
    set username  ""
    set password  ""
    set resource  ""
    set ssl       0
    set sasl      0
    
    # Must do this for it to be automatically saved.
    set tmpProfArr($profile,name) $profile
    focus $wuserinfofocus
}

proc ::Profiles::DeleteCmd { } {
    global  prefs
    
    variable tmpProfArr
    variable tmpSelected
    variable profile
    variable wmenu
    variable wpage
    
    # puts "::Profiles::DeleteCmd profile=$profile"
    set ans "yes"
    
    # The present state may be something that has not been stored yet.
    if {[info exists tmpProfArr($profile,server)]} {
	# puts "\t exists tmpProfArr($profile,server)"
	set ans [tk_messageBox -title [::msgcat::mc Warning]  \
	  -type yesno -icon warning -default yes  \
	  -parent [winfo toplevel $wpage] \
	  -message [FormatTextForMessageBox [::msgcat::mc messremoveprofile]]]
    }
    if {$ans == "yes"} {
	set ind [$wmenu index $profile]
	if {$ind >= 0} {
	    $wmenu delete $ind
	}
	array unset tmpProfArr "$profile,*"
	set allNames [::Profiles::GetAllTmpNames]
	
	# Set selection to first.
	set profile [lindex $allNames 0]
	::Profiles::SetCmd $profile
    }
}

proc  ::Profiles::DestroyHandler { } {
    
    trace vdelete [namespace current]::profile w  \
      [namespace current]::TraceMenuVar   
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
    variable profile
    
    # Get present dialog state into tmp array first.
    ::Profiles::SaveStateToTmpProfArr $profile
    
    set tmpProfiles {}
    foreach name [::Profiles::GetAllTmpNames] {
	set plist [list $tmpProfArr($name,server) $tmpProfArr($name,username) \
	  $tmpProfArr($name,password)]

	foreach key {resource ssl sasl} {
	    if {[info exists tmpProfArr($name,-$key)]} {
		
		switch -- $key {
		    resource {
			lappend plist -resource $tmpProfArr($name,-resource)
		    }
		    ssl - tasl {		    
			lappend plist -$key $tmpProfArr($name,-$key)
		    }
		}
	    }
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

proc ::Profiles::UserDefaultsHook { } {
    variable selected
    variable tmpSelected
    variable profile
    
    ::Profiles::MakeTmpProfArr
    set tmpSelected $selected
    set profile $selected
    ::Profiles::SetCmd $selected
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
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Save]  \
      -default active -command [list [namespace current]::SaveDlg $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::CancelDlg $w]]  \
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
