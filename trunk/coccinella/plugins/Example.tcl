# Example.tcl --
#  
#       This file is part of the whiteboard application. It is an example
#       template for the plugin structure. See also lib/Plugins.tcl.
#
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Example.tcl,v 1.1 2003-05-18 13:04:13 matben Exp $


namespace eval ::Example:: {
    
    # Local storage: unique running identifier.
    variable uid 0
    variable locals
    set locals(wuid) 0
}

# Example::Init --
# 
#       This is called from '::Plugins::Load' and is defined in the file 
#       'pluginDefs.tcl' in this directory.

proc ::Example::Init { } {
    
    # This defines the properties of the plugin.
    set defList {\
      pack        Example                 \
      desc        "Example dummy plugin"  \
      platform    {macintosh   macosx    windows   unix} \
      importProc  ::Example::Import       \
      mimes       {application/x-junk}    \
      winClass    ExampleFrame            \
      saveProc    ::Example::Save         \
    }
  
    # These are generic bindings for a framed thing. $wcan will point
    # to the canvas and %W to the actual frame widget.
    # You may write your own. Tool button names are:
    #   point, move, line, arrow, rect, oval, text, del, pen, brush, paint,
    #   poly, arc, rot.
    # Only few of these are relevant for plugins.
    
    set bindList {\
      move    {{bind ExampleFrame <Button-1>}         {::CanvasDraw::InitMoveFrame $wcan %W %x %y}} \
      move    {{bind ExampleFrame <B1-Motion>}        {::CanvasDraw::DoMoveFrame $wcan %W %x %y}} \
      move    {{bind ExampleFrame <ButtonRelease-1>}  {::CanvasDraw::FinMoveFrame $wcan %W %x %y}} \
      move    {{bind ExampleFrame <Shift-B1-Motion>}  {::CanvasDraw::FinMoveFrame $wcan %W %x %y}} \
      del     {{bind ExampleFrame <Button-1>}         {::CanvasDraw::DeleteFrame $wcan %W %x %y}} \
    }
  
    # Register the plugin with the applications plugin mechanism.
    # Any 'package require' must have been done before this.
    ::Plugins::Register Example $defList $bindList
    
    # Register nonsense mime type for this.
    ::Types::NewMimeType "application/x-junk" "Junk File" {.junk} 0 {TEXT}
}

# Example::Import --
#
#       Template import procedure.
#       
# Arguments:
#
#       
# Results:
#       an error string which is empty if things went ok so far.

proc ::Example::Import {wtop fileName optList args} {
    upvar ::${wtop}::wapp wapp
    variable uid
    variable locals
    
    array set argsArr $args
    array set optArr $optList
    set wCan $wapp(can)
    set locals(file) $fileName    
    if {![catch {open $locals(file) r} fd]} {
	set locals(body) [read $fd]
	close $fd
    }
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(coords:) { break }
    if {[info exists optArr(tags:)]} {
	set useTag $optArr(tags:)
    } else {
	set useTag [::CanvasUtils::NewUtag]
    }
    set uniqueName [::CanvasUtils::UniqueImageName]		
    set wfr ${wCan}.fr_${uniqueName}    
    
    # Make actual object in a frame with special -class.
    frame $wfr -bg gray50 -class ExampleFrame
    button ${wfr}.bt -text {Example Plugin} -command [namespace current]::Clicked
    pack ${wfr}.bt -padx 3 -pady 3
    
    set id [$wCan create window $x $y -anchor nw -window $wfr -tags [list tframe $useTag]]
    set locals(id2file,$id) $fileName
    
    # Success.
    return ""
}

# ::Example::Save --
# 
#       Template proc for saving an 'import' command to file.
#       Return empty of failure.

proc ::Example::Save {wCan id} {
    variable locals
    
    ::Debug 2 "::Example::Save wCan=$wCan, id=$id"

    if {[info exists locals(id2file,$id)]} {
	lappend impArgs -file $locals(id2file,$id)
	lappend impArgs -tags [::CanvasUtils::GetUtag $wCan $id 1]
	return "import [$wCan coords $id] $impArgs"
    } else {
	return ""
    }
}

proc ::Example::Clicked { } {
    global sysFont
    variable locals

    set win .ty7532[incr locals(wuid)]
    toplevel $win
    wm title $win "Example Plugin:"
    pack [frame ${win}.f -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    if {[info exists locals(file)]} {
	set txt "The content of the imported file: [file tail $locals(file)]"
    } else {
	set txt "The content of the imported file: none"
    }
    pack [label ${win}.f.la -text $txt -font $sysFont(sb)]  \
      -side top -anchor w -padx 12 -pady 6
    pack [frame ${win}.f.fr] -side top -fill both -expand 1
    set wtext ${win}.f.fr.t
    set wysc ${win}.f.fr.ysc
    pack [text $wtext -width 80 -height 30 -yscrollcommand [list $wysc set] \
      -font $sysFont(s)] -side left -fill both -expand 1
    pack [scrollbar $wysc -orient vertical -command [list $wtext yview]] \
      -side right -fill y
    
    if {[info exists locals(body)]} {
	$wtext insert 1.0 $locals(body)
    }
    
    pack [button ${win}.f.bt -text Close -command [list destroy $win]] \
      -side bottom -anchor e -padx 12 -pady 8
}

#-------------------------------------------------------------------------------
