#  Profiles.tcl ---
#  
#      This file implements code for handling profiles.
#      
#  Copyright (c) 2003-2004  Mats Bengtsson
#  
# $Id: Profiles.tcl,v 1.1 2004-01-03 14:37:59 matben Exp $

package provide Profiles 1.0

namespace eval ::Profiles:: {
    
    ::hooks::add prefsInitHook          ::Profiles::InitHook
    
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
#       args:       -resource, -ssl, -priority, -invisible, ...
#       
# Results:
#       none.

proc ::Profiles::Set {name server username password args} {    
    variable profiles
    variable selected
    
    ::Jabber::Debug 2 "name=$name, s=$server, u=$username, p=$password, '$args'"

    array set jserverArr $profiles
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
    set jserverArr($name) [concat [list $server $username $password] $args]
    set profiles [array get jserverArr]
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

# BUBUBUBUBUBUBUBUBU ...........................................................
# 
# 

# Jabber::SetUserProfile --
#
#       Sets or replaces a user profile. Format:
#  jserver(profile,selected)  profile picked in user info
#  jserver(profile):          {profile1 {server1 username1 password1 resource1} \
#                              profile2 {server2 username2 password2 resource2} ... }
#       
# Arguments:
#       profile     if empty, make a new unique profile, else, create this,
#                   possibly replace if exists already.
#       server      Jabber server name.
#       username
#       password
#       
# Results:
#       none.

proc ::Jabber::SetUserProfile {profile server username password {res {coccinella}}} {    
    variable jserver
    
    ::Jabber::Debug 2 "profile=$profile, s=$server, u=$username, p=$password, r=$res"

    # 
    array set jserverArr $jserver(profile)
    set profileList [::Jabber::GetAllProfileNames]
    
    # Create a new unique profile name.
    if {[string length $profile] == 0} {
	set profile $server

	# Make sure that 'profile' is unique.
	if {[lsearch -exact $profileList $profile] >= 0} {
	    set i 2
	    set tmpprof $profile
	    set profile ${tmpprof}-${i}
	    while {[lsearch -exact $profileList $profile] >= 0} {
		incr i
		set profile ${tmpprof}-${i}
	    }
	}
    }
    set jserverArr($profile) [list $server $username $password $res]
    set jserver(profile) [array get jserverArr]
    set jserver(profile,selected) $profile
    return ""
}


proc ::Jabber::RemoveUserProfile {profile} {
    variable jserver
    
    ::Jabber::Debug 2 "::Jabber::RemoveUserProfile profile=$profile"
 
    set ind [lsearch -exact $jserver(profile) $profile]
    if {$ind >= 0} {
	if {[string equal $jserver(profile,selected) $profile]} {
	    set jserver(profile,selected) [lindex $jserver(profile) 0]
	}
	set jserver(profile) [lreplace $jserver(profile) $ind [incr ind]]
    }
    return ""
}

# Jabber::FindProfileFromJid --
# 
#       Returns first matching 'profile' for jid.
#       It makes only sence for jid2's.

proc ::Jabber::FindProfileFromJid {jid} {
    variable jserver
    
    set profile ""
    
    # If jid2 the resource == "". Find any match.
    if {[regexp {(^.+)@([^/]+)(/(.*))?} $jid match name host junk resource]} {    
	foreach {prof spec} $jserver(profile) {
	    foreach {serv user pass res} $spec break
	    if {($serv == $host) && ($user == $name)} {
		if {$resource != ""} {
		    if {$resource == $res} {
			set profile $prof
			break
		    }
		} else {
		    set profile $prof
		    break
		}
	    }
	}
    }
    return $profile
}

# Jabber::GetAllProfileNames --
# 
#       Utlity function to get a list of the names of all profiles. Sorted!

proc ::Jabber::GetAllProfileNames { } {
    variable jserver

    set profiles {}
    foreach {name spec} $jserver(profile) {
	lappend profiles $name
    }    
    return [lsort -dictionary $profiles]
}

# Jabber::SortProfileList --
# 
#       Just sorts the jserver(profile) list using names only.

proc ::Jabber::SortProfileList { } {
    variable jserver

    set tmp {}
    array set jserverArr $jserver(profile)
    foreach name [::Jabber::GetAllProfileNames] {
	lappend tmp $name $jserverArr($name)
    }
    set jserver(profile) $tmp
}

#-------------------------------------------------------------------------------
