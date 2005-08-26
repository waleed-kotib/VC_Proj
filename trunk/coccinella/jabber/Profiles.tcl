#  Profiles.tcl ---
#  
#      This file implements code for handling profiles.
#      
#  Copyright (c) 2003-2005  Mats Bengtsson
#  
# $Id: Profiles.tcl,v 1.42 2005-08-26 15:02:34 matben Exp $

package provide Profiles 1.0

namespace eval ::Profiles:: {
    
    # Define all hooks that are needed.
    ::hooks::register prefsInitHook          ::Profiles::InitHook
    ::hooks::register prefsBuildHook         ::Profiles::BuildHook         20
    ::hooks::register prefsUserDefaultsHook  ::Profiles::UserDefaultsHook
    ::hooks::register prefsSaveHook          ::Profiles::SaveHook
    ::hooks::register prefsCancelHook        ::Profiles::CancelHook
    ::hooks::register prefsUserDefaultsHook  ::Profiles::UserDefaultsHook
    
    #::hooks::register initHook               ::Profiles::ImportIfNecessary
    
    option add *JProfiles*TLabel.style        Small.TLabel        widgetDefault
    #option add *JProfiles*TLabelframe.style   Small.TLabelframe   widgetDefault
    option add *JProfiles*TButton.style       Small.TButton       widgetDefault
    option add *JProfiles*TMenubutton.style   Small.TMenubutton   widgetDefault
    option add *JProfiles*TRadiobutton.style  Small.TRadiobutton  widgetDefault
    option add *JProfiles*TCheckbutton.style  Small.TCheckbutton  widgetDefault
    option add *JProfiles*TEntry.style        Small.TEntry        widgetDefault
    option add *JProfiles*TScale.style        Small.Horizontal.TScale        widgetDefault
    option add *JProfiles*TNotebook.Tab.style  Small.Tab   widgetDefault

    # Internal storage:
    #   {name1 {server1 username1 password1 ?-key value ...?}
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

    ::PrefUtils::Add [list  \
      [list ::Profiles::profiles   profiles          $profiles   userDefault] \
      [list ::Profiles::selected   selected_profile  $selected   userDefault]]
    
    # Sanity check.
    SanityCheck
}

# Profiles::SanityCheck --
# 
#       Make sure we have got the correct form:
#          {name1 {server1 username1 password1 ?-key value ...?}
#           name2 {server2 username2 password2 ?-key value ...?} ... }


