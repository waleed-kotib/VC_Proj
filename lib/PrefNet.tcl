#  PrefNet.tcl ---
#  
#       This file is part of The Coccinella application. 
#       It implements network prefs dialogs and panel.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: PrefNet.tcl,v 1.2 2005-10-22 14:26:21 matben Exp $
 
package provide PrefNet 1.0

namespace eval ::PrefNet:: {

    ::hooks::register prefsInitHook          ::PrefNet::InitPrefsHook  20
    ::hooks::register prefsBuildHook         ::PrefNet::BuildPrefsHook 20
    ::hooks::register prefsSaveHook          ::PrefNet::SavePrefsHook  20
    ::hooks::register prefsCancelHook        ::PrefNet::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::PrefNet::UserDefaultsHook
    ::hooks::register prefsDestroyHook       ::PrefNet::DestroyPrefsHook

    variable opts
    set opts(main) {protocol autoConnect multiConnect}
}

proc ::PrefNet::InitPrefsHook { } {
    global  prefs
    
    # Connect automatically to connecting clients if 'symmetricNet'.
    set prefs(autoConnect) 1                
    
    # Disconnect automatically to disconnecting clients.
    set prefs(autoDisconnect) $prefs(autoConnect)	
    
    # When connecting to other client, connect automatically to all *its* clients.
    set prefs(multiConnect) 1
    
    ::PrefUtils::Add [list  \
      [list prefs(protocol)        prefs_protocol        $prefs(protocol)]       \
      [list prefs(autoConnect)     prefs_autoConnect     $prefs(autoConnect)]    \
      [list prefs(multiConnect)    prefs_multiConnect    $prefs(multiConnect)]   \
      [list prefs(thisServPort)    prefs_thisServPort    $prefs(thisServPort)]   \
      [list prefs(httpdPort)       prefs_httpdPort       $prefs(httpdPort)]      \
      ]    
}

proc ::PrefNet::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {General {Network Setup}} [mc {Network Setup}]
    set wpage [$nbframe page {Network Setup}]
    BuildPage $wpage
}

proc ::PrefNet::SavePrefsHook { } {
    global prefs wDlgs
    variable tmpPrefs
    
    set protocolSet 0
	
    # Was protocol changed?
    if {![string equal $prefs(protocol) $tmpPrefs(protocol)]} {	
	set ans [::UI::MessageBox -title Relaunch -icon info -type yesno \
	  -message [mc messprotocolch] -parent $wDlgs(prefs)]
	if {$ans eq "no"} {
	    set finished 1
	    return stop
	} else {
	    set protocolSet 1
	}
    }
    
    if {$protocolSet} {

	switch -- $tmpPrefs(protocol) {
	    jabber {
		package require Jabber
	    }
	    symmetric - server - client {
		package require P2P
		package require P2PNet
	    }
	}
    }
    
    array set prefs [array get tmpPrefs]
}

