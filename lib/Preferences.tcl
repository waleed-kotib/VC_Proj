#  Preferences.tcl ---
#  
#       This file is part of The Coccinella application. It implements the
#       preferences dialog window.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Preferences.tcl,v 1.53 2004-06-30 08:52:40 matben Exp $
 
package require notebook
package require tree
package require tablelist
package require combobox

package provide Preferences 1.0

namespace eval ::Preferences:: {
    global  wDlgs this
    
    # Variable to be used in tkwait.
    variable finished
        
    # Name of the page that was in front last time.
    variable lastPage {}

    # Add all event hooks.
    ::hooks::add quitAppHook     [list ::UI::SaveWinGeom $wDlgs(prefs)]
    ::hooks::add closeWindowHook ::Preferences::CloseHook

    variable xpadbt
    variable ypad 
    variable ypadtiny
    variable ypadbig
    
    # Unfortunately it is necessary to do some platform specific things to
    # get the pages to look nice.

    switch -glob -- $this(platform) {
	macintosh {
	    set ypadtiny 1
	    set ypad     3
	    set ypadbig  4
	    set xpadbt   7
	}
	macosx {
	    set ypadtiny 0
	    set ypad     0
	    set ypadbig  1
	    set xpadbt   7
	}
	windows {
	    set ypadtiny 0
	    set ypad     0
	    set ypadbig  1
	    set xpadbt   4
	}
	default {
	    set ypadtiny 0
	    set ypad     1
	    set ypadbig  2
	    set xpadbt   2
	}
    }    
    option add *Preferences.xPadBt              $xpadbt       widgetDefault
    option add *Preferences.yPadTiny            $ypadtiny     widgetDefault
    option add *Preferences.yPad                $ypad         widgetDefault
    option add *Preferences.yPadBig             $ypadbig      widgetDefault
}

proc ::Preferences::Build {args} {
    global  this prefs wDlgs
    
    variable tmpPrefs
    variable tmpJPrefs
    
    variable wtoplevel
    variable wtree
    variable finished
    variable nbframe
    variable lastPage
    
    array set argsArr $args

    set w $wDlgs(prefs)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -class Preferences -usemacmainmenu 1  \
      -macstyle documentProc -macclass {document closeBox}
    wm title $w [::msgcat::mc Preferences]
    wm withdraw $w
    
    set finished 0
    set wtoplevel $w
        
    # Work only on a temporary copy in case we cancel.
    catch {unset tmpPrefs}
    catch {unset tmpJPrefs}
    array set tmpPrefs [array get prefs]
    array set tmpJPrefs [::Jabber::GetjprefsArray]
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Frame for everything except the buttons.
    pack [frame $w.frall.fr] -fill both -expand 1 -side top
    
    # Tree frame with scrollbars.
    pack [frame $w.frall.fr.t -relief sunken -bd 1]   \
      -fill y -side left -padx 4 -pady 4
    set frtree $w.frall.fr.t.frtree
    pack [frame $frtree] -fill both -expand 1 -side left
    
    # Set a width in the label to act as a spacer when scrollbar is unpacked.
    pack [label $frtree.la -text [::msgcat::mc {Settings Panels}]  \
      -font $fontSB -relief raised -width 24 -bd 1 -bg #bdbdbd] -side top -fill x
    set wtree $frtree.t
    ::tree::tree $wtree -width 100 -height 300 \
      -yscrollcommand [list ::UI::ScrollSet $frtree.sby \
      [list pack $frtree.sby -side right -fill y]]  \
      -selectcommand ::Preferences::SelectCmd   \
      -doubleclickcommand {}
    scrollbar $frtree.sby -orient vertical -command [list $wtree yview]
    
    pack $wtree -side left -fill both -expand 1
    pack $frtree.sby -side right -fill y
    
    # Fill tree.
    $wtree newitem {General} -text [::msgcat::mc General]
    $wtree newitem {General {Network Setup}} -text [::msgcat::mc {Network Setup}]
    $wtree newitem {General {Proxy Setup}} -text [::msgcat::mc {Proxy Setup}]
    if {!$prefs(stripJabber)} {
	$wtree newitem {Jabber}
    }
    $wtree newitem {Whiteboard} -text [::msgcat::mc Whiteboard]
    
    # The notebook and its pages.
    set nbframe [notebook::notebook $w.frall.fr.nb -borderwidth 1 -relief sunken]
    pack $nbframe -expand 1 -fill both -padx 4 -pady 4
    
    # Make the notebook pages.
    
    # Network Setup page -------------------------------------------------------
    set frpnet [$nbframe page {Network Setup}]
    ::Preferences::NetSetup::BuildPage $frpnet
    
    # Proxies Setup page -------------------------------------------------------
    set frpoxy [$nbframe page {Proxy Setup}]
    ::Preferences::Proxies::BuildPage $frpoxy
    
    # Each code component makes its own page.
    ::hooks::run prefsBuildHook $wtree $nbframe
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [::msgcat::mc Save] -default active \
      -command ::Preferences::SavePushBt]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command ::Preferences::CancelPushBt]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btfactory -text [::msgcat::mc {Factory Settings}]   \
      -command [list ::Preferences::ResetToFactoryDefaults "40"]]  \
      -side left -padx 5 -pady 5
    pack [button $frbot.btrevert -text [::msgcat::mc {Revert Panel}]  \
      -command ::Preferences::ResetToUserDefaults]  \
      -side left -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6

    ::UI::SetWindowPosition $w
    wm resizable $w 0 0
    bind $w <Return> {}
    
    # Which page to be in front?
    if {[info exists argsArr(-page)]} {
	$wtree setselection $argsArr(-page)
    } elseif {[llength $lastPage]} {
	$wtree setselection $lastPage
    }    
    wm deiconify $w
    
    # Grab and focus.
    focus $w
}

