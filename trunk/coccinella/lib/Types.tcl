# Types.tcl --
#  
#       This file is part of The Coccinella application. It contains various
#       tools to map:
#       mime type <-> file suffix
#       mac type <-> file suffix
#      
#  Copyright (c) 2003-2004  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Types.tcl,v 1.9 2004-05-13 13:50:22 matben Exp $

package provide Types 1.0

namespace eval ::Types:: {
    
    variable inited 0
    
    # We start by defining general relations between MIME types etc.
    # Mapping from MIME type to a list of suffixes.
    
    variable mime2SuffList
    array set mime2SuffList {
	application/x-world  {.3dmf .3dm  .qd3d .qd3}
	application/x-3dmf   {.3dmf .3dm  .qd3d .qd3}
	application/x-tcl    {.tcl}
	application/sdp      {.sdp}
	application/x-shockwave-flash  {.swf}
	application/macbinary {.bin}
	application/x-macbinary {.bin}
	application/vtk      {.vtk  .g    .cyb  .tri  .stl  .wrl}
	application/octet-stream {.bin .exe .gz .Z .zip}
	application/pdf      {.pdf}
	application/postscript {.eps .ps}
	application/rtf      {.rtf}
	application/x-javascript {.js}
	application/x-tex    {.tex}
	application/x-tar    {.tar}
	application/abiword  {.abi}
	application/vnd.ms-excel {.xls .xlc .xlw}
	application/vnd.ms-powerpoint {.pps .ppt}
	application/msword   {.doc}
	audio/mpeg           {.mpeg .m1s  .m15  .m1a  .m1v  .m64  .m75  \
	  .mp2  .mpa  .mpg  .mpm  .mpv  .mp3}
	audio/x-mpeg         {.mpeg .m1s  .m15  .m1a  .m1v  .m64  .m75  \
	  .mp2  .mpa  .mpg  .mpm  .mpv  .mp3}
	audio/aiff           {.aif  .aiff .aifc}
	audio/x-aiff         {.aif  .aiff .aifc}
	audio/basic          {.au   .snd  .ulw}
	audio/x-sd2          {.sd2}
	audio/wav            {.wav}
	audio/x-wav          {.wav}
	audio/vnd.qcelp      {.qcp}
	audio/midi           {.mifi .mid  .smf  .kar}
	audio/x-midi         {.mifi .mid  .smf  .kar}
	image/x-bmp          {.bmp}
	image/vnd.fpx        {.fpx}
	image/gif            {.gif}
	image/jpeg           {.jpg  .jpeg}
	image/x-macpaint     {.pntg .pnt  .mac}
	image/x-photoshop    {.psd}
	image/png            {.png}
	image/x-png          {.png}
	image/pict           {.pict .pic  .pct}
	image/x-sgi          {.sgi  .rgb}
	image/x-targa        {.tga}
	image/tiff           {.tif  .tiff}
	image/x-tiff         {.tif  .tiff}
	image/x-portable-pixmap {.xpm}
	text/plain           {.txt}
	text/html            {.html .htm}
	text/richtext        {.rtx}
	text/xml             {.xml}
	video/quicktime      {.mov  .qt}
	video/mpeg4          {.mp4}
	video/x-msvideo      {.avi}
	video/avi            {.avi}
	video/x-dv           {.dif  .dv}
	video/mpeg           {.mpeg .m1s  .m15  .m1a  .m1v  .m64  .m75  \
	  .mpa  .mpg  .mpm  .mpv}
	video/x-mpeg         {.mpeg .m1s  .m15  .m1a  .m1v  .m64  .m75  \
	  .mpa  .mpg  .mpm  .mpv}
	video/flc            {.flc  .fli}
    }
    
