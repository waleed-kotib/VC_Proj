#  Multicast.tcl ---
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
# $Id: Multicast.tcl,v 1.7 2006-08-20 13:41:20 matben Exp $

package provide Multicast 1.0

namespace eval ::Multicast:: {
    
    variable uid 0
    variable txtvarEntMulticast
    variable selMulticastName
    variable finished
}

# Multicast::OpenMulticast --
#
#       Makes dialog to open streaming audio/video.
#   
# Arguments:
#       wcan        canvas widget
#       
# Results:
#       shows dialog.

proc ::Multicast::OpenMulticast {wcan} {
    global  prefs this wDlgs
    
    variable uid
    variable txtvarEntMulticast
    variable selMulticastName
    variable finished

    set finished -1
    set w $wDlgs(openMulti)[incr uid]
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [mc {Open Stream}]

    set shorts [lindex $prefs(shortsMulticastQT) 0]

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Labelled frame.
    set frtot $wbox.fr
    ttk::labelframe $frtot -padding [option get . groupSmallPadding {}] \
      -text [mc openquicktime]
    pack $frtot -side top -fill both
    
    ttk::label $frtot.lbltop -text [mc writeurl]
    eval {ttk::optionmenu $frtot.optm  \
      [namespace current]::selMulticastName} $shorts
    ttk::label $frtot.lblhttp -text {http://}
    ttk::entry $frtot.entip -width 40  \
      -textvariable [namespace current]::txtvarEntMulticast
    ttk::label $frtot.msg -style Small.TLabel \
      -wraplength 400 -justify left -text [mc openquicktimeurlmsg]

    grid  $frtot.lbltop   -             $frtot.optm  -padx 2 -pady 2 -sticky w
    grid  $frtot.lblhttp  $frtot.entip  -            -padx 2 -pady 2 -sticky e
    grid  $frtot.msg      -             -            -sticky ew
    
    grid  $frtot.optm  $frtot.entip  -sticky ew
    grid columnconfigure $frtot 1 -weight 1
        
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btconn -text [mc Open] -default active  \
      -command [list Multicast::OpenMulticastQTStream $wcan $frtot.entip]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list set [namespace current]::finished 0]
    ttk::button $frbot.btedit -text "[mc Edit]..."   \
      -command [list ::Multicast::DoAddOrEditQTMulticastShort edit $frtot.optm]
    ttk::button $frbot.btadd -text "[mc Add]..."   \
      -command [list ::Multicast::DoAddOrEditQTMulticastShort add $frtot.optm]
    set padx [option get . buttonPadX {}]
    pack  $frbot.btconn  -side right
    pack  $frbot.btcancel  -side right -padx $padx
    pack  $frbot.btedit  -side right
    pack  $frbot.btadd  -side right -padx $padx
    pack  $frbot  -side bottom -fill x
    
    wm resizable $w 0 0
    
    # Grab and focus.
    focus $w
    focus $frtot.entip
    bind $w <Return> "$frbot.btconn invoke"
    trace variable [namespace current]::selMulticastName w  \
      [namespace current]::TraceSelMulticastName
    catch {grab $w}
    tkwait variable [namespace current]::finished
    
    catch {grab release $w}
    destroy $w
    
    return $finished
}

# Multicast::DoAddOrEditQTMulticastShort --
#
#       Process the edit and add buttons. Makes call to 'AddOrEditShortcuts'.
#   
# Arguments:
#       what   "add" or "edit".
#       wOptMenu
#       
# Results:
#       .

proc ::Multicast::DoAddOrEditQTMulticastShort {what wOptMenu} {
    global  prefs
    
    variable selMulticastName
    
    if {[string equal $what "add"]} {
	
	# Use the standard edit shortcuts dialogs. (0: cancel, 1 added)
	set btAns [::EditShortcuts::AddOrEditShortcuts add   \
	  prefs(shortsMulticastQT) -1]
    } elseif {[string equal $what "edit"]} {
	set btAns [::EditShortcuts::EditShortcuts .edtstrm   \
	  prefs(shortsMulticastQT)]
    }
    
    # Update the option menu as a menubutton.
    # Destroying old one and make a new one was the easy way out.
    if {$btAns == 1} {
	set shorts [lindex $prefs(shortsMulticastQT) 0]
	set gridInfo [grid info $wOptMenu]
	destroy $wOptMenu
	set optMenu [eval {tk_optionMenu $wOptMenu   \
	  [namespace current]::selMulticastName} $shorts]
	$wOptMenu configure -highlightthickness 0 -foreground black
	eval {grid $wOptMenu} $gridInfo
    }
}