# Preferences::ResetToFactoryDefaults --
#
#       Takes all prefs that is in the master list, and sets all
#       our tmp variables identical to their default (hardcoded) values.
#       All MIME settings are excluded.
#
# Arguments:
#       maxPriority 0 20 40 60 80 100, or equivalent description.
#                   Pick only values with lower priority than maxPriority.
#       
# Results:
#       none. 

proc ::Preferences::ResetToFactoryDefaults {maxPriorityNum} {
    global  prefs
    
    variable tmpPrefs
    variable tmpJPrefs

    Debug 2 "::Preferences::ResetToFactoryDefaults maxPriorityNum=$maxPriorityNum"
    
    # Warn first.
    set ans [tk_messageBox -title [::msgcat::mc Warning] -type yesno -icon warning \
      -message [FormatTextForMessageBox [::msgcat::mc messfactorydefaults]] \
      -default no]
    if {$ans == "no"} {
	return
    }
    foreach item $prefs(master) {
	set varName [lindex $item 0]
	set resourceName [lindex $item 1]
	set defaultValue [lindex $item 2]
	set varPriority [lindex $item 3]
	if {$varPriority < $maxPriorityNum} {
	
	    # Set only tmp variables. Find the corresponding tmp variable.
	    if {[regsub "^prefs" $varName tmpPrefs tmpVarName]} {
	    } elseif {[regsub "^::Jabber::jprefs" $varName tmpJPrefs tmpVarName]} {
	    } else {
		continue
	    }
	    #puts "varName=$varName, tmpVarName=$tmpVarName"
	    
	    # Treat arrays specially.
	    if {[string match "*_array" $resourceName]} {
		array set $tmpVarName $defaultValue
	    } else {
		set $tmpVarName $defaultValue
	    }
	}
    }
}

# Preferences::ResetToUserDefaults --
#
#       Revert panels to the state when dialog showed.

proc ::Preferences::ResetToUserDefaults { } {
    global  prefs
    
    variable tmpPrefs
    variable tmpJPrefs

    Debug 2 "::Preferences::ResetToUserDefaults"

    array set tmpPrefs [array get prefs]
    array set tmpJPrefs [::Jabber::GetjprefsArray]

    # Run hook for the components.
    ::hooks::run prefsUserDefaultsHook
}

# namespace  ::Preferences::NetSetup:: -----------------------------------------

namespace eval ::Preferences::NetSetup:: {

}
    
