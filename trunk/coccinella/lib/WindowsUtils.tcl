#  WindowsUtils.tcl ---
#  
#      This file is part of The Coccinella application. It implements things
#      that are windows only, like a glue to win only packages.
#      
#  Copyright (c) 2002-2007  Mats Bengtsson
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
#  See: http://msdn.microsoft.com/library/default.asp?url=/library/en-us/shellcc/platform/shell/programmersguide/shell_adv/registeringapps.asp
#  
# $Id: WindowsUtils.tcl,v 1.16 2007-09-14 08:11:47 matben Exp $

package require registry
package provide WindowsUtils 1.0

namespace eval ::Windows:: {
    
    variable ProgramFiles
    
    if {[info exists ::env(ProgramFiles)]} {
	set ProgramFiles $::env(ProgramFiles)
    } elseif {[info exists ::env(PROGRAMFILES)]} {
	set ProgramFiles $::env(PROGRAMFILES)
    }
}

proc ::Windows::OpenURI {uri} {	
    variable ProgramFiles

    # uri MUST have the form "protocol:..."
    if {![regexp {^([^:]+):.+} $uri - name]} {
	return
    }
    set key [format {HKEY_CLASSES_ROOT\%s\shell\open\command} $name] 
    if {[catch {registry get $key {}} appCmd]} {
	return
    }
    if {[info exists ProgramFiles]} {
	regsub -nocase "%programfiles%" $appCmd $ProgramFiles appCmd
    }
    regsub -all {\\} $appCmd  {\\\\} appCmd
    
    # Outlook uses a mailurl:%1 which I don't know how to interpret.
    set appCmd [string map [list {%1} $uri] $appCmd]
    
    if {[catch {
	eval exec $appCmd &
    } err]} {
	tk_messageBox -icon error -title [mc Error] -message $err
    }
}

# Slight rewrite of Chris Nelson's Wiki contribution: http://wiki.tcl.tk/557

proc ::Windows::OpenUrl {url} {
    variable ProgramFiles
    
    set ext .html

    # Get the application key for HTML files
    set appKey [registry get [format {HKEY_CLASSES_ROOT\%s} $ext] {}]
    set key [format {HKEY_CLASSES_ROOT\%s\shell\open\command} $appKey] 
	 
    # Get the command for opening HTML files
    if {[catch {registry get $key {}} appCmd]} {
	
	# Try a different key.
	set key [format {HKEY_CLASSES_ROOT\%s\shell\opennew\command} $appKey] 
	if {[catch {
	    set appCmd [registry get $key {}]
	} msg]} {
	    return -code error $msg
	}
    }
    
    # Double up the backslashes for eval (below)
    regsub -all {\\} $appCmd  {\\\\} appCmd
    if {[info exists ProgramFiles]} {
	regsub -nocase "%programfiles%" $appCmd $ProgramFiles appCmd
    }
    
    # Substitute the url name into the command for %1
    # Not always needed (opennew).
    set havePercent [string match {*"%1"*} $appCmd]
    set finCmd [string map [list {%1} $url] $appCmd]
    
    # Invoke the command. 
    # It seems that if there is a "%1" we shall use that for url else just append?
    if {[catch {
	if {$havePercent} {
	    eval exec $finCmd &
	} else {
	    # This wont work with Firefox.
	    eval exec $finCmd [list $url] &
	}
    } err]} {
	tk_messageBox -icon error -title [mc Error] -message $err
    }
}

# ::Windows::OpenFileFromSuffix --
# 
#       Uses the registry to try to find an application for a file using
#       its suffix.
#       If the path starts with "file://" we assume it is already uri encoded.

