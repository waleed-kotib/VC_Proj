#  Dialogs.tcl ---
#  
#      This file is part of the whiteboard application. It implements some
#      of the dialogs. 
#      
#  Copyright (c) 1999-2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Dialogs.tcl,v 1.7 2003-07-26 13:54:23 matben Exp $
   
package provide Dialogs 1.0

namespace eval ::Dialogs:: {
    
    
}

# Define the toplevel windows here so they don't collide.
# Toplevel dialogs.
array set wDlgs {
    editFonts       .edfnt
    editShorts      .tshcts
    fileAssoc       .fass
    infoClient      .infocli
    infoServ        .infoserv
    netSetup        .netsetup
    openConn        .opc
    openMulti       .opqtmulti
    prefs           .prefs
    print           .prt
    prog            .prog
    splash          .splash
}

# Toplevel dialogs for the jabber part.
array set wDlgs {
    jreg            .jreg
    jlogin          .jlogin
    jrost           .jrost
    jrostnewedit    .jrostnewedit
    jsubsc          .jsubsc
    jsendmsg        .jsendmsg
    jgotmsg         .jgotmsg
    jchat           .jchat
    jbrowse         .jbrowse
    jrostbro        .jrostbro
    jenterroom      .jenterroom
    jcreateroom     .jcreateroom
    jinbox          .jinbox
    jpresmsg        .jpresmsg
}

#  ::GetCanvas:: implements the dialog for choosing which client to get the 
#  canvas from.

namespace eval ::GetCanvas:: {
    
    namespace export GetCanvas
    
    # Wait for this variable to be set.
    variable finished
    
    # The ip name to get canvas from.
    variable getIPName
}

proc ::GetCanvas::GetCanvas {w} {
    global  allIPnumsToSend ipNumTo ipName2Num sysFont prefs this
    
    variable finished
    variable getIPName
    
    # Build list of ip names.
    set ipNames {}
    foreach ip $allIPnumsToSend {
	if {[info exists ipNumTo(name,$ip)]} {
	    lappend ipNames $ipNumTo(name,$ip)
	}
    }
    if {[llength $ipNames] == 0} {
	return 
    }
    set finished -1
    if {[winfo exists $w]} {
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w {Get Canvas}
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Labelled frame.
    set wcfr $w.frall.fr
    set wcont [LabeledFrame2 $wcfr {Get Canvas}]
    pack $wcfr -side top -fill both -ipadx 10 -ipady 6 -in $w.frall
    
    # Overall frame for whole container.
    set frtot [frame $wcont.frin]
    pack $frtot
    message $frtot.msg -borderwidth 0 -font $sysFont(s) -aspect 500 \
      -text {Choose client from which you want to get the canvas.\
      Your own canvas will be erased.}
    eval {tk_optionMenu $frtot.optm [namespace current]::getIPName} $ipNames
    $frtot.optm configure -highlightthickness 0  \
      -background $prefs(bgColGeneral) -foreground black
    grid $frtot.msg -column 0 -row 0 -columnspan 2 -padx 4 -pady 2 -sticky news
    grid $frtot.optm -column 1 -row 1 -padx 4 -pady 0 -sticky e
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text {    Get    } -width 8 -default active \
      -command "set [namespace current]::finished 1"]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command "set [namespace current]::finished 2"]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> "set [namespace current]::finished 1"
    
    # Grab and focus.
    focus $w
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finished
    
    catch {grab release $w}
    catch {destroy $w}
    #puts "   getIPName=$getIPName"
    
    if {$finished == 1 &&  \
      [info exists ipName2Num($getIPName)]} {
	return $ipName2Num($getIPName)
    } else {
	return ""
    }
}

#-- end ::GetCanvas:: ----------------------------------------------------------

#  Dialogs::InfoOnPlugins ---
#  
#      It implements the dialog for presenting the loaded packages or helper 
#      applications.

