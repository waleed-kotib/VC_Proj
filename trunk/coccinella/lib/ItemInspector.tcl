#  ItemInspector.tcl ---
#  
#      This file is part of the whiteboard application. It lets the user 
#      inspect and configure item options in the canvas. The options are 
#      organized into a list as:   
#      listOfAllOptions = {{-option oldValue entryWidget} {...} ...}
#      
#  Copyright (c) 1999-2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: ItemInspector.tcl,v 1.3 2003-02-06 17:23:33 matben Exp $

namespace eval ::ItemInspector::  {
    
    # Only the main procedure is exported.
    namespace export ItemInspector
    
    # Maps 0, 1 to and from false, true. Strange in tcl8.3; bezier? boolean?
    variable boolFull2Short
    variable boolShort2Full
    array set boolFull2Short {false 0 true 1}
    array set boolShort2Full {0 false 1 true bezier true}
        
    # Filter away options that we don't want to be set or displayed.
    variable notWantedOpts
    set notWantedOpts {
	activedash
	activefill
	activeoutline
	activeoutlinestipple
	activestipple
	activewidth
	disableddash
	disabledfill
	disabledoutline
	disabledoutlinestipple
	disabledstipple
	disabledwidth
	outlineoffset
	state
    }

    # On 8.3 and earlier we use '-background' for disabled entries,
    # else use '-disabledbackground'.
    variable disabledBackground
    if {[info tclversion] >= 8.4} {
	set disabledBackground -disabledbackground
    } else {
	set disabledBackground -background
    }
    
    # For QuickTime movies.
    variable skipMovieOpts
    set skipMovieOpts(std) {
	loadcommand
	mccommand
	resizable
	progressproc
	qtprogress
	qtvrqualitystatic
	qtvrqualitymotion
	swing
	swingspeed
    }
    set skipMovieOpts(qtvr) {
	loadcommand
	mccommand
	resizable
	progressproc
	qtprogress
	swing
	swingspeed
    }
    
    variable uid 0
}

# ItemInspector::ItemInspector --
#
#       Shows options dialog for the selected canvas item.
#   
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       which       a valid specifier for a canvas item
#       args        ?-state normal|disabled?
#       
# Results:
#       dialog displayed.

proc ::ItemInspector::ItemInspector {wtop which args} {
    
    upvar ::${wtop}::wapp wapp

    Debug 2 "ItemInspector:: wtop=$wtop, which=$which"
    set wCan $wapp(can)
    
    # We need to create an item specific instance. 
    # Use the item id for instance.
    set itemIdList [$wCan find withtag $which]
    if {$itemIdList == ""}  {
	return
    }
    
    # Query the whiteboard's state.
    array set opts [::UI::ConfigureMain $wtop]
    array set opts $args
    foreach itemId $itemIdList {
	eval {::ItemInspector::Build $wtop $itemId} [array get opts]
    }
}

# ItemInspector::Build --
# 
#       Builds one inspector window for the specified item.

