# notebox.tcl ---
#
#       A single instance notifier window where simple messages can be added.
#       
#  Copyright (c) 2004
#  
#  This source file is distributed under the BSD license.
#  
#  $Id: notebox.tcl,v 1.3 2007-07-19 06:28:11 matben Exp $

package provide notebox 1.0

namespace eval ::notebox:: {

    variable this
    
    option add *Notebox.millisecs                  0         widgetDefault
    option add *Notebox.anchor                     se        widgetDefault

    option add *Notebox.background                 #ffff9f   50
    option add *Notebox.foreground                 black     30
    option add *Notebox.Message.width              160       widgetDefault

    option add *Notebox.closeButtonBgWinxp         #ca2208   widgetDefault
    
    switch -- $::tcl_platform(platform) {
	unix {
	    set this(platform) $::tcl_platform(platform)
	    if {[package vcompare [info tclversion] 8.3] == 1} {	
		if {[string equal [tk windowingsystem] "aqua"]} {
		    set this(platform) "macosx"
		}
	    }
	}
	windows - macintosh {
	    set this(platform) $::tcl_platform(platform)
	}
    }
    
    switch -- $this(platform) {
	unix {
	    option add *Notebox.font {Helvetica 10} widgetDefault
	}
	windows {
	    option add *Notebox.font {Arial 8} widgetDefault
	}
	macintosh - macosx {
	    option add *Notebox.font {Geneva 9} widgetDefault
	}
    }
    set MAX_INT 0x7FFFFFFF
    set hex [format {%x} [expr {int($MAX_INT*rand())}]]
    set w .notebox$hex
    set this(w) $w
    set this(uid) 0
    set this(x) [expr [winfo screenwidth .] - 30]
    set this(y) [expr [winfo screenheight .] - 30]    
}

proc ::notebox::setposition {x y} {
    variable this
    
    set this(x) $x
    set this(y) $y
}

proc ::notebox::Build { } {
    variable this

    set w $this(w)
    toplevel $w -class Notebox -bd 0 -relief flat
    wm resizable $w 0 0 
    
    switch -- $this(platform) {
	macintosh {
	    if {[package vcompare [info tclversion] 8.3] == 1} {
		::tk::unsupported::MacWindowStyle style $w floatSideProc
	    } else {
		unsupported1 style $w floatSideProc
	    }
	    frame $w.f -height 32 -width 0
	    pack  $w.f -side left -fill y
	}
	macosx {
	    tk::unsupported::MacWindowStyle style $w floating \
	      {sideTitlebar closeBox}
	    frame $w.f -height 32 -width 0
	    pack  $w.f -side left -fill y
	}
	default {
	    wm overrideredirect $w 1
	    wm transient $w
	    frame $w.f -bd 1 -relief raised
	    pack  $w.f -side left -fill y
	    set c $w.f.c
	    set size 13
	    canvas $c -width $size -height $size -highlightthickness 0
	    DrawWinxpButton $c 5
	    pack $c -side top
	}
    }
}

proc ::notebox::DrawWinxpButton {c r} { 
    variable this

    set rm [expr {$r-1}]
    set a  [expr {int(($r-2)/1.4)}]
    set ap [expr {$a+1}]
    set width  [$c cget -width]
    set width2 [expr {$width/2}]

    set red  [option get $this(w) closeButtonBgWinxp {}]
    
    # Be sure to offset ovals to put center pixel at (1,1).
    if {[string match mac* $this(platform)]} {
	$c create oval -$rm -$rm  $r $r -tags bt -outline {} -fill $red
	set id1 [$c create line -$a -$a $a  $a -tags bt -fill white]
	set id2 [$c create line -$a  $a $a -$a -tags bt -fill white]
    } else {
	$c create oval -$rm -$rm $rm $rm -tags bt -outline $red -fill $red
	set id1 [$c create line -$a -$a $ap  $ap -tags bt -fill white]
	set id2 [$c create line -$a  $a $ap -$ap -tags bt -fill white]
    }
    $c move bt $width2 $width2
    $c bind bt <ButtonPress-1> [list destroy $this(w)]
}

proc ::notebox::addmsg {str args} {
    variable this

    if {![winfo exists $this(w)]} {
	Build
    }
    array set argsArr {
	-title ""
    }
    array set argsArr $args
    set w $this(w)
    wm title $w $argsArr(-title)
    if {[llength [winfo children $w]] > 1} {
	set wdiv $w.f[incr this(uid)]
	frame $wdiv -height 2
	pack  $wdiv -side top -fill x
    }
    set t $w.t[incr this(uid)]
    set bg   [option get $w background {}]
    set fg   [option get $w foreground {}]
    set font [option get $w font {}]
    message $t -bg $bg -fg $fg -font $font -padx 8 -pady 2 \
      -highlightthickness 0 -justify left -text $str
    pack $t -side top -anchor w
        
    after idle [list ::notebox::SetGeometry $t]
    
    if {[info exists this(afterid)]} {
	after cancel $this(afterid)
    }
    set ms [option get $w millisecs {}]
    if {$ms > 0} {
	after $ms ::notebox::Destroy
    }
}

proc ::notebox::SetGeometry {t} {
    variable this
    
    update idletasks
    set w $this(w)
    set anchor [option get $w anchor {}]
    set newx [expr {$this(x) - [winfo reqwidth $w]}]
    set newy [expr {$this(y) - [winfo reqheight $w]}]
    wm geometry $w +${newx}+${newy}
}

proc ::notebox::Destroy { } {
    variable this
    
    catch {destroy $this(w)}
}

#-------------------------------------------------------------------------------