proc ::Dialogs::InfoOnPlugins {w} {
    global  sysFont prefs this
    
    # Check first of there are *any* plugins.
    if {[llength [::Plugins::GetAllPackages loaded]] == 0} {
	tk_messageBox -icon info -type ok -message   \
	  [FormatTextForMessageBox [::msgcat::mc messnoplugs]]
	return  
    }
    if {[winfo exists $w]} {
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc {Plugin Info}]
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1

    # Button part.
    pack [frame $w.frall.frbot -borderwidth 0] -fill both -side bottom \
      -padx 8 -pady 6
    pack [button $w.frall.frbot.ok -text [::msgcat::mc OK] -width 8  \
      -command "destroy $w"] -side right -padx 5 -pady 5

    set fbox $w.frall.fbox
    pack [frame $fbox -bd 1 -relief sunken] -side top -padx 4 -pady 4  \
      -fill both -expand 1
    
    set xtab1 80
    set xtab2 90
    set wtxt $w.frall.fbox.txt
    set wysc $w.frall.fbox.ysc
    scrollbar $wysc -orient vertical -command [list $wtxt yview]
    text $wtxt -yscrollcommand [list $wysc set] -highlightthickness 0  \
      -bg white -wrap word -font $sysFont(s) -width 50 -height 30  \
      -exportselection 1 -tabs [list $xtab1 right $xtab2 left]
    pack $wysc -side right -fill y
    pack $wtxt -side left -fill both -expand 1
    
    $wtxt tag configure ttitle -foreground black -background #dedede  \
      -spacing1 2 -spacing3 2 -lmargin1 20 -font $sysFont(sb)
    $wtxt tag configure tkey -font $sysFont(sb) -spacing1 2  \
      -tabs [list $xtab1 right $xtab2 left]
    $wtxt tag configure ttxt -font $sysFont(s) -wrap word -lmargin1 $xtab2 \
      -lmargin2 $xtab2
    $wtxt tag configure tline -font {Helvetica -1} -background black
    
    # If mac (classic) or win and not QuickTime, make an ad as the first item.
    if {[::Plugins::IsHost QuickTimeTcl] &&  \
      ![::Plugins::HavePackage QuickTimeTcl]} {

	::Text::ConfigureLinkTagForTextWidget $wtxt linktag linkactive
	set ad {Get QuickTime for free from Apple at www.apple.com/quicktime.\
	  It adds a lot of functionality to this application.}
	$wtxt insert end "\n" tline
	$wtxt insert end "QuickTimeTcl\n" ttitle
	$wtxt insert end "\n" tline
	$wtxt insert end "\tDownload:\t" tkey
	set textCmds [::Text::ParseHttpLinksForTextWidget $ad ttxt linktag]
	foreach cmd $textCmds {
	    eval $wtxt $cmd
	}	
	$wtxt insert end "\n\n"
    }
    
    # If Windows and not MSSpeech, make an ad as the first item.
    if {[::Plugins::IsHost MSSpeech] && ![::Plugins::HavePackage MSSpeech]} {

	$wtxt insert end "\n" tline
	$wtxt insert end "Microsoft Speech\n" ttitle
	$wtxt insert end "\n" tline
	$wtxt insert end "\tDownload:\t" tkey
	$wtxt insert end {Get Microsoft Speech for free from Microsoft at } ttxt
	::Text::InsertURL $wtxt "download.microsoft.com"  \
	  {http://download.microsoft.com/download/speechSDK/SDK/5.1/WXP/EN-US/Sp5TTIntXP.exe} \
	  ttxt
	$wtxt insert end { It adds synthetic speech of text messages.} ttxt	
	$wtxt insert end "\n\n"
    }
        
    # Try the known plugind and apps, and make a labelled frame for each.
    foreach plug [::Plugins::GetAllPackages loaded] {
	
	set txtver [::Plugins::GetVersionForPackage $plug]
	if {$txtver == ""} {
	    set txtver "unknown"
	}
	set txtsuf [::Plugins::GetSuffixes $plug]
	if {$txtsuf == ""} {
	    set txtsuff "none"
	}
	
	$wtxt insert end "\n" tline
	$wtxt insert end " " ttitle
	set icon [::Plugins::GetIconForPackage $plug 16]
	if {$icon != ""} {
	    $wtxt image create end -image $icon
	}
	$wtxt insert end " $plug\n" ttitle
	$wtxt insert end "\n" tline
	$wtxt insert end "\tType:\t" tkey
	$wtxt insert end "[::Plugins::GetTypeDesc $plug]\n" ttxt
	$wtxt insert end "\tDescription:\t" tkey
	$wtxt insert end "[::Plugins::GetDescForPlugin $plug]\n" ttxt
	$wtxt insert end "\tVersion:\t" tkey
	$wtxt insert end "$txtver\n" ttxt
	$wtxt insert end "\tSuffixes:\t" tkey
	$wtxt insert end "$txtsuf\n" ttxt
	$wtxt insert end "\n"
    }
    $wtxt configure -state disabled
    bind $w <Return> "$w.frall.frbot.ok invoke"
    
    tkwait window $w
    grab release $w
}

# It implements the dialog for choosing type of network topology and some 
# options.

namespace eval ::NetworkSetup:: {
    
}

# NetworkSetup::StartServer --
#
#       Starts the reflector server as a separate process. Platform specific!
#       
# Arguments:
#       wbt   ???.
#       
# Results:
#       starts a new tcl process.

proc ::NetworkSetup::StartServer { wbt } {
    global  this state prefs
        
    set path [file join $this(path) lib ReflectorServer.tcl]
    
    # Start the reflector server as a background process. Mac not working!
    
    switch -- $this(platform) {
	macintosh {
	    tk_messageBox -message  \
	      "The Reflector Server can't be started on the Mac, Sorry."  \
	      -icon error -type ok
	    return
	    
	    # Don't know Applescript yet!
	    AppleScript execute {open application TclShell}
	    AppleScript execute {tell application TclShell to do script "puts hello"}
	}
	windows {
	    
	    # Need to start the right version, try same is present.
	    regsub -all {\.} [info tclversion] {} ver
	    set prgm tclsh${ver}.exe
	    if {[catch {exec $prgm $path $prefs(reflectPort) &} res]} {
		tk_messageBox -message  \
		  "Failed starting the Reflector Server: $res"  \
		  -icon error -type ok
		return
	    } else {
		set state(reflectPid) $res
	    }
	}
	unix - macosx {
	    
	    # Remeber, the exec does not go through an Unix shell!
	    if {[catch {exec tclsh $path $prefs(reflectPort) &} res]} {
		tk_messageBox -message  \
		  "Failed starting the Reflector Server: $res"  \
		  -icon error -type ok
		return
	    } else {
		set state(reflectPid) $res
	    }
	}
    }
    $wbt configure -text " Stop Server " -command  \
      [list ::NetworkSetup::StopServer $wbt]
    set state(reflectorStarted) 1
}

# NetworkSetup::StopServer --
#
#       Stops the reflector server. Kills process.
#       
# Arguments:
#       wbt   ???.
#       
# Results:
#       kills tcl process.

proc ::NetworkSetup::StopServer { {wbt {}} } {
    global  this state prefs
    
    if {[string equal $this(platform) "macintosh"]} {
	return
    }
    
    # Stop the reflector servers background process. Mac not working!
    switch -- $this(platform) {
	windows {
	    
	    # Need to find the right DOS command here.
	    set s [socket $this(ipnum) $prefs(reflectPort)]
	    puts $s "KILL:"
	    catch {close $s}
	}
	unix - macosx {
	    if {[catch {exec kill $state(reflectPid)} res]} {
		tk_messageBox -message  \
		  "Failed stopping the Reflector Server: $res"  \
		  -icon error -type ok
		return

	    }
	}
    }
    Debug 2 "::NetworkSetup::StopServer  "

    if {[winfo exists $wbt]} {
	$wbt configure -text " Start Server " -command  \
	  [list ::NetworkSetup::StartServer $wbt]
    }
    set state(reflectorStarted) 0
}

#-- end ::NetworkSetup:: -------------------------------------------------------

# Printing the canvas on Unix/Linux.

namespace eval ::Dialogs:: {
    
    variable psCmd
    variable finishedPrint
}

# ::Dialogs::UnixPrintPS --
#
#       It implements the dialog for printing the canvas on Unix/Linux.
#       
# Arguments:
#       w      the toplevel dialog.
#       wtoprint widget to print, Canvas or Text class
#       
# Results:
#       shows dialog.

proc ::Dialogs::UnixPrintPS {w wtoprint} {
    global  sysFont prefs this
    
    variable psCmd
    variable finishedPrint
    
    Debug 2 "PrintPSonUnix (entry)::"

    set finishedPrint -1
    set psCmd $prefs(unixPrintCmd)
    
    catch {toplevel $w}
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w {Print Canvas}
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    set w1 $w.frall.fr1
    set wcont1 [LabeledFrame2 $w1 [::msgcat::mc Print]]
    
    # Overall frame for whole container.
    set frtot [frame $wcont1.frin]
    pack $frtot -padx 10 -pady 10
    
    message $frtot.msg -borderwidth 0 -font $sysFont(s) -aspect 1000 \
      -text "Shell print command, edit if desired."
    entry $frtot.entcmd -width 20 -font $sysFont(m)   \
      -textvariable [namespace current]::psCmd
    grid $frtot.msg -column 0 -row 0 -padx 4 -pady 2 -sticky news
    grid $frtot.entcmd -column 0 -row 1 -padx 4 -pady 2 -sticky news
    pack $w1 -fill x
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btpr -text [::msgcat::mc Print] -width 8 -default active  \
      -command "set [namespace current]::finishedPrint 1"]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command "set [namespace current]::finishedPrint 0"]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -in $w.frall  \
      -padx 8 -pady 6
    wm resizable $w 0 0
    
    # Grab and focus.
    focus $w
    focus $frtot.entcmd
    bind $w <Return> "$frbot.btpr invoke"
    tkwait variable [namespace current]::finishedPrint
    
    # Print...
    if {$finishedPrint == 1} {
	switch -- [winfo class $wtoprint] {
	    Canvas {
	
		# Pipe instead of using a temporary file. Note eval!
		# Note extra braces to protect eval'ing postscript!		
		if {[catch {eval exec $psCmd <<    \
		  {[eval $wtoprint postscript $prefs(postscriptOpts)]}} msg]} {
		    tk_messageBox -message  \
		      "Error when printing: $msg" -icon error -type ok
		}
	    }
	    Text {
		if {[catch {eval exec $psCmd <<    \
		  {[$wtoprint get 1.0 end]}} msg]} {
		    tk_messageBox -message  \
		      "Error when printing: $msg" -icon error -type ok
		}
	    }
	}
	set prefs(unixPrintCmd) $psCmd
    }
    catch {grab release $w}
    destroy $w
    return $finishedPrint
}

