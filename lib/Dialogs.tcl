#  Dialogs.tcl ---
#  
#      This file is part of The Coccinella application. It implements some
#      of the dialogs. 
#      
#  Copyright (c) 1999-2005  Mats Bengtsson
#  
# $Id: Dialogs.tcl,v 1.59 2005-08-14 07:17:55 matben Exp $
   
package provide Dialogs 1.0

namespace eval ::Dialogs:: {
    
    # Add all event hooks.
    ::hooks::register quitAppHook ::Dialogs::Free 10
}

# Dialogs::GetCanvas --
# 
#       Implements the dialog for choosing which client to get the 
#       canvas from. P2P only!

proc ::Dialogs::GetCanvas {w} {
    global  prefs this
    
    variable finished -1
    variable getIPName
    
    # Build list of ip names.
    set ipNames {}
    foreach ip [::P2PNet::GetIP to] {
	set name [::P2PNet::GetValueFromIP $ip name]
	if {$name ne ""} {
	    lappend ipNames $name
	}
    }
    if {$ipNames == {}} {
	return 
    }
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [mc {Get Canvas}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Labelled frame.
    set wcfr $wbox.fr
    ttk::labelframe $wcfr -padding [option get . groupSmallPadding {}] \
      -text [mc {Get Canvas}]
    pack $wcfr -side top -fill both
    
    ttk::label $wcfr.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left  \
      -text "Choose client from which you want to get the canvas.\
      Your own canvas will be erased."
    eval {ttk::optionmenu $wcfr.optm [namespace current]::getIPName} $ipNames

    grid  $wcfr.msg  -           -pady 4 -sticky news
    grid  x          $wcfr.optm  -pady 4 -sticky e
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Get] -default active \
      -command [list set [namespace current]::finished 1]
    ttk::button $frbot.btcancel -text [mc Cancel] \
      -command [list set [namespace current]::finished 2]
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
    bind $w <Return> [list set [namespace current]::finished 1]
    
    # Grab and focus.
    focus $w
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finished
    
    catch {grab release $w}
    catch {destroy $w}
    
    if {$finished == 1} {
	return [::P2PNet::GetIPFromName $getIPName]
    } else {
	return ""
    }
}

#  Dialogs::InfoOnPlugins ---
#  
#      It implements the dialog for presenting the loaded packages or helper 
#      applications.

