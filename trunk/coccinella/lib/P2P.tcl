#  P2P.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It provides the glue between the p2p mode and the whiteboard.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: P2P.tcl,v 1.2 2004-03-15 13:26:11 matben Exp $

package provide P2P 1.0


namespace eval ::P2P:: {

    variable initted 0
        
    # For the communication entries.
    # variables:              $wtop is used as a key in these vars.
    #       nEnt              a running counter for the communication frame entries
    #                         that is *never* reused.
    #       ipNum2iEntry:     maps ip number to the entry line (nEnt) in the connect 
    #                         panel.
    #       thisType          protocol
    variable nEnt
    variable ipNum2iEntry
    variable commTo
    variable commFrom
    variable thisType

}


proc ::P2P::Init {} {
    global  prefs
    variable initted
    
    # Register canvas draw event handler.
    ::hooks::add whiteboardBuildEntryHook     ::P2P::BuildEntryHook
    ::hooks::add whiteboardSetMinsizeHook     ::P2P::SetMinsizeHook    
    ::hooks::add whiteboardFixMenusWhenHook   ::P2P::FixMenusWhenHook
    ::hooks::add whiteboardSendMessageHook    ::P2P::SendMessageListHook
    ::hooks::add whiteboardSendGenMessageHook ::P2P::SendGenMessageListHook
    ::hooks::add whiteboardPutFileHook        ::P2P::PutFileHook
    ::hooks::add serverGetRequestHook         ::P2P::HandleGetRequest
    ::hooks::add serverPutRequestHook         ::P2P::HandlePutRequest
    ::hooks::add serverCmdHook                ::P2P::HandleServerCmd

    set buttonTrayDefs(symmetric) {
	connect    {::OpenConnection::OpenConnection $wDlgs(openConn)}
	save       {::CanvasFile::DoSaveCanvasFile $wtop}
	open       {::CanvasFile::DoOpenCanvasFile $wtop}
	import     {::Import::ImportImageOrMovieDlg $wtop}
	send       {::CanvasCmd::DoSendCanvas $wtop}
	print      {::UserActions::DoPrintCanvas $wtop}
	stop       {::P2P::CancelAllPutGetAndPendingOpen $wtop}
    }
    set buttonTrayDefs(client) $buttonTrayDefs(symmetric)
    set buttonTrayDefs(server) $buttonTrayDefs(symmetric)
    ::WB::SetButtonTrayDefs $buttonTrayDefs($prefs(protocol))

    set menuDefsFile {
	{command   mOpenConnection     {::UserActions::DoConnect}                 normal   O}
	{command   mCloseWindow        {::UI::DoCloseWindow}                      normal   W}
	{separator}
	{command   mPutCanvas          {::CanvasCmd::DoPutCanvasDlg $wtop}        disabled {}}
	{command   mGetCanvas          {::CanvasCmd::DoGetCanvas $wtop}           disabled {}}
	{command   mPutFile            {::P2P::PutFileDlg $wtop}         disabled {}}
	{command   mStopPut/Get/Open   {::P2P::CancelAllPutGetAndPendingOpen $wtop} normal {}}
	{separator}
	{command   mOpenImage/Movie    {::Import::ImportImageOrMovieDlg $wtop}    normal  I}
	{command   mOpenURLStream      {::OpenMulticast::OpenMulticast $wtop}     normal   {}}
	{separator}
	{command   mOpenCanvas         {::CanvasFile::DoOpenCanvasFile $wtop}     normal   {}}
	{command   mSaveCanvas         {::CanvasFile::DoSaveCanvasFile $wtop}     normal   S}
	{separator}
	{command   mSaveAs             {::CanvasCmd::SavePostscript $wtop}        normal   {}}
	{command   mPageSetup          {::UserActions::PageSetup $wtop}           normal   {}}
	{command   mPrintCanvas        {::UserActions::DoPrintCanvas $wtop}       normal   P}
	{separator}
	{command   mQuit               {::UserActions::DoQuit}                    normal   Q}
    }
    if {![::Plugins::HavePackage QuickTimeTcl]} {
	lset menuDefsFile 4 3 disabled
    }
    ::WB::SetMenuDefs file $menuDefsFile
    
    set initted 1
}

# P2P::BuildEntryHook --
# 
#       Build the p2p specific part of the whiteboard.

