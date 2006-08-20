#  ItemInspector.tcl ---
#  
#      This file is part of The Coccinella application. It lets the user 
#      inspect and configure item options in the canvas.
#      
#  Copyright (c) 1999-2006  Mats Bengtsson
#  
# $Id: ItemInspector.tcl,v 1.14 2006-08-20 13:41:20 matben Exp $

package provide ItemInspector 1.0

namespace eval ::ItemInspector::  {
    
    option add *ItemInspector*Menu.font           CociSmallFont       widgetDefault

    option add *ItemInspector*TLabel.style        Small.TLabel        widgetDefault
    option add *ItemInspector*TLabelframe.style   Small.TLabelframe   widgetDefault
    option add *ItemInspector*TMenubutton.style   Small.TMenubutton   widgetDefault
    option add *ItemInspector*TRadiobutton.style  Small.TRadiobutton  widgetDefault
    option add *ItemInspector*TCheckbutton.style  Small.TCheckbutton  widgetDefault
    option add *ItemInspector*TEntry.style        Small.TEntry        widgetDefault
    option add *ItemInspector*TEntry.font         CociSmallFont       widgetDefault

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
	activeimage
	activeoutline
	activeoutlinestipple
	activestipple
	activewidth
	dashoffset
	disableddash
	disabledfill
	disabledimage
	disabledoutline
	disabledoutlinestipple
	disabledstipple
	disabledwidth
	offset
	outlineoffset
	state
	splinesteps
    }
    
    # For QuickTime movies.
    variable skipMovieOpts
    set skipMovieOpts(std) {
	highlightbackground
	highlightcolor
	highlightthickness
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
	highlightbackground
	highlightcolor
	highlightthickness
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
#       w           canvas widget
#       which       a valid specifier for a canvas item
#       args        ?-state normal|disabled?
#       
# Results:
#       dialog displayed.

proc ::ItemInspector::ItemInspector {wcan which args} {
        
    # We need to create an item specific instance. 
    # Use the item id for instance.
    set idlist [$wcan find withtag $which]
    if {$idlist == {}}  {
	return
    }
    set w [winfo toplevel $wcan]
    
    # Query the whiteboard's state.
    array set opts [::WB::ConfigureMain $w]
    array set opts $args
    foreach id $idlist {
	set tags [$wcan gettags $id]
	if {[lsearch $tags broken] >= 0} {
	    eval {Broken $wcan $id} [array get opts]
	} else {
	    eval {Build $wcan $id} [array get opts]
	}
    }
}

# ItemInspector::Build --
# 
#       Builds one inspector window for the specified item.
#
# Arguments:
#
#
# Results:
#       dialog window path

proc ::ItemInspector::Build {wcan itemid args} {
    global  prefs fontPoints2Size this wDlgs
    upvar ::WB::dashShort2Full dashShort2Full
    
    set w $wDlgs(iteminsp)$itemid
    
    # If window already there, just return silently.
    if {[winfo exists $w]} {
	raise $w
	return
    }
    set wtoplevel [winfo toplevel $wcan]
    
    # Keep state array for item options etc.
    set token [namespace current]::$itemid
    variable $token
    upvar 0 $token state

    set state(w)      $w
    set state(wcan)   $wcan
    set state(itemid) $itemid
    set state(finished) -1

    # The local namespace variables.
    variable boolFull2Short
    variable boolShort2Full
    variable notWantedOpts

    array set argsArr {
	-state    normal
    }
    array set argsArr $args
    set canvasState $argsArr(-state)
    
    set nl_ {\\n}
    set utag [::CanvasUtils::GetUtag $wcan $itemid]
    if {$utag == {}}  {
	return
    }
    set state(utag) $utag
    
    # Movies may not be selected this way; temporary solution?
    if {[lsearch [$wcan gettags $utag] "frame"] >= 0}  {
	#return
    }	
    ::UI::Toplevel $w -class ItemInspector  \
      -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} \
      -closecommand [list [namespace current]::CloseCmd $token]
    wm title $w [mc {Item Inspector}]
    bind $wcan <Destroy> +[list [namespace current]::Cancel $token]
    
    set typWidth 24
        
    # Global frame.
    ttk::frame $w.frall -padding [option get . dialogPadding {}]
    pack  $w.frall  -fill both -expand 1

    set w1 $w.frall.fr1
    ttk::labelframe $w1 -padding [option get . groupSmallPadding {}]  \
      -text [mc {Item Options}]
    pack $w1
    
    # Overall frame for whole container.
    set frtot $w1
    
    # List available options of the option menus.
    array set menuOpts {
	arrow             {none first last both}
	capstyle          {butt projecting round}
	joinstyle         {bevel miter round}
	dash              {none dotted dash-dotted dashed}
	smooth            {false true}
	stipple           {none gray75 gray50 gray25 gray12}
	outlinestipple    {none gray75 gray50 gray25 gray12}
	style             {pieslice chord arc}
	anchor            {n ne e se s sw w nw center}
	fontsize          {1 2 3 4 5 6}
	fontweight        {normal bold italic}
	justify           {left right center}
	fill              {transparent fill}
	outline           {transparent fill}
    }
    set menuOpts(fontfamily) $prefs(canvasFonts)
    
    foreach {key values} [array get menuOpts] {
	set exlist {}
	foreach value $values {
	    lappend exlist $value [mc $value]
	}
	set menuOptsEx($key) $exlist
    }

    set state(allopts) {}

    # Item type.
    set line 0
    set itemType [$wcan type $itemid]
    set state(type)       $itemType
    set state(type,value) $itemType
    set wlabel $frtot.l$line
    set wentry $frtot.e$line
    ttk::label $wlabel -text "[mc {Item Type}]:"
    ttk::entry $wentry -width $typWidth -textvariable $token\(type)
    $wentry state {disabled}
    grid  $wlabel  $wentry  -padx 2 -pady 2
    grid  $wlabel  -sticky e
    grid  $wentry  -sticky ew
    set state(type,w) $wentry
    
    # Coordinates.
    set theCoords [$wcan coords $itemid]
    set state(coords) $theCoords
    set state(coords,value) $theCoords
    lappend state(allopts) "coords"
    incr line
    set wlabel $frtot.l$line
    set wentry $frtot.e$line
    ttk::label $wlabel -text "[mc coordinates]:"
    ttk::entry $wentry -width $typWidth -textvariable $token\(coords)
    $wentry state {disabled}
    grid  $wlabel  $wentry  -padx 2 -pady 2
    grid  $wlabel  -sticky e
    grid  $wentry  -sticky ew
    set state(coords,w) $wentry
        
    # Get all item options. Fonts need special treatment.
    set opts [$wcan itemconfigure $itemid]
    set ind [lsearch $opts "-font*"]
    
    # We have got a font option.
    if {$ind >= 0}  {
	
	# Find the actual values set for the text.
	set fontOpts [lindex $opts $ind 4]
	set opts [lreplace $opts $ind $ind   \
	  [list {-fontfamily} {} {} {} [lindex $fontOpts 0]]  \
	  [list {-fontsize} {} {} {} $fontPoints2Size([lindex $fontOpts 1])]  \
	  [list {-fontweight} {} {} {} [lindex $fontOpts 2]]]
	
	set state(-fontfamily) [lindex $fontOpts 0]
	set state(-fontsize)   $fontPoints2Size([lindex $fontOpts 1])
	set state(-fontweight) [lindex $fontOpts 2]
    }
    
    # Get any cached info for this id. Flat list!
    foreach {key value} [::CanvasUtils::ItemCGet $wtoplevel $itemid] {
	lappend opts [list $key {} {} {} $value]
    }
    
    # Loop over all options.
    foreach opt $opts {
	incr line
	set op  [lindex $opt 0]
	set val [lindex $opt 4]
	set opname [string trimleft $op "-"]
	
	# Skip not wanted options.
	if {[lsearch $notWantedOpts $opname] >= 0} {
	    continue
	}
	set state($op,value) $val
	lappend state(allopts) $op
	
	# If multine text, encode as one line with explicit "\n".
	if {[string equal $op "-text"]}  {
	    regsub -all "\n" $val $nl_ oneliner
	    regsub -all "\r" $oneliner $nl_ oneliner
	    set val $oneliner
	}
	ttk::label $frtot.l$line -text "[mc $opname]:"
	
	# Intercept options for nontext output.
	switch -exact -- $op {
	    -fill        -
	    -outline     {		
		frame $frtot.e$line
		if {$val eq ""}  {
		    set state($op) "transparent"
		} else {
		    set state($op) "fill"
		}
		set wmb    $frtot.menu$line
		set wentry $frtot.ente$line
		set wMenu [eval {
		    ttk::optionmenuex $wmb $token\($op)
		} $menuOptsEx($opname)]
		entry $wentry -width 4 -state disabled -highlightthickness 0
		if {$val ne ""} {
		    set rgb8 {}
		    # winfo rgb . white -> 65535 65535 65535
		    foreach rgb [winfo rgb . $val] {
			lappend rgb8 [expr $rgb >> 8]
		    }
		    set val [eval {format "#%02x%02x%02x"} $rgb8]
		    $wentry configure -disabledbackground $val
		}
		pack $wmb    -in $frtot.e$line -side left
		pack $wentry -in $frtot.e$line  \
		  -side left -fill x -expand 1
		if {$canvasState eq "normal"} {
		    bind $wentry <Double-Button-1>   \
		      [list [namespace current]::ChooseItemColor $wentry]
		} else {
		    $wmb state {disabled}
		}
		set state($op,w) $wentry
		set state($op,value) $val
	    } 
	    -tags             -
	    -image            {
		set wentry $frtot.e$line
		ttk::entry $wentry -width $typWidth -textvariable $token\($op)
		$wentry state {disabled}
		set state($op) $val
		set state($op,w) $wentry
		
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
	    -fontfamily       -
	    -fontsize         -
	    -fontweight       -
	    -justify          {
		if {[string equal $op "-smooth"]}  {
		    
		    # Get full menu name.
		    if {$val eq ""}  {
			set state($op) "false"
		    } else  {
			set state($op) $boolShort2Full($val)
		    }
		} elseif {[string equal $op "-dash"]}  {
		    set state($op) $dashShort2Full($val)
		} else  {
		    if {$val eq ""}  {
			set state($op) "none"
		    } else  {
			set state($op) $val
		    }
		}
		set wmb $frtot.e$line
		set wMenu [eval {
		    ttk::optionmenuex $wmb $token\($op)
		} $menuOptsEx($opname)]
		if {$canvasState eq "disabled"} {
		    $wmb state {disabled}
		}
		set state($op,w) $wmb
	    } 
	    default  {
		
		# Just an editable text entry widget.
		set wentry $frtot.e$line
		ttk::entry $wentry -width $typWidth -textvariable $token\($op)
		if {$canvasState eq "disabled"} {
		    $wentry state {disabled}
		}
		set state($op) $val
		set state($op,w) $wentry
	    }
	}
	grid  $frtot.l$line  $frtot.e$line  -padx 2 -pady 2
	grid  $frtot.l$line  -sticky e
	grid  $frtot.e$line  -sticky ew
    }
    
    incr line
    set lockCmd [list [namespace current]::LockCmd $token]
    ttk::checkbutton $frtot.lock$line -text [mc wblockitem] \
      -variable $token\(locked) -command $lockCmd
    grid  x  $frtot.lock$line  -sticky w
    set state(locked) 0
    if {[::CanvasUtils::IsLocked $wcan $itemid]} {
	set state(locked) 1
    }
    set state(locked,value) $state(locked)
    
    # Button part.
    set saveCmd   [list [namespace current]::Configure $token]
    set cancelCmd [list [namespace current]::Cancel $token]
    set frbot $w.frall.frbot
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btsave -text [mc Save] -default active \
      -command $saveCmd
    ttk::button $frbot.btcancel -text [mc Cancel] -command $cancelCmd
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btsave -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btsave -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    if {$canvasState eq "disabled"} {
	$frbot.btsave state {disabled}
    }
    set state(wbtsave) $frbot.btsave
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btsave invoke]
    
    return $w
}

proc ::ItemInspector::LockCmd {token} {
    variable $token
    upvar 0 $token state
    
    # We have the possibility here to disable the Save button. Good or Bad?
    if {0} {
	if {$state(locked)} {
	    $state(wbtsave) state {disabled}
	} else {
	    $state(wbtsave) state {!disabled}
	}
    }
}

proc ::ItemInspector::CloseCmd {token w} {
    Cancel $token
}

proc ::ItemInspector::Cancel {token} {
    variable $token
    upvar 0 $token state

    if {[array exists state]} {
	set state(finished) 0
	Close $token
	Free $token
    }
}

# ItemInspector::Configure --
#
#       When the Save button is clicked in the item inspector dialog.
#   
# Arguments:
#
#       
# Results:
#       dialog closed, state freed

proc ::ItemInspector::Configure {token} {
    global  fontPoints2Size fontSize2Points
    
    variable $token
    upvar 0 $token state

    upvar ::WB::dashFull2Short dashFull2Short
    
    set utag $state(utag)
    set type $state(type)
    set wcan $state(wcan)
        
    # Loop through all options. Assemble a configure list.
    set allNewOpts {}
    foreach op $state(allopts) {
	set wname  $state($op,w)
	set opname [string trimleft $op "-"]
	set oldVal $state($op,value)
	set newVal $state($op)
	
	# Intercept options for nontext output.
	switch -- $op {
	    type         -
	    coords       -
	    -file        -
	    -tags        {
		
		# Do nothing
		continue
	    }
	    -fill        -
	    -outline     {		
		if {[string equal $newVal "transparent"]}  {
		    set newVal {}
		} else  {

		    # On MacOSX this can return systemWindowBody which 
		    # fails on other platforms.
		    set newVal [$wname cget -disabledbackground]
		    set rgb8 {}
		    # winfo rgb . white -> 65535 65535 65535
		    foreach rgb [winfo rgb . $newVal] {
			lappend rgb8 [expr $rgb >> 8]
		    }
		    set newVal [eval {format "#%02x%02x%02x"} $rgb8]
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
		# empty
	    }
	    -fontfamily       {
		set fontFamily $newVal
	    }
	    -fontsize         {
		set fontSize $newVal
	    }
	    -fontweight       {
		set fontWeight $newVal
	    }
	    -dash             {
		if {[string equal $newVal "none"]}  {
		    set newVal {}
		} else  {
		    set newVal $dashFull2Short($newVal)
		}
	    }
	    -stipple          -
	    -outlinestipple   {	    
		if {[string equal $newVal "none"]}  {
		    set newVal {}
		}
	    }
	    default           {
		# empty
	    }
	}
	
	# If new different from old, reconfigure. Reinterpret \n"
	if {![string equal $oldVal $newVal]}  {
	    lappend allNewOpts $op $newVal
	}
    }
    
    # We need to collect all three artificial font options to the real one.
    # Only for the text item type.
    
    if {$type eq "text"}  {
	array set newOptsArr $allNewOpts
	
	# If any font attributes changed, need to collect them all.
	if {[info exists newOptsArr(-fontfamily)] ||     \
	  [info exists newOptsArr(-fontsize)] ||         \
	  [info exists newOptsArr(-fontweight)]}  {
	    set newFontOpts   \
	      [list $fontFamily $fontSize2Points($fontSize) $fontWeight]
	    unset -nocomplain newOptsArr(-fontfamily) \
	      newOptsArr(-fontsize) \
	      newOptsArr(-fontweight)
	    set newOptsArr(-font) $newFontOpts
	    set allNewOpts [array get newOptsArr]
	}
    }
    
    # Do the actual change.
    if {$allNewOpts != {}}  {
	eval {::CanvasUtils::ItemConfigure $wcan $utag} $allNewOpts
    }
    set selected 0
    if {[::CanvasDraw::IsSelected $wcan $utag]} {
	set selected 1
    }
    if {$state(locked,value) != $state(locked)} {
	::CanvasDraw::DeselectItem $wcan $utag
	if {$state(locked)} {
	    ::CanvasUtils::AddTag $wcan $utag "locked"
	} else {
	    ::CanvasUtils::DeleteTag $wcan $utag "locked"
	}
	if {$selected} {
	    ::CanvasDraw::SelectItem $wcan $utag
	}
    }
    set state(finished) 1 
    Close $token
    Free $token
}
    
proc ::ItemInspector::ChooseItemColor {wEntry} {
    
    set col [$wEntry cget -disabledbackground]
    set col [tk_chooseColor -initialcolor $col]
    if {[string length $col] > 0}	 {
	$wEntry configure -disabledbackground $col
    }
}

proc ::ItemInspector::Close {token} {
    variable $token
    upvar 0 $token state

    destroy $state(w)
}

proc ::ItemInspector::Free {token} {
    variable $token
    upvar 0 $token state

    unset -nocomplain state
}

# ItemInspector::Movie --
#
#       As above but for QuickTime movies.
#
#

proc ::ItemInspector::Movie {wcan winfr args} {
    global  wDlgs
    
    variable skipMovieOpts
    variable boolFull2Short
    variable boolShort2Full
    variable uid

    set w $wDlgs(iteminsp)m[incr uid]
    
    # If window already there, just return silently.
    if {[winfo exists $w]} {
	raise $w
	return
    }
    set wtoplevel [winfo toplevel $wcan]
    
    # Keep state array for item options etc.
    set token [namespace current]::m$uid
    variable $token
    upvar 0 $token state

    set state(w)      $w
    set state(wcan)   $wcan
    set state(finished) -1

    array set argsArr {
	-state    normal
    }
    array set argsArr $args
    set canvasState $argsArr(-state)
    
    if {0} {
	set utag [::CanvasUtils::GetUtag $wcan $itemid]
	if {$utag == {}}  {
	    return
	}
	set state(utag) $utag
    }
    
    ::UI::Toplevel $w -class ItemInspector  \
      -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}  \
      -closecommand [list [namespace current]::CloseCmd $token]
    wm title $w {Movie Inspector}
    bind $wcan  <Destroy> +[list [namespace current]::Cancel $token]
    bind $winfr <Destroy> +[list [namespace current]::Cancel $token]
    
    set typWidth 24
    
    set wmov $winfr.m
    set ispano [$wmov ispanoramic]
    set isvisual [$wmov isvisual]
    set type "std"
    if {$ispano} {
	set type "qtvr"
    }
    set state(wmov)  $wmov
    set state(winfr) $winfr
    set state(type)  $type
    
    # Global frame.
    ttk::frame $w.frall -padding [option get . dialogPadding {}]
    pack  $w.frall  -fill both -expand 1

    set w1 $w.frall.fr1
    ttk::labelframe $w1 -padding [option get . groupSmallPadding {}]  \
      -text [mc {Movie Options}]
    pack $w1
    
    # Overall frame for whole container.
    set frtot $w1
    
    # Loop over all options.
    set i 0
    
    foreach opt [$wmov configure] {
	set op  [lindex $opt 0]
	set val [lindex $opt 4]
	set opname [string trimleft $op "-"]
	if {[lsearch $skipMovieOpts($type) $opname] >= 0} {
	    continue
	}
	if {!$isvisual && ($op eq "-height" || $op eq "-width")} {
	    continue
	}
	set state($op,isbool) 0
	lappend state(allopts) $op
	incr i
	ttk::label $frtot.l$i -text [string totitle "$opname:"]
	
	switch -- $op {
	    -controller     - 
	    -custombutton   - 
	    -loadintoram    - 
	    -loopstate      -
	    -mcedit         - 
	    -palindromeloopstate {
		set wmb $frtot.e$i
		set state($op) $val
		set wMenu [ttk::optionmenuex $wmb $token\($op)  \
		  1 [mc true] 0 [mc false]]
		if {$canvasState eq "disabled"} {
		    $wmb state disabled
		}
		set state($op,value) $state($op)
		set state($op,w) $wmb
		set state($op,isbool) 1
	    }
	    default {
		set wentry $frtot.e$i
		ttk::entry $wentry -width $typWidth -textvariable $token\($op)

		switch -- $op {
		    -file - -url {
			$wentry configure -state disabled
		    }
		}
		if {$canvasState eq "disabled"} {
		    $wentry configure -state disabled
		}
		set state($op) $val
		set state($op,value) $val
		set state($op,w) $wentry
	    }
	}
	grid  $frtot.l$i  $frtot.e$i  -padx 2 -pady 2
	grid  $frtot.l$i  -sticky e
	grid  $frtot.e$i  -sticky ew
    }
  
    # Button part.
    set saveCmd   [list [namespace current]::MovieConfigure $token]
    set cancelCmd [list [namespace current]::Cancel $token]
    set frbot $w.frall.frbot
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btsave -text [mc Save] -default active \
      -command $saveCmd
    ttk::button $frbot.btcancel -text [mc Cancel] -command $cancelCmd
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btsave -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btsave -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btsave invoke]
}

proc ::ItemInspector::MovieConfigure {token} {
    
    variable $token
    upvar 0 $token state

    variable boolFull2Short
    variable boolShort2Full
    
    set wmov $state(wmov)
    
    # Loop through all options. Assemble a configure list.
    set newOptList {}
    foreach op $state(allopts) {
	set wname  $state($op,w)
	set opname [string trimleft $op "-"]
	set oldVal $state($op,value)
	set newVal $state($op)
	set optVal $newVal
		
	# If new different from old, reconfigure.
	if {![string equal $oldVal $newVal]}  {
	    lappend newOptList $op $optVal
	}
    }
    if {$newOptList != {}} {
	
	# Remote???
	eval {$wmov configure} $newOptList
    }
    set state(finished) 1 
    Close $token
    Free $token
}

proc ::ItemInspector::Broken {wcan itemid args} {
    global  wDlgs
        
    set w $wDlgs(iteminsp)$itemid
    
    # If window already there, just return silently.
    if {[winfo exists $w]} {
	raise $w
	return
    }
    set wtoplevel [winfo toplevel $wcan]
    
    # Keep state array for item options etc.
    set token [namespace current]::$itemid
    variable $token
    upvar 0 $token state

    set state(w)      $w
    set state(wcan)   $wcan
    set state(itemid) $itemid
    set state(finished) -1

    set utag [::CanvasUtils::GetUtag $wcan $itemid]
    if {$utag == {}}  {
	return
    }
    set state(utag) $utag

    ::UI::Toplevel $w -class ItemInspector  \
      -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} \
      -closecommand [list [namespace current]::CloseCmd $token]
    wm title $w {Item Inspector}
    bind $wcan <Destroy> +[list [namespace current]::Cancel $token]
            
    # Global frame.
    ttk::frame $w.frall -padding [option get . dialogPadding {}]
    pack  $w.frall  -fill both -expand 1

    set w1 $w.frall.fr1
    ttk::labelframe $w1 -padding [option get . groupSmallPadding {}]  \
      -text [mc {Broken Image}]
    pack $w1
    
    # Overall frame for whole container.
    set fr $w1
    
    # Get any cached info for this id.
    set itemcget [::CanvasUtils::ItemCGet $wtoplevel $itemid]
    set i 0
    foreach {key value} $itemcget {
	if {$key eq "-optlist"} {
	    foreach {optkey optvalue} $value {
		set name [string totitle [string trimright $optkey :]]
		ttk::label $fr.l$i -text $name
		ttk::label $fr.v$i -text $optvalue
		grid  $fr.l$i  $fr.v$i  -pady 2
		grid  $fr.l$i  -sticky e
		grid  $fr.v$i  -sticky w
		incr i
	    }
	} else {
	    set name [string totitle [string trimleft $key -]]
	    ttk::label $fr.l$i -text $name
	    ttk::label $fr.v$i -text $value
	    grid  $fr.l$i  $fr.v$i  -pady 2
	    grid  $fr.l$i  -sticky e
	    grid  $fr.v$i  -sticky w
	    incr i
	}
    }
    
    # Button part.
    set frbot $w.frall.frbot
    ttk::frame $w.frall.frbot
    ttk::button $frbot.btok -text [mc OK] -command [list destroy $w]
    pack $frbot.btok -side right
    pack $frbot -side top -fill both -expand 1
        
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
}

#-------------------------------------------------------------------------------