    variable mime2Desc
    array set mime2Desc {
	application/x-world  {World Application}
	application/x-3dmf   {3D Meta Format}
	application/x-tcl    {Tcl Application}
	application/sdp      {Session Description Protocol}
	application/x-shockwave-flash  {Shockwave Flash}
	application/macbinary {Mac Binary}
	application/x-macbinary {Mac Binary}
	application/vtk      {VTK 3D}
	application/octet-stream {Generic Type}
	application/pdf      {Portable Document Format}
	application/postscript {Postscript Document}
	application/rtf      {Rich Text Format}
	application/x-javascript {Java Script}
	application/x-tex    {TeX Document}
	application/x-tar    {Tape Archive}
	application/abiword  {Abi Word Document}
	application/vnd.ms-excel {MS Excel Document}
	application/vnd.ms-powerpoint {PowerPoint Slide Show}
	application/msword   {Word Document}
	audio/mpeg           {MPEG Audio}
	audio/x-mpeg         {MPEG Audio}
	audio/aiff           {AIFF Audio}
	audio/x-aiff         {AIFF Audio}
	audio/basic          {ULAW Audio}
	audio/x-sd2          {Streaming Audio}
	audio/wav            {WAV Audio}
	audio/x-wav          {WAV Audio}
	audio/vnd.qcelp      {QCP Audio}
	audio/midi           {MIDI Audio}
	audio/x-midi         {MIDI Audio}
	image/x-bmp          {Windows BMP Image}
	image/vnd.fpx        {Image}
	image/gif            {GIF Image}
	image/jpeg           {JPEG Image}
	image/x-macpaint     {Macpaint Image}
	image/x-photoshop    {Photoshop Image}
	image/png            {PNG Image}
	image/x-png          {PNG Image}
	image/pict           {PICT Image}
	image/x-sgi          {SGI Image}
	image/x-targa        {Targa Truevision Image}
	image/tiff           {TIFF Image}
	image/x-tiff         {TIFF Image}
	image/x-portable-pixmap {Portable Pixmap}
	text/plain           {Plain Text}
	text/xml             {Extensible Markup Language}
	text/richtext        {Rich Text Format}
	text/html            {Hypertext Markup Language}
	video/quicktime      {QuickTime Video}
	video/mpeg4          {MPEG 4 Video}
	video/x-dv           {DV Video}
	video/mpeg           {MPEG Video}
	video/x-mpeg         {MPEG Video and Audio}
	video/x-msvideo      {Microsoft Video}
	video/avi            {Microsoft Video}
	video/flc            {FLC Animation}
    }
    
    
    # Mapping from MIME type to a list of Mac types.
    variable mime2MacTypeList
    array set mime2MacTypeList {
	application/octet-stream {BINA}
	application/x-tcl    {TEXT}
	application/x-world  {3DMF}
	application/x-3dmf   {3DMF}
	application/sdp      {TEXT}
	application/x-shockwave-flash  {SWFL "SWF "}
	application/macbinary {BINA}
	application/x-macbinary {BINA}
	application/postscript  {TEXT}
	application/vtk      {????}
	application/pdf      {"PDF "}
	application/rtf      {TEXT}
	application/x-javascript {TEXT}
	application/x-tex    {TEXT}
	application/x-tar    {TARF}
	application/abiword  {}
	application/vnd.ms-excel {"XLS " "XLC " XLC3}
	application/vnd.ms-powerpoint {SLD3 SLD8 PPSS}
	application/msword   {WDBN W6BN W8BN}
	audio/mpeg           {MPEG MPGa MPGv MPGx "Mp3 " SwaT PLAY MPG3 "MP3 "}
	audio/x-mpeg         {MPEG MPGa MPGv MPGx "Mp3 " SwaT PLAY MPG3 "MP3 "}
	audio/aiff           {AIFF AIFC}
	audio/x-aiff         {AIFF AIFC}
	audio/basic          {ULAW}
	audio/x-sd2          {Sd2f "SD2 "}
	audio/wav            {WAVE "WAV "}
	audio/x-wav          {WAVE "WAV "}
	audio/vnd.qcelp      {????}
	audio/midi           {Midi}
	audio/x-midi         {Midi}
	image/x-bmp          {"BMP " BMPf}
	image/vnd.fpx        {FPix}
	image/gif            {GIFf "GIF "}
	image/jpeg           {JPEG}
	image/x-macpaint     {PNTG}
	image/x-photoshop    {8BPS}
	image/png            {PNGf "PNG "}
	image/x-png          {PNGf "PNG "}
	image/pict           {PICT}
	image/x-sgi          {"SGI "}
	image/x-targa        {TPIC}
	image/tiff           {TIFF}
	image/x-tiff         {TIFF}
	image/x-portable-pixmap {PPGM}
	text/plain           {TEXT}
	text/html            {TEXT}
	text/xml             {TEXT}
	text/richtext        {TEXT}
	video/flc            {"FLI "}
	video/quicktime      {MooV}
	video/x-dv           {dvc!}
	video/mpeg           {MPEG MPGa MPGv MPGx}
	video/mpeg4          {MPEG MooV}
	video/x-mpeg         {MPEG MPGa MPGv MPGx}
	video/x-msvideo      {"VfW "}
	video/avi            {"VfW "}
    }
    
