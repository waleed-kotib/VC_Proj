#  PrefUtils.tcl ---
#  
#      This file is part of The Coccinella application. It defines some 
#      utilities for keeping the user preferences. 
#      
#  Copyright (c) 1999-2007  Mats Bengtsson
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
# $Id: PrefUtils.tcl,v 1.13 2007-09-14 08:11:46 matben Exp $
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

package provide PrefUtils 1.0

namespace eval ::PrefUtils:: {
    
    variable priNameToNum
    array set priNameToNum {
	0 0 20 20 40 40 60 60 80 80 100 100
	factoryDefault 20
	appDefault     40
	userDefault    60
	interactive    80
	absolute      100
    }
}

# PrefUtils::Init --
# 
#       Reads the preference file into the internal option database.
#       Use pre 0.94.2 prefs file as a fallback.
#
# Arguments:
#                        
# Results:
#       updates the internal option database.

proc ::PrefUtils::Init { } {
    global  this prefs
    
    set prefs(master,default)  {}
    set prefs(master,mustSave) {}
    set prefs(master)          {}

    set prefsFilePath $this(userPrefsFilePath)
    
    # Pre prefs file if any. Lower priority!
    if {[file exists $this(prePrefsFile)]} {
	catch {option readfile $this(prePrefsFile) startupFile} err
    }
    set appName    [option get . appName {}]
    set theAppName [option get . theAppName {}]
    
    if {[file exists $prefsFilePath]} {
	if {[catch {option readfile $prefsFilePath} err]} {
	    tk_messageBox -type ok -title [mc Error] -icon error \
	      -message "Error reading preference file: $prefsFilePath."
	}
    }
    
    # Post prefs file if any.
    if {[file exists $this(postPrefsFile)]} {
	catch {option readfile $this(postPrefsFile)} err
    }
}

# PrefUtils::Add --
# 
#       Set the user preferences from the preferences file if they are there,
#       else take the hardcoded defaults.
#       Take care of the priority for each variable.
#
# Arguments:
#       prefsL a list of lists where each sublist defines an item in the
#                 following way: 
#                 {varName resourceName defaultValue ?priority?}
#                        
# Results:
#       none

proc ::PrefUtils::Add {prefsL} {
    AddToMaster $prefsL
}

proc ::PrefUtils::AddMustSave {prefsL} {
    AddToMaster $prefsL mustSave
}

proc ::PrefUtils::AddToMaster {prefsL {key ""}} {
    global  prefs
    
    variable priNameToNum
    
    foreach item $prefsL {
	foreach {varName resName defaultValue} $item { break }
	
	# The default priority for hardcoded values are 20 (factoryDefault).
	if {[llength $item] >= 4} {
	    set priority $priNameToNum([lindex $item 3])
	} else {
	    set priority 20
	}
	if {$key eq ""} {
	    lappend prefs(master,default)  \
	      [list $varName $resName $defaultValue $priority]
	} else {
	    lappend prefs(master,$key)  \
	      [list $varName $resName $defaultValue $priority]
	}
	
	# Override options that should be write only:
	# for instance, version numbers.
	if {$priority <= 60} {
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
    
    # Keep syncd.
    set prefs(master) [concat $prefs(master,default) $prefs(master,mustSave)]
}

# PrefUtils::GetValue --
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

proc ::PrefUtils::GetValue {varName resName defValue} {
    
    set value [option get . $resName {}]
    
    # If not there {} then take the itsHardCodedDefaultValue.
    if {$value == {}} {
	set value $defValue
    }
    return $value
}

# PrefUtils::SaveToFile --
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

proc ::PrefUtils::SaveToFile { } {
    global prefs this
    
    set userPrefsFile $this(userPrefsFilePath)	

    # Work on a temporary file and switch later.
    set tmpFile $userPrefsFile.tmp
    if {[catch {open $tmpFile w} fid]} {
	::UI::MessageBox -icon error -title [mc Error] -type ok \
	  -message [mc messerrpreffile2 $tmpFile]
	return
    }
    fconfigure $fid -encoding utf-8
    
    # Header information.
    puts $fid "!\n!   User preferences for the Coccinella application."
    puts $fid "!   It may be edited if you know what you are doing."
    puts $fid "!   The data written at: [clock format [clock seconds]]\n!"
    
    # Only preferences indicated in the master copy are saved.
    foreach item $prefs(master,default) {
	PutsItem $item $fid 0
    }
    foreach item $prefs(master,mustSave) {
	PutsItem $item $fid 1
    }
    close $fid
    if {[catch {file rename -force $tmpFile $userPrefsFile} err]} {
	set msg "Error renaming preferences file: $err"
	::UI::MessageBox -type ok -message $msg -icon error
	return
    }
    if {$this(platform) eq "windows"} {
	file attributes $userPrefsFile -hidden 1
    }
}

proc ::PrefUtils::PutsItem {item fid ignoreDefault} {
    
    lassign $item varName resName defVal
        
    # All names must be fully qualified. Therefore #0.
    upvar #0 $varName var
    
    # Treat arrays specially.
    if {[string match "*_array" $resName]} {
	array set tmpArr $defVal
	if {$ignoreDefault || ![arraysequal $varName tmpArr]} {
	    puts $fid [format "%-24s\t%s" *${resName}: [array get var]]	    
	}
    } else {
	if {$ignoreDefault || ![string equal $var $defVal]} {
	    puts $fid [format "%-24s\t%s" *${resName}: $var]
	}
    }
}

# PrefUtils::ResetToFactoryDefaults --
# 
#       Resets the preferences in 'prefs(master)' to their hardcoded values.
#
# Arguments:
#       maxPriority 0 20 40 60 80 100, or equivalent description.
#                   Pick only values with lower priority than maxPriority.
#       
# Results:
#       prefs values may change, and user interface stuff updated. 

proc ::PrefUtils::ResetToFactoryDefaults {maxPriority} {
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

# PrefUtils::ResetToUserDefaults --
# 
#       Resets the applications state to correspond to the existing
#       preference file.
#
# Arguments:
#       
# Results:
#       prefs values may change, and user interface stuff updated. 

proc ::PrefUtils::ResetToUserDefaults { } {
    global  prefs
	
    # Need to make a temporary storage in order not to duplicate items.
    set defaultList $prefs(master,default)
    set mustSaveList $prefs(master,mustSave)
    
    # Read the user option database file once again.
    Init
    Add $defaultList
    AddMustSave $mustSaveList
}

# PrefUtils::ParseCommandLineOptions --
#
#       Process command line options. Some systems (Mac OS X) add their own
#       things in the beginning. Skip these.

proc ::PrefUtils::ParseCommandLineOptions {cargv} {
    global  prefs argvArr
    
    if {$cargv == {}} {
	return
    }
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
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
