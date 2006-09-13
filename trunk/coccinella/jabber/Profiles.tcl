#  Profiles.tcl ---
#  
#      This file implements code for handling profiles.
#      
#  Copyright (c) 2003-2005  Mats Bengtsson
#  
# $Id: Profiles.tcl,v 1.67 2006-09-13 14:09:11 matben Exp $

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
    #    
    #    Options:
    #           -digest     0|1
    #           -http       0|1
    #           -httpurl
    #           -invisible  0|1
    #           -ip
    #           -priority
    #           -secure     0|1
    #           -method     ssl|tlssasl|sasl
    #           
    #           Note the naming convention for -method!
    #            ssl        using direct tls socket connection
    #                       it corresponds to the original jabber method
    #            tlssasl    in stream tls negotiation + sasl, xmpp compliant
    #                       XMPP requires sasl after starttls!
    #            sasl       only sasl authentication
 
    variable profiles
    
    # Profile name of selected profile.
    variable selected
    
    # Configurations:
    # This is a way to hardcode some or all of the profile. Same format.
    # Public APIs must cope with this. Both Get and Set functions.
    # If 'do' then there MUST be valid values in config array.
    set ::config(profiles,do) 0
    set ::config(profiles,profiles) {}
    set ::config(profiles,selected) {}
    set ::config(profiles,prefspanel) 1
    
    # The 'config' array shall never be written to, and since not all elements
    # of the profile are fixed, we need an additional profile that is written
    # to the prefs file. It must furthermore not interfere with the other 
    # 'profile'. Same format.
    variable cprofiles
    variable cselected    
    
    variable debug 0
}

proc ::Profiles::InitHook { } {
    global config
    variable profiles
    variable selected
    variable cprofiles
    variable cselected
    
    set profiles {jabber.org {jabber.org myUsername myPassword}}
    lappend profiles {Google Talk} {gmail.com You from_gmail_your_account  \
      -ip talk.google.com -port 5223 -secure 1 -method ssl -digest 0}
    set selected [lindex $profiles 0]

    ::PrefUtils::Add [list  \
      [list ::Profiles::profiles   profiles          $profiles   userDefault] \
      [list ::Profiles::selected   selected_profile  $selected   userDefault]]
        
    # Google Talk profile?
    if {[::Preferences::UpgradedFromVersion 0.95.10]  \
      && [lsearch -glob $profiles "gmail.com *"] < 0} {
	lappend profiles {Google Talk} {
	    gmail.com You from_gmail_your_account
	    -ip talk.google.com -port 5223 -secure 1 -method ssl -digest 0
	}	
    }
    
    set cprofiles $config(profiles,profiles)
    set cselected $config(profiles,selected)

    ::PrefUtils::Add [list  \
      [list ::Profiles::cprofiles   cprofiles          $cprofiles   userDefault] \
      [list ::Profiles::cselected   selected_cprofile  $cselected   userDefault]]

    # Sanity check.
    SanityCheck
    
    # Translate any old -ssl & -sasl switches.
    TranslateAnySSLSASLOptions
}

# Profiles::SanityCheck --
# 
#       Make sure we have got the correct form:
#          {name1 {server1 username1 password1 ?-key value ...?}
#           name2 {server2 username2 password2 ?-key value ...?} ... }