# Choosing postscript options for the canvas.

namespace eval ::PSPageSetup:: {
    
    namespace export PSPageSetup

    variable copyOfPostscriptOpts
    variable txtvarEnt
    variable menuBtVar
    variable allOptNames
    variable unitsFull2Short
    variable unitsShort2Full
    variable rotFull2Short
    variable rotShort2Full
    variable finished
}

# PSPageSetup::PSPageSetup --
#
#       It implements a dialog to select postscript options for canvas.
#       
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       shows dialog.

proc ::PSPageSetup::PSPageSetup { w } {
    global  sysFont prefs this
    
    variable copyOfPostscriptOpts
    variable txtvarEnt
    variable menuBtVar
    variable allOptNames
    variable unitsFull2Short
    variable unitsShort2Full
    variable rotFull2Short
    variable rotShort2Full
    variable finished
    
    Debug 2 "PSPageSetup (entry)::"

    set finished -1
    set num_ {[0-9\.]+}
    
    # The options.
    set allOptNames {colormode height pageanchor pageheight  \
      pagewidth pagex pagey rotate width x y}
    set unitsShort {p c m i}
    set unitsFull {point cm mm inch}
    array set unitsFull2Short {point p cm c mm m inch i}
    array set unitsShort2Full {p point c cm m mm i inch}
    array set rotFull2Short {portrait 0 landscape 1}
    array set rotShort2Full {0 portrait 1 landscape}
    
    # List available options of special option menus.
    array set theMenuOpts {   \
      colormode {color grey mono}  \
      pageanchor {n ne e se s sw w nw center}  \
      rotate {portrait landscape}}
    
    # Take a copy of the actual options to work on.
    array set copyOfPostscriptOpts $prefs(postscriptOpts)
    
    # Write this container as a simple proc with automatic sizing.
    if {[winfo exists $w]} {
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w "Page Setup"
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    set w1 $w.frall.fr1
    set wcont [LabeledFrame2 $w1 {Postscript Page Setup}]
    
    # Overall frame for whole container.
    set frtot [frame $wcont.frin]
    pack $frtot -padx 10 -pady 10
    
    message $frtot.msg -width 200 -font $sysFont(s) -text  \
      "Set any of the following options for the postscript\
      generated when printing or saving the canvas as\
      a postscript file."
    grid $frtot.msg -column 0 -columnspan 2 -row 0 -sticky news   \
      -padx 2 -pady 1
    
    # All the options.
    set iLine 0
    foreach optName $allOptNames {
	incr iLine
	label $frtot.lbl$optName -text "${optName}:" -font $sysFont(sb)
	frame $frtot.fr$optName
	
	if {[string equal $optName "colormode"] ||  \
	  [string equal $optName "pageanchor"] ||  \
	  [string equal $optName "rotate"]} {
	    
	    # Only menubutton.
	    # Get value if exists.
	    if {[info exists copyOfPostscriptOpts(-$optName)]} {
		if {[string equal $optName "rotate"]} {
		    
		    # Get full menu name.
		    set menuBtVar($optName)   \
		      $rotShort2Full($copyOfPostscriptOpts(-$optName))
		} else {
		    set menuBtVar($optName)   \
		      $copyOfPostscriptOpts(-$optName)
		}
	    } else {
		set menuBtVar($optName)   \
		  [lindex $theMenuOpts($optName) 0]
	    }
	    set wMenu [eval {tk_optionMenu $frtot.menu$optName   \
	      [namespace current]::menuBtVar($optName)}    \
	      $theMenuOpts($optName)]
	    $wMenu configure -font $sysFont(sb)
	    $frtot.menu$optName configure -font $sysFont(sb)   \
	      -highlightthickness 0 -background $prefs(bgColGeneral)   \
	      -foreground black
	    pack $frtot.menu$optName -in $frtot.fr$optName
	    
	} else {
	    
	    # Length option.
	    # Get value if exists. Need to separate value and unit.
	    if {[info exists copyOfPostscriptOpts(-$optName)]} {
		set valUnit $copyOfPostscriptOpts(-$optName)
		regexp "(${num_})(p|c|m|i)" $valUnit match val unit
		set txtvarEnt($optName) $val
		set menuBtVar($optName) $unitsShort2Full($unit)
	    } else {
		set txtvarEnt($optName) {}
		set menuBtVar($optName) [lindex $unitsFull 0]
	    }
	    entry $frtot.ent$optName -width 8   \
	      -textvariable [namespace current]::txtvarEnt($optName)
	    set wMenu [eval {tk_optionMenu $frtot.menu$optName   \
	      [namespace current]::menuBtVar($optName)}   \
	      $unitsFull]
	    $wMenu configure -font $sysFont(sb)
	    $frtot.menu$optName configure -font $sysFont(sb)   \
	      -highlightthickness 0 -background $prefs(bgColGeneral)   \
	      -foreground black
	    pack $frtot.ent$optName $frtot.menu$optName   \
	      -in $frtot.fr$optName -side left
	}
	grid $frtot.lbl$optName -column 0 -row $iLine -sticky e -padx 2 -pady 1
	grid $frtot.fr$optName -column 1 -row $iLine -sticky w -padx 2 -pady 1
    }
    pack $w1 -fill x
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btsave -text [::msgcat::mc Save] -width 8 -default active  \
      -command [list [namespace current]::PushBtSave]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command "set [namespace current]::finished 0"]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -in $w.frall  \
      -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btsave invoke"
    
    # Grab and focus.
    focus $w
    catch {grab $w}
    tkwait variable [namespace current]::finished
    catch {grab release $w}
    destroy $w
    return $finished
}
    