proc ::Preferences::NetSetup::BuildPage {page} {
    global  prefs this state

    variable wopt

    upvar ::Preferences::ypadtiny ypadtiny
    upvar ::Preferences::ypadbig ypadbig
    
    set fontSB [option get . fontSmallBold {}]
        
    set wcont $page.fr
    labelframe $wcont -text [::msgcat::mc prefnetconf]
    pack $wcont -side top -anchor w -padx 8 -pady 4

    # Frame for everything inside the labeled container.
    set fr [frame $wcont.fr]    
    pack $fr -side left -padx 2    
    label $fr.msg -wraplength 200 -justify left \
      -text [::msgcat::mc prefnethead]
    pack $fr.msg -side top -padx 2 -anchor w -pady $ypadbig
    
    # The actual options.
    set fropt [frame $fr.fropt]
    set wopt $fropt
        
    # The Jabber server.
    radiobutton $fropt.jabb -text [::msgcat::mc {Jabber Client}]  \
      -value jabber -variable ::Preferences::tmpPrefs(protocol)
    label $fropt.jabbmsg -wraplength 200 -justify left  \
      -text [::msgcat::mc prefnetjabb]
    
    # For the symmetric network config.
    radiobutton $fropt.symm -text [::msgcat::mc {Peer-to-Peer}]  \
      -variable ::Preferences::tmpPrefs(protocol) -value symmetric
    checkbutton $fropt.auto -text "  [::msgcat::mc {Auto Connect}]"  \
      -variable ::Preferences::tmpPrefs(autoConnect)
    label $fropt.automsg -wraplength 200 -justify left  \
      -text [::msgcat::mc prefnetauto]
    checkbutton $fropt.multi -text "  [::msgcat::mc {Multi Connect}]"  \
      -variable ::Preferences::tmpPrefs(multiConnect)
    label $fropt.multimsg -wraplength 200 -justify left  \
      -text [::msgcat::mc prefnetmulti]
    if {![string equal $prefs(protocol) "symmetric"]} { 
	$fropt.auto configure -state disabled
	$fropt.multi configure -state disabled
    }    
    
    button $fropt.adv -text "[::msgcat::mc Advanced]..." -command  \
      [list ::Preferences::NetSetup::Advanced]
    
    # If already connected don't allow network topology to be changed.
    
    switch -- $prefs(protocol) {
	jabber {
	    set connected [::Jabber::IsConnected]
	}
	default {
	    set connected [llength [::P2PNet::GetIP to]]
	}
    }
    if {$connected} {
	$fropt.jabb configure -state disabled
	$fropt.symm configure -state disabled
    }
    if {$prefs(stripJabber) ||  \
      ($prefs(protocol) == "server") || ($prefs(protocol) == "client")} {
	$fropt.jabb configure -state disabled
	$fropt.symm configure -state disabled
    }
    grid $fropt.jabb -column 0 -row 0 -rowspan 4 -sticky nw -padx 10 -pady $ypadtiny
    grid $fropt.jabbmsg -column 1 -row 0 -sticky w -padx 10 -pady $ypadtiny
    grid $fropt.symm -column 0 -row 1 -rowspan 4 -sticky nw -padx 10 -pady $ypadtiny
    grid $fropt.auto -column 1 -row 1 -sticky w -padx 10 -pady $ypadtiny
    grid $fropt.automsg -column 1 -row 2 -sticky w -padx 10 -pady $ypadtiny
    grid $fropt.multi -column 1 -row 3 -sticky w -padx 10 -pady $ypadtiny
    grid $fropt.multimsg -column 1 -row 4 -sticky w -padx 10 -pady $ypadtiny
    grid $fropt.adv -column 0 -row 6 -sticky w -padx 10 -pady $ypadbig

    pack $fropt -side top -padx 5 -pady $ypadbig
    
    trace variable ::Preferences::tmpPrefs(protocol) w  \
      [namespace current]::TraceNetConfig
	
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $fr.msg $fr]    
    after idle $script
}

# ::Preferences::NetSetup::TraceNetConfig --
#
#       Trace command for the 'tmpPrefs(protocol)' variable that is
#       used for the network type radio buttons.
#       
# Arguments:
#       name   the toplevel window.
#       index  array index.
#       op     operation.
#       
# Results:
#       shows dialog.

