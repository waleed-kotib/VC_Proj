# PluginTextPlain.tcl --
#  
#       This file is part of the whiteboard application. 
#       It is an importer for plain text documents.
#       
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: PluginTextPlain.tcl,v 1.5 2003-10-05 13:36:21 matben Exp $


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
    
    set icon12 [image create photo -data {
R0lGODlhDAAMAPYAAP////7+/v7+/fz8/Pv7+/r6+/n5+fj5+Pj4+Pf49/b3
9/b29vIO1fHx8e/w8O7u7u3u7uzt7ejp6efn6Ofn5+Xm5uXl5ePk5NLS083N
zcLCwru7u7i4uLS0s6ysrJuampiYmIaGhmBhYV9gYF9gX15gX15fX11eX11e
Xl1eXV1cXVtdXFlZWVlZV1hYWFhYV1dXV1ZXVVZWVVZVVlRUVFFSUU5PTk1O
S0hJSENCQjw9PDo6OjU2NTExMTAvLy0uLiwsLCgoKCQkJCMiIyEiIiAgIB4e
HwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAwA
LAAAAAAMAAwAAAd4gCIkJywtMDAyHTMMDCMAAQYHCQAyFB2MJQIFmwUANDY4
jCYDBJwAGB+hDCgGR66vADmMKQgKG7e3HDqMKgC+vwAcPowrC0cNr0ccP4wu
Dg8bErgcQowvEBESExUWFxxEGQwwERzl5hxFHhoxNTc7PD1AQUNGISCBADs=
}]
    set icon16 [image create photo -data {
R0lGODlhEAAQAPYAAP////7+/v7+/fz9/fz8/Pz7+/v7+/v6+vr6+/n5+fn4
+Pj5+Pj4+Pf49/f39/b39/b29vX19fT09PP09PP08/Pz8/Lz8/Lz8vLy8vIO
1fHy8vHy8fHx8fHx8O/w8O/v7+7v7+7u7u3u7u3t7ezt7ezs7Ovs6+rr6+rq
6+nr6+nq6enp6ujp6ejo6efn6Ofn5+bm5uXm5uXl5ePk5NLS083NzcLCwru7
u7i4uLS0s7Ozs6ysrJuampiYmJKSkoaGhn9/f3V1dWBhYV9gYF9gX15gX15f
X11eX11eXl1eXV1cXVtdXFtcW1pbW1paWllZWVlZV1hYWFhYV1dXV1ZXVVZW
VVZVVlRUVFFSUU5PTk1OS0hJSEhJR0NEQ0NCQj8/Pjw9PDo6OjU2NTExMTAv
Ly0uLiwsLCwsKykpKigoKCcnKCUlJiQkJCMiIyEiIiAgIB4eHwAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAABkA
LAAAAAAQABAAAAfIgEJER0lMTU9QU1VWNRmOGUMAAQMFBwkLDVU5jI9FAgig
oQhVL5uPRgQGoqBXWVtej0gICQoOoBIVNDw8sI5JCXHBEcHEOGCPSgwPN8wX
zMw4ZI9LEBESFBgcHiAiJThlj0zDcRrExWePTRMWzB/P0GiPThgb2yIjJikq
LThqj08dzJ2IsyIYjjWPongI8Y7FDRg3cLDR0UiKCBIlUKxg4SKGjBk43PjY
YWMKCRwoU6p8E+RHDypYtHDp8iWMmDFm0rSBA8SHjkAAOw==
}]
    
    
    # This defines the properties of the plugin.
    set defList [list \
      pack        TextImporter                 \
      desc        "Text importer plugin"       \
      ver         0.1                          \
      platform    {macintosh   macosx    windows   unix} \
      importProc  ::TextImporter::Import       \
      mimes       {text/plain}                 \
      winClass    TextDocFrame                 \
      saveProc    ::TextImporter::Save         \
      icon,12     $icon12                      \
      icon,16     $icon16                      \
    ]
  
    # These are generic bindings for a framed thing. $wcan will point
    # to the canvas and %W to the actual frame widget.
    # You may write your own. Tool button names are:
    #   point, move, line, arrow, rect, oval, text, del, pen, brush, paint,
    #   poly, arc, rot.
    # Only few of these are relevant for plugins.
    
    set bindList {\
      move    {{bind TextDocFrame <Button-1>}         {::CanvasDraw::InitMoveWindow $wcan %W %x %y}} \
      move    {{bind TextDocFrame <B1-Motion>}        {::CanvasDraw::DoMoveWindow $wcan %W %x %y}}   \
      move    {{bind TextDocFrame <ButtonRelease-1>}  {::CanvasDraw::FinMoveWindow $wcan %W %x %y}}  \
      move    {{bind TextDocFrame <Shift-B1-Motion>}  {::CanvasDraw::FinMoveWindow $wcan %W %x %y}}  \
      del     {{bind TextDocFrame <Button-1>}         {::CanvasDraw::DeleteWindow $wcan %W %x %y}}   \
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
#       wcan        canvas widget path
#       optListVar  the *name* of the optList variable.
#       args
#       
# Results:
#       an error string which is empty if things went ok so far.

proc ::TextImporter::Import {wcan optListVar args} {
    upvar $optListVar optList
    variable uid
    variable locals
    
    array set argsArr $args
    array set optArr $optList
    if {![info exists argsArr(-file)] && ![info exists argsArr(-data)]} {
	return -code error "Missing both -file and -data options"
    }
    if {[info exists argsArr(-data)]} {
	return -code error "Does not yet support -data option"
    }
    set fileName $argsArr(-file)
    set wtop [::UI::GetToplevelNS $wcan]
    set errMsg ""
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(-coords) break
    if {[info exists optArr(-tags)]} {
	set useTag $optArr(-tags)
    } else {
	set useTag [::CanvasUtils::NewUtag]
    }
    set uniqueName [::CanvasUtils::UniqueImageName]		
    set wfr ${wcan}.fr_${uniqueName}    
    
    # Make actual object in a frame with special -class.
    frame $wfr -bg gray50 -class TextDocFrame
    label $wfr.icon -background white -image $locals(icon)
    pack $wfr.icon -padx 4 -pady 4
    
    set id [$wcan create window $x $y -anchor nw -window $wfr -tags  \
      [list frame $useTag]]
    set locals(id2file,$id) $fileName
    
    # Need explicit permanent storage for import options.
    ::CanvasUtils::ItemSet $wtop $useTag -file $fileName
    
    bind $wfr.icon <Double-Button-1> [list [namespace current]::Clicked $id]

    # We may let remote clients know our size.
    lappend optList -width [winfo reqwidth $wfr] -height [winfo reqheight $wfr]

    set msg "Plain text: [file tail $fileName]"
    ::balloonhelp::balloonforwindow $wfr.icon $msg
    
    # Success.
    return $errMsg
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

    set win .ty7588[incr locals(wuid)]
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
	unset data
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
