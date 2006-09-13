#  Bookmarks.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a bookmarks dialog.
#      
#      @@@ Perhaps this could be made general enogh to be placed in ui/
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: Bookmarks.tcl,v 1.5 2006-09-13 14:09:12 matben Exp $

package require snit 1.0
package require ui::util

package provide Bookmarks 1.0

namespace eval ::Bookmarks {

    set title [mc Bookmarks]	
    option add *Bookmarks.title         $title      widgetDefault
}

# Bookmarks::Dialog --
#
#       Megawidget bookmarks dialog.

snit::widget ::Bookmarks::Dialog {
    hulltype toplevel
    widgetclass Bookmarks
    
    # @@@ works only on macs!!!
    # -menu must be done only on creation, else crash on mac.
    delegate option -menu to hull
    
    variable bookmarksVar
    variable tmpList
    variable boolColumns
    variable boolVar
    variable wtablelist
    variable wnew
    variable wsave
    variable wrun

    option -command      -default ::Bookmarks::Nop
    option -geovariable
    option -title -configuremethod OnConfigTitle
    option -columns     -default {0 Bookmark 0 Address}
    option -editable    -default {}
    
    constructor {_bookmarksVar args} {
	$self configurelist $args
	set bookmarksVar $_bookmarksVar
	
	# Operate on a temporary list.
	set tmpList [uplevel #0 [list set $bookmarksVar]]
	
	if {[tk windowingsystem] ne "aqua"} {
	    $win configure -menu ""
	}
	wm title $win $options(-title)

	# Global frame.
	set wbox $win.f
	ttk::frame $wbox -padding [option get . dialogPadding {}]
	pack $wbox -fill both -expand 1

	frame $wbox.fb -bd 1 -relief sunken
	set wfb $wbox.fb
	set wsc $wfb.s
	set wtb $wfb.t
	set wtablelist $wtb
	
	ttk::scrollbar $wsc -orient vertical -command [list $wtb yview]
	tablelist::tablelist $wtb -columns $options(-columns)  \
	  -listvariable [myvar tmpList] -stretch all           \
	  -yscrollcommand [list $wsc set] -width 48 -bd 0
	
	# Make all columns editable by default.
	if {[llength $options(-editable)]} {
	    foreach c $options(-editable) {
		$wtb columnconfigure $c -editable 1
	    }
	} else {
	    set ncol [$wtb columncount]
	    for {set c 0} {$c < $ncol} {incr c} {
		$wtb columnconfigure $c -editable 1
	    }
	}
	set rowCount [$wtb size]
	for {set row 0} {$row < $rowCount} {incr row} {
	    $self BooleanColumnsForRow $row
	}
	
	grid  $wtb  -column 0 -row 0 -sticky news
	grid  $wsc  -column 1 -row 0 -sticky ns
	grid columnconfigure $wfb 0 -weight 1
	grid rowconfigure    $wfb 0 -weight 1
	
	pack $wfb -fill both -expand 1
	
	# Button part.
	set bot $wbox.b
	ttk::frame $bot -padding [option get . okcancelTopPadding {}]
	ttk::button $bot.save -text [mc Save] -default active  \
	  -command [list $self Save]
	::chasearrows::chasearrows $bot.run -size 16
	ttk::button $bot.cancel -text [mc Cancel]  \
	  -command [list $self Destroy]
	ttk::button $bot.new -text [mc {New Bookmark}]  \
	  -command [list $self New]
	set padx [option get . buttonPadX {}]
	if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	    pack $bot.save   -side right
	    pack $bot.cancel -side right -padx $padx
	} else {
	    pack $bot.cancel -side right
	    pack $bot.save   -side right -padx $padx
	}
	pack $bot.new -side left
	pack $bot.run -side left -padx 8
	pack $bot -side bottom -fill x
	
	set wsave $bot.save
	set wnew  $bot.new
	set wrun  $bot.run
	
	if {[string length $options(-geovariable)]} {
	    ui::SetClassGeometry $win $options(-geovariable) "Bookmarks"
	}

	set tag [$wtb bodytag]
	bind $win <Return> [list $self Save]
	bind $win <Escape> [list $self Cancel]
	bind $tag <BackSpace> [list $self Delete]

	return
    }
    
    destructor {
	if {[string length $options(-geovariable)]} {
	    ui::SaveGeometry $win $options(-geovariable)
	}
    }
    
    method OnConfigTitle {option value} {
	wm title $win $value
	set options($option) $value
    }
    
    method New {} {
	set row [list [mc {New Bookmark}]]
	set ncol [$wtablelist columncount]
	for {set i 1} {$i < $ncol} {incr i} {
	    lappend row {}
	}
	lappend tmpList $row
	$wtablelist editcell end,0
    }
    
    method Delete {} {
	set items [$wtablelist curselection]
	foreach item [lsort -integer -decreasing $items] {
	    $wtablelist delete $item	
	}
	puts $tmpList
    }
        
    method Save {} {
	$wtablelist finishediting
	
	# Trim empty rows.
	set tmp {}
	set ncol [$wtablelist columncount]
	for {set c 0} {$c < $ncol} {incr c} {
	    lappend tmp {}
	}
	set tmpList [lsearch -all -not -inline $tmpList $tmp]

	puts $tmpList

	# Any booleans.
	if {1} {
	    foreach {key value} [array get boolVar] {
		puts "\t key=$key, value=$value"
		foreach {row col} [split $key ,] break
		lset tmpList $row $col $value
	    }
	}

	#set wcheck [$wtablelist cellconfigure $row,$col -window]
	#puts "wcheck=$wcheck"

	
	
	uplevel #0 [list set $bookmarksVar $tmpList]

	if {$options(-command) ne ""} {
	    set rc [catch {$options(-command)} result]
	    if {$rc == 1} {
		return -code $rc -errorinfo $::errorInfo -errorcode $::errorCode $result
	    } elseif {$rc == 3 || $rc == 4} {
		return
	    } 
	}
	$self Destroy
    }
        
    method BooleanColumnsForRow {row} {
	#puts "BooleanColumnsForRow row=$row"
	foreach c $boolColumns {
	    $wtablelist cellconfigure $row,$c  \
	      -window [list $self MakeCheckbutton]
	}
    }
    
    method SetCheckbuttonForRow {row} {
	#puts "SetCheckbuttonForRow row=$row"
	foreach col $boolColumns {
	    set boolVar($row,$col) [lindex $tmpList $row $col]
	    lset tmpList $row $col ""
	    $wtablelist cellconfigure $row,$col -editable 0
	}	    
	#puts "tmpList=$tmpList"
	#parray boolVar
    }

    method MakeCheckbutton {tbl row col w} {
	#puts "MakeCheckbutton $tbl $row $col $w"
	checkbutton $w -highlightthickness 0 -padx 0 -pady 0 -bg white  \
	  -variable [myvar boolVar($row,$col)]
    }
    
    method Destroy {} {
	if {[string length $options(-geovariable)]} {
	    ui::SaveGeometry $win $options(-geovariable)
	}
	destroy $win
    }
    
    # Public methods:

    method add {row} {
	lappend tmpList $row
	set ridx [expr {[llength $tmpList]-1}]
	if {[llength $boolColumns]} {
	    $self BooleanColumnsForRow $ridx
	    $self SetCheckbuttonForRow $ridx
	}
    }
    
    method state {state} {
	$wsave state $state
	$wnew  state $state
	if {[lsearch $state "disabled"] >= 0} {
	    #$wtablelist
	} else {
	    
	}
    }
    
    method boolean {column} {
	lappend boolColumns $column
    }
    
    method wait {{bool 1}} {
	if {$bool} {
	    $wrun start
	} else {
	    $wrun stop
	}
    }

    method grab {} {
	ui::Grab $win
    }
}

proc ::Bookmarks::Nop {args} {}