proc ::Dialogs::InfoOnPlugins { } {
    global  prefs this wDlgs
    
    # Check first of there are *any* plugins.
    if {[llength [::Plugins::GetAllPackages loaded]] == 0} {
	::UI::MessageBox -icon info -type ok -message [mc messnoplugs]
	return  
    }
    set w $wDlgs(plugs)
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1
    wm title $w [mc {Plugin Info}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] -command [list destroy $w]
    pack $frbot.btok -side right
    pack $frbot -side bottom -fill x

    set fbox $wbox.f
    frame $fbox -bd 1 -relief sunken
    pack  $fbox -side top -fill both -expand 1
    
    set xtab1 80
    set xtab2 90
    set wtxt $fbox.txt
    set wysc $fbox.ysc
    tuscrollbar $wysc -orient vertical -command [list $wtxt yview]
    text $wtxt -yscrollcommand [list $wysc set] -highlightthickness 0  \
      -bg white -wrap word -width 50 -height 30  \
      -exportselection 1 -tabs [list $xtab1 right $xtab2 left]
    pack $wysc -side right -fill y
    pack $wtxt -side left -fill both -expand 1
    
    $wtxt tag configure ttitle -foreground black -background #dedede  \
      -spacing1 2 -spacing3 2 -lmargin1 20 -font CociSmallBoldFont
    $wtxt tag configure tkey -font CociSmallBoldFont -spacing1 2  \
      -tabs [list $xtab1 right $xtab2 left]
    $wtxt tag configure ttxt -font CociSmallFont -wrap word -lmargin1 $xtab2 \
      -lmargin2 $xtab2
    $wtxt tag configure tline -font {Helvetica -1} -background black
    
    # If mac or win and not QuickTime, make an ad as the first item.
    if {[::Plugins::IsHost QuickTimeTcl] &&  \
      ![::Plugins::HavePackage QuickTimeTcl]} {

	set ad "Get QuickTime for free from Apple at www.apple.com/quicktime.\
	  It adds a lot of functionality to this application."
	$wtxt insert end "\n" tline
	$wtxt insert end "QuickTimeTcl\n" ttitle
	$wtxt insert end "\n" tline
	$wtxt insert end "\tDownload:\t" tkey
	::Text::Parse $wtxt $ad ttxt
	$wtxt insert end "\n\n"
    }
            
    # Try the known plugind and apps, and make a labelled frame for each.
    foreach plug [::Plugins::GetAllPackages loaded] {
	
	set txtver [::Plugins::GetVersionForPackage $plug]
	if {$txtver eq ""} {
	    set txtver "unknown"
	}
	set txtsuf [::Plugins::GetSuffixes $plug]
	if {$txtsuf eq ""} {
	    set txtsuff "none"
	}
	
	$wtxt insert end "\n" tline
	$wtxt insert end " " ttitle
	set icon [::Plugins::GetIconForPackage $plug 16]
	if {$icon ne ""} {
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
    bind $w <Return> [list $frbot.btok invoke]
    
    tkwait window $w
    grab release $w
}

proc ::Dialogs::InfoComponents { } {
    global  prefs this wDlgs
    
    # Check first of there are *any* components.
    set compList [component::getall]
    if {[llength $compList] == 0} {
	::UI::MessageBox -icon info -type ok -message [mc messnoplugs]
	return  
    }
    set w $wDlgs(comp)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1
    wm title $w [mc {Component Info}]
     
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] -command [list destroy $w]
    pack $frbot.btok -side right
    pack $frbot -side bottom -fill x

    set tbox $wbox.t
    frame $tbox -bd 1 -relief sunken
    pack  $tbox -fill both -expand 1

    set wtxt $tbox.txt
    set wysc $tbox.ysc
    tuscrollbar $wysc -orient vertical -command [list $wtxt yview]
    text $wtxt -yscrollcommand [list $wysc set] -highlightthickness 0  \
      -bg white -wrap word -width 50 -height 16 -exportselection 1

    pack $wysc -side right -fill y
    pack $wtxt -side left -fill both -expand 1

    $wtxt tag configure ttitle -foreground black -background #dedede  \
      -spacing1 2 -spacing3 2 -lmargin1 20 -font CociSmallBoldFont
    $wtxt tag configure ttxt -font CociSmallFont -wrap word -lmargin1 10 -lmargin2 10 \
      -spacing1 6 -spacing3 6
    $wtxt tag configure tline -font {Helvetica -1} -background black
    
    foreach {name str} $compList {
	$wtxt insert end "$name\n" ttitle
	$wtxt insert end "$str\n" ttxt
    }
    $wtxt configure -state disabled
    bind $w <Return> [list $frbot.btok invoke]
}

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
    
    set kprinter [auto_execok kprinter]
    if {[llength $kprinter]} {
	set cmd [lindex $kprinter 0]
	KPrinter $w $wtoprint $cmd
    } else {
	UnixPrintLpr $w $wtoprint
    }
}

proc ::Dialogs::KPrinter {w wtoprint cmd} {
    global  this prefs

    # Save to temp file.
    set tmpfile [::tfileutils::tempfile $this(tmpPath) prnt]
    
    switch -- [winfo class $wtoprint] {
	Canvas {
	    append tmpfile .ps
	}
	Text {
	    append tmpfile .txt
	}
    }
    
    if {[catch {set fd [open $tmpfile {CREAT WRONLY}]} err]} {
	::UI::MessageBox -message  \
	  "Error when printing: $err" -icon error -type ok
	return
    }
    fconfigure $fd -translation binary
    
    switch -- [winfo class $wtoprint] {
	Canvas {
	    puts $fd [eval {$wtoprint postscript} $prefs(postscriptOpts)]
	}
	Text {
	    puts $fd [$wtoprint get 1.0 end]
	}
    }
    close $fd
    exec $cmd [list $tmpfile] &
}

