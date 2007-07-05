#  Profiles.tcl ---
#  
#      This file implements code for handling profiles.
#      
#  Copyright (c) 2003-2007  Mats Bengtsson
#  
# $Id: Profiles.tcl,v 1.71 2007-07-05 07:28:28 matben Exp $

package provide Profiles 1.0

namespace eval ::Profiles:: {
    
    # Define all hooks that are needed.
    ::hooks::register prefsInitHook          ::Profiles::InitHook
    ::hooks::register prefsBuildHook         ::Profiles::BuildHook         20
    ::hooks::register prefsSaveHook          ::Profiles::SaveHook
    ::hooks::register prefsCancelHook        ::Profiles::CancelHook
    
    option add *JProfiles*TLabel.style        Small.TLabel        widgetDefault
    option add *JProfiles*TButton.style       Small.TButton       widgetDefault
    option add *JProfiles*TMenubutton.style   Small.TMenubutton   widgetDefault
    option add *JProfiles*TRadiobutton.style  Small.TRadiobutton  widgetDefault
    option add *JProfiles*TCheckbutton.style  Small.TCheckbutton  widgetDefault
    option add *JProfiles*TEntry.style        Small.TEntry        widgetDefault
    option add *JProfiles*TScale.style        Small.Horizontal.TScale  widgetDefault
    option add *JProfiles*TNotebook.Tab.style Small.Tab           widgetDefault

    # Customization. @@@ TODO; config() ???
    option add *JProfileFrame.showNickname    1                   widgetDefault

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
    #           -resource
    #           -nickname
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
    
    # @@@ using resource option database instead ???
    # Configurations:
    # This is a way to hardcode some or all of the profile. Same format.
    # Public APIs must cope with this. Both Get and Set functions.
    # If 'do' then there MUST be valid values in config array.
    set ::config(profiles,do)         0
    set ::config(profiles,profiles)   {}
    set ::config(profiles,selected)   {}
    set ::config(profiles,prefspanel) 1
    set ::config(profiles,style)      "jid"  ;# jid | parts

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

    # Not sure this is a good idea if they are hardcoded???
    # Username and password must be saved to profile but it can screw up if we
    # previously have used a different config profiles.
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
    set idx [lsearch -exact $profiles $name]
    if {$idx >= 0} {
	if {[string equal $selected $name]} {
	    set selected [lindex $profiles 0]
	}
	set profiles [lreplace $profiles $idx [incr idx]]
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

proc ::Profiles::SetList {_profiles} {
    variable profiles
    
    set profiles $_profiles
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

    set idx [lsearch -exact $prof $name]
    if {$idx >= 0} {
	set spec [lindex $prof [incr idx]]
	
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
		return [lrange [lindex $prof $idx] 3 end]
	    }
	    default {
		array set tmp [lrange [lindex $prof $idx] 3 end]
		if {[info exists tmp($key)]} {
		    return $tmp($key)
		} else {
		    # @@@ Default???
		    return
		}
	    }
	}
    } else {
	return -code error "profile \"$name\" does not exist"
    }
}

