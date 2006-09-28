#  P2P.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It provides the glue between the p2p mode and the whiteboard.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: P2P.tcl,v 1.28 2006-09-28 13:28:55 matben Exp $

package provide P2P 1.0


namespace eval ::P2P:: {

    # Be sure to run this after the WB init hook!
    ::hooks::register initHook            ::P2P::InitHook        80

    variable initted 0
        
    # For the communication entries.
    # variables:              $w is used as a key in these vars.
    #       nEnt              a running counter for the communication frame entries
    #                         that is *never* reused.
    #       ipNum2iEntry:     maps ip number to the entry line (nEnt) in the connect 
    #                         panel.
    variable nEnt
    variable ipNum2iEntry
    variable commTo
    variable commFrom
}

proc ::P2P::InitHook {} {
    
    ::Debug 2 "::P2P::InitHook"
    
    ::P2P::Init
    ::P2PNet::Init
}

proc ::P2P::Init {} {
    global  prefs
    variable initted
    
    # Do this only once.
    if {$initted} {
	return
    }
    ::Debug 2 "::P2P::Init"

    ::hooks::register launchFinalHook                ::P2P::LaunchFinalHook

    # Register canvas draw event handler.
    ::hooks::register whiteboardBuildEntryHook       ::P2P::BuildEntryHook
    ::hooks::register whiteboardSetMinsizeHook       ::P2P::SetMinsizeHook    
    ::hooks::register whiteboardSendMessageHook      ::P2P::SendMessageListHook
    ::hooks::register whiteboardSendGenMessageHook   ::P2P::SendGenMessageListHook
    ::hooks::register whiteboardPutFileHook          ::P2P::PutFileHook
    ::hooks::register whiteboardBuildButtonTrayHook  ::P2P::BuildButtonsHook
    ::hooks::register postInitHook                   ::P2P::PostInitHook
    ::hooks::register serverGetRequestHook           ::P2P::HandleGetRequest
    ::hooks::register serverPutRequestHook           ::P2P::HandlePutRequest
    ::hooks::register serverCmdHook                  ::P2P::HandleServerCmd

    ::hooks::register preCloseWindowHook             ::P2P::CloseHook

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook                  ::P2P::Prefs::InitPrefsHook
    ::hooks::register prefsBuildHook                 ::P2P::Prefs::BuildPrefsHook
    ::hooks::register prefsSaveHook                  ::P2P::Prefs::SavePrefsHook
    ::hooks::register prefsCancelHook                ::P2P::Prefs::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook          ::P2P::Prefs::UserDefaultsHook

    set buttonTrayDefs(symmetric) {
	connect    {::P2PNet::OpenConnection $wDlgs(openConn)}
	save       {::WB::OnMenuSaveCanvas}
	open       {::WB::OnMenuOpenCanvas}
	import     {::WB::OnMenuImport}
	send       {::CanvasCmd::DoPutCanvasDlg $w}
	print      {::WB::OnMenuPrintCanvas}
	stop       {::P2P::CancelAllPutGetAndPendingOpen $w}
    }
    set buttonTrayDefs(client) $buttonTrayDefs(symmetric)
    set buttonTrayDefs(server) $buttonTrayDefs(symmetric)
    ::WB::SetButtonTrayDefs    $buttonTrayDefs($prefs(protocol))

    set menuDefsFile {
	{command   mOpenConnection     {::UserActions::DoConnect}            O}
	{command   mCloseWindow        {::UI::CloseWindowEvent}              W}
	{separator}
	{command   mPutCanvas          {::CanvasCmd::DoPutCanvasDlg $w}      {}}
	{command   mGetCanvas          {::CanvasCmd::DoGetCanvas $w}         {}}
	{command   mPutFile            {::P2P::PutFileDlg $w}                {}}
	{command   mStopPut/Get/Open   {::P2P::CancelAllPutGetAndPendingOpen $w} {}}
	{separator}
	{command   mOpenImage/Movie    {::WB::OnMenuImport}                  I}
	{command   mOpenURLStream      {::WB::OnMenuOpenURL}                 {}}
	{separator}
	{command   mOpenCanvas         {::WB::OnMenuOpenCanvas}              {}}
	{command   mSaveCanvas         {::WB::OnMenuSaveCanvas}              S}
	{separator}
	{command   mSaveAs             {::WB::OnMenuSaveAs}                  {}}
	{command   mSaveAsItem         {::WB::OnMenuSaveAsItem}              {}}
	{command   mPageSetup          {::WB::OnMenuPageSetup}               {}}
	{command   mPrintCanvas        {::WB::OnMenuPrintCanvas}             P}
	{separator}
	{command   mQuit               {::UserActions::DoQuit}               Q}
    }
    if {[::Plugins::HavePackage QuickTimeTcl]} {
	package require Multicast
    }

    # Get any registered menu entries.
    # I don't like this solution!
    set ind [expr [lindex [lsearch -exact -all $menuDefsFile separator] end] + 1]
    set mdef [::UI::Public::GetRegisteredMenuDefs file]
    if {$mdef != {}} {
	set menuDefsFile [linsert $menuDefsFile $ind {separator}]
	set menuDefsFile [linsert $menuDefsFile $ind $mdef]
    }
    ::WB::SetMenuDefs file $menuDefsFile
    
    set initted 1
}

