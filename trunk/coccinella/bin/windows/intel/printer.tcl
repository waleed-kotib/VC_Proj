################################################################
## printer.tcl
##
## Usage:
##	printer::print_widget p
##		If the parameter p is anything but default, uses the
##		print dialog. If it is default, it uses the default printer.
##
## Prints a canvas "reasonably" well (as GDI matures...)
## John Blattner <johnb@imagix.com> contributed the original
## version of this code.
## Modifications made by Michael Schwartz (mschwart@nyx.net)
## Handles some additional printer types that do not put numbers in the
## resolution field
## Darcy Kahle <darcykahle@sympatico.ca> contributed the origianl
## version of this code.
## Modifications made by Michael Schwartz (mschwart@nyx.net)
## Several suggestions and code contributions were made by Mick O'Donnell (micko@wagsoft.com)
##
## This version (0.1) scales the canvas to "fit" the page.
## It is very limited now, by may meet simple user needs.
## LIMITATIONS:
##   This is limited by GDI (e.g., no arrows on the lines, stipples),
##   and is also limited in current canvas items supported.
##   For instance, bitmaps and images are not yet supported.
##
## Idea mill for future enhancements:
## c) Add an optional page title and footer
## d) Add tk font support to the gdi command if tk is loaded.
## e) Make scaling an option
## f) Make rendering the canvas something done as PART of a 
##    print.
################################################################
#
# CHANGES by Mats Bengtsson
#
# - fixed font spec problem
# - ppt replaced by ppi
# - changed -offset in gdi map call
# - rewrites, added stuff from text printing

package require gdi
package require printer

namespace eval printer {

    # First some utilities to ensure we can debug this sucker.
    
    variable debug
    variable option
    variable vtgPrint
}

proc printer::init_print_canvas { } {
    variable debug
    variable option
    variable vtgPrint
    
    set debug 0
    set option(use_copybits) 1
    set vtgPrint(printer.bg) white
}

proc printer::is_win {} {
    return [ info exist tk_patchLevel ]
}

proc printer::debug_puts {str} {
    variable debug
    
    if $debug {
	if {[ is_win ]} {
	    if {![winfo exist .debug ]} {
		set tl [ toplevel .debug ]
		frame $tl.buttons
		pack $tl.buttons -side bottom -fill x
		button $tl.buttons.ok -text OK -command "destroy .debug"
		pack $tl.buttons.ok
		text $tl.text -yscroll "$tl.yscroll set"
		scrollbar $tl.yscroll -orient vertical -command "$tl.text yview"
		pack $tl.yscroll -side right -fill y -expand false
		pack $tl.text    -side left -fill both -expand true
	    }
	    $tl.text insert end $str
	} else {
	    puts "Debug: $str"
	    after 100
	}
    }
}

################################################################
## page_args
## Description:
##   This is a helper proc used to parse common arguments for
##   text processing in the other commands.
##   "Reasonable" defaults are provided if not present
## Args:
##   Name of an array in which to store the various pieces 
##   needed for text processing
################################################################