    # Mapping from Mac "TYPE" to file suffix.
    # This is necessary if we open a file on a mac without a file name suffix,
    # the network file *must* have a suffix.
    # Some are missing...
    variable macType2Suff
    array set macType2Suff {
	TEXT   .txt          GIFf   .gif          GIFF   .gif
	JPEG   .jpg          MooV   .mov          PLAY   .mp3
	ULAW   .au           PNGf   .png          "VfW " .avi
	dvc!   .dv           MPEG   .mpg          MPGa   .m1a
	MPGv   .m1v          MPGx   .m64          AIFF   .aif
	"PNG " .png          TIFF   .tif          PICT   .pct
	SWFL   .swf          AIFC   .aif          "Mp3 " .mp3
	SwaT   .swa          MPG3   .mp3          "MP3 " .mp3
	Sd2f   .sd2          "SD2 " .sd2          WAVE   .wav
	"WAV " .wav          sfil   .snd          "BMP " .bmp
	BMPf   .bmp          FPix   .fpx          PNTG   .pnt
	8BPS   .psd          qtif   .qtif         "SGI " .sgi
	TPIC   .tga          3DMF   .3dmf         "FLI " .fli
	"SWF " .swf          Midi   .mid          JPEG   .jpeg
	"PDF " .pdf          PPGM   .ppm
    }
}

# ::Types::Init --

proc ::Types::Init { } {
    variable mime2SuffList
    variable mime2MacTypeList
    variable suff2MimeList
    variable prefSuff2MimeType
    variable macType2Suff
    variable macType2MimeList
    variable suff2MacType
    variable mimeIsText
    variable inited
        
    # Create the inverse mapping, from a suffix to a list of MIME types.
    # This is not unique either.
    foreach {mime suffList} [array get mime2SuffList] {
	foreach suff $suffList {
	    lappend suff2MimeList($suff) $mime
	}
	if {[string match "text/*" $mime]} {
	    set mimeIsText($mime) 1
	} else {
	    set mimeIsText($mime) 0
	}
    }
    
    # Just take the first element to get a unique file suffix.
    foreach suff [array names suff2MimeList] {
	set prefSuff2MimeType($suff) [lindex $suff2MimeList($suff) 0]
    }
    
    # Create the inverse mapping, from a mac type to a list of MIME types.
    # This is not unique either. Unneccesary?
    foreach {mime macTypeList} [array get mime2MacTypeList] {
	foreach macType $macTypeList {
	    lappend macType2MimeList($macType) $mime
	}
    }    
    # Make TEXT map to text/plain.
    set macType2MimeList(TEXT) text/plain
    foreach {macType suff} [array get macType2Suff] {
	set suff2MacType($suff) $macType
    }    
    set inited 1
}

# Types::QuickCheck --
# 
#       Checks that we haven't missed something when setting up our arrays.
#       Is always run "offline".

proc ::Types::QuickCheck { } {
    variable mime2SuffList
    variable mime2Desc
    variable mime2MacTypeList
    variable mimeIsText
    variable suff2MacType
 
    set allSuffs {}
    foreach m [::Types::GetAllMime] {
	if {![info exists mime2SuffList($m)]} {
	    puts "$m\t\tmissing mime2SuffList"
	} else {
	    set allSuffs [concat $allSuffs $mime2SuffList($m)]
	}
	if {![info exists mime2Desc($m)]} {
	    puts "$m\t\tmissing mime2Desc"
	}
	if {![info exists mime2MacTypeList($m)]} {
	    puts "$m\t\tmissing mime2MacTypeList"
	}
	if {![info exists mimeIsText($m)]} {
	    puts "$m\t\tmissing mimeIsText"
	}
    }
    set allSuffs [lsort -unique $allSuffs]
    foreach suff $allSuffs {
	if {![info exists suff2MacType($suff)]} {
	    puts "$suff\t\tmissing suff2MacType"
	}
    }
}

# Types::VerifyInternal --
# 
#       Verify that there are no array entries missing, in which case some
#       default values are filled in. Typically run after getting preferences
#       to stop any corruption.