proc ::Profiles::SanityCheck { } {
    variable profiles
    variable selected

    # Verify that 'selected' exists in 'profiles'.
    set all [GetAllNames]
    if {[lsearch -exact $all $selected] < 0} {
	set selected [lindex $all 0]
    }
    array set arr $profiles
    foreach {name spec} $profiles {
	# Incomplete
	if {[llength $spec] < 3} {
	    unset -nocomplain arr($name)
	}
	# Odd number opts are corrupt. Skip these.
	if {[expr {[llength [lrange $spec 3 end]] % 2}] == 1} {
	    set arr($name) [lrange $spec 0 2]
	}
    }
    set profiles [array get arr]
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
    set allNames [GetAllNames]
    
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
    SortProfileList
    return
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
    return
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
	    
	    lassign $spec serv user pass
	    unset -nocomplain opts
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

proc ::Profiles::GetList { } {
    variable profiles
 
    return $profiles
}

proc ::Profiles::Get {name key} {
    variable profiles
    
    set ind [lsearch -exact $profiles $name]
    if {$ind >= 0} {
	set spec [lindex $profiles [incr ind]]
	
	switch -- $key {
	    domain {
		return [lindex $spec 0]
	    }
	    node {
		return [lindex $spec 1]
	    }
	    password {
		return [lindex $spec 2]
	    }
	    options {
		return [lrange [lindex $profiles $ind] 3 end]
	    }
	}
    } else {
	return -code error "profile \"$name\" does not exist"
    }
}

proc ::Profiles::GetProfile {name} {
    variable profiles
 
    array set profArr $profiles
    if {[info exists profArr($name)]} {
	return $profArr($name)
    } else {
	return
    }
    return $profiles
}

proc ::Profiles::GetSelectedName { } {
    variable selected
 
    set all [GetAllNames]
    if {[lsearch -exact $all $selected] < 0} {
	set selected [lindex $all 0]
    }
    return $selected
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
    foreach name [GetAllNames] {
	set noopts [lrange $profArr($name) 0 2]
	set opts [SortOptsList [lrange $profArr($name) 3 end]]
	lappend tmp $name [concat $noopts $opts]
    }
    set profiles $tmp
}

proc ::Profiles::SortOptsList {opts} {
    
    set tmp {}
    array set arr $opts
    foreach name [lsort [array names arr]] {
	lappend tmp $name $arr($name)
    }
    return $tmp
}

proc ::Profiles::ImportIfNecessary { } {
    variable profiles
    variable selected
    upvar ::Jabber::jserver jserver

    if {[info exists jserver(profile)] && [info exists jserver(profile,selected)]} {

	# Use ad hoc method to figure out if want to import profiles.
	if {[string equal [lindex $profiles 1 1] "myUsername"] && \
	  ([llength $profiles] == 2)} {
	    ImportFromJserver
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
	lassign $spec se us pa re
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
    
    $wtree newitem {Jabber {User Profiles}} -text [mc {User Profiles}]

    set wpage [$nbframe page {User Profiles}]    
    BuildPage $wpage
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
    
    # Make temp array for servers. Be sure they are sorted first.
    SortProfileList
    MakeTmpProfArr
    set tmpSelected $selected
		
    # Init textvariables.
    set profile  $tmpSelected
    set server   $tmpProfArr($profile,server)
    set username $tmpProfArr($profile,username)
    set password $tmpProfArr($profile,password)
    
    set allNames [GetAllNames]
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    set wp $wc.p
    ttk::labelframe $wp -text [mc {User Profiles}] \
      -padding [option get . groupSmallPadding {}]
    pack  $wp  -side top -fill x
    
    ttk::label $wp.msg -text [mc prefprof] -wraplength 200 -justify left
    pack $wp.msg -side top -anchor w -fill x
    
    # Need to pack options here to get the complete bottom slice.
    set wopt $wp.fopt
    ttk::frame $wopt
    pack  $wopt  -side bottom -fill x -expand 1

    set wui $wp.u
    ttk::frame $wui
    pack  $wui  -side left

    ttk::label $wui.lpop -text "[mc Profile]:" -anchor e
    
    set wmenu [eval {
	ttk::optionmenu $wui.pop [namespace current]::profile
    } $allNames]
    trace variable [namespace current]::profile w  \
      [namespace current]::TraceProfile
    
    ttk::label $wui.lserv -text "[mc {Jabber Server}]:" -anchor e
    ttk::entry $wui.eserv -font CociSmallFont \
      -width 22   \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateDomainStr %S}
    ttk::label $wui.luser -text "[mc Username]:" -anchor e
    ttk::entry $wui.euser -font CociSmallFont \
      -width 22  \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::label $wui.lpass -text "[mc Password]:" -anchor e
    ttk::entry $wui.epass -font CociSmallFont \
      -width 22 -show {*}  \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidatePasswordStr %S}
    ttk::label $wui.lres -text "[mc Resource]:" -anchor e
    ttk::entry $wui.eres -font CociSmallFont \
      -width 22   \
      -textvariable [namespace current]::resource -validate key  \
      -validatecommand {::Jabber::ValidateResourceStr %S}

    grid  $wui.lpop   $wui.pop    -sticky e -pady 2
    grid  $wui.lserv  $wui.eserv  -sticky e -pady 2
    grid  $wui.luser  $wui.euser  -sticky e -pady 2
    grid  $wui.lpass  $wui.epass  -sticky e -pady 2
    grid  $wui.lres   $wui.eres   -sticky e -pady 2
    
    grid  $wui.pop  $wui.eserv  $wui.euser  $wui.epass  $wui.eres  -sticky ew
    
    set wuserinfofocus $wui.eserv
        
    set wbt $wp.bt 
    ttk::frame $wbt -padding {6 0 0 0}
    pack  $wbt  -side right -fill y
    
    ttk::button $wbt.new -text [mc New] \
      -command [namespace current]::NewCmd
    ttk::button $wbt.del -text [mc Delete] \
      -command [namespace current]::DeleteCmd

    pack  $wbt.new  $wbt.del  -side top -fill x -pady 4

    # We use an array for "more" options.
    set token [namespace current]::moreOpts
    variable $token

    foreach {key value} [array get tmpProfArr $profile,-*] {
	set optname [string map [list $profile,- ""] $key]
	
	switch -- $optname {
	    resource {
		set resource $value
	    }
	    default {
		set moreOpts($optname) $value
	    }
	}
    }

    # Tabbed notebook for more options.
    set wtabnb $wopt.nb
    NotebookOptionWidget $wtabnb $token
    pack $wtabnb -fill x
    
    # The actual prefs state for the current profile must be set.
    SetCurrentFromTmp $tmpSelected

    # This allows us to clean up some things when we go away.
    bind $wc <Destroy> [list [namespace current]::DestroyHandler]

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s.msg configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wp $wp]    
    after idle $script
}

