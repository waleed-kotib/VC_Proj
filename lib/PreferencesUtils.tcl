#  PreferencesUtils.tcl ---
#  
#      This file is part of The Coccinella application. It defines some 
#      utilities for keeping the user preferences. 
#      
#  Copyright (c) 1999-2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: PreferencesUtils.tcl,v 1.43 2005-06-03 13:00:06 matben Exp $
# 
################################################################################
#                                                                                                                                                              
#  The priority arguments to the option command are normally specified 
#  symbolically using one of the following values: 
#                                                                                                                                                              
#   factoryDefault                                                                                                                                              
#          Level 20. Used for default values hard-coded into application.                                                                                
#                                                                                                                                                      
#   appDefault                                                                                                                                
#          Level 40. Used for options specified in application-specific 
#          startup files.                                                                    
#                                                                                                                                    
#   userDefault                                                                                                                           
#          Level 60. Used for options describing customization, such as
#          shortcuts etc.                                                                                                
#                                                                                            
#   interactive                                                                                                                                     
#          Level 80. Used for options specified interactively after the 
#          application starts running.
#   
#   absolute                        
#          Level 100. Cannot be overridden.
#          
################################################################################

package provide PreferencesUtils 1.0

namespace eval ::PreferencesUtils:: {
    
    variable priNameToNum
    array set priNameToNum {0 0 20 20 40 40 60 60 80 80 100 100   \
      factoryDefault 20    \
      appDefault     40    \
      userDefault    60    \
      interactive    80    \
      absolute 100}
}

# PreferencesUtils::Init --
# 
#       Reads the preference file into the internal option database.
#       Use pre 0.94.2 prefs file as a fallback.
#
# Arguments:
#                        
# Results:
#       updates the internal option database.

proc ::PreferencesUtils::Init { } {
    global  this
    
    set prefsFilePath $this(userPrefsFilePath)
    set old $this(oldPrefsFilePath)
    
    if {[file exists $prefsFilePath]} {
	if {[catch {option readfile $prefsFilePath} err]} {
	    ::UI::MessageBox -type ok -icon error \
	      -message "Error reading preference file: $prefsFilePath."
	}
    } elseif {[file exists $old]} {
	if {[catch {option readfile $old} err]} {
	    ::UI::MessageBox -type ok -icon error \
	      -message "Error reading preference file: $old."
	}
    }
    
    # Post prefs file if any.
    if {[file exists $this(postPrefsFile)]} {
	catch {option readfile $this(postPrefsFile)} err
    }
}

# PreferencesUtils::Add --
# 
#       Set the user preferences from the preferences file if they are there,
#       else take the hardcoded defaults.
#       Take care of the priority for each variable.
#
# Arguments:
#       thePrefs  a list of lists where each sublist defines an item in the
#                 following way:  
#                    {theVarName itsResourceName itsHardCodedDefaultValue
#                    thePriority}.
#                        
# Results:
#       none

proc ::PreferencesUtils::Add {thePrefs} {
    global  prefs
    
    variable priNameToNum

    set isOldPrefFile 0
    
    foreach item $thePrefs {
	foreach {varName resName defaultValue} $item break
	
	# The default priority for hardcoded values are 20 (factoryDefault).
	if {[llength $item] >= 4} {
	    set varPriority $priNameToNum([lindex $item 3])
	} else {
	    set varPriority 20
	}
	lappend prefs(master)   \
	  [list $varName $resName $defaultValue $varPriority]
	
	# Override options that should be write only:
	# for instance, version numbers.
	if {$varPriority <= 60} {
	    set value [GetValue $varName $resName $defaultValue]
	} else {
	    set value $defaultValue
	}
	
	# All names must be fully qualified. Therefore #0.
	upvar #0 $varName var
	
	# Treat arrays specially.
	if {[string match "*_array" $resName]} {
	    array set var $value
	} else {
	    set var $value
	}
    }   
}