proc printer::page_args { arrName } {
    # use upvar one level to get into the context of the immediate caller.
    upvar 1 $arrName ary
    
    # First we check whether we have a valid hDC
    # (perhaps we can later make this also an optional argument, defaulting to 
    #  the default printer)
    set attr [ printer attr ]
    foreach attrpair $attr {
	set key [lindex $attrpair 0]
	set val [lindex $attrpair 1]
	set ary($key) $val
	switch -exact $key {
	    "page dimensions" {
		set wid [lindex $val 0]
		set hgt [lindex $val 1]
		if { $wid > 0 } { set ary(pw) $wid }
		if { $hgt > 0 } { set ary(pl) $hgt }
	    }
	    "page margins"    {
		if { [scan [lindex $val 0] %d tmp] > 0 } {
		    foreach {ary(lm) ary(tm) ary(rm) ary(bm)} $val {}
		}
	    }
	    "resolution"      {
		if { [scan [lindex $val 0] %d tmp] > 0 } {
		    foreach {ary(resx) ary(resy)} $val {}
		} else {
		    set ary(resolution) [lindex $val 0]
		}
	    }
	}
    }
    
    if { ( [ info exist ary(hDC) ] == 0 ) || ($ary(hDC) == 0x0) } {
	error "Can't get printer attributes"
    }
    
    # Now, set "reasonable" defaults if some values were unavailable
    # Resolution is the hardest. Uses "resolution" first, if it was numeric.
    # Uses "pixels per inch" second, if it is set.
    # Use the words medium and best for resolution third--these are guesses
    # Uses 200 as a last resort.
    if { ![info exist ary(resx)] } { 
	set ppi "pixels per inch"
	if { [info exist ary($ppi)] } {
	    if { [scan $ary($ppi) "%d %d" tmp1 tmp2] > 0 } {
		set ary(resx) $tmp1
		if { $tmp2 > 0 } {
		    set ary(resy) $tmp2
		}
	    } else {
		if [ string match -nocase $ary($ppi) "medium" ] {
		    set ary(resx) 300
		    set ary(resy) 300
		} elseif [ string match -nocase $ary($ppi) "best" ] {
		    set ary(resx) 600
		    set ary(resy) 600
		} else {
		    set ary(resx) 200
		    set ary(resy) 200
		}
	    }
	} else {
	    set ary(resx) 200 
	}
    }
    if { [ info exist ary(resy) ] == 0 } { set ary(resy) $ary(resx) }
    if { [ info exist ary(tm) ] == 0 } { set ary(tm) 1000 }
    if { [ info exist ary(bm) ] == 0 } { set ary(bm) 1000 }
    if { [ info exist ary(lm) ] == 0 } { set ary(lm) 1000 }
    if { [ info exist ary(rm) ] == 0 } { set ary(rm) 1000 }
    if { [ info exist ary(pw) ] == 0 } { set ary(pw) 8500 }
    if { [ info exist ary(pl) ] == 0 } { set ary(pl) 11000 }
    if { [ info exist ary(copies) ] == 0 } { set ary(copies) 1 }
}

################################################################
# These procedures read in the canvas widget, and write all of #
# its contents out to the Windows printer.                     #
################################################################

################################################################
## print_widget
## Description:
##   Main procedure for printing a widget.  Currently supports
##   canvas widgets.  Handles opening and closing of printer.
##   Assumes that printer and gdi packages are loaded.
## Args:
##   wid                The widget to be printed. 
##   args
##        -printer      Flag whether to use the default printer. 
##        -name         App name to pass to printer. 
##        -font         Specify font.
##        -data         text
################################################################