proc ::ItemInspector::Build {wtop itemId args} {
    global  sysFont prefs fontSize2Points fontPoints2Size  \
      dashShort2Full this
    
    upvar ::${wtop}::wapp wapp

    Debug 2 "::ItemInspector::Build wtop=$wtop, itemId=$itemId"
    set w .itinsp${itemId}
    set wCan $wapp(can)
    
    # If window already there, just return silently.
    if {[winfo exists $w]}  {
	return
    }

    # The local namespace variables.
    variable boolFull2Short
    variable boolShort2Full
    variable notWantedOpts
    variable disabledBackground

    # Need to have instance specific namespace for regional variables.
    namespace eval ::ItemInspector::$w  {
	variable menuBtVar
	variable finished
    }
    array set argsArr {
	-state    normal
    }
    array set argsArr $args
    
    # Refer to them by simpler variable names.
    upvar ::ItemInspector::${w}::menuBtVar menuBtVar
    upvar ::ItemInspector::${w}::finished finished

    set nl_ {\\n}
    set finished -1
    set itPrefNo [::CanvasUtils::GetUtag $wCan $itemId]
    if {[llength $itPrefNo] == 0}  {
	return
    }
    
    # Movies may not be selected this way; temporary solution?
    if {[lsearch [$wCan gettags $itPrefNo] "movie"] >= 0}  {
	#return
    }	
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	#
    }
    wm title $w {Item Inspector}
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    set w1 $w.frall.fr1
    set wcont1 [LabeledFrame2 $w1 {Item Options}]
    
    # Overall frame for whole container.
    set frtot [frame $wcont1.frin]
    pack $frtot -padx 10 -pady 10
    
    # List available options of the option menus.
    array set theMenuOpts [list    \
      arrow {none first last both}  \
      capstyle {butt projecting round}   \
      joinstyle {bevel miter round}  \
      dash {none dotted dash-dotted dashed}   \
      smooth {false true}    \
      stipple {none gray75 gray50 gray25 gray12}  \
      outlinestipple {none gray75 gray50 gray25 gray12}   \
      style {pieslice chord arc}   \
      anchor {n ne e se s sw w nw center}   \
      {fontfamily} $prefs(canvasFonts)    \
      {fontsize} {1 2 3 4 5 6}   \
      {fontweight} {normal bold italic}  \
      justify {left right center}]
    set listOfAllOptions {}
    
    # Item type.
    set iLine 0
    set itemType [$wCan type $itemId]
    label $frtot.lbl$iLine -text "item type:" -font $sysFont(sb)
    entry $frtot.ent$iLine -width 30
    $frtot.ent$iLine insert end $itemType
    $frtot.ent$iLine configure -state disabled -bg $prefs(bgColGeneral)
    grid $frtot.lbl$iLine -column 0 -row $iLine -sticky e -padx 2 -pady 1
    grid $frtot.ent$iLine -column 1 -row $iLine -sticky w -padx 2 -pady 1
    lappend listOfAllOptions [list type $itemType $frtot.ent$iLine]
    
    # Coordinates.
    incr iLine
    label $frtot.lbl$iLine -text {coordinates:} -font $sysFont(sb)
    entry $frtot.ent$iLine -width 30
    set theCoords [$wCan coords $itemId]
    $frtot.ent$iLine insert end $theCoords
    $frtot.ent$iLine configure -state disabled -bg $prefs(bgColGeneral)
    grid $frtot.lbl$iLine -column 0 -row $iLine -sticky e -padx 2 -pady 1
    grid $frtot.ent$iLine -column 1 -row $iLine -sticky w -padx 2 -pady 1
    lappend listOfAllOptions [list coords $theCoords $frtot.ent$iLine]
    
    # Get all item options. Fonts need special treatment.
    set opts [$wCan itemconfigure $itemId]
    set ind [lsearch $opts "-font*"]
    
    # We have got a font option.
    if {$ind >= 0}  {
	
	# Find the actual values set for the text.
	set fontOpts [lindex [lindex $opts $ind] 4]
	set opts [lreplace $opts $ind $ind   \
	  [list {-fontfamily} {} {} {} [lindex $fontOpts 0]]  \
	  [list {-fontsize} {} {} {} $fontPoints2Size([lindex $fontOpts 1])]  \
	  [list {-fontweight} {} {} {} [lindex $fontOpts 2]]]
    }
    
    # Loop over all options.
    foreach opt $opts {
	incr iLine
	set op [lindex $opt 0]
	set val [lindex $opt 4]
	
	# Skip not wanted options.
	set noMinOp [string trimleft $op "-"]
	if {[lsearch $notWantedOpts $noMinOp] >= 0} {
	    continue
	}
	
	# If multine text, encode as one line with explicit "\n".
	if {[string equal $op "-text"]}  {
	    regsub -all "\n" $val $nl_ oneliner
	    regsub -all "\r" $oneliner $nl_ oneliner
	    set val $oneliner
	}
	set opname [string trim $op -]
	label $frtot.lbl$iLine -text "$opname:" -font $sysFont(sb)
	
	# Intercept options for nontext output.
	switch -exact -- $op {
	    -fill        -
	    -outline     {
		
		frame $frtot.ent$iLine
		if {[string length $val] == 0}  {
		    set menuBtVar($opname) transparent
		} else {
		    set menuBtVar($opname) fill
		}
		set wMenu [tk_optionMenu $frtot.menu$iLine   \
		  ::ItemInspector::${w}::menuBtVar($opname) transparent fill]
		$wMenu configure -font $sysFont(sb)
		$frtot.menu$iLine configure -font $sysFont(sb)  \
		  -highlightthickness 0  \
		  -background $prefs(bgColGeneral) -foreground black
		entry $frtot.entent$iLine -width 4 -state disabled
		if {[string length $val] > 0} {
		    $frtot.entent$iLine configure $disabledBackground $val
		}
		pack $frtot.menu$iLine -in $frtot.ent$iLine -side left
		pack $frtot.entent$iLine -in $frtot.ent$iLine  \
		  -side left -fill x -expand 1
		if {$argsArr(-state) == "normal"} {
		    bind $frtot.entent$iLine <Double-Button-1>   \
		      [list [namespace current]::ChooseItemColor $frtot.entent$iLine]
		} else {
			$frtot.menu$iLine configure -state disabled
		}
	    } 
	    -tags       {
		
		entry $frtot.ent$iLine -width 30 
		$frtot.ent$iLine insert end $val
		$frtot.ent$iLine configure -state disabled   \
		  -bg $prefs(bgColGeneral)
		
		# Pure menu options.
	    } 
	    -arrow            -
	    -capstyle         -
	    -dash             -
	    -joinstyle        -
	    -smooth           -
	    -stipple          -
	    -outlinestipple   -
	    -style            -
	    -anchor           -
	    "-fontfamily"     -
	    "-fontsize"       -
	    "-fontweight"     -
	    -justify          {
		if {[string equal $op "-smooth"]}  {
		    
		    # Get full menu name.
		    if {[string length $val] == 0}  {
			set menuBtVar($opname) "false"
		    } else  {
			set menuBtVar($opname) $boolShort2Full($val)
		    }
		} elseif {[string equal $op "-dash"]}  {
		    set menuBtVar($opname) $dashShort2Full($val)
		} else  {
		    if {[string length $val] == 0}  {
			set menuBtVar($opname) "none"
		    } else  {
			set menuBtVar($opname) $val
		    }
		}
		set wMenu [eval {tk_optionMenu $frtot.ent$iLine   \
		  ::ItemInspector::${w}::menuBtVar($opname)}  \
		  $theMenuOpts($opname)]
		$wMenu configure -font $sysFont(sb) 
		if {$argsArr(-state) == "disabled"} {
		    $frtot.ent$iLine configure -state disabled
		}
		$frtot.ent$iLine configure -font $sysFont(sb) -highlightthickness 0  \
		  -background $prefs(bgColGeneral) -foreground black
	    } 
	    default  {
		
		# Just an editable text entry widget.
		entry $frtot.ent$iLine -width 30 
		$frtot.ent$iLine insert end $val
		if {$argsArr(-state) == "disabled"} {
		    $frtot.ent$iLine configure -state disabled
		}
	    }
	}
	grid $frtot.lbl$iLine -column 0 -row $iLine -sticky e -padx 2 -pady 0
	if {[string equal $op "-fill"] || [string equal $op "-outline"]} {
	    grid $frtot.ent$iLine -column 1 -row $iLine -sticky ew   \
	      -padx 2 -pady 1
	} else  {
	    grid $frtot.ent$iLine -column 1 -row $iLine -sticky w   \
	      -padx 2 -pady 1
	}
	if {[string equal $op "-fill"] || [string equal $op "-outline"]} {
	    lappend listOfAllOptions [list $op $val $frtot.entent$iLine]
	} else  {
	    lappend listOfAllOptions [list $op $val $frtot.ent$iLine]
	}
    }
    pack $w1 -fill x
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btsave -text [::msgcat::mc Save] -width 8 -default active  \
      -command [list [namespace current]::CanvasConfigureItem $w $wCan  \
      $itemId $listOfAllOptions]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command "[namespace current]::Cancel $w"]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -in $w.frall  \
      -padx 8 -pady 6
    
    if {$argsArr(-state) == "disabled"} {
	$frbot.btsave configure -state disabled
    }
    
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btsave invoke"
}

