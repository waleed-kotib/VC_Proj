#  P2P.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It provides the glue between the p2p mode and the whiteboard.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: P2P.tcl,v 1.19 2004-12-02 08:22:34 matben Exp $

package provide P2P 1.0


namespace eval ::P2P:: {

    # Be sure to run this after the WB init hook!
    ::hooks::register initHook            ::P2P::InitHook        80

    variable initted 0
        
    # For the communication entries.
    # variables:              $wtop is used as a key in these vars.
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
    
    ::Debug 2 "::P2P::Init"
    
    # Register canvas draw event handler.
    ::hooks::register whiteboardBuildEntryHook       ::P2P::BuildEntryHook
    ::hooks::register whiteboardSetMinsizeHook       ::P2P::SetMinsizeHook    
    ::hooks::register whiteboardFixMenusWhenHook     ::P2P::FixMenusWhenHook
    ::hooks::register whiteboardSendMessageHook      ::P2P::SendMessageListHook
    ::hooks::register whiteboardSendGenMessageHook   ::P2P::SendGenMessageListHook
    ::hooks::register whiteboardPutFileHook          ::P2P::PutFileHook
    ::hooks::register whiteboardBuildButtonTrayHook  ::P2P::BuildButtonsHook
    ::hooks::register postInitHook                   ::P2P::PostInitHook
    ::hooks::register serverGetRequestHook           ::P2P::HandleGetRequest
    ::hooks::register serverPutRequestHook           ::P2P::HandlePutRequest
    ::hooks::register serverCmdHook                  ::P2P::HandleServerCmd

    ::hooks::register closeWindowHook                ::P2P::CloseHook
    ::hooks::register quitAppHook                    ::P2P::QuitHook

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook                  ::P2P::Prefs::InitPrefsHook
    ::hooks::register prefsBuildHook                 ::P2P::Prefs::BuildPrefsHook
    ::hooks::register prefsSaveHook                  ::P2P::Prefs::SavePrefsHook
    ::hooks::register prefsCancelHook                ::P2P::Prefs::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook          ::P2P::Prefs::UserDefaultsHook

