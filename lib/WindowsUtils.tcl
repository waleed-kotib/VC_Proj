#  WindowsUtils.tcl ---
#  
#      This file is part of the whiteboard application. It implements things
#      that are windows only, like a glue to win only packages.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: WindowsUtils.tcl,v 1.2 2003-09-21 13:02:12 matben Exp $

#package require gdi
#package require printer
package require registry

namespace eval ::Windows:: {

}

# Slight rewrite of Chris Nelson's Wiki contribution.

proc ::Windows::OpenUrl {url} {

    # Look for the application under HKEY_CLASSES_ROOT
    set root HKEY_CLASSES_ROOT
    
    # Get the application key for HTML files
    set appKey [registry get $root\\.html ""]
    
    # Get the command for opening HTML files
    if {[catch {registry get \
      $root\\$appKey\\shell\\opennew\\command ""} appCmd]} {
	
	# Try a different key.
	set appCmd [registry get \
	  $root\\$appKey\\shell\\open\\command ""]
    }
    
    # Substitute the url name into the command for %1
    # Perhaps need to protect special chars???
    #regsub {%1} $appCmd $url appCmd
    
    # Double up the backslashes for eval (below)
    regsub -all {\\} $appCmd  {\\\\} appCmd
    
    # Invoke the command
    eval exec $appCmd $url &
}

# ::Windows::OpenFileFromSuffix --
# 
#       Uses the registry to try to find an application for a file using
#       its suffix.

proc ::Windows::OpenFileFromSuffix {path} {

    # Look for the application under HKEY_CLASSES_ROOT
    set root HKEY_CLASSES_ROOT
    set suff [file extension $path]
    
    # Get the application key for .suff files
    set appKey [registry get $root\\$suff ""]
    
    # Get the command for opening $suff files
    if {[catch {registry get \
      $root\\$appKey\\shell\\opennew\\command ""} appCmd]} {
	
	# Try a different key.
	set appCmd [registry get \
	  $root\\$appKey\\shell\\open\\command ""]
    }
        
    # Double up the backslashes for eval (below)
    regsub -all {\\} $appCmd  {\\\\} appCmd
    
    # Invoke the command
    eval exec $appCmd $path &
}
  
proc ::Windows::CanOpenFileWithSuffix {path} {

    # Look for the application under HKEY_CLASSES_ROOT
    set root HKEY_CLASSES_ROOT
    set suff [file extension $path]
    
    # Get the application key for .suff files
    if {[catch {registry get $root\\$suff ""} appKey]} {
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

# Sketch...

proc ::Windows::Printer::DoPrintText {w} {
    
    variable p
    
    set hdc [printer dialog select]
    
    printer::page_attr p
    printer job start
    printer page start
    
    ::Windows::Printer::PrintText $w $hdc p
    
    printer page end
    printer job end
}

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
    
    if {![winfo class $w] == "Text"} {
	error "::Windows::Printer::PrintText for text widgets only"
    }
    
    # Common scale factors etc.
    set facx [expr $p(resx)/1000.0]
    set facy [expr $p(resy)/1000.0]
    set lm [expr round($p(lm) * $facx)]
    set tm [expr round($p(tm) * $facy)]
    set pw [expr round(($p(pw) - $p(lm) - $p(rm)) * $facx)]
    set pl [expr round(($p(pl) - $p(tm) - $p(bm)) * $facy)]
    if {$::tcl_platform(platform) == "windows"} {
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
    catch {unset state}
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
    set dcx $rm
    set dcy $tm
    
    # And finally...
    $w dump 1.0 end -command  \
      [list ::Windows::Printer::TextDumpCallback $hdc]
    
    # Cleanup
    catch {unset facx}
    catch {unset facy}
}

proc ::Windows::Printer::TextDumpCallback {hdc key value index} {
    
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
	    if {$bg == "white"} {
		set backfill {}
	    } else {
		set backfill [list -backfill $bg]
	    }
	    while {$len < $totlen} {
		set str [string range $value $len end]
		
		# Handle text paragraph by paragraph, separated by \n.
		# split \n  to list ??
		set end [string first "\n" $str]
		if {$str == ""} {
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


