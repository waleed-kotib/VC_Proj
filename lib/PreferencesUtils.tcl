#  PreferencesUtils.tcl ---
#  
#      This file is part of the whiteboard application. It defines some 
#      utilities for keeping the user preferences. 
#      
#  Copyright (c) 1999-2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: PreferencesUtils.tcl,v 1.17 2003-11-09 15:07:32 matben Exp $
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
      factoryDefault 20 appDefault 40 userDefault 60 interactive 80 \
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
    global  prefs
    
    set prefsFilePath $prefs(userPrefsFilePath)
    set old $prefs(oldPrefsFilePath)
    
    if {[file exists $prefsFilePath]} {
	if {[catch {option readfile $prefsFilePath} err]} {
	    tk_messageBox -type ok -icon error -message  \
	      [FormatTextForMessageBox \
	      "Error reading preference file: $prefsFilePath."]
	}
    } elseif {[file exists $old]} {
	if {[catch {option readfile $old} err]} {
	    tk_messageBox -type ok -icon error -message  \
	      [FormatTextForMessageBox \
	      "Error reading preference file: $old."]
	}
    }
}

# PreferencesUtils::Add --
# 
#       Set the user preferences from the preferences file if they are there,
#       else take the hardcoded defaults.
#       Take care if the priority for each variable.
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
	foreach {varName resourceName defaultValue} $item break
	
	# The default priority for hardcoded values are 20 (factoryDefault).
	if {[llength $item] >= 4} {
	    set varPriority $priNameToNum([lindex $item 3])
	} else {
	    set varPriority 20
	}
	lappend prefs(master)   \
	  [list $varName $resourceName $defaultValue $varPriority]
	
	# Override options that should be write only:
	# for instance, version numbers.
	if {$varPriority <= 60} {
	    set value [GetValue $varName $resourceName $defaultValue]
	} else {
	    set value $defaultValue
	}
	
	# Don't read in version 0.92 preference file.
	if {[string equal $resourceName "prefs_minorVers"]} {
	    set majorOnFile [option get . prefs_majorVers {}]
	    set minorOnFile [option get . prefs_minorVers {}]
	    if {[string equal ${majorOnFile}.${minorOnFile} "0.92"]} {
		
		# Empty the database just read. Clears also the widget options!
		option clear
		
		# Reset the widget defaults.
		::PreferencesUtils::SetWidgetDefaultOptions
	    }
	}

	# Treat incompatbility issues for prefs format here. DIRTY! Usch.		
	# Do not read in jserver(list) if written by 0.93; format change.
	if {[string equal $resourceName "jserver_list"]} {
	    set majorOnFile [option get . prefs_majorVers {}]
	    set minorOnFile [option get . prefs_minorVers {}]
	    if {[string equal ${majorOnFile}.${minorOnFile} "0.93"]} {
		set $varName $defaultValue
		continue
	    }
	}	
	
	# All names must be fully qualified. Therefore #0.
	upvar #0 $varName var
	
	# Treat arrays specially.
	if {[string match "*_array" $resourceName]} {
	    array set var $value
	} else {
	    set var $value
	}
	#puts "varName=$varName, resourceName=$resourceName, defaultValue=$defaultValue, value=$value"
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
#       resourceName  the resource name of the preference variable.
#       defValue      the default value of the preference name.
#       
# Results:
#       a value for the preference with the given name. 