proc ::Types::VerifyInternal { } {
    variable mime2SuffList
    variable mime2Desc
    variable mime2MacTypeList
    variable mimeIsText
    variable suff2MacType
    
    set allSuffs {}
    foreach m [::Types::GetAllMime] {
	if {![info exists mime2SuffList($m)]} {
	    set mime2SuffList($m) {}
	}
	set allSuffs [concat $allSuffs $mime2SuffList($m)]
	if {![info exists mime2Desc($m)]} {
	    set mime2Desc($m) "Unknown"
	}
	if {![info exists mime2MacTypeList($m)]} {
	    set mime2MacTypeList($m) {}
	}
	if {![info exists mimeIsText($m)]} {
	    if {[string match "text/*" $mime]} {
		set mimeIsText($m) 1
	    } else {
		set mimeIsText($m) 0
	    }
	}	
    }
    set allSuffs [lsort -unique $allSuffs]
    foreach suff $allSuffs {

    }
}

# Types::GetMimeTypeForFileName --
#
#       Return the file's MIME type, either from it's suffix, or on mac, it's
#       file type. Returns application/octet-stream if MIME type unknown.
#       
# Arguments:
#       fileName    the name of the file.
#   
# Results:
#       the MIME type, or application/octet-stream

proc ::Types::GetMimeTypeForFileName {fileName} {
    global this
    variable suff2MimeList
    variable inited
    
    if {!$inited} {
	::Types::Init
    }    
    set fext [string tolower [file extension $fileName]]
    if {[string equal $this(platform) "macintosh"]} {
	set mime [GetMimeTypeForMacFile $fileName]
    } else {
	if {[info exists suff2MimeList($fext)]} {
	    set mime [lindex $suff2MimeList($fext) 0]
	} else {
	    set mime application/octet-stream
	}
    }
    return $mime
}

# Types::GetMimeTypeForMacFile --
#
#       If file suffix exists it determines MIME type, else use 
#       application/octet-stream
#       
# Arguments:
#       fileName    the name of the file.
#   
# Results:
#       the MIME type, or application/octet-stream

proc ::Types::GetMimeTypeForMacFile {fileName} {
    variable macType2MimeList
    variable suff2MimeList
    variable inited

    if {!$inited} {
	::Types::Init
    }    
    set fext [string tolower [file extension $fileName]]
    if {[string length $fext]}  {
	if {[info exists suff2MimeList($fext)]} {
	    set mime [lindex $suff2MimeList($fext) 0]
	} else {
	    
	    # Perhaps we should get the mac type here???
	    set mime application/octet-stream
	}
    } else {
	set macType [file attributes $fileName -type]
	if {[string length $macType]}  {
	    if {[info exists macType2MimeList($macType)]} {	    
		set mime [lindex $macType2MimeList($macType) 0]
	    } else {
		set mime application/octet-stream
	    }
	} else {
	    set mime application/octet-stream
	}
    }
    return $mime
}

# Types::GetSuffixForMacFile --
#
#       Returns the file suffix (extension) of a file on mac.
#       If original file does not have any, uses internal arrays and
#       educated guesses.
#       
# Arguments:
#       filePath    the full path of the file.
#   
# Results:
#       the file suffix if any (dot included)

proc ::Types::GetSuffixForMacFile {filePath} {
    variable macType2Suff
    variable inited
    
    if {!$inited} {
	::Types::Init
    }    
    set fext [string tolower [file extension $filePath]]
    if {[string length $fext] == 0} {
	set macType [file attributes $filePath -type]
	if {[info exists macType2Suff($macType)]} {
	    set fext $macType2Suff($macType)
	} else {
	    
	    # Educated guess.
	    if {[string equal $macType "????"]} {
		set fext ""
	    } else {
		set fext ".[string tolower [string trim $macType]]"
	    }
	}
    }
    return $fext
}

# Types::GetFileTailAddSuffix --
#
#       Return the file tail and try to add a reasonably chosen file suffix
#       on macs. Just returns the file tail on non macs.
#
# Arguments:
#       filePath    the full path of the file.
#
# Results:
#       a network compliant file name or empty if failed.

proc ::Types::GetFileTailAddSuffix {filePath} {
    global  this
    
    set fileTail [file tail $filePath]
    if {[string equal $this(platform) "macintosh"]} {
	set fext [file extension $fileTail]
	if {$fext == ""} {
	    set fileTailSuff "${fileTail}[GetSuffixForMacFile $filePath]"
	} else {
	    set fileTailSuff $fileTail
	}	
    } else {
	set fileTailSuff $fileTail
    }
    return $fileTailSuff
}    