proc printer::print_widget { wid args } {
    
    variable debug

    array set argsArr {
	-data         {}
	-printer      {}
	-name         "Tcl"
	-font         {}
	-copybits     1
    }
    array set argsArr $args
    
    # start printing process ------
    if {[string match "default" $argsArr(-printer)]} {
	set hdc [printer open]
    } else {
	set hdc [printer dialog select]
	if { [lindex $hdc 1] == 0 } {
	    # User has canceled printing
	    return
	}
	set hdc [ lindex $hdc 0 ]
    }
    
    variable p
    set p(0) 0 ; unset p(0)
    page_args p
    
    if {![info exist p(hDC)]} {
	set hdc [printer open]
	page_args p
    }
    if {[string match "?" $hdc] || [string match 0x0 $hdc]} {
	catch {printer close}
	error "Problem opening printer: printer context cannot be established"
    }
    
    printer job start -name "$argsArr(-name)"
    printer page start
    
    # Here is where any scaling/gdi mapping should take place
    # For now, scale so the dimensions of the window are sized to the
    # width of the page. Scale evenly.
    
    # For normal windows, this may be fine--but for a canvas, one wants the 
    # canvas dimensions, and not the WINDOW dimensions.
    if { [winfo class $wid] == "Canvas" } {
	set sc [ lindex [ $wid configure -scrollregion ] 4 ]
	# if there is no scrollregion, use width and height.
	# Mats: since copybits take only visible window.
	if {1 || "$sc" == "" } {
	    set window_x [ lindex [ $wid configure -width ] 4 ]
	    set window_y [ lindex [ $wid configure -height ] 4 ]
	} else {
	    set window_x [ lindex $sc 2 ]
	    set window_y [ lindex $sc 3 ]
	}
    } else {
	set window_x [ winfo width $wid ]
	set window_y [ winfo height $wid ]
    }
    
    set pd "page dimensions"
    set pm "page margins"
    set ppi "pixels per inch"
    
    set printer_x [ expr ( [lindex $p($pd) 0] - \
      [lindex $p($pm) 0 ] - [lindex $p($pm) 2 ] ) * \
      [lindex $p($ppi) 0] / 1000.0 ]
    set printer_y [ expr ( [lindex $p($pd) 1] - \
      [lindex $p($pm) 1 ] - [lindex $p($pm) 3 ] ) * \
      [lindex $p($ppi) 1] / 1000.0 ]
    set factor_x [ expr $window_x / $printer_x ]
    set factor_y [ expr $window_y / $printer_y ]
    
    debug_puts "printer: ($printer_x, $printer_y)"
    debug_puts "window : ($window_x, $window_y)"
    debug_puts "factor : $factor_x $factor_y"
    
    if { $factor_x < $factor_y } {
	set lo $window_y
	set ph $printer_y
	set p_y $printer_y
	set p_x [expr $p_y * $window_x / $window_y]
    } else {
	set lo $window_x
	set ph $printer_x
	set p_x $printer_x
	set p_y [expr $p_x * $window_y / $window_x]
    }
    
    # handling of canvas widgets
    # additional procs can be added for other widget types
    switch [winfo class $wid] {
	Canvas {
	    if {$argsArr(-copybits)} {
		#gdi copybits $hdc -window $wid   \
		#  -source [list 0 0 $window_x $window_y] \
		#  -destination [list $p(lm) $p(tm) ]
		raise [winfo toplevel $wid]
		update
		gdi map $hdc -logical $lo -physical $ph -offset [list $p(resx) $p(resy)]
		gdi copybits $hdc -window $wid
	    } else {
    
		# The offset still needs to be set based on page margins
		debug_puts [ list \
		  gdi map $hdc -logical $lo -physical $ph -offset [list $p(resx) $p(resy)] ]
		gdi map $hdc -logical $lo -physical $ph -offset [list $p(resx) $p(resy)]
		
		print_canvas [lindex $hdc 0] $wid
	    }
	}
	Text {
	    set lm [ expr $p(lm) * $p(resx) / 1000 ]
	    set tm [ expr $p(tm) * $p(resy) / 1000 ]
	    set pw [ expr ($p(pw) - $p(rm) - $p(lm)) * $p(resx) / 1000 ]
	    set pl [ expr ($p(pl) - $p(tm) - $p(bm)) * $p(resx) / 1000 ]
	    if {$debug} {
		gdi rectangle $p(hDC) $lm $tm [expr $lm+$pw] [expr $tm+$pl]
		gdi text $p(hDC) $lm [expr $tm+$pl] -anchor sw -text  \
		  "lm=$lm, tm=$tm, pw=$pw, pl=$pl" -font {Times 10}
		gdi text $p(hDC) $lm [expr $tm+$pl-200] -anchor sw -text  \
		  "p(resx)=$p(resx), p(resy)=$p(resy)" -font {courier 10}
	    }
	    if {[llength $argsArr(-font)]} {
		set fontargs [list -font [printer::font_map $argsArr(-font)]]
	    } else {
		set fontargs {}
	    }
	    if {[llength $argsArr(-data)]} {
		set data $argsArr(-data)
	    } else {
		set data [$wid get 1.0 end]
	    }
	    eval {gdi text $p(hDC) $lm $tm -anchor nw -text $data -width $pw} \
	      $fontargs
	}
	default {
	    debug_puts "Can't print items of type [winfo class $wid]. No handler registered"
	}
    }
    
    # end printing process ------
    printer page end
    printer job end
    printer close
}