#   PushBtSave ---
#
#   Read out options from the panel and save in 'prefs(postscriptOpts)'.

proc ::PSPageSetup::PushBtSave {  } {
    global  prefs
    
    variable copyOfPostscriptOpts
    variable txtvarEnt
    variable menuBtVar
    variable allOptNames
    variable unitsFull2Short
    variable unitsShort2Full
    variable rotFull2Short
    variable rotShort2Full
    variable finished

    set num_ {([0-9]+|[0-9]+\.[0-9]*|\.[0-9]+)}
    set allNewOpts {}
    foreach optName $allOptNames {
	
	if {[string equal $optName "colormode"] ||  \
	  [string equal $optName "pageanchor"] ||  \
	  [string equal $optName "rotate"]} {
	    if {[string equal $optName "rotate"]} {
		
		# Get short name from full name in menu.
		set val $rotFull2Short($menuBtVar($optName))
	    } else {
		set val $menuBtVar($optName)
	    }
	    lappend allNewOpts "-$optName" $val
	} else {
	    # If length option in entry.
	    if {[string length $txtvarEnt($optName)] > 0} {
		set unit $unitsFull2Short($menuBtVar($optName))
		
		# Check consistency of length value.
		if {![regexp "^${num_}$" $txtvarEnt($optName)]} {
		    
		    # Not a valid number.
		    tk_messageBox -icon error -type ok -message   \
		      "Error: not a valid number for $optName" 		      
		    return
		}
		set val $txtvarEnt($optName)$unit
		lappend allNewOpts "-$optName" $val
	    }
	}
    }
    set prefs(postscriptOpts) $allNewOpts
    set finished 1
}