# Profiles::NotebookOptionWidget --
# 
#       Megawidget tabbed notebook for all extras.
#       Can be used elsewhere as well.

proc ::Profiles::NotebookOptionWidget {w token} {
    global  prefs this
    variable $token
    upvar 0 $token state
    variable defaultOptionsArr
    
    Debug 2 "::Profiles::NotebookOptionWidget"
    
    # Tabbed notebook for more options.
    ttk::notebook $w -style Small.TNotebook -padding {4}

    # Login options.
    $w add [ttk::frame $w.log] -text [mc {Login}] -sticky news

    set wlog $w.log.f
    ttk::frame $wlog -padding [option get . notebookPageSmallPadding {}]
    pack  $wlog  -side top -anchor [option get . dialogAnchor {}]

    ttk::checkbutton $wlog.cdig -style Small.TCheckbutton \
      -text [mc {Scramble password}]  \
      -variable $token\(digest)
    ttk::label $wlog.lp -style Small.TLabel \
      -text "[mc {Priority}]:"
    spinbox $wlog.sp -font CociSmallFont \
      -textvariable $token\(priority) \
      -width 5 -state readonly -increment 1 -from 0 -to 127
    ttk::checkbutton $wlog.cinv -style Small.TCheckbutton \
      -text [mc {Login as invisible}]  \
      -variable $token\(invisible)
    
    grid  $wlog.cdig   -          -sticky w
    grid  $wlog.cinv   -          -sticky w
    grid  $wlog.lp     $wlog.sp
    
    # Connection page.
    $w add [ttk::frame $w.con] -text [mc {Connection}] -sticky news

    set wcon $w.con.f
    ttk::frame $wcon -padding [option get . notebookPageSmallPadding {}]
    pack  $wcon  -side top -anchor [option get . dialogAnchor {}]

    ttk::label $wcon.lip -style Small.TLabel \
      -text "[mc {IP address}]:"
    ttk::entry $wcon.eip -font CociSmallFont \
      -textvariable $token\(ip)
    ttk::label $wcon.lport -style Small.TLabel \
      -text "[mc Port]:"
    ttk::entry $wcon.eport -font CociSmallFont \
      -textvariable $token\(port) -width 6 -validate key  \
      -validatecommand {::Register::ValidatePortNumber %S}
    ttk::checkbutton $wcon.cssl -style Small.TCheckbutton \
      -text [mc {Use SSL for security}] \
      -variable $token\(ssl)   
    ttk::checkbutton $wcon.csasl -style Small.TCheckbutton \
      -text [mc prefsusesasl] -variable $token\(sasl)   
    
    grid  $wcon.lip    $wcon.eip    -sticky e -pady 1
    grid  $wcon.lport  $wcon.eport  -sticky e -pady 1
    grid  x            $wcon.cssl   -sticky w
    grid  x            $wcon.csasl  -sticky w
    
    grid  $wcon.eip  $wcon.eport  -sticky w

    if {!$this(package,tls)} {
	$wcon.cssl state {disabled}
    }
    if {![jlib::havesasl]} {
	$wcon.csasl state {disabled}
    }

    # HTTP
    $w add [ttk::frame $w.http] -text [mc {HTTP}] -sticky news
    set whttp $w.http.f
    ttk::frame $whttp -padding [option get . notebookPageSmallPadding {}]
    pack  $whttp  -side top -fill x -anchor [option get . dialogAnchor {}]
    
    ttk::checkbutton $whttp.http -style Small.TCheckbutton \
      -text [mc {Connect using HTTP}] -variable $token\(http)
    
    ttk::frame $whttp.u
    ttk::label $whttp.u.lurl -style Small.TLabel  \
      -text "[mc {URL}]:"
    ttk::entry $whttp.u.eurl -font CociSmallFont  \
      -textvariable $token\(httpurl)
    grid  $whttp.u.lurl  $whttp.u.eurl  -sticky w
    grid  $whttp.u.eurl  -sticky ew
    grid columnconfigure $whttp.u 1 -weight 1
    
    ttk::frame $whttp.p
    ttk::checkbutton $whttp.p.proxy -style Small.TCheckbutton \
      -text [mc {Use proxy}] -variable $token\(proxy)   
    ttk::button $whttp.p.bproxy -style Small.TButton  \
      -text "[mc {Proxy Settings}]..."  \
      -command [list ::Preferences::Build -page {General {Proxy Setup}}]
    grid  $whttp.p.proxy  $whttp.p.bproxy  -sticky w
    grid  $whttp.p.bproxy  -sticky e -padx 4

    ttk::label $whttp.lpoll -style Small.TLabel  \
      -text [mc {Poll interval (secs)}]
    spinbox $whttp.spoll -textvariable $token\(pollsecs) \
      -width 3 -state readonly -increment 1 -from 1 -to 120
    
    grid  $whttp.http    -             -sticky w  -pady 1
    grid  $whttp.u       -             -sticky ew -pady 1
    grid  $whttp.p       -             -sticky w  -pady 1
    #grid  $whttp.lpoll   $whttp.spoll  -sticky w  -pady 1
    grid columnconfigure $whttp 1 -weight 1
    
    # Set defaults.
    NotebookSetDefaults $token ""

    # Let components ad their own stuff here.
    ::hooks::run profileBuildTabNotebook $w $token
    
    # The components should set their defaults in the hook, which we
    # need to read out here.
    array set defaultOptionsArr [array get state]
    
    return $w
}

