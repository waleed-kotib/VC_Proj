#  Connections.tcl ---
#  
#      This file is part of the whiteboard application. It creates a dialog 
#      for connecting to the server via TCP/IP, and provide some procedures 
#      to make the connection.
#      Contains also open streaming media dialogs.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Connections.tcl,v 1.9 2003-10-12 13:12:55 matben Exp $

package provide Connections 1.0

namespace eval ::OpenConnection:: {
        
    # The textvariable for the adress entry widget.
    variable txtvarEntIPnameOrNum
    
    # Variable in the shorts popup menu that is traced.
    variable menuShortVar
    
    # The actual adress connected to.
    variable connIPnum
    
    # The textvariable for the port number entry widget.
    variable compPort
    variable killerId
    
    # Is set when pressing cancel or open button.
    variable finished
}
    
# ::OpenConnection::OpenConnection --
#
#       Starts process to open a connection to another client.
#       Needs procedures from the OpenConnection.tcl file.
#       When opening in async mode, the calling sequence is:
#           OpenConnection -> PushBtConnect ->
#           -> DoConnect -> WhenSocketOpensInits,
#       where the last sequence is triggered by a fileevent.

proc ::OpenConnection::OpenConnection {w} {
    global  sysFont prefs this
    
    variable txtvarEntIPnameOrNum
    variable menuShortVar
    variable connIPnum
    variable compPort
    variable finished
    variable wtoplevel $w

    set finished -1
    if {[winfo exists $w]} {
	return
    }
    if {[string match "mac*" $this(platform)]} {
	toplevel $w
	eval $::macWindowStyle $w documentProc
	::UI::MacUseMainMenu $w
    } else {
	toplevel $w
    }
    wm title $w {Open Connection}
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Ip part.
    set wcont1 [LabeledFrame2 $w.frip {Connect to}]
    
    # Overall frame for whole container.
    set frtot [frame $wcont1.fr]
    pack $frtot
    message $frtot.msg -width 230 -font $sysFont(s) -text  \
      "Connect to a remote computer. Write remote computer name\
      or choose shortcut from the popup menu.\
      If necessary choose new remote port number."
    label $frtot.lblip -text {Shortcut:}
    entry $frtot.entip -width 30   \
      -textvariable [namespace current]::txtvarEntIPnameOrNum
    
    # The option menu. 
    set shorts [lindex $prefs(shortcuts) 0]
    eval {tk_optionMenu $frtot.optm [namespace current]::menuShortVar} \
      $shorts 
    if {[string length $txtvarEntIPnameOrNum] == 0} {
	set txtvarEntIPnameOrNum [lindex [lindex $prefs(shortcuts) 1] 0]
    }
    $frtot.optm configure -highlightthickness 0  \
      -background $prefs(bgColGeneral) -foreground black
    grid $frtot.msg -column 0 -row 0 -columnspan 2 -sticky w -padx 6 -pady 2
    grid $frtot.lblip -column 0 -row 1 -sticky w -padx 6 -pady 2
    grid $frtot.optm -column 1 -row 1 -sticky e -padx 6 -pady 2
    grid $frtot.entip -column 0 -row 2 -sticky ew -padx 10 -columnspan 2
    pack $w.frip -side top -fill both -ipadx 10 -ipady 6 -in $w.frall
    
    # Port part.
    set ofr $w.frport
    set wcont2 [LabeledFrame2 $ofr "Port number"]
    label $wcont2.lport -text "Remote server port:"
    entry $wcont2.entport -width 6 -textvariable [namespace current]::compPort
    set compPort $prefs(remotePort)
    grid $wcont2.lport -row 0 -column 0 -padx 3
    grid $wcont2.entport -row 0 -column 1 -padx 3
    pack $ofr -side top -fill both -ipadx 10 -ipady 6 -in $w.frall
    
    # Button part.
    frame $w.frbot -borderwidth 0
    pack [button $w.btconn -text "Connect" -default active  \
      -command [namespace current]::PushBtConnect]  \
      -in $w.frbot -side right -padx 5 -pady 5
    pack [button $w.btcancel -text [::msgcat::mc Cancel]   \
      -command "destroy $w"]  \
      -in $w.frbot -side right -padx 5 -pady 5
    pack $w.frbot -side top -fill both -expand 1 -in $w.frall  \
      -padx 8 -pady 6
    
    bind $w <Return> [namespace current]::PushBtConnect
    trace variable [namespace current]::menuShortVar w  \
      [namespace current]::TraceOpenConnect
    
    if {[info exists prefs(winGeom,$w)]} {
	wm geometry $w $prefs(winGeom,$w)
    }
    wm resizable $w 0 0
    focus $w
    catch {grab $w}
    tkwait window $w
    
    # Clean up.
    trace vdelete [namespace current]::menuShortVar w  \
      [namespace current]::TraceOpenConnect
    catch {grab release $w}
    destroy $w
    
    if {$finished == 1} {
	return $connIPnum
    } else {
	return ""
    }
}