#-- end ::PSPageSetup:: --------------------------------------------------------

# Dialogs::ShowInfoClients --
#
#       It implements a dialog that shows client information.
#       
# Arguments:
#       w      the toplevel window.
#       allIPnumsFrom   list of ip numbers of all connected clients.
#       
# Results:
#       shows dialog.

proc ::Dialogs::ShowInfoClients {w allIPnumsFrom} {
    global  sysFont ipNumTo this
    
    if {[llength $allIPnumsFrom] <= 0} {
	return
    }
    if {[winfo exists $w]} {
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w "Client Info"
    pack [frame $w.frall -borderwidth 1 -relief raised]
    pack [frame $w.frtop -borderwidth 0] -in $w.frall
    
    
    # Treat each connected client in order and make a labelled frame for each.
    set n 0
    foreach ip $allIPnumsFrom {
	set channel $ipNumTo(servSocket,$ip)
	set peername [fconfigure $channel -peername]
	set sockname [fconfigure $channel -sockname]
	set buff [fconfigure $channel -buffering]
	set block [fconfigure $channel -blocking]
	set wcont [LabeledFrame2 $w.frtop$n [lindex $peername 1]]
	pack $w.frtop$n -in $w.frtop
	
	# Frame for everything inside the labeled container.
	set fr [frame $wcont.fr]
	label $fr.a1 -text "IP number:" -font $sysFont(sb)
	label $fr.a2 -text "[lindex $peername 0]"
	label $fr.b1 -text "Host name:" -font $sysFont(sb)
	label $fr.b2 -text "[lindex $peername 1]"
	label $fr.c1 -text "User name:" -font $sysFont(sb)
	label $fr.c2 -text $ipNumTo(user,$ip)
	label $fr.d1 -text "Port number:" -font $sysFont(sb)
	label $fr.d2 -text "$ipNumTo(servPort,$ip)"
	label $fr.e1 -text "Buffering:" -font $sysFont(sb)
	label $fr.e2 -text "$buff"
	label $fr.f1 -text "Blocking:" -font $sysFont(sb)
	label $fr.f2 -text "$block"
	label $fr.g1 -text "Since:" -font $sysFont(sb)
	label $fr.g2 -text   \
	  "[clock format $ipNumTo(connectTime,$ip) -format "%X  %x"]"
	grid $fr.a1 -column 0 -row 0 -sticky e
	grid $fr.a2 -column 1 -row 0 -sticky w
	grid $fr.b1 -column 0 -row 1 -sticky e
	grid $fr.b2 -column 1 -row 1 -sticky w
	grid $fr.c1 -column 0 -row 2 -sticky e
	grid $fr.c2 -column 1 -row 2 -sticky w
	grid $fr.d1 -column 0 -row 3 -sticky e
	grid $fr.d2 -column 1 -row 3 -sticky w
	grid $fr.e1 -column 0 -row 4 -sticky e
	grid $fr.e2 -column 1 -row 4 -sticky w
	grid $fr.f1 -column 0 -row 5 -sticky e
	grid $fr.f2 -column 1 -row 5 -sticky w
	grid $fr.g1 -column 0 -row 6 -sticky e
	grid $fr.g2 -column 1 -row 6 -sticky w
	pack $fr -side left -padx 20
	pack $wcont -fill x    
	incr n
    }
    
    # Button part.
    pack [frame $w.frbot -borderwidth 0] -in $w.frall -fill both  \
      -padx 8 -pady 6
    pack [button $w.ok -text [::msgcat::mc OK] -default active  \
      -width 8 -command "destroy $w"] \
      -in $w.frbot -side right -padx 5 -pady 5
    wm resizable $w 0 0
    bind $w <Return> "$w.ok invoke"

    tkwait window $w
    grab release $w
}

#-- end ShowInfoClients --------------------------------------------------------

# Dialogs::ShowInfoServer --
#
#       It shows server information. Uses one of the 'allIPnumsTo' to get a 
#       channel which is used to obtain information. If not connected, then 
#       give only the hostname if available.
#       
# Arguments:
#       w      the toplevel window.
#       thisIPnum   the servers local ip number.
#       
# Results:
#       none

proc ::Dialogs::ShowInfoServer {w thisIPnum} {
    global  sysFont this ipNumTo allIPnumsFrom  \
      state listenServSocket this prefs
    
    if {[winfo exists $w]} {
	return
    }
    array set boolToYesNo [list 0 [::msgcat::mc no] 1 [::msgcat::mc yes]]
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc {Server Info}]
    pack [frame $w.frall -borderwidth 1 -relief raised]
    set wcont [LabeledFrame2 $w.frtop [::msgcat::mc {Server Info}]]
    pack $w.frtop -in $w.frall    
    
    # Frame for everything inside the labeled container.
    set fr [frame $wcont.fr]
    label $fr.x1 -text "[::msgcat::mc {Is server up}]:" -font $sysFont(sb)
    label $fr.x2 -text $boolToYesNo($state(isServerUp))
    label $fr.a1 -text "[::msgcat::mc {This IP number}]:" -font $sysFont(sb)
    label $fr.b1 -text "[::msgcat::mc {Host name}]:" -font $sysFont(sb)
    label $fr.c1 -text "[::msgcat::mc Username]:" -font $sysFont(sb)
    label $fr.d1 -text "[::msgcat::mc {Port number}]:" -font $sysFont(sb)
    label $fr.e1 -text "[::msgcat::mc Buffering]:" -font $sysFont(sb)
    label $fr.f1 -text "[::msgcat::mc Blocking]:" -font $sysFont(sb)
    label $fr.g1 -text "[::msgcat::mc {Is safe}]:" -font $sysFont(sb)

    if {!$state(isServerUp)} {
	
	# Not yet started server.
	set theHostname [info hostname]
	if {[string length $theHostname] == 0} {
	    set theHostname [::msgcat::mc {Not available}]
	}
	label $fr.a2 -text $thisIPnum
	label $fr.b2 -text $theHostname
	label $fr.c2 -text $this(username)
	label $fr.d2 -text [::msgcat::mc {Not available}]
	label $fr.e2 -text [::msgcat::mc {Not available}]
	label $fr.f2 -text [::msgcat::mc {Not available}]
	label $fr.g2 -text [::msgcat::mc {Not available}]
	
    } elseif {$state(isServerUp) && [llength $allIPnumsFrom] == 0} {

	# Not yet connected but up.
	set theHostname [info hostname]
	if {[string length $theHostname] == 0} {
	    set theHostname [::msgcat::mc {Not available}]
	}
	set sockname [fconfigure $listenServSocket -sockname]
	label $fr.a2 -text $thisIPnum
	label $fr.b2 -text $theHostname
	label $fr.c2 -text $this(username)
	label $fr.d2 -text $prefs(thisServPort)
	label $fr.e2 -text [::msgcat::mc {Not available}]
	label $fr.f2 -text [::msgcat::mc {Not available}]
	label $fr.g2 -text "$boolToYesNo($prefs(makeSafeServ))"

    } elseif {$state(isServerUp) && [llength $allIPnumsFrom] > 0} {
	
	# Take any ip and get server side channel.
	set channel $ipNumTo(servSocket,[lindex $allIPnumsFrom 0])
	set peername [fconfigure $channel -peername]
	set sockname [fconfigure $channel -sockname]
	set buff [fconfigure $channel -buffering]
	set block [fconfigure $channel -blocking]
	label $fr.a2 -text $thisIPnum
	label $fr.b2 -text "[info hostname]"
	label $fr.c2 -text $this(username)
	label $fr.d2 -text $prefs(thisServPort)
	label $fr.e2 -text $buff
	label $fr.f2 -text "$block"
	label $fr.g2 -text "$boolToYesNo($prefs(makeSafeServ))"
    }
    grid $fr.x1 -column 0 -row 0 -sticky e
    grid $fr.x2 -column 1 -row 0 -sticky w
    grid $fr.a1 -column 0 -row 1 -sticky e
    grid $fr.a2 -column 1 -row 1 -sticky w
    grid $fr.b1 -column 0 -row 2 -sticky e
    grid $fr.b2 -column 1 -row 2 -sticky w
    grid $fr.c1 -column 0 -row 3 -sticky e
    grid $fr.c2 -column 1 -row 3 -sticky w
    grid $fr.d1 -column 0 -row 4 -sticky e
    grid $fr.d2 -column 1 -row 4 -sticky w
    grid $fr.e1 -column 0 -row 5 -sticky e
    grid $fr.e2 -column 1 -row 5 -sticky w
    grid $fr.f1 -column 0 -row 6 -sticky e
    grid $fr.f2 -column 1 -row 6 -sticky w
    grid $fr.g1 -column 0 -row 7 -sticky e
    grid $fr.g2 -column 1 -row 7 -sticky w
    pack $fr -side left -padx 20    
    pack $wcont -fill x    
        
    # button part
    pack [frame $w.frbot -borderwidth 0] -in $w.frall -fill both  \
      -padx 8 -pady 6
    pack [button $w.ok -text [::msgcat::mc OK] -width 8  \
      -command "destroy $w"]  \
      -in $w.frbot -side right -padx 5 -pady 5
    wm resizable $w 0 0
    bind $w <Return> "$w.ok invoke"
    
    tkwait window $w
    grab release $w
}