namespace eval ::Profiles:: {
    
    variable initedDefaultOptions 0
}

proc ::Profiles::NotebookSetDefaults {token server} {
    variable $token
    upvar 0 $token state
    variable defaultOptionsArr
    variable initedDefaultOptions
    
    Debug 2 "::Profiles::NotebookSetDefaults"

    if {!$initedDefaultOptions} {
	InitDefaultOptions
    }
    array set state [array get defaultOptionsArr]
    set state(httpurl) "http://${server}:5280/http-poll/"
}

proc ::Profiles::InitDefaultOptions { } {
    global  prefs this
    variable initedDefaultOptions
    variable defaultOptionsArr
    upvar ::Jabber::jprefs jprefs
    
    Debug 2 "::Profiles::InitDefaultOptions"
 
    array set defaultOptionsArr {
	digest      1
	invisible   0
	ip          ""
	pollsecs    5
	priority    0
	http        0
	httpurl     ""
	proxy       0
    }
    set defaultOptionsArr(port) $jprefs(port)
    set defaultOptionsArr(ssl)  $jprefs(usessl)
    if {!$this(package,tls)} {
	set defaultOptionsArr(ssl) 0
    }
    set defaultOptionsArr(sasl) 0
    if {[catch {package require jlibsasl}]} {
	set defaultOptionsArr(sasl) 0
    }
    set initedDefaultOptions 1
}

# Profiles::MakeTmpProfArr --
#
#       Make temp array for profiles.

proc ::Profiles::MakeTmpProfArr { } {
    
    variable profiles
    variable tmpProfArr
    
    # New... Profiles
    unset -nocomplain tmpProfArr
    
    foreach {name spec} $profiles {
	set tmpProfArr($name,name) $name
	lassign $spec                \
	  tmpProfArr($name,server)   \
	  tmpProfArr($name,username) \
	  tmpProfArr($name,password)
	set tmpProfArr($name,-resource) ""
	foreach {key value} [lrange $spec 3 end] {
	    set tmpProfArr($name,$key) $value
	}
    }
}

