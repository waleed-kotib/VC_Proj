# HtmlImport.tcl --
#  
#       This file is part of the whiteboard application. 
#       It is an importer for html documents.
#       
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: HtmlImport.tcl,v 1.1 2003-10-05 13:42:29 matben Exp $


namespace eval ::HtmlImport:: {
    
    # Local storage: unique running identifier.
    variable uid 0
    variable locals
    set locals(wuid) 0
}

# HtmlImport::Init --
# 
#       This is called from '::Plugins::Load' and is defined in the file 
#       'pluginDefs.tcl' in this directory.

proc ::HtmlImport::Init { } {
    global  tcl_platform
    variable locals
            
    set locals(docim) [image create photo -data {
R0lGODdhIAAgAOYAAP////395f395P394/394v394f383/383vz83fz83Pz8
2/z82fz82Pz81/z81vz71fz71Pz70/z70vz70fz70Pz7z/z7zvv7zfv7zPv7
y/v6y/v6yvv6yfv6yPv6x/v6xvv6xfv6xPv6w/v6wvv6wfv6wPv6v/v6vvv6
vfv6vPv6u/v6uvv6ufv6uPv6t/v6tvv6tPv6s/v6svv6sfv6sPv6r/v6rvv6
rPv6q/v6qvv6qfv6qPv6p/v6pvr5pfn4pPj3pPj3o/f2ovb1ofX0ofTzn/Hw
nfDvnPDvm+7tmezrmOvql+rplunoldfW1sLCwkxMTAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAIAAg
AAAH/4AAglGEhYaHiIdPToKDAo8BkZICBw8XHR4fmpubUYuNAFGSo5EDCREZ
HZyrH56MjaKRULO0sxUctB9QuruarqCxpAIEChIYmKycv7CkAcMJEBccmcmd
n8yyUAK1s7q8u72+14Ojzw8WG9TV1q/kkgQIDujq6+LtoZK1G7n8tezAkQQY
YEAhXT1Wy8gJKLBgggZkBzeBSIivgAJaHrhp8tcNhAiKUeBFmxZRoogSIA/I
M1jyA4gQJFSAbEBBA5SM3TiCozUCBQyQDiGW9HjihQ2Qx+gd9FiCBQ0dIEnm
3NmvlgwcPEAqrfcyZgysPUC2dAkzBYwbO3qEHRdqk79vtXdG0EqrVuxQESZa
1NChti7bKENDlFgxIwePvj7s8voGF0oKKDdo9fABRHG1lz2N0u3x4wcRy8k8
mnCx97Baz0cUU4VLuFYPKEOMKAG9yqPPG6bVBimShAltiTBZ7O07WYjsJr81
vTTxAjdxH0OQLEH+N5H1678CAQA7
}]
        
    set icon12 [image create photo -data {
R0lGODlhDAAMAPYAAPYOyLrG07O+y7LAzpvF8JqvxJmtwpKxy4uht4qguImp
yoSjwYOs1IG47X+r1H+p0n+jyX6gwnuewnqmznecwHSj0HSZvnKj1nGj1W6c
y26axW2czGye0WyXwWmOs2mOsmSQu2OXzGGm516OvlyPwVyLtlmZ2lmW0VeY
1lCd2k+Pwk2U10qAtkmKykSBvkOV30KQ2z+Q4j+Avz55sjt6uTmH0Dh8wTaP
4DN8xDKC0jFysy6J5Cd+1SZvtyR+1iR0xSNorh9ruBp20RZ/5xZy0BV11RVu
xRRqvhNz0xJtyRJtxhJeqRF33hFqwRFpwg9syQ523g5wzwx33wtqxwtlvQpd
sARu2gRs1QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAA
LAAAAAAMAAwAAAdvgACCg4IBBQiEAA0mLTMJiQApOERTVEsfhColOScjPU1V
C4IeBy8sghNOUTKCAyJCPzYrNUlDPIIEPkUxISQgGhgVgjBGSC6DDhuDQEFP
RzQoN1JQEAAZEQY6SldWTDsPghIUgh0cFwwChBYKkIOBADs=
}]

    set icon16 [image create photo -data {
R0lGODlhEAAQAPcAAP////YOyOLq8ODr8+Dg4N/i5N3d3dzd3dra2tTV1tTU
1NPT09Lm8NLS0tDU2dDR0c/Z3c7V3MzS2MzR1srS2snLzsfQ2sfJzMXHycTN
1cPM1MDT5b3BxbnL3bnJ2bnEz7m/w7fCzbe/x7XE0rHj/au+0au6yKu1v6rD
3anI56nF4Ka3x6a1w6W5zZ7K9J672ZyuwZq52Jqwx5qqu4qnxoiw2Yiiuoic
sIeft4ax3IXJ94PV+YOgvoGYrn6YsnuYtHq15HqfxHCJoGycy2Wt42Kr5mKR
v2GPu1+Js1yJtlel81J9qE+n7k+Kx06l706NzEuR1kt2oUp+s0p9r0md4UeI
ykWP2UWIy0WFxESHykOAvEKM1kF6s0CX7UB9ukB5sj55sjx5tjtyqzqO5DqC
yTpwpjeN4Dd3tzZ9xTWL4DOJ2zN9vTNrpDF+zC+E2Sx0vCuB0yp+0ih90CaA
3CZ4yiWP+SWP+CSN9SSK7yKH7SJ60iJ0xyGI8CF3zCF1yCFywiFdlh+B4R9k
px9fnh6D5h593R551R5yxR172h172Rx93Rx61hx30Rx2zxxsvRt83Rt52Bt3
0Rt20Rt20BtzyhtwxRtwxBp52Bp31Bp0zxp0zRpzzBpwxRpvwhppthpmshl3
1hlxyBlwxxlvxRluwRltwRhvxhhrvRhotxhntxhkrxhjrhhhrBduxBdnuBdd
ohZqvRZntxVirhRpvRJfrAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAAQABAAAAjEAAMIHEgwgAwe
PnoUFJgiR40hNhYO1OFkTJw/nl5FkbiDipQzhhhRIiULUMEia4SgwUMmzKpT
nGKxGahiEAgien4M/FQp1CwYApdwAGIm1Y2BbSwtupRk4IsufjKNQgVHTSdM
hO5gGahETqM8VrJ4AcNFSxUoRwS6SHMo0iOJBLc44jTJVJmBTPaUAjVDICsx
sERpcqWKjps+gew0ERjjTQAktFpJSoSoEJ86TwbS+DJwyiZIiuZcwVFQEFyJ
K4wEOT0wIAA7
}]

    # This defines the properties of the plugin.
    set defList [list \
      pack        HtmlImport                       \
      desc        "Html Importer"                  \
      ver         0.1                              \
      platform    {unix windows macintosh macosx}  \
      importProc  ::HtmlImport::Import             \
      mimes       {text/html}                      \
      winClass    HtmlDocFrame                     \
      saveProc    ::HtmlImport::Save               \
      icon,12     $icon12                          \
      icon,16     $icon16                          \
    ]
  
    # These are generic bindings for a framed thing. $wcan will point
    # to the canvas and %W to the actual frame widget.
    # You may write your own. Tool button names are:
    #   point, move, line, arrow, rect, oval, text, del, pen, brush, paint,
    #   poly, arc, rot.
    # Only few of these are relevant for plugins.
    
    set bindList {\
      move    {{bind HtmlDocFrame <Button-1>}         {::CanvasDraw::InitMoveWindow $wcan %W %x %y}} \
      move    {{bind HtmlDocFrame <B1-Motion>}        {::CanvasDraw::DoMoveWindow $wcan %W %x %y}} \
      move    {{bind HtmlDocFrame <ButtonRelease-1>}  {::CanvasDraw::FinMoveWindow $wcan %W %x %y}} \
      move    {{bind HtmlDocFrame <Shift-B1-Motion>}  {::CanvasDraw::FinMoveWindow $wcan %W %x %y}} \
      del     {{bind HtmlDocFrame <Button-1>}         {::CanvasDraw::DeleteWindow $wcan %W %x %y}} \
    }
    
    # Register the plugin with the applications plugin mechanism.
    # Any 'package require' must have been done before this.
    ::Plugins::Register HtmlImport $defList $bindList
}

# HtmlImport::Import --
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

proc ::HtmlImport::Import {wcan optListVar args} {
    global  tcl_platform
    
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
    frame $wfr -bg gray50 -class HtmlDocFrame
    label ${wfr}.icon -bg white -image $locals(docim)
    pack ${wfr}.icon -padx 4 -pady 4
    
    set id [$wcan create window $x $y -anchor nw -window $wfr -tags  \
      [list frame $useTag]]
    set locals(id2file,$id) $fileName
    
    # Need explicit permanent storage for import options.
    ::CanvasUtils::ItemSet $wtop $useTag -file $fileName
    
    bind $wfr.icon <Double-Button-1> [list [namespace current]::Clicked $id]

    # We may let remote clients know our size.
    lappend optList -width [winfo reqwidth $wfr] -height [winfo reqheight $wfr]

    set msg "Html document: [file tail $fileName]"
    ::balloonhelp::balloonforwindow ${wfr}.icon $msg
    
    # Success.
    return ""
}

proc ::HtmlImport::Clicked {id} {
    variable locals
    
    OpenHtmlInBrowser $locals(id2file,$id)
}

proc ::HtmlImport::SaveAs {id} {
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