# Handles the splash screen.

namespace eval ::SplashScreen:: {
        
    # Name of variable for message displat.
    variable startMsg ""
    variable topwin ""
}

# SplashScreen::SplashScreen --
#
#       Shows the splash screen.
#       
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       none

proc ::SplashScreen::SplashScreen {w} {
    global  sysFont this prefs
    variable topwin
    variable canwin
    variable startMsg
    
    set topwin $w
    if [catch {toplevel $w}] {
	return
    }
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w movableDBoxProc
	wm transient $w .
    } else {
	wm transient $w
    }
    wm title $w [::msgcat::mc {About Coccinella}]
    wm resizable $w 0 0
    foreach {screenW screenH} [GetScreenSize] break
    wm geometry $w +[expr ($screenW - 450)/2]+[expr ($screenH - 300)/2]
    
    # If image not already there, get it.
    
    if {[lsearch [image names] mysplash] == -1} {
	image create photo mysplash -format gif -file   \
	  [file join $this(path) images splash.gif]
    }
    set imHeight [image height mysplash]
    set imWidth [image width mysplash]
    foreach {r g b} [mysplash get 50 [expr $imHeight - 20]] break
    if {[expr $r + $g + $b] > [expr 2*255]} {
	set textcol black
    } else {
	set textcol white
    }
    set canwin $w.can
    canvas $w.can -width $imWidth -height $imHeight -bd 0 -highlightthickness 0
    $w.can create image 0 0 -anchor nw -image mysplash
    $w.can create text 50 [expr $imHeight - 20] -anchor nw -tags tsplash  \
      -font $sysFont(s) -text $startMsg -fill $textcol
    
    # Print patch level for dev versions.
    if {$prefs(releaseVers) != ""} {
	$w.can create text 420 [expr $imHeight - 40] -anchor nw  \
	  -font {Helvetica 18} -text $prefs(releaseVers) -fill #ef2910
    }
    
    pack $w.can
    bind $w <Return> [list destroy $w]
    bind $w <Button-1> [list destroy $w]
}

