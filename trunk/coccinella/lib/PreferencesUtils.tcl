#  PreferencesUtils.tcl ---
#  
#      This file is part of the whiteboard application. It defines some 
#      utilities for keeping the user preferences. 
#      
#  Copyright (c) 1999-2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: PreferencesUtils.tcl,v 1.2 2003-01-30 17:34:03 matben Exp $
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

    namespace export PreferencesInit PreferencesAdd PreferencesSaveToFile  \
      PreferencesResetToFactoryDefaults PreferencesResetToUserDefaults 
    
    variable priNameToNum
    array set priNameToNum {0 0 20 20 40 40 60 60 80 80 100 100   \
      factoryDefault 20 appDefault 40 userDefault 60 interactive 80 \
      absolute 100}
}

# PreferencesUtils::PreferencesInit --
# 
#       Reads the preference file into the internal option database.
#       Use pre 0.94.2 prefs file as a fallback.
#
# Arguments:
#                        
# Results:
#       updates the internal option database.

proc ::PreferencesUtils::PreferencesInit { } {
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

# PreferencesUtils::PreferencesAdd --
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

proc ::PreferencesUtils::PreferencesAdd {thePrefs} {
    global  prefs
    
    variable priNameToNum

    set isOldPrefFile 0
    foreach item $thePrefs {
	set varName [lindex $item 0]
	set resourceName [lindex $item 1]
	set defaultValue [lindex $item 2]
	
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
	    set value [PreferencesGetValue $varName $resourceName $defaultValue]
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

# PreferencesUtils::PreferencesGetValue --
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

proc ::PreferencesUtils::PreferencesGetValue {varName resourceName defValue} {
    upvar #0 varName theVar
    
    set theVar [option get . $resourceName {}]
    
    # If not there {} then take the itsHardCodedDefaultValue.
    if {$theVar == {}} {
	set theVar $defValue
    }
    return $theVar
}
  
# PreferencesUtils::PreferencesSaveToFile --
# 
#       Saves the preferences to a file. Preferences must be stored in
#       the master copy 'prefs(master)' in the corresponding list format.
#
# Arguments:
#       
# Results:
#       preference file written. 

proc ::PreferencesUtils::PreferencesSaveToFile { } {
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
    if {$this(platform) == "macintosh"} {
	file attributes $prefs(userPrefsFilePath) -type pref
    }
}

# PreferencesUtils::PreferencesResetToFactoryDefaults --
# 
#       Resets the preferences in 'prefs(master)' to their hardcoded values.
#
# Arguments:
#       maxPriority 0 20 40 60 80 100, or equivalent description.
#                   Pick only values with lower priority than maxPriority.
#       
# Results:
#       prefs values may change, and user interface stuff updated. 

proc ::PreferencesUtils::PreferencesResetToFactoryDefaults {maxPriority} {
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

# PreferencesUtils::PreferencesResetToUserDefaults --
# 
#       Resets the applications state to correspond to the existing
#       preference file.
#
# Arguments:
#       
# Results:
#       prefs values may change, and user interface stuff updated. 

proc ::PreferencesUtils::PreferencesResetToUserDefaults { } {
    global  prefs
	
    # Need to make a temporary storage in order not to duplicate items.
    set thePrefs $prefs(master)
    set prefs(master) {}
    
    # Read the user option database file once again.
    PreferencesInit
    PreferencesAdd $thePrefs
}

# PreferencesUtils::SetWidgetDefaultOptions --
#
#       Set defaults in the option database for widget classes.
#       First, on all platforms...

proc ::PreferencesUtils::SetWidgetDefaultOptions { } {
    global  prefs sysFont this
    
    option add *Canvas.Background $prefs(bgColGeneral)
    option add *Checkbutton.Font $sysFont(s)
    option add *Frame.Background $prefs(bgColGeneral)
    option add *Label.Background $prefs(bgColGeneral)
    option add *Label.Font $sysFont(s)
    option add *Message.Background $prefs(bgColGeneral)
    option add *Progressbar.Background $prefs(bgColGeneral)
    option add *Entry.Background white
    option add *Entry.BorderWidth 1
    option add *Entry.Font $sysFont(s)
    option add *Entry.HighlightColor #6363CE
    option add *Entry.HighlightBackground $prefs(bgColGeneral)
    option add *Entry.DisableBackground $prefs(bgColGeneral)
    option add *Listbox.HighlightColor #6363CE
    option add *Listbox.HighlightBackground $prefs(bgColGeneral)
    option add *Radiobutton.Font $sysFont(s)
    option add *Text.Background white
    option add *Text.HighlightColor #6363CE
    option add *Text.HighlightBackground $prefs(bgColGeneral)
    option add *Tablelist.HighlightThickness 3
    option add *Tablelist.HighlightColor #6363CE
    option add *Tablelist.HighlightBackground $prefs(bgColGeneral)
    
    # ...and then on specific platforms.
    
    switch -- $this(platform) {
	"macintosh" - "macosx" {
	    option add *Radiobutton.Background $prefs(bgColGeneral)
	    option add *Button.HighlightBackground $prefs(bgColGeneral)
	    option add *Checkbutton.Background $prefs(bgColGeneral)
	    option add *Entry.HighlightThickness 3
	    option add *Listbox.Font $sysFont(m)
	    option add *Listbox.HighlightThickness 3
	    option add *Text.HighlightThickness 3
	    option add *Tablelist.BorderWidth 1
	}
	"windows" {
	    option add *Radiobutton.Background $prefs(bgColGeneral)
	    option add *Button.Background $prefs(bgColGeneral)
	    option add *Checkbutton.Background $prefs(bgColGeneral)
	    option add *Entry.HighlightThickness 2
	    option add *Listbox.Background white
	    option add *Listbox.Font $sysFont(m)
	    option add *Listbox.HighlightThickness 2
	    option add *Text.HighlightThickness 2
	}
	"unix" {
	    option add *Entry.HighlightThickness 2
	    option add *Listbox.HighlightThickness 2
	    option add *Listbox.BorderWidth 1
	    option add *Text.HighlightThickness 2
	    option add *Scrollbar.BorderWidth 1
	    option add *Scrollbar.Width 12
	    option add *Scrollbar*troughColor #bdbdbd
	    option add *Tablelist.BorderWidth 1
	}
    }
}


# PreferencesUtils::SetUserPreferences --
#
#       Set defaults in the option database for widget classes.
#       First, on all platforms...

# Set the user preferences from the preferences file if they are there,
# else take the hardcoded defaults.
# 'thePrefs': a list of lists where each sublist defines an item in the
# following way:  {theVarName itsResourceName itsHardCodedDefaultValue
#                 {thePriority 20}}.
# Note: it may prove useful to have the versions numbers as the first elements!

proc ::PreferencesUtils::SetUserPreferences { } {
    global  prefs dims state mime2Description mimeTypeIsText mime2SuffixList \
      mimeTypeDoWhat
    
    ::PreferencesUtils::PreferencesAdd [list  \
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
      [list state(splinesteps)     state_splinesteps     $state(splinesteps)]    \
      [list state(dash)            state_dash            $state(dash)]           \
      [list state(canGridOn)       state_canGridOn       $state(canGridOn)]      \
      [list state(visToolbar)      state_visToolbar      $state(visToolbar)]  ]
    
    # All MIME type stuff... The problem is that they are all arrays... 
    # Invented the ..._array resource specifier!
    
    PreferencesAdd [list  \
      [list mime2Description       mime2Description_array        [array get mime2Description]]   \
      [list mimeTypeIsText         mimeTypeIsText_array          [array get mimeTypeIsText]]     \
      [list mime2SuffixList        mime2SuffixList_array         [array get mime2SuffixList]]    \
      [list mimeTypeDoWhat         mimeTypeDoWhat_array          [array get mimeTypeDoWhat]] ]
    
    # And continue with the jabber preferences... 
    
    set ver $prefs(fullVers)
    if {!$prefs(stripJabber)} {
	PreferencesAdd [list  \
	  [list ::Jabber::jprefs(port)             jprefs_port              $::Jabber::jprefs(port)]  \
	  [list ::Jabber::jprefs(sslport)          jprefs_sslport           $::Jabber::jprefs(sslport)]  \
	  [list ::Jabber::jprefs(rost,clrLogout)   jprefs_rost_clrRostWhenOut $::Jabber::jprefs(rost,clrLogout)]  \
	  [list ::Jabber::jprefs(rost,dblClk)      jprefs_rost_dblClk       $::Jabber::jprefs(rost,dblClk)]  \
	  [list ::Jabber::jprefs(rost,rmIfUnsub)   jprefs_rost_rmIfUnsub    $::Jabber::jprefs(rost,rmIfUnsub)]  \
	  [list ::Jabber::jprefs(rost,allowSubNone) jprefs_rost_allowSubNone $::Jabber::jprefs(rost,allowSubNone)]  \
	  [list ::Jabber::jprefs(subsc,inrost)     jprefs_subsc_inrost      $::Jabber::jprefs(subsc,inrost)]  \
	  [list ::Jabber::jprefs(subsc,notinrost)  jprefs_subsc_notinrost   $::Jabber::jprefs(subsc,notinrost)]  \
	  [list ::Jabber::jprefs(subsc,auto)       jprefs_subsc_auto        $::Jabber::jprefs(subsc,auto)]  \
	  [list ::Jabber::jprefs(subsc,group)      jprefs_subsc_group       $::Jabber::jprefs(subsc,group)]  \
	  [list ::Jabber::jprefs(block,notinrost)  jprefs_block_notinrost   $::Jabber::jprefs(block,notinrost)]  \
	  [list ::Jabber::jprefs(block,list)       jprefs_block_list        $::Jabber::jprefs(block,list)    userDefault] \
	  [list ::Jabber::jprefs(speakMsg)         jprefs_speakMsg          $::Jabber::jprefs(speakMsg)]  \
	  [list ::Jabber::jprefs(speakChat)        jprefs_speakChat         $::Jabber::jprefs(speakChat)]  \
	  [list ::Jabber::jprefs(snd,newmsg)       jprefs_snd_newmsg        $::Jabber::jprefs(snd,newmsg)]  \
	  [list ::Jabber::jprefs(snd,online)       jprefs_snd_online        $::Jabber::jprefs(snd,online)]  \
	  [list ::Jabber::jprefs(snd,offline)      jprefs_snd_offline       $::Jabber::jprefs(snd,offline)]  \
	  [list ::Jabber::jprefs(snd,statchange)   jprefs_snd_statchange    $::Jabber::jprefs(snd,statchange)]  \
	  [list ::Jabber::jprefs(agentsOrBrowse)   jprefs_agentsOrBrowse    $::Jabber::jprefs(agentsOrBrowse)]  \
	  [list ::Jabber::jprefs(agentsServers)    jprefs_agentsServers     $::Jabber::jprefs(agentsServers)]  \
	  [list ::Jabber::jprefs(browseServers)    jprefs_browseServers     $::Jabber::jprefs(browseServers)]  \
	  [list ::Jabber::jprefs(showMsgNewWin)    jprefs_showMsgNewWin     $::Jabber::jprefs(showMsgNewWin)]  \
	  [list ::Jabber::jprefs(inbox2click)      jprefs_inbox2click       $::Jabber::jprefs(inbox2click)]  \
	  [list ::Jabber::jprefs(inboxSave)        jprefs_inboxSave         $::Jabber::jprefs(inboxSave)]  \
	  [list ::Jabber::jprefs(autoaway)         jprefs_autoaway          $::Jabber::jprefs(autoaway)]  \
	  [list ::Jabber::jprefs(xautoaway)        jprefs_xautoaway         $::Jabber::jprefs(xautoaway)]  \
	  [list ::Jabber::jprefs(awaymin)          jprefs_awaymin           $::Jabber::jprefs(awaymin)]  \
	  [list ::Jabber::jprefs(xawaymin)         jprefs_xawaymin          $::Jabber::jprefs(xawaymin)]  \
	  [list ::Jabber::jprefs(awaymsg)          jprefs_awaymsg           $::Jabber::jprefs(awaymsg)]  \
	  [list ::Jabber::jprefs(xawaymsg)         jprefs_xawaymsg          $::Jabber::jprefs(xawaymsg)]  \
	  [list ::Jabber::jprefs(logoutStatus)     jprefs_logoutStatus      $::Jabber::jprefs(logoutStatus)]  \
	  [list ::Jabber::jprefs(chatFont)         jprefs_chatFont          $::Jabber::jprefs(chatFont)]  \
	  [list ::Jabber::jprefs(autoupdateCheck)  jprefs_autoupdateCheck   $::Jabber::jprefs(autoupdateCheck)]  \
	  [list ::Jabber::jprefs(autoupdateShow,$ver) jprefs_autoupdateShow_ver $::Jabber::jprefs(autoupdateShow,$ver)]  \
	  [list ::Jabber::jstate(rostBrowseVis)    jstate_rostBrowseVis     $::Jabber::jstate(rostBrowseVis) userDefault] \
	  [list ::Jabber::jserver(profile)         jserver_profile          $::Jabber::jserver(profile)      userDefault] \
	  [list ::Jabber::jserver(profile,selected) jserver_profile_selected $::Jabber::jserver(profile,selected) userDefault] \
	  ]
	
	# Personal info corresponding to the iq:register namespace.
	
	set jprefsRegList {}
	foreach key $::Jabber::jprefs(iqRegisterElem) {
	    lappend jprefsRegList [list  \
	      ::Jabber::jprefs(iq:register,$key) jprefs_iq_register_$key   \
	      $::Jabber::jprefs(iq:register,$key) userDefault]
	}
	::PreferencesUtils::PreferencesAdd $jprefsRegList
    }
    
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
#       Process command line options. Some systems (MacOSX) add their own
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