proc ::Preferences::NetSetup::TraceNetConfig {name index op} {
    
    variable wopt
    upvar ::Preferences::tmpPrefs tmpPrefs
    
    Debug 2 "::Preferences::NetSetup::TraceNetConfig"

    set fropt $wopt
    if {$tmpPrefs(protocol) == {symmetric}} { 
	$fropt.auto configure -state normal
	$fropt.multi configure -state normal
    } elseif {$tmpPrefs(protocol) == {central}} {
	$fropt.auto configure -state disabled
	$fropt.multi configure -state disabled
    } elseif {$tmpPrefs(protocol) == {jabber}} {
	$fropt.auto configure -state disabled
	$fropt.multi configure -state disabled
    }
}

# ::Preferences::NetSetup::UpdateUI --
#
#       If network setup changed be sure to update the UI to reflect this.
#       Must be called after saving in 'prefs' etc.
#       
# Arguments:
#       
# Results:
#       .

proc ::Preferences::NetSetup::UpdateUI { } {
    global  prefs state wDlgs
    
    Debug 2 "::Preferences::NetSetup::UpdateUI"
    
    # Update menus.
    switch -- $prefs(protocol) {
	jabber {
	    
	    # Show our combination window.
	    ::Jabber::UI::Show $wDlgs(jrostbro)
	}
	central {
	    
	    # We are only a client.
	    ::UI::MenuMethod .menu.file entryconfigure mOpenConnection  \
	      -command [list ::P2PNet::OpenConnection $wDlgs(openConn)]
	    .menu entryconfigure *Jabber* -state disabled
	    
	    # Hide our combination window.
	    ::Jabber::UI::Close $wDlgs(jrostbro)
	}
	default {
	    ::UI::MenuMethod .menu.file entryconfigure mOpenConnection   \
	      -command [list ::P2PNet::OpenConnection $wDlgs(openConn)]
	    if {!$prefs(stripJabber)} {
		.menu entryconfigure *Jabber* -state disabled
		
		# Hide our combination window.
		::Jabber::UI::Close $wDlgs(jrostbro)
	    }
	}
    }
    
    # Other UI updates needed.
    foreach w [::WB::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]

    }
}

# Preferences::NetSetup::Advanced --
#
#       Shows dialog for setting the "advanced" network options.
#       
# Arguments:
#       
# Results:
#       shows dialog.

proc ::Preferences::NetSetup::Advanced {  } {
    global  this prefs

    variable finishedAdv -1
    
    set w .dlgAdvNet
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [::msgcat::mc {Advanced Setup}]
    
    set fontSB [option get . fontSmallBold {}]
    
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall
    set wcont $w.frtop
    labelframe $wcont -text [::msgcat::mc {Advanced Configuration}]
    pack $wcont -in $w.frall -side top -padx 8 -pady 4
    
    # Frame for everything inside the labeled container.
    set fr [frame $wcont.fr]
    message $fr.msg -width 260 -text [::msgcat::mc prefnetadv]
    
    # The actual options.
    set fropt [frame $fr.fropt]

    label $fropt.lserv -text "[::msgcat::mc {Built in server port}]:"  \
      -font $fontSB
    label $fropt.lhttp -text "[::msgcat::mc {HTTP port}]:" \
      -font $fontSB
    label $fropt.ljab -text "[::msgcat::mc {Jabber server port}]:"  \
      -font $fontSB
    entry $fropt.eserv -width 6 -textvariable  \
      ::Preferences::tmpPrefs(thisServPort)
    entry $fropt.ehttp -width 6 -textvariable  \
      ::Preferences::tmpPrefs(httpdPort)
    entry $fropt.ejab -width 6 -textvariable  \
      ::Preferences::tmpJPrefs(port)

    if {!$prefs(haveHttpd)} {
	$fropt.ehttp configure -state disabled
    }
    
    set py 0
    set px 2
    set row 0
    foreach wid {serv http jab} {
	grid $fropt.l$wid -column 0 -row $row -sticky e   \
	  -padx $px -pady $py
	grid $fropt.e$wid -column 1 -row $row -sticky w   \
	  -padx $px -pady $py
	incr row
    }
        
    pack $fr.msg -side top -padx 2 -pady 6
    pack $fropt -side top -padx 5 -pady 6
    pack $fr -side left -padx 2    
    pack $wcont -fill x    
    
    # Button part.
    pack [frame $w.frbot -borderwidth 0] -in $w.frall -fill both  \
      -padx 8 -pady 6 -side bottom
    pack [button $w.btok -text [::msgcat::mc Save] -default active \
      -command [namespace current]::AdvSetupSave]  \
      -in $w.frbot -side right -padx 5 -pady 5
    pack [button $w.btcancel -text [::msgcat::mc Cancel]  \
      -command "set [namespace current]::finishedAdv 0"]  \
      -in $w.frbot -side right -padx 5 -pady 5
    wm resizable $w 0 0
    bind $w <Return> "$w.btok invoke"
    
    # Grab and focus.
    focus $w
    catch {grab $w}    
    tkwait variable [namespace current]::finishedAdv
    
    # Clean up.
    catch {unset finishedAdv}
    catch {grab release $w}
    destroy $w
}
    