proc ::OpenConnection::PushBtConnect { } {
    global  this prefs
    
    variable txtvarEntIPnameOrNum
    variable connIPnum
    variable compPort
    variable finished
    variable wtoplevel

    # Always allow connections to 'this(internalIPname)'.
    # This is because 'IsConnectedToQ' always answers this question with true.
    
    if {[string equal $txtvarEntIPnameOrNum $this(internalIPnum)] ||  \
      [string equal $txtvarEntIPnameOrNum $this(internalIPname)]} {
	set connIPnum [::OpenConnection::DoConnect $txtvarEntIPnameOrNum $compPort 1]
	set finished 1
	destroy $wtoplevel
	return
    }
    
    # Check that you do not connect to yourself. Only allowed if central net.
    if {$prefs(protocol) == "symmetric"} {
	if {($txtvarEntIPnameOrNum == $this(ipnum)) ||  \
	  ($txtvarEntIPnameOrNum == $this(hostname))} {
	    tk_messageBox -icon error -type ok -message  \
	      [FormatTextForMessageBox \
	      "You are not allowed to connect to yourself!"]	      
	    return
	}    
    }
    
    # Check if not already connected to the ip in question.
    
    if {[IsConnectedToQ $txtvarEntIPnameOrNum]} {
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	   "You are already connected to this client!"]
	set finished 0
	destroy $wtoplevel
	return
    }
    set prefs(remotePort) $compPort
    set connIPnum [::OpenConnection::DoConnect $txtvarEntIPnameOrNum $compPort 1]
    set finished 1
    ::UI::SaveWinGeom $wtoplevel
    destroy $wtoplevel
}

proc ::OpenConnection::TraceOpenConnect {name junk1 junk2} {
    global  prefs
    
    # Call by name.
    upvar #0 $name locName

    variable txtvarEntIPnameOrNum

    # 'txtvarEntIPnameOrNum' is textvariable in entry widget
    set ind [lsearch [lindex $prefs(shortcuts) 0] $locName]
    set txtvarEntIPnameOrNum [lindex [lindex $prefs(shortcuts) 1] $ind]
}

# ::OpenConnection::DoConnect --
# 
#       Handles the complete connection process.
#       It makes the actual connection to a given ip address and
#       port number. It sets some arrays to keep track of each connection.
#       If open socket async, then need 'WhenSocketOpensInits' as callback.
#       If 'propagateSizeToClients', then let other clients know this canvas 
#       size, which is the case if interactive open, else not 
#       (weird things happen).

