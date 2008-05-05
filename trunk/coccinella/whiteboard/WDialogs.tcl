#  WDialogs.tcl ---
#  
#      This file is part of The Coccinella application. It implements some
#      of the dialogs for the whiteboard. 
#      
#  Copyright (c) 2007  Mats Bengtsson
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
# $Id: WDialogs.tcl,v 1.5 2008-05-05 14:22:29 matben Exp $
   
package provide WDialogs 1.0

namespace eval ::WDialogs:: {

}

# WDialogs::InfoOnPlugins ---
#  
#      It implements the dialog for presenting the loaded packages or helper 
#      applications.

proc ::WDialogs::InfoOnPlugins {} {
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
    wm title $w [mc Plugins]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] -command [list destroy $w] \
      -default active
    pack $frbot.btok -side right
    pack $frbot -side bottom -fill x

    set fbox $wbox.f
    frame $fbox -bd 1 -relief sunken
    pack  $fbox -side top -fill both -expand 1
    
    set xtab1 80
    set xtab2 90
    set wtxt $fbox.txt
    set wysc $fbox.ysc
    ttk::scrollbar $wysc -orient vertical -command [list $wtxt yview]
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
	$wtxt insert end "\t[mc Type]:\t" tkey
	$wtxt insert end "[::Plugins::GetTypeDesc $plug]\n" ttxt
	$wtxt insert end "\t[mc Description]:\t" tkey
	$wtxt insert end "[::Plugins::GetDescForPlugin $plug]\n" ttxt
	$wtxt insert end "\t[mc Version]:\t" tkey
	$wtxt insert end "$txtver\n" ttxt
	$wtxt insert end "\t[mc Extensions]:\t" tkey
	$wtxt insert end "$txtsuf\n" ttxt
	$wtxt insert end "\n"
    }
    $wtxt configure -state disabled
    bind $w <Return> [list $frbot.btok invoke]
    
    tkwait window $w
    grab release $w
}

# WDialogs::ShowInfoServer --
#
#       It shows server information. Uses one of the connections to get a 
#       channel which is used to obtain information. If not connected, then 
#       give only the hostname if available.
#       
# Arguments:
#       
# Results:
#       none

proc ::WDialogs::ShowInfoServer { } {
    global  this wDlgs state prefs
    
    set w $wDlgs(infoServ)
    if {[winfo exists $w]} {
	return
    }
    array set boolToYesNo [list 0 [mc no] 1 [mc yes]]
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [mc Server]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    set fr $wbox.f
    ttk::frame $fr -padding [option get . groupSmallPadding {}]
    pack $fr
    
    option add *$fr.TLabel.style Small.TLabel
    
    ttk::label $fr.x1 -text "[mc Running]:"
    ttk::label $fr.x2 -text $boolToYesNo($state(isServerUp))
    ttk::label $fr.a1 -text "IP:"
    ttk::label $fr.b1 -text "[mc Host]:"
    ttk::label $fr.c1 -text "[mc Username]:"
    ttk::label $fr.d1 -text "[mc Port]:"
    ttk::label $fr.e1 -text "[mc {Buffering support}]:"
    ttk::label $fr.f1 -text "[mc {Blocking support}]:"
    ttk::label $fr.g1 -text "[mc Secured]:"

    if {!$state(isServerUp)} {
	ttk::label $fr.a2 -text $this(ipnum)
	ttk::label $fr.b2 -text $this(hostname)
	ttk::label $fr.c2 -text $this(username)
	ttk::label $fr.d2 -text [mc "not available"]
	ttk::label $fr.e2 -text [mc "not available"]
	ttk::label $fr.f2 -text [mc "not available"]
	ttk::label $fr.g2 -text [mc "not available"]
	
    } elseif {$state(isServerUp)} {
	set sockname [fconfigure $state(serverSocket) -sockname]
	ttk::label $fr.a2 -text $this(ipnum)
	ttk::label $fr.b2 -text $this(hostname)
	ttk::label $fr.c2 -text $this(username)
	ttk::label $fr.d2 -text $prefs(thisServPort)
	ttk::label $fr.e2 -text [mc "not available"]
	ttk::label $fr.f2 -text [mc "not available"]
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

# WDialogs::WelcomeCanvas --
# 
#       Is it the first time it is launched, then show the welcome canvas.

proc ::WDialogs::WelcomeCanvas { } {
    global  this
    
    set systemLocale [lindex [split $this(systemLocale) _] 0]
    set floc [file join $this(docsPath) Welcome_${systemLocale}.can]
    if {[file exists $floc]} {
	set f $floc
    } else {
	set f [file join $this(docsPath) Welcome_en.can]
    }
    ::WDialogs::Canvas $f -title [mc {Welcome}] -encoding utf-8
}

namespace eval ::WDialogs:: {
    
    # Running number to create unique toplevel paths.
    variable uidcan 0
}

# WDialogs::Canvas --
# 
#       Display a *.can file into simple canvas window.
#       A kind of minimal, readonly, whiteboard.

proc ::WDialogs::Canvas {filePath args} {
    global this prefs
    variable uidcan
    
    set w .spcan[incr uidcan]
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm withdraw $w
    
    # Make the namespace exist.
    namespace eval ::WB::${w}:: {}

    array set argsA [list -title [file rootname [file tail $filePath]]]
    array set argsA $args
    wm title $w $argsA(-title)
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
    if {[info exists argsA(-encoding)]} {
	fconfigure $fd -encoding $argsA(-encoding)
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