proc ::P2P::BuildEntryHook {wtop wclass wcomm} {
    global  prefs
    variable nEnt
    variable p2pstate
      
    set nEnt($wtop) 0
  
    set contactOffImage [::Theme::GetImage [option get $wclass contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage [option get $wclass contactOnImage {}]]

    set   fr $wcomm.f
    frame $fr -relief raised -borderwidth 1
    pack  $fr -side bottom -fill x

    switch -- $prefs(protocol) {
	symmetric {
	    label $fr.comm -text {  Remote address:} -width 22 -anchor w
	    label $fr.user -text {  User:} -width 14 -anchor w
	    label $fr.to -text [::msgcat::mc To]
	    label $fr.from -text [::msgcat::mc From]
	    grid  $fr.comm $fr.user $fr.to $fr.from -sticky nws -pady 0
	}
	client {
	    label $fr.comm -text {  Remote address:} -width 22 -anchor w
	    label $fr.user -text {  User:} -width 14 -anchor w
	    label $fr.to -text [::msgcat::mc To]
	    grid  $fr.comm $fr.user $fr.to -sticky nws -pady 0
	}
	server {
	    label $fr.comm -text {  Remote address:} -width 22 -anchor w
	    label $fr.user -text {  User:} -width 14 -anchor w
	    label $fr.from -text [::msgcat::mc From]
	    grid  $fr.comm $fr.user $fr.from -sticky nws -pady 0
	}
	central {
	    
	    # If this is a client connected to a central server, no 'from' 
	    # connections.
	    label $fr.comm -text {  Remote address:} -width 22 -anchor w
	    label $fr.user -text {  User:} -width 14 -anchor w
	    label $fr.to -text [::msgcat::mc To]
	    label $fr.icon -image $contactOffImage
	    grid  $fr.comm $fr.user $fr.to $fr.icon -sticky nws -pady 0
	}
    }  
    set p2pstate($wtop,wfr) $fr
}

# ::P2P::SetCommEntry --
#
#       Adds, removes or updates an entry in the communications frame.
#       If 'to' or 'from' is -1 then disregard this variable.
#       If neither 'to' or 'from', then remove the entry completely for this
#       specific ipNum.
#       The actual job of handling the widgets are done in 'RemoveCommEntry' 
#       and 'BuildCommEntry'.
#       
# variables:
#       nEnt              a running counter for the communication frame entries
#                         that is *never* reused.
#       ipNum2iEntry:     maps ip number to the entry line (nEnt) in the connect 
#                         panel.
#                    
# Arguments:
#       wtop
#       ipNum       the ip number.
#       to          0/1/-1 if off/on/indifferent respectively.
#       from        0/1/-1 if off/on/indifferent respectively.
#       args        '-jidvariable varName', '-validatecommand tclProc'
#                   '-dosendvariable varName'
#       
# Results:
#       updated communication frame.

proc ::P2P::SetCommEntry {wtop ipNum to from args} { 
    global  prefs
    
    variable commTo
    variable commFrom
    variable thisType
    
    Debug 2 "SetCommEntry:: wtop=$wtop, ipNum=$ipNum, to=$to, from=$from, \
      args='$args'"
    
    # Need to check if already exist before adding a completely new entry.
    set alreadyThere 0
    if {[info exists commTo($wtop,$ipNum)]} {
	set alreadyThere 1
    } else {
	set commTo($wtop,$ipNum) 0		
    }
    if {[info exists commFrom($wtop,$ipNum)]} {
	set alreadyThere 1
    } else {
	set commFrom($wtop,$ipNum) 0		
    }

    Debug 2 "  SetCommEntry:: alreadyThere=$alreadyThere, ipNum=$ipNum"
    Debug 2 "     commTo($wtop,$ipNum)=$commTo($wtop,$ipNum), commFrom($wtop,$ipNum)=$commFrom($wtop,$ipNum)"

    if {$to >= 0} {
	set commTo($wtop,$ipNum) $to
    }
    if {$from >= 0} {
	set commFrom($wtop,$ipNum) $from
    }
    
    # If it is not there and shouldn't be added, just return.
    if {!$alreadyThere && ($commTo($wtop,$ipNum) == 0) &&  \
      ($commFrom($wtop,$ipNum) == 0)} {
	Debug 2 "  SetCommEntry:: it is not there and shouldnt be added"
	return
    }
    
    # Update network register to contain each ip num connected to.
    if {$commTo($wtop,$ipNum) == 1} {
	::Network::RegisterIP $ipNum to
    } elseif {$commTo($wtop,$ipNum) == 0} {
	::Network::DeRegisterIP $ipNum to
    }
    
    # Update network register to contain each ip num connected to our server
    # from a remote client.
    if {$commFrom($wtop,$ipNum) == 1} {
	::Network::RegisterIP $ipNum from
    } elseif {$commFrom($wtop,$ipNum) == 0} {
	::Network::DeRegisterIP $ipNum from
    }
	
    # Build new or remove entry line.
    if {($commTo($wtop,$ipNum) == 0) && ($commFrom($wtop,$ipNum) == 0)} {

	# If both 'to' and 'from' 0, and not jabber, then remove entry.
	::P2P::RemoveCommEntry $wtop $ipNum
    } elseif {!$alreadyThere} {
	eval {::P2P::BuildCommEntry $wtop $ipNum} $args
    } 
}

# ::P2P::BuildCommEntry --
#
#       Makes a new entry in the communications frame.
#       Should only be called from SetCommEntry'.
#       
# Arguments:
#       wtop
#       ipNum       the ip number.
#       args        '-jidvariable varName', '-validatecommand cmd',
#                   '-dosendvariable varName'
#       
# Results:
#       updated communication frame with new client.

proc ::P2P::BuildCommEntry {wtop ipNum args} {
    global  prefs ipNumTo
    
    variable commTo
    variable commFrom
    variable ipNum2iEntry
    variable nEnt
    variable thisType
    upvar ::WB::${wtop}::wapp wapp
    
    Debug 2 "BuildCommEntry:: ipNum=$ipNum, args='$args'"

    array set argsArr $args
    set ns [namespace current]
    set wcomm $wapp(comm)
    set wall  $wapp(frall)

    if {[string equal $wtop "."]} {
	set wtopReal .
    } else {
	set wtopReal [string trimright $wtop .]
    }
    set contactOffImage [::Theme::GetImage [option get $wall contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage [option get $wall contactOnImage {}]]
	
    set size [::UI::ParseWMGeometry $wtopReal]
    set n $nEnt($wtop)
    
    # Add new status line.
    if {[string equal $thisType "jabber"]} {
	# empty
    } elseif {[string equal $thisType "symmetric"]} {
	entry $wcomm.ad$n -width 24 -relief sunken
	entry $wcomm.us$n -width 16   \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken
	checkbutton $wcomm.to$n -variable ${ns}::commTo($wtop,$ipNum)   \
	  -highlightthickness 0 -command [list ::P2P::CheckCommTo $wtop $ipNum]
	checkbutton $wcomm.from$n -variable ${ns}::commFrom($wtop,$ipNum)  \
	  -highlightthickness 0 -state disabled
	grid $wcomm.ad$n $wcomm.us$n $wcomm.to$n   \
	  $wcomm.from$n -padx 4 -pady 0
	$wcomm.us$n configure -state disabled
    } elseif {[string equal $thisType "client"]} {
	entry $wcomm.ad$n -width 24 -relief sunken
	entry $wcomm.us$n -width 16    \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken
	checkbutton $wcomm.to$n -variable ${ns}::commTo($wtop,$ipNum)   \
	  -highlightthickness 0 -command [list ::P2P::CheckCommTo $wtop $ipNum]
	grid $wcomm.ad$n $wcomm.us$n $wcomm.to$n -padx 4 -pady 0
	$wcomm.us$n configure -state disabled
    } elseif {[string equal $thisType "server"]} {
	entry $wcomm.ad$n -width 24 -relief sunken
	entry $wcomm.us$n -width 16    \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken
	checkbutton $wcomm.from$n -variable ${ns}::commFrom($wtop,$ipNum)  \
	  -highlightthickness 0 -state disabled
	grid $wcomm.ad$n $wcomm.us$n $wcomm.from$n -padx 4 -pady 0
	$wcomm.us$n configure -state disabled
    }
    
	
    # If no ip name given (unknown) pick ip number instead.
    if {[string match "*unknown*" [string tolower $ipNumTo(name,$ipNum)]]} {
	$wcomm.ad$n insert end $ipNum
    } else {
	$wcomm.ad$n insert end $ipNumTo(name,$ipNum)
    }
    $wcomm.ad$n configure -state disabled
    
    # Increase application height with the correct entry height.
    set entHeight [winfo reqheight $wcomm.ad$n]
    if {[winfo exists $wcomm.to$n]} {
	set checkHeight [winfo reqheight $wcomm.to$n]
    } else {
	set checkHeight 0
    }
    set extraHeight [max $entHeight $checkHeight]
    set newHeight [expr [lindex $size 1] + $extraHeight]

    Debug 3 "  BuildCommEntry:: nEnt=$n, size=$size, \
      entHeight=$entHeight, newHeight=$newHeight, checkHeight=$checkHeight"

    wm geometry $wtopReal [lindex $size 0]x$newHeight
    
    # Geometry considerations. Update geometry vars and set new minsize.
    after idle [list [namespace current]::SetNewWMMinsize $wtop]
    
    # Map ip name to nEnt.
    set ipNum2iEntry($wtop,$ipNum) $nEnt($wtop)
    
    # Step up running index. This must *never* be reused!
    incr nEnt($wtop)
}

# ::P2P::CheckCommTo --
#
#       This is the callback function when the checkbutton 'To' has been trigged.
#       
# Arguments:
#       wtop 
#       ipNum       the ip number.
#       
# Results:
#       updated communication frame.

proc ::P2P::CheckCommTo {wtop ipNum} {
    global  ipNumTo
    
    variable commTo
    variable ipNum2iEntry
    variable thisType
    
    Debug 2 "CheckCommTo:: ipNum=$ipNum"

    if {$commTo($wtop,$ipNum) == 0} {
	
	# Close connection.
	set res [tk_messageBox -message [FormatTextForMessageBox \
	  "Are you sure that you want to disconnect $ipNumTo(name,$ipNum)?"] \
	  -icon warning -type yesno -default yes]
	if {$res == "no"} {
	    
	    # Reset.
	    set commTo($wtop,$ipNum) 1
	    return
	} elseif {$res == "yes"} {
	    ::OpenConnection::DoCloseClientConnection $ipNum
	}
    } elseif {$commTo($wtop,$ipNum) == 1} {
	
	# Open connection. Let propagateSizeToClients = true.
	::OpenConnection::DoConnect $ipNum $ipNumTo(servPort,$ipNum) 1
	::P2P::SetCommEntry $wtop $ipNum 1 -1
    }
}

# ::P2P::RemoveCommEntry --
#
#       Removes the complete entry in the communication frame for 'ipNum'.
#       It should not be called by itself; only from 'SetCommEntry'.
#       
# Arguments:
#       ipNum       the ip number.
#       
# Results:
#       updated communication frame.

proc ::P2P::RemoveCommEntry {wtop ipNum} {
    global  prefs
    
    upvar ::UI::icons icons
    variable commTo
    variable commFrom
    variable ipNum2iEntry
    upvar ::WB::${wtop}::wapp wapp
    
    set wCan  $wapp(can)
    set wcomm $wapp(comm)
    set wall  $wapp(frall)
    
    if {[string equal $wtop "."]} {
	set wtopReal .
    } else {
	set wtopReal [string trimright $wtop .]
    }
    set contactOffImage [::Theme::GetImage [option get $wall contactOffImage {}]]
    
    # Find widget paths from ipNum and remove the entries.
    set no $ipNum2iEntry($wtop,$ipNum)

    Debug 2 "RemoveCommEntry:: no=$no"
    
    # Size administration is very tricky; blood, sweat and tears...
    # Fix the canvas size to relax wm geometry. - 2 ???
    if {$prefs(haveScrollbars)} {
	$wCan configure -height [winfo height $wCan]  \
	  -width [winfo width $wCan]
    } else {
	$wCan configure -height [expr [winfo height $wCan] - 2]  \
	  -width [expr [winfo width $wCan] - 2]
    }
    
    # Switch off the geometry constraint to let resize automatically.
    wm geometry $wtopReal {}
    wm minsize $wtopReal 0 0
    
    # Remove the widgets.
    catch {grid forget $wcomm.ad$no $wcomm.us$no $wcomm.to$no   \
      $wcomm.from$no}
    catch {destroy $wcomm.ad$no $wcomm.us$no $wcomm.to$no   \
      $wcomm.from$no}
    
    # These variables must be unset to indicate that entry does not exists.
    catch {unset commTo($wtop,$ipNum)}
    catch {unset commFrom($wtop,$ipNum)}
    
    # Electric plug disconnect? Only for client only (and jabber).
    if {[string equal $prefs(protocol) "jabber"]} {
	after 400 [list $wcomm.icon configure -image $contactOffImage]
    }
    update idletasks
    
    # Organize the new geometry. First fix using wm geometry, then relax
    # canvas size.
    set newGeom [::UI::ParseWMGeometry $wtopReal]
    wm geometry $wtopReal [lindex $newGeom 0]x[lindex $newGeom 1]
    $wCan configure -height 1 -width 1
    
    # Geometry considerations. Update geometry vars and set new minsize.
    after idle [list [namespace current]::SetNewWMMinsize $wtop]
}

proc ::P2P::SetMinsizeHook {wtop} {
    
    after idle ::P2P::SetMinsize $wtop
}

proc ::P2P::SetMinsize {wtop} {
    variable p2pstate

    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    
    foreach {wMin hMin} [::WB::GetBasicWhiteboardMinsize $wtop] break

    # Add the communication entries.
    set wMinEntry [winfo reqheight $p2pstate($wtop,wfr)]
    set hMinEntry [winfo reqheight $p2pstate($wtop,wfr)]
    set wMin [expr $wMin + $wMinEntry]
    set hMin [expr $hMin + $hMinEntry]
    
    wm minsize $w $wMin $hMin
}

# P2P::SendMessageListHook --
#
#       Sends to command to whoever we are connected to.
#   
# Arguments:
#       wtop
#       msgList     list of commands to send.
#       args   ?-key value ...?
#       -ips         (D=all ips) send to this list of ip numbers. 
#                    Not for jabber.
#       -force 0|1  (D=1) overrides the doSend checkbutton in jabber.
#       
# Results:
#       none

proc ::P2P::SendMessageListHook {wtop msgList args} {
    global  ipNumTo prefs
    
    array set opts [list -ips [::Network::GetIP to] -force 0]
    array set opts $args

    foreach ip $opts(-ips) {
	if {[catch {
	    foreach cmd $cmdList {
		puts $ipNumTo(socket,$ip) "CANVAS: $cmd"
	    }
	}]} {
	    tk_messageBox -type ok -title [::msgcat::mc {Network Error}] \
	      -icon error -message  \
	      [FormatTextForMessageBox [::msgcat::mc messfailsend $ip]]
	}
    }
}

# P2P::SendGenMessageListHook --
# 
#       As above but allows any prefix.

proc ::P2P::SendGenMessageListHook {wtop msgList args} {
    global  ipNumTo prefs
    
    array set opts [list -ips [::Network::GetIP to] -force 0]
    array set opts $args

    foreach ip $opts(-ips) {
	if {[catch {
	    foreach cmd $cmdList {
		puts $ipNumTo(socket,$ip) $cmd
	    }
	}]} {
	    tk_messageBox -type ok -title [::msgcat::mc {Network Error}] \
	      -icon error -message  \
	      [FormatTextForMessageBox [::msgcat::mc messfailsend $ip]]
	}
    }
}

# P2P::FixMenusWhenHook --
#       
#       Sets the correct state for menus and buttons when 'what'.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       what        "connect", "disconnect", "disconnectserver"
#
# Results:

proc ::P2P::FixMenusWhenHook {} {
    global  prefs
    
    upvar ::WB::${wtop}::wapp wapp
    upvar ::WB::${wtop}::opts opts
    
    set mfile ${wtop}menu.file 
    set wtray $wapp(tray)
    
    switch -exact -- $what {
	connect {
	    
	    # If client only, allow only one connection, limited.
	    switch -- $prefs(protocol) {
		symmetric {
		    ::UI::MenuMethod $mfile entryconfigure mPutFile -state normal
		    ::UI::MenuMethod $mfile entryconfigure mPutCanvas -state normal
		    ::UI::MenuMethod $mfile entryconfigure mGetCanvas -state normal
		}
		client {
		    $wtray buttonconfigure connect -state disabled
		    ::UI::MenuMethod $mfile entryconfigure mOpenConnection -state disabled
		    ::UI::MenuMethod $mfile entryconfigure mPutFile -state normal
		    ::UI::MenuMethod $mfile entryconfigure mPutCanvas -state normal
		    ::UI::MenuMethod $mfile entryconfigure mGetCanvas -state normal
		}
		server {
		    ::UI::MenuMethod $mfile entryconfigure mPutFile -state normal
		    ::UI::MenuMethod $mfile entryconfigure mPutCanvas -state normal
		    ::UI::MenuMethod $mfile entryconfigure mGetCanvas -state normal
		}
		default {
		    ::UI::MenuMethod $mfile entryconfigure mOpenConnection -state disabled
		    $wtray buttonconfigure connect -state disabled
		}
	    }	    
	}
	disconnect {
	    
	    switch -- $prefs(protocol) {
		client {
		    $wtray buttonconfigure connect -state normal
		    ::UI::MenuMethod $mfile entryconfigure mOpenConnection -state normal
		}
	    }
	    
	    # If no more connections left, make menus consistent.
	    if {[llength [::Network::GetIP to]] == 0} {
		::UI::MenuMethod $mfile entryconfigure mPutFile -state disabled
		::UI::MenuMethod $mfile entryconfigure mPutCanvas -state disabled
		::UI::MenuMethod $mfile entryconfigure mGetCanvas -state disabled
	    }
	}
	disconnectserver {
		
	    # If no more connections left, make menus consistent.
	    if {[llength [::Network::GetIP to]] == 0} {
		::UI::MenuMethod $mfile entryconfigure mPutFile -state disabled
		::UI::MenuMethod $mfile entryconfigure mPutCanvas -state disabled
		::UI::MenuMethod $mfile entryconfigure mGetCanvas -state disabled
	    }
	}
    }    
    
    # Invoke any callbacks from 'addons'. 
    # Let them use their own registerd hook!!!!!!!!!!!!
}

# P2P::PutFileDlg --
#
#       Opens a file in a dialog and lets 'PutFile' do the job of transferring
#       the file to all other clients.

proc ::P2P::PutFileDlg {wtop} {
    
    if {[llength [::Network::GetIP to]] == 0} {
	return
    }
    set ans [tk_getOpenFile -title [::msgcat::mc {Put Image/Movie}] \
      -filetypes [::Plugins::GetTypeListDialogOption]]
    if {$ans == ""} {
	return
    }
    set fileName $ans
    
    # Do the actual putting once the file is chosen. 
    ::P2P::PutFileHook $wtop $fileName "all"
}

# P2P::PutFileHook --
#   
#       Transfers a file to all remote servers. It needs some negotiation to 
#       work.
#       
# Arguments:
#       wtop
#       fileName   the local path to the file to be put.
#       opts      a list of '-key value' pairs, where most keys correspond 
#                 to a valid "canvas create" option, and everything is on 
#                 a single line.
#       args:
#       -where = "remote" or "all": put only to remote clients.
#       -where = ip number: put only to this remote client.

proc ::P2P::PutFileHook {wtop fileName opts args} {
    global  prefs this
    
    Debug 2 "+PutFile:: fileName=$fileName, opts=$opts"
    
    if {[llength [::Network::GetIP to]] == 0} {
	return
    }
    array set argsArr $args
    set where all
    if {[info exists argsArr(-where)]} {
	set where $argsArr(-where)
    }
    	
    # If we are a server in a client-server we need to ask the client
    # to get the file by sending a PUT NEW instruction to it on our
    # primary connection.
    
    switch -- $prefs(protocol) {
	server {
    
	    # Translate tcl type '-key value' list to 'Key: value' option list.
	    set optList [::Import::GetTransportSyntaxOptsFromTcl $opts]
	    set relFilePath [filerelative $this(path) $fileName]
	    set relFilePath [uriencode::quotepath $relFilePath]
	    set putCmd "PUT NEW: [list $relFilePath] $optList"
	    if {$where == "remote" || $where == "all"} {
		::WB::SendGenMessageList $wtop [list $putCmd]
	    } else {
		::WB::SendGenMessageList $wtop [list $putCmd] -ips $where
	    }
	}
	default {
	    
	    # Make a list with all ip numbers to put file to.
	    switch -- $where {
		remote - all {
		    set allPutIP [::Network::GetIP to]
		}
		default {
		    set allPutIP $where
		}    
	    }
    
	    # Translate tcl type '-key value' list to 'Key: value' option list.
	    set optList [::Import::GetTransportSyntaxOptsFromTcl $opts]
	    
	    # Loop over all connected servers or only the specified one.
	    foreach ip $allPutIP {
		::PutFileIface::PutFile $wtop $fileName $ip $optList
	    }
	}
    }
}

# P2P::CancelAllPutGetAndPendingOpen ---
#
#       It is supposed to stop every put and get operation taking place.
#       This may happen when the user presses a stop button or something.
#       
# Arguments:
#
# Results:

proc ::P2P::CancelAllPutGetAndPendingOpen {wtop} {
    
    ::GetFileIface::CancelAllWtop $wtop
    ::Import::HttpResetAll $wtop
    ::OpenConnection::OpenCancelAllPending
    ::WB::SetStatusMessage $wtop {}
    ::WB::StartStopAnimatedWave $wtop 0
}

proc ::P2P::HandleGetRequest {channel ip fileName opts} {

    # A file is requested from this server. 'fileName' may be
    # a relative path so beware. This should be taken care for in
    # 'PutFileToClient'.		    
    ::PutFileIface::PutFileToClient . $channel $ip $fileName $opts
}

proc ::P2P::HandlePutRequest {channel fileName opts} {
    
    ::GetFileIface::GetFile . $channel $fileName $opts
}

# ::P2P::HandleServerCmd --
#
#       Interpret the command we just read.
#     
# Arguments:
#       channel
#       ip
#       port
#       line       Typically a canvas command.
#       args       a list of '-key value' pairs which is typically XML
#                  attributes of our XML message element (jabber only).
#
# Returns:
#       none.

proc ::P2P::HandleServerCmd {channel ip port line args} {
    global  tempChannel ipNumTo debugServerLevel   \
      clientRecord prefs this canvasSafeInterp
    
    # regexp patterns. Defined globally to speedup???
    set wrd_ {[^ ]+}
    set optwrd_ {[^ ]*}
    set optlist_ {.*}
    set any_ {.+}
    set nothing_ {}
    
    # Matches list with braces.  
    # ($llist_|$wrd_)  :should match single item list or multi item list.
    set llist_ {\{[^\}]+\}}
    set pre_ {[^/ ]+}
    set portwrd_ {[0-9]+}
    set ipnum_ {[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+}
    set int_ {[0-9]+}
    set signint_ {[-0-9]+}
    set punct {[.,;?!]}
	
    if {$debugServerLevel >= 2} {
	puts "ExecuteClientRequest:: line='$line', args='$args'"
    }
    array set attrarr $args
    if {![regexp {^([A-Z ]+): *(.*)$} $line x prefixCmd instr]} {
	return
    }
    
    # Branch into the right command prefix.
    switch -exact -- $prefixCmd {
	CANVAS {
	    if {[string length $instr] > 0} {
		::CanvasUtils::HandleCanvasDraw . $instr
	    }		
	}
	IDENTITY {
	    if {[regexp "^IDENTITY: +($portwrd_) +($pre_) +($llist_|$wrd_)$" \
	      $line junk remPort id user]} {
		
		# A client tells which server port number it has, its item prefix
		# and its user name.
		
		if {$debugServerLevel >= 2 } {
		    puts "HandleClientRequest:: IDENTITY: remPort=$remPort, \
		      id=$id, user=$user"
		}
		
		# Save port and socket for the server side in array.
		# This is done here so we are sure that it is not a temporary socket
		# for file transfer etc.
		
		set ipNumTo(servSocket,$ip) $channel
		set ipNumTo(servPort,$ip) $remPort
		
		# If user is a list remove braces.
		set ipNumTo(user,$ip) [lindex $user 0]
		set ipNumTo(connectTime,$ip) [clock seconds]
		
		# Add entry in the communication frame.
		::P2P::SetCommEntry . $ip -1 1
		::UI::MenuMethod .menu.info entryconfigure mOnClients  \
		  -state normal
		
		# Check that not own ip and user.
		if {$ip == $this(ipnum) &&   \
		  [string equal [string tolower $user]  \
		  [string tolower $this(username)]]} {
		    tk_messageBox -message [FormatTextForMessageBox  \
		      "A connecting client has chosen an ip number  \
		      and user name identical to your own."] \
		      -icon warning -type ok
		}
		
		# If auto connect, then make a connection to the client as well.
		if {[string equal $prefs(protocol) "symmetric"] &&  \
		  $prefs(autoConnect) && [lsearch [::Network::GetIP to] $ip] == -1} {
		    if {$debugServerLevel >= 2} {
			puts "HandleClientRequest:: autoConnect:  \
			  ip=$ip, name=$ipNumTo(name,$ip), remPort=$remPort"
		    }
		    
		    # Handle the complete connection process.
		    # Let propagateSizeToClients = false.
		    ::OpenConnection::DoConnect $ip $ipNumTo(servPort,$ip) 0
		} elseif {[string equal $prefs(protocol) "server"]} {
		    ::hooks::run whiteboardFixMenusWhenHook . "connect"
		}
	    }		
	}
	"IPS CONNECTED" {
	    if {[regexp "^IPS CONNECTED: +($any_|$nothing_)$" \
	      $line junk remListIPandPort]} {
		
		# A client tells which other ips it is connected to.
		# 'remListIPandPort' contains: ip1 port1 ip2 port2 ...
		
		if {$debugServerLevel >= 2 } {
		    puts "HandleClientRequest:: IPS CONNECTED:  \
		      remListIPandPort=$remListIPandPort"
		}
		
		# If multi connect then connect to all other 'remAllIPnumsTo'.
		if {[string equal $prefs(protocol) "symmetric"] &&  \
		  $prefs(multiConnect)} {
		    
		    # Make temporary array that maps ip to port.
		    array set arrayIP2Port $remListIPandPort
		    foreach ipNum [array names arrayIP2Port] {
			if {![::OpenConnection::IsConnectedToQ $ipNum]} {		
			    
			    # Handle the complete connection process.
			    # Let propagateSizeToClients = false.
			    ::OpenConnection::DoConnect $ipNum $arrayIP2Port($ipNum) 0
			}
		    }
		}
	    }		
	}
	CLIENT {
	    if {[regexp "^CLIENT: *($optlist_)$" $line match clientList]} {
		
		# Primarily for the reflector server, when one client connects,
		# the reflector srver has cached information of all other clients
		# that is transfered this way. Also used when a new client connects
		# to the reflector server.
		# Each client identifies itself with a list of 'key: value' pairs.
		
		array set arrClient $clientList
		set clientRecord($arrClient(ip:)) $clientList
	    }		
	}
	DISCONNECTED {
	    if {[regexp "^DISCONNECTED: *($ipnum_)$" $line match theIP]} {
		
		# Primarily for the reflector server, when one client disconnects.
		
		if {[info exists clientRecord($theIP)]} {
		    unset clientRecord($theIP)
		}
	    }		
	}
	"PUT NEW" {
	    if {[regexp "^PUT NEW: +($llist_|$wrd_) *($optlist_)$" \
	      $line what relFilePath optList]} {
		
		# We should open a new socket and request a GET operation on that
		# socket with the options given.
		
		# For some reason the outer {} must be stripped off.
		set relFilePath [lindex $relFilePath 0]
		::GetFileIface::GetFileFromServer . $ip $ipNumTo(servPort,$ip) \
		  $relFilePath $optList
	    }		
	}
	"GET CANVAS" {
	    if {[regexp "^GET CANVAS:" $line]} {
		
		# The present client requests to put this canvas.	
		if {$debugServerLevel >= 2} {
		    puts "--->GET CANVAS:"
		}
		set wServCan [::WB::GetServerCanvasFromWtop .]
		::CanvasCmd::DoPutCanvas $wServCan $ip
	    }		
	}
	"RESIZE IMAGE" {
	    if {[regexp "^RESIZE IMAGE: +($wrd_) +($wrd_) +($signint_)$"   \
	      $line match itOrig itNew zoomFactor]} {
		
		# Image (photo) resizing.	
		if {$debugServerLevel >= 2} {
		    puts "--->RESIZE IMAGE: itOrig=$itOrig, itNew=$itNew, \
		      zoomFactor=$zoomFactor"
		}
		::Import::ResizeImage . $zoomFactor $itOrig $itNew "local"
	    }		
	}
	default {
	    
	    # We couldn't recognize this command as our own.
	    
	}
    }
}

#-------------------------------------------------------------------------------