proc ::P2P::LaunchFinalHook { } {
    global  argvArr prefs
    
    if {[info exists argvArr(-connect)]} {
	update idletasks
	after $prefs(afterConnect) [list ::P2PNet::DoConnect  \
	  $argvArr(-connect) $prefs(remotePort)]
    }
}

proc ::P2P::GetMainWindow { } {
    global wDlgs
    
    return $wDlgs(mainwb)
}

proc ::P2P::BuildButtonsHook {wtray} {
    global  prefs

    if {[string equal $prefs(protocol) "server"]} {
	$wtray buttonconfigure connect -state disabled
    }   
}

# P2P::BuildEntryHook --
# 
#       Build the p2p specific part of the whiteboard.

proc ::P2P::BuildEntryHook {w wcomm} {
    global  prefs
    variable nEnt
    variable wp2p
      
    set nEnt($w) 0
  
    set contactOffImage [::Theme::GetImage [option get $w contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage [option get $w contactOnImage {}]]

    set fr $wcomm.f
    frame $fr
    pack  $fr -side bottom -fill x
        
    set   wgrid  $fr.grid
    ttk::frame $wgrid
    pack  $wgrid  -side left
    
    ttk::frame $fr.pad
    pack  $fr.pad  -side right -fill both -expand 1
    
    set wp2p($w,w)      $w
    set wp2p($w,wfr)    $fr
    set wp2p($w,wgrid)  $wgrid
    
    set wodb [string trim $wgrid .]
    
    option add *$wodb*TLabel.style        Small.TLabel        widgetDefault
    option add *$wodb*TCheckbutton.style  Small.TCheckbutton  widgetDefault
    option add *$wodb*TEntry.style        Small.TEntry        widgetDefault
    option add *$wodb*TEntry.font         CociSmallFont       widgetDefault

    set waddr $wgrid.comm
    set wuser $wgrid.user
    set wto   $wgrid.to
    set wfrom $wgrid.from

    switch -- $prefs(protocol) {
	symmetric {
	    ttk::label $waddr -text "Remote address:" -width 22 -anchor w
	    ttk::label $wuser -text "User:" -width 14 -anchor w
	    ttk::label $wto   -text [mc To]
	    ttk::label $wfrom -text [mc From]
	    grid  $waddr $wuser $wto $wfrom -sticky nws -padx 6 -pady 1
	}
	client {
	    ttk::label $waddr -text "Remote address:" -width 22 -anchor w
	    ttk::label $wuser -text "User:" -width 14 -anchor w
	    ttk::label $wto   -text [mc To]
	    grid  $waddr $wuser $wto -sticky nws -padx 6 -pady 1
	}
	server {
	    ttk::label $waddr -text "Remote address:" -width 22 -anchor w
	    ttk::label $wuser -text "User:" -width 14 -anchor w
	    ttk::label $wfrom -text [mc From]
	    grid  $waddr $wuser $wfrom -sticky nws -padx 6 -pady 1
	}
	central {
	    
	    # If this is a client connected to a central server, no 'from' 
	    # connections.
	    ttk::label $waddr -text "Remote address:" -width 22 -anchor w
	    ttk::label $wuser -text "User:" -width 14 -anchor w
	    ttk::label $wto   -text [mc To]
	    ttk::label $fr.icon -image $contactOffImage
	    grid  $waddr $wuser $wto $fr.icon -sticky nws -padx 6 -pady 1
	}
    }  
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
#       w
#       ipNum       the ip number.
#       to          0/1/-1 if off/on/indifferent respectively.
#       from        0/1/-1 if off/on/indifferent respectively.
#       args        '-jidvariable varName', '-validatecommand tclProc'
#                   '-dosendvariable varName'
#       
# Results:
#       updated communication frame.

proc ::P2P::SetCommEntry {w ipNum to from args} { 
    global  prefs
    
    variable commTo
    variable commFrom
    
    Debug 2 "SetCommEntry:: w=$w, ipNum=$ipNum, to=$to, from=$from, \
      args='$args'"
    
    # Need to check if already exist before adding a completely new entry.
    set alreadyThere 0
    if {[info exists commTo($w,$ipNum)]} {
	set alreadyThere 1
    } else {
	set commTo($w,$ipNum) 0		
    }
    if {[info exists commFrom($w,$ipNum)]} {
	set alreadyThere 1
    } else {
	set commFrom($w,$ipNum) 0		
    }

    Debug 2 "\t SetCommEntry:: alreadyThere=$alreadyThere, ipNum=$ipNum"
    Debug 2 "\t\t commTo($w,$ipNum)=$commTo($w,$ipNum), commFrom($w,$ipNum)=$commFrom($w,$ipNum)"

    if {$to >= 0} {
	set commTo($w,$ipNum) $to
    }
    if {$from >= 0} {
	set commFrom($w,$ipNum) $from
    }
    set toip   $commTo($w,$ipNum)
    set fromip $commFrom($w,$ipNum)
    
    # If it is not there and shouldn't be added, just return.
    if {!$alreadyThere && ($toip == 0) && ($fromip == 0)} {
	Debug 2 "\t SetCommEntry:: it is not there and shouldnt be added"
	return
    }
    
    # Update network register to contain each ip num connected to.
    if {$toip == 1} {
	::P2PNet::RegisterIP $ipNum to
    } elseif {$toip == 0} {
	::P2PNet::DeRegisterIP $ipNum to
    }
    
    # Update network register to contain each ip num connected to our server
    # from a remote client.
    if {$fromip == 1} {
	::P2PNet::RegisterIP $ipNum from
    } elseif {$fromip == 0} {
	::P2PNet::DeRegisterIP $ipNum from
    }
	
    # Build new or remove entry line.
    if {($toip == 0) && ($fromip == 0)} {

	# If both 'to' and 'from' 0, and not jabber, then remove entry.
	RemoveCommEntry $w $ipNum
    } elseif {!$alreadyThere} {
	eval {BuildCommEntry $w $ipNum} $args
    } 
}

# ::P2P::BuildCommEntry --
#
#       Makes a new entry in the communications frame.
#       Should only be called from SetCommEntry'.
#       
# Arguments:
#       w
#       ipNum       the ip number.
#       args        '-jidvariable varName', '-validatecommand cmd',
#                   '-dosendvariable varName'
#       
# Results:
#       updated communication frame with new client.

proc ::P2P::BuildCommEntry {w ipNum args} {
    global  prefs
    
    variable commTo
    variable commFrom
    variable ipNum2iEntry
    variable nEnt
    variable addr
    variable wp2p
    
    Debug 2 "BuildCommEntry:: w=$w, ipNum=$ipNum, args='$args'"

    array set argsArr $args

    set size [::UI::ParseWMGeometry [wm geometry $w]]
    set n $nEnt($w)
    set wcomm $wp2p($w,wgrid)
    set waddr $wcomm.ad${n}
    set wuser $wcomm.us${n}
    set wto   $wcomm.to${n}
    set wfrom $wcomm.from${n}
    
    # Add new status line.
    
    switch -- $prefs(protocol) {
	jabber {
	    # empty
	}
	symmetric {
	    ttk::entry $waddr -width 24  \
	      -textvariable [namespace current]::addr($w,$ipNum)
	    ttk::entry $wuser -width 16  \
	      -textvariable ::P2PNet::ipNumTo(user,$ipNum)
	    ttk::checkbutton $wto  \
	      -variable [namespace current]::commTo($w,$ipNum)   \
	      -command [list [namespace current]::CheckCommTo $w $ipNum]
	    ttk::checkbutton $wfrom  \
	      -variable [namespace current]::commFrom($w,$ipNum)
	    
	    grid $waddr $wuser $wto $wfrom -padx 6 -pady 1
	    
	    $waddr state {disabled}
	    $wuser state {disabled}
	    $wfrom state {disabled}
	}
	client {
	    ttk::entry $waddr -width 24 \
	      -textvariable [namespace current]::addr($w,$ipNum)
	    ttk::entry $wuser -width 16  \
	      -textvariable ::P2PNet::ipNumTo(user,$ipNum)
	    ttk::checkbutton $wto  \
	      -variable [namespace current]::commTo($w,$ipNum)   \
	      -command [list [namespace current]::CheckCommTo $w $ipNum]
	    
	    grid $waddr $wuser $wto -padx 6 -pady 1

	    $waddr state {disabled}
	    $wuser state {disabled}
	}
	server {
	    ttk::entry $waddr -width 24 \
	      -textvariable [namespace current]::addr($w,$ipNum)
	    ttk::entry $wuser -width 16  \
	      -textvariable ::P2PNet::ipNumTo(user,$ipNum)
	    ttk::checkbutton $wfrom -state disabled \
	      -variable [namespace current]::commFrom($w,$ipNum)

	    grid $waddr $wuser $wfrom -padx 6 -pady 1

	    $waddr state {disabled}
	    $wuser state {disabled}
	}
    }  
	
    # If no ip name given (unknown) pick ip number instead.
    if {[info exists ::P2PNet::ipNumTo(name,$ipNum)]} {
	if {[string match "*unknown*" [string tolower $::P2PNet::ipNumTo(name,$ipNum)]]} {
	    set addr($w,$ipNum) $ipNum
	} else {
	    set addr($w,$ipNum) $::P2PNet::ipNumTo(name,$ipNum)
	}
    }
    
    # Increase application height with the correct entry height.
    set entHeight [winfo reqheight $waddr]
    if {[winfo exists $wto]} {
	set checkHeight [winfo reqheight $wto]
    } else {
	set checkHeight 0
    }
    set extraHeight [max $entHeight $checkHeight]
    set newHeight [expr [lindex $size 1] + $extraHeight]

    Debug 3 "  BuildCommEntry:: nEnt=$n, size=$size, \
      entHeight=$entHeight, newHeight=$newHeight, checkHeight=$checkHeight"

    wm geometry $w [lindex $size 0]x$newHeight
    
    # Geometry considerations. Update geometry vars and set new minsize.
    after idle [list [namespace current]::SetMinsize $w]
    
    # Map ip name to nEnt.
    set ipNum2iEntry($w,$ipNum) $nEnt($w)
    
    # Step up running index. This must *never* be reused!
    incr nEnt($w)
}

# ::P2P::CheckCommTo --
#
#       This is the callback function when the checkbutton 'To' has been trigged.
#       
# Arguments:
#       w 
#       ipNum       the ip number.
#       
# Results:
#       updated communication frame.

proc ::P2P::CheckCommTo {w ipNum} {
    
    variable commTo
    
    Debug 2 "CheckCommTo:: ipNum=$ipNum"

    if {$commTo($w,$ipNum) == 0} {
	
	# Close connection.
	set res [::UI::MessageBox -message \
	  "Are you sure that you want to disconnect $::P2PNet::ipNumTo(name,$ipNum)?" \
	  -icon warning -type yesno -default yes]
	if {$res eq "no"} {
	    
	    # Reset.
	    set commTo($w,$ipNum) 1
	    return
	} elseif {$res eq "yes"} {
	    ::P2PNet::DoCloseClientConnection $ipNum
	}
    } elseif {$commTo($w,$ipNum) == 1} {
	
	# Open connection. Let propagateSizeToClients = true.
	::P2PNet::DoConnect $ipNum $::P2PNet::ipNumTo(servPort,$ipNum) 1
	SetCommEntry $w $ipNum 1 -1
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

proc ::P2P::RemoveCommEntry {w ipNum} {
    global  prefs
    
    variable commTo
    variable commFrom
    variable ipNum2iEntry
    variable wp2p
    
    # Find widget paths from ipNum and remove the entries.
    set n $ipNum2iEntry($w,$ipNum)

    Debug 2 "RemoveCommEntry:: n=$n"
    
    set wcomm $wp2p($w,wgrid)
    set waddr ${wcomm}.ad${n}
    set wuser ${wcomm}.us${n}
    set wto   ${wcomm}.to${n}
    set wfrom ${wcomm}.from${n}
    
    # Decrease the toplevels height by the entry lines height.
    array set infoArr [grid info $waddr]
    foreach {width height x y} [::UI::ParseWMGeometry [wm geometry $w]] break
    foreach {xoff yoff ewidth eheight}  \
      [grid bbox $wp2p($w,wgrid) $infoArr(-column) $infoArr(-row)] break
    #puts "height=$height, eheight=$eheight"

    # Remove the widgets.
    catch {grid forget $waddr $wuser $wto $wfrom}
    catch {destroy $waddr $wuser $wto $wfrom}
    
    wm geometry $w ${width}x[expr $height - $eheight]
    
    # These variables must be unset to indicate that entry does not exists.
    unset -nocomplain commTo($w,$ipNum) commFrom($w,$ipNum)
    
    # Geometry considerations. Update geometry vars and set new minsize.
    after idle [list [namespace current]::SetMinsize $w]
}

proc ::P2P::SetMinsizeHook {w} {
    
    after idle ::P2P::SetMinsize $w
}

proc ::P2P::SetMinsize {w} {
    variable wp2p

    foreach {wMin hMin} [::WB::GetBasicWhiteboardMinsize $w] break

    # Add the communication entries.
    set wMinEntry [winfo reqheight $wp2p($w,wfr)]
    set hMinEntry [winfo reqheight $wp2p($w,wfr)]
    set wMin [expr $wMin + $wMinEntry]
    set hMin [expr $hMin + $hMinEntry]
    
    wm minsize $w $wMin $hMin
}

proc ::P2P::CloseHook {wclose} {
    global  wDlgs
    variable wp2p
    
    if {$wclose == $wDlgs(mainwb)} {
	set win $wDlgs(mainwb)

	Debug 4 "::P2P::CloseHook"
	
	# Must save "clean" size without any user entries.
	lassign [::UI::ParseWMGeometry [wm geometry $win]] w h x y
	lassign [grid bbox $wp2p($win,wgrid) 0 1 0 9] xoff yoff width height
	::UI::SaveWinGeomUseSize $win ${w}x[expr $h-$height]+${x}+${y}
	
	if {![::UserActions::DoQuit -warning 1]} {
	    return stop
	}
    }      
}

# P2P::SendMessageListHook --
#
#       Sends to command to whoever we are connected to.
#   
# Arguments:
#       w
#       msgList     list of commands to send.
#       args   ?-key value ...?
#       -ips         (D=all ips) send to this list of ip numbers. 
#                    Not for jabber.
#       -force 0|1  (D=1) overrides the doSend checkbutton in jabber.
#       
# Results:
#       none

proc ::P2P::SendMessageListHook {w msgList args} {
    global  prefs
    
    array set opts [list -ips [::P2PNet::GetIP to] -force 0]
    array set opts $args

    foreach ip $opts(-ips) {
	if {[catch {
	    foreach cmd $msgList {
		puts $::P2PNet::ipNumTo(socket,$ip) "CANVAS: $cmd"
	    }
	}]} {
	    ::UI::MessageBox -type ok -title [mc {Network Error}] \
	      -icon error -message [mc messfailsend $ip]
	}
    }
}

# P2P::SendGenMessageListHook --
# 
#       As above but allows any prefix.

proc ::P2P::SendGenMessageListHook {w msgList args} {
    global  prefs
    
    array set opts [list -ips [::P2PNet::GetIP to] -force 0]
    array set opts $args

    foreach ip $opts(-ips) {
	if {[catch {
	    foreach cmd $msgList {
		puts $::P2PNet::ipNumTo(socket,$ip) $cmd
	    }
	}]} {
	    ::UI::MessageBox -type ok -title [mc {Network Error}] \
	      -icon error -message [mc messfailsend $ip]
	}
    }
}

# P2P::FixMenusWhenHook --
#       
#       Sets the correct state for menus and buttons when 'what'.
#       
# Arguments:
#       w           toplevel widget path
#       what        "connect", "disconnect", "disconnectserver"
#
# Results:

proc ::P2P::FixMenusWhenHook {w what} {
    global  prefs

    set mfile [::WB::GetMenu $w].file 
    set wtray [::WB::GetButtonTray $w]
    
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
	    #  ????????
	    if {[llength [::P2PNet::GetIP to]] == 0} {
		::UI::MenuMethod $mfile entryconfigure mPutFile -state disabled
		::UI::MenuMethod $mfile entryconfigure mPutCanvas -state disabled
		::UI::MenuMethod $mfile entryconfigure mGetCanvas -state disabled
	    }
	}
	disconnectserver {
		
	    # If no more connections left, make menus consistent.
	    # ??????????
	    if {[llength [::P2PNet::GetIP to]] == 0} {
		::UI::MenuMethod $mfile entryconfigure mPutFile -state disabled
		::UI::MenuMethod $mfile entryconfigure mPutCanvas -state disabled
		::UI::MenuMethod $mfile entryconfigure mGetCanvas -state disabled
	    }
	}
    }    
    
    # Invoke any callbacks from 'components'. 
    # Let them use their own registerd hook!!!!!!!!!!!!
}

# P2P::PutFileDlg --
#
#       Opens a file in a dialog and lets 'PutFile' do the job of transferring
#       the file to all other clients.

proc ::P2P::PutFileDlg {w} {
    
    if {[llength [::P2PNet::GetIP to]] == 0} {
	return
    }
    set ans [tk_getOpenFile -title [mc {Put Image/Movie}] \
      -filetypes [::Plugins::GetTypeListDialogOption]]
    if {$ans eq ""} {
	return
    }
    set fileName $ans
    
    # Do the actual putting once the file is chosen. 
    PutFileHook $w $fileName "all"
}

# P2P::PutFileHook --
#   
#       Transfers a file to all remote servers. It needs some negotiation to 
#       work.
#       
# Arguments:
#       w
#       fileName   the local path to the file to be put.
#       opts      a list of '-key value' pairs, where most keys correspond 
#                 to a valid "canvas create" option, and everything is on 
#                 a single line.
#       args:
#       -where = "remote" or "all": put only to remote clients.
#       -where = ip number: put only to this remote client.

proc ::P2P::PutFileHook {w fileName opts args} {
    global  prefs this
    
    Debug 2 "+PutFile:: fileName=$fileName, opts=$opts"
    
    if {[llength [::P2PNet::GetIP to]] == 0} {
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
	    set relFilePath [::tfileutils::relative $this(path) $fileName]
	    set relFilePath [uriencode::quotepath $relFilePath]
	    set putCmd "PUT NEW: [list $relFilePath] $optList"
	    if {$where eq "remote" || $where eq "all"} {
		::WB::SendGenMessageList $w [list $putCmd]
	    } else {
		::WB::SendGenMessageList $w [list $putCmd] -ips $where
	    }
	}
	default {
	    
	    # Make a list with all ip numbers to put file to.
	    switch -- $where {
		remote - all {
		    set allPutIP [::P2PNet::GetIP to]
		}
		default {
		    set allPutIP $where
		}    
	    }
    
	    # Translate tcl type '-key value' list to 'Key: value' option list.
	    set optList [::Import::GetTransportSyntaxOptsFromTcl $opts]
	    
	    # Loop over all connected servers or only the specified one.
	    foreach ip $allPutIP {
		::PutFileIface::PutFile $w $fileName $ip $optList
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

proc ::P2P::CancelAllPutGetAndPendingOpen {w} {
    
    ::GetFileIface::CancelAllWtop $w
    ::Import::HttpResetAll $w
    ::P2PNet::OpenCancelAllPending
    ::WB::SetStatusMessage $w ""
    ::WB::StartStopAnimatedWave $w 0
}

proc ::P2P::HandleGetRequest {channel ip fileName opts} {
    global  wDlgs

    # A file is requested from this server. 'fileName' may be
    # a relative path so beware. This should be taken care for in
    # 'PutFileToClient'.		    
    ::PutFileIface::PutFileToClient $wDlgs(mainwb) $channel $ip $fileName $opts
}

proc ::P2P::HandlePutRequest {channel fileName opts} {
    global  wDlgs
    
    ::GetFileIface::GetFile $wDlgs(mainwb) $channel $fileName $opts
}

proc ::P2P::PostInitHook { } {
    
    ::P2P::GetRegisteredHandlers
}
# ::P2P::GetRegisteredHandlers --
# 
#       Get protocol handlers, present and future.

proc ::P2P::GetRegisteredHandlers { } {
    variable handler
    
    array set handler [::WB::GetRegisteredHandlers]
    ::hooks::register whiteboardRegisterHandlerHook  ::P2P::RegisterHandlerHook
}

proc ::P2P::RegisterHandlerHook {prefix cmd} {
    variable handler
    
    set handler($prefix) $cmd
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
    global  clientRecord prefs this wDlgs

    variable handler
    
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
	
    ::Debug 2 "ExecuteClientRequest:: line='$line', args='$args'"

    array set attrarr $args
    if {![regexp {^([A-Z ]+): *(.*)$} $line x prefix instr]} {
	return
    }
    
    # Branch into the right command prefix.
    switch -exact -- $prefix {
	CANVAS {
	    if {[string length $instr] > 0} {
		::CanvasUtils::HandleCanvasDraw $wDlgs(mainwb) $instr
	    }		
	}
	IDENTITY {
	    if {[regexp "^IDENTITY: +($portwrd_) +($pre_) +($llist_|$wrd_)$" \
	      $line junk remPort id user]} {
		
		# A client tells which server port number it has, its item prefix
		# and its user name.
		
		# Save port and socket for the server side in array.
		# This is done here so we are sure that it is not a temporary socket
		# for file transfer etc.
		
		set ::P2PNet::ipNumTo(servSocket,$ip) $channel
		set ::P2PNet::ipNumTo(servPort,$ip) $remPort
		
		# If user is a list remove braces.
		set ::P2PNet::ipNumTo(user,$ip) [lindex $user 0]
		set ::P2PNet::ipNumTo(connectTime,$ip) [clock seconds]
		
		# Add entry in the communication frame.
		set wmenu [::UI::GetMainMenu]
		::P2P::SetCommEntry $wDlgs(mainwb) $ip -1 1
		::UI::MenuMethod $wmenu.info entryconfigure mOnClients  \
		  -state normal
		
		# Check that not own ip and user.
		if {$ip == $this(ipnum) &&   \
		  [string equal [string tolower $user]  \
		  [string tolower $this(username)]]} {
		    ::UI::MessageBox -message  \
		      "A connecting client has chosen an ip number  \
		      and user name identical to your own." \
		      -icon warning -type ok
		}
		
		# If auto connect, then make a connection to the client as well.
		if {[string equal $prefs(protocol) "symmetric"] &&  \
		  $prefs(autoConnect) && [lsearch [::P2PNet::GetIP to] $ip] == -1} {
		    
		    # Handle the complete connection process.
		    # Let propagateSizeToClients = false.
		    ::P2PNet::DoConnect $ip $::P2PNet::ipNumTo(servPort,$ip) 0
		} elseif {[string equal $prefs(protocol) "server"]} {
		    ::hooks::run whiteboardFixMenusWhenHook $wDlgs(mainwb) "connect"
		}
	    }		
	}
	"IPS CONNECTED" {
	    if {[regexp "^IPS CONNECTED: +($any_|$nothing_)$" \
	      $line junk remListIPandPort]} {
		
		# A client tells which other ips it is connected to.
		# 'remListIPandPort' contains: ip1 port1 ip2 port2 ...
		
		# If multi connect then connect to all other 'remAllIPnumsTo'.
		if {[string equal $prefs(protocol) "symmetric"] &&  \
		  $prefs(multiConnect)} {
		    
		    # Make temporary array that maps ip to port.
		    array set arrayIP2Port $remListIPandPort
		    foreach ipNum [array names arrayIP2Port] {
			if {![::P2PNet::IsConnectedToQ $ipNum]} {		
			    
			    # Handle the complete connection process.
			    # Let propagateSizeToClients = false.
			    ::P2PNet::DoConnect $ipNum $arrayIP2Port($ipNum) 0
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
		::GetFileIface::GetFileFromServer $wDlgs(mainwb) $ip $::P2PNet::ipNumTo(servPort,$ip) \
		  $relFilePath $optList
	    }		
	}
	"GET CANVAS" {
	    if {[regexp "^GET CANVAS:" $line]} {
		
		# The present client requests to put this canvas.	
		::Debug 2 "--->GET CANVAS:"
		set wServCan [::WB::GetServerCanvasFromWtop [GetMainWindow]]
		::CanvasCmd::DoPutCanvas $wServCan $ip
	    }		
	}
	"RESIZE IMAGE" {
	    if {[regexp "^RESIZE IMAGE: +($wrd_) +($wrd_) +($signint_)$"   \
	      $line match itOrig itNew zoomFactor]} {
		
		# Image (photo) resizing.	
		::Debug 2 "--->RESIZE IMAGE: itOrig=$itOrig, itNew=$itNew, \
		  zoomFactor=$zoomFactor"
		::Import::ResizeImage $wDlgs(mainwb) $zoomFactor $itOrig $itNew "local"
	    }		
	}
	default {
	    if {[info exists handler($prefix)]} {
		set wServCan [::WB::GetServerCanvasFromWtop [GetMainWindow]]
		set code [catch {
		    uplevel #0 $handler($prefix) [list $wServCan p2p $line] $args
		} ans]
	    }
	}
    }
}

# Preference page --------------------------------------------------------------

namespace eval ::P2P::Prefs:: { 
    
    variable finished
}

proc ::P2P::Prefs::InitPrefsHook { } {
    global  prefs

    ::PrefUtils::Add [list  \
      [list prefs(shortcuts)  prefs_shortcuts  $prefs(shortcuts)  userDefault]]
}

proc ::P2P::Prefs::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {General Shortcuts} [mc Shortcuts]
    
    set wpage [$nbframe page {Shortcuts}]    
    ::P2P::Prefs::BuildPrefsPage $wpage
}

proc ::P2P::Prefs::BuildPrefsPage {wpage} {
    global  prefs
    
    variable btadd
    variable btrem
    variable btedit
    variable wlbox
    variable shortListVar
    variable tmpPrefs
    
    set tmpPrefs(shortcuts) $prefs(shortcuts)
        
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set wcont $wc.ca
    ttk::labelframe $wcont -text [mc {Edit Shortcuts}] \
      -padding [option get . groupSmallPadding {}]
    pack  $wcont  -side top -fill x
    
    ttk::label $wcont.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text [mc prefshortcut]
    pack $wcont.msg -side top
    
    # Frame for listbox and scrollbar.
    set frlist [frame $wcont.lst]
    
    # The listbox.
    set wsb $frlist.sb
    set shortListVar {}
    foreach pair $tmpPrefs(shortcuts) {
	lappend shortListVar [lindex $pair 0]
    }
    set wlbox $frlist.lb
    listbox $wlbox -height 10 -width 18   \
      -listvar [namespace current]::shortListVar \
      -yscrollcommand [list $wsb set] -selectmode extended
    ttk::scrollbar $wsb -command [list $wlbox yview]
    pack  $wlbox  -side left -fill both
    pack  $wsb    -side left -fill both
    pack  $frlist -side left
    
    # Buttons at the right side.
    set frbt $wcont.btfr
    ttk::frame $frbt
    set btadd  $frbt.btadd
    set btrem  $frbt.btrem
    set btedit $frbt.btedit
    ttk::button $btadd -text "[mc Add]..."  \
      -command [list [namespace current]::AddOrEdit add]
    ttk::button $btrem -text [mc Remove]  \
      -command [namespace current]::Remove
    ttk::button $btedit -text "[mc Edit]..."  \
      -command [list [namespace current]::AddOrEdit edit]

    pack  $frbt  -side top -anchor w
    pack  $btadd  $btrem  $btedit  -side top -fill x -padx 4 -pady 4
    
    $btrem  state {disabled}
    $btedit state {disabled}
	
    # Listbox bindings.
    bind $wlbox <Button-1> {+ focus %W}
    bind $wlbox <Double-Button-1> [list $btedit invoke]
    bind $wlbox <<ListboxSelect>> [list [namespace current]::SelectCmd]
}

proc ::P2P::Prefs::SelectCmd { } {

    variable btadd
    variable btrem
    variable btedit
    variable wlbox

    if {[llength [$wlbox curselection]]} {
	$btrem state {!disabled}
    } else {
	$btrem  state {disabled}
	$btedit state {disabled}
    }
    if {[llength [$wlbox curselection]] == 1} {
	$btedit state {!disabled}
    }
}

proc ::P2P::Prefs::Remove { } {
    
    variable wlbox
    variable shortListVar
    variable tmpPrefs

    set selInd [$wlbox curselection]
    if {[llength $selInd]} {
	foreach ind [lsort -integer -decreasing $selInd] {
	    set shortListVar [lreplace $shortListVar $ind $ind]
	    set tmpPrefs(shortcuts) [lreplace $tmpPrefs(shortcuts) $ind $ind]
	}
    }
}

# ::P2P::Prefs::AddOrEdit --
#
#       Callback when the "add" or "edit" buttons pushed. New toplevel dialog
#       for editing an existing shortcut, or adding a fresh one.
#
# Arguments:
#       what           "add" or "edit".
#       
# Results:
#       shows dialog.

proc ::P2P::Prefs::AddOrEdit {what} {
    global  this
    
    variable wlbox
    variable finAdd
    variable shortListVar
    variable shortTextVar
    variable longTextVar
    variable tmpPrefs
    
    Debug 2 "::P2P::Prefs::AddOrEdit"

    set indShortcuts [lindex [$wlbox curselection] 0]
    if {$what eq "edit" && $indShortcuts eq ""} {
	return
    } 
    set w .taddshorts$what
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    if {$what eq "add"} {
	set txt [mc {Add Shortcut}]
	set txt1 "[mc {New shortcut}]:"
	set txt2 "[mc prefshortip]:"
	set txtbt [mc Add]
	set shortTextVar {}
	set longTextVar {}
    } elseif {$what eq "edit"} {
	set txt [mc {Edit Shortcut}]
	set txt1 "[mc Shortcut]:"
	set txt2 "[mc prefshortip]:"
	set txtbt [mc Save]
    }
    set finAdd 0
    wm title $w $txt
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set wcont $wbox.f
    ttk::labelframe $wcont -text $txt -padding [option get . groupPadding {}]
    pack $wcont -side top

    ttk::label $wcont.lbl1 -text $txt1
    ttk::entry $wcont.ent1 -width 36 -textvariable [namespace current]::shortTextVar
    ttk::label $wcont.lbl2 -text $txt2
    ttk::entry $wcont.ent2 -width 36 -textvariable [namespace current]::longTextVar
    
    grid  $wcont.lbl1  -sticky w  -pady 1
    grid  $wcont.ent1  -sticky ew -pady 1
    grid  $wcont.lbl2  -sticky w  -pady 1
    grid  $wcont.ent2  -sticky ew -pady 1
    
    focus $wcont.ent1
    
    # Get the short pair to edit.
    if {[string equal $what "edit"]} {
	set shortTextVar [lindex $tmpPrefs(shortcuts) $indShortcuts 0]
	set longTextVar  [lindex $tmpPrefs(shortcuts) $indShortcuts 1]
    } elseif {[string equal $what "add"]} {
	
    }
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text $txtbt -default active  \
      -command [list [namespace current]::PushBtAddOrEdit $what]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list set [namespace current]::finAdd 2]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    bind $w <Return> [list $w.frbot.bt1 invoke]
    wm resizable $w 0 0
    
    # Grab and focus.
    focus $w
    catch {grab $w}
    tkwait variable [namespace current]::finAdd
    
    catch {grab release $w}
    destroy $w
}

proc ::P2P::Prefs::PushBtAddOrEdit {what} {
    variable wlbox
    variable finAdd
    variable shortListVar
    variable shortTextVar
    variable longTextVar
    variable tmpPrefs

    if {($shortTextVar eq "") || ($longTextVar eq "")} {
	set finAdd 1
	return
    }
    if {$what eq "add"} {
 
	# Save shortcuts in listbox.
	lappend shortListVar $shortTextVar
	lappend tmpPrefs(shortcuts) [list $shortTextVar $longTextVar]
    } else {
	
	# Edit. Replace old with new.
	set ind [lindex [$wlbox curselection] 0]
	set shortListVar [lreplace $shortListVar $ind $ind $shortTextVar]
	set tmpPrefs(shortcuts) [lreplace $tmpPrefs(shortcuts) $ind $ind   \
	  [list $shortTextVar $longTextVar]]
    }
    set finAdd 1
}

proc ::P2P::Prefs::SavePrefsHook { } {
    global  prefs
    variable tmpPrefs
    
    array set prefs [array get tmpPrefs]
    unset tmpPrefs
}

proc ::P2P::Prefs::CancelPrefsHook { } {
    global  prefs
    variable tmpPrefs
	
    foreach key [array names tmpPrefs] {
	if {![string equal $prefs($key) $tmpPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::P2P::Prefs::UserDefaultsHook { } {
    global  prefs
    variable tmpPrefs
	
    foreach key [array names tmpPrefs] {
	set tmpPrefs($key) $prefs($key)
    }
}

#-------------------------------------------------------------------------------