# ::Preferences::NetSetup::AdvSetupSave --
#
#       Saves the values set in dialog in the preference variables.
#       It saves these port numbers independently of the main panel!!!
#       Is this the right thing to do???
#       
# Arguments:
#       
# Results:
#       none.

proc ::Preferences::NetSetup::AdvSetupSave {  } {
    global  prefs
    
    variable finishedAdv
    upvar ::Preferences::tmpPrefs tmpPrefs
    upvar ::Preferences::tmpJPrefs tmpJPrefs
    upvar ::Jabber::jprefs jprefs

    set prefs(thisServPort) $tmpPrefs(thisServPort)
    set prefs(httpdPort) $tmpPrefs(httpdPort)
    set jprefs(port) $tmpJPrefs(port)

    set finishedAdv 1
}

# namespace  ::Preferences::Proxies:: ----------------------------------------
# 
#       This is supposed to provide proxy support etc. 

namespace eval ::Preferences::Proxies:: {
    
}

proc ::Preferences::Proxies::BuildPage {page} {
    
    upvar ::Preferences::ypad ypad
    
    set pcnat $page.nat
    labelframe $pcnat -text [::msgcat::mc {NAT Address}] -padx 4 -pady 2
    pack $pcnat -side top -anchor w -padx 12 -pady 4
    checkbutton $pcnat.cb -text "  [::msgcat::mc prefnatip]" \
      -variable [namespace current]::tmpPrefs(setNATip)
    entry $pcnat.eip -textvariable [namespace current]::tmpPrefs(NATip) \
      -width 32
    grid $pcnat.cb -sticky w -pady $ypad
    grid $pcnat.eip -sticky ew -pady $ypad
    
    set pca $page.fr
    labelframe $pca -text {Http Proxy} -padx 12 -pady 4
    pack $pca -side top -anchor w -padx 8 -pady 4

    label $pca.msg -wraplength 300 -justify left \
      -text "Usage of the Http proxy is determined\
      by each profile settings. File transfers wont work if you use Http proxy!"
    
    label $pca.lserv -text [::msgcat::mc {Proxy Server}]:
    entry $pca.eserv -textvariable [namespace current]::tmpPrefs(httpproxyserver)
    label $pca.lport -text [::msgcat::mc {Proxy Port}]:
    entry $pca.eport -textvariable [namespace current]::tmpPrefs(httpproxyport)
    label $pca.luser -text [::msgcat::mc Username]:
    entry $pca.euser -textvariable [namespace current]::tmpPrefs(httpproxyusername)
    label $pca.lpass -text [::msgcat::mc Password]:
    entry $pca.epass -textvariable [namespace current]::tmpPrefs(httpproxypassword)

    grid $pca.msg   -          -sticky w
    grid $pca.lserv $pca.eserv
    grid $pca.lport $pca.eport
    grid $pca.luser $pca.euser
    grid $pca.lpass $pca.epass
    grid $pca.lserv $pca.lport $pca.luser $pca.lpass -sticky e
    grid $pca.eserv $pca.eport $pca.euser $pca.epass -sticky ew
}

#-------------------------------------------------------------------------------