proc ::OpenConnection::DoConnect {toNameOrNum toPort {propagateSizeToClients 1}} {
    global  this prefs errorCode wDlgs
    
    set nameOrIP $toNameOrNum
    set remoteServPort $toPort
    
    Debug 2 "DoConnect:: nameOrIP: $nameOrIP, remoteServPort: $remoteServPort"

    ::UI::SetStatusMessage $wDlgs(mainwb) "Contacted $nameOrIP. Waiting for response..."
    ::UI::StartStopAnimatedWaveOnMain 1
    
    # Handle the TCP/IP channel; if internal pick internalIPnum
    
    if {($nameOrIP == $this(internalIPnum)) || ($nameOrIP == $this(internalIPname))} {
	if {$prefs(asyncOpen)} {
	    set res [catch {socket -async -myaddr $this(internalIPnum)  \
	      $this(internalIPnum) $remoteServPort} server]
	} else {
	    set res [catch {socket -myaddr $this(internalIPnum)  \
	      $this(internalIPnum) $remoteServPort} server]
	}
    } else {
	if {$prefs(asyncOpen)} {
	    set res [catch {socket -async $nameOrIP $remoteServPort} server]
	} else {
	    set res [catch {socket $nameOrIP $remoteServPort} server]
	}
    }
    Debug 2 "DoConnect:: res=$res"

    if {$res} {
	tk_messageBox -icon error -type ok -parent $wDlgs(mainwb) -message  \
	  [FormatTextForMessageBox [::msgcat::mc messfailedsock $errorCode]]
	::UI::SetStatusMessage $wDlgs(mainwb) {}
	::UI::StartStopAnimatedWaveOnMain 0
	update idletasks
	return {}
    }
    
    # Write line by line; encode newlines in text items as \n.
    fconfigure $server -buffering line
    
    # When socket writable the connection is opened.
    # Needs to be in nonblocking mode.
    fconfigure $server -blocking 0
    
    # For nonlatin characters to work be sure to use Unicode/UTF-8.
    if {[info tclversion] >= 8.1} {
	catch {fconfigure $server -encoding utf-8}
    }
    
    # If open socket in async mode, need to wait for fileevent.
    if {$prefs(asyncOpen)} {
	fileevent $server writable   \
	  [list [namespace current]::WhenSocketOpensInits $nameOrIP $server   \
	  $remoteServPort $propagateSizeToClients]
	
	# Set up timer event for timeouts.
	ScheduleKiller $server
	set ans ""
    } else {
	
	# Else, it is already open.
	set ans [[namespace current]::WhenSocketOpensInits   \
	  $nameOrIP $server $remoteServPort $propagateSizeToClients]
    }
    return $ans
}

# OpenConnection::WhenSocketOpensInits --
#
#       When socket is writable, it is open. Do all the necessary 
#       initializations.
#       If 'propagateSizeToClients', then let other clients know this canvas 
#       size.