proc printer::font_map {font} {
    
    switch -- [lindex $font 0] {
	"Courier" {	    
	    return "{Courier New} [lrange $font 1 end]"
	}
	default {
	    return $font
	}
    }
}

################################################################
## print_page_data
## Description:
##   This is the simplest way to print a small amount of text
##   on a page. The text is formatted in a box the size of the
##   selected page and margins.
## Args:
##   data         Text data for printing
##   fontargs     Optional arguments to supply to the text command
################################################################

proc printer::print_page_data {data args} {    
    
    page_args printargs
    if { ! [info exist printargs(hDC)] } {
	printer open
	page_args printargs
    }
    
    set tm [ expr $printargs(tm) * $printargs(resy) / 1000 ]
    set lm [ expr $printargs(lm) * $printargs(resx) / 1000 ]
    set pw [ expr ( $printargs(pw)  - $printargs(lm) - $printargs(rm) ) /  \
      1000 * $printargs(resx) ]
    printer job start
    printer page start
    eval {gdi text $printargs(hDC) $lm $tm \
      -anchor nw -text $data -width $pw} $args
    printer page end
    printer job end
}

################################################################
## print_canvas
## Description:
##   Main procedure for writing canvas widget items to printer.
## Args:
##   hdc                The printer handle.
##   cw                 The canvas widget.
################################################################

proc printer::print_canvas {hdc cw} {
    variable  vtgPrint
    
    # get information about page being printed to
    # print_canvas.CalcSizing $cw
    set vtgPrint(canvas.bg) [string tolower [$cw cget -background]]
    
    # re-write each widget from cw to printer
    foreach id [$cw find all] {
	set type [$cw type $id]
	if { [ info commands print_canvas.$type ] == "print_canvas.$type" } {
	    print_canvas.[$cw type $id] $hdc $cw $id
	} else {
	    debug_puts "Omitting canvas item of type $type since there is no handler registered for it"
	}
    }
}

################################################################
## These procedures support the various canvas item types,     #
## reading the information about the item on the real canvas   #
## and then writing a similar item to the printer.             #
################################################################

################################################################
## print_canvas.line
## Description:
##   Prints a line item.
## Args:
##   hdc                The printer handle.
##   cw                 The canvas widget.
##   id                 The id of the canvas item.
################################################################

proc printer::print_canvas.line {hdc cw id} {
    variable vtgPrint
    
    set color [print_canvas.TransColor [$cw itemcget $id -fill]]
    if {[string match $vtgPrint(printer.bg) $color]} {return}
    set coords  [$cw coords $id]
    set wdth [$cw itemcget $id -width]
    
    if {$wdth <= 1 } {
	set cmmd "gdi line $hdc $coords -fill $color"
    } else {
	set cmmd "gdi line $hdc $coords -fill $color -width $wdth"
    }
    
    debug_puts "$cmmd"
    eval $cmmd
}


################################################################
## print_canvas.polygon
## Description:
##   Prints a polygon item.
## Args:
##   hdc                The printer handle.
##   cw                 The canvas widget.
##   id                 The id of the canvas item.
################################################################

proc printer::print_canvas.polygon {hdc cw id} {
    variable vtgPrint
    
    set fcolor [print_canvas.TransColor [$cw itemcget $id -fill]]
    if {![string length $fcolor]} {set fcolor $vtgPrint(printer.bg)}
    set ocolor [print_canvas.TransColor [$cw itemcget $id -outline]]
    if {![string length $ocolor]} {set ocolor $vtgPrint(printer.bg)}
    set coords  [$cw coords $id]
    set wdth [$cw itemcget $id -width]
    
    set cmmd "gdi polygon $hdc $coords -width $wdth \
      -fill $fcolor -outline $ocolor"
    debug_puts "$cmmd"
    eval $cmmd
}