proc ::Windows::OpenFileFromSuffix {path} {
    variable ProgramFiles

    set ext [file extension $path]
    
    # Get the application key for .ext files
    set appKey [registry get HKEY_CLASSES_ROOT\\$ext {}]
    set key [format {HKEY_CLASSES_ROOT\%s\shell\open\command} $appKey] 
   
    # Get the command for opening $suff files
    if {[catch {
	set appCmd [registry get $key {}]
    } msg]} {
	return -code error $msg
    }
        
    # Double up the backslashes for eval (below)
    regsub -all {\\} $appCmd  {\\\\} appCmd
    regsub {%1} $appCmd $path appCmd
    if {[info exists ProgramFiles]} {
	regsub -nocase "%programfiles%" $appCmd $ProgramFiles appCmd
    }
    
    # URI encode if necessary. We fixed this using [list $path] instead!
    if {0 && ![regexp {^file://.*} $path]} {
	#set path "file://[uriencode::quotepath $path]"
    }
    
    # Invoke the command
    if {[catch {
	eval exec $appCmd [list $path] &
    } err]} {
	tk_messageBox -icon error -title [mc Error] -message $err
    }
}

proc ::Windows::CanOpenFileWithSuffix {path} {

    # Look for the application under HKEY_CLASSES_ROOT
    set root HKEY_CLASSES_ROOT
    set suff [file extension $path]
    
    # Get the application key for .suff files
    if {[catch {registry get $root\\$suff ""} appKey]} {
	return 0
    } 
    
    # Perhaps there can be other commands than 'open'.
    if {[catch {
	set appCmd [registry get $root\\$appKey\\shell\\open\\command ""]
    } msg]} {
	return 0
    }
    return 1
}

#--- Printer Utilities ---------------------------------------------------------
#
# Be sure that the 'printer' and 'gdi' packages are there.

namespace eval ::Windows::Printer:: {

}

proc ::Windows::Printer::PageSetup { } {
        
    set ans [printer dialog page_setup]
    return $ans
}

proc ::Windows::Printer::Print {w args} {
        
    eval {printer::print_widget $w -name "Coccinella"} $args
}

proc ::Windows::Printer::DoPrintText {w} {
    
    variable p
    
    set ans [printer dialog select]
    if {[lindex $ans 1] != 1} {
	return
    }
    set hdc [lindex $ans 0]
    
    # For the time being we use a crude method of printing text.
    set str [::Text::TransformToPureText $w]
    printer::print_page_data $str
    
    if {0} {
	printer::page_args p
	printer job start
	printer page start
    
	::Windows::Printer::PrintText $w $hdc p
	
	printer page end
	printer job end
    }
}

# Sketch...
# 
# This should print images as well...

proc ::Windows::Printer::PrintText {w hdc pName} {
    
    variable state
    variable tagConfig
    variable facx
    variable facy
    variable dcx
    variable dcy
    variable lm
    variable tm
    variable pw
    variable pl
    variable pix2dcx
    variable pix2dcy
    variable iLine 0
    upvar 1 $pName p
    
    if {[winfo class $w] ne "Text"} {
	error "::Windows::Printer::PrintText for text widgets only"
    }
    
    # Common scale factors etc.
    set facx [expr $p(resx)/1000.0]
    set facy [expr $p(resy)/1000.0]
    set lm [expr round($p(lm) * $facx)]
    set tm [expr round($p(tm) * $facy)]
    set pw [expr round(($p(pw) - $p(lm) - $p(rm)) * $facx)]
    set pl [expr round(($p(pl) - $p(tm) - $p(bm)) * $facy)]
    if {$::tcl_platform(platform) eq "windows"} {
	set ppiScreen 94
    } else {
	set ppiScreen 72
    }
    set pix2dcx [expr double($p(resx))/$ppiScreen]
    set pix2dcy [expr double($p(resy))/$ppiScreen]
    
    # Init state vars.
    set attrList {-background -borderwidth -font -foreground \
      -lmargin1 -lmargin2 -rmargin -spacing1 -spacing2 -spacing3 \
      -tabs}
    unset -nocomplain state
    foreach key $attrList {
	set state($key) {}
    }
    foreach {key a b c value} [$w configure] {
	if {[info exists state($key)]} {
	    set state($key) $value
	}
    }
    
    # Get all tag configs.
    foreach tag [$w tag names] {
	set tagConfig($tag) [$w tag configure $tag]	
    }
    
    # Get all gdi font metrics.
    set defFont [$w cget -font]
    gdi characters $hdc -font $defFont -array fm
    regsub " " $defFont "" fkey
    array set fmArr${fkey} [array get fm]
    foreach tag [array names tagConfig] {
	set ind [lsearch $tagConfig($tag) "-font"]
	if {$ind >= 0} {
	    set font [lindex $tagConfig($tag) [expr $ind+1]]
	    regsub " " $font "" fkey
	    if {![info exists fmArr${fkey}]} {
		
		variable fmArr${fkey}
		gdi characters $hdc -font $font -array fm
		array set fmArr${fkey} [array get fm]
	    }
	}
    }
    
    # Start position.
    set dcx $tm
    set dcy $tm
    
    # And finally...
    foreach {key value index} [$w dump 1.0 end] {
	::Windows::Printer::TextDumpCallback $hdc $key $value $index
    }
    
    # Cleanup
    unset -nocomplain facx facy
}

proc ::Windows::Printer::TextDumpCallback {hdc key value index} {
    
    variable state
    variable iLine
    variable dcx
    variable dcy
    variable facx
    variable facy
    variable lm
    variable tm
    variable pw
    variable pl
    variable tagConfig
    variable pix2dcx
    variable pix2dcy
    
    puts "$hdc, key=$key, value=$value, index=$index"
    
    switch -- $key {
	tagon {
	    foreach {tkey tval} $tagConfig($value) {
		set state($tkey) [linsert $state($tkey) 0 $tval]
	    }
	}
	tagoff {
	    foreach {tkey tval} $tagConfig($value) {
		set state($tkey) [lreplace $state($tkey) 0 0]
	    }
	}
	text {
	    set font [lindex $state(-font) 0]
	    regsub " " $font "" fkey
	    array set fm [array get fmArr${fkey}]
	    set fg [lindex $state(-foreground) 0]
	    set bg [lindex $state(-background) 0]
	    set len 0
	    set totlen [string length $value]
	    set dcwidth 0
	    if {$bg eq "white"} {
		set backfill {}
	    } else {
		set backfill [list -backfill $bg]
	    }
	    while {$len < $totlen} {
		set str [string range $value $len end]
		
		# Handle text paragraph by paragraph, separated by \n.
		# split \n  to list ??
		set end [string first "\n" $str]
		if {$str eq ""} {
		    set str " "
		}
		set maxlen [string length $str]
		
		for {set i 0} {($i < $maxlen) && ($dcwidth < $pw)} {incr i} {
		    incr dcwidth $fm([string index $str $i])
		}
		set endi $i
		set starti $i
		
		# Keep track of max y for each line so we know to offset next.
		set dcyMax 0
	    
		# If not the complete string used up. Break on a word.
		if {$i < $maxlen} {
		    set endi [expr [string wordstart $str $endi] - 1]
		    set starti [expr $endi + 1]
		    
		    # No word boundary found. Cut.
		    if {$endi <= 1} {
			set endi $i
			set starti $i
		    }
		}
		set res [eval {gdi text $hdc $dcx $dcy -anchor nw -justify left \
		  -text $str -font $font -fill $fg} $backfill]
		incr len [lindex $res 0]
		incr dcx $dcwidth
		if {$newline} {
		    incr dcy $dcyMax
		    set dcyMax 0
		} else {
		    set y [lindex $res 1]
		    set dcyMax [expr $y > $dcyMax ? $y : $dcyMax]
		}
		
	    }
	}
	image {
	    
	    # value is image name?
	    set dcImw [expr round( $facx * [image width $value] )]
 	    set dcImh [expr round( $facy * [image height $value] )]
	    
	    # Fix anchor later. Wrong position.
	    gdi rectangle $hdc $dcx $dcy [expr $dcx + $dcImw]  \
	      [expr $dcy - $dcImh]
	}
    }
    
}

#-------------------------------------------------------------------------------