proc ::OpenConnection::WhenSocketOpensInits {nameOrIP server remoteServPort \
  {propagateSizeToClients 1}} {	
    global  ipName2Num ipNumTo this allIPnumsTo prefs wDlgs
    
    variable killerId
    
    Debug 2 "WhenSocketOpensInits:: (entry) nameOrIP=$nameOrIP"
    
    # No more event handlers here. See also below...
    fileevent $server writable {}
    
    #  Cancel timeout killer.
    if {[info exists killerId($server)]} {
	after cancel $killerId($server)
	catch {unset killerId($server)}
    }
    
    ::UI::StartStopAnimatedWaveOnMain 0
    if {[eof $server]} {
	::UI::SetStatusMessage $wDlgs(mainwb) [::msgcat::mc messeofconnect]
	tk_messageBox -icon error -type ok -parent $wDlgs(mainwb) -message  \
	  [FormatTextForMessageBox [::msgcat::mc messeofconnect]]	  
	return
    }
    
    # Check if something went wrong first.
    if {[catch {fconfigure $server -sockname} sockname]} {
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  "Something went wrong (-sockname). $sockname"]	  
	::UI::SetStatusMessage $wDlgs(mainwb) {}
	return {}
    }
    
    # Save ip number, names, socks etc. in arrays.
    if {![::OpenConnection::SetIpArrays $nameOrIP $server $remoteServPort]} {
	::UI::SetStatusMessage $wDlgs(mainwb) {}
	return
    }
    if {[::Utils::IsIPNumber $nameOrIP]} {
	set ipNum $nameOrIP
	set ipName $ipNumTo(name,$ipNum)
    } else {
	set ipName $nameOrIP
	set ipNum $ipName2Num($ipName)
    }

    ::UI::SetStatusMessage $wDlgs(mainwb) "Client $ipName responded."
    
    # If a central server, then the single socket must be used full duplex.
    # This is only valid only for the clients.
    # It means that the socket we have just opened to the remote server
    # is used to read from as well as writing to.
    # We therefore set up an event handler similar to the server event
    # handler that is used to handle remote commands.
    # Same for "client".
    
    if {($prefs(protocol) == "central") || ($prefs(protocol) == "client")} {
	fileevent $server readable    \
	  [list HandleClientRequest $server $ipNum $remoteServPort]
    }    
    set listIPandPort {}
    foreach ip $allIPnumsTo {
	lappend listIPandPort $ip $ipNumTo(servPort,$ipNum)
    }
    if {[catch {
    
	# Let the remote computer know port and itpref used by this client.
	set utagPref [::CanvasUtils::GetUtagPrefix]
	puts $server [list "IDENTITY:" $prefs(thisServPort) $utagPref $this(username)]
	
	# Let connecting client now this 'allIPnumsTo' (for multi connect).????
	# 'allIPnumsTo' not yet updated with the new ip; doesn't matter!
	puts $server "IPS CONNECTED: $listIPandPort"
    }]} {
	tk_messageBox -type ok -title [::msgcat::mc {Network Error}] -icon error -message \
	  [FormatTextForMessageBox [::msgcat::mc messfailconnect $nameOrIP]]
	return
    }
    
    # Add line in the communication entry. Also updates 'allIPnumsTo'.
    ::UI::SetCommEntry $wDlgs(mainwb) $ipNum 1 -1
    
    # Let all other now about the size change. propagateToClients and force.
    
    if {$propagateSizeToClients} {
	::UI::CanvasSizeChange $allIPnumsTo 1
    } else {
	::UI::CanvasSizeChange 0 1
    }
    
    # Update menus. If client only, allow only one connection, limited.
    ::UI::FixMenusWhen $wDlgs(mainwb) "connect"
    return $ipNum
}

# OpenConnection::SetIpArrays --
#
#       Save ip number, names, socks etc. in arrays.
#
# Arguments:
#       nameOrIP    ipname or ip number for this connection
#       sock        the respective socket
#       remoteServPort
#       
# Results:
#       Boolean.

proc ::OpenConnection::SetIpArrays {nameOrIP sock remoteServPort} {
    global  ipName2Num ipNumTo this state
    
    # Need to be economical here since '-peername' takes 5 secs on 
    # the Windows box on my intranet.
    # Find out if this client already registered arrays.
    # Need to check both since we doesn't know if number or name.
    
    set isRegistered 0
    if {[info exists ipNumTo(name,$nameOrIP)] ||  \
      [info exists ipName2Num($nameOrIP)]} {
	set isRegistered 1
    }
    Debug 2 "::OpenConnection::SetIpArrays isRegistered=$isRegistered"
    
    if {!$isRegistered} {

	# If not, we need to register it here and now.
	if {[catch {fconfigure $sock -peername} peername]} {
	    tk_messageBox -icon error -type ok -message \
	      [FormatTextForMessageBox \
	      "Something went wrong (-peername): $peername"]	      
	    return 0
	}
	Debug 2 "::OpenConnection::SetIpArrays peername=$peername"
	
	# Careful because sometimes (mac only?) we get '<unknown>' for ip name.
	set ipNum [lindex $peername 0]
	set ipName [lindex $peername 1]
	if {![::Utils::IsIPNumber $nameOrIP]} {
	    set ipName $nameOrIP
	}

	# Save ip nums and names etc in arrays.
	set ipNumTo(name,$ipNum) $ipName
	set ipName2Num($ipName) $ipNum
    } else {
	if {[::Utils::IsIPNumber $nameOrIP]} {
	    set ipNum $nameOrIP
	    set ipName $ipNumTo(name,$ipNum)
	} else {
	    set ipName $nameOrIP
	    set ipNum $ipName2Num($ipName)
	}
    }
    
    # Save ip nums and names etc in arrays.
    set ipNumTo(socket,$ipNum) $sock
    set ipNumTo(servPort,$ipNum) $remoteServPort
    
    # Sometimes the DoStartServer just gives this(ipnum)=0.0.0.0 ; fix this here.
    if {!$state(connectedOnce)} {
	if {[catch {fconfigure $sock -sockname} sockname]} {
	    tk_messageBox -icon error -type ok -message \
	      [FormatTextForMessageBox "Something went wrong: $sockname"]
	    return 0
	}
	if {[lindex $sockname 0] != "0.0.0.0"} {
	    set this(ipnum) [lindex $sockname 0]
	    Debug 2 "\tSetting this(ipnum) = $this(ipnum), sockname=$sockname"
	}
	set state(connectedOnce) 1
    }
    return 1
}