proc ::Profiles::GetSelected {key} {
    return [Get [GetSelectedName] $key]
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

    # Keep fallback if selected profile does not exist.
    set all [GetAllNames]
    if {$config(profiles,do)} {
	if {[lsearch -exact $all $cselected] < 0} {
	    set cselected [lindex $all 0]
	}
	set prof $cselected
    } else {
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
	#-nickname       ""

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

# Profiles::MachineResource --
# 
#       Get a default resource in the form "Coccinella@My Box".

proc ::Profiles::MachineResource {} {
    global  tcl_platform prefs this
    variable hostname
    
    if {[string equal $tcl_platform(platform) "windows"]} {
	return $prefs(appName)@$this(hostname)
    } else {
	if {![info exists hostname]} {
	    set bpath [auto_execok hostname]
	    if {[llength $bpath]} {
		set hostname [eval exec $bpath -s]
	    } else {
		set hostname $this(hostname)
	    }
	}
	return $prefs(appName)@$hostname
    }
}

#- User Profiles Page ----------------------------------------------------------

proc ::Profiles::BuildHook {wtree nbframe} {
    global  config
    
    if {$config(profiles,prefspanel)} {
	::Preferences::NewTableItem {Jabber {User Profiles}} [mc {User Profiles}]
	
	set wpage [$nbframe page {User Profiles}]    
	BuildPage $wpage
    }
}

proc ::Profiles::BuildPage {page} {
    variable wprefspage
    
    set wprefspage $page.c
    FrameWidget $wprefspage 0 -padding [option get . notebookPageSmallPadding {}]
    pack $wprefspage -side top -anchor [option get . dialogAnchor {}]    
}

# Profiles::SaveHook --
# 
#       Invoked from the Save button.

proc ::Profiles::SaveHook { } {
    global  config
    variable wprefspage

    if {$config(profiles,prefspanel)} {
	SetList [FrameGetProfiles $wprefspage]
	SetSelectedName [FrameGetSelected $wprefspage]
	
	# Update the Login dialog if any.
	::Login::LoadProfiles
    }
}

proc ::Profiles::CancelHook { } {
    global  config
    variable wprefspage

    if {$config(profiles,prefspanel)} {

	# Detect any changes.
	set selected [GetSelectedName]
	set selectedPref [FrameGetSelected $wprefspage]
	if {![string equal $selected $selectedPref]} {
	    ::Preferences::HasChanged
	    return
	}
	array set profA [GetList]
	array set prefA [FrameGetProfiles $wprefspage]
	if {![arraysequal prefA profA]} {
	    ::Preferences::HasChanged
	}
    }
}

#-------------------------------------------------------------------------------

namespace eval ::Profiles {
    
    option add *JProfiles*settingsImage        settings         widgetDefault
    option add *JProfiles*settingsDisImage     settingsDis      widgetDefault
}

# Profiles::BuildDialog --
# 
#       Standalone dialog profile settings dialog.

proc ::Profiles::BuildDialog { } {
    global  wDlgs
    variable wdlgpage
    
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
    set wdlgpage $wpage
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
    variable wdlgpage
    
    # If created new it may not have been verified.
    if {![FrameVerifyNonEmpty $wdlgpage]} {
	return
    }
    ::UI::SaveWinGeom $w
    SetList [FrameGetProfiles $wdlgpage]
    SetSelectedName [FrameGetSelected $wdlgpage]
    ::Login::LoadProfiles
    destroy $w
}

proc ::Profiles::CancelDlg {w} {
    
    ::UI::SaveWinGeom $w
    destroy $w
}

#-------------------------------------------------------------------------------

namespace eval ::Profiles {
    
    # We must keep a list of all existing FrameWidgets in order to create
    # unique profile names.
    variable wallframes {}
}

# Profiles::FrameWidget --
# 
#       Megawidget profile frame.

proc ::Profiles::FrameWidget {w moreless args} {
    global  prefs config
    variable wallframes
            
    set token [namespace current]::$w
    variable $w
    upvar 0 $w state
    
    Debug 2 "::Profiles::FrameWidget w=$w"
    
    lappend wallframes $w
    set state(moreless) $moreless
    
    # Make temp array for servers. Be sure they are sorted first.
    SortProfileList
    FrameMakeTmpProfiles $w
		
    # We keep two variables for the profile name:
    #   state(profile):   which is used directly in the optionmenu
    #   state(selected):  which is the one actually displayed
    #                     (helpful to switch back to previous profile)
    set selected [GetSelectedName]
    set state(selected) $selected
    set profile $selected
    
    # We keep two state arrays: 'state' and 'mstate'.
    # The 'state' array keeps temporary space for all profiles and
    # contains the text variables of the actual frame but not the notebook.
    # The 'mstate' array keep tracks of the notebook textvariables.
    
    # Init textvariables.
    set state(profile)  $selected
    set state(server)   $state(prof,$profile,server)
    set state(username) $state(prof,$profile,username)
    set state(password) $state(prof,$profile,password)
        
    eval {ttk::frame $w -class JProfileFrame} $args
    
    ttk::label $w.msg -text [mc prefprof] -wraplength 200 -justify left
    grid  $w.msg  -  -sticky ew
    
    set wui $w.u
    ttk::frame $wui
    
    ttk::label $wui.lpop -text "[mc Profile]:" -anchor e
    
    set wmenu [eval {
	ttk::optionmenu $wui.pop $token\(profile)
    } [GetAllNames]]
    trace add variable $token\(profile) write  \
      [list [namespace current]::FrameTraceProfile $w]

    if {$config(profiles,style) eq "jid"} {
	set width 26
    } else {
	set width 22
    }
    
    # Depending on 'config(profiles,style)' not all get mapped.
    ttk::label $wui.ljid -text "[mc {Jabber ID}]:" -anchor e
    ttk::entry $wui.ejid -font CociSmallFont \
      -width $width -textvariable $token\(jid)
    ttk::label $wui.lserv -text "[mc {Jabber Server}]:" -anchor e
    ttk::entry $wui.eserv -font CociSmallFont \
      -width $width -textvariable $token\(server) -validate key  \
      -validatecommand {::Jabber::ValidateDomainStr %S}
    ttk::label $wui.luser -text "[mc Username]:" -anchor e
    ttk::entry $wui.euser -font CociSmallFont \
      -width $width -textvariable $token\(username) -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::label $wui.lpass -text "[mc Password]:" -anchor e
    ttk::entry $wui.epass -font CociSmallFont \
      -width $width -show {*} -textvariable $token\(password) -validate key  \
      -validatecommand {::Jabber::ValidatePasswordStr %S}
    ttk::label $wui.lres -text "[mc Resource]:" -anchor e
    ttk::entry $wui.eres -font CociSmallFont \
      -width $width -textvariable $token\(resource) -validate key  \
      -validatecommand {::Jabber::ValidateResourceStr %S}
    ttk::label $wui.lnick -text "[mc Nickname]:" -anchor e
    ttk::entry $wui.enick -font CociSmallFont \
      -width $width -textvariable $token\(nickname)

    if {$config(profiles,style) eq "jid"} {
	# @@@ TODO
	grid  $wui.lpop   $wui.pop    -sticky e -pady 2
	grid  $wui.ljid   $wui.ejid   -sticky e -pady 2
	grid  $wui.lnick  $wui.enick  -sticky e -pady 2

	grid  $wui.pop  $wui.ejid  $wui.enick -sticky ew

	set wuserinfofocus $wui.ejid
    } elseif {$config(profiles,style) eq "parts"} {
	grid  $wui.lpop   $wui.pop    -sticky e -pady 2
	grid  $wui.lserv  $wui.eserv  -sticky e -pady 2
	grid  $wui.luser  $wui.euser  -sticky e -pady 2
	grid  $wui.lpass  $wui.epass  -sticky e -pady 2
	grid  $wui.lres   $wui.eres   -sticky e -pady 2
	grid  $wui.lnick  $wui.enick  -sticky e -pady 2

	grid  $wui.pop  $wui.eserv  $wui.euser  $wui.epass  $wui.eres  $wui.enick -sticky ew

	set wuserinfofocus $wui.eserv
    }
    
        
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
      -command [list [namespace current]::FrameNewCmd $w]
    ttk::button $wbt.del -text [mc {Delete Profile}] \
      -command [list [namespace current]::FrameDeleteCmd $w]

    if {0} {
	pack  $wbt.new  $wbt.del  -side top -fill x -pady 4
    } else {
	grid  $wbt.new  $wbt.del  -sticky ew -padx 10
	foreach c {0 1} {
	    grid columnconfigure $wbt $c -uniform u -weight 1
	}
    }
    
    # Need to pack options here to get the complete bottom slice.
    set wopt $w.fopt
    ttk::frame $wopt
    grid  $wopt  -  -sticky ew
    
    # Triangle switch for more options.
    set wtri $wopt.tri
    if {$moreless} {
	ttk::button $wtri -style Small.Toolbutton -padding {6 1} \
	  -compound left -image [::UI::GetIcon mactriangleclosed] \
	  -text "[mc More]..." -command [list [namespace current]::FrameMoreOpts $w]
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

    set state(wtri)   $wtri
    set state(wtabnb) $wtabnb
    set state(wmore)  $wfrmore
    set state(wmenu)  $wmenu
    set state(wfocus) $wuserinfofocus
    
    # We use an array for "more" options.
    set mtoken [namespace current]::${w}-more
    variable $mtoken
    upvar 0 $mtoken mstate

    # Translate the current profile to its 'state' and 'mstate' arrays.
    foreach {key value} [array get state prof,$profile,-*] {
	set optname [string map [list prof,$profile,- ""] $key]
	
	switch -- $optname {
	    resource - nickname {
		set state($optname) $value
	    }
	    default {
		set mstate($optname) $value
	    }
	}
    }

    NotebookOptionWidget $wtabnb $mtoken
    pack $wtabnb -fill x -expand 1
    
    # The actual prefs state for the current profile must be set.
    FrameSetCurrentFromTmp $w $state(selected)
    
    # This allows us to clean up some things when we go away.
    bind $w <Destroy> +[list [namespace current]::FrameOnDestroy %W]

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s.msg configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $w $w]    
    after idle $script
    
    return $w
}

proc ::Profiles::FrameMoreOpts {w} {
    variable $w
    upvar 0 $w state

    pack $state(wmore) -side top -fill x -padx 2
    $state(wtri) configure -command [list [namespace current]::FrameLessOpts $w] \
      -image [::UI::GetIcon mactriangleopen] -text "[mc Less]..."   
}

proc ::Profiles::FrameLessOpts {w} {
    variable $w
    upvar 0 $w state

    pack forget $state(wmore)
    $state(wtri) configure -command [list [namespace current]::FrameMoreOpts $w] \
      -image [::UI::GetIcon mactriangleclosed] -text "[mc More]..."   
}

# Profiles::FrameMakeTmpProfiles --
#
#       Make temp array for profiles.

proc ::Profiles::FrameMakeTmpProfiles {w} {    
    variable $w
    upvar 0 $w state
    
    # New... Profiles
    array unset state prof,*
    
    foreach {name spec} [GetList] {
	lassign [lrange $spec 0 2] server username password
	set state(prof,$name,name) $name
	set state(prof,$name,server)    $server
	set state(prof,$name,username)  $username
	set state(prof,$name,password)  $password
	set state(prof,$name,-resource) ""
	set state(prof,$name,-nickname) ""
	foreach {key value} [lrange $spec 3 end] {
	    set state(prof,$name,$key) $value
	}
	set jid [jlib::joinjid $username $server $state(prof,$name,-resource)]
	set state(prof,$name,jid) $jid
    }
}

proc ::Profiles::FrameTraceProfile {w name key op} {
    variable $w
    upvar 0 $w state

    Debug 4 "FrameTraceProfile name=$name, key=$key"
    FrameSetCmd $w $state(profile)
}

# Profiles::FrameSetCmd --
#
#       Callback when a new item is selected in the menu.

proc ::Profiles::FrameSetCmd {w pname} {
    variable $w
    upvar 0 $w state
        
    set selected $state(selected)
    
    # The 'pname' is here the new profile, and 'tmpSelected' the
    # previous one.
    Debug 2 "::Profiles::FrameSetCmd pname=$pname, selected=$selected"

    if {[info exists state(prof,$selected,name)]} {
	Debug 2 "\t selected exists"
	
	# Check if there are any empty fields.
	if {![FrameVerifyNonEmpty $w]} {
	    set state(profile) $state(selected)
	    Debug 2 "***::Profiles::FrameVerifyNonEmpty: set profile $state(selected)"
	    return
	}
	
	# Save previous state in tmp before setting the new one.
	FrameSaveCurrentToTmp $w $selected
    }
    
    # In case this is a new profile.
    if {[info exists state(prof,$pname,server)]} {
	FrameSetCurrentFromTmp $w $pname
    }
}

proc ::Profiles::FrameSetCurrentFromTmp {w pname} {
    variable $w
    upvar 0 $w state

    Debug 2 "::Profiles::FrameSetCurrentFromTmp pname=$pname"
    
    set state(server)   $state(prof,$pname,server)
    set state(username) $state(prof,$pname,username)
    set state(password) $state(prof,$pname,password)
    set state(jid)      $state(prof,$pname,jid)
    set state(resource) ""
    set state(nickname) ""

    set mtoken [namespace current]::${w}-more
    variable $mtoken
    upvar 0 $mtoken mstate

    NotebookSetDefaults $mtoken $state(server)
    
    foreach {key value} [array get state prof,$pname,-*] {
	set optname [string map [list prof,$pname,- ""] $key]
	Debug 4 "\t key=$key, value=$value, optname=$optname"
	
	switch -- $optname {
	    resource - nickname {
		set state($optname) $value
	    }
	    default {
		set mstate($optname) $value
	    }
	}
    }
    set state(selected) $pname
    set state(jid) [jlib::joinjid $state(username) $state(server) $state(resource)]
    
    NotebookSetAnyConfigState $state(wtabnb) $pname
    NotebookDefaultWidgetStates $state(wtabnb)
}

proc ::Profiles::FrameSaveCurrentToTmp {w pname} {
    variable $w
    upvar 0 $w state
    
    Debug 2 "::Profiles::FrameSaveCurrentToTmp pname=$pname"
    
    # Store it in the temporary array. 
    # But only of the profile already exists since we may have just deleted it!
    if {[info exists state(prof,$pname,name)]} {
	Debug 2 "\t exists state(prof,$pname,name)"
	
	set state(prof,$pname,name)      $pname
	set state(prof,$pname,server)    $state(server)
	set state(prof,$pname,username)  $state(username)
	set state(prof,$pname,password)  $state(password)
	set state(prof,$pname,jid)       $state(jid)
	set state(prof,$pname,-resource) $state(resource)
	set state(prof,$pname,-nickname) $state(nickname)
	
	set server $state(server)

	set mtoken [namespace current]::${w}-more
	variable $mtoken
	upvar 0 $mtoken mstate

	# Set more options if different from defaults.
	foreach key [array names mstate] {
	    
	    # Cleanup any old entries. Save only if different from default.
	    unset -nocomplain state(prof,$pname,-$key)
	    set dvalue [GetDefaultOptValue $key $server]
	    if {![string equal $mstate($key) $dvalue]} {
		set state(prof,$pname,-$key) $mstate($key)
	    }
	}
	set state(selected) $pname
    }
}

proc ::Profiles::FrameVerifyNonEmpty {w} {
    global  config
    variable $w
    upvar 0 $w state

    set ans 1

    if {$config(profiles,style) eq "jid"} {
	if {![jlib::jidvalidate $state(jid)]} {
	    ::UI::MessageBox -type ok -icon error  \
	      -title [mc Error] -message [mc jamessjidinvalid]
	    set ans 0
	}
    } else {
	
	# Check that necessary entries are non-empty, at least.
	if {($state(server) eq "") || ($state(username) eq "")} {
	    ::UI::MessageBox -type ok -icon error  \
	      -title [mc Error] -message [mc messfillserveruser]
	    set ans 0
	}
    }
    return $ans
}

proc ::Profiles::MakeUniqueProfileName {name} {
    variable wallframes
    
    # Create a unique profile name if not given.
    set names {}
    foreach w $wallframes {
	set names [concat $names [FrameGetAllTmpNames $w]]
    }
    set names [lsort -unique $names]
    
    # Make sure that 'profile' is unique.
    if {[lsearch -exact $names $name] >= 0} {
	set i 2
	set tmpprof $name
	set name ${tmpprof}-${i}
	while {[lsearch -exact $names $name] >= 0} {
	    incr i
	    set name ${tmpprof}-${i}
	}
    }
    return $name
}
    
proc ::Profiles::FrameGetAllTmpNames {w} {
    variable $w
    upvar 0 $w state
    
    set names [list]
    foreach {key name} [array get state prof,*,name] {
	lappend names $name
    }    
    return [lsort -dictionary $names]
}

proc ::Profiles::FrameNewCmd {w} {
    variable $w
    upvar 0 $w state
        
    set newName ""
    
    # First get a unique profile name.
    set ans [::UI::MegaDlgMsgAndEntry [mc Profile] [mc prefprofname] \
      "[mc {Profile Name}]:" newName [mc Cancel] [mc OK]]
    if {$ans eq "cancel" || $newName eq ""} {
	return
    }
    Debug 2 "::Profiles::FrameNewCmd state(selected)$state(selected), newName=$newName"

    set wmenu $state(wmenu)
    
    set uname [MakeUniqueProfileName $newName]
    $wmenu add radiobutton -label $uname  \
      -variable [namespace current]::$w\(profile)

    set state(selected) $uname
    set state(profile)  $uname
    set state(server)   ""
    set state(username) ""
    set state(jid)      ""
    set state(password) ""
    set state(resource) ""
    set state(nickname) ""
    
    set mtoken [namespace current]::${w}-more
    NotebookSetDefaults $mtoken ""
    
    # Must do this for it to be automatically saved.
    set state(prof,$uname,name) $uname
    focus $state(wfocus)
}

proc ::Profiles::FrameDeleteCmd {w} {
    variable $w
    upvar 0 $w state
    
    set profile $state(profile)
        
    Debug 2 "::Profiles::FrameDeleteCmd profile=$profile"
    set ans "yes"
    
    # The present state may be something that has not been stored yet.
    if {[info exists state(prof,$profile,server)]} {
	set ans [::UI::MessageBox -title [mc Warning]  \
	  -type yesno -icon warning -default yes  \
	  -parent [winfo toplevel $w] \
	  -message [mc messremoveprofile]]
    }
    if {$ans eq "yes"} {
	set wmenu $state(wmenu)
	set idx [$wmenu index $profile]
	if {$idx >= 0} {
	    $wmenu delete $idx
	}
	array unset state prof,$profile,*
	
	# Set selection to first.
	set state(profile) [lindex [FrameGetAllTmpNames $w] 0]
	FrameSetCmd $w $state(profile)
    }
}

proc ::Profiles::FrameGetSelected {w} {
    variable $w
    upvar 0 $w state
    
    return $state(selected)
}

proc ::Profiles::FrameGetProfiles {w} {
    global  config
    variable $w
    upvar 0 $w state
    
    Debug 2 "::Profiles::FrameGetProfiles"
    
    # Get present dialog state into tmp array first.
    FrameSaveCurrentToTmp $w $state(profile)
    
    # The 'resource' handled differently depending on the style.
    set profileL [list]
    foreach name [FrameGetAllTmpNames $w] {
	if {$config(profiles,style) eq "jid"} {
	    jlib::splitjidex $state(prof,$name,jid) u s resource
	    
	} elseif {$config(profiles,style) eq "parts"} {
	    set s $state(prof,$name,server)
	    set u $state(prof,$name,username)
	}
	set p $state(prof,$name,password)
	set plist [list $s $u $p]
	if {$config(profiles,style) eq "jid"} {
	    lappend plist -resource $resource
	}
	
	# Set the optional options as "-key value ...". Sorted!
	foreach key [lsort [array names state prof,$name,-*]] {
	    set optname [string map [list prof,$name,- ""] $key]
	    set value $state($key)

	    switch -- $optname {
		resource {
		    if {$config(profiles,style) eq "parts"} {
			if {[string length $value]} {
			    lappend plist -$optname $value 
			}
		    }
		}
		nickname {
		    if {[string length $value]} {
			lappend plist -$optname $value 
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
	lappend profileL $name $plist
    }
    return $profileL
}

proc ::Profiles::FrameOnDestroy {w} {
    variable $w
    variable wallframes
    
    lprune wallframes $w

    # This removes any traces on this array as well.
    unset -nocomplain $w
}

#-------------------------------------------------------------------------------

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

proc ::Profiles::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------
