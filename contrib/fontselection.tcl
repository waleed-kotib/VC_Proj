#  Copyright (c) 2002  Mats Bengtsson
#
# $Id: fontselection.tcl,v 1.8 2004-06-07 13:43:55 matben Exp $

package require combobox

package provide fontselection 1.0

namespace eval ::fontselection:: {
    
    variable options
    
    set options {
	-defaultfont    {Helvetica 12 normal}
	-initialfont    {Helvetica 12 normal}
    }
}

proc ::fontselection::fontselection {w args} {
    global  tcl_platform

    variable finished
    variable options
    variable opts
    variable wcan
    variable wlb
    variable font
    variable size
    variable weight
    variable allFonts
    
    if {[winfo exists $w]} {
	return
    }
    toplevel $w
    if {[string equal $tcl_platform(platform) "macintosh"]} {
	::tk::unsupported::MacWindowStyle style $w documentProc
    }
    
    wm title $w [::msgcat::mc {Select Font}]
    set finished 0
    array set opts $options
    array set opts $args
    array set defaultFontArr [font actual $opts(-defaultfont)]
    array set initialFontArr [font actual $opts(-initialfont)]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Top frame.
    set frtop $w.frall.frtop
    frame $frtop
    pack $frtop -side top -fill x -padx 4 -pady 4
    
    # System fonts.
    set font $initialFontArr(-family)
    set allFonts [lsort [font families]]
    set frfont $w.frall.frtop.font
    frame $frfont
    pack $frfont -side left -fill y -padx 4 -pady 4
    set wlb $frfont.lb
    set ysc $frfont.ysc
    listbox $wlb -width 28 -height 10 -yscrollcommand [list $ysc set]
    scrollbar $ysc -orient vertical -command [list $wlb yview]
    set ind [lsearch $allFonts $initialFontArr(-family)]
    pack $wlb $ysc -side left -fill y
    eval $wlb insert 0 $allFonts

    # Font size, weight etc.
    set frprop $w.frall.frtop.prop
    frame $frprop
    pack $frprop -side top -fill y -padx 8 -pady 8

    set size $initialFontArr(-size)
    label $frprop.lsize -text {Font size:}
    ::combobox::combobox $frprop.size -width 8  \
      -textvariable [namespace current]::size  \
      -command [namespace current]::Select
    eval {$frprop.size list insert end} {9 10 12 14 16 18 24 36 48 60 72}

    grid $frprop.lsize -sticky w
    grid $frprop.size  -sticky ew

    set weight $initialFontArr(-weight)
    label $frprop.lwe -text {Font weight:}
    ::combobox::combobox $frprop.we -width 10  \
      -textvariable [namespace current]::weight -editable 0  \
      -command [namespace current]::Select
    eval {$frprop.we list insert end} {normal bold italic}

    grid $frprop.lwe -sticky w
    grid $frprop.we  -sticky ew
    
    # Font text.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    set wcan [canvas $frmid.can -width 200 -height 48 \
      -highlightthickness 0 -border 1 -relief sunken]
    pack $frmid -side top -fill both -expand 1 -padx 8 -pady 6
    pack $frmid.can -fill both -expand 1
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btset -text [::msgcat::mc Select] -default active  \
      -command "set [namespace current]::finished 1"]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command "set [namespace current]::finished 2"]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btdef -text [::msgcat::mc Default]  \
      -command [namespace current]::SetDefault]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w   <Return> {}
    bind $wlb <<ListboxSelect>> "[namespace current]::Select $wlb font"
    bind $wlb <Button-1> {+ focus %W}
    Select $wlb xxx
    if {$ind >= 0} {
	$wlb selection set $ind
	$wlb see $ind
    } else {
	$wlb selection set 0
    }
    trace variable [namespace current]::size w [namespace current]::TraceSize
    
    # Grab and focus.
    focus $wlb
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finished
    
    catch {grab release $w}
    catch {destroy $w}
    trace vdelete [namespace current]::size w [namespace current]::TraceSize
    if {$finished == 1} {
	return [list $font $size $weight]
    } else {
	return {}
    }
}

proc ::fontselection::TraceSize {varName key op} {   
    variable wlb
    
    Select $wlb size
}

proc ::fontselection::Select {w what} {
    variable wcan
    variable wlb
    variable font
    variable size
    variable weight

    if {$what == "font"} {
	set selInd [$wlb curselection]
	if {[llength $selInd]} {
	    set font [$wlb get $selInd]
	}
    }
    $wcan delete all
    $wcan create text 6 24 -anchor w -text {Hello cruel World!}  \
      -font [list $font $size $weight]
}
		
proc ::fontselection::SetDefault { } {
    variable wlb
    variable opts
    variable font
    variable size
    variable weight
    variable allFonts

    if {$opts(-defaultfont) != ""} {
	array set defaultFontArr [font actual $opts(-defaultfont)]
	set font   $defaultFontArr(-family)
	set size   $defaultFontArr(-size)
	set weight $defaultFontArr(-weight)
    }
    set ind [lsearch $allFonts $font]
    $wlb selection clear 0 end
    if {$ind >= 0} {
	$wlb selection set $ind
	$wlb see $ind
    } else {
	$wlb selection set 0
	$wlb see 0
    }
}

#-------------------------------------------------------------------------------