# Preferences::SavePushBt --
#
#       Saving all settings of panels to the applications state and
#       its preference file.

proc ::Preferences::SavePushBt { } {
    global  prefs
    
    variable wtoplevel
    variable finished
    variable tmpPrefs
    variable tmpJPrefs
    
    set protocolSet 0
    
    # Was protocol changed?
    if {![string equal $prefs(protocol) $tmpPrefs(protocol)]} {
	set ans [tk_messageBox -title Relaunch -icon info -type yesno \
	  -message [FormatTextForMessageBox [::msgcat::mc messprotocolch]]]
	if {$ans == "no"} {
	    set finished 1
	    return
	} else {
	    set protocolSet 1
	}
    }
    
    # Copy the temporary copy to the real variables.
    array set prefs [array get tmpPrefs]
    ::Jabber::SetjprefsArray [array get tmpJPrefs]
    
    # Let components store themselves.
    ::hooks::run prefsSaveHook
	
    # Save the preference file.
    ::PreferencesUtils::SaveToFile
    ::Preferences::CleanUp
    
    set finished 1
    destroy $wtoplevel
}

proc ::Preferences::CloseHook {wclose} {
    global  wDlgs
    
    set result ""
    if {[string equal $wclose $wDlgs(prefs)]} {
	set ans [::Preferences::CancelPushBt]
	if {$ans == "no"} {
	    set result stop
	  }
    }   
    return $result
}

# Preferences::CancelPushBt --
#
#       User presses the cancel button. Warn if anything changed.

proc ::Preferences::CancelPushBt { } {
    global  prefs wDlgs
    
    variable wtoplevel
    variable finished
    variable tmpPrefs
    variable tmpJPrefs
    variable hasChanged
    upvar ::Jabber::jprefs jprefs
    
    set ans yes
        
    # Check if anything changed, if so then warn.
    set hasChanged 0
    foreach {arrName tmpName} {
	prefs      tmpPrefs 
	jprefs     tmpJPrefs
    } {
	if {!$hasChanged} {
	    foreach key [array names $arrName] {		
		set locName ${arrName}($key)
		upvar 0 $locName arrVal 
		set locName ${tmpName}($key)
		upvar 0 $locName tmpVal 
		
		if {![info exists $tmpName]} {
		    ::Debug 3 "\tdiff: locName=$locName"
		    set hasChanged 1
		    break
		}
		if {![string equal $arrVal $tmpVal]} {
		    ::Debug 3 "\tdiff: locName=$locName,\n\tarrVal=$arrVal,\n\ttmpVal=$tmpVal"
		    set hasChanged 1
		    break
		}
	    }
	}
    }

    # Let the code components check for themselves.
    ::hooks::run prefsCancelHook
    
    if {$hasChanged} {
	set ans [tk_messageBox -title [::msgcat::mc Warning]  \
	  -type yesno -default no -parent $wDlgs(prefs) -icon warning \
	  -message [FormatTextForMessageBox [::msgcat::mc messprefschanged]]]
	if {$ans == "yes"} {
	    set finished 2
	}
    } else {
	set finished 2
    }
    if {$finished == 2} {
	::Preferences::CleanUp
	destroy $wtoplevel
    }
    return $ans
}

proc ::Preferences::CleanUp { } {
    variable wtoplevel
    variable wtree
    variable lastPage
    variable tmpPrefs
    
    # Which page to be in front next time?
    set lastPage [$wtree getselection]
    
    # Clean up.
    trace vdelete ::Preferences::tmpPrefs(protocol) w  \
      ::Preferences::NetSetup::TraceNetConfig

    ::UI::SaveWinGeom $wtoplevel
}

# Preferences::HasChanged --
# 
#       Used for components to tell us that something changed with their
#       internal preferences.

proc ::Preferences::HasChanged { } {
    variable hasChanged

    set hasChanged 1
    CallTrace 4
}

# Preferences::SelectCmd --
#
#       Callback when selecting item in tree.
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       new page displayed

proc ::Preferences::SelectCmd {w v} {

    variable nbframe

    if {[llength $v] && ([$w itemconfigure $v -dir] == 0)} {
	$nbframe displaypage [lindex $v end]
    }    
}

#-------------------------------------------------------------------------------