#  FTrans.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the UI for file-transfer.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: FTrans.tcl,v 1.1 2005-09-19 06:37:21 matben Exp $

package require snit 1.0
package require uriencode
package require jlib::ftrans
package require ui::util
package require ui::progress
package require ui::dialog

package provide FTrans 1.0

namespace eval ::FTrans {

    set title [mc {Send File}]
        
    option add *FTrans.title                 $title           widgetDefault
    option add *FTrans.sendFileImage         sendfile         widgetDefault
    option add *FTrans.sendFileDisImage      sendfileDis      widgetDefault
    
    variable uid 0
    
    variable xmlns
    array set xmlns {
	oob            "jabber:iq:oob"
	file-transfer  "http://jabber.org/protocol/si/profile/file-transfer"
    }
    
    # Handler for incoming file-transfer requests (set).
    jlib::ftrans::registerhandler ::FTrans::SetHandler
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

    option -command      -default ::FTrans::Nop
    option -geovariable
    option -initialdir
    option {-image   sendFileImage    Image}
    option {-imagebg sendFileDisImage Image}
    option -title -configuremethod OnConfigTitle
    
    typeconstructor {
	if {![catch {package require tkdnd}]} {
	    set havednd 1
	}       
    }
    
    constructor {_jid args} {
	$self configurelist $args
	set jid $_jid

	if {[tk windowingsystem] eq "aqua"} {
	    ::tk::unsupported::MacWindowStyle style $win document closeBox
	}
	wm title $win $options(-title)
	if {[tk windowingsystem] ne "aqua"} {
	    $win configure -menu ""
	}

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
	  -text [mc oobmsg $jid]
	pack $wbox.msg -side top -fill both -expand 1
	
	# Entries etc.
	set frm $wbox.m
	ttk::frame $frm
	ttk::button $frm.btfile -text "[mc {File}]..." -width -10  \
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

	bind $win <Return> [list $self OK]
	bind $win <Escape> [list $self Destroy]
	after idle [list $self WrapLength]
	#bind $win <Configure> [subst {if {"%W" eq "$win"} {$self WrapLength}}]
	
	if {$havednd} {
	    $self InitDnD $frm.efile
	}
	return
    }
    
    method WrapLength {} {
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
	set ans [eval {tk_getOpenFile -title [mc {Pick File}]} $opts]
	if {[string length $ans]} {
	    set fileName $ans
	    set initialdir [file dirname $ans]
	}
    }
    
    method InitDnD {w} {
	dnd bindtarget $w text/uri-list <Drop>      {$self DnDDrop  %W %D %T}
	dnd bindtarget $w text/uri-list <DragEnter> {$self DnDEnter %W %A %D %T}
	dnd bindtarget $w text/uri-list <DragLeave> {$self DnDLeave %W %D %T}
    }

    method DnDDrop {w data dndtype} {

	# Take only first file.
	set f [lindex $data 0]
	    
	# Strip off any file:// prefix.
	set f [string map {file:// ""} $f]
	set f [uriencode::decodefile $f]
	set fileName $f
    }

    # @@@ There can be problems with this one since returns stuff...
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

proc ::FTrans::Send {jid} {
    variable xmlns
    upvar ::Jabber::jstate jstate

    if {[$jstate(jlib) disco isdiscoed info $jid]} {
	set feature [DiscoGetFeature $jid]
	if {$feature eq ""} {
	    ui::dialog [ui::autoname]  \
	      -type ok -icon error -title [mc {Error}]  \
	      -message "We couldn't see that $jid supports file transfer."
	} else {
	    Build $jid
	}
    } else {
	set w [Build $jid]
	$w state disabled
	$w status "Waiting for disco result..."
	set discoCB [list [namespace current]::DiscoCB $w]
	$jstate(jlib) disco send_get info $jid $discoCB
    }
}

proc ::FTrans::Build {jid} {
    global  wDlgs
    variable uid
    
    set dlg $wDlgs(jftrans)
    set w   $dlg[incr uid]
    set m   [::UI::GetMainMenu]
    SendDialog $w $jid  \
      -command [namespace current]::DoSend  \
      -menu $m -geovariable prefs(winGeom,$dlg)
    ::UI::SetMenuAcceleratorBinds $w $m

    return $w
}

proc ::FTrans::DiscoCB {w jlibname type jid subiq} {
    
    ::Debug 4 "::FTrans::DiscoCB"
    
    if {[winfo exists $w]} {
	$w status ""
	if {$type eq "error"} {
	    ui::dialog [ui::autoname]  \
	      -type ok -icon error -title [mc {Error}]  \
	      -message "We couldn't see that $jid supports file transfer."
	    destroy $w
	} else {
	    set feature [DiscoGetFeature $jid]
	    if {$feature eq ""} {
		ui::dialog [ui::autoname]  \
		  -type ok -icon error -title [mc {Error}]  \
		  -message "We couldn't see that $jid supports file transfer."
		destroy $w
	    } else {
		$w state !disabled
	    }
	}
    }
}

proc ::FTrans::DiscoGetFeature {jid} {
    variable xmlns
    upvar ::Jabber::jstate jstate
    
    if {[$jstate(jlib) disco hasfeature $xmlns(file-transfer) $jid]} {
	return $xmlns(file-transfer)
    } elseif {[$jstate(jlib) disco hasfeature $xmlns(oob) $jid]} {
	return $xmlns(oob)
    } else {
	return
    }
}

# FTrans::DoSend --
# 
#       Callback from Send button.

proc ::FTrans::DoSend {win jid fileName desc} {
    variable xmlns
    upvar ::Jabber::jstate jstate
    
    set fileName [string trim $fileName]
        
    # Verify that file is ok.	
    if {![string length $fileName]} {
	::UI::MessageBox -type ok -icon error   \
	  -title [mc {Pick File}] -parent $win  \
	  -message "You must provide a file to send"
	return -code break
    }
    if {![file exists $fileName]} {
	::UI::MessageBox -type ok -icon error   \
	  -title [mc {Pick File}] -parent $win  \
	  -message "The picked file does not exist. Pick a new one."
	return -code break
    }
    set opts [list -mime [::Types::GetMimeTypeForFileName $fileName]]
    if {[string length $desc]} {
	set opts [list -description $desc]
    }
    
    # Select protocol to be used: oob or file-transfer.
    set feature [DiscoGetFeature $jid]
    if {$feature eq ""} {
	::UI::MessageBox -type ok -icon error -title [mc {Error}]  \
	  -message "We couldn't see that $jid supports file transfer."
	return
    }
    if {$feature eq $xmlns(file-transfer)} {
	set sendCB [namespace current]::SendCommand
	eval {$jstate(jlib) filetransfer send $jid $sendCB -file $fileName} $opts
    } else {
	
	# Different options for oob!
	set url [::Utils::GetHttpFromFile $fileName]
	set opts {}
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
		set msg [mc jamessooberr406 $state(jid) $state(name)]
	    }
	    default {
		set msg [mc jamessooberr404 $state(name) $state(jid) \
		  $stanza $errstr]
	    }
	}
	ui::dialog [ui::autoname]  \
	  -icon error -type ok -title [mc Error] -message $msg
    } else {
	ui::dialog [ui::autoname]  \
	  -icon info -type ok -title [mc {File Transfer}] \
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
		set msg [mc jamessooberr406 $jid $tail]
	    }
	    default {
		set msg [mc jamessooberr404 $tail $jid $errcode $errmsg]
	    }
	}
	
	ui::dialog [ui::autoname]  \
	  -icon error -type ok -title [mc Error] -message $msg
    } else {
	ui::dialog [ui::autoname]  \
	  -icon info -type ok -title [mc {File Transfer}] \
	  -message [mc jamessoobok2 $tail $jid]
    }
}

#... Target (receiver) section..................................................

proc ::FTrans::SetHandler {jlibname jid name size cmd args} {
    variable uid
    
    ::Debug 2 "---> ::FTrans::SetHandler (t): jid=$jid, name=$name, size=$size, cmd=$cmd, $args"

    array set opts {
	-mime   application/octet-stream
	-desc   ""
    }
    array set opts $args    

    # Initialize the state variable, an array, that keeps is the storage.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set state(jid)   $jid
    set state(name)  $name
    set state(size)  $size
    set state(cmd)   $cmd
    set state(w)     [ui::autoname]
    foreach {key value} $args {
	set state($key) $value
    }
    
    # Nonmodal message dialog.
    ui::dialog [ui::autoname]  \
      -title [mc {Get File}] -icon question  \
      -type yesno -default yes  \
      -command [list [namespace current]::SetHandlerAnswer $token] \
      -message [mc jamessoobask $jid $name $opts(-desc)]
}

proc ::FTrans::SetHandlerAnswer {token wdlg answer} {
    global  prefs
    variable $token
    upvar 0 $token state
    
    destroy $wdlg
    
    if {$answer} {
	set name $state(name)
	set cmd  $state(cmd)
	set userDir [::Utils::GetDirIfExist $prefs(userPath)]
	set fileName [tk_getSaveFile -title [mc {Save File}] \
	  -initialfile $name -initialdir $userDir]
	if {$fileName ne ""} {
	    set fd [open $fileName w]
	    
	    set state(fileName) $fileName
	    set state(fd)       $fd

	    eval [linsert $cmd end yes      \
	      -channel $fd                  \
	      -progress [list ::FTrans::TProgress $token] \
	      -command  [list ::FTrans::TCommand $token]]
	} else {
	    eval $cmd no
	    unset -nocomplain state
	}
    } else {
	eval $cmd $ans
	unset -nocomplain state
    }
}

proc ::FTrans::TProgress {token jlibname sid total bytes} {
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "---> ::FTrans::TProgress total=$total, bytes=$bytes"

    # Cache timing info.
    ::timing::setbytes $sid $bytes

    set w $state(w)

    # Update the progress window.
    if {[winfo exists $w]} {
	set percent [expr 100.0 * $bytes/($total + 0.001)]
	set timsg [::timing::getmessage $sid $total]
	set str "[mc Rate]: $timsg"	
	$w configuredelayed -percent $percent -text2 $str
    } else {
	set str "[mc {Writing file}]: $state(name)"
	ui::progress::toplevel $w -text $str  \
	  -cancelcommand [list [namespace current]::TCancel $jlibname $sid]
    }
    update idletasks
}

proc ::FTrans::TCancel {jlibname sid} {
    
    $jlibname filetransfer treset $sid    
}

proc ::FTrans::TCommand {token jlibname sid status {errmsg ""}} {
    variable $token
    upvar 0 $token state
        
    ::Debug 2 "---> ::FTrans::TCommand status=$status"

    if {$status eq "error"} {
	ui::dialog [ui::autoname]  \
	  -icon error -type ok -title [mc Error]  \
	  -message "Failed to get file $state(name) from $state(jid): $errmsg"
	catch {file delete $state(fileName)}
    } elseif {$status eq "reset"} {
	catch {file delete $state(fileName)}
    }
    destroy $state(w)
    ::timing::free $sid
    unset -nocomplain state
}

