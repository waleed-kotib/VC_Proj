# Types.tcl --
#  
#       This file is part of the whiteboard application. It contains various
#       tools to map:
#       mime type <-> file suffix
#       mac type <-> file suffix
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Types.tcl,v 1.1 2003-05-01 13:51:14 matben Exp $

package provide Types 1.0


namespace eval ::Types:: {
    
    # We start by defining general relations between MIME types etc.
    # Mapping from MIME type to a list of suffixes.
    
    variable mime2SuffixList
    array set mime2SuffixList {
	application/x-world  {.3dmf .3dm  .qd3d .qd3}
	application/x-3dmf   {.3dmf .3dm  .qd3d .qd3}
	application/x-tcl    {.tcl}
	application/sdp      {.sdp}
	application/x-shockwave-flash  {.swf}
	application/x-macbinary {.bin}
	application/vtk      {.vtk  .g    .cyb  .tri  .stl  .wrl}
	application/octet-stream {.bin .exe .gz .Z .zip}
	application/pdf      {.pdf}
	application/postscript {.eps .ps}
	application/rtf      {.rtf}
	application/x-javascript {.js}
	application/x-tex    {.tex}
	application/x-tar    {.tar}
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
	text/plain           {.txt}
	text/html            {.html .htm}
	text/richtext        {.rtx}
	text/xml             {.xml}
	video/quicktime      {.mov  .qt}
	video/x-msvideo      {.avi}
	video/avi            {.avi}
	video/x-dv           {.dif  .dv}
	video/mpeg           {.mpeg .m1s  .m15  .m1a  .m1v  .m64  .m75  \
	  .mpa  .mpg  .mpm  .mpv}
	video/x-mpeg         {.mpeg .m1s  .m15  .m1a  .m1v  .m64  .m75  \
	  .mpa  .mpg  .mpm  .mpv}
	video/flc            {.flc  .fli}
    }
    
    variable mime2Description
    array set mime2Description {
	application/x-tcl    {Tcl Application}
	application/sdp      {Session Description Protocol}
	application/x-world  {World Application}
	application/x-3dmf   {3D Meta Format}
	application/x-shockwave-flash  {Shockwave Flash}
	application/postscript  {Postscript Document}
	application/x-macbinary {Mac Binary}
	application/vtk      {VTK 3D}
	application/pdf      {Portable Document Format}
	application/rtf      {Rich Text Format}
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
	text/plain           {Plain Text}
	text/xml             {Extensible Markup Language}
	text/html            {Hypertext Markup Language}
	video/quicktime      {QuickTime Video}
	video/x-dv           {DV Video}
	video/mpeg           {MPEG Video}
	video/x-mpeg         {MPEG Video and Audio}
	video/x-msvideo      {Microsoft Video}
	video/avi            {Microsoft Video}
	video/flc            {FLC Animation}
    }
    
    # Mapping from MIME type to a list of Mac types.
    variable mime2MacTypesList
    array set mime2MacTypesList {
	application/x-tcl    {TEXT}
	application/x-world  {3DMF}
	application/x-3dmf   {3DMF}
	application/sdp      {TEXT}
	application/x-shockwave-flash  {SWFL "SWF "}
	application/postscript  {TEXT}
	application/vtk      {????}
	application/pdf      {"PDF "}
	audio/mpeg           {MPEG MPGa MPGv MPGx "Mp3 " SwaT         \
	  PLAY MPG3 "MP3 "}
	audio/x-mpeg         {MPEG MPGa MPGv MPGx "Mp3 " SwaT         \
	  PLAY MPG3 "MP3 "}
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
	text/plain           {TEXT}
	text/html            {TEXT}
	video/flc            {"FLI "}
	video/quicktime      {MooV}
	video/x-dv           {dvc!}
	video/mpeg           {MPEG MPGa MPGv MPGx}
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
	"SWF " .swf          Midi   .mid
    }
}

# ::Types::Init --

proc ::Types::Init { } {
    variable mime2SuffixList
    variable mime2MacTypesList
    variable suffix2MimeList
    variable prefSuffix2MimeType
    variable macType2Suff
    variable macType2MimeList
    variable suff2MacType
    
    # Create the inverse mapping, from a suffix to a list of MIME types.
    # This is not unique either.
    foreach {mime suffList} [array get $mime2SuffixList] {
	foreach suff $suffList {
	    lappend suffix2MimeList($suff) $theMime
	}
    }
    
    # Just take the first element to get a unique file suffix.
    foreach suff [array names suffix2MimeList] {
	set prefSuffix2MimeType($suff) [lindex $suffix2MimeList($suff) 0]
    }
    
    # Create the inverse mapping, from a mac type to a list of MIME types.
    # This is not unique either. Unneccesary?
    foreach {mime macTypeList} [array get $mime2MacTypesList] {
	foreach macType $macTypeList {
	    lappend macType2MimeList($macType) $theMime
	}
    }
    
    foreach {macType suff} [array get $macType2Suff] {
	set suff2MacType($suff) $macType
    }
    
}

# Types::GetMimeTypeFromFileName --
#
#       Return the file's MIME type, either from it's suffix, or on mac, it's
#       file type. Returns application/octet-stream if MIME type unknown.
#       
# Arguments:
#       fileName    the name of the file.
#   
# Results:
#       the MIME type, or application/octet-stream

proc ::Types::GetMimeTypeFromFileName {fileName} {
    global this
    variable suffix2MimeList
    
    set fext [string tolower [file extension $fileName]]
    if {[string equal $this(platform) "macintosh"]} {
	set mime [GetMimeTypeForMacFile $fileName]
    } else {
	if {[info exists suffix2MimeList($fext)]} {
	    set mime [lindex $suffix2MimeList($fext) 0]
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
    variable suffix2MimeList
    
    set fext [string tolower [file extension $fileName]]
    if {[string length $fext]}  {
	if {[info exists suffix2MimeList($fext)]} {
	    set mime [lindex $suffix2MimeList($fext) 0]
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



#-------------------------------------------------------------------------------
