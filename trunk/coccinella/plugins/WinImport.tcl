# WinImport.tcl --
#  
#       This file is part of The Coccinella application. 
#       It is an importer on windows for a number of documents.
#       
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: WinImport.tcl,v 1.9 2004-12-02 08:22:35 matben Exp $

#package require WindowsUtils

namespace eval ::WinImport:: {
    
    # Local storage: unique running identifier.
    variable uid 0
    variable locals
    set locals(wuid) 0
}

# WinImport::Init --
# 
#       This is called from '::Plugins::Load' and is defined in the file 
#       'pluginDefs.tcl' in this directory.

proc ::WinImport::Init { } {
    global  tcl_platform
    variable locals
    
    # Windows only so far.
    if {![string equal $tcl_platform(platform) "windows"]} {
	return 
    }
    
    # Put the mime types here. Be sure they exist in Types.tcl
    set mimeList {
	application/pdf
	application/abiword
	application/vnd.ms-excel
	application/vnd.ms-powerpoint
	application/msword
	application/rtf
    }
    set mimes {}
    foreach mime $mimeList {
	foreach suff [::Types::GetSuffixListForMime $mime] {
	    if {[::Windows::CanOpenFileWithSuffix $suff]} {
		lappend mimes $mime
	    }	    
	}
    }
    set mimes [lsort -unique $mimes]
    set locals(mimes) $mimes
    
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
    
    set icon16pdf [image create photo -data {
R0lGODlhEAAQAPMAAP///+Av3t3d3d0AALu7u6qqqoiIiBEREQAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAAQABAAAAROMEhEq0UyI8E7
PwN2jQIYIkOqqtvhHui6bt1I1tnhFYUnYBJdh2DwAQNCTsHQwwU9BqLnmCT0
lrwClUPMLg2G4wbr41C/ZXMOnFYHbZcIADs=
}]
    
    set icon12 [image create photo -data {
R0lGODdhDAAMAOYAAP/////87v/75P/30P/1xf/1wv/zuv/zuP/yt//xo//l
W//gQ//fP//eOf/dM//PIP7tlP7tkv7sj/7WFf7VEP7UCfzxv/jwxfTZ3/OB
gPLp6fLQ1/LLNPHGAPHFAPGFhfDv9PDDAO9hX+756u1mZuy5w+u0vukEAOgY
FeYLC+UfH+SwuuLh9+LBGOHAE+G+DODe9tz019m3sdi1rtEAAM4AAMzvwszJ
8crH8cjH28bD68Pku8LrtcK+08G90r+70b7nr7zsvrnrvJSV6YyG34qM6ImD
3oaA3YF63H5323tz2nTYeW3WdUJD2Do92TMnxjHHOS4ixSstxSsfxikcwyfF
MyYaxSAUwxkOsBejKBQJrg0CrAygIgu7FAC4DQCsAQCpAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAADAAM
AAAHeIAqHyQpNTJZX1BLXUGChIaIioyOhYeJi42DlZGYKBkiJzQzXGBVTF5C
JRgbJisaO0A2MTwjTUNFTlI5HA8KCQ4FUUZJVlo+Lh4MERQHT0RIU1g9LR0L
EBMGztDS1NbYVEdKV1s/LyENEhUINywwODogFxYDAgQBgQA7
}]

    set icon16 [image create photo -data {
R0lGODdhEAAQAMQAAP////7wqf7fSP7SAvKKiu5ubuxeXuS9AuIICM2qArYG
BqWg5ojejHVt2GVc1DPGOikdwyEXnQK4CwKlCgKFCAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAEAAQAAAFYiBSEAaCKAA1SQ/zSIBI
mqjKurBcnunavrHRrubDBWc82y8npPVuQJ1TaQRYr9gsAOJYNCCQCCBxGAgC
gsG2+w2Py+f02gsWk81oNZfuvsf1bHVveHJ7bXZweXOHg39aj1ghADs=
}]

    # This defines the properties of the plugin.
    set defList [list \
      pack        WinImport                  \
      desc        "Generic Importer"         \
      ver         0.1                        \
      platform    {windows}                  \
      importProc  ::WinImport::Import        \
      mimes       $mimes                     \
      winClass    GenDocFrame                \
      saveProc    ::WinImport::Save          \
      icon,12     $icon12                    \
      icon,16     $icon16                    \
    ]
  
    # These are generic bindings for a framed thing. $wcan will point
    # to the canvas and %W to the actual frame widget.
    # You may write your own. Tool button names are:
    #   point, move, line, arrow, rect, oval, text, del, pen, brush, paint,
    #   poly, arc, rot.
    # Only few of these are relevant for plugins.
    
    set bindList {\
      move    {{bind GenDocFrame <Button-1>}         {::CanvasDraw::InitMoveWindow $wcan %W %x %y}} \
      move    {{bind GenDocFrame <B1-Motion>}        {::CanvasDraw::DoMoveWindow $wcan %W %x %y}} \
      move    {{bind GenDocFrame <ButtonRelease-1>}  {::CanvasDraw::FinMoveWindow $wcan %W %x %y}} \
      move    {{bind GenDocFrame <Shift-B1-Motion>}  {::CanvasDraw::FinMoveWindow $wcan %W %x %y}} \
      del     {{bind GenDocFrame <Button-1>}         {::CanvasDraw::DeleteWindow $wcan %W %x %y}} \
    }
  
    set locals(icon) [image create photo -data {
R0lGODlhJAAkAPMAAP///+Av3t3d3d0AAMzMzLu7u6qqqoiIiHd3d1VVVRER
EQAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAAkACQAAAT/MMhJq704683n
+mAoip0nnGiqnsqwYGMsf+zgXout73zvIoKW7VXJ6QBIGxKgXOoWQOGwuGMO
mFZsDxpUeBVETzV5VV7JQ6AAwUZAKUbz0WzdcVVv8fxIrj/VKXkScT6FfyuC
ATOLIYAoiThtkpOSiAgbCysnBwKcmo+XGpmaB6WfoJifBgkGpyeQFqMrBQmu
r6EZsiu1trBFn7Strr5wn6W8p8QmmrUGwp/Kg5qrJwkFybgwzMKrz3jZOLPI
At0FBc7C0Yq71wIFxwnxnKUG6rrk1gal5iil8wf2VCQ4wE8TAX3OArrT58kW
KlHuOI1zKCBgLVYUA4GLVctUxoe5EBiJ3HiBksmTbEqoXMmSQwQAOw==
}]

    set locals(iconpdf) [image create photo -data {
R0lGODlhIAAgAPMAAP////IL5d3d3d0AAMzMzLu7u6qqqoiIiHd3d1VVVRER
EQAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAAgACAAAAT4MMgZlr04Z8rn
EmAojqAyLJSmrlY5nN4rz3R9IoL5otUM/K8fICiULXC6XU82HAybz9oxp6gq
UAsf0Bl0bnc4AWKMOGaZvm5zNh2Z08zt2hgWvW14WtteZvkvdSFHHRVkhoeG
JIMdHyQCB4+OfISNJAeXkoIIlJIGCQaZIIsclSMFCaGim4yZqKmjKZKnoKGw
HpKXrpm2EqUiqAa0krwVjp4gCQW7q6SOnyCewm7Msaa6AtEFBcG0xL4CySAF
uQnlkJcG3iOe25faIZfnB+q/B++OBAYHwfTtkKmTWI0DB3AaJ1TPCmqihAqT
woWM/kikxgGRxYtjIgAAOw==
}]
  
    # Register the plugin with the applications plugin mechanism.
    # Any 'package require' must have been done before this.
    ::Plugins::Register WinImport $defList $bindList
}

