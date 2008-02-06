# HtmlImport.tcl --
#  
#       This file is part of The Coccinella application. 
#       It is an importer for html documents.
#       
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: HtmlImport.tcl,v 1.16 2008-02-06 13:57:25 matben Exp $


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
    
    # We use a variable 'locals(platform)' that is more convenient for Mac OS X.
    switch -- $tcl_platform(platform) {
	unix {
	    set locals(platform) $tcl_platform(platform)
	    if {[package vcompare [info tclversion] 8.3] == 1} {	
		if {[string equal [tk windowingsystem] "aqua"]} {
		    set locals(platform) "macosx"
		}
	    }
	}
	windows - macintosh {
	    set locals(platform) $tcl_platform(platform)
	}
    }
    
    # Verify that we have web browser.
    switch -- $locals(platform) {
	unix {
	    if {[string length [::Utils::UnixGetWebBrowser]] == 0} {
		return
	    }
	}
	windows {
	    if {![::Windows::CanOpenFileWithSuffix .html]} {
		return
	    }
	}
    }
    
    set locals(docim) [image create photo -data {
R0lGODdhIAAgAPcAAP////395f395P394/394v394f383/383vz83fz83Pz8
2/z82fz82Pz81/z81vz71fz71Pz70/z70vz70fz70Pz7z/z7zvv7zfv7zPv6
y/v6yvv6yfv6yPv6x/v6xvv6xfv6xPv6w/v6wfv6wPv6v/v6vfv6vPv6u/v6
uPv6tvv6tPv6svv6sfv6sPv6r/v6rvv6rPv6q/v6qvv6qfv6qPv6p/v6pvr5
pfn4pPj3pPj3o/f2ovb1ofX0ofTzn/Ly2/HwxvHwnfDwxPDvvvDvvfDvvPDv
uvDvsvDvnPDvm+7tmezrmOvql+rplunolefn0uXlu+Xkt9zcyNrZsdrZr9rZ
rNfW1tHRv9HRvs/OqM/Op8/Opc/Ons/Omc/OksXFs8XEpcTDosTDoMTDn8TD
ncLCwrq6q7q5nrm4m7m4mLm4l7m4k7m4krm4iqSkmKOjiaOjg6OjfZycnJmZ
iJmYgpmYgZmYf5eXl5KSko+PhY6Ogo6Oeo6Od42NjYiIiIODg4ODc4ODcoOD
cYODbX5+fnh4cHh4a3h4anR0dG9vb21tZ21tY21tXmpqamVlZWJiW2JiWmJi
WWBgYFtbW1dXVldXVVdXVFdXU1FRUUxMTAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAACwAAAAAIAAgAAAI/wABCNREsKDBgwgPlrEicKCA
hwEiShRw4MEFDh08aNy4UdPChgA0SbzyJOKTKwMSRIAyhaNLDx4ZNhQZcZIk
OXIcZfojp4KhRDg9yBE6VGNMkDQDuMn0IwClTHokCMmU5SXHozMlSslkBksm
RZUuhLFk9erHrBHlYMqDaBKhnY0CDcU516zMgRID5KlUaA6QTHsepSnb8Sxe
iV8yZQKjAdCjTEMIGzUcUqKcO4o1yHm7iC5Rz5PvVg4gwACDM2gyDnmjRXJo
pKQLLJiQASNHLVE0Rmmtm8oHrHgLKKDbgS7ORYZw6hSD01CdEMBDEkAA4cKG
jC7fQPZgCbCHIZm2jP+IrumAAwsasLukkimNlkyLyI6xJOIE+QYUMsgpHtS4
pUaILPLWH40IUoIK5NFmW1l7WGIIHeAFtkYKL5CHwYJliaGYGB4E8tgRLcxA
3nVElWgcZpng9NYkK8RQA3nqSZZGGh+AYAQcXbhoA3mucVSjCCaoAAMNNuxI
mSYb0eVHbnLg4QddeFRBF5FF8ugSchoFkgmHHxxiBwouzFBklUe+pF1k3e3x
QRGZcMGCDDWMeYOVJfaRCSHvTYKJHH9cIgcMdNlwQw50cmTJHm8sokYmZPAx
yAtU2oADDj0UulGDDxKRCR+RtDFDnEVSigSdc/GpGE+OQJLJHYHKwUMQS1g6
qhF4mXwQAhuZMAJqkTr4oEQTsmqUhhogiHBEHF6MKegOsDoRrEY1kpACDLsK
ykMSTDh7ZELcdntUQAA7
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
    set w [winfo toplevel $wcan]
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(-coords) break
    if {[info exists optArr(-tags)]} {
	set useTag [::CanvasUtils::GetUtagFromTagList $optArr(-tags)]
    } else {
	set useTag [::CanvasUtils::NewUtag]
    }
    set uniqueName [::CanvasUtils::UniqueImageName]		
    set wfr ${wcan}.fr_${uniqueName}    
    
    # Make actual object in a frame with special -class.
    frame $wfr -bg gray50 -class HtmlDocFrame
    label $wfr.icon -bg white -image $locals(docim)
    pack  $wfr.icon -padx 4 -pady 4
    
    set id [$wcan create window $x $y -anchor nw -window $wfr -tags  \
      [list frame $useTag]]
    set locals(id2file,$id) $fileName    
    
    # Need explicit permanent storage for import options.
    set configOpts [list -file $fileName]
    if {[info exists optArr(-url)]} {
	lappend configOpts -url $optArr(-url)
    }
    eval {::CanvasUtils::ItemSet $w $id} $configOpts
    
    bind $wfr.icon <Double-Button-1> [list [namespace current]::Clicked $id]

    # We may let remote clients know our size.
    lappend optList -width [winfo reqwidth $wfr] -height [winfo reqheight $wfr]

    if {[info exists optArr(-url)]} {
	set name [::uri::urn::unquote [file tail $optArr(-url)]]
    } else {
	set name [file tail $fileName]
    }
    set msg "Html document: $name"
    ::balloonhelp::balloonforwindow $wfr.icon $msg
    
    # Success.
    return
}

proc ::HtmlImport::Clicked {id} {
    variable locals
    
    ::Utils::OpenURLInBrowser $locals(id2file,$id)
}

# ::HtmlImport::Save --
# 
#       Template proc for saving an 'import' command to file.
#       Return empty if failure.

proc ::HtmlImport::Save {wCan id args} {
    variable locals
    
    ::Debug 2 "::HtmlImport::Save wCan=$wCan, id=$id, args=$args"
    array set argsArr {
	-uritype file
    }
    array set argsArr $args

    if {[info exists locals(id2file,$id)]} {
	set fileName $locals(id2file,$id)
	if {$argsArr(-uritype) == "http"} {
	    lappend impArgs -url [::Utils::GetHttpFromFile $fileName]
	} else {
	    lappend impArgs -file $fileName
	}
	lappend impArgs -tags [::CanvasUtils::GetUtag $wCan $id 1]
	lappend impArgs -mime [::Types::GetMimeTypeForFileName $fileName]
	return [concat import [$wCan coords $id] $impArgs]
    } else {
	return
    }
}

proc ::HtmlImport::SaveAs {id} {
    variable locals
    
    set ans [tk_getSaveFile]
    if {$ans == ""} {
	return
    }
    if {[catch {file copy $locals(id2file,$id) $ans} err]} {
	::UI::MessageBox -type ok -title [mc Error] -icon error -message \
	  "Failed copying file: $err"
	return
    }
}

#-------------------------------------------------------------------------------
