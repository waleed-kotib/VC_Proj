#  Profiles.tcl ---
#  
#      This file implements code for handling profiles.
#      
#  Copyright (c) 2003-2004  Mats Bengtsson
#  
# $Id: Profiles.tcl,v 1.21 2004-07-02 14:08:02 matben Exp $

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
    
    variable debug 0
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
    variable wuserinfofocus
    variable tmpProfArr
    variable tmpSelected
    variable wpage $page
    
    set fontS  [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    set contrastBg [option get . backgroundLightContrast {}]

    set lfr $page.fr
    labelframe $lfr -text [::msgcat::mc {User Profiles}]
    pack $lfr -side top -anchor w -padx 8 -pady 4
    
    label $lfr.msg -text [::msgcat::mc prefprof] -wraplength 200 -justify left
    pack  $lfr.msg -side top -anchor w -fill x
    
    # Need to pack options here to get the complete bottom slice.
    set  popt [frame $lfr.fropt -bd 1 -relief flat -bg $contrastBg]
    pack $popt -padx 10 -pady 6 -side bottom -fill x -expand 1

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
    
    # We use an array for "more" options.
    set token [namespace current]::moreOpts
    variable $token

    ::Profiles::DefaultOptionsTabNotebook $token

    foreach {key value} [array get tmpProfArr $profile,-*] {
	set optname [string map [list $profile,- ""] $key]
	
	switch -- $optname {
	    resource {
		set resource $tmpProfArr($profile,-resource)
	    }
	    default {
		set moreOpts($optname) $value
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

    grid $pui.lserv $pui.eserv
    grid $pui.luser $pui.euser
    grid $pui.lpass $pui.epass
    grid $pui.lres  $pui.eres
    grid $pui.lserv $pui.luser $pui.lpass $pui.lres -sticky e
    grid $pui.eserv $pui.euser $pui.epass $pui.eres -sticky w
    
    set  puibt [frame $lfr.frbt]
    pack $puibt -padx 8 -pady 6 -side right -fill y
    pack [button $puibt.new -font $fontS -text [::msgcat::mc New]  \
      -command [namespace current]::NewCmd]   \
      -side top -fill x -pady 4
    pack [button $puibt.del -font $fontS -text [::msgcat::mc Delete]  \
      -command [namespace current]::DeleteCmd]   \
      -side top -fill x -pady 4

    # Tabbed notebook for more options.
    set wtabnb $popt.nb
    ::Profiles::OptionsTabNotebook $wtabnb $token
    pack $wtabnb -fill x

    # This allows us to clean up some things when we go away.
    bind $lfr <Destroy> [list [namespace current]::DestroyHandler]

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s.msg configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $lfr $lfr]    
    after idle $script
}

# Profiles::OptionsTabNotebook --
# 
#       Megawidget tabbed notebook for all extras.
#       Can be used elsewhere as well.

proc ::Profiles::OptionsTabNotebook {w token} {
    global  prefs
    variable $token
    
    set fontS  [option get . fontSmall {}]

    # Tabbed notebook for more options.
    ::mactabnotebook::mactabnotebook $w

    # Login options.
    set wpage [$w newpage {Login} -text [::msgcat::mc {Login}]]
    set pagelog $wpage.f
    pack [frame $pagelog] -side top -anchor w -padx 6 -pady 4
    checkbutton $pagelog.cdig -text " [::msgcat::mc {Scramble password}]"  \
      -variable $token\(digest)
    label $pagelog.lp -text "[::msgcat::mc {Priority}]:"
    spinbox $pagelog.sp -textvariable $token\(priority) \
      -width 5 -state readonly -increment 1 -from 0 -to 127
    checkbutton $pagelog.cinv  \
      -text " [::msgcat::mc {Login as invisible}]"  \
      -variable $token\(invisible)
    grid $pagelog.cdig   - -sticky w
    grid $pagelog.cinv   - -sticky w
    grid $pagelog.lp     $pagelog.sp
    
    # Connection page.
    set wpage [$w newpage {Connection} -text [::msgcat::mc {Connection}]] 
    set pageconn $wpage.f
    pack [frame $pageconn] -side top -anchor w -padx 6 -pady 4
    label $pageconn.lip   -text "[::msgcat::mc {IP address}]:"
    entry $pageconn.eip   -textvariable $token\(ip)
    label $pageconn.lport -text "[::msgcat::mc Port]:"
    entry $pageconn.eport -textvariable $token\(port) -width 6
    checkbutton $pageconn.cssl -text " [::msgcat::mc {Use SSL for security}]" \
      -variable $token\(ssl)   
    if {!$prefs(tls)} {
	$pageconn.cssl configure -state disabled
    }
    grid $pageconn.lip   $pageconn.eip  
    grid $pageconn.lport $pageconn.eport
    grid x               $pageconn.cssl
    grid $pageconn.lip $pageconn.lport -sticky e
    grid $pageconn.eip $pageconn.eport -sticky w
    grid $pageconn.cssl -sticky w

    # HTTP proxy.
    set wpage [$w newpage {Proxy} -text [::msgcat::mc {HTTP Proxy}]] 
    set pageproxy $wpage.f
    pack [frame $pageproxy] -side top -anchor w -padx 6 -pady 4
    checkbutton $pageproxy.http -text " [::msgcat::mc {Connect using Http proxy}]" \
      -variable $token\(httpproxy)
    label $pageproxy.lpoll -text [::msgcat::mc {Poll interval (secs)}]
    spinbox $pageproxy.spoll -textvariable $token\(pollsecs) \
      -width 4 -state readonly -increment 1 -from 1 -to 120
    button $pageproxy.set -font $fontS -text [::msgcat::mc {Proxy Settings}] \
      -command [list ::Preferences::Build -page {General {Proxy Setup}}]
    grid $pageproxy.http  -   -sticky w
    grid $pageproxy.lpoll $pageproxy.spoll -sticky e
    grid $pageproxy.set   -   -sticky w

    # Let components ad their own stuff here.
    ::hooks::run profileBuildTabNotebook $w $token
    return $w
}

namespace eval ::Profiles:: {
    
    variable initedDefaultOptions 0
}

proc ::Profiles::InitDefaultOptions { } {
    global  prefs
    variable initedDefaultOptions
    variable defaultOptionsArr
    upvar ::Jabber::jprefs jprefs
 
    array set defaultOptionsArr {
	digest      1
	invisible   0
	ip          ""
	pollsecs    5
	priority    0
	httpproxy   0
    }
    set defaultOptionsArr(port) $jprefs(port)
    set defaultOptionsArr(ssl)  $jprefs(usessl)
    if {!$prefs(tls)} {
	set defaultOptionsArr(ssl) 0
    }
    set initedDefaultOptions 1
}

proc ::Profiles::DefaultOptionsTabNotebook {token} {
    variable $token
    upvar 0 $token state
    variable defaultOptionsArr
    variable initedDefaultOptions

    if {!$initedDefaultOptions} {
	::Profiles::InitDefaultOptions
    }
    array set state [array get defaultOptionsArr]
}

# Profiles::MakeTmpProfArr --
#
#       Make temp array for profiles.

proc ::Profiles::MakeTmpProfArr { } {
    
    variable profiles
    variable tmpProfArr
    variable moreOpts
    
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
    variable moreOpts
    
    # The 'profName' is here the new profile, and 'tmpSelected' the
    # previous one.
    Debug 2 "::Profiles::SetCmd profName=$profName, tmpSelected=$tmpSelected"

    set previousExists [info exists tmpProfArr($tmpSelected,name)]
    Debug 2 "\t previousExists=$previousExists"
    if {$previousExists} {
	
	# Check if there are any empty fields.
	if {![::Profiles::VerifyNonEmpty]} {
	    set profile $tmpSelected
	    Debug 2 "***::Profiles::VerifyNonEmpty: set profile $tmpSelected"
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
	::Profiles::DefaultOptionsTabNotebook [namespace current]::moreOpts
	
	foreach {key value} [array get tmpProfArr $profName,-*] {
	    set optname [string map [list $profName,- ""] $key]
	    if {$optname == "resource"} {
		continue
	    }
	    set moreOpts($optname) $value
	}
	set resource $tmpProfArr($profName,-resource)
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
    variable moreOpts
    variable defaultOptionsArr
    
    Debug 2 "::Profiles::SaveStateToTmpProfArr profName=$profName"
    
    # Store it in the temporary array. 
    # But only of the profile already exists since we may have just deleted it!
    if {[info exists tmpProfArr($profName,name)]} {
	Debug 2 "\t exists tmpProfArr($profName,name)"
	set tmpProfArr($profName,name)     $profName
	set tmpProfArr($profName,server)   $server
	set tmpProfArr($profName,username) $username
	set tmpProfArr($profName,password) $password
	
	if {$resource != ""} {
	    set tmpProfArr($profName,-resource) $resource
	}
	
	# Set more options if different from defaults.
	foreach key [array names moreOpts] {
	    
	    # Cleanup any old entries.
	    catch {unset tmpProfArr($profName,-$key)}
	    if {![string equal $moreOpts($key) $defaultOptionsArr($key)]} {
		Debug 4 "\t key=$key"
		set tmpProfArr($profName,-$key) $moreOpts($key)
	    }
	}
	#parray tmpProfArr $profName,-*
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
    variable moreOpts
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
    Debug 2 "::Profiles::NewCmd tmpSelected=$tmpSelected, newProfile=$newProfile"

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
    ::Profiles::DefaultOptionsTabNotebook [namespace current]::moreOpts
    
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
    
    Debug 2 "::Profiles::DeleteCmd profile=$profile"
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

# Profiles::SaveHook --
# 
#       Invoked from the Save button.

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
    
    Debug 2 "::Profiles::GetTmpProfiles"
    
    # Get present dialog state into tmp array first.
    ::Profiles::SaveStateToTmpProfArr $profile
    
    set tmpProfiles {}
    foreach name [::Profiles::GetAllTmpNames] {
	set plist [list $tmpProfArr($name,server) $tmpProfArr($name,username) \
	  $tmpProfArr($name,password)]
	
	# Set the optional options as "-key value ..."
	foreach {key value} [array get tmpProfArr $name,-*] {
	    set optname [string map [list $name,- ""] $key]
	    switch -- $optname {
		resource {
		    if {$value != ""} {
			lappend plist -resource $value 
		    }
		}
		default {
		    lappend plist -$optname $value
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
    pack  $w.frall -fill both -expand 1

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

proc ::Profiles::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------