proc ::Dialogs::UnixPrintLpr {w wtoprint} {
    global  prefs this
    
    variable psCmd
    variable finishedPrint
    
    Debug 2 "PrintPSonUnix (entry)::"

    set finishedPrint -1
    set psCmd $prefs(unixPrintCmd)
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} -closecommand ::Dialogs::UnixPrintLprClose
    wm title $w [mc Print]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set frtot $wbox.f
    ttk::labelframe $frtot -padding [option get . groupSmallPadding {}] \
      -text [mc Print]
    pack $frtot -side top
        
    ttk::label $frtot.msg -style Small.TLabel \
      -wraplength 300 -justify left -text [mc printunixcmd]
    ttk::entry $frtot.entcmd -width 20   \
      -textvariable [namespace current]::psCmd

    grid  $frtot.msg     -pady 2 -sticky news
    grid  $frtot.entcmd  -pady 2 -sticky news
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Print] -default active  \
      -command [list set [namespace current]::finishedPrint 1]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list set [namespace current]::finishedPrint 0]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x

    wm resizable $w 0 0
    
    # Grab and focus.
    focus $w
    focus $frtot.entcmd
    bind $w <Return> [list $frbot.btok invoke]
    tkwait variable [namespace current]::finishedPrint
    
    # Print...
    if {$finishedPrint == 1} {
	switch -- [winfo class $wtoprint] {
	    Canvas {
	
		# Pipe instead of using a temporary file. Note eval!
		# Note extra braces to protect eval'ing postscript!		
		if {[catch {eval exec $psCmd <<    \
		  {[eval $wtoprint postscript $prefs(postscriptOpts)]}} msg]} {
		    ::UI::MessageBox -message  \
		      "Error when printing: $msg" -icon error -type ok
		}
	    }
	    Text {
		if {[catch {eval exec $psCmd <<    \
		  {[$wtoprint get 1.0 end]}} msg]} {
		    ::UI::MessageBox -message  \
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

proc ::Dialogs::UnixPrintLprClose {w} {
    variable finishedPrint
    
    set finishedPrint 0
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

proc ::PSPageSetup::PSPageSetup {w} {
    global  prefs this
    
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
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} -closecommand ::PSPageSetup::CloseCmd
    wm title $w "Page Setup"
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set frtot $wbox.f
    ttk::labelframe $frtot -padding [option get . groupSmallPadding {}] \
      -text {Postscript Page Setup}
    pack $frtot
        
    ttk::label $frtot.msg -style Small.TLabel \
      -wraplength 300 -justify left -padding {0 0 0 8} \
      -text "Set any of the following options for the postscript\
      generated when printing or saving the canvas as\
      a postscript file."

    grid  $frtot.msg  -  -  -sticky news
    
    # All the options.
    foreach optName $allOptNames {
	ttk::label $frtot.l$optName -text "${optName}:"
	
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
	    eval {ttk::optionmenu $frtot.m$optName   \
	      [namespace current]::menuBtVar($optName)} \
	      $theMenuOpts($optName)
	    
	    grid  $frtot.l$optName  $frtot.m$optName  -  -sticky e -padx 2 -pady 2
	    grid  $frtot.m$optName  -sticky ew
	      
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
	    ttk::entry $frtot.e$optName -width 8   \
	      -textvariable [namespace current]::txtvarEnt($optName)
	    eval {ttk::optionmenu $frtot.m$optName   \
	      [namespace current]::menuBtVar($optName)}   \
	      $unitsFull

	    grid  $frtot.l$optName  $frtot.e$optName  $frtot.m$optName  \
	      -sticky e -padx 2 -pady 2
	    grid  $frtot.e$optName  $frtot.m$optName  -sticky ew
	}
    }
    grid columnconfigure $frtot 1 -weight 1
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Save] -default active  \
      -command [list [namespace current]::PushBtSave]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list set [namespace current]::finished 0]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    # Grab and focus.
    focus $w
    catch {grab $w}
    tkwait variable [namespace current]::finished
    catch {grab release $w}
    destroy $w
    return $finished
}

proc ::PSPageSetup::CloseCmd {w} {
    variable finished
    
    set finished 0
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
		    ::UI::MessageBox -icon error -type ok -message   \
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

# OBSOLETE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Dialogs::ShowInfoClients --
#
#       It implements a dialog that shows client information. ???
#       
# Arguments:
#       
# Results:
#       shows dialog.

proc ::Dialogs::ShowInfoClients { } {
    global  this wDlgs
    
    set allIPnumsFrom [::P2PNet::GetIP from]
    if {[llength $allIPnumsFrom] <= 0} {
	return
    }
    set w $wDlgs(infoClient)
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w "Client Info"
    
    pack [frame $w.frall -borderwidth 1 -relief raised]
    pack [frame $w.frtop -borderwidth 0] -in $w.frall
    
    
    # Treat each connected client in order and make a labelled frame for each.
    set n 0
    foreach ip [::P2PNet::GetIP from] {
	set channel  [::P2PNet::GetValueFromIP $ip servSocket]
	set peername [fconfigure $channel -peername]
	set sockname [fconfigure $channel -sockname]
	set buff  [fconfigure $channel -buffering]
	set block [fconfigure $channel -blocking]
	set wcont $w.frtop$n
	set wcont [labelframe $wcont -text [lindex $peername 1]]
	pack $wcont -in $w.frtop -padx 8 -pady 4
	
	# Frame for everything inside the labeled container.
	set fr [frame $wcont.fr]
	label $fr.a1 -text "IP number:" -font CociSmallBoldFont
	label $fr.a2 -text "[lindex $peername 0]"
	label $fr.b1 -text "Host name:" -font CociSmallBoldFont
	label $fr.b2 -text "[lindex $peername 1]"
	label $fr.c1 -text "User name:" -font CociSmallBoldFont
	label $fr.c2 -text [::P2PNet::GetValueFromIP $ip user]
	label $fr.d1 -text "Port number:" -font CociSmallBoldFont
	label $fr.d2 -text [::P2PNet::GetValueFromIP $ip servPort]
	label $fr.e1 -text "Buffering:" -font CociSmallBoldFont
	label $fr.e2 -text "$buff"
	label $fr.f1 -text "Blocking:" -font CociSmallBoldFont
	label $fr.f2 -text "$block"
	label $fr.g1 -text "Since:" -font CociSmallBoldFont
	label $fr.g2 -text [clock format [::P2PNet::GetValueFromIP $ip connectTime] \
	  -format "%X  %x"]
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
    pack [button $w.btok -text [mc OK] -default active  \
      -command "destroy $w"] \
      -in $w.frbot -side right -padx 5 -pady 5
    wm resizable $w 0 0
    bind $w <Return> "$w.btok invoke"

    tkwait window $w
    grab release $w
}

#-- end ShowInfoClients --------------------------------------------------------

# Dialogs::ShowInfoServer --
#
#       It shows server information. Uses one of the connections to get a 
#       channel which is used to obtain information. If not connected, then 
#       give only the hostname if available.
#       
# Arguments:
#       
# Results:
#       none

proc ::Dialogs::ShowInfoServer { } {
    global  this wDlgs state prefs
    
    set w $wDlgs(infoServ)
    if {[winfo exists $w]} {
	return
    }
    array set boolToYesNo [list 0 [mc no] 1 [mc yes]]
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [mc {Server Info}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    set fr $wbox.f
    ttk::labelframe $fr -padding [option get . groupSmallPadding {}] \
      -text [mc {Server Info}]
    pack $fr
    
    option add *$fr.TLabel.style Small.TLabel
    
    ttk::label $fr.x1 -text "[mc {Is server up}]:"
    ttk::label $fr.x2 -text $boolToYesNo($state(isServerUp))
    ttk::label $fr.a1 -text "[mc {This IP number}]:"
    ttk::label $fr.b1 -text "[mc {Host name}]:"
    ttk::label $fr.c1 -text "[mc Username]:"
    ttk::label $fr.d1 -text "[mc {Port number}]:"
    ttk::label $fr.e1 -text "[mc Buffering]:"
    ttk::label $fr.f1 -text "[mc Blocking]:"
    ttk::label $fr.g1 -text "[mc {Is safe}]:"

    if {!$state(isServerUp)} {
	ttk::label $fr.a2 -text $this(ipnum)
	ttk::label $fr.b2 -text $this(hostname)
	ttk::label $fr.c2 -text $this(username)
	ttk::label $fr.d2 -text [mc {Not available}]
	ttk::label $fr.e2 -text [mc {Not available}]
	ttk::label $fr.f2 -text [mc {Not available}]
	ttk::label $fr.g2 -text [mc {Not available}]
	
    } elseif {$state(isServerUp)} {
	set sockname [fconfigure $state(serverSocket) -sockname]
	ttk::label $fr.a2 -text $this(ipnum)
	ttk::label $fr.b2 -text $this(hostname)
	ttk::label $fr.c2 -text $this(username)
	ttk::label $fr.d2 -text $prefs(thisServPort)
	ttk::label $fr.e2 -text [mc {Not available}]
	ttk::label $fr.f2 -text [mc {Not available}]
	ttk::label $fr.g2 -text "$boolToYesNo($prefs(makeSafeServ))"

    }
    grid  $fr.x1  $fr.x2  -sticky e
    grid  $fr.a1  $fr.a2  -sticky e
    grid  $fr.b1  $fr.b2  -sticky e
    grid  $fr.c1  $fr.c2  -sticky e
    grid  $fr.d1  $fr.d2  -sticky e
    grid  $fr.e1  $fr.e2  -sticky e
    grid  $fr.f1  $fr.f2  -sticky e
    grid  $fr.g1  $fr.g2  -sticky e

    grid  $fr.x2  $fr.a2  $fr.b2  $fr.c2  $fr.d2  $fr.e2  $fr.f2  $fr.g2  -sticky w
        
    # button part
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] -command [list destroy $w]
    pack $frbot.btok -side right
    pack $frbot -side bottom -fill x

    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    tkwait window $w
    grab release $w
}

namespace eval ::Dialogs:: {
    
    # Running number to create unique toplevel paths.
    variable uidcan 0
}

# Dialogs::Canvas --
# 
#       Display a *.can file into simple canvas window.
#       A kind of minimal, readonly, whiteboard.

proc ::Dialogs::Canvas {filePath args} {
    global this prefs
    variable uidcan
    
    set w .spcan[incr uidcan]
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm withdraw $w
    
    # Make the namespace exist.
    namespace eval ::WB::${w}:: {}

    array set argsArr [list -title [file rootname [file tail $filePath]]]
    array set argsArr $args
    wm title $w $argsArr(-title)
    wm resizable $w 0 0
    foreach {screenW screenH} [::UI::GetScreenSize] break
    set xmax 200
    set ymax 200
    set wcan $w.can
    canvas $wcan -width $xmax -height $ymax -highlightthickness 0 -bg white
    pack $wcan

    if {[catch {open $filePath r} fd]} {
	return
    }
    fconfigure $fd -encoding utf-8
    if {[info exists argsArr(-encoding)]} {
	fconfigure $fd -encoding $argsArr(-encoding)
    }
    
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
		    ::Import::HandleImportCmd $wcan $line -where local \
		      -basepath [file dirname $filePath] -addundo 0
		}
	    }
	}
    }
    catch {close $fd}
    lassign [$wcan bbox all] x0 y0 x1 y1
    incr x1 20
    incr y1 20
    $wcan configure -width $x1 -height $y1
    update idletasks
    wm deiconify $w
    raise $w
}