################################################################
## print_canvas.oval
## Description:
##   Prints an oval item.
## Args:
##   hdc                The printer handle.
##   cw                 The canvas widget.
##   id                 The id of the canvas item.
################################################################

proc printer::print_canvas.oval { hdc cw id } {
    variable vtgPrint
    
    set fcolor [print_canvas.TransColor [$cw itemcget $id -fill]]
    if {![string length $fcolor]} {set fcolor $vtgPrint(printer.bg)}
    set ocolor [print_canvas.TransColor [$cw itemcget $id -outline]]
    if {![string length $ocolor]} {set ocolor $vtgPrint(printer.bg)}
    set coords  [$cw coords $id]
    set wdth [$cw itemcget $id -width]
    
    set cmmd "gdi oval $hdc $coords -width $wdth \
      -fill $fcolor -outline $ocolor"
    debug_puts "$cmmd"
    eval $cmmd
}

################################################################
## print_canvas.rectangle
## Description:
##   Prints a rectangle item.
## Args:
##   hdc                The printer handle.
##   cw                 The canvas widget.
##   id                 The id of the canvas item.
################################################################

proc printer::print_canvas.rectangle {hdc cw id} {
    variable vtgPrint
    
    set fcolor [print_canvas.TransColor [$cw itemcget $id -fill]]
    if {![string length $fcolor]} {set fcolor $vtgPrint(printer.bg)}
    set ocolor [print_canvas.TransColor [$cw itemcget $id -outline]]
    if {![string length $ocolor]} {set ocolor $vtgPrint(printer.bg)}
    set coords  [$cw coords $id]
    set wdth [$cw itemcget $id -width]
    
    set cmmd "gdi rectangle $hdc $coords -width $wdth \
      -fill $fcolor -outline $ocolor"
    debug_puts "$cmmd"
    eval $cmmd
}


################################################################
## print_canvas.text
## Description:
##   Prints a text item.
## Args:
##   hdc                The printer handle.
##   cw                 The canvas widget.
##   id                 The id of the canvas item.
################################################################

proc printer::print_canvas.text {hdc cw id} {
    variable vtgPrint
    variable p
    
    set p(0) 1 ; unset p(0)
    page_args p
    
    set color [print_canvas.TransColor [$cw itemcget $id -fill]]
    #    if {[string match white [string tolower $color]]} {return}
    #    set color black
    set txt [$cw itemcget $id -text]
    if {![string length $txt]} {return}
    set coords [$cw coords $id]
    set anchr [$cw itemcget $id -anchor]
    
    set bbox [$cw bbox $id]
    set wdth [expr [lindex $bbox 2] - [lindex $bbox 0]]
    
    set just [$cw itemcget $id -justify]
    
    set font [ $cw itemcget $id -font ]
    #set font [list [font configure -family]  -[font configure -size]]
    
    set cmmd "gdi text $hdc $coords -fill $color -text [list $txt] \
      -anchor $anchr -font [ list $font ] \
      -width $wdth -justify $just"
    debug_puts "$cmmd"
    eval $cmmd
} 


################################################################
## print_canvas.image
## Description:
##   Prints an image item.
## Args:
##   hdc                The printer handle.
##   cw                 The canvas widget.
##   id                 The id of the canvas item.
################################################################