proc ::Profiles::TraceProfile {name key op} {
    variable profile

    Debug 4 "TraceProfile name=$name; set name=[set $name]"
    SetCmd [set $name]
}

# Profiles::SetCmd --
#
#       Callback when a new item is selected in the menu.

proc ::Profiles::SetCmd {profName} {
    
    variable tmpProfArr
    variable tmpSelected
    variable profile
    
    # The 'profName' is here the new profile, and 'tmpSelected' the
    # previous one.
    Debug 2 "::Profiles::SetCmd profName=$profName, tmpSelected=$tmpSelected"

    if {[info exists tmpProfArr($tmpSelected,name)]} {
	Debug 2 "\t tmpSelected exists"
	
	# Check if there are any empty fields.
	if {![VerifyNonEmpty]} {
	    set profile $tmpSelected
	    Debug 2 "***::Profiles::VerifyNonEmpty: set profile $tmpSelected"
	    return
	}
	
	# Save previous state in tmp before setting the new one.
	SaveCurrentToTmp $tmpSelected
    }
    
    # In case this is a new profile.
    if {[info exists tmpProfArr($profName,server)]} {
	SetCurrentFromTmp $profName
    }
}

proc ::Profiles::SetCurrentFromTmp {profName} {
    variable tmpProfArr
    variable tmpSelected
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable moreOpts

    Debug 2 "::Profiles::SetCurrentFromTmp profName=$profName"
    
    set server   $tmpProfArr($profName,server)
    set username $tmpProfArr($profName,username)
    set password $tmpProfArr($profName,password)
    NotebookSetDefaults [namespace current]::moreOpts $server
    
    foreach {key value} [array get tmpProfArr $profName,-*] {
	set optname [string map [list $profName,- ""] $key]
	Debug 4 "\t key=$key, value=$value, optname=$optname"
	
	# The 'resource' is a bit special...
	if {$optname eq "resource"} {
	    set resource $value
	} else {
	    set moreOpts($optname) $value
	}
    }
    set tmpSelected $profName  
}

