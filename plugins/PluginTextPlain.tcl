# PluginTextPlain.tcl --
#  
#       This file is part of the whiteboard application. 
#       It is an importer for plain text documents.
#       
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: PluginTextPlain.tcl,v 1.1 2003-07-05 13:31:50 matben Exp $


namespace eval ::TextImporter:: {
    
    # Local storage: unique running identifier.
    variable uid 0
    variable locals
    set locals(wuid) 0
}

# TextImporter::Init --
# 
#       This is called from '::Plugins::Load' and is defined in the file 
#       'pluginDefs.tcl' in this directory.

proc ::TextImporter::Init { } {
    variable locals
    
    # This defines the properties of the plugin.
    set defList {\
      pack        TextImporter                 \
      desc        "Text importer plugin"  \
      platform    {macintosh   macosx    windows   unix} \
      importProc  ::TextImporter::Import       \
      mimes       {text/plain}    \
      winClass    TextDocFrame            \
      saveProc    ::TextImporter::Save         \
    }
  
    # These are generic bindings for a framed thing. $wcan will point
    # to the canvas and %W to the actual frame widget.
    # You may write your own. Tool button names are:
    #   point, move, line, arrow, rect, oval, text, del, pen, brush, paint,
    #   poly, arc, rot.
    # Only few of these are relevant for plugins.
    
    set bindList {\
      move    {{bind TextDocFrame <Button-1>}         {::CanvasDraw::InitMoveFrame $wcan %W %x %y}} \
      move    {{bind TextDocFrame <B1-Motion>}        {::CanvasDraw::DoMoveFrame $wcan %W %x %y}} \
      move    {{bind TextDocFrame <ButtonRelease-1>}  {::CanvasDraw::FinMoveFrame $wcan %W %x %y}} \
      move    {{bind TextDocFrame <Shift-B1-Motion>}  {::CanvasDraw::FinMoveFrame $wcan %W %x %y}} \
      del     {{bind TextDocFrame <Button-1>}         {::CanvasDraw::DeleteFrame $wcan %W %x %y}} \
    }
  
    set locals(icon) [image create photo -data {
R0lGODlhIAAgAPMAAP//////zP//mf//Zv//M///AOMKwszMmZmZZnd3d2Zm
MwAAAAAAAAAAAAAAAAAAACH5BAEAAAYALAAAAAAgACAAAATi0MhJq7046827
/yC1LCG3AMBYYicKBCO5Sm3w3urauvybf7Vb4GArpmSmHuqgRMGQLKdQYWMO
jbZfJVikAqxEoVBr4L4QNsTLC8bCJiNxwKtYV1/h4pu2KIwCgIFUAWiEgIOB
MAmLMQV+f4lzh5ORI4sSCSOPj5GSnokLBwcLCROZjY8LAqsDqwirsAKhBwOW
pgsImrqqrLGrs5aXtwi5mqkDyMm1o6SlF5kHxCME09ME1zHCGdDRxX2pj9ob
mQOi0n264h3k5d0xzSvsyJbwM+TBi84zBpna+vv8AAocSHBfBAA7
}]
  
    # Register the plugin with the applications plugin mechanism.
    # Any 'package require' must have been done before this.
    ::Plugins::Register TextImporter $defList $bindList
}

# TextImporter::Import --
#
#       Import procedure for text.
#       
# Arguments:
#       wtop
#       fileName
#       optListVar  the *name* of the optList variable.
#       args
#       
# Results:
#       an error string which is empty if things went ok so far.

proc ::TextImporter::Import {wtop fileName optListVar args} {
    upvar $optListVar optList
    upvar ::${wtop}::wapp wapp
    variable uid
    variable locals
    
    array set argsArr $args
    array set optArr $optList
    set wCan $wapp(can)
    
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
    frame $wfr -bg gray50 -class TextDocFrame
    label $wfr.icon -background white -image $locals(icon)
    pack $wfr.icon -padx 3 -pady 3
    
    set id [$wCan create window $x $y -anchor nw -window $wfr -tags  \
      [list tframe $useTag]]
    set locals(id2file,$id) $fileName
    bind $wfr.icon <Double-Button-1> [list [namespace current]::Clicked $id]

    # We may let remote clients know our size.
    lappend optList "width:" [winfo reqwidth $wfr] "height:" [winfo reqheight $wfr]

    set msg "Plain text: [file tail $fileName]"
    ::balloonhelp::balloonforwindow $wfr.icon $msg
    
    # Success.
    return ""
}

# ::TextImporter::Save --
# 
#       Template proc for saving an 'import' command to file.
#       Return empty if failure.

proc ::TextImporter::Save {wCan id args} {
    variable locals
    
    ::Debug 2 "::TextImporter::Save wCan=$wCan, id=$id, args=$args"
    array set argsArr {
	-uritype file
    }
    array set argsArr $args

    if {[info exists locals(id2file,$id)]} {
	set fileName $locals(id2file,$id)
	if {$argsArr(-uritype) == "http"} {
	    lappend impArgs -url [::CanvasUtils::GetHttpFromFile $fileName]
	} else {
	    lappend impArgs -file $fileName
	}
	lappend impArgs -tags [::CanvasUtils::GetUtag $wCan $id 1]
	return "import [$wCan coords $id] $impArgs"
    } else {
	return ""
    }
}

proc ::TextImporter::Clicked {id} {
    global sysFont
    variable locals

    set win .ty7532[incr locals(wuid)]
    toplevel $win
    wm title $win "Plain Text Browser"
    pack [frame ${win}.f -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    set txt "The content of the text file: [file tail $locals(id2file,$id)]"
    pack [label ${win}.f.la -text $txt -font $sysFont(sb)]  \
      -side top -anchor w -padx 12 -pady 6
    
    # Button part.
    set frbot [frame ${win}.f.frbot -borderwidth 0]
    pack [button $frbot.btset -text [::msgcat::mc {Save As}] -width 8 \
      -command [list [namespace current]::SaveAs $id]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Close] -width 8  \
      -command [list destroy $win]] \
      -side right -padx 5 -pady 5
    pack $frbot -side bottom -fill both -expand 1 -padx 8 -pady 6
        
    pack [frame ${win}.f.fr -relief sunken -bd 1] -side top -fill both -expand 1
    set wtext ${win}.f.fr.t
    set wysc ${win}.f.fr.ysc
    pack [scrollbar $wysc -orient vertical -command [list $wtext yview]] \
      -side right -fill y
    pack [text $wtext -width 80 -height 30 -yscrollcommand [list $wysc set] \
      -font $sysFont(s)] -side left -fill both -expand 1
    
    if {![catch {open $locals(id2file,$id) r} fd]} {
	set data [read $fd]
	$wtext insert 1.0 $data
	close $fd
    }
}

proc ::TextImporter::SaveAs {id} {
    variable locals
    
    set ans [tk_getSaveFile]
    if {$ans == ""} {
	return
    }
    if {[catch {file copy $locals(id2file,$id) $ans} err]} {
	tk_messageBox -type ok -icon error -message \
	  "Failed copying file: $err"
	return
    }
}

#-------------------------------------------------------------------------------