proc ::ItemInspector::Cancel {w} {
    
    set ::ItemInspector::${w}::finished 0
    destroy $w
}

# ItemInspector::CanvasConfigureItem --
#
#       When the Save button is clicked in the item inspector dialog.
#   
# Arguments:
#       w
#       wCan        the canvas widget.
#       itemId
#       listOfAllOptions
#       
# Results:
#       dialog displayed.

proc ::ItemInspector::CanvasConfigureItem {w wCan itemId listOfAllOptions} {
    global  allIPnumsToSend fontPoints2Size fontSize2Points   \
      dashFull2Short
    
    variable disabledBackground
    upvar ::ItemInspector::${w}::menuBtVar menuBtVar
    upvar ::ItemInspector::${w}::finished finished
    
    set itPrefNo [::CanvasUtils::GetUtag $wCan $itemId]
    
    # Loop through all options. Assemble a configure list.
    set allNewOpts {}
    foreach opt $listOfAllOptions {
	set op [lindex $opt 0]
	set val [lindex $opt 1]
	set entWid [lindex $opt 2]
	set opname [string trim $op -]

	# Intercept options for nontext output.
	switch -- $op {
	    type         -
	    coords       {
		
		# Do nothing
		continue
	    }
	    -fill        -
	    -outline     {
		
		set newOpt $menuBtVar($opname)
		if {[string equal $newOpt "transparent"]}  {
		    set newVal {}
		} else  {
		    set newVal [$entWid cget $disabledBackground]
		}
		
		# Pure menu options.
	    } 
	    -arrow            -
	    -capstyle         -
	    -joinstyle        -
	    -smooth           -
	    -style            -
	    -anchor           -
	    -justify          {
	    
		set newVal $menuBtVar($opname)
	    }
	    "-fontfamily"     {
	    
		set newVal $menuBtVar($opname)
		set fontFamily $newVal
	    }
	    "-fontsize"       {
	    
		set newVal $menuBtVar($opname)
		set fontSize $newVal
	    }
	    "-fontweight"     {
	    
		set newVal $menuBtVar($opname)
		set fontWeight $newVal
	    }
	    -dash             {
		set newOpt $menuBtVar($opname)
		if {[string equal $newOpt "none"]}  {
		    set newVal {}
		} else  {
		    set newVal $dashFull2Short($menuBtVar($opname))
		}
	    }
	    "-stipple"    -
	    -outlinestipple   {
	    
		set newOpt $menuBtVar($opname)
		if {[string equal $newOpt "none"]}  {
		    set newVal {}
		} else  {
		    set newVal $menuBtVar($opname)
		}
	    }
	    default           {
		set newVal [$entWid get]
	    }
	}
	
	# If new different from old, reconfigure. Reinterpret \n"
	if {![string equal $val $newVal]}  {
	    lappend allNewOpts $op $newVal
	}
    }
    
    # We need to collect all three artificial font options to the real one.
    # Only for the text item type.
    
    if {[string equal [$wCan type $itemId] "text"]}  {
	array set newOptsArr $allNewOpts
	
	# If any font attributes changed, need to collect them all.
	if {[info exists newOptsArr(-fontfamily)] ||     \
	  [info exists newOptsArr(-fontsize)] ||         \
	  [info exists newOptsArr(-fontweight)]}  {
	    set newFontOpts   \
	      [list $fontFamily $fontSize2Points($fontSize) $fontWeight]
	    catch {unset newOptsArr(-fontfamily)}
	    catch {unset newOptsArr(-fontsize)}
	    catch {unset newOptsArr(-fontweight)}
	    set newOptsArr(-font) $newFontOpts
	    #puts "newFontOpts=$newFontOpts"
	    set allNewOpts [array get newOptsArr]
	}
    }
    #puts "2: allNewOpts=$allNewOpts"
    
    # Do the actual change.
    if {[llength $allNewOpts] > 0}  {
	eval ::CanvasUtils::ItemConfigure $wCan $itPrefNo $allNewOpts
    }
    set ::ItemInspector::${w}::finished 1 
    destroy $w
}
    
proc ::ItemInspector::ChooseItemColor {wEntry} {
    variable disabledBackground
    
    set col [$wEntry cget $disabledBackground]
    set col [tk_chooseColor -initialcolor $col]
    if {[string length $col] > 0}	 {
	$wEntry configure $disabledBackground $col
    }
}

# ItemInspector::Movie --
#
#       As above but for QuickTime movies.
#
#

proc ::ItemInspector::Movie {wtop winfr} {
    global  sysFont prefs this
    
    variable uid
    variable skipMovieOpts
    variable boolFull2Short
    variable boolShort2Full
    upvar ::${wtop}::wapp wapp

    incr uid
    set w ".itinsp${uid}"
    set wCan $wapp(can)
    
    # Need to have instance specific namespace for regional variables.
    namespace eval ::ItemInspector::$w  {
	variable menuBtVar
	variable optList
	variable finished
    }
    
    # Refer to them by simpler variable names.
    upvar ::ItemInspector::${w}::menuBtVar menuBtVar
    upvar ::ItemInspector::${w}::optList optList
    upvar ::ItemInspector::${w}::finished finished
        
    # If window already there, just return.
    if {[winfo exists $w]}  {
	error "window name $w already exists!"
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	#
    }
    wm title $w {Movie Inspector}
    set wmov ${winfr}.m
    set ispano [$wmov ispanoramic]
    set isvisual [$wmov isvisual]
    set type "std"
    if {$ispano} {
	set type "qtvr"
    }
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    set w1 $w.frall.fr1
    set wcont1 [LabeledFrame2 $w1 {Movie Options}]
    
    # Overall frame for whole container.
    set frtot [frame $wcont1.frin]
    pack $frtot -padx 10 -pady 10
    
    # Loop over all options.
    set i 0
    set optList {}
    foreach opts [$wmov configure] {
	foreach {op x y def val} $opts {
	    set opname [string trim $op -]
	    if {[lsearch $skipMovieOpts($type) $opname] >= 0} {
		continue
	    }
	    if {!$isvisual && ($op == "-height" || $op == "-width")} {
		continue
	    }
	    incr i
	    label $frtot.l$i -text "$opname:" -font $sysFont(sb)
	    switch -- $op {
		-controller - -custombutton - -loadintoram - -loopstate -
		-mcedit - -palindromeloopstate {
		    
		    set menuBtVar($op) $boolShort2Full($val)
		    set wMenu [eval {tk_optionMenu $frtot.e$i  \
		      ::ItemInspector::${w}::menuBtVar($op)} true false]
		    $wMenu configure -font $sysFont(sb) 
		    $frtot.e$i configure -font $sysFont(sb)  \
		      -highlightthickness 0  \
		      -background $prefs(bgColGeneral) -foreground black		    
		}
		default {
		    set ::ItemInspector::${w}::tvar($op) $val
		    entry $frtot.e$i -width 26  \
		      -textvariable ::ItemInspector::${w}::tvar($op)
		}
	    }
	    lappend optList [list $op $val]
	    grid $frtot.l$i -column 0 -row $i -sticky e -padx 2 -pady 0
	    grid $frtot.e$i -column 1 -row $i -sticky w -padx 2 -pady 1
	}
    }
    pack $w1 -fill x
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btsave -text [::msgcat::mc Save] -width 8 -default active  \
      -command [list [namespace current]::MovieConfigure $w $wmov]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command "[namespace current]::MovieCancel $w"]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -in $w.frall  \
      -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btsave invoke"
}

proc ::ItemInspector::MovieConfigure {w wmov} {
    
    variable boolFull2Short
    variable boolShort2Full
    upvar ::ItemInspector::${w}::menuBtVar menuBtVar
    upvar ::ItemInspector::${w}::optList optList
    upvar ::ItemInspector::${w}::finished finished
    upvar ::ItemInspector::${w}::tvar tvar
    
    # Loop through all options. Assemble a configure list.
    set newOptList {}
    foreach opt $optList {
	set op [lindex $opt 0]
	set val [lindex $opt 1]
	if {[info exists tvar($op)]} {
	    set newVal $tvar($op)
	} elseif {[info exists menuBtVar($op)]} {
	    set newVal $boolFull2Short($menuBtVar($op))
	}
	
	# If new different from old, reconfigure.
	if {![string equal $val $newVal]}  {
	    lappend newOptList $op $newVal
	}
    }
    if {[llength $newOptList]} {
	eval {$wmov configure} $newOptList
    }
    destroy $w
}

proc ::ItemInspector::MovieCancel {w} {
    
    set ::ItemInspector::${w}::finished 0
    destroy $w
}

#-------------------------------------------------------------------------------