proc ::PreferencesUtils::GetValue {varName resourceName defValue} {
    upvar #0 varName theVar
    
    set theVar [option get . $resourceName {}]
    
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
#
# Arguments:
#       
# Results:
#       preference file written. 

proc ::PreferencesUtils::SaveToFile { } {
    global prefs this

    # Work on a temporary file and switch later.
    set tmpFile $prefs(userPrefsFilePath).tmp
    if {[catch {open $tmpFile w} fid]} {
	tk_messageBox -icon error -type ok -message \
	  [FormatTextForMessageBox [::msgcat::mc messerrpreffile $tmpFile]]
	return
    }
    
    # Header information.
    puts $fid "!\n!   User preferences for the Whiteboard application."
    puts $fid "!   It may be edited if you now what you are doing."
    puts $fid "!   The data written at: [clock format [clock seconds]]\n!"
    
    # Only preferences indicated in the master copy are saved.
    foreach item $prefs(master) {
	set varName [lindex $item 0]
	set resourceName [lindex $item 1]
	
	# All names must be fully qualified. Therefore #0.
	upvar #0 $varName var
	
	# Treat arrays specially.
	if {[string match "*_array" $resourceName]} {
	    puts $fid [format "%-24s\t%s" *${resourceName}: [array get var]]	    
	} else {
	    puts $fid [format "%-24s\t%s" *${resourceName}: $var]
	}
    }
    close $fid
    if {[catch {file rename -force $tmpFile $prefs(userPrefsFilePath)} msg]} {
	tk_messageBox -type ok -message {Error renaming preferences file.}  \
	  -icon error
	return
    }
    if {[string equal $this(platform) "macintosh"]} {
	file attributes $prefs(userPrefsFilePath) -type pref
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
	set resourceName [lindex $item 1]
	set defaultValue [lindex $item 2]
	set varPriority [lindex $item 3]
	if {$varPriority < $maxPriorityNum} {
	    upvar #0 $varName var
	
	    # Treat arrays specially.
	    if {[string match "*_array" $resourceName]} {
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

# PreferencesUtils::SetWidgetDefaultOptions --
#
#       Set defaults in the option database for widget classes.
#       First, on all platforms...

proc ::PreferencesUtils::SetWidgetDefaultOptions { } {
    global  prefs sysFont this
    
    option add *Canvas.Background                   $prefs(bgColGeneral) startupFile
    option add *Checkbutton.Font                    $sysFont(s) startupFile
    option add *Frame.Background                    $prefs(bgColGeneral) startupFile
    option add *Label.Background                    $prefs(bgColGeneral) startupFile
    option add *Label.Font                          $sysFont(s) startupFile
    option add *Message.Background                  $prefs(bgColGeneral) startupFile
    option add *Progressbar.Background              $prefs(bgColGeneral) startupFile
    option add *Entry.Background                    white startupFile
    option add *Entry.BorderWidth                   1 startupFile
    option add *Entry.Font                          $sysFont(s) startupFile
    option add *Entry.HighlightColor                #6363CE startupFile
    option add *Entry.HighlightBackground           $prefs(bgColGeneral) startupFile
    option add *Entry.DisableBackground             $prefs(bgColGeneral) startupFile
    option add *Entry.DisableForeground             gray20 startupFile
    option add *Listbox.HighlightColor              #6363CE startupFile
    option add *Listbox.HighlightBackground         $prefs(bgColGeneral) startupFile
    option add *Radiobutton.Font                    $sysFont(s) startupFile
    option add *Text.Background                     white startupFile
    option add *Text.HighlightColor                 #6363CE startupFile
    option add *Text.HighlightBackground            $prefs(bgColGeneral) startupFile
    option add *Tablelist.HighlightThickness        3 startupFile
    option add *Tablelist.HighlightColor            #6363CE startupFile
    option add *Tablelist.HighlightBackground       $prefs(bgColGeneral) startupFile
    option add *Tablelist.HighlightBackground       $prefs(bgColGeneral) startupFile
    option add *ButtonTray.background               $prefs(bgColGeneral) startupFile
    
    # ...and then on specific platforms.
    
    switch -- $this(platform) {
	macintosh - macosx {
	    option add *Radiobutton.Background     $prefs(bgColGeneral) startupFile
	    option add *Button.HighlightBackground $prefs(bgColGeneral) startupFile
	    option add *Checkbutton.Background     $prefs(bgColGeneral) startupFile
	    option add *Entry.HighlightThickness   3 startupFile
	    option add *Listbox.Font               $sysFont(m) startupFile
	    option add *Listbox.HighlightThickness 3 startupFile
	    option add *Text.HighlightThickness    3 startupFile
	    option add *Tablelist.BorderWidth      1 startupFile
	}
	windows {
	    option add *Radiobutton.Background $prefs(bgColGeneral) startupFile
	    option add *Button.Background $prefs(bgColGeneral) startupFile
	    option add *Checkbutton.Background $prefs(bgColGeneral) startupFile
	    option add *Entry.HighlightThickness 2 startupFile
	    option add *Listbox.Background white startupFile
	    option add *Listbox.Font $sysFont(m) startupFile
	    option add *Listbox.HighlightThickness 2 startupFile
	    option add *Text.HighlightThickness 2 startupFile
	}
	unix {
	    option add *Entry.Foreground Black startupFile
	    option add *Entry.HighlightThickness 2 startupFile
	    option add *Listbox.HighlightThickness 2 startupFile
	    option add *Listbox.BorderWidth 1 startupFile
	    option add *Text.HighlightThickness 2 startupFile
	    option add *Scrollbar.BorderWidth 1 startupFile
	    option add *Scrollbar.Width 12 startupFile
	    option add *Scrollbar*troughColor #bdbdbd startupFile
	    option add *Tablelist.BorderWidth 1 startupFile
	}
    }
}


proc ::PreferencesUtils::ReadOptionDatabase { } {
    global  prefs
    
    if {[info exists $prefs(optionsRdb)]} {
	catch {option readfile $prefs(optionsRdb) userDefault}
    }
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
    global  prefs state
    
    ::PreferencesUtils::Add [list  \
      [list prefs(majorVers)       prefs_majorVers       $prefs(majorVers)       absolute] \
      [list prefs(minorVers)       prefs_minorVers       $prefs(minorVers)       absolute] \
      [list prefs(canvasFonts)     prefs_canvasFonts     $prefs(canvasFonts)]    \
      [list prefs(privacy)         prefs_privacy         $prefs(privacy)]        \
      [list prefs(45)              prefs_45              $prefs(45)]             \
      [list prefs(checkCache)      prefs_checkCache      $prefs(checkCache)]     \
      [list prefs(protocol)        prefs_protocol        $prefs(protocol)]       \
      [list prefs(autoConnect)     prefs_autoConnect     $prefs(autoConnect)]    \
      [list prefs(multiConnect)    prefs_multiConnect    $prefs(multiConnect)]   \
      [list prefs(thisServPort)    prefs_thisServPort    $prefs(thisServPort)]   \
      [list prefs(remotePort)      prefs_remotePort      $prefs(remotePort)]     \
      [list prefs(setNATip)        prefs_setNATip        $prefs(setNATip)]       \
      [list prefs(NATip)           prefs_NATip           $prefs(NATip)]          \
      [list prefs(shortcuts)       prefs_shortcuts       $prefs(shortcuts)       userDefault] \
      [list prefs(shortsMulticastQT) prefs_shortsMulticastQT $prefs(shortsMulticastQT) userDefault] \
      [list prefs(postscriptOpts)  prefs_postscriptOpts  $prefs(postscriptOpts)] \
      [list prefs(firstLaunch)     prefs_firstLaunch     $prefs(firstLaunch)     userDefault] \
      [list prefs(SpeechOn)        prefs_SpeechOn        $prefs(SpeechOn)]       \
      [list prefs(unixPrintCmd)    prefs_unixPrintCmd    $prefs(unixPrintCmd)]   \
      [list prefs(webBrowser)      prefs_webBrowser      $prefs(webBrowser)]     \
      [list prefs(userDir)         prefs_userDir         $prefs(userDir)]        \
      [list prefs(winGeom)         prefs_winGeom         $prefs(winGeom)]        \
      [list prefs(paneGeom)        prefs_paneGeom        $prefs(paneGeom)]       \
      [list prefs(lastAutoUpdateVersion) prefs_lastAutoUpdateVersion $prefs(lastAutoUpdateVersion)] \
      [list prefs(pluginBanList)   prefs_pluginBanList   $prefs(pluginBanList)]  \
      [list ::UI::dims(x)          dims_x                $::UI::dims(x)]         \
      [list ::UI::dims(y)          dims_y                $::UI::dims(y)]         \
      [list ::UI::dims(wRoot)      dims_wRoot            $::UI::dims(wRoot)]     \
      [list ::UI::dims(hRoot)      dims_hRoot            $::UI::dims(hRoot)]     \
      [list state(btState)         state_btState         $state(btState)]        \
      [list state(bgColCan)        state_bgColCan        $state(bgColCan)]       \
      [list state(fgCol)           state_fgCol           $state(fgCol)]          \
      [list state(penThick)        state_penThick        $state(penThick)]       \
      [list state(brushThick)      state_brushThick      $state(brushThick)]     \
      [list state(fill)            state_fill            $state(fill)]           \
      [list state(arcstyle)        state_arcstyle        $state(arcstyle)]       \
      [list state(fontSize)        state_fontSize        $state(fontSize)]       \
      [list state(font)            state_font            $state(font)]           \
      [list state(fontWeight)      state_fontWeight      $state(fontWeight)]     \
      [list state(smooth)          state_smooth          $state(smooth)]         \
      [list state(dash)            state_dash            $state(dash)]           \
      [list state(canGridOn)       state_canGridOn       $state(canGridOn)]      \
      [list state(visToolbar)      state_visToolbar      $state(visToolbar)]  ]
    
    # All MIME type stuff... The problem is that they are all arrays... 
    # Invented the ..._array resource specifier!    
    # We should have used accesor functions and not direct access to internal
    # arrays. Sorry for this.
    # 
    ::PreferencesUtils::Add [list  \
      [list ::Types::mime2Desc     mime2Desc_array         [::Types::GetDescriptionArr]] \
      [list ::Types::mimeIsText    mimeTypeIsText_array    [::Types::GetIsMimeTextArr]]  \
      [list ::Types::mime2SuffList mime2SuffixList_array   [::Types::GetSuffixListArr]]  \
      [list ::Plugins::mimeTypeDoWhat mimeTypeDoWhat_array [::Plugins::GetDoWhatForMimeArr]] ]
            
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
    
    # Moved 30days -> month
    if {$prefs(checkCache) == "30days"} {
	set prefs(checkCache) "month"
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
    regexp {(-[a-z].+$)} $cargv match optList
    set ind [lsearch -glob $optList "-psn*"]
    if {$ind >= 0} {
	set optList [lrange $optList [expr $ind + 1] end]
    }
    
    foreach {key value} $optList {
	switch -glob -- $key {
	    -debugLevel - -debugServerLevel {
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