proc ::SplashScreen::SetMsg {msg} {
    variable topwin
    variable canwin
    variable startMsg
    
    set startMsg $msg
    
    # Update needed to force display (bad?).
    if {[winfo exists $topwin]} {
	$canwin itemconfigure tsplash -text $startMsg
	update idletasks
    }
}

namespace eval ::Dialogs:: {
    
    # Running number to create unique toplevel paths.
    variable uidcan 0
}

# Dialogs::Canvas --
# 
#       Display a *.can file into simple canvas window.

proc ::Dialogs::Canvas {filePath args} {
    global this prefs
    variable uidcan
    
    if {[catch {open $filePath r} fd]} {
	return
    }
    set w .spcan[incr uidcan]
    if [catch {toplevel $w}] {
	return
    }
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    array set argsArr [list -title [file rootname [file tail $filePath]]]
    array set argsArr $args
    wm title $w $argsArr(-title)
    wm resizable $w 0 0
    foreach {screenW screenH} [GetScreenSize] break
    set xmax 200
    set ymax 200
    set wcan $w.can
    canvas $wcan -width $xmax -height $ymax -highlightthickness 0 -bg white
    pack $wcan
    
    while {[gets $fd line] >= 0} { 
	
	# Skip any comment lines and empty lines.
	if {[regexp {(^ *#|^[ \n\t]*$)} $line]} {
	    continue
	}
	set cmd [lindex $line 0]
	set type [lindex $line 1]
	
	switch -- $cmd {
	    create {
		
		# Make newline substitutions.
		set cmd [subst -nocommands -novariables $line]
		if {[string equal $type "text"]} {
		    set cmd [::CanvasUtils::FontHtmlToPointSize $cmd]
		}
		set id [eval $wcan $cmd]
	    }
	    import {
		set ind [lsearch -exact $line -file]
		if {$ind >= 0} {
		    ::ImageAndMovie::HandleImportCmd $wcan $line -where local \
		      -basepath [file dirname $filePath]
		}
	    }
	}
    }
    foreach {x0 y0 x1 y1} [eval {$wcan bbox} [$wcan find all]] break
    incr x1 20
    incr y1 20
    $wcan configure -width $x1 -height $y1
    catch {close $fd}
}

proc ::Dialogs::AboutQuickTimeTcl { } {
    global  this
    
    set w .abqt
    if {[winfo exists $w]} {
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
	wm transient $w
    } else {

    }
    wm title $w [::msgcat::mc {About QuickTimeTcl}]
    
    pack [movie $w.m -file [file join $this(path) images FakeSample.mov]]
    set theSize [$w.m size]
    set mw [lindex $theSize 0]
    set mh [lindex $theSize 1]
    foreach {screenW screenH} [GetScreenSize] break
    wm geometry $w +[expr ($screenW - $mw)/2]+[expr ($screenH - $mh)/2]
    update
    wm resizable $w 0 0
    $w.m play
}

#-------------------------------------------------------------------------------