#  Multicast.tcl ---
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
# $Id: Multicast.tcl,v 1.2 2004-05-06 13:41:11 matben Exp $

package provide Multicast 1.0

namespace eval ::Multicast:: {
    
    namespace export OpenMulticast
    
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
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       w           the toplevel dialog.
#       
# Results:
#       shows dialog.

proc ::Multicast::OpenMulticast {wtop} {
    global  prefs this wDlgs
    
    variable uid
    variable txtvarEntMulticast
    variable selMulticastName
    variable finished

    set finished -1
    set w $wDlgs(openMulti)[incr uid]
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [::msgcat::mc {Open Stream}]
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Labelled frame.
    set wcfr $w.frall.fr
    labelframe $wcfr -text [::msgcat::mc openquicktime]
    pack $wcfr -side top -fill both -padx 8 -pady 4 -ipadx 10 -ipady 6 -in $w.frall
    
    # Overall frame for whole container.
    set frtot [frame $wcfr.frin]
    pack $frtot
    label $frtot.lbltop -text [::msgcat::mc writeurl] -font $fontSB
    set shorts [lindex $prefs(shortsMulticastQT) 0]
    set optMenu [eval {tk_optionMenu $frtot.optm  \
      [namespace current]::selMulticastName} $shorts]
    $frtot.optm configure -highlightthickness 0 -foreground black
    #set selMulticastName [lindex [lindex $prefs(shortsMulticastQT) 0] 0]
    label $frtot.lblhttp -text {http://} -font $fontSB
    entry $frtot.entip -width 60   \
      -textvariable [namespace current]::txtvarEntMulticast
    message $frtot.msg -borderwidth 0 -aspect 500 \
      -text [::msgcat::mc openquicktimeurlmsg]
    grid $frtot.lbltop -column 0 -row 0 -sticky sw -padx 0 -pady 2 -columnspan 2
    grid $frtot.optm -column 2 -row 0 -sticky e -padx 2 -pady 2
    grid $frtot.lblhttp -column 0 -row 1 -sticky e -padx 0 -pady 6
    grid $frtot.entip -column 1 -row 1 -columnspan 2 -sticky w -padx 0 -pady 6
    grid $frtot.msg -column 0 -row 2 -columnspan 3 -padx 4 -pady 2 -sticky news
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]  
    pack [button $frbot.btconn -text [::msgcat::mc Open] -default active  \
      -command [list Multicast::OpenMulticastQTStream $wtop $frtot.entip]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command "set [namespace current]::finished 0"]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btedit -text "[::msgcat::mc Edit]..."   \
      -command [list Multicast::DoAddOrEditQTMulticastShort edit $frtot.optm]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btadd -text "[::msgcat::mc Add]..."   \
      -command [list Multicast::DoAddOrEditQTMulticastShort add $frtot.optm]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -in $w.frall  \
      -padx 8 -pady 6
    
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
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!

proc ::Multicast::OpenMulticastQTStream {wtop wentry} {
    global  this prefs
    variable finished

    set wCan [::WB::GetCanvasFromWtop $wtop]

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
    catch {unset port}
    if {![regexp -nocase "($proto_)://($domain_)(:($port_))?($path_)$"  \
      $url match protocol domain junk port path]} {
	tk_messageBox -message   \
	  "Inconsistent url=$url." -icon error -type ok
	set finished 0
	return ""
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
	return ""
    }
    
    # This is opened as an ordinary movie.
    set anchor [::CanvasUtils::NewImportAnchor $wCan]
    ::Import::DoImport $wCan $anchor -url $url
}

proc ::Multicast::CleanupMulticastQTStream {wtop fid fullName token} { 

    upvar #0 $token state    

    set wCan [::WB::GetCanvasFromWtop $wtop]
    set no_ {^2[0-9]+}
    catch {close $fid}
    
    # Waiting is over.
    ::WB::StartStopAnimatedWaveOnMain 0
    
    # Access state as a Tcl array.
    # Check errors. 
    if {[info exists state(status)] &&  \
      [string equal $state(status) "timeout"]} {
	tk_messageBox -icon error -type ok -message   \
	  "Timout event for url=$state(url)" 
	return
    } elseif {[info exists state(status)] &&  \
      ![string equal $state(status) "ok"]} {
	tk_messageBox -icon error -type ok -message   \
	  "Not ok return code from url=$state(url); status=$state(status)"	  
	return
    }
    
    # The http return status. Must be 2**.
    set httpCode [lindex $state(http) 1]
    if {![regexp "$no_" $httpCode]} {
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  "Failed open url=$url. Returned with code: $httpCode."]
    }
    
    # Check that type of data is the wanted. Check further.
    if {[info exists state(type)] &&  \
      [string equal $state(type) "video/quicktime"]} {
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  "Not correct file type returned from url=$state(url); \
	  filetype=$state(type); expected video/quicktime."]	  
	return
    }
    
    # This is opened as an ordinary movie.
    set anchor [::CanvasUtils::NewImportAnchor $wCan]
    ::Import::DoImport $wCan "$anchor" -file $fullName  \
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