proc ::Profiles::SanityCheck { } {
    global  config
    variable profiles
    variable selected
    variable cprofiles
    variable cselected
    
    set all [GetAllNames]

    if {$config(profiles,do)} {
	
	# We shall verify that the 'config' array is consistent with 'cprofiles'.
	if {$cselected eq ""} {
	    set cselected [lindex $all 0]
	}
	array set arr $cprofiles
	foreach {name spec} $cprofiles {
	    set prof [eval {FilterConfigProfile $name} $spec]
	    if {$prof ne {}} {
		set arr($name) $prof
	    }
	}
	set cprofiles [array get arr]
    } else {

	# Verify that 'selected' exists in 'profiles'.
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
}

# Profiles::TranslateAnySSLSASLOptions --
# 
#       Translate any old -ssl and -sasl switches to the new ones 
#       -secure 0|1 and -method sasl|tlssasl|ssl according to this map:
#       
#       ---------------------------------
#       | -ssl  -sasl | -secure -method |
#       ---------------------------------
#       |   0      0  |    0       -    |
#       |   1      0  |    1      ssl   |
#       |   0      1  |    1     sasl   |
#       |   1      1  |    1    tlssasl |
#       ---------------------------------

proc ::Profiles::TranslateAnySSLSASLOptions { } {
    variable profiles
    
    array set mapMethod {
	0,0   sasl
	1,0   ssl
	0,1   sasl
	1,1   tlssasl
    }
    array set arr $profiles
    foreach {name spec} $profiles {
	set server [lindex $spec 0]
	array unset opts	
	array set opts [lrange $spec 3 end]
	set ssl 0
	set sasl 0
	set anyOld 0
	if {[info exists opts(-ssl)]} {
	    set ssl $opts(-ssl)
	    set anyOld 1
	}
	if {[info exists opts(-sasl)]} {
	    set sasl $opts(-sasl)
	    set anyOld 1
	}
	#puts "\t name=$name, spec=$spec, anyOld=$anyOld"
	if {$anyOld} {
	    if {$ssl || $sasl} {
		set opts(-secure) 1
	    } else {
		set opts(-secure) 0
	    }
	    set opts(-method) $mapMethod($ssl,$sasl)
	    unset -nocomplain opts(-ssl) opts(-sasl)
	    set lopts [eval {FilterOpts $server} [array get opts]]
	    set arr($name) [concat [lrange $spec 0 2] $lopts]
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
#       args:       -resource, -tls, -priority, -invisible, -ip, -scramble, ...
#       
# Results:
#       none.

proc ::Profiles::Set {name server username password args} {
    global  config
    variable profiles
    variable selected
    variable cprofiles
    variable cselected
    
    ::Debug 2 "::Profiles::Set: name=$name, s=$server, u=$username, p=$password, '$args'"

    if {$config(profiles,do)} {
	array set profArr $cprofiles
    } else {
	array set profArr $profiles
    }
    set allNames [GetAllNames]
    
    # Create a new unique profile name.
    if {![string length $name]} {
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
    set opts [eval {FilterOpts $server} $args]
    
    if {$config(profiles,do)} {
	set prof [eval {
	    FilterConfigProfile $name $server $username $password} $opts]
	if {$prof ne {}} {
	    set profArr($name) $prof
	    set cprofiles [array get profArr]
	    #set cselected $name
	}
    } else {
	set profArr($name) [concat [list $server $username $password] $opts]
	set profiles [array get profArr]
	set selected $name
    }
    
    # Keep them sorted.
    SortProfileList
    return
}

# Profiles::FilterOpts --
# 
#       Filter out options that are different from defaults.

proc ::Profiles::FilterOpts {server args} {
    
    array set dopts [GetDefaultOpts $server]
    foreach {key value} $args {
	if {[info exists dopts($key)] && ![string equal $dopts($key) $value]} {
	    set opts($key) $value
	}
    }
    return [array get opts]
}

# Profiles::FilterConfigProfile --
# 
#       Return the profile preserving any config settings.
#       Must only be called when using 'config' profiles.
#       Returns empty if name does not exist.

proc ::Profiles::FilterConfigProfile {name server username password args} {
    global  config
    
    Debug 2 "::Profiles::FilterConfigProfile $name $server $username $password $args"
    
    # We must NEVER overwrite any values that exist in the 'config' array.
    array set cprofArr $config(profiles,profiles)
    if {[info exists cprofArr($name)]} {
	set prof {}
	set sup [lrange $cprofArr($name) 0 2]	
	foreach val [list $server $username $password] cval $sup {
	    if {$cval ne ""} {
		lappend prof $cval
	    } else {
		lappend prof $val
	    }
	}
	array set copts [lrange $cprofArr($name) 3 end]
	foreach {key value} $args {
	    if {![info exists copts($key)]} {
		lappend prof $key $value
	    }
	}
	return $prof
    } else {
	return {}
    }
}

proc ::Profiles::SetWithKey {name key value} {
    global  config
    variable profiles
    variable cprofiles
        
    array set profArr $profiles
    set allNames [GetAllNames]
    if {[lsearch $allNames $name] < 0} {
	return -code error "nonexisting profile name $name"
    }
    array set idx {server 0 username 1 password 2}
    if {[info exists idx($key)]} {
	lset profArr($name) $idx($key) $value
    } else {
	array set opts [lrange $profArr($name) 3 end]
	set opts($key) $value
	set profArr($name) [concat [lrange $profArr($name) 0 2] [array get opts]]
    }
    if {$config(profiles,do)} {
	set prof [eval {FilterConfigProfile $name} $profArr($name)]
	if {$prof ne {}} {
	    set profArr($name) $prof
	    set cprofiles [array get profArr]
	}
    } else {    
	set profiles [array get profArr]
    }
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
	    
	    if {($serv eq $server) && ($user eq $username)} {
		if {$resource ne ""} {
		    if {$resource eq $opts(-resource)} {
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

# Profiles::DoConfig --
# 
#       Do we use the (partly) hardcoded profiles?

proc ::Profiles::DoConfig { } {
    global  config
    
    return $config(profiles,do)
}

proc ::Profiles::GetConfigProfile {name} {
    global  config
    
    array set profArr $config(profiles,profiles)
    if {[info exists profArr($name)]} {
	return $profArr($name)
    } else {
	return
    }
}

proc ::Profiles::GetList { } {
    global  config
    variable profiles
    variable cprofiles
    
    if {$config(profiles,do)} {
	return $cprofiles
    } else {
	return $profiles
    }
}

proc ::Profiles::Get {name key} {
    global  config
    variable profiles
    variable cprofiles
    
    if {$config(profiles,do)} {
	set prof $cprofiles
    } else {
	set prof $profiles
    }

    set ind [lsearch -exact $prof $name]
    if {$ind >= 0} {
	set spec [lindex $prof [incr ind]]
	
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
		return [lrange [lindex $prof $ind] 3 end]
	    }
	}
    } else {
	return -code error "profile \"$name\" does not exist"
    }
}

proc ::Profiles::GetProfile {name} {
    global  config
    variable profiles
    variable cprofiles
 
    if {$config(profiles,do)} {
	set prof $cprofiles
    } else {
	set prof $profiles
    }

    array set profArr $prof
    if {[info exists profArr($name)]} {
	return $profArr($name)
    } else {
	return
    }
}

proc ::Profiles::GetSelectedName { } {
    global  config
    variable selected
    variable cselected

    if {$config(profiles,do)} {
	set prof $cselected
    } else {
	set all [GetAllNames]
	if {[lsearch -exact $all $selected] < 0} {
	    set selected [lindex $all 0]
	}
	set prof $selected
    }    
    return $prof
}

proc ::Profiles::SetSelectedName {name} {
    global  config
    variable selected
    variable cselected
    
    if {$config(profiles,do)} {
	# @@@ Not sure of this...
	set cselected $name
    } else {
	set selected $name
    }
}

# Profiles::GetAllNames --
# 
#       Utlity function to get a list of the names of all profiles. Sorted!

proc ::Profiles::GetAllNames { } {
    global  config
    variable profiles
    variable cprofiles
    
    if {$config(profiles,do)} {
	set prof $cprofiles
    } else {
	set prof $profiles
    }

    set names {}
    foreach {name spec} $prof {
	lappend names $name
    }    
    return [lsort -dictionary $names]
}

# Profiles::SortProfileList --
# 
#       Just sorts the profiles list using names only.

proc ::Profiles::SortProfileList { } {
    global  config
    variable profiles
    variable cprofiles
    
    Debug 2 "::Profiles::SortProfileList"

    if {$config(profiles,do)} {
	set prof $cprofiles
    } else {
	set prof $profiles
    }
    set tmp {}
    array set profArr $prof
    foreach name [GetAllNames] {
	set noopts [lrange $profArr($name) 0 2]
	set opts [SortOptsList [lrange $profArr($name) 3 end]]
	lappend tmp $name [concat $noopts $opts]
    }
    if {$config(profiles,do)} {
	set cprofiles $tmp
    } else {
	set profiles $tmp
    }
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
	if {$re ne ""} {
	    lappend plist -resource $re
	}
	lappend profiles $name $plist
    }
    set selected $jserver(profile,selected)
}

# Profiles::GetDefaultOpts --
# 
#       Return a default -key value list of the default options.

proc ::Profiles::GetDefaultOpts {server} {
    global  prefs this
    upvar ::Jabber::jprefs jprefs
    variable defaultOpts
    
    # We MUST list all available options here!
    if {![info exists defaultOpts]} {
	array set defaultOpts {
	    -digest         1
	    -invisible      0
	    -ip             ""
	    -priority       0
	    -http           0
	    -httpurl        ""
	    -minpollsecs    4
	    -secure         0
	    -method         sasl
	    -port           ""
	}
	# DO NOT add this!
	#-resource       ""

	#set defaultOpts(-port) $jprefs(port)
	if {!$this(package,tls)} {
	    set defaultOpts(-secure) 0
	    set defaultOpts(-method) sasl
	}
	if {[catch {package require jlibsasl}]} {
	    set defaultOpts(-secure) 0
	}
    }
    
    # Leave it empty.
    #set defaultOpts(-httpurl) [GetDefaultHttpUrl $server]
    return [array get defaultOpts]
}

proc ::Profiles::GetDefaultHttpUrl {server} {
    
    return "http://${server}:5280/http-poll/"
}

proc ::Profiles::GetDefaultOptValue {name server} {
    
    array set arr [GetDefaultOpts $server]
    return $arr(-$name)
}

# User Profiles Page ...........................................................

proc ::Profiles::BuildHook {wtree nbframe} {
    global  config
    
    if {$config(profiles,prefspanel)} {
	::Preferences::NewTableItem {Jabber {User Profiles}} [mc {User Profiles}]
	
	set wpage [$nbframe page {User Profiles}]    
	BuildPage $wpage
    }
}

proc ::Profiles::BuildPage {page} {
    
    set wc $page.c
    FrameWidget $wc 0 -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]    
}

# Profiles::FrameWidget --
# 
#       Megawidget profile frame.
#       @@@ TODO OO

proc ::Profiles::FrameWidget {w moreless args} {
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
    variable wtabnb
    variable wtri
    variable wfrmore
    
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
    
    eval {ttk::frame $w} $args
    
    ttk::label $w.msg -text [mc prefprof] -wraplength 200 -justify left
    grid  $w.msg  -  -sticky ew
    
    set wui $w.u
    ttk::frame $wui
    
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
        
    set wbt $w.bt 
    ttk::frame $wbt -padding {0 4 0 6}
    if {0} {
	grid  $wui  $wbt
	grid $wbt -sticky n
    } else {
	grid  $wui  -sticky ew
	grid  $wbt  -sticky ew    
    }
    ttk::button $wbt.new -text [mc {New Profile}] \
      -command [list [namespace current]::NewCmd $w]
    ttk::button $wbt.del -text [mc {Delete Profile}] \
      -command [list [namespace current]::DeleteCmd $w]

    if {0} {
	pack  $wbt.new  $wbt.del  -side top -fill x -pady 4
    } else {
	grid  $wbt.new  $wbt.del  -sticky ew -padx 10
	foreach c {0 1} {
	    grid columnconfigure $wbt $c -uniform u -weight 1
	}
    }
    
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
    # Need to pack options here to get the complete bottom slice.
    set wopt $w.fopt
    ttk::frame $wopt
    grid  $wopt  -  -sticky ew
    
    # Triangle switch for more options.
    if {$moreless} {
	set wtri $wopt.tri
	ttk::button $wtri -style Small.Toolbutton -padding {6 1} \
	  -compound left -image [::UI::GetIcon mactriangleclosed] \
	  -text "[mc More]..." -command [list [namespace current]::MoreOpts $w]
	pack $wtri -side top -anchor w
    }
    
    # More options.
    set wfrmore $wopt.frmore
    ttk::frame $wfrmore

    if {!$moreless} {
	pack $wfrmore -side top -fill x
    }
    
    # Tabbed notebook for more options.
    set wtabnb $wfrmore.nb
    NotebookOptionWidget $wtabnb $token
    pack $wtabnb -fill x -expand 1
    
    # The actual prefs state for the current profile must be set.
    SetCurrentFromTmp $tmpSelected

    # This allows us to clean up some things when we go away.
    bind $w <Destroy> [list [namespace current]::DestroyHandler]

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s.msg configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $w $w]    
    after idle $script
    
    return $w
}

proc ::Profiles::MoreOpts {w} {
    variable wtri
    variable wfrmore

    pack $wfrmore -side top -fill x -padx 2
    $wtri configure -command [list [namespace current]::LessOpts $w] \
      -image [::UI::GetIcon mactriangleopen] -text "[mc Less]..."   
}

proc ::Profiles::LessOpts {w} {
    variable wtri
    variable wfrmore
    
    pack forget $wfrmore
    $wtri configure -command [list [namespace current]::MoreOpts $w] \
      -image [::UI::GetIcon mactriangleclosed] -text "[mc More]..."   
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
    
    Debug 2 "::Profiles::NotebookOptionWidget w=$w, token=$token"
    
    # Collect all widget paths. Note the trick to get the array name!
    variable $w
    upvar 0 $w wstate

    set wstate(token) $token

    # Tabbed notebook for more options.
    ttk::notebook $w -style Small.TNotebook -padding {4}

    # Login options.
    $w add [ttk::frame $w.log] -text [mc {Login}] -sticky news

    set wlog $w.log.f
    ttk::frame $wlog -padding [option get . notebookPageSmallPadding {}]
    pack  $wlog  -side top -anchor [option get . dialogAnchor {}]

    set wstate(digest)        $wlog.cdig
    set wstate(priority)      $wlog.sp
    set wstate(invisible)     $wlog.cinv

    ttk::checkbutton $wlog.cdig -style Small.TCheckbutton \
      -text [mc {Scramble password}]  \
      -variable $token\(digest)
    ttk::label $wlog.lp -style Small.TLabel \
      -text "[mc {Priority}]:"
    spinbox $wlog.sp -font CociSmallFont \
      -textvariable $token\(priority) \
      -width 5 -increment 1 -from -128 -to 127 -validate all  \
      -validatecommand [list ::Profiles::NotebookValidatePrio $token %V %P]  \
      -invalidcommand bell
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

    set wstate(ip)            $wcon.eip
    set wstate(port)          $wcon.eport

    ttk::label $wcon.lip -style Small.TLabel \
      -text "[mc {IP address}]:"
    ttk::entry $wcon.eip -font CociSmallFont \
      -textvariable $token\(ip)
    ttk::label $wcon.lport -style Small.TLabel \
      -text "[mc Port]:"
    ttk::entry $wcon.eport -font CociSmallFont \
      -textvariable $token\(port) -width 6 -validate key  \
      -validatecommand {::Register::ValidatePortNumber %S}
        
    set wse $wcon.se
    ttk::frame $wcon.se

    set wstate(mssl)          $wse.mssl
    set wstate(mtls)          $wse.mtls
    set wstate(sasl)          $wse.sasl

    ttk::checkbutton $wse.tls -style Small.TCheckbutton  \
      -text [mc {Use Secure Connection}] -variable $token\(secure)  \
      -command [list ::Profiles::NotebookSecCmd $w]
    ttk::radiobutton $wse.sasl -style Small.TRadiobutton  \
      -text [mc prefsusesasl]  \
      -variable $token\(method) -value sasl
    ttk::radiobutton $wse.mtls -style Small.TRadiobutton  \
      -text [mc {Use TLS and SASL authentication}]  \
      -variable $token\(method) -value tlssasl
    ttk::radiobutton $wse.mssl -style Small.TRadiobutton  \
      -text [mc {Use TLS on separate port (old)}]  \
      -variable $token\(method) -value ssl
    
    grid  $wse.tls     -          -sticky w
    grid  x            $wse.sasl  -sticky w
    grid  x            $wse.mtls  -sticky w
    grid  x            $wse.mssl  -sticky w
    grid columnconfigure $wse 0 -minsize 24
    
    grid  $wcon.lip    $wcon.eip    -sticky e -pady 1
    grid  $wcon.lport  $wcon.eport  -sticky e -pady 1
    grid  $wcon.se     -            -sticky ew -pady 1    
    grid $wcon.eip $wcon.eport  -sticky w

    # HTTP
    $w add [ttk::frame $w.http] -text [mc {HTTP}] -sticky news
    set whttp $w.http.f
    ttk::frame $whttp -padding [option get . notebookPageSmallPadding {}]
    pack  $whttp  -side top -fill x -anchor [option get . dialogAnchor {}]

    set wstate(http)          $whttp.http
    set wstate(httpurl)       $whttp.u.eurl
    set wstate(httpproxy)     $whttp.bproxy

    ttk::checkbutton $whttp.http -style Small.TCheckbutton \
      -text [mc {Connect using HTTP}] -variable $token\(http)  \
      -command [list ::Profiles::NotebookHttpCmd $w]
    
    ttk::frame $whttp.u
    ttk::label $whttp.u.lurl -style Small.TLabel  \
      -text "[mc {URL}]:"
    ttk::entry $whttp.u.eurl -font CociSmallFont  \
      -textvariable $token\(httpurl)
    grid  $whttp.u.lurl  $whttp.u.eurl  -sticky w
    grid  $whttp.u.eurl  -sticky ew
    grid columnconfigure $whttp.u 1 -weight 1
    
    ttk::button $whttp.bproxy -style Small.TButton  \
      -text "[mc {Proxy Setup}]..."  \
      -command [list ::Preferences::Show {General {Proxy Setup}}]

    ttk::label $whttp.lpoll -style Small.TLabel  \
      -text [mc {Poll interval (secs)}]
    spinbox $whttp.spoll -textvariable $token\(minpollsecs) \
      -width 3 -state readonly -increment 1 -from 1 -to 120
    
    grid  $whttp.http    -             -sticky w  -pady 1
    grid  $whttp.u       -             -sticky ew -pady 1
    grid  $whttp.bproxy  -                        -pady 1
    #grid  $whttp.lpoll   $whttp.spoll  -sticky w  -pady 1
    grid columnconfigure $whttp 1 -weight 1    

    if {!$this(package,tls)} {
	$wse.tls state {disabled}
    }

    # Set defaults.
    NotebookSetDefaults $token ""
    NotebookDefaultWidgetStates $w
    
    # Let components ad their own stuff here.
    ::hooks::run profileBuildTabNotebook $w $token
    
    # The components should set their defaults in the hook, which we
    # need to read out here.
    array set defaultOptionsArr [array get state]
    
    bind $w <Destroy> {+::Profiles::NotebookOnDestroy %W }
    
    return $w
}

proc ::Profiles::NotebookValidatePrio {token type new} {
    variable $token
    upvar 0 $token state
    
    switch -- $type {
	key {
	    if {($new eq "-") || ($new eq "")} {
		return 1
	    } elseif {[string is integer -strict $new]  \
	      && ($new >= -128) && ($new <= 127)} {
		return 1
	    } else {
		return 0
	    }
	}
	focusout - forced {
	    if {[string is integer -strict $new]  \
	      && ($new >= -128) && ($new <= 127)} {
		return 1
	    } else {
		set state(priority) 0
		return 0
	    }
	}
	default {
	    return 1
	}
    }
}

proc ::Profiles::NotebookDefaultWidgetStates {w} {
    NotebookSecCmd $w
    NotebookHttpCmd $w
}

proc ::Profiles::NotebookSecCmd {w} {
    variable $w
    upvar 0 $w wstate

    set token $wstate(token)
    variable $token
    upvar 0 $token state

    if {$state(secure)} {
	$wstate(mssl)  state {!disabled}
	$wstate(mtls)  state {!disabled}
	if {[jlib::havesasl]} {
	    $wstate(sasl) state {!disabled}
	} else {
	    $wstate(sasl) state {disabled}
	}
    } else {
	$wstate(mssl)  state {disabled}
	$wstate(mtls)  state {disabled}
	$wstate(sasl)  state {disabled}
    }
}

proc ::Profiles::NotebookHttpCmd {w} {
    variable $w
    upvar 0 $w wstate

    set token $wstate(token)
    variable $token
    upvar 0 $token state

    if {$state(http)} {
	$wstate(httpurl)   state {!disabled}
	$wstate(httpproxy) state {!disabled}
    } else {
	$wstate(httpurl)   state {disabled}
	$wstate(httpproxy) state {disabled}
    }
}

proc ::Profiles::NotebookSetDefaults {token server} {
    variable $token
    upvar 0 $token state

    foreach {key value} [GetDefaultOpts $server] {
	set name [string trimleft $key "-"]
	set state($name) $value
    }
}

proc ::Profiles::NotebookSetState {w args} {
    variable $w
    upvar 0 $w wstate
    
    set map {!disabled normal}
    
    foreach {key value} $args {
	set name [string trimleft $key "-"]
	set widget $wstate($name)

	switch -glob -- [winfo class $widget] {
	    T* {
		$widget state $value
	    }
	    default {
		$widget configure -state [string map $map $value]
	    }
	}
    }
}

proc ::Profiles::NotebookSetAllState {w state} {
    variable $w
    upvar 0 $w wstate
    
    if {$state eq "normal" || $state eq "!disabled"} {
	set tkstate normal
	set ttkstate {!disabled}
    } else {
	set tkstate disabled
	set ttkstate {disabled}
    }

    foreach {key widget} [array get wstate] {
	if {$key eq "token"} continue

	switch -glob -- [winfo class $widget] {
	    T* {
		$widget state $ttkstate
	    }
	    default {
		$widget configure -state $tkstate
	    }
	}
    }
}

proc ::Profiles::NotebookSetAnyConfigState {w name} {
    
    # Disable every option set by any config.
    if {[DoConfig]} {
	NotebookSetAllState $w normal
	set sopts {}
	foreach {key value} [lrange [GetConfigProfile $name] 3 end] {
	    lappend sopts $key disabled
	}
	eval {NotebookSetState $w} $sopts
    }
}

proc ::Profiles::NotebookOnDestroy {w} {
    variable $w
    
    unset -nocomplain $w
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
    variable wtabnb

    Debug 2 "::Profiles::SetCurrentFromTmp profName=$profName"
    
    set server   $tmpProfArr($profName,server)
    set username $tmpProfArr($profName,username)
    set password $tmpProfArr($profName,password)
    set resource ""
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
    
    NotebookSetAnyConfigState $wtabnb $profName
    NotebookDefaultWidgetStates $wtabnb
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
	if {$resource ne ""} {
	    set tmpProfArr($profName,-resource)  $resource
	}
	
	# Set more options if different from defaults.
	foreach key [array names moreOpts] {
	    
	    # Cleanup any old entries. Save only if different from default.
	    unset -nocomplain tmpProfArr($profName,-$key)
	    set dvalue [GetDefaultOptValue $key $server]
	    if {![string equal $moreOpts($key) $dvalue]} {
		set tmpProfArr($profName,-$key) $moreOpts($key)
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

proc ::Profiles::NewCmd {w} {
    
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
    if {$ans eq "cancel"} {
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

proc ::Profiles::DeleteCmd {w} {
    global  prefs
    
    variable tmpProfArr
    variable tmpSelected
    variable profile
    variable wmenu
    
    Debug 2 "::Profiles::DeleteCmd profile=$profile"
    set ans "yes"
    
    # The present state may be something that has not been stored yet.
    if {[info exists tmpProfArr($profile,server)]} {
	set ans [::UI::MessageBox -title [mc Warning]  \
	  -type yesno -icon warning -default yes  \
	  -parent [winfo toplevel $w] \
	  -message [mc messremoveprofile]]
    }
    if {$ans eq "yes"} {
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
    global  config
    variable profiles
    variable selected
    variable tmpSelected

    if {$config(profiles,prefspanel)} {
	set profiles [GetTmpProfiles]
	set selected $tmpSelected
	
	# Update the Login dialog if any.
	::Login::LoadProfiles
    }
}

proc ::Profiles::GetTmpProfiles { } {
    variable tmpProfArr
    variable profile
    
    Debug 2 "::Profiles::GetTmpProfiles"
    
    # Get present dialog state into tmp array first.
    SaveCurrentToTmp $profile
    
    set tmpProfiles {}
    foreach name [GetAllTmpNames] {
	set s $tmpProfArr($name,server)
	set u $tmpProfArr($name,username)
	set p $tmpProfArr($name,password)
	set plist [list $s $u $p]
	
	# Set the optional options as "-key value ...". Sorted!
	foreach key [lsort [array names tmpProfArr $name,-*]] {
	    set optname [string map [list $name,- ""] $key]
	    set value $tmpProfArr($key)

	    switch -- $optname {
		resource {
		    if {[string length $value]} {
			lappend plist -resource $value 
		    }
		}
		default {
	
		    # Save only if different from default.
		    set dvalue [GetDefaultOptValue $optname $s]
		    if {![string equal $value $dvalue]} {
			lappend plist -$optname $value
		    }
		}
	    }
	}
	lappend tmpProfiles $name $plist
    }
    return $tmpProfiles
}

proc ::Profiles::CancelHook { } {
    global  config
    variable profiles
    variable selected
    variable tmpProfArr
    variable tmpSelected
    
    if {$config(profiles,prefspanel)} {

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
}

proc ::Profiles::UserDefaultsHook { } {
    global  config
    variable selected
    variable tmpSelected
    variable profile
    
    if {$config(profiles,prefspanel)} {
	MakeTmpProfArr
	set tmpSelected $selected
	set profile $selected
	SetCmd $selected
    }
}

namespace eval ::Profiles {
    
    option add *JProfiles*settingsImage        settings         widgetDefault
    option add *JProfiles*settingsDisImage     settingsDis      widgetDefault
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
    
    set im   [::Theme::GetImage [option get $w settingsImage {}]]
    set imd  [::Theme::GetImage [option get $w settingsDisImage {}]]

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    ttk::label $w.frall.head -style Headlabel \
      -text [mc Profiles] -compound left \
      -image [list $im background $imd]
    pack  $w.frall.head  -side top -fill both -expand 1

    ttk::separator $w.frall.s -orient horizontal
    pack  $w.frall.s  -side top -fill x

    set wpage $w.frall.page
    FrameWidget $wpage 1 -padding [option get . dialogPadding {}]

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
