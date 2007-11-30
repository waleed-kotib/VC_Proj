#  FTrans.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the UI for file-transfer.
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: FTrans.tcl,v 1.29 2007-11-30 15:30:13 matben Exp $

package require snit 1.0
package require uriencode
package require jlib::ftrans
package require ui::progress
package require ui::dialog

package provide FTrans 1.0

namespace eval ::FTrans {

    ::hooks::register prefsInitHook                   ::FTrans::InitPrefsHook
    ::hooks::register jabberInitHook                  ::FTrans::JabberInitHook
    ::hooks::register discoInfoProxyBytestreamsHook   ::FTrans::DiscoHook
    ::hooks::register logoutHook                      ::FTrans::LogoutHook
    
    set title [mc "Send File"]
        
    option add *FTrans.title                 $title           widgetDefault
    option add *FTrans.sendFileImage         sendfile         widgetDefault
    option add *FTrans.sendFileDisImage      sendfileDis      widgetDefault
    
    variable uid 0
    
    # Handler for incoming file-transfer requests (set).
    jlib::ftrans::registerhandler ::FTrans::SetHandler
}

proc ::FTrans::JabberInitHook {jlib} {
    upvar ::Jabber::xmppxmlns xmppxmlns
    
    # si/profile/file-transfer registered in jlib::ftrans
    jlib::disco::registerfeature $xmppxmlns(oob)
}

proc ::FTrans::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
	
    set jprefs(bytestreams,port) 8237
    
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(bytestreams,port) jprefs_bytestreams_port $jprefs(bytestreams,port)]  \
      ]    
}

proc ::FTrans::DiscoHook {type from queryE args} {
    upvar ::Jabber::jstate jstate
    
    $jstate(jlib) bytestreams get_proxy $from \
      [namespace code [list GetProxyCB $from]]
}

proc ::FTrans::GetProxyCB {from jlib type queryE} {
    
    # It happens that Wildfire doesn't return a host attribute if it
    # cannot resolve its host.
    if {$type eq "result"} {
	set hostE [wrapper::getfirstchildwithtag $queryE "streamhost"]
	if {[llength $hostE]} {
	    array set attr [wrapper::getattrlist $hostE]
	    if {[info exists attr(host)] && [info exists attr(port)]} {
		$jlib bytestreams configure \
		  -proxyhost [list $from $attr(host) $attr(port)]
	    }
	}
    }
}

proc ::FTrans::LogoutHook {} {
    upvar ::Jabber::jstate jstate
    
    $jstate(jlib) bytestreams configure -proxyhost ""
}

proc ::FTrans::BytestreamsConfigure {} {
    global  prefs
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
        
    set opts [list -port $jprefs(bytestreams,port)]
    if {$prefs(setNATip) && ($prefs(NATip) ne "")} {
	lappend opts -address $prefs(NATip)
    }
    eval {$jstate(jlib) bytestreams configure} $opts
}

proc ::FTrans::MD5 {fileName} {
    
    # We don't use the md5x package since that is way too slow if pure tcl.
    # Assumes the following output form for md5:
    # MD5 (sigslot.pdf) = 7ea44817f6def146ee180d0fff114b87
    # And for md5sum:
    # 7ea44817f6def146ee180d0fff114b87  sigslot.pdf
    set hash ""
    if {[llength [set cmd [auto_execok md5]]]} {
	set ans [exec $cmd [list $fileName]]
	regexp { +([0-9a-f]+$)} $ans - hash
    } elseif {[llength [set cmd [auto_execok md5sum]]]} {
	set ans [exec $cmd [list $fileName]]
	regexp {^([0-9a-f]+)} $ans - hash
    }
    return $hash
}

#... Initiator (sender) section ................................................

# FTrans::SendDialog --
#
#       Megawidget send file dialog.