proc ::Profiles::SaveCurrentToTmp {profName} {
    global  prefs
    
    variable tmpProfArr    
    variable server
    variable username
    variable password
    variable resource
    variable moreOpts
    variable defaultOptionsArr
    
    Debug 2 "::Profiles::SaveCurrentToTmp profName=$profName"
    
    # Store it in the temporary array. 
    # But only of the profile already exists since we may have just deleted it!
    if {[info exists tmpProfArr($profName,name)]} {
	Debug 2 "\t exists tmpProfArr($profName,name)"
	set tmpProfArr($profName,name)       $profName
	set tmpProfArr($profName,server)     $server
	set tmpProfArr($profName,username)   $username
	set tmpProfArr($profName,password)   $password
	set tmpProfArr($profName,-resource)  $resource
	
	# Set more options if different from defaults.
	foreach key [array names moreOpts] {
	    
	    # Cleanup any old entries. Save only if different from default.
	    unset -nocomplain tmpProfArr($profName,-$key)
	    if {$key eq "httpurl"} {
		if {$moreOpts($key) ne "http://${server}:5280/http-poll"} {
		    set tmpProfArr($profName,-$key) $moreOpts($key)
		}
	    } elseif {![string equal $moreOpts($key) $defaultOptionsArr($key)]} {
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
	::UI::MessageBox -type ok -icon error -parent [winfo toplevel $wpage] \
	  -title [mc Error] -message [mc messfillserveruser]
	set ans 0
    }
    return $ans
}

proc ::Profiles::MakeUniqueProfileName {name} {
    variable server
    
    # Create a unique profile name if not given.
    set allNames [GetAllTmpNames]
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
    set ans [::UI::MegaDlgMsgAndEntry [mc Profile] [mc prefprofname] \
      "[mc {Profile Name}]:" newProfile [mc Cancel] [mc OK]]
    if {$ans == "cancel"} {
	return
    }
    Debug 2 "::Profiles::NewCmd tmpSelected=$tmpSelected, newProfile=$newProfile"

    set uniqueName [MakeUniqueProfileName $newProfile]
    $wmenu add radiobutton -label $uniqueName  \
      -variable [namespace current]::profile

    set tmpSelected $uniqueName
    set profile   $uniqueName
    set server    ""
    set username  ""
    set password  ""
    set resource  ""
    NotebookSetDefaults [namespace current]::moreOpts $server
    
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
	set ans [::UI::MessageBox -title [mc Warning]  \
	  -type yesno -icon warning -default yes  \
	  -parent [winfo toplevel $wpage] \
	  -message [mc messremoveprofile]]
    }
    if {$ans == "yes"} {
	set ind [$wmenu index $profile]
	if {$ind >= 0} {
	    $wmenu delete $ind
	}
	array unset tmpProfArr "$profile,*"
	set allNames [GetAllTmpNames]
	
	# Set selection to first.
	set profile [lindex $allNames 0]
	SetCmd $profile
    }
}

proc  ::Profiles::DestroyHandler { } {
    
    trace vdelete [namespace current]::profile w  \
      [namespace current]::TraceProfile   
}

# Profiles::SaveHook --
# 
#       Invoked from the Save button.

proc ::Profiles::SaveHook { } {
    variable profiles
    variable selected
    variable tmpSelected

    set profiles [GetTmpProfiles]
    set selected $tmpSelected
    
    # Update the Login dialog if any.
    ::Login::LoadProfiles
}

proc ::Profiles::GetTmpProfiles { } {
    variable tmpProfArr
    variable profile
    
    Debug 2 "::Profiles::GetTmpProfiles"
    
    # Get present dialog state into tmp array first.
    SaveCurrentToTmp $profile
    
    set tmpProfiles {}
    foreach name [GetAllTmpNames] {
	set plist [list $tmpProfArr($name,server) $tmpProfArr($name,username) \
	  $tmpProfArr($name,password)]
	
	# Set the optional options as "-key value ...". Sorted!
	foreach key [lsort [array names tmpProfArr $name,-*]] {
	    set optname [string map [list $name,- ""] $key]
	    set value $tmpProfArr($key)
	    
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
    set tmpProfiles [GetTmpProfiles]
    array set profArr $profiles
    array set tmpArr $tmpProfiles
    if {![arraysequal tmpArr profArr]} {
	::Preferences::HasChanged
    }
}

proc ::Profiles::UserDefaultsHook { } {
    variable selected
    variable tmpSelected
    variable profile
    
    MakeTmpProfArr
    set tmpSelected $selected
    set profile $selected
    SetCmd $selected
}

# Profiles::BuildDialog --
# 
#       Standalone dialog profile settings dialog.

proc ::Profiles::BuildDialog { } {
    global  wDlgs
    
    set w $wDlgs(jprofiles)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    ::UI::Toplevel $w -class JProfiles \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand ::Profiles::CloseDlgHook
    wm title $w [mc Profiles]
    ::UI::SetWindowPosition $w
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wpage $w.frall.page
    ttk::frame $wpage -padding {8}
    BuildPage $wpage
    pack $wpage -side top
    
    # Button part.
    set frbot $w.frall.b
    ttk::frame $frbot -padding [option get . okcancelNoTopPadding {}]
    ttk::button $frbot.btok -style TButton \
      -text [mc Save]  \
      -default active -command [list [namespace current]::SaveDlg $w]
    ttk::button $frbot.btcancel -style TButton \
      -text [mc Cancel]  \
      -command [list [namespace current]::CancelDlg $w]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x

    wm resizable $w 0 0
}

proc ::Profiles::CloseDlgHook {wclose} {
    global  wDlgs

    if {[string equal $wclose $wDlgs(jprofiles)]} {
	CancelDlg $wclose
    }
}

proc ::Profiles::SaveDlg {w} {
    
    # If created new it may not have been verified.
    if {![VerifyNonEmpty]} {
	return
    }
    ::UI::SaveWinGeom $w
    SaveHook
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