# WinImport::Import --
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

proc ::WinImport::Import {wcan optListVar args} {
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
	set useTag [::CanvasUtils::GetUtagFromTagList $optArr(-tags)]
    } else {
	set useTag [::CanvasUtils::NewUtag]
    }
    set uniqueName [::CanvasUtils::UniqueImageName]		
    set wfr ${wcan}.fr_${uniqueName}    
    set mime [::Types::GetMimeTypeForFileName $fileName]
    
    # Make actual object in a frame with special -class.
    frame $wfr -bg gray50 -class GenDocFrame
    if {[string equal $mime "application/pdf"]} {
	label ${wfr}.icon -bg white -image $locals(iconpdf)
    } else {
	::WinImport::MakeGenericAppIcon32 ${wfr}.icon [file extension $fileName]
    }
    pack ${wfr}.icon -padx 4 -pady 4
    
    set id [$wcan create window $x $y -anchor nw -window $wfr -tags  \
      [list frame $useTag]]
    set locals(id2file,$id) $fileName
    
    # Need explicit permanent storage for import options.
    set configOpts [list -file $fileName]
    if {[info exists optArr(-url)]} {
	lappend configOpts -url $optArr(-url)
    }
    eval {::CanvasUtils::ItemSet $wtop $id} $configOpts
    
    bind $wfr.icon <Double-Button-1> [list [namespace current]::Clicked $id]

    # We may let remote clients know our size.
    lappend optList -width [winfo reqwidth $wfr] -height [winfo reqheight $wfr]

    set desc [::Types::GetDescriptionForMime $mime]
    if {[info exists optArr(-url)]} {
	set name [::uriencode::decodefile  \
	  [file tail [::Utils::GetFilePathFromUrl $optArr(-url)]]]
    } else {
	set name [file tail $fileName]
    }
    set msg "$desc: $name"
    ::balloonhelp::balloonforwindow $wfr.icon $msg
    
    # Success.
    return ""
}

proc ::WinImport::Clicked {id} {
    variable locals
    
    ::Windows::OpenFileFromSuffix $locals(id2file,$id)
}

# ::WinImport::Save --
# 
#       Template proc for saving an 'import' command to file.
#       Return empty if failure.

proc ::WinImport::Save {wCan id args} {
    variable locals
    
    ::Debug 2 "::WinImport::Save wCan=$wCan, id=$id, args=$args"
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
	return ""
    }
}

proc ::WinImport::SaveAs {id} {
    variable locals
    
    set ans [tk_getSaveFile]
    if {$ans == ""} {
	return
    }
    if {[catch {file copy $locals(id2file,$id) $ans} err]} {
	::UI::MessageBox -type ok -icon error -message \
	  "Failed copying file: $err"
	return
    }
}

proc ::WinImport::MakeGenericAppIcon32 {w suff} {
    
    variable locals
    
    set fontSB [option get . fontSmallBold {}]
    
    canvas $w -bg white -width 32 -height 32 -scrollregion {0 0 32 32} \
      -highlightthickness 0
    set col gray20
    $w create image 0 0 -anchor nw -image $locals(docim)
    $w create text 18 24 -anchor c -text $suff -font $fontSB -fill gray70 \
      -tags txt
    $w create text 17 23 -anchor c -text $suff -font $fontSB -fill gray60 \
      -tags txt
    $w create text 16 22 -anchor c -text $suff -font $fontSB -fill gray10 \
      -tags txt
    return $w
}

#-------------------------------------------------------------------------------