# PreferencesUtils::GetValue --
# 
#       Returns the preference variables value, either from the preference
#       file, or if there is no value for it there, return the default
#       value.
#
# Arguments:
#       varName       the actual name of the preference variable.
#       resName       the resource name of the preference variable.
#       defValue      the default value of the preference name.
#       
# Results:
#       a value for the preference with the given name. 

proc ::PreferencesUtils::GetValue {varName resName defValue} {
    upvar #0 varName theVar
    
    set theVar [option get . $resName {}]
    
    # If not there {} then take the itsHardCodedDefaultValue.
    if {$theVar == {}} {
	set theVar $defValue
    }
    return $theVar
}
  
# PreferencesUtils::SaveToFile --
# 
#       Saves the preferences to a file. Preferences must be stored in
#       the master copy 'prefs(master)' in the corresponding list format.
#       We do not save options if equal to default values.
#       This has the benefit that we may change hardcoded defaults without
#       changing resource names or other tricks. It is also useful if a
#       default value depends on an dynamic OS thing, like if QuickTime
#       is installed or not.
#
# Arguments:
#       
# Results:
#       preference file written. 

proc ::PreferencesUtils::SaveToFile { } {
    global prefs this

    # Work on a temporary file and switch later.
    set tmpFile $this(userPrefsFilePath).tmp
    if {[catch {open $tmpFile w} fid]} {
	::UI::MessageBox -icon error -type ok \
	  -message [mc messerrpreffile $tmpFile]
	return
    }
    
    # Header information.
    puts $fid "!\n!   User preferences for the Whiteboard application."
    puts $fid "!   It may be edited if you know what you are doing."
    puts $fid "!   The data written at: [clock format [clock seconds]]\n!"
    
    # Only preferences indicated in the master copy are saved.
    foreach item $prefs(master) {
	foreach {varName resName defVal} $item {break}
	
	# All names must be fully qualified. Therefore #0.
	upvar #0 $varName var
	
	# Treat arrays specially.
	if {[string match "*_array" $resName]} {
	    array set tmpArr $defVal
	    if {[arraysequal $varName tmpArr]} {
		continue
	    }
	    puts $fid [format "%-24s\t%s" *${resName}: [array get var]]	    
	} else {
	    if {[string equal $var $defVal]} {
		continue
	    }
	    puts $fid [format "%-24s\t%s" *${resName}: $var]
	}
    }
    close $fid
    if {[catch {file rename -force $tmpFile $this(userPrefsFilePath)} msg]} {
	::UI::MessageBox -type ok -message {Error renaming preferences file.}  \
	  -icon error
	return
    }
    if {[string equal $this(platform) "macintosh"]} {
	file attributes $this(userPrefsFilePath) -type pref
    }
}

# PreferencesUtils::ResetToFactoryDefaults --
# 
#       Resets the preferences in 'prefs(master)' to their hardcoded values.
#
# Arguments:
#       maxPriority 0 20 40 60 80 100, or equivalent description.
#                   Pick only values with lower priority than maxPriority.
#       
# Results:
#       prefs values may change, and user interface stuff updated. 

proc ::PreferencesUtils::ResetToFactoryDefaults {maxPriority} {
    global  prefs
    
    variable priNameToNum

    set maxPriorityNum $priNameToNum($maxPriority)
    foreach item $prefs(master) {
	set varName [lindex $item 0]
	set resName [lindex $item 1]
	set defaultValue [lindex $item 2]
	set varPriority [lindex $item 3]
	if {$varPriority < $maxPriorityNum} {
	    upvar #0 $varName var
	
	    # Treat arrays specially.
	    if {[string match "*_array" $resName]} {
		array set var $defaultValue
	    } else {
		set var $defaultValue
	    }
	}
    }
}

# PreferencesUtils::ResetToUserDefaults --
# 
#       Resets the applications state to correspond to the existing
#       preference file.
#
# Arguments:
#       
# Results:
#       prefs values may change, and user interface stuff updated. 

proc ::PreferencesUtils::ResetToUserDefaults { } {
    global  prefs
	
    # Need to make a temporary storage in order not to duplicate items.
    set thePrefs $prefs(master)
    set prefs(master) {}
    
    # Read the user option database file once again.
    Init
    Add $thePrefs
}