proc ::Multicast::TraceSelMulticastName {name junk1 junk2} {
    global  prefs
    upvar #0 $name locName
    
    variable txtvarEntMulticast
    
    set ind [lsearch [lindex $prefs(shortsMulticastQT) 0] $locName]
    set txtvarEntMulticast [lindex $prefs(shortsMulticastQT) 1 $ind]
}

# Multicast::OpenMulticastQTStream --
#
#       Initiates a separate download of the tiny SDR file with http.
#   
# Arguments:
#       wcan        canvas widget

proc ::Multicast::OpenMulticastQTStream {wcan wentry} {
    global  this prefs
    variable finished

    # Patterns.
    set proto_ {[^:]+}
    set domain_ {[A-Za-z0-9\-\_\.]+}
    set port_ {[0-9]+}
    set path_ {/.*}
    set url [$wentry get]
    
    # Add leading http:// if not there.
    if {![regexp -nocase "^http://.+" $url]} {
	set url "http://$url"
    }
    
    # Check and parse url.
    unset -nocomplain port
    if {![regexp -nocase "($proto_)://($domain_)(:($port_))?($path_)$"  \
      $url match protocol domain junk port path]} {
	::UI::MessageBox -message   \
	  "Inconsistent url=$url." -icon error -type ok
	set finished 0
	return
    }
    if {[string length $port] == 0} {
	set port 80
    }
    
    # Somehow we need to pad an extra / here.
    set fileTail [string trim [file tail "junk/[string trim $path /]"] /]
    set fullName [file join $prefs(incomingPath) $fileTail]
    
    if {[string length $fileTail] == 0} {
	tk_dialog .wrfn "No Path" "No file name in path." \
	  error 0 Cancel
	return
    }
    
    # This is opened as an ordinary movie.
    set anchor [::CanvasUtils::NewImportAnchor $wcan]
    ::Import::DoImport $wcan $anchor -url $url
}

proc ::Multicast::CleanupMulticastQTStream {wtop fid fullName token} { 

    upvar #0 $token state    

    set wcan [::WB::GetCanvasFromWtop $wtop]
    set no_ {^2[0-9]+}
    catch {close $fid}
    
    # Waiting is over.
    ::WB::StartStopAnimatedWaveOnMain 0
    
    # Access state as a Tcl array.
    # Check errors. 
    if {[info exists state(status)] &&  \
      [string equal $state(status) "timeout"]} {
	::UI::MessageBox -icon error -type ok -message   \
	  "Timout event for url=$state(url)" 
	return
    } elseif {[info exists state(status)] &&  \
      ![string equal $state(status) "ok"]} {
	::UI::MessageBox -icon error -type ok -message   \
	  "Not ok return code from url=$state(url); status=$state(status)"	  
	return
    }
    
    # The http return status. Must be 2**.
    set httpCode [lindex $state(http) 1]
    if {![regexp "$no_" $httpCode]} {
	::UI::MessageBox -icon error -type ok \
	  -message "Failed open url=$url. Returned with code: $httpCode."
    }
    
    # Check that type of data is the wanted. Check further.
    if {[info exists state(type)] &&  \
      [string equal $state(type) "video/quicktime"]} {
	::UI::MessageBox -icon error -type ok -message \
	  "Not correct file type returned from url=$state(url); \
	  filetype=$state(type); expected video/quicktime."
	return
    }
    
    # This is opened as an ordinary movie.
    set anchor [::CanvasUtils::NewImportAnchor $wcan]
    ::Import::DoImport $wcan "$anchor" -file $fullName  \
      -where "local"
    set fileTail [file tail $fullName]
    ::WB::SetStatusMessage $wtop "Opened streaming live multicast: $fileTail."
    update idletasks
}

proc ::Multicast::ProgressMulticastQTStream {wtop fileTail token totalBytes currentBytes} {

    upvar #0 $token state
    
    # Access state as a Tcl array.
    if {$totalBytes != 0} {
	set percentLeft [expr ($totalBytes - $currentBytes)/$totalBytes]
	set txtLeft ", $percentLeft% left"
    } else {
	set txtLeft ""
    }
    ::WB::SetStatusMessage $wtop "Getting $fileTail$txtLeft"
    update idletasks
}