proc ::PrefNet::CancelPrefsHook { } {
    global prefs
    variable tmpPrefs
	
    foreach key [array names tmpPrefs] {
	if {![string equal $prefs($key) $tmpPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::PrefNet::UserDefaultsHook { } {
    global prefs
    variable tmpPrefs
    
    foreach key [array names tmpPrefs] {
	set tmpPrefs($key) $prefs($key)
    }
}

proc ::PrefNet::DestroyPrefsHook { } {
    variable tmpPrefs
    
    unset -nocomplain tmpPrefs
}
    
proc ::PrefNet::BuildPage {page} {
    global  prefs this state

    variable wfr
    variable tmpPrefs
    variable opts
    
    foreach key $opts(main) {
	set tmpPrefs($key) $prefs($key)
    }
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set wfr $wc.f
    ttk::labelframe $wfr -text [mc prefnetconf] \
      -padding [option get . groupSmallPadding {}]

    ttk::label $wfr.msg -wraplength 200 -justify left \
      -padding {0 0 0 8} -text [mc prefnethead]
    pack $wfr.msg -side top
	    
    # The Jabber server.
    ttk::radiobutton $wfr.jabb -text [mc {Jabber Client}]  \
      -value jabber -variable [namespace current]::tmpPrefs(protocol)
    ttk::label $wfr.jabbmsg -wraplength 200 -justify left  \
      -text [mc prefnetjabb]
    
    # For the symmetric network config.
    ttk::radiobutton $wfr.symm -text [mc {Peer-to-Peer}]  \
      -variable [namespace current]::tmpPrefs(protocol) -value symmetric
    ttk::checkbutton $wfr.auto -text [mc {Auto Connect}]  \
      -variable [namespace current]::tmpPrefs(autoConnect)
    ttk::label $wfr.automsg -wraplength 200 -justify left  \
      -text [mc prefnetauto]
    ttk::checkbutton $wfr.multi -text [mc {Multi Connect}]  \
      -variable [namespace current]::tmpPrefs(multiConnect)
    ttk::label $wfr.multimsg -wraplength 200 -justify left  \
      -text [mc prefnetmulti]
    ttk::button $wfr.adv -text "[mc Advanced]..." \
      -command [list ::PrefNet::Advanced]
    
    grid  $wfr.msg    -              -sticky w
    grid  $wfr.jabb   $wfr.jabbmsg   -sticky nw
    grid  $wfr.symm   $wfr.auto      -sticky w
    grid  x           $wfr.automsg   -sticky w
    grid  x           $wfr.multi     -sticky w
    grid  x           $wfr.multimsg  -sticky w
    grid  $wfr.adv    -              -sticky w
    
    pack  $wfr  -fill x

    if {![string equal $prefs(protocol) "symmetric"]} { 
	$wfr.auto  state {disabled}
	$wfr.multi state {disabled}
    }    

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
	$wfr.jabb state {disabled}
	$wfr.symm state {disabled}
    }
    if {($prefs(protocol) eq "server") || ($prefs(protocol) eq "client")} {
	$wfr.jabb state {disabled}
	$wfr.symm state {disabled}
    }
    
    trace variable [namespace current]::tmpPrefs(protocol) w  \
      [namespace current]::TraceNetConfig
    
    bind $page <Destroy> [namespace current]::Free
	
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wfr.msg $page]    
    after idle $script
}

# ::PrefNet::TraceNetConfig --
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

proc ::PrefNet::TraceNetConfig {name index op} {
    
    variable wfr
    variable tmpPrefs
    
    Debug 2 "::PrefNet::TraceNetConfig"

    switch -- $tmpPrefs(protocol) {
	symmetric {
	    $wfr.auto  state {!disabled}
	    $wfr.multi state {!disabled}
	}
	central {
	    $wfr.auto  state {disabled}
	    $wfr.multi state {disabled}
	}
	jabber {
	    $wfr.auto  state {disabled}
	    $wfr.multi state {disabled}
	}
    }
}

# ::PrefNet::UpdateUI --
#
#       If network setup changed be sure to update the UI to reflect this.
#       Must be called after saving in 'prefs' etc.
#       
# Arguments:
#       
# Results:
#       .

proc ::PrefNet::UpdateUI { } {
    global  prefs state wDlgs
    
    Debug 2 "::PrefNet::UpdateUI"
    
    set wmenu [::UI::GetMainMenu]
    
    # Update menus.
    switch -- $prefs(protocol) {
	jabber {
	    
	    # Show our combination window.
	    ::Jabber::UI::Show $wDlgs(jmain)
	}
	central {
	    
	    # We are only a client.
	    ::UI::MenuMethod $wmenu.file entryconfigure mOpenConnection  \
	      -command [list ::P2PNet::OpenConnection $wDlgs(openConn)]
	    $wmenu entryconfigure *Jabber* -state disabled
	    
	    # Hide our combination window.
	    ::Jabber::UI::Close $wDlgs(jmain)
	}
	default {
	    ::UI::MenuMethod $wmenu.file entryconfigure mOpenConnection   \
	      -command [list ::P2PNet::OpenConnection $wDlgs(openConn)]
	    $wmenu entryconfigure *Jabber* -state disabled
		
	    # Hide our combination window.
	    ::Jabber::UI::Close $wDlgs(jmain)
	}
    }
    
    # Other UI updates needed.
    foreach w [::WB::GetAllWhiteboards] {
	# ???
    }
}

# Preferences::Net::Advanced --
#
#       Shows dialog for setting the "advanced" network options.
#       
# Arguments:
#       
# Results:
#       shows dialog.

proc ::PrefNet::Advanced {  } {
    global  this prefs

    variable finishedAdv -1
    variable tmpAdvPrefs
    upvar ::Jabber::jprefs jprefs
    
    set tmpAdvPrefs(thisServPort)      $prefs(thisServPort)
    set tmpAdvPrefs(httpdPort)         $prefs(httpdPort)
    set tmpAdvPrefs(bytestreams,port)  $jprefs(bytestreams,port)

    set w .dlgAdvNet
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [mc {Advanced Setup}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 320 -justify left -text [mc prefnetadv]
    pack $wbox.msg -side top -anchor w
    
    # The actual options.
    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.lserv -text "[mc {Built in server port}]:"
    ttk::label $frmid.lhttp -text "[mc {HTTP port}]:"
    ttk::label $frmid.lbs   -text "[mc {Filetransfer (bytestreams) port}]:"
    ttk::entry $frmid.eserv -width 6 -textvariable  \
      [namespace current]::tmpAdvPrefs(thisServPort)
    ttk::entry $frmid.ehttp -width 6 -textvariable  \
      [namespace current]::tmpAdvPrefs(httpdPort)
    ttk::entry $frmid.ebs -width 6 -textvariable  \
      [namespace current]::tmpAdvPrefs(bytestreams,port)

    grid  $frmid.lserv  $frmid.eserv  -sticky e -pady 2
    grid  $frmid.lhttp  $frmid.ehttp  -sticky e -pady 2
    grid  $frmid.lbs    $frmid.ebs    -sticky e -pady 2
    
    if {!$prefs(haveHttpd)} {
	$frmid.ehttp state {disabled}
    }
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Save] -default active \
      -command [namespace current]::AdvSetupSave
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list set [namespace current]::finishedAdv 0]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side top -fill x

    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    # Grab and focus.
    focus $w
    catch {grab $w}    
    tkwait variable [namespace current]::finishedAdv
    
    # Clean up.
    unset -nocomplain finishedAdv
    catch {grab release $w}
    destroy $w
}
    
# ::PrefNet::AdvSetupSave --
#
#       Saves the values set in dialog in the preference variables.
#       It saves these port numbers independently of the main panel!!!
#       Is this the right thing to do???
#       
# Arguments:
#       
# Results:
#       none.

proc ::PrefNet::AdvSetupSave { } {
    global  prefs
    
    variable finishedAdv
    variable tmpAdvPrefs
    upvar ::Jabber::jprefs jprefs

    set prefs(thisServPort)      $tmpAdvPrefs(thisServPort)
    set prefs(httpdPort)         $tmpAdvPrefs(httpdPort)
    set jprefs(bytestreams,port) $tmpAdvPrefs(bytestreams,port)
    
    set finishedAdv 1
}

proc ::PrefNet::Free { } {
    
    # Clean up.
    trace vdelete [namespace current]::tmpPrefs(protocol) w  \
      [namespace current]::TraceNetConfig
}

#-------------------------------------------------------------------------------
