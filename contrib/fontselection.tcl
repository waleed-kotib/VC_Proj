#  Copyright (c) 2002  Mats Bengtsson
#  This source file is distributed under the BSD license.
#
# $Id: fontselection.tcl,v 1.13 2005-08-14 06:56:45 matben Exp $

package provide fontselection 1.0

namespace eval ::fontselection:: {
    
    variable options
    variable prefs
    
    set options {
	-defaultfont    {Helvetica 12 normal}
	-initialfont    {Helvetica 12 normal}
    }
}

proc ::fontselection::fontselection {w args} {
    global  tcl_platform

    variable prefs
    variable finished
    variable options
    variable opts
    variable wcan
    variable wlb
    variable font
    variable size
    variable weight
    variable fontFamilies
    
    if {[winfo exists $w]} {
	raise $w
	return
    }
    toplevel $w
    
    switch -- [tk windowingsystem] {
	aqua {
	    ::tk::unsupported::MacWindowStyle style $w document closeBox
	}
    }
    
    wm title $w [::msgcat::mc {Select Font}]
    wm protocol $w WM_DELETE_WINDOW [list [namespace current]::Close $w]
    
    set finished -1
    array set opts $options
    array set opts $args
    array set defaultFontArr [font actual $opts(-defaultfont)]
    array set initialFontArr [font actual $opts(-initialfont)]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Top frame.
    set wtop $wbox.top
    ttk::frame $wtop
    pack $wtop -side top -fill x
    
    # System fonts.
    set font $initialFontArr(-family)
    
    # Cache font families since can be slow.
    if {![info exists fontFamilies]} {
	set fontFamilies [font families]
    }
    set frfont $wtop.font
    ttk::frame $frfont
    pack $frfont -side left -fill y
    
    set wlb $frfont.lb
    set ysc $frfont.ysc
    listbox $wlb -width 28 -height 10 -yscrollcommand [list $ysc set]
    scrollbar $ysc -orient vertical -command [list $wlb yview]
    set ind [lsearch $fontFamilies $initialFontArr(-family)]
    pack $wlb $ysc -side left -fill y
    eval $wlb insert 0 $fontFamilies

    # Font size, weight etc.
    set frprop $wtop.prop
    ttk::frame $frprop -padding {12 0 0 0}
    pack $frprop -side top -fill y

    set size $initialFontArr(-size)
    ttk::label $frprop.lsize -text {Font size:}
    ttk::combobox $frprop.size -width 8  \
      -textvariable [namespace current]::size  \
      -values {9 10 12 14 16 18 24 36 48 60 72}
    ttk::separator $frprop.s -orient horizontal

    grid  $frprop.lsize  -sticky w
    grid  $frprop.size   -sticky ew
    grid  $frprop.s      -sticky ew -pady 12

    bind $frprop.lsize <<ComboboxSelected>> [namespace current]::Select

    set weight $initialFontArr(-weight)
    ttk::label $frprop.lwe -text {Font weight:}
    ttk::combobox $frprop.we -width 10  \
      -textvariable [namespace current]::weight -state readonly \
      -values {normal bold italic}

    grid  $frprop.lwe  -sticky w
    grid  $frprop.we   -sticky ew

    bind $frprop.we <<ComboboxSelected>> [namespace current]::Select

    # Font text.
    set frmid $wbox.frmid
    ttk::frame $frmid
    set wcan [canvas $frmid.can -width 200 -height 48 \
      -highlightthickness 0 -border 1 -relief sunken -bg white]
    pack $frmid -side top -fill both -expand 1 -pady 16
    pack $frmid.can -fill both -expand 1
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot
    ttk::button $frbot.btset -text [::msgcat::mc Select] -default active  \
      -command [list [namespace current]::OK $w]
    ttk::button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::Cancel $w]
    ttk::button $frbot.btdef -text [::msgcat::mc Default]  \
      -command [namespace current]::SetDefault
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btset -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btset -side right -padx $padx
    }
    pack $frbot.btdef -side left
    pack $frbot -side top -fill x
    
    wm resizable $w 0 0
    if {[info exists prefs(winGeom)]} {
	regexp {^[^+-]+((\+|-).+$)} $prefs(winGeom) match pos
	wm geometry $w $pos
    }
    bind $w   <Return> {}
    bind $wlb <<ListboxSelect>> [list [namespace current]::Select $wlb font]
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
    tkwait window $w
    
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
    variable fontFamilies

    if {$opts(-defaultfont) != ""} {
	array set defaultFontArr [font actual $opts(-defaultfont)]
	set font   $defaultFontArr(-family)
	set size   $defaultFontArr(-size)
	set weight $defaultFontArr(-weight)
    }
    set ind [lsearch $fontFamilies $font]
    $wlb selection clear 0 end
    if {$ind >= 0} {
	$wlb selection set $ind
	$wlb see $ind
    } else {
	$wlb selection set 0
	$wlb see 0
    }
}

proc ::fontselection::OK {w} {
    variable finished
    
    set finished 1
    ::fontselection::Close $w
}

proc ::fontselection::Cancel {w} {
    variable finished
    
    set finished 0
    ::fontselection::Close $w
}

proc ::fontselection::Close {w} {
    variable prefs

    set prefs(winGeom) [wm geometry $w]
    destroy $w
}

#-------------------------------------------------------------------------------
