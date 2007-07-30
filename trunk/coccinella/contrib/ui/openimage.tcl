# openimage.tcl --
# 
#   Implements an Open Image dialog.
#
# Copyright (c) 2007 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: openimage.tcl,v 1.1 2007-07-30 08:16:02 matben Exp $

package require snit 1.0
package require tile
package require msgcat
package require ui::util

package provide ui::openimage 0.1

namespace eval ui::openimage {


}

interp alias {} ui::openimage {} ui::openimage::widget

# Tested using snit::widgetadaptor on ui::dialog::widget but fails in destructor.
# 
# snit::widgetadaptor ui::openimage::widget {
#    delegate option * to hull
#    delegate method * to hull
#    constructor {args} {
#	installhull using ui::dialog::widget
#	$self configurelist $args
#    }
# }

proc ui::openimage::widget {w args} {    
    upvar 0 $w state
    variable $w
    
    set filetypes [list [list [::msgcat::mc {Image Files}] {.gif}]]
        
    set state(-defaultfile) [ui::from args -defaultfile]
    set state(-filetypes)   [ui::from args -filetypes $filetypes]
    set state(-initialfile) [ui::from args -initialfile]
    set state(-size)        [ui::from args -size 128]
    
    # To be garbage collected.
    set state(imagecache) [list]
    
    set size $state(-size)

    eval {ui::dialog::widget $w -type okcancel -icon ""} $args
    
    set fr [$w clientframe]
    ttk::frame $fr.l

    # Bug in 8.4.1 but ok in 8.4.9
    if {[regexp {^8\.4\.[0-5]$} [info patchlevel]]} {
	label $fr.l.image -relief sunken -bd 1 -bg white
    } else {
	ttk::label $fr.l.image -style Sunken.TLabel -compound image
    }
    grid  $fr.l.image  -sticky news
    grid columnconfigure $fr.l 0 -minsize [expr {2*4 + 2*4 + $size}]
    grid rowconfigure    $fr.l 0 -minsize [expr {2*4 + 2*4 + $size}]

    ttk::frame $fr.r
    ttk::button $fr.r.new -style Small.TButton \
      -command [namespace code [list New $w]] -text [msgcat::mc New]
    ttk::button $fr.r.rem -style Small.TButton \
      -command [namespace code [list Remove $w]] -text [msgcat::mc Remove]
    ttk::button $fr.r.def -style Small.TButton \
      -command [namespace code [list Default $w]] -text [msgcat::mc Default]

    grid  $fr.r.new  -padx 8 -pady 2 -sticky ew
    grid  $fr.r.rem  -padx 8 -pady 2 -sticky ew
    grid  $fr.r.def  -padx 8 -pady 2 -sticky ew

    grid rowconfigure $fr.r 0 -weight 1
    grid rowconfigure $fr.r 1 -weight 1
    grid rowconfigure $fr.r 2 -weight 1

    grid  $fr.l  $fr.r
    grid $fr.r  -sticky news

    set state(wimage) $fr.l.image
    set state(wnew)   $fr.r.new
    set state(wrem)   $fr.r.rem
    set state(wdef)   $fr.r.def
    
    if {[file exists $state(-initialfile)]} {
	set image [image create photo -file $state(-initialfile)]
	set new [::ui::image::scale $image $state(-size)]
	lappend state(imagecache) $new
	$state(wimage) configure -image $new    
    }
    if {![file exists $state(-defaultfile)]} {
	$fr.r.def state {disabled}
    }
    bind $w <Destroy> \
      [subst { if {"%W" eq "$w"} { ui::openimage::destructor "$w" } }]
    return $w
}

proc ui::openimage::New {w} {
    upvar 0 $w state
    variable $w

    set fileName [tk_getOpenFile -title [::msgcat::mc {Pick Image File}] \
      -filetypes $state(-filetypes)]
    if {[file exists $fileName]} {
	set image [image create photo -file $fileName]
	set new [::ui::image::scale $image $state(-size)]
	lappend state(imagecache) $new
	$state(wimage) configure -image $new    
    }
}

proc ui::openimage::Remove {w} {
    upvar 0 $w state
    variable $w

    $state(wimage) configure -image ""
}

proc ui::openimage::Default {w} {
    upvar 0 $w state
    variable $w

}

proc ui::openimage::destructor {w} {
    upvar 0 $w state
    variable $w
  
    eval {image delete} $state(imagecache)
    unset -nocomplain state
}

if {0} {
    # Test:
    set str "Select an image file for the roster background."
    set mimeL {image/gif image/png image/jpeg}
    set suffL [::Types::GetSuffixListForMimeList $mimeL]
    set types [concat [list [list {Image Files} $suffL]] \
      [::Media::GetDlgFileTypesForMimeList $mimeL]]

    ui::openimage .mnb -message $str -filetypes $types \
      -initialfile /Users/matben/Docs/code/oil/20060211-173572-4.jpg \
      -defaultfile /Users/matben/Docs/code/oil/20060211-173572-4.jpg
    
    
}