proc printer::print_canvas.image {hdc cw id} {
    
    variable vtgPrint
    variable option
    
    # First, we have to get the image name
    set imagename [ $cw itemcget $id -image]
    # Now we get the size
    set wid [ image width $imagename]
    set hgt [ image height $imagename ]
    # next, we get the location and anchor
    set anchor [ $cw itemcget $id -anchor ]
    set coords [ $cw coords $id ]
    
    
    # Since the GDI commands don't yet support images and bitmaps,
    # and since this represents a rendered bitmap, we CAN use
    # copybits IF we create a new temporary toplevel to hold the beast.
    # if this is too ugly, change the option!
    if { [ info exist option(use_copybits) ] } {
	set firstcase $option(use_copybits)
    } else {
	set firstcase 0
    }
    
    if { $firstcase > 0 } {
	set tl [toplevel .tmptop[expr int( rand() * 65535 ) ] -height $hgt -width $wid -background $vtgPrint(printer.bg) ]
	canvas $tl.canvas -width $wid -height $hgt
	$tl.canvas create image 0 0 -image $imagename -anchor nw
	pack $tl.canvas -side left -expand false -fill none 
	tkwait visibility $tl.canvas
	update
	set srccoords [list "0 0 [ expr $wid - 1] [expr  $hgt - 1 ]" ]
	set dstcoords [ list "[lindex $coords 0] [lindex $coords 1] [expr $wid - 1] [expr $hgt - 1]" ]
	set cmmd "gdi copybits $hdc -window $tl -client -source $srccoords -destination $dstcoords "
	debug_puts "$cmmd"
	eval $cmmd
	destroy $tl      
    } else {
	set cmmd "gdi image $hdc $coords -anchor $anchor -image $imagename"
	debug_puts "$cmmd"
	eval $cmmd
    }
}

################################################################
## print_canvas.bitmap
## Description:
##   Prints a bitmap item.
## Args:
##   hdc                The printer handle.
##   cw                 The canvas widget.
##   id                 The id of the canvas item.
################################################################

proc printer::print_canvas.bitmap {hdc cw id} {
    variable option
    variable vtgPrint
    
    # First, we have to get the bitmap name
    set imagename [ $cw itemcget $id -bitmap]
    # Now we get the size
    set wid [ image width $imagename]
    set hgt [ image height $imagename ]
    # next, we get the location and anchor
    set anchor [ $cw itemcget $id -anchor ]
    set coords [ $cw itemcget $id -coords ]
    
    # Since the GDI commands don't yet support images and bitmaps,
    # and since this represents a rendered bitmap, we CAN use
    # copybits IF we create a new temporary toplevel to hold the beast.
    # if this is too ugly, change the option!
    if { [ info exist option(use_copybits) ] } {
	set firstcase $option(use_copybits)
    } else {
	set firstcase 0
    }
    if { $firstcase > 0 } {
	set tl [toplevel .tmptop[expr int( rand() * 65535 ) ] -height $hgt -width $wid -background $vtgPrint(canvas.bg) ]
	canvas $tl.canvas -width $wid -height $hgt
	$tl.canvas create bitmap 0 0 -bitmap $imagename -anchor nw
	pack $tl.canvas -side left -expand false -fill none 
	tkwait visibility $tl.canvas
	update
	set srccoords [list "0 0 [ expr $wid - 1] [expr  $hgt - 1 ]" ]
	set dstcoords [ list "[lindex $coords 0] [lindex $coords 1] [expr $wid - 1] [expr $hgt - 1]" ]
	set cmmd "gdi copybits $hdc -window $tl -client -source $srccoords -destination $dstcoords "
	debug_puts "$cmmd"
	eval $cmmd
	destroy $tl      
    } else {
	set cmmd "gdi bitmap $hdc $coords -anchor $anchor -bitmap $imagename"
	debug_puts "$cmmd"
	eval $cmmd
    }
}

################################################################
## These procedures transform attribute setting from the real  #
## canvas to the appropriate setting for printing to paper.    #
################################################################

################################################################
## print_canvas.TransColor
## Description:
##   Does the actual transformation of colors from the
##   canvas widget to paper.
## Args:
##   color              The color value to be transformed.
################################################################

proc printer::print_canvas.TransColor {color} {
    variable vtgPrint
    
    switch [string toupper $color] {
	$vtgPrint(canvas.bg)       {return $vtgPrint(printer.bg)} 
    }
    return $color
}

# Initialize all the variables once
printer::init_print_canvas