# ScheduleKiller, Kill --
#
#       Cancel 'OpenConnection' process if timeout.

proc ::OpenConnection::ScheduleKiller {sock} {
    global  prefs
    
    variable killerId    

    if {[info exists killerId($sock)]} {
	after cancel $killerId($sock)
    }
    set killerId($sock) [after $prefs(timeoutMillis)   \
      [list [namespace current]::Kill $sock]]
}

proc ::OpenConnection::Kill {sock} {
    global  prefs wDlgs
    
    variable killerId    

    catch {close $sock}
    set statMess [::msgcat::mc messtimeout]
    ::UI::SetStatusMessage $wDlgs(mainwb) $statMess
    ::UI::StartStopAnimatedWaveOnMain 0
    if {[info exists killerId($sock)]} {
	after cancel $killerId($sock)
	catch {unset killerId($sock)}
    }
    tk_messageBox -icon error -type ok -parent $wDlgs(mainwb) -message \
      [FormatTextForMessageBox $statMess]
}

# OpenConnection::IsConnectedToQ --
#
#       Finds if connected to 'ipNameOrNum' by searching 'allIPnumsTo'.
#       Always allow local connections to ourselves (127.0.0.1 and localhost).
#       Also, alllow to connect to ourselves if we have got a real ip number;
#       This is good if we want to start a ReflectorServer.
#

proc ::OpenConnection::IsConnectedToQ {ipNameOrNum} {
    global  ipName2Num allIPnumsTo this

    Debug 2 "IsConnectedToQ:: ipNameOrNum=$ipNameOrNum, this(ipnum)=$this(ipnum)"
    
    # Always allow local connections to ourselves (127.0.0.1 and localhost).
    if {[string equal $ipNameOrNum $this(internalIPnum)] ||  \
      [string equal $ipNameOrNum "localhost"]} {
	return 0
    }
    
    # Find out if 'ipNameOrNum' is name or number.
    # If any character in 'ipNameOrNum' then assume it is a name.
    if {[regexp {[a-zA-Z]+} $ipNameOrNum]} {
	if {[info exists ipName2Num($ipNameOrNum)]} {
	    set ipNum $ipName2Num($ipNameOrNum)
	} else {
	    
	    # If we don't have registered the ip in 'ipName2Num' then
	    # we are not connected and have not connected to it previously.
	    return 0
	}
    } else {
	set ipNum $ipNameOrNum
    }
    
    # Here we are sure that 'ipNum' is an ip number.
    if {[lsearch -exact $allIPnumsTo $ipNum] >= 0} {
	return 1
    } else {
	return 0
    }
}

#   Sets auto disconnect identical to autoConnect.

proc ::OpenConnection::DoAutoConnect { } {
    global  prefs
    
    set prefs(autoDisconnect) $prefs(autoConnect)
}


# OpenConnection::OpenCancelAllPending --
#
#       This may happen when the user presses a stop button or something.

proc ::OpenConnection::OpenCancelAllPending { } {
    variable killerId wDlgs

    Debug 2 "+OpenCancelAllPending::"

    ::UI::SetStatusMessage $wDlgs(mainwb) {}
    ::UI::StartStopAnimatedWaveOnMain 0
        
    # Pending Open connection:
    if {[info exists killerId]} {
	foreach s [array names killerId] {
	    
	    # Be sure to cancel any timeout events first.
	    after cancel $killerId($s)
	    
	    # Then close socket.
	    catch {close $s}
	    catch {unset killerId($s)}
	}
    }
}