# Types::GetSuffixListForMime, SetSuffixListForMime,
# 
#       Various accesor functions.

proc ::Types::GetSuffixListForMime {mime} {
    variable mime2SuffList
    
    if {[info exists mime2SuffList($mime)]} {
	return $mime2SuffList($mime)
    } else {
	return ""
    }
}

proc ::Types::SetSuffixListForMime {mime suffList} {
    variable mime2SuffList
    
    set mime2SuffList($mime) $suffList
}

proc ::Types::GetSuffixListArr { } {
    variable mime2SuffList

    return [array get mime2SuffList]
}

proc ::Types::SetSuffixListArr {suffListName} {
    variable mime2SuffList
    upvar $suffListName locArrName
    
    catch {unset mime2SuffList}
    array set mime2SuffList [array get locArrName]
}

proc ::Types::GetMacTypeListForMime {mime} {
    variable mime2MacTypeList

    if {[info exists mime2MacTypeList($mime)]} {
	return $mime2MacTypeList($mime)
    } else {
	return ""
    }
}

proc ::Types::GetDescriptionForMime {mime} {
    variable mime2Desc

    if {[info exists mime2Desc($mime)]} {
	return $mime2Desc($mime)
    } else {
	return ""
    }
}

proc ::Types::SetDescriptionForMime {mime desc} {
    variable mime2Desc

    set mime2Desc($mime) $desc
}

proc ::Types::GetDescriptionArr { } {
    variable mime2Desc

    return [array get mime2Desc]
}

proc ::Types::SetDescriptionArr {descListName} {
    variable mime2Desc
    upvar $descListName locArrName

    catch {unset mime2Desc}
    array set mime2Desc [array get locArrName]
}

proc ::Types::GetAllMime { } {
    variable mime2SuffList
    
    return [array names mime2SuffList]
}

proc ::Types::GetSuffMimeArr { } {
    variable prefSuff2MimeType
    
    return [array get prefSuff2MimeType]
}

proc ::Types::IsMimeText {mime} {
    variable mimeIsText

    if {[info exists mimeIsText($mime)]} {
	return $mimeIsText($mime)
    } else {
	if {[string match "text/*" $mime]} {
	    return 1
	} else {
	    return 0
	}
    }    
}

proc ::Types::SetMimeTextOrNot {mime what} {
    variable mimeIsText

    set mimeIsText($mime) $what
}

proc ::Types::GetIsMimeTextArr { } {
    variable mimeIsText

    return [array get mimeIsText]
}

proc ::Types::SetIsMimeTextArr {isTextArrName} {
    variable mimeIsText
    upvar $isTextArrName locArrName

    catch {unset mimeIsText}
    array set mimeIsText [array get locArrName]
}

# Types::NewMimeType, DeleteMimeType --
#
#       Registers and deregisters additional mime types.
#       Can be used by plugins.

proc ::Types::NewMimeType {mime desc suffList istext macTypeList} {
    variable mime2Desc
    variable mime2SuffList
    variable mimeIsText
    variable mime2MacTypeList
    variable suff2MimeList
    variable macType2MimeList

    set mime2Desc($mime) $desc
    set mime2SuffList($mime) $suffList
    set mimeIsText($mime) $istext
    set mime2MacTypeList($mime) $macTypeList
    foreach suff $suffList {
	lappend suff2MimeList($suff) $mime
    }
    foreach macType $macTypeList {
	lappend macType2MimeList($macType) $mime
    }
}

proc ::Types::DeleteMimeType {mime} {
    variable mime2Desc
    variable mime2SuffList
    variable mimeIsText
    variable mime2MacTypeList
    variable suff2MimeList
    variable macType2MimeList

    foreach suff mime2SuffList($mime) {
	set ind [lsearch $suff2MimeList($suff) $mime
	if {$ind >= 0} {
	    set suff2MimeList($suff)  \
	      [lreplace $suff2MimeList($suff) $ind $ind]
	}
    }
    foreach macType macType2MimeList($mime) {
	set ind [lsearch $macType2MimeList($macType) $mime
	if {$ind >= 0} {
	    set macType2MimeList($macType)  \
	      [lreplace $macType2MimeList($macType) $ind $ind]
	}
    }
    catch {unset mime2Desc($mime)}
    catch {unset mime2SuffList($mime)}
    catch {unset mimeIsText($mime)}
    catch {unset mime2MacTypeList($mime)}
}

#-------------------------------------------------------------------------------