snit::widget ::FTrans::SendDialog {
    hulltype toplevel
    widgetclass FTrans
    
    # @@@ works only on macs!!!
    # -menu must be done only on creation, else crash on mac.
    delegate option -menu to hull

    typevariable havednd 0
    typevariable initialdir
    
    variable jid
    variable sendProc
    variable fileName    ""
    variable description ""
    variable sendButton
    variable status      ""
    variable afterid     ""

    option -command      -default ::FTrans::Nop
    option -geovariable
    option -initialdir
    option {-image   sendFileImage    Image}
    option {-imagebg sendFileDisImage Image}
    option -title -configuremethod OnConfigTitle
    option -filename
    
    typeconstructor {
	if {[tk windowingsystem] ne "aqua"} {
	    if {![catch {package require tkdnd}]} {
		set havednd 1
	    }
	}
    }
    
    constructor {_jid args} {
	$self configurelist $args
	set jid $_jid

	if {[tk windowingsystem] eq "aqua"} {
	    ::tk::unsupported::MacWindowStyle style $win document closeBox
	} else {
	    $win configure -menu ""
	}
	wm title $win $options(-title)

	set im   [::Theme::GetImage $options(-image)]
	set imbg [::Theme::GetImage $options(-imagebg)]

	# Global frame.
	ttk::frame $win.f
	pack $win.f -fill both -expand 1
	    
	ttk::label $win.f.head -style Headlabel  \
	  -text [mc {Send File}] -compound left  \
	  -image [list $im background $imbg]
	pack $win.f.head -side top -anchor w

	ttk::separator $win.f.s -orient horizontal
	pack $win.f.s -side top -fill x
	
	set wbox $win.f.f
	ttk::frame $wbox -padding [option get . dialogPadding {}]
	pack $wbox -fill both -expand 1

	ttk::label $wbox.msg -style Small.TLabel  \
	  -padding {0 0 0 6} -wraplength 200 -anchor w -justify left \
	  -text [mc oobmsg2 $jid]
	pack $wbox.msg -side top -fill both -expand 1
	
	# Entries etc.
	set frm $wbox.m
	ttk::frame $frm
	ttk::button $frm.btfile -text "[mc {Select File}]..." -width -10  \
	  -command [list $self GetFile]
	ttk::entry $frm.efile -textvariable [myvar fileName]
	ttk::label $frm.ldesc -text "[mc {Description}]:" -anchor e
	ttk::entry $frm.edesc -width 32  \
	  -textvariable [myvar description]

	grid  $frm.btfile  $frm.efile  -padx 2 -pady 2 -sticky e
	grid  $frm.ldesc   $frm.edesc  -padx 2 -pady 2 -sticky e
	grid  $frm.efile   $frm.edesc  -sticky ew
	grid columnconfigure $frm 1 -weight 1

	pack  $frm  -side top -fill both -expand 1
	
	# Button part.
	set frbot $wbox.b
	ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
	ttk::button $frbot.btok -text [mc Send] -default active  \
	  -command [list $self OK]
	ttk::button $frbot.btcancel -text [mc Cancel]  \
	  -command [list $self Destroy]
	ttk::label $wbox.status -style Small.TLabel  \
	  -textvariable [myvar status]
	set padx [option get . buttonPadX {}]
	if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	    pack $frbot.btok -side right
	    pack $frbot.btcancel -side right -padx $padx
	} else {
	    pack $frbot.btcancel -side right
	    pack $frbot.btok -side right -padx $padx
	}
	pack $wbox.status -side left
	pack $frbot -side bottom -fill x

	set sendButton $frbot.btok
	
	wm resizable $win 0 0
	wm protocol  $win WM_DELETE_WINDOW [list $self Destroy]

	if {[string length $options(-geovariable)]} {
	    ui::PositionClassWindow $win $options(-geovariable) "FTrans"
	}
	set fileName $options(-filename)

	bind $win <Return> [list $self OK]
	bind $win <Escape> [list $self Destroy]
	set afterid [after idle [list $self WrapLength]]
	
	if {$havednd} {
	    $self InitDnD $frm.efile
	}
	return
    }
    
    destructor {
	if {$afterid ne ""} {
	    after cancel $afterid
	}
	if {[string length $options(-geovariable)]} {
	    ui::SaveGeometry $win $options(-geovariable)
	}
    }
    
    method WrapLength {} {
	set afterid ""
	update idletasks
	set pad  [$win.f.f cget -padding]
	set padx [expr {[lindex $pad 0] + [lindex $pad 2]}]
	set wdth [winfo reqwidth $win]
	$win.f.f.msg configure -wraplength [expr {$wdth - $padx - 10}]
    }
    
    method OnConfigTitle {option value} {
	wm title $win $value
	set options($option) $value
    }
    
    method GetFile {} {
	set opts {}
	if {[file isdirectory $options(-initialdir)]} {
	    set opts [list -initialdir $options(-initialdir)]
	}
	set ans [eval {tk_getOpenFile -title [mc "Select File"]} $opts]
	if {[string length $ans]} {
	    set fileName $ans
	    set initialdir [file dirname $ans]
	}
    }
    
    method InitDnD {w} {
	dnd bindtarget $w text/uri-list <Drop>      [list $self DnDDrop  %W %D %T]
	dnd bindtarget $w text/uri-list <DragEnter> [list $self DnDEnter %W %A %D %T]
	dnd bindtarget $w text/uri-list <DragLeave> [list $self DnDLeave %W %D %T]
    }

    method DnDDrop {w data dndtype} {

	# Take only first file.
	set f [lindex $data 0]
	    
	# Strip off any file:// prefix.
	set f [string map {file:// ""} $f]
	set f [uriencode::decodefile $f]
	set fileName $f
    }

    method DnDEnter {w action data dndtype} {
	focus $w
	set act "none"
	return $act
    }

    method DnDLeave {w data dndtype} {	
	focus [winfo toplevel $w] 
    }

    method OK {} {
	if {$options(-command) ne ""} {
	    set rc [catch {
		$options(-command) $win $jid $fileName $description
	    } result]
	    if {$rc == 1} {
		return -code $rc -errorinfo $::errorInfo -errorcode $::errorCode $result
	    } elseif {$rc == 3 || $rc == 4} {
		return
	    } 
	}
	$self Destroy
    }
    
    method Destroy {} {
	if {[string length $options(-geovariable)]} {
	    ui::SaveGeometry $win $options(-geovariable)
	}
	destroy $win
    }
    
    # Public methods:

    method state {state} {
	$sendButton state $state
    }
    
    method status {msg} {
	set status $msg
    }
}

proc ::FTrans::Nop {args} { }

# FTrans::Send --
# 
#       Initiator function. Must be 3-tier jid.

proc ::FTrans::Send {jid args} {
    upvar ::Jabber::jstate jstate
    
    if {[$jstate(jlib) disco isdiscoed info $jid]} {
	set feature [DiscoGetFeature $jid]
	if {$feature eq ""} {
	    ui::dialog -type ok -icon error -title [mc Error] \
	      -message [mc jamessnofiletrpt2 $jid]
	} else {
	    eval {Build $jid} $args
	}
    } else {
	set w [eval {Build $jid} $args]
	$w state disabled
	$w status "[mc jawaitdisco]..."
	set cb [list [namespace current]::DiscoCB $w]
	$jstate(jlib) disco get_async info $jid $cb
    }
}

proc ::FTrans::Build {jid args} {
    global  wDlgs
    variable uid
    
    set dlg $wDlgs(jftrans)
    set w   $dlg[incr uid]
    set m   [::UI::GetMainMenu]
    eval {SendDialog $w $jid  \
      -command [namespace current]::DoSend  \
      -menu $m -geovariable prefs(winGeom,$dlg)} $args
    ::UI::SetMenubarAcceleratorBinds $w $m

    return $w
}

proc ::FTrans::DiscoCB {w jlibname type jid subiq} {
    
    ::Debug 4 "::FTrans::DiscoCB"
    
    if {[winfo exists $w]} {
	$w status ""
	if {($type eq "error") || ([DiscoGetFeature $jid] eq "")} {
	    ui::dialog -type ok -icon error -title [mc Error]  \
	      -message [mc jamessnofiletrpt2 $jid]
	    destroy $w
	} else {
	    $w state !disabled
	}
    }
}

# @@@ Shall be done using caps instead!

proc ::FTrans::DiscoGetFeature {jid} {
    upvar ::Jabber::xmppxmlns xmppxmlns
    upvar ::Jabber::jstate jstate
    
    if {[$jstate(jlib) disco hasfeature $xmppxmlns(file-transfer) $jid]} {
	return $xmppxmlns(file-transfer)
    } elseif {[$jstate(jlib) disco hasfeature $xmppxmlns(oob) $jid]} {
	return $xmppxmlns(oob)
    } else {
	return
    }
}

# FTrans::DoSend --
# 
#       Callback from Send button.

proc ::FTrans::DoSend {win jid fileName desc} {
    upvar ::Jabber::xmppxmlns xmppxmlns
    upvar ::Jabber::jstate jstate
    
    set fileName [string trim $fileName]
        
    # Verify that file is ok.	
    if {![string length $fileName]} {
	::UI::MessageBox -type ok -icon error   \
	  -title [mc Error] -parent $win -message [mc jamessnofile2]
	return -code break
    }
    if {![file exists $fileName]} {
	::UI::MessageBox -type ok -icon error   \
	  -title [mc Error] -parent $win -message [mc jamessfilenotexist]
	return -code break
    }
    set opts [list -mime [::Types::GetMimeTypeForFileName $fileName]]
    if {[string length $desc]} {
	set opts [list -description $desc]
    }
    
    # Select protocol to be used: oob or file-transfer.
    set feature [DiscoGetFeature $jid]
    if {$feature eq ""} {
	::UI::MessageBox -type ok -icon error -title [mc Error]  \
	  -message [mc jamessnofiletrpt2 $jid]
	return
    }
    if {$feature eq $xmppxmlns(file-transfer)} {
	lappend opts -hash [MD5 $fileName]
	
	# Do this each time since we may have changed proxy settings.
	BytestreamsConfigure
	set sendCB [namespace current]::SendCommand
	eval {$jstate(jlib) filetransfer send $jid $sendCB -file $fileName} $opts
    } else {
	
	# Different options for oob!
	set url [::Utils::GetHttpFromFile $fileName]
	set opts [list]
	if {[string length $desc]} {
	    lappend opts -desc $desc
	}
	set sendCB [list [namespace current]::SendCommandOOB $fileName $jid]
	eval {$jstate(jlib) oob_set $jid $sendCB $url} $opts
    }
}

proc ::FTrans::SendCommand {jlibname status sid {subiq ""}} {

    ::Debug 2 "---> ::FTrans::SendCommand status=$status, subiq=$subiq"
    
    array set state {
	jid     ""
	name    ""
    }
    array set state [$jlibname filetransfer getinitiatorstate $sid]

    if {$status eq "error"} {
	lassign $subiq stanza errstr
	
	switch -- $stanza {
	    forbidden {
		set msg [mc jamessooberr406b $state(jid) $state(name)]
	    }
	    default {
		set msg [mc jamessooberr404b $state(name) $state(jid)]
		append msg "\n[mc {Error code}]: $stanza"
		append msg "\n[mc Message]: $errstr"
	    }
	}
	ui::dialog -icon error -type ok -title [mc Error] -message $msg
    } elseif {$status eq "reset"} {
	# empty    
    } else {
	ui::dialog -icon info -type ok -title [mc "File Transfer"] \
	  -message [mc jamessoobok2 $state(name) $state(jid)]
    }
}

proc ::FTrans::SendCommandOOB {fileName jid jlibname type subiq} {
    
    ::Debug 2 "---> ::FTrans::SendCommandOOB"
    
    set tail [file tail $fileName]
    
    if {$type eq "error"} {
	lassign $subiq errcode errmsg
	
	switch -- $errcode {
	    406 {
		set msg [mc jamessooberr406b $jid $tail]
	    }
	    default {
		set msg [mc jamessooberr404b $tail $jid]
		append msg "\n[mc {Error code}]: $errcode"
		append msg "\n[mc Message]: $errmsg"
	    }
	}
	ui::dialog -icon error -type ok -title [mc Error] -message $msg
    } else {
	ui::dialog -icon info -type ok -title [mc {File Transfer}] \
	  -message [mc jamessoobok2 $tail $jid]
    }
}

#... Target (receiver) section..................................................

# FTrans::SetHandler --
# 
#       Handler for incoming file-transfer requests (set).

proc ::FTrans::SetHandler {jlibname jid name size cmd args} {
    
    ::Debug 2 "---> ::FTrans::SetHandler (t): jid=$jid, name=$name, size=$size, cmd=$cmd, $args"
    
    array set argsA $args

    # Keep this for the non modal dialog -command.
    set spec [list $jlibname $jid $name $size $cmd $args]
    
    # Nonmodal message dialog.
    set str "\n[mc File]: $name\n[mc Size]: [::Utils::FormatBytes $size]\n"
    if {[info exists argsA(-desc)]} {
	append str "[mc Description]: $argsA(-desc)\n"
    }
    set msg [mc jamessoobask2 $jid $name $str]
    ui::dialog -title [mc "Receive File"] -icon question  \
      -type yesno -default yes -message $msg                    \
      -command [list [namespace current]::SetHandlerAnswer $spec]
    
    ::hooks::run fileTransferReceiveHook $jid $name $size
}

proc ::FTrans::SetHandlerAnswer {spec wdlg answer} {
    global  prefs

    destroy $wdlg
    
    lassign $spec jlibname jid name size cmd args
    
    if {$answer} {
	
	# Do this each time since we may have changed proxy settings.
	BytestreamsConfigure
	
	set userDir [::Utils::GetDirIfExist $prefs(userPath)]
	set fileName [tk_getSaveFile -title [mc "Save File"] \
	  -initialfile $name -initialdir $userDir]
	if {$fileName ne ""} {
	    set prefs(userPath) [file dirname $fileName]
	    
	    # Make progress object.
	    set token [eval {ObjectReceive $jid $fileName $size} $args]
	    set fd [open $fileName w]

	    eval [linsert $cmd end yes      \
	      -channel $fd                  \
	      -progress [list ::FTrans::TProgress $token] \
	      -command  [list ::FTrans::TCommand $token]]
	} else {
	    eval $cmd no
	    unset -nocomplain state
	}
    } else {
	eval $cmd $answer
	unset -nocomplain state
    }
}

# FTrans::ObjectReceive --
# 
#       This is kind of constructor for our file transfer operation.

proc ::FTrans::ObjectReceive {jid fileName size args} {
    variable uid
    
    # Initialize the state variable, an array, that keeps is the storage.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set state(jid)      $jid
    set state(fileName) $fileName
    set state(name)     [file tail $fileName]
    set state(size)     $size
    set state(w)        [ui::autoname]
    
    foreach {key value} $args {
	set state($key) $value
    }    
    return $token
}

proc ::FTrans::TProgress {token jlibname sid total bytes} {
    variable $token
    upvar 0 $token state
    
    # Cache timing info.
    ::timing::setbytes $sid $bytes

    set w $state(w)

    # Update the progress window.
    if {[winfo exists $w]} {
	set percent [expr {100.0 * $bytes/($total + 0.001)}]
	set timsg [::timing::getmessage $sid $total]
	set str "[mc Rate]: $timsg"	
	$w configuredelayed -percent $percent -text2 $str
    } else {
	set str "[mc {Writing file}]: $state(name)"
	ui::progress::toplevel $w -text $str  \
	  -cancelcommand [list [namespace current]::TCancel $jlibname $sid]
    }
    
    # WRONG !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#     if {[string equal $::tcl_platform(platform) "windows"]} {
# 	update
#     } else {
# 	update idletasks
#     }
}

proc ::FTrans::TCancel {jlibname sid} {
    
    $jlibname filetransfer treset $sid    
}

proc ::FTrans::TCommand {token jlibname sid status {errmsg ""}} {
    variable $token
    upvar 0 $token state
        
    ::Debug 2 "---> ::FTrans::TCommand status=$status"

    if {$status eq "error"} {
	set str "[mc jamessfiletrpterr2 $state(name) $state(jid)]\n"
	append str "[mc Error]: $errmsg"
	ui::dialog -icon error -type ok -title [mc Error] -message $str

	catch {file delete $state(fileName)}
    } elseif {$status eq "reset"} {
	catch {file delete $state(fileName)}
    } else {
    
	# Check file integrity using md5.
	if {[info exists state(-hash)] && [string length $state(-hash)]} {
	    set hash [MD5 $state(fileName)]
	    if {[string length $hash] && ($hash ne $state(-hash))} {
		ui::dialog -icon error -type ok -title [mc Error]  \
		  -message [mc jamessfilemd5]
	    }
	}
    }
    destroy $state(w)
    ::timing::free $sid
    unset -nocomplain state
}