    set buttonTrayDefs(symmetric) {
	connect    {::P2PNet::OpenConnection $wDlgs(openConn)}
	save       {::CanvasFile::Save $wtop}
	open       {::CanvasFile::OpenCanvasFileDlg $wtop}
	import     {::Import::ImportImageOrMovieDlg $wtop}
	send       {::CanvasCmd::DoPutCanvasDlg $wtop}
	print      {::UserActions::DoPrintCanvas $wtop}
	stop       {::P2P::CancelAllPutGetAndPendingOpen $wtop}
    }
    set buttonTrayDefs(client) $buttonTrayDefs(symmetric)
    set buttonTrayDefs(server) $buttonTrayDefs(symmetric)
    ::WB::SetButtonTrayDefs    $buttonTrayDefs($prefs(protocol))

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
	{command   mOpenURLStream      {::Multicast::OpenMulticast $wtop}     normal   {}}
	{separator}
	{command   mOpenCanvas         {::CanvasFile::OpenCanvasFileDlg $wtop}     normal   {}}
	{command   mSaveCanvas         {::CanvasFile::Save $wtop}             normal   S}
	{separator}
	{command   mSaveAs             {::CanvasFile::SaveAsDlg $wtop}        normal   {}}
	{command   mSaveAsItem         {::CanvasCmd::DoSaveAsItem $wtop}      normal   {}}
	{command   mPageSetup          {::UserActions::PageSetup $wtop}           normal   {}}
	{command   mPrintCanvas        {::UserActions::DoPrintCanvas $wtop}       normal   P}
	{separator}
	{command   mQuit               {::UserActions::DoQuit}                    normal   Q}
    }
    if {![::Plugins::HavePackage QuickTimeTcl]} {
	lset menuDefsFile 4 3 disabled
    } else {
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

proc ::P2P::BuildButtonsHook {wtray} {
    global  prefs

    if {[string equal $prefs(protocol) "server"]} {
	$wtray buttonconfigure connect -state disabled
    }   
}

# P2P::BuildEntryHook --
# 
#       Build the p2p specific part of the whiteboard.

proc ::P2P::BuildEntryHook {wtop wclass wcomm} {
    global  prefs
    variable nEnt
    variable wp2p
      
    set nEnt($wtop) 0
  
    set contactOffImage [::Theme::GetImage [option get $wclass contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage [option get $wclass contactOnImage {}]]

    set   fr ${wcomm}.f
    frame $fr -relief raised -borderwidth 1
    pack  $fr -side bottom -fill x
    
    set   wgrid  ${fr}.grid
    frame $wgrid -relief flat -borderwidth 0
    pack  $wgrid -side left
    
    set wp2p($wtop,wclass) $wclass
    set wp2p($wtop,wfr)    $fr
    set wp2p($wtop,wgrid)  $wgrid

    set waddr ${wgrid}.comm
    set wuser ${wgrid}.user
    set wto   ${wgrid}.to
    set wfrom ${wgrid}.from

    switch -- $prefs(protocol) {
	symmetric {
	    label $waddr -text {  Remote address:} -width 22 -anchor w
	    label $wuser -text {  User:} -width 14 -anchor w
	    label $wto   -text [mc To]
	    label $wfrom -text [mc From]
	    grid  $waddr $wuser $wto $wfrom -sticky nws -pady 0
	}
	client {
	    label $waddr -text {  Remote address:} -width 22 -anchor w
	    label $wuser -text {  User:} -width 14 -anchor w
	    label $wto   -text [mc To]
	    grid  $waddr $wuser $wto -sticky nws -pady 0
	}
	server {
	    label $waddr -text {  Remote address:} -width 22 -anchor w
	    label $wuser -text {  User:} -width 14 -anchor w
	    label $wfrom -text [mc From]
	    grid  $waddr $wuser $wfrom -sticky nws -pady 0
	}
	central {
	    
	    # If this is a client connected to a central server, no 'from' 
	    # connections.
	    label $waddr -text {  Remote address:} -width 22 -anchor w
	    label $wuser -text {  User:} -width 14 -anchor w
	    label $wto   -text [mc To]
	    label $fr.icon -image $contactOffImage
	    grid  $waddr $wuser $wto $fr.icon -sticky nws -pady 0
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

    Debug 2 "\t SetCommEntry:: alreadyThere=$alreadyThere, ipNum=$ipNum"
    Debug 2 "\t\t commTo($wtop,$ipNum)=$commTo($wtop,$ipNum), commFrom($wtop,$ipNum)=$commFrom($wtop,$ipNum)"

    if {$to >= 0} {
	set commTo($wtop,$ipNum) $to
    }
    if {$from >= 0} {
	set commFrom($wtop,$ipNum) $from
    }
    set toip   $commTo($wtop,$ipNum)
    set fromip $commFrom($wtop,$ipNum)
    
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
    global  prefs
    
    variable commTo
    variable commFrom
    variable ipNum2iEntry
    variable nEnt
    variable addr
    variable wp2p
    
    Debug 2 "BuildCommEntry:: wtop=$wtop, ipNum=$ipNum, args='$args'"

    array set argsArr $args
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
	
    set size [::UI::ParseWMGeometry [wm geometry $w]]
    set n $nEnt($wtop)
    set wcomm $wp2p($wtop,wgrid)
    set waddr ${wcomm}.ad${n}
    set wuser ${wcomm}.us${n}
    set wto   ${wcomm}.to${n}
    set wfrom ${wcomm}.from${n}
    
    # Add new status line.
    
    switch -- $prefs(protocol) {
	jabber {
	    # empty
	}
	symmetric {
	    entry $waddr -width 24 -relief sunken -state disabled \
	      -textvariable [namespace current]::addr($wtop,$ipNum)
	    entry $wuser -width 16 -state disabled  \
	      -textvariable ::P2PNet::ipNumTo(user,$ipNum) -relief sunken
	    checkbutton $wto -highlightthickness 0 \
	      -variable [namespace current]::commTo($wtop,$ipNum)   \
	      -command [list [namespace current]::CheckCommTo $wtop $ipNum]
	    checkbutton $wfrom -highlightthickness 0 -state disabled \
	      -variable [namespace current]::commFrom($wtop,$ipNum)
	    grid $waddr $wuser $wto $wfrom -padx 4 -pady 0
	}
	client {
	    entry $waddr -width 24 -relief sunken -state disabled \
	      -textvariable [namespace current]::addr($wtop,$ipNum)
	    entry $wuser -width 16 -relief sunken -state disabled  \
	      -textvariable ::P2PNet::ipNumTo(user,$ipNum)
	    checkbutton $wto -highlightthickness 0  \
	      -variable [namespace current]::commTo($wtop,$ipNum)   \
	      -command [list [namespace current]::CheckCommTo $wtop $ipNum]
	    grid $waddr $wuser $wto -padx 4 -pady 0
	}
	server {
	    entry $waddr -width 24 -relief sunken -state disabled \
	      -textvariable [namespace current]::addr($wtop,$ipNum)
	    entry $wuser -width 16 -relief sunken -state disabled  \
	      -textvariable ::P2PNet::ipNumTo(user,$ipNum)
	    checkbutton $wfrom -highlightthickness 0 -state disabled \
	      -variable [namespace current]::commFrom($wtop,$ipNum)
	    grid $waddr $wuser $wfrom -padx 4 -pady 0
	}
    }  
	
    # If no ip name given (unknown) pick ip number instead.
    if {[info exists ::P2PNet::ipNumTo(name,$ipNum)]} {
	if {[string match "*unknown*" [string tolower $::P2PNet::ipNumTo(name,$ipNum)]]} {
	    set addr($wtop,$ipNum) $ipNum
	} else {
	    set addr($wtop,$ipNum) $::P2PNet::ipNumTo(name,$ipNum)
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
    after idle [list [namespace current]::SetMinsize $wtop]
    
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
    
    variable commTo
    
    Debug 2 "CheckCommTo:: ipNum=$ipNum"

    if {$commTo($wtop,$ipNum) == 0} {
	
	# Close connection.
	set res [::UI::MessageBox -message \
	  "Are you sure that you want to disconnect $::P2PNet::ipNumTo(name,$ipNum)?" \
	  -icon warning -type yesno -default yes]
	if {$res == "no"} {
	    
	    # Reset.
	    set commTo($wtop,$ipNum) 1
	    return
	} elseif {$res == "yes"} {
	    ::P2PNet::DoCloseClientConnection $ipNum
	}
    } elseif {$commTo($wtop,$ipNum) == 1} {
	
	# Open connection. Let propagateSizeToClients = true.
	::P2PNet::DoConnect $ipNum $::P2PNet::ipNumTo(servPort,$ipNum) 1
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
    
    variable commTo
    variable commFrom
    variable ipNum2iEntry
    variable wp2p
    
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    
    # Find widget paths from ipNum and remove the entries.
    set n $ipNum2iEntry($wtop,$ipNum)

    Debug 2 "RemoveCommEntry:: n=$n"
    
    set wcomm $wp2p($wtop,wgrid)
    set waddr ${wcomm}.ad${n}
    set wuser ${wcomm}.us${n}
    set wto   ${wcomm}.to${n}
    set wfrom ${wcomm}.from${n}
    
    # Decrease the toplevels height by the entry lines height.
    array set infoArr [grid info $waddr]
    foreach {width height x y} [::UI::ParseWMGeometry [wm geometry $w]] break
    foreach {xoff yoff ewidth eheight}  \
      [grid bbox $wp2p($wtop,wgrid) $infoArr(-column) $infoArr(-row)] break
    #puts "height=$height, eheight=$eheight"

    # Remove the widgets.
    catch {grid forget $waddr $wuser $wto $wfrom}
    catch {destroy $waddr $wuser $wto $wfrom}
    
    wm geometry $w ${width}x[expr $height - $eheight]
    
    # These variables must be unset to indicate that entry does not exists.
    unset -nocomplain commTo($wtop,$ipNum) commFrom($wtop,$ipNum)
    
    # Geometry considerations. Update geometry vars and set new minsize.
    after idle [list [namespace current]::SetMinsize $wtop]
}

proc ::P2P::SetMinsizeHook {wtop} {
    
    after idle ::P2P::SetMinsize $wtop
}

proc ::P2P::SetMinsize {wtop} {
    variable wp2p

    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    
    foreach {wMin hMin} [::WB::GetBasicWhiteboardMinsize $wtop] break

    # Add the communication entries.
    set wMinEntry [winfo reqheight $wp2p($wtop,wfr)]
    set hMinEntry [winfo reqheight $wp2p($wtop,wfr)]
    set wMin [expr $wMin + $wMinEntry]
    set hMin [expr $hMin + $hMinEntry]
    
    wm minsize $w $wMin $hMin
}

proc ::P2P::CloseHook {wclose} {
    variable wp2p
    
    if {$wclose == "."} {
	
	# Must save "clean" size without any user entries.
	foreach {w h x y} [::UI::ParseWMGeometry [wm geometry .]] break
	foreach {xoff yoff width height} [grid bbox $wp2p(.,wgrid) 0 1 0 9] break
	::UI::SaveWinGeomUseSize . ${w}x[expr $h-$height]+${x}+${y}
    }      
}

proc ::P2P::QuitHook { } {
    
    ::P2P::CloseHook .
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

proc ::P2P::SendGenMessageListHook {wtop msgList args} {
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
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       what        "connect", "disconnect", "disconnectserver"
#
# Results:

proc ::P2P::FixMenusWhenHook {wtop what} {
    global  prefs
    
    set mfile [::WB::GetMenu $wtop].file 
    set wtray [::WB::GetButtonTray $wtop]
    
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

proc ::P2P::PutFileDlg {wtop} {
    
    if {[llength [::P2PNet::GetIP to]] == 0} {
	return
    }
    set ans [tk_getOpenFile -title [mc {Put Image/Movie}] \
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
    ::P2PNet::OpenCancelAllPending
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
    global  clientRecord prefs this

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
		::CanvasUtils::HandleCanvasDraw . $instr
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
		::P2P::SetCommEntry . $ip -1 1
		::UI::MenuMethod .menu.info entryconfigure mOnClients  \
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
		    ::hooks::run whiteboardFixMenusWhenHook . "connect"
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
		::GetFileIface::GetFileFromServer . $ip $::P2PNet::ipNumTo(servPort,$ip) \
		  $relFilePath $optList
	    }		
	}
	"GET CANVAS" {
	    if {[regexp "^GET CANVAS:" $line]} {
		
		# The present client requests to put this canvas.	
		::Debug 2 "--->GET CANVAS:"
		set wServCan [::WB::GetServerCanvasFromWtop .]
		::CanvasCmd::DoPutCanvas $wServCan $ip
	    }		
	}
	"RESIZE IMAGE" {
	    if {[regexp "^RESIZE IMAGE: +($wrd_) +($wrd_) +($signint_)$"   \
	      $line match itOrig itNew zoomFactor]} {
		
		# Image (photo) resizing.	
		::Debug 2 "--->RESIZE IMAGE: itOrig=$itOrig, itNew=$itNew, \
		  zoomFactor=$zoomFactor"
		::Import::ResizeImage . $zoomFactor $itOrig $itNew "local"
	    }		
	}
	default {
	    if {[info exists handler($prefix)]} {
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

    ::PreferencesUtils::Add [list  \
      [list prefs(shortcuts)  prefs_shortcuts  $prefs(shortcuts)  userDefault]]
}

proc ::P2P::Prefs::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {General Shortcuts} -text [mc Shortcuts]
    
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
    
    set fontS [option get . fontSmall {}]
    
    set wcont $wpage.frtop
    labelframe $wcont -text [mc {Edit Shortcuts}]
    pack $wcont -side top -anchor w -padx 8 -pady 4
    
    # Overall frame for whole container.
    set frtot [frame $wcont.fr]
    pack $frtot -side left -padx 6 -pady 6    
    message $frtot.msg -borderwidth 0 -aspect 600 \
      -text [mc prefshortcut]
    pack $frtot.msg -side top -padx 4 -pady 6
    
    # Frame for listbox and scrollbar.
    set frlist [frame $frtot.lst]
    
    # The listbox.
    set wsb $frlist.sb
    set shortListVar {}
    foreach pair $tmpPrefs(shortcuts) {
	lappend shortListVar [lindex $pair 0]
    }
    set wlbox [listbox $frlist.lb -height 10 -width 18   \
      -listvar [namespace current]::shortListVar \
      -yscrollcommand [list $wsb set] -selectmode extended]
    scrollbar $wsb -command [list $wlbox yview]
    pack $wlbox -side left -fill both
    pack $wsb -side left -fill both
    pack $frlist -side left
    
    # Buttons at the right side.
    frame $frtot.btfr
    set btadd $frtot.btfr.btadd
    set btrem $frtot.btfr.btrem
    set btedit $frtot.btfr.btedit
    button $btadd -text "[mc Add]..." -font $fontS  \
      -command [list [namespace current]::AddOrEdit add]
    button $btrem -text [mc Remove] -font $fontS -state disabled  \
      -command [namespace current]::Remove
    button $btedit -text "[mc Edit]..." -state disabled -font $fontS \
      -command [list [namespace current]::AddOrEdit edit]
    pack $frtot.btfr -side top -anchor w
    pack $btadd $btrem $btedit -side top -fill x -padx 4 -pady 4
	
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
	$btrem configure -state normal
    } else {
	$btrem configure -state disabled
	$btedit configure -state disabled
    }
    if {[llength [$wlbox curselection]] == 1} {
	$btedit configure -state normal
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
    if {$what == "edit" && $indShortcuts == ""} {
	return
    } 
    set w .taddshorts$what
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    if {$what == "add"} {
	set txt [mc {Add Shortcut}]
	set txt1 "[mc {New shortcut}]:"
	set txt2 "[mc prefshortip]:"
	set txtbt [mc Add]
	set shortTextVar {}
	set longTextVar {}
    } elseif {$what == "edit"} {
	set txt [mc {Edit Shortcut}]
	set txt1 "[mc Shortcut]:"
	set txt2 "[mc prefshortip]:"
	set txtbt [mc Save]
    }
    set finAdd 0
    wm title $w $txt
    
    set fontSB [option get . fontSmallBold {}]
    
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall
    
    # The top part.
    set wcont $w.frtop
    labelframe $wcont -text $txt
    pack $wcont -in $w.frall -padx 8 -pady 4
    
    # Overall frame for whole container.
    set frtot [frame $wcont.fr]
    label $frtot.lbl1 -text $txt1 -font $fontSB
    entry $frtot.ent1 -width 36 -textvariable [namespace current]::shortTextVar
    label $frtot.lbl2 -text $txt2 -font $fontSB
    entry $frtot.ent2 -width 36 -textvariable [namespace current]::longTextVar
    grid $frtot.lbl1 -sticky w -padx 6 -pady 1
    grid $frtot.ent1 -sticky ew -padx 6 -pady 1
    grid $frtot.lbl2 -sticky w -padx 6 -pady 1
    grid $frtot.ent2 -sticky ew -padx 6 -pady 1
    
    pack $frtot -side left -padx 16 -pady 10
    pack $wcont -fill x    
    focus $frtot.ent1
    
    # Get the short pair to edit.
    if {[string equal $what "edit"]} {
	set shortTextVar [lindex $tmpPrefs(shortcuts) $indShortcuts 0]
	set longTextVar  [lindex $tmpPrefs(shortcuts) $indShortcuts 1]
    } elseif {[string equal $what "add"]} {
	
    }
    
    # The bottom part.
    pack [frame $w.frbot -borderwidth 0] -in $w.frall -fill both  \
      -padx 8 -pady 6
    button $w.frbot.bt1 -text "$txtbt" -default active  \
      -command [list [namespace current]::PushBtAddOrEdit $what]
    pack $w.frbot.bt1 -side right -padx 5 -pady 5
    pack [button $w.frbot.btcancel -text [mc Cancel]  \
      -command "set [namespace current]::finAdd 2"]  \
      -side right -padx 5 -pady 5
    
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

    if {($shortTextVar == "") || ($longTextVar == "")} {
	set finAdd 1
	return
    }
    if {$what == "add"} {
 
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