namespace eval ::Dialogs:: {
    
    variable initedAboutQuickTimeTcl 0
    variable wAboutQuickTimeTcl .aboutqt
}

proc ::Dialogs::InitAboutQuickTimeTcl { } {
    global  this
    variable initedAboutQuickTimeTcl
    variable fakeQTSampleFile
    
    set origMovie [file join $this(imagePath) FakeSample.mov]
    set fakeQTSampleFile $origMovie
    
    # QuickTime doesn't understand vfs; need to copy out to tmp dir.
    if {[namespace exists ::vfs]} {
	set tmp [::tfileutils::tempfile $this(tmpPath) FakeSample]
	append tmp .mov
	file copy -force $origMovie $tmp
	set fakeQTSampleFile $tmp
    }
    set initedAboutQuickTimeTcl 1
}

proc ::Dialogs::AboutQuickTimeTcl { } {
    global  this
    variable initedAboutQuickTimeTcl
    variable fakeQTSampleFile
    variable wAboutQuickTimeTcl
    
    if {!$initedAboutQuickTimeTcl} {
	InitAboutQuickTimeTcl
    }
    set w $wAboutQuickTimeTcl
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -macclass {document closeBox}
    if {[string match "mac*" $this(platform)]} {
	wm transient $w
    } else {

    }
    wm title $w [mc {About QuickTimeTcl}]
    
    pack [movie $w.m -file $fakeQTSampleFile]
    set theSize [$w.m size]
    set mw [lindex $theSize 0]
    set mh [lindex $theSize 1]
    lassign [::UI::GetScreenSize] screenW screenH
    wm geometry $w +[expr ($screenW - $mw)/2]+[expr ($screenH - $mh)/2]
    update
    wm resizable $w 0 0
    $w.m play
}


namespace eval ::Dialogs:: { }

# Dialogs::Free --
# 
#       In case we want to cleanup tmp directory we must destroy window
#       before deleting the movie file!

proc ::Dialogs::Free { } {
    variable wAboutQuickTimeTcl
    
    if {[winfo exists $wAboutQuickTimeTcl]} {
	destroy $wAboutQuickTimeTcl
    }
}

#-- ::NetworkSetup:: -----------------------------------------------------------

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
	    ::UI::MessageBox -message  \
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
		::UI::MessageBox -message  \
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
		::UI::MessageBox -message  \
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
		::UI::MessageBox -message  \
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

#-------------------------------------------------------------------------------