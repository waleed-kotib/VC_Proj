# dialog.tcl --
# 
#       Flexible dialog box.
#       Some code from ttk::dialog.
#
# Copyright (c) 2005-2007 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: dialog.tcl,v 1.31 2007-08-09 14:14:16 matben Exp $

# Public commands:
# 
#   ui::dialog ?w? ?args?
#   ui::dialog::modal ?args?
#   ui::dialog::setimage name image
#   ui::dialog::setbadge image

package require snit 1.0
package require tile
package require msgcat
package require ui::util

package provide ui::dialog 0.1

namespace eval ui::dialog {

    variable dialogTypes	;# map -type => list of dialog options
    variable buttonOptions	;# map button name => list of button options

    variable images
    set images(names) [list]
    
    variable buttonModal ""
    
    # Padding strategy: message {0} but detail and client handles their top
    # padding themselves.
    option add *Dialog.f.t.message.wrapLength      300            widgetDefault
    option add *Dialog.f.t.detail.wrapLength       300            widgetDefault
    option add *Dialog.f.t.message.font            DlgDefaultFont widgetDefault
    option add *Dialog.f.t.detail.font             DlgSmallFont   widgetDefault    
    option add *Dialog.f.b.padding                 { 0 12  0  0}  widgetDefault

    switch -- [tk windowingsystem] {
	aqua {
	    option add *Dialog.f.padding           {20 15 20 16}  widgetDefault
	    option add *Dialog.f.t.message.padding { 0  0  0  0}  widgetDefault
	    option add *Dialog.f.t.detail.padding  { 0 12  0  0}  widgetDefault
	    option add *Dialog.f.t.icon.padding    { 0  0 16  0}  widgetDefault
	    option add *Dialog.f.t.client.padding  { 0 12  0  0}  widgetDefault
	    option add *Dialog.buttonAnchor        e              widgetDefault
	    option add *Dialog.buttonOrder         "cancelok"     widgetDefault
	    option add *Dialog.buttonPadX          8              widgetDefault
	}
	win32 {
	    option add *Dialog.f.padding           {12  6}        widgetDefault
	    option add *Dialog.f.t.message.padding { 0  0  0  0}  widgetDefault
	    option add *Dialog.f.t.detail.padding  { 0  8  0  0}  widgetDefault
	    option add *Dialog.f.t.icon.padding    { 0  0  8  0}  widgetDefault
	    option add *Dialog.f.t.client.padding  { 0 12  0  0}  widgetDefault
	    option add *Dialog.buttonAnchor        center         widgetDefault
	    option add *Dialog.buttonOrder         "okcancel"     widgetDefault
	    option add *Dialog.buttonPadX          4              widgetDefault
	}
	x11 {
	    option add *Dialog.f.padding           {12  6}        widgetDefault
	    option add *Dialog.f.t.message.padding { 0  0  0  0}  widgetDefault
	    option add *Dialog.f.t.detail.padding  { 0  8  0  0}  widgetDefault
	    option add *Dialog.f.t.icon.padding    { 0  0  8  0}  widgetDefault
	    option add *Dialog.f.t.client.padding  { 0 12  0  0}  widgetDefault
	    option add *Dialog.buttonAnchor        e              widgetDefault
	    option add *Dialog.buttonOrder         "okcancel"     widgetDefault
	    option add *Dialog.buttonPadX          4              widgetDefault
	}
    }    
}

# TODO:
#   o use typemethod instead for these! See defaultmenu.
#   
# These two must be able to call before any dialog instance created.
# We always take copies to be on the safe side.

proc ui::dialog::setimage {name image} {
    variable images

    # Garbage collection.
    if {[info exists images($name)]} {
	image delete $images($name)
    }
    set new [image create photo]
    $new blank
    $new copy $image
    set images($name) $new
    lappend images(names) $name
    set images(names) [lsort -unique $images(names)]
    
    # Badge?
    CreateBadgeImage $name
}

proc ui::dialog::setbadge {badge} {
    variable images

    # Garbage collection.
    if {[info exists images(badge)]} {
	image delete $images(badge)
    }
    set new [image create photo]
    $new blank
    set W [image width $badge]
    set H [image height $badge]
    if {$W > 32 || $H > 32} {
	
	# Find common scale factor so that smaller than 32x32.
	set fW [expr {1 + ($W - 1)/32}]
	set fH [expr {1 + ($H - 1)/32}]
	set factor [expr {$fW > $fH ? $fW : $fH}]	
	$new copy $badge -subsample $factor
    } else {
	$new copy $badge
    }
    set images(badge) $new
    
    # Badge all icons.
    foreach name $images(names) {
	CreateBadgeImage $name
    }
}

proc ui::dialog::CreateBadgeImage {name} {
    variable images
    if {[info exists images(badge)]} {
	if {[info exists images($name,badge)]} {
	    image delete $images($name,badge)
	}
	set new [image create photo]
	$new blank
	$new copy $images($name)
	BadgeImage $new
	set images($name,badge) $new
    }
}

proc ui::dialog::BadgeImage {image} {
    variable images
    set badge $images(badge)
    set x [expr {[image width $image]  - [image width $badge]}]
    set y [expr {[image height $image] - [image height $badge]}]
    $image copy $badge -to $x $y
}

proc ui::dialog::Nop {args} { }

# ui::dialog --
# 
#       Implements a simple dialog like tk_messageBox but much more flexible.
#             
# Arguments:
#       args:
#         -badge        0 | 1
#         -buttons      list of button names {ok cancel yes no retry abort ignore}
#         -cancel       cancel button name
#         -command      tclProc {w buttonName}
#         -default      "" | buttonName
#         -detail       text
#         -geovariable  varName
#         -icon         "" | info | question | error | warning
#         -menu
#         -message      text
#         -modal        0 | 1
#         -parent       widgetPath
#         -timeout      millisecs
#         -title        text
#         -type         ok | okcancel | retrycancel |yesno |yesnocancel | 
#                       abortretryignore
#         -variable     varName
#                       
# Results:
#       widgetPath

proc ui::dialog {args} {
 
    if {![llength $args] || [string match "-*" [lindex $args 0]]} {
	set w [autoname]
    } else {
	set w [lindex $args 0]
	set args [lrange $args 1 end]
    }
    return [eval {ui::dialog::widget $w} $args]
}

snit::widget ui::dialog::widget {
    hulltype toplevel
    widgetclass Dialog
    
    typevariable dialogTypes      ;# map -type => list of dialog options
    typevariable buttonOptions	  ;# map button name => list of button options
    typevariable wmalpha          0
    typevariable defaultmenu      {}
    typevariable positionType     {}
    typevariable screenmargin     {}
    typevariable typicalDlgSize   {}
    typevariable centerPos        {}
    typevariable dialogStack      {}
    
    variable client
    variable timeoutID
    variable fadeoutID
    variable isDone 0
    variable stackIdx
    
    delegate option -detail  to detail  as -text
    delegate option -menu    to hull
    delegate option -message to message as -text

    option -command                   \
      -default ui::dialog::Nop
    option -geovariable
    option -type                      \
      -validatemethod ValidateType    \
      -default ok
    option -title                     \
      -configuremethod OnConfigTitle
    option -buttons     {ok}
    option -default     {}
    option -cancel      {}
    option -icon                      \
      -default info                   \
      -validatemethod ValidateIcon
    option -badge       1
    option -modal       0
    option -parent      .
    option -timeout     {}
    option -variable    {}
    
    typeconstructor {

	# Built-in button types:
	#
	StockButton ok 	   -text [::msgcat::mc OK]
	StockButton cancel -text [::msgcat::mc Cancel]
	StockButton yes	   -text [::msgcat::mc Yes]
	StockButton no	   -text [::msgcat::mc No]
	StockButton retry  -text [::msgcat::mc Retry]
	StockButton abort  -text [::msgcat::mc Abort]
	StockButton ignore -text [::msgcat::mc Ignore]

	# Built-in dialog types:
	#
	StockDialog ok \
	  -icon info -buttons {ok} -default ok
	StockDialog okcancel \
	  -icon info -buttons {ok cancel} -default ok -cancel cancel
	StockDialog retrycancel \
	  -icon question -buttons {retry cancel} -cancel cancel
	StockDialog yesno \
	  -icon question -buttons {yes no}
	StockDialog yesnocancel \
	  -icon question -buttons {yes no cancel} -cancel cancel
	StockDialog abortretryignore  \
	  -icon question -buttons {abort retry ignore} -cancel cancel
	
	array set wmArr [wm attributes .]
	if {[info exists wmArr(-alpha)]} {
	    set wmalpha 1
	} else {
	    set wmalpha 0
	}
    }
    
    typemethod defaultmenu {menu} {
	if {[llength $menu]} {
	    set defaultmenu $menu
	}
	return $defaultmenu
    }
    
    typemethod button {name args} {
	eval {StockButton $name} $args
    }

    typemethod type {name args} {
	eval {StockDialog $name} $args
    }
    
    typemethod positiontype {args} {
	if {[llength $args] == 0} {
	    return $positionType
	}
	if {[llength $args] > 1} {
	    return -code error "Usage: \"ui::dialog positiontype ?stack?\""
	}	
	
	# Important, else we get an infinite loop!
	GetInitialPosition
	set positionType $args
    }
    
    constructor {args} {
	upvar ::ui::dialog::images images
	
	set f $win.f
	set top $f.t
	install f using ttk::frame $win.f -class Dialog
	ttk::frame $top
	install message using ttk::label $top.message -anchor w -justify left
	install detail  using ttk::label $top.detail  -anchor w -justify left
	
	# Trick to let individual options override -type ones.
	set dlgtype [from args -type ok]
	if {[info exists dialogTypes($dlgtype)]} {
	    array set options $dialogTypes($dlgtype)
	}
	set argsA(-menu) $defaultmenu
	array set argsA $args
	
	$self configurelist [array get argsA]
	
	if {[tk windowingsystem] eq "aqua"} {
	    if {$options(-modal)} {
		::tk::unsupported::MacWindowStyle style $win moveableModal none
	    } else {
		::tk::unsupported::MacWindowStyle style $win document closeBox
	    }
	} else {
	    $win configure -menu ""
	}
	if {![winfo exists $options(-parent)]} {
	    return -code error "bad window path name \"$options(-parent)\""
	}
	if {[winfo viewable [winfo toplevel $options(-parent)]] } {
	    wm transient $win $options(-parent)
	}    
	wm title $win $options(-title)
	set wraplength [$top.message cget -wraplength]
	
	set icon $options(-icon)
	if {$options(-badge) && [info exists images($icon,badge)]} {
	    set im $images($icon,badge)
	} elseif {[string length $icon]} {
	    set im $images($icon)
	} else {
	    set im ""
	}
	if {[string length $icon]} {
	    set minsize 64
	} else {
	    set minsize 0
	}
	ttk::label $top.icon -image $im
	
	grid $top.icon    -column 0 -row 0 -rowspan 3 -sticky n
	grid $top.message -column 1 -row 0 -sticky nw
	grid columnconfigure $top 0 -minsize $minsize
	grid columnconfigure $top 1 -minsize $wraplength

	# This stops -detail from being configurable :-(
	if {[$top.detail cget -text] ne ""} {
	    grid  $top.detail  -column 1 -row 1 -sticky nw
	}
	set client $top.client
	set bottom $f.b
	ttk::frame $f.b
	
	# Reversed order for Mac.
	set buttons $options(-buttons)
	if {[option get $win buttonOrder {}] eq "cancelok"} {
	    set buttons {}
	    foreach b $options(-buttons) {
		set buttons [linsert $buttons 0 $b]
	    }
	}
	set column 0
	set padx [option get $win buttonPadX {}]
	
	foreach bt $buttons {
	    
	    # Using -padx wont work here due to -uniform
	    incr column
	    eval [linsert $buttonOptions($bt) 0 ttk::button $bottom.$bt]
	    $bottom.$bt configure -command [list $self Done $bt]
	    grid $bottom.$bt -row 0 -column $column -sticky ew
	    grid columnconfigure $bottom $column -uniform buttons
	    
	    # Using empty frame for padding.
	    if {$bt ne [lindex $buttons end]} {
		incr column
		ttk::frame $bottom.$column
		grid columnconfigure $bottom $column -minsize $padx
	    }
	}
	if {[option get $win buttonOrder {}] eq "cancelok"} {
	    if {[llength $buttons] > 2} {
		#grid 
	    }
	}
	if {$buttons eq {}} {
	    set options(-default) ""
	}

	if {$options(-default) ne ""} {
	    bind $win <KeyPress-Return> \
	      [list event generate $bottom.$options(-default) <<Invoke>>]
	    focus $bottom.$options(-default)
	}
	if {$options(-cancel) ne ""} {
	    bind $win <KeyPress-Escape> \
	      [list event generate $bottom.$options(-cancel) <<Invoke>>]
	}

	pack $f
	pack $top    -side top
	pack $bottom -side bottom -anchor [option get $win buttonAnchor {}]

	if {[string length $options(-geovariable)]} {
	    ui::PositionWindow $win $options(-geovariable)
	} elseif {$positionType eq "stack"} {
	    
	    # Get first free slot in 'dialogStack'.
	    if {[llength $dialogStack]} {
		set idx [expr {[lindex $dialogStack end] + 1}]
	    } else {
		set idx 0
	    }
	    set stackIdx $idx
	    lappend dialogStack $idx
	    foreach {x y} [GetPositionAtIndex $idx] { break }
	    wm geometry $win +$x+$y
	}
	if {$options(-modal)} {
	    # This doesn't work because we are destroyed after grab is released!
	    #ui::Grab $win
	}
	if {[string length $options(-timeout)]} {
	    set timeoutID [after $options(-timeout) [list $self Timeout]]
	}
	return
    }
    
    destructor {
	if {[info exists timeoutID]} {
	    after cancel $timeoutID
	}
	if {[info exists fadeoutID]} {
	    after cancel $fadeoutID
	}
	if {[info exists stackIdx]} {
	    set idx [lsearch $dialogStack $stackIdx]
	    if {$idx >= 0} {
		set dialogStack [lreplace $dialogStack $idx $idx]
	    }
	}
	    
	# This happens when the dialog isn't closed with any of the buttons.
	if {!$isDone} {
	    
	    # If there is a cancel button this is the default in this case.
	    # Else an empty string indicates that the dialog was closed this way.
	    if {$options(-cancel) ne ""} {
		set button $options(-cancel)
	    } else {
		set button ""
	    }
	    if {[string length $options(-variable)]} {
		uplevel #0 [list set $options(-variable) $button]
	    }
	    set rc [catch [linsert $options(-command) end $win $button] result]
	}
    }

    # StockButton -- define new built-in button
    #
    proc StockButton {button args} {
	set buttonOptions($button) $args
    }

    # StockDialog -- define new dialog type.
    #
    proc StockDialog {dlgtype args} {
	set dialogTypes($dlgtype) $args
    }
    
    # Get a typical size so we can start positioning.
    proc GetInitialPosition {} {
	if {[llength $centerPos]} {
	    return $centerPos
	}
	set str [string repeat "xx " 36]
	set w [ui::dialog -message $str -detail $str]
	wm withdraw $w
	update idletasks
	set dW [winfo reqwidth $w]
	set dH [winfo reqheight $w]
	set sW [winfo screenwidth .]
	set sH [winfo screenheight .]
	destroy $w
	set x [expr {($sW - $dW)/2}]
	set y [expr {3*($sH - $dH)/7}]
	puts "GetInitialPosition $x $y"
	set centerPos [list $x $y]
	set typicalDlgSize [list $dW $dH]
	return $centerPos
    }

    proc GetPositionAtIndex {idx} {
	
	# Do calculations using an inset of the actual screen and then
	# scale back to the actual screen.
	foreach {x0 y0} [GetInitialPosition] { break }
	foreach {dW dH} $typicalDlgSize { break }
	
	# This is the inset screen rectangle (x, y, width, height)
	set inset(x) 20
	set inset(y) 20
	set inset(w) [expr {[winfo screenwidth .] - $inset(x) - $dW}]
	set inset(h) [expr {[winfo screenheight .] - $inset(y) - $dH}]
	puts "x0=$x0, y0=$y0, dW=$dW, dH=$dH"
	
	set x [expr {($x0 + $idx*30 - $inset(x)) % $inset(w) + $inset(x)}]
	set y [expr {($y0 + $idx*20 - $inset(y)) % $inset(h) + $inset(y)}]
	return [list $x $y]
    }
    
    # Private methods:
    
    method OnConfigTitle {option value} {
	wm title $win $value
	set options($option) $value
    }
    
    method ValidateType {option value} {
	if {![info exists dialogTypes($value)]} {
	    set valid [join [lsort [array names dialogTypes]] ", "]
	    return -code error "unrecognized type $value, must be one of $valid"
	}
    }
    
    method ValidateIcon {option value} {
	upvar ::ui::dialog::images images
	if {[string length $value] && ![info exists images($value)]} {
	    set valid [join $images(names) ", "]
	    return -code error "unrecognized icon $value, must be one of $valid"
	}
    }
    
    method Timeout {} {
	unset -nocomplain timeoutID
	if {$wmalpha} {
	    $self FadeOut {0.95 0.9 0.85 0.8 0.75 0.7 0.65 0.6 0.55 0.5 0.4 0.3 0.2}
	} else {
	    $self Dismiss
	}
    }
    
    method FadeOut {fades} {
	if {[llength $fades]} {
	    wm attributes $win -alpha [lindex $fades 0]
	    set fadeoutID [after 80 [list $self FadeOut [lrange $fades 1 end]]]
	} else {
	    $self Dismiss
	}
    }
	
    method Done {button} {
	set isDone 1
	if {[string length $options(-variable)]} {
	    uplevel #0 [list set $options(-variable) $button]
	}
	set rc [catch [linsert $options(-command) end $win $button] result]
	if {$rc == 1} {
	    return -code $rc -errorinfo $::errorInfo -errorcode $::errorCode $result
	} elseif {$rc == 3 || $rc == 4} {
	    # break or continue -- don't dismiss dialog
	    return
	} 
	
	# We can have been destroyed already!
	if {[lsearch [ui::dialog::widget info instances] $win] >= 0} {
	    $self Dismiss
	}
    }
        
    method Dismiss {} {
	if {[string length $options(-geovariable)]} {
	    ui::SaveGeometry $win $options(-geovariable)
	}
	destroy $win
    }
    
    # Public methods:
    
    method clientframe {} { 
	if {![winfo exists $client]} {
	    ttk::frame $client
	    grid $client -column 1 -row 2 -sticky news
	    # so it's first in keyboard traversal order
	    lower $client
	}
	return $client 
    }

    method grab {} {
	ui::Grab $win
    }
}

proc ui::dialog::ModalCmd {w button} {
    variable buttonModal
    set buttonModal $button
}

# ui::dialog::modal --
# 
#       As ui::dialog but it is a modal dialog and returns the pressed button.

proc ui::dialog::modal {args} {
    variable buttonModal
 
    set w [ui::autoname]
    ui::from args -modal
    ui::from args -command
    set postCmd [ui::from args -postcommand]
    eval {widget $w -modal 1 -command [namespace code ModalCmd]} $args
    if {[llength $postCmd]} {
	uplevel #0 $postCmd $w
    }
    ui::Grab $w
    return $buttonModal
}


if {0} {
    # Tests... Run from inside Coccinella.
    foreach name {info error warning question} {
	ui::dialog::setimage $name [::Theme::GetImage ${name}64]
    }
    ui::dialog::setbadge [::Theme::GetImage Coccinella]
    ui::dialog::setimage coccinella [::Theme::GetImage coccinella64]
    proc cmd1 {w bt} {destroy $w}
    proc cmd2 {w bt} {puts "cmd: bt=$bt, dlgvar=$::dlgvar"}

    set str "These two must be able to call before any dialog instance created."
    set str2 "Elvis has left the building and is driving his white Cadillac."
    ui::dialog -message $str -detail $str2
    ui::dialog -message $str -detail $str2  \
      -icon error -buttons {yes no cancel} -default yes -variable dlgvar
    ui::dialog -message "Check destroy from -command" -command cmd1
    ui::dialog -message $str -type yesnocancel -command cmd2 -variable dlgvar
    ui::dialog -message "Check timeout for auto destruction"  \
      -timeout 4000 -buttons {}
    set w [ui::dialog -message $str -detail $str  \
      -icon error -type yesnocancel]
    set fr [$w clientframe]
    pack [ttk::checkbutton $fr.c -text $str2] -side left
    
    ui::dialog defaultmenu [::UI::GetMainMenu]
    set w [ui::dialog -message $str -detail $str2 -modal 1]

    ui::dialog::modal -message "This is a modal dialog" -detail $str2 \
      -icon error -type yesnocancel
    
    # Test stacking:
    ui::dialog positiontype stack
    set str "These two must be able to call before any dialog instance created."
    set str2 "Elvis has left the building and is driving his white Cadillac."
    for {set i 0} {$i < 30} {incr i} {
	ui::dialog -message $str -detail "$str2 Number $i"
    }
}

#-------------------------------------------------------------------------------