# OpenConnection::DoCloseClientConnection --
#
#       Handle closing down the client side connection (the 'to' part).
#       
# Arguments:
#       ipNum     the ip number.
#       
# Results:
#       none

proc ::OpenConnection::DoCloseClientConnection {ipNum} {
    global  prefs allIPnumsToSend allIPnumsTo ipNumTo wDlgs
        
    Debug 2 "DoCloseClientConnection:: ipNum=$ipNum"    
    
    # If it is not there, just return.
    set ind [lsearch $allIPnumsTo $ipNum]
    if {$ind == -1} {
	return
    }
    
    # Do the actual closing.
    catch {close $ipNumTo(socket,$ipNum)}

    # Update the communication frame; remove connection 'to'.
    ::UI::SetCommEntry $wDlgs(mainwb) $ipNum 0 -1

    # If no more connections left, make menus consistent.
    if {[llength $allIPnumsToSend] == 0} {
	::UI::FixMenusWhen $wDlgs(mainwb) {disconnect}
    }
}

# OpenConnection::DoCloseServerConnection --
#
#       Handles everything to close the server side connection (the 'from' part).
#       
# Arguments:
#       ipNum     the ip number.
#       
# Results:
#       none

proc ::OpenConnection::DoCloseServerConnection {ipNum args} {
    global  ipNumTo allIPnumsToSend prefs wDlgs
    
    Debug 2 "DoCloseServerConnection:: ipNum=$ipNum, ipNumTo(servSocket,$ipNum)=\
      $ipNumTo(servSocket,$ipNum)"

    array set opts {
	-close   0
    }
    array set opts $args
    
    # Switch off the comm 'from' button.
    ::UI::SetCommEntry $wDlgs(mainwb) $ipNum -1 0
    if {[string equal $prefs(protocol) "server"]} {
	catch {close $ipNumTo(socket,$ipNum)}
	catch {unset ipNumTo(socket,$ipNum)}
    } else {
	catch {close $ipNumTo(servSocket,$ipNum)}
    }
    
    # If we are running an internal server, close client connections.
    # Applies only to the case with symmetric network topology.    
    if {($prefs(protocol) == "symmetric") && $prefs(autoDisconnect)} {
	::OpenConnection::DoCloseClientConnection $ipNum
    }
    
    # If no more connections left, make menus consistent.
    ::UI::FixMenusWhen $wDlgs(mainwb) "disconnectserver"
}

#--- OpenMulticast stuff -------------------------------------------------------

namespace eval ::OpenMulticast:: {
    
    namespace export OpenMulticast
    
    variable txtvarEntMulticast
    variable selMulticastName
    variable finished
}

# OpenMulticast::OpenMulticast --
#
#       Makes dialog to open streaming audio/video.
#   
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       w           the toplevel dialog.
#       
# Results:
#       shows dialog.