# PreferencesUtils::SetUserPreferences --
#
#       Set defaults in the option database for widget classes.
#       First, on all platforms...
#       Set the user preferences from the preferences file if they are there,
#       else take the hardcoded defaults.
#       'thePrefs': a list of lists where each sublist defines an item in the
#       following way:  {theVarName itsResourceName itsHardCodedDefaultValue
#                 {thePriority 20}}.
# Note: it may prove useful to have the versions numbers as the first elements!

proc ::PreferencesUtils::SetUserPreferences { } {
    global  prefs
    
    ::Debug 2 "::PreferencesUtils::SetUserPreferences"
    
    ::PreferencesUtils::Add [list  \
      [list prefs(majorVers)       prefs_majorVers       $prefs(majorVers)       absolute] \
      [list prefs(minorVers)       prefs_minorVers       $prefs(minorVers)       absolute] \
      [list prefs(protocol)        prefs_protocol        $prefs(protocol)]       \
      [list prefs(autoConnect)     prefs_autoConnect     $prefs(autoConnect)]    \
      [list prefs(multiConnect)    prefs_multiConnect    $prefs(multiConnect)]   \
      [list prefs(thisServPort)    prefs_thisServPort    $prefs(thisServPort)]   \
      [list prefs(httpdPort)       prefs_httpdPort       $prefs(httpdPort)]   \
      [list prefs(remotePort)      prefs_remotePort      $prefs(remotePort)]     \
      [list prefs(postscriptOpts)  prefs_postscriptOpts  $prefs(postscriptOpts)] \
      [list prefs(firstLaunch)     prefs_firstLaunch     $prefs(firstLaunch)     userDefault] \
      [list prefs(unixPrintCmd)    prefs_unixPrintCmd    $prefs(unixPrintCmd)]   \
      [list prefs(webBrowser)      prefs_webBrowser      $prefs(webBrowser)]     \
      [list prefs(userPath)        prefs_userPath        $prefs(userPath)]        \
      [list prefs(winGeom)         prefs_winGeom         $prefs(winGeom)]        \
      [list prefs(paneGeom)        prefs_paneGeom        $prefs(paneGeom)]       \
      ]    
            
    # Map list of win geoms into an array.
    foreach {win geom} $prefs(winGeom) {
	set prefs(winGeom,$win) $geom
    }
    foreach {win pos} $prefs(paneGeom) {
	set prefs(paneGeom,$win) $pos
    }
    
    # The prefs(stripJabber) option always overrides overrides prefs(protocol)!
    if {$prefs(stripJabber)} {
	set prefs(protocol) "symmetric"
    }
}

# PreferencesUtils::ParseCommandLineOptions --
#
#       Process command line options. Some systems (Mac OS X) add their own
#       things in the beginning. Skip these.

proc ::PreferencesUtils::ParseCommandLineOptions {cargc cargv} {
    global  prefs argvArr
    
    if {!$prefs(stripJabber)} {
	upvar ::Jabber::jprefs jprefs
	upvar ::Jabber::jstate jstate
    }
    
    # Skip anything that does not start with "-". Skip also -psn_...
    if {![regexp {(-[a-z].+$)} $cargv match optList]} {
	return
    }
    set optList [lsearch -all -not -inline -regexp $optList {-psn_\d*}]
    
    foreach {key value} $optList {
	
	switch -glob -- $key {
	    -debugLevel {
		set name [string trimleft $key -]
		uplevel #0 set $name $value
	    }
	    -port {
		
	    }
	    -connect {
		
	    }
	    -prefs_* {
		if {[regexp {^-prefs_(.+)$} $key match index]} {
		    set prefs($index) $value
		}
	    }
	    -jprefs_* {
		if {[regexp {^-jprefs_(.+)$} $key match index]} {
		    set jprefs($index) $value
		}
	    }
	    -jstate_debug {
		if {[regexp {^-jstate_(.+)$} $key match index]} {
		    set jstate($index) $value
		}
	    }
	}
    }
}

#-------------------------------------------------------------------------------
