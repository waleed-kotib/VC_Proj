# openimage.tcl --
# 
#   Implements an Open Image dialog.
#
# Copyright (c) 2007 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: openimage.tcl,v 1.7 2008-05-05 14:22:28 matben Exp $

# Public commands:
# 
#   ui::openimage w ?args?
#   ui::openimage::modal ?args?
#   
# @@@ Add support for dnd

package require snit 1.0
package require msgcat
package require ui::util

package provide ui::openimage 0.1

namespace eval ui::openimage {

    variable fileNameModal ""
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

# ui::openimage::widget --
# 
#       Implements a simple open image widget which can act as a preference
#       dialog. Built on top of ui::dialog.
#       
# Arguments:
#       w           widgetPath
#       args:       all from ui::dialog and
#         -defaultfile  fileName
#         -filetypes    for tk_getOpenFile
#         -initialfile  fileName
#         -size         integer
#                       
# Results:
#       widgetPath

proc ui::openimage::widget {w args} {    
    upvar 0 $w state
    variable $w
    
    set filetypes [list [list [::msgcat::mc {Image Files}] {.gif}]]
        
    # We must hijack the -command if any and use our own.
    set state(-command)     [ui::from args -command]
    set state(-defaultfile) [ui::from args -defaultfile]
    set state(-filetypes)   [ui::from args -filetypes $filetypes]
    set state(-initialfile) [ui::from args -initialfile]
    set state(-size)        [ui::from args -size 128]
    
    # To be garbage collected.
    set state(imagecache) [list]
    set state(fileName) ""
    set state(image)  ""
    set state(scaled) ""
    set state(maxsize) 0
    
    set size $state(-size)

    eval {ui::dialog::widget $w -type okcancel -icon "" \
      -command [namespace code Cmd]} $args
    
    set fr [$w clientframe]
    ttk::frame $fr.l
    ttk::label $fr.l.image -compound image

    grid  $fr.l.image  -sticky news
    grid columnconfigure $fr.l 0 -minsize [expr {2*4 + 2*4 + $size}]
    grid rowconfigure    $fr.l 0 -minsize [expr {2*4 + 2*4 + $size}]

    ttk::frame $fr.r
    ttk::button $fr.r.new \
      -command [namespace code [list New $w]] -text "[::msgcat::mc {Open Image}]..."
    ttk::button $fr.r.rem \
      -command [namespace code [list Remove $w]] -text [::msgcat::mc Clear]
    ttk::button $fr.r.def \
      -command [namespace code [list Default $w]] -text [::msgcat::mc Default]

    grid  $fr.r.new  -pady 2 -sticky ew
    grid  $fr.r.rem  -pady 2 -sticky ew
    grid  $fr.r.def  -pady 2 -sticky ew

    grid rowconfigure $fr.r 0 -weight 1
    grid rowconfigure $fr.r 1 -weight 1
    grid rowconfigure $fr.r 2 -weight 1

    grid  $fr.l  $fr.r  -padx 6
    grid $fr.r  -sticky news

    set state(wimage) $fr.l.image
    set state(wnew)   $fr.r.new
    set state(wrem)   $fr.r.rem
    set state(wdef)   $fr.r.def
    set state(wballoon) $w.ball
    
    if {[file exists $state(-initialfile)]} {
	PutImageFile $w $state(-initialfile)
	Binds $w
    }
    if {![file exists $state(-defaultfile)]} {
	$fr.r.def state {disabled}
    }
    bind $fr.r.new <Map> { focus %W }
    bind $w <Destroy> \
      [subst { if {"%W" eq "$w"} { ui::openimage::destructor "$w" } }]
    return $w
}

proc ui::openimage::PutImageFile {w fileName} {
    upvar 0 $w state
    variable $w
    
    if {[file exists $fileName]} {
	set state(fileName) $fileName
	set image [image create photo -file $fileName]
	set new [::ui::image::scale $image $state(-size)]
	set state(image)  $image
	set state(scaled) $new
	set W [image width $image]
	set H [image height $image]
	set state(maxsize) [expr {$W > $H ? $W : $H}]
	lappend state(imagecache) $image $new
	$state(wimage) configure -image $new    
    }
}

proc ui::openimage::New {w} {
    upvar 0 $w state
    variable $w

    set fileName [tk_getOpenFile -title [::msgcat::mc "Open Image"] \
      -filetypes $state(-filetypes)]
    if {[file exists $fileName]} {
	PutImageFile $w $fileName
	Binds $w
    }
}

proc ui::openimage::Remove {w} {
    upvar 0 $w state
    variable $w

    set state(fileName) "-"
    set state(image)  ""
    set state(scaled) ""
    set state(maxsize) 0
    $state(wimage) configure -image ""
    Binds $w
}

proc ui::openimage::Default {w} {
    upvar 0 $w state
    variable $w

    if {[file exists $state(-defaultfile)]} {
	PutImageFile $w $state(-defaultfile)
	Binds $w
    }
}

proc ui::openimage::Binds {w} {
    upvar 0 $w state
    variable $w
    
    set wimage $state(wimage)
    if {($state(image) ne "") && ($state(maxsize) > $state(-size))} {
	bind $wimage <Button-1> [namespace code [list Balloon $w 1]]
	bind $wimage <Leave>    [namespace code [list Balloon $w 0]]
    } else {
	bind $wimage <Button-1> {}
	bind $wimage <Leave> {}
    }   
}

proc ::ui::openimage::Balloon {w show} {
    upvar 0 $w state
    variable $w
    
    set win $state(wballoon)
    if {![winfo exists $win]} {
	toplevel $win -bd 0 -relief flat
	wm overrideredirect $win 1
	wm transient $win
	wm withdraw  $win
	wm resizable $win 0 0 
	
	if {[tk windowingsystem] eq "aqua"} {
	    tk::unsupported::MacWindowStyle style $win help none
	}
	pack [label $win.l -bd 0 -bg white -compound none]
    }
    if {$show} {
	set wimage $state(wimage)
	$win.l configure -image $state(image)
	update idletasks
	set W [image width $state(image)]
	set H [image height $state(image)]
	set x [expr {[winfo rootx $wimage] + [winfo height $wimage]/2 -$W/2}]
	set y [expr {[winfo rooty $wimage] + [winfo height $wimage]}]
	wm geometry $win +${x}+${y}
	wm deiconify $win
    } else {
	wm withdraw $win
    }
}

proc ui::openimage::Cmd {w bt} {
    upvar 0 $w state
    variable $w
    
    # We must have a way to differentiate between cancel and remove.
    #   cancel: ""
    #   remove: "-"
    if {$bt ne "ok"} {
	set state(fileName) ""
    } elseif {![file exists $state(fileName)]} {
	set state(fileName) "-"	
    }
    if {$state(-command) ne {}} {
	set rc [catch [linsert $state(-command) end $state(fileName)] result]
	if {$rc == 1} {
	    return -code $rc -errorinfo $::errorInfo -errorcode $::errorCode $result
	} elseif {$rc == 3 || $rc == 4} {
	    # break or continue -- don't dismiss dialog
	    return
	} 
    }
}

proc ui::openimage::destructor {w} {
    upvar 0 $w state
    variable $w
  
    eval {image delete} $state(imagecache)
    unset -nocomplain state
}

proc ui::openimage::ModalCmd {fileName} {
    variable fileNameModal
    set fileNameModal $fileName
}

# ui::openimage::modal --
# 
#       As ui::openimage but it is a modal dialog and returns any selected
#       file name.

proc ui::openimage::modal {args} {
    variable fileNameModal
 
    set w [ui::autoname]
    ui::from args -modal
    ui::from args -command
    eval {widget $w -modal 1 -command [namespace code ModalCmd]} $args
    ui::Grab $w
    return $fileNameModal
}

if {0} {
    # Test:
    
    package require ui::openimage
    set str "Select an image file for the roster background."
    set str2 "The supported formats are GIF, PNG, and JPEG."
    set mimeL {image/gif image/png image/jpeg}
    set suffL [::Types::GetSuffixListForMimeList $mimeL]
    set types [concat [list [list {Image Files} $suffL]] \
      [::Media::GetDlgFileTypesForMimeList $mimeL]]
    proc cmd {fileName} {puts "---> $fileName"}

    ui::openimage .mnb -message $str -detail $str2 -filetypes $types \
      -command cmd \
      -initialfile /Users/matben/Docs/code/oil/20060211-173572-4.jpg \
      -defaultfile /Users/matben/Graphics/Avatars/boy_avatar_lnx/Icons/128X128/boy_1.png
    
    ui::openimage::modal -message $str -detail $str2 -filetypes $types \
      -initialfile /Users/matben/Tcl/cvs/coccinella/images/cociexec.gif \
      -defaultfile /Users/matben/Graphics/Avatars/boy_avatar_lnx/Icons/128X128/boy_1.png
    
}