proc ::OpenMulticast::OpenMulticast {wtop w} {
    global  sysFont prefs this
    
    variable txtvarEntMulticast
    variable selMulticastName
    variable finished

    set finished -1
    if {[winfo exists $w]} {
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
	::UI::MacUseMainMenu $w
    } else {
	#
    }
    wm title $w [::msgcat::mc {Open Stream}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Labelled frame.
    set wcfr $w.frall.fr
    set wcont [LabeledFrame2 $wcfr [::msgcat::mc openquicktime]]
    pack $wcfr -side top -fill both -ipadx 10 -ipady 6 -in $w.frall
    
    # Overall frame for whole container.
    set frtot [frame $wcont.frin]
    pack $frtot
    label $frtot.lbltop -text [::msgcat::mc writeurl] -font $sysFont(sb)
    set shorts [lindex $prefs(shortsMulticastQT) 0]
    set optMenu [eval {tk_optionMenu $frtot.optm  \
      [namespace current]::selMulticastName} $shorts]
    $frtot.optm configure -highlightthickness 0  \
      -background $prefs(bgColGeneral) -foreground black
    #set selMulticastName [lindex [lindex $prefs(shortsMulticastQT) 0] 0]
    label $frtot.lblhttp -text {http://} -font $sysFont(sb)
    entry $frtot.entip -width 60   \
      -textvariable [namespace current]::txtvarEntMulticast
    message $frtot.msg -borderwidth 0 -font $sysFont(s) -aspect 500 \
      -text [::msgcat::mc openquicktimeurlmsg]
    grid $frtot.lbltop -column 0 -row 0 -sticky sw -padx 0 -pady 2 -columnspan 2
    grid $frtot.optm -column 2 -row 0 -sticky e -padx 2 -pady 2
    grid $frtot.lblhttp -column 0 -row 1 -sticky e -padx 0 -pady 6
    grid $frtot.entip -column 1 -row 1 -columnspan 2 -sticky w -padx 0 -pady 6
    grid $frtot.msg -column 0 -row 2 -columnspan 3 -padx 4 -pady 2 -sticky news
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]  
    pack [button $frbot.btconn -text [::msgcat::mc Open] -default active -width 8 \
      -command [list OpenMulticast::OpenMulticastQTStream $wtop $frtot.entip]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command "set [namespace current]::finished 0"]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btedit -text "[::msgcat::mc Edit]..." -width 8  \
      -command [list OpenMulticast::DoAddOrEditQTMulticastShort edit $frtot.optm]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btadd -text "[::msgcat::mc Add]..." -width 8  \
      -command [list OpenMulticast::DoAddOrEditQTMulticastShort add $frtot.optm]]  \
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

# OpenMulticast::DoAddOrEditQTMulticastShort --
#
#       Process the edit and add buttons. Makes call to 'AddOrEditShortcuts'.
#   
# Arguments:
#       what   "add" or "edit".
#       wOptMenu
#       
# Results:
#       .

proc ::OpenMulticast::DoAddOrEditQTMulticastShort {what wOptMenu} {
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
	$wOptMenu configure -highlightthickness 0  \
	  -background $prefs(bgColGeneral) -foreground black
	eval {grid $wOptMenu} $gridInfo
    }
}

proc ::OpenMulticast::TraceSelMulticastName {name junk1 junk2} {
    global  prefs
    upvar #0 $name locName
    
    variable txtvarEntMulticast
    
    set ind [lsearch [lindex $prefs(shortsMulticastQT) 0] $locName]
    set txtvarEntMulticast [lindex [lindex $prefs(shortsMulticastQT) 1] $ind]
}

# OpenMulticast::OpenMulticastQTStream --
#
#       Initiates a separate download of the tiny SDR file with http.
#   
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!

proc ::OpenMulticast::OpenMulticastQTStream {wtop wentry} {
    global  this prefs    
    variable finished

    set wCan [::UI::GetCanvasFromWtop $wtop]

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
    set anchor [::CanvasUtils::NewImportAnchor]
    ::Import::DoImport $wCan $anchor -url $url
}

proc ::OpenMulticast::CleanupMulticastQTStream {wtop fid fullName token} { 

    upvar #0 $token state    

    set wCan [::UI::GetCanvasFromWtop $wtop]
    set no_ {^2[0-9]+}
    catch {close $fid}
    #parray state
    
    # Waiting is over.
    ::UI::StartStopAnimatedWaveOnMain 0
    
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
    set anchor [::CanvasUtils::NewImportAnchor]
    ::Import::DoImport $wCan "$anchor" -file $fullName  \
      -where "local"
    set fileTail [file tail $fullName]
    ::UI::SetStatusMessage $wtop "Opened streaming live multicast: $fileTail."
    update idletasks
}

proc ::OpenMulticast::ProgressMulticastQTStream {wtop fileTail token totalBytes currentBytes} {

    upvar #0 $token state
    
    # Access state as a Tcl array.
    if {$totalBytes != 0} {
	set percentLeft [expr ($totalBytes - $currentBytes)/$totalBytes]
	set txtLeft ", $percentLeft% left"
    } else {
	set txtLeft ""
    }
    ::UI::SetStatusMessage $wtop "Getting $fileTail$txtLeft"
    update idletasks
}

#-------------------------------------------------------------------------------
