#  MimeTypesAndPlugins.tcl ---
#  
#      This file is part of the whiteboard application. For a number of 
#      plugins and helpers, define their features, and try to load them.
#      Defines relations between MIME types and file name suffixes,
#      suffixes and mac types etc. A number of arrays are defined at the 
#      global scope. The 'typlist' option for the File Open dialogs are 
#      designed as well.
#      
#  Copyright (c) 1999-2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: MimeTypesAndPlugins.tcl,v 1.2 2003-01-11 16:16:09 matben Exp $

# We need to be very systematic here to handle all possible MIME types
# and extensions supported by each package or helper application.
#
# mimeType2Packages: array that maps a MIME type to a list of one or many 
#                    packages.
# 
# supSuff:           maps package name to supported suffixes for that package,
#                    and maps from MIME type (image, audio, video) to suffixes.
#                    It contains a bin (binary) element as well which is the
#                    the union of all MIME types except text.
#                    
# supportedMimeTypes: maps package name to supported MIME types for that package,
#                    and maps from MIME type (image, audio, video) to MIME type.
#                    It contains a bin (binary) element as well which is the
#                    the union of all MIME types except text.
#                    
# prefMimeType2Package:  The preferred package to handle a file with this MIME 
#                    type. Empty if no packages support MIME.
#
# mimeTypeDoWhat:    is one of (unavailable|reject|save|ask|$packageName).
#                    The default is "unavailable". Only "reject" if package
#                    is there but actively picked reject in dialog.
#                    Both "unavailable" and "reject" map to "Reject" in dialog.
#                    The "unavailable" says that there is no package for MIME.
#                    
#
# NOTE:  1) file suffixes should be phased out, and eventually MIME types
#           should be used as far as possible.
#        2) potential problem with spaces in Mac types.
#
#-------------------------------------------------------------------------------

namespace eval ::Importers:: {
    
    
}

# We start by defining general relations between MIME types etc.
# Mapping from MIME type to a list of suffixes.

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
    
# Create the inverse mapping, from a suffix to a list of MIME types.
# This is not unique either.

foreach theMime [array names mime2SuffixList] {
    set suffList $mime2SuffixList($theMime)
    foreach suff $suffList {
	lappend suffix2MimeList($suff) $theMime
    }
}

# Just take the first element to get a unique file suffix.
foreach suff [array names suffix2MimeList] {
    set prefSuffix2MimeType($suff) [lindex $suffix2MimeList($suff) 0]
}

# For each MIME type set the default coding, text or binary.
# Set also how MIME should be handled. 
# By default, each unknown MIME is unsupported, thus {}, and "unavailable".

foreach theMime [array names mime2SuffixList] {
    if {[string match "text/*" $theMime]} {
	set mimeTypeIsText($theMime) 1
    } else {
	set mimeTypeIsText($theMime) 0
    }
    set prefMimeType2Package($theMime) {}
    set mimeTypeDoWhat($theMime) {unavailable}
}

# Mapping from MIME type to a list of Mac types.

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

# Create the inverse mapping, from a mac type to a list of MIME types.
# This is not unique either. Unneccesary?

foreach theMime [array names mime2MacTypesList] {
    foreach macType $mime2MacTypesList($theMime) {
	lappend macType2MimeList($macType) $theMime
    }
}

# Mapping from Mac "TYPE" to file suffix.
# This is necessary if we open a file on a mac without a file name suffix,
# the network file *must* have a suffix.
# Some are missing...
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

# ...and the inverse mapping. Maybe there are problems with uniqueness? (.gif)
InvertArray macType2Suff suff2MacType

# Search for a set of packages and define their characteristics.
# List all wanted plugins and short names for on which platforms they work.
# m: macintosh, u: unix, w: windows.

if {1} {
    array set packages2Platform {
	QuickTimeTcl       mw 
	TclSpeech          m 
	MSSpeech           w
	snack              muw 
	Img                uw
    }
} else {
    array set packages2Platform {QuickTimeTcl x TclSpeech x snack x Img x}
    puts "WARNING: no extensions loaded"
}
array set helpers2Platform {xanim u}
#set plugin(allPacks) [array names packages2Platform]
#set plugin(allHelper) [array names helpers2Platform]
#set plugin(all) [concat $plugin(allPacks) $plugin(allHelper)]

# The descriptions of the plugins:
#--- Define the reject, save to disk etc. options ------------------------------

set plugin(reject,full) {Reject}
set plugin(reject,type) {}
set plugin(reject,desc) {Reject reception}
set plugin(unavailable,full) {Reject}
set plugin(unavailable,type) {}
set plugin(unavailable,desc) {Reject reception}
set plugin(save,full) {Save to disk}
set plugin(save,type) {}
set plugin(save,desc) {Save to disk}
set plugin(ask,full) {Prompt user}
set plugin(ask,type) {}
set plugin(ask,desc) {Is assumed to be an unknown MIME type therefore prompt\
  the user}
set plugin(tk,full) {tk}
set plugin(tk,type) {}
set plugin(tk,desc) {Supported by the core}
set plugin(tk,importProc) ::ImageAndMovie::DoImport
set plugin(tk,icon,12) [image create photo -format gif -file \
  [file join $this(path) images tklogo12.gif]]

#--- QuickTime -----------------------------------------------------------------

set plugin(QuickTimeTcl,full) "QuickTimeTcl"
set plugin(QuickTimeTcl,type) "Tcl plugin"
set plugin(QuickTimeTcl,desc) "Displays multimedia content such as\
  video, sound, mp3 etc. It also supports a large number of\
  still image formats."
set plugin(QuickTimeTcl,platform) $packages2Platform(QuickTimeTcl)
set plugin(QuickTimeTcl,importProc) ::ImageAndMovie::DoImport

# In future quicktime should get files via its -url option, i.e. http.
set plugin(QuickTimeTcl,trpt,audio) http
set plugin(QuickTimeTcl,trpt,video) http

# Define any 16x16 icon to spice up the UI.
set plugin(QuickTimeTcl,icon,16) [image create photo -format gif -file \
  [file join $this(path) images qtlogo16.gif]]
set plugin(QuickTimeTcl,icon,12) [image create photo -format gif -file \
  [file join $this(path) images qtlogo12.gif]]

# We must list supported MIME types for each package.
# For QuickTime:
set supportedMimeTypes(QuickTimeTcl) {\
    video/quicktime     video/x-dv          video/mpeg\
    video/x-mpeg        audio/mpeg          audio/x-mpeg\
    video/x-msvideo     application/sdp     audio/aiff\
    audio/x-aiff        audio/basic         audio/x-sd2\
    audio/wav           audio/x-wav         image/x-bmp\
    image/vnd.fpx       image/gif           image/jpeg\
    image/x-macpaint    image/x-photoshop   image/png\
    image/x-png         image/pict          image/x-sgi\
    image/x-targa       image/tiff          image/x-tiff\
    application/x-world application/x-3dmf  video/flc\
    application/x-shockwave-flash           audio/midi\
    audio/x-midi        audio/vnd.qcelp     video/avi\
}

#--- TclSpeech via PlainTalk if available --------------------------------------
  
set plugin(TclSpeech,full) "PlainTalk"
set plugin(TclSpeech,type) "Tcl plugin"
set plugin(TclSpeech,desc) "When enabled, a synthetic voice speaks out\
  text that is written in the canvas as well as text received\
  from remote clients. It is triggered by a punctation character (,.;)."
set plugin(TclSpeech,platform) $packages2Platform(TclSpeech)
set plugin(TclSpeech,importProc) {}
set supportedMimeTypes(TclSpeech) {}
set supSuff(TclSpeech) {}

#--- Microsoft Speech via tcom if available --------------------------------------
  
set plugin(MSSpeech,full) "Microsoft Speech"
set plugin(MSSpeech,type) "Tcl plugin"
set plugin(MSSpeech,desc) "When enabled, a synthetic voice speaks out\
  text that is written in the canvas as well as text received\
  from remote clients. It is triggered by a punctation character (,.;)."
set plugin(MSSpeech,platform) $packages2Platform(MSSpeech)
set plugin(MSSpeech,importProc) {}
set supportedMimeTypes(MSSpeech) {}
set supSuff(MSSpeech) {}

#--- snack ---------------------------------------------------------------------
# On Unix/Linux and Windows we try to find the Snack Sound extension.
# Only the "sound" part of the extension is actually needed.

set plugin(snack,full) "snack"
set plugin(snack,type) "Tcl plugin"
set plugin(snack,desc) "The Snack Sound extension adds audio capabilities\
  to the application. Presently supported formats include wav, au, aiff and mp3."
set plugin(snack,platform) $packages2Platform(snack)
set plugin(snack,importProc) ::ImageAndMovie::DoImport
set supportedMimeTypes(snack) {\
    audio/wav           audio/x-wav         audio/basic\
    audio/aiff          audio/x-aiff        audio/mpeg\
    audio/x-mpeg\
}

#--- Img -----------------------------------------------------------------------
# On Unix/Linux and Windows we try to find the Img extension for reading more
# image formats than the standard core one (gif)..

set plugin(Img,full) "Img"
set plugin(Img,type) "Tcl plugin"
set plugin(Img,desc) "Adds more image formats than the standard one (gif)."
set plugin(Img,platform) $packages2Platform(Img)
set plugin(Img,importProc) ::ImageAndMovie::DoImport
set supportedMimeTypes(Img) {\
    image/x-bmp         image/gif           image/jpeg\
    image/png           image/x-png         image/tiff\
    image/x-tiff\
}

#--- xanim ---------------------------------------------------------------------
# Test the 'xanim' app on Unix/Linux for multimedia.
  
set plugin(xanim,full) "xanim"
set plugin(xanim,type) "Helper application"
set plugin(xanim,desc) "A unix/Linux only application that is used\
  for displaying multimedia content in the canvas."
set plugin(xanim,platform) u
set plugin(xanim,importProc) ::ImageAndMovie::DoImport

# There are many more...
set supportedMimeTypes(xanim) {\
    audio/wav           audio/x-wav         video/mpeg\
    video/x-mpeg        audio/mpeg          audio/x-mpeg\
    audio/basic         video/quicktime\
}
      
# Add more supported filetypes as additional extensions and Mac types.
# Hook for adding other packages or plugins
#
#  plugin(packageName,full)        Exact name.
#  plugin(packageName,type)        "Tcl plugin" or "Helper application".
#  plugin(packageName,desc)        A longer description of the package.
#  plugin(packageName,platform)    m: macintosh, u: unix, w: windows.
#  plugin(packageName,trpt,MIME)   (optional) the transport method used,
#                                  which defaults to the built in PUT/GET,
#                                  but can be "http" for certain Mime types
#                                  for the QuickTime package. In that case
#                                  the 'importProc' procedure gets it internally.
#                                  Here MIME can be the mimetype, or the
#                                  mimetype/subtype to be flexible.
#  plugin(packageName,importProc)  which tcl procedure to call when importing...
#  supportedMimeTypes(packageName) List of all MIME types supported.

#...............................................................................
# Search for packages and extensions in the 'addons' directory.
# This is the "hook" that we provide for third parties.

set allFiles [glob [file join [file join $this(path) addons] *.tcl]]

Debug 2 "MimeTypesAndPlugins: allFiles=$allFiles"

foreach addonFile $allFiles {
    source $addonFile
}

#...............................................................................
  
# Compile information of all packages and helper apps to search for.
 
foreach packAndPlat [array names plugin "*,platform"] {
    if {[regexp {^([^,]+),platform$} $packAndPlat match packName]} {
	lappend plugin(all) $packName
	
	# Find type, "Tcl plugin" or "Helper application".
	if {[string match "*plugin*" $plugin($packName,type)]} {
	    lappend plugin(allPacks) $packName
	} elseif {[string match "*application*" $plugin($packName,type)]} {
	    lappend plugin(allHelpers) $packName
	}
    }
}

# Search for the wanted packages in a systematic way. --------------------------

set platformShort [string tolower [string index $tcl_platform(platform) 0]]
foreach packName $plugin(allPacks) {
    
    # Check first if this package can live on this platform.
    if {[string match "*${platformShort}*" $plugin($packName,platform)]} {

	# Search for it! Be silent.
	if {[info exists ::SplashScreen::startMsg]}  {
	    set ::SplashScreen::startMsg "[::msgcat::mc splashlook] $packName..."
	}
	if {![catch {package require $packName} msg]}  {
	    set prefs($packName) 1
	    set plugin($packName,ver) $msg
	} else {
	    set prefs($packName) 0
	}	    
	set prefs($packName,ishost) 1
    } else {
	set prefs($packName,ishost) 0
	set prefs($packName) 0
    }
}
    
# Special solution only for VTK; bad!!! Problem is that VTK is no package :-(
if {[info exists plugin(vtk,full)]} {
    set prefs(vtk) 1
    set plugin(vtk,ver) 0.0
}

# And all helper applications... only apps on Unix/Linux.

foreach helperApp $plugin(allHelpers) {
    if {[string compare $this(platform) "unix"] == 0 }  {
	if {![catch {exec which $helperApp} apath]}  {
	    set prefs($helperApp) 1
	} else  {
	    set prefs($helperApp) 0
	}
    } else  {
	set prefs($helperApp) 0
    }
}

# Mappings file extension (suffixes) to transfer mode; binary or text.
# Supported binary files, that is, images movies etc.
# Start with the core Tk supported formats. Mac 'TYPE'.

set prefs(tk) 1
set supSuff(text) {.txt .tcl}
set supSuff(image) {}
set supSuff(audio) {}
set supSuff(video) {}
set supSuff(application) {}

# Map keywords and package names to the supported MIME types.
# Start by initing, MIME types added below.

set supportedMimeTypes(text) text/plain
set supportedMimeTypes(image) {}
set supportedMimeTypes(audio) {}
set supportedMimeTypes(video) {}
set supportedMimeTypes(application) {}
set supportedMimeTypes(all) $supportedMimeTypes(text)
set supMacTypes(text) {TEXT}
set supSuff(tk) {.gif}
set supportedMimeTypes(tk) image/gif


# Now its time to systematically make the 'supSuff',
# 'supMacTypes', 'supportedMimeTypes', 'mimeType2Packages'.
  
set mime_ {[^/]+}

# We add the tk library to the other ones.
foreach packName "tk $plugin(all)" {
    if {$prefs($packName)}  {
	
	# Loop over all file MIME types supported by this specific package.
	foreach mimeType $supportedMimeTypes($packName) {
	    
	    # Collect all suffixes for this package.
	    eval lappend supSuff($packName) $mime2SuffixList($mimeType)
	    
	    # Get the MIME base: text, image, audio...
	    if {[regexp "(${mime_})/" $mimeType match mimeBase]}  {

		eval lappend supSuff($mimeBase) $mime2SuffixList($mimeType)
		
		# Add upp all "binary" files.
		if {![string equal $mimeBase "text"]}  {
		    eval lappend supSuff(bin) $mime2SuffixList($mimeType)
		}
		
		# Collect the mac types.
		eval lappend supMacTypes($mimeBase) $mime2MacTypesList($mimeType)
		lappend supportedMimeTypes($mimeBase) $mimeType
		lappend mimeType2Packages($mimeType) $packName
		
		# Add upp all "binary" files.
		if {![string equal $mimeBase "text"]}  {
		    lappend supportedMimeTypes(bin) $mimeType
		}
	    }
	}
	eval lappend supSuff(all) $supSuff($packName)
	eval lappend supportedMimeTypes(all) $supportedMimeTypes($packName)
    }
}

# Remove duplicates in lists.
foreach packName "tk $plugin(all)" {
    if {[info exists supSuff($packName)]} {
	set supSuff($packName) [lsort -unique $supSuff($packName)]
    }
}
foreach mimeBase {text image audio video application} {
    if {[info exists supSuff($mimeBase)]} {
	set supSuff($mimeBase) [lsort -unique $supSuff($mimeBase)]
    }
    if {[info exists supportedMimeTypes($mimeBase)]} {
	set supportedMimeTypes($mimeBase) [lsort -unique $supportedMimeTypes($mimeBase)]
    }
}
foreach key [array names supMacTypes] {
    set supMacTypes($key) [lsort -unique $supMacTypes($key)]
}
set supSuff(all) [lsort -unique $supSuff(all)]
set supSuff(bin) [lsort -unique $supSuff(bin)]
set supportedMimeTypes(all) [lsort -unique $supportedMimeTypes(all)]
set supportedMimeTypes(bin) [lsort -unique $supportedMimeTypes(bin)]

# Some kind of mechanism needed to select which package to choose when
# more than one package can support a suffix.
# Here we just takes the first one. Should find a better way!
# QuickTimeTcl is preferred.

foreach mime [array names mimeType2Packages] {
    if {[lsearch -exact $mimeType2Packages($mime) "QuickTimeTcl"] > 0} {
	set prefMimeType2Package($mime) QuickTimeTcl
    } else {
	set prefMimeType2Package($mime) [lindex $mimeType2Packages($mime) 0]
    }
    set mimeTypeDoWhat($mime) $prefMimeType2Package($mime)
}

# By default, no importing takes place, thus {}.
set prefMimeType2Package(text/plain) {}
  
# Create the 'typelist' option for the Open Image/Movie dialog and 
# standard text files.

if {$this(platform) == "macintosh"}  {

    # On Mac either file extension or 'type' must match.
    set typelistText [list  \
      [list "Text" $supSuff(text)]  \
      [list "Text" {} $supMacTypes(text)] ]
} else {
    set typelistText [list  \
      [list "Text" $supSuff(text)]]
}
if {[string match "mac*" $this(platform)] ||   \
  ($this(platform) == "windows")}  {

    set typelistImageMovie [list   \
      [list "Image" $supSuff(image)]  \
      [list "Image" {} $supMacTypes(image)] ]
    if {[llength $supSuff(audio)] > 0}  {
	lappend typelistImageMovie  \
	  [list "Audio" $supSuff(audio)]  \
	  [list "Audio" {} $supMacTypes(audio)]
    }
    if {[llength $supSuff(video)] > 0}  {
	lappend typelistImageMovie  \
	  [list "Video" $supSuff(video)]  \
	  [list "Video" {} $supMacTypes(video)]
    }	
    if {[llength $supSuff(application)] > 0}  {
	lappend typelistImageMovie  \
	  [list "Application" $supSuff(application)]  \
	  [list "Application" {} $supMacTypes(application)]
    }	
    
    # Use 'mime2Description' as entries.
    set mimeTypeList {}
    foreach mime $supportedMimeTypes(all) {
	lappend mimeTypeList   \
	  [list $mime2Description($mime) $mime2SuffixList($mime)   \
	  $mime2MacTypesList($mime)]
    }
    set mimeTypeList [lsort -index 0 $mimeTypeList]
    set typelistImageMovie [concat $typelistImageMovie $mimeTypeList]
    lappend typelistImageMovie [list "Any File" *]
        
} else {

    # Make a separate entry for each file extension. Sort.
    set tlist {}
    foreach ext $supSuff(text) {
	lappend tlist [list [string toupper [string trim $ext .]] $ext]
    }
    set ilist {}
    foreach ext $supSuff(image) {
	lappend ilist [list [string toupper [string trim $ext .]] $ext]
    }
    set alist {}
    foreach ext $supSuff(audio) {
	lappend alist [list [string toupper [string trim $ext .]] $ext]
    }
    set mlist {}
    foreach ext $supSuff(video) {
	lappend mlist [list [string toupper [string trim $ext .]] $ext]
    }
    set applist {}
    foreach ext $supSuff(application) {
	lappend applist [list [string toupper [string trim $ext .]] $ext]
    }
    set sortlist [lsort -index 0 [concat $ilist $alist $mlist $applist]]
    set typelistImageMovie "$sortlist {{Any File} *}"	    

}

# GetMimeTypeFromFileName --
#
#       Return the file's MIME type, either from it's suffix, or on mac, it's
#       file type. Returns application/octet-stream if MIME type unknown.
#       
# Arguments:
#       fileName    the name of the file.
#   
# Results:
#       the MIME type, or application/octet-stream

proc GetMimeTypeFromFileName {fileName} {
    global  suffix2MimeList this
    
    set fext [string tolower [file extension $fileName]]
    if {[string compare $this(platform) "macintosh"] == 0} {
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
    
# GetMimeTypeForMacFile --
#
#       If file suffix exists it determines MIME type, else use 
#       application/octet-stream
#       
# Arguments:
#       fileName    the name of the file.
#   
# Results:
#       the MIME type, or application/octet-stream

proc GetMimeTypeForMacFile {fileName} {
    global  macType2MimeList suffix2MimeList
    
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

#     (Didn't find a better place for this one)

# NativeToNetworkFileName --
#
#       Return a file name that is suitable for transferring over the network.
#       Simply: on Mac, if no extension, find one!
#       Strips off any path.
#
# Arguments:
#       fileName   the native file name.
#
# Results:
#       a network compliant file name or empty if failed.

proc NativeToNetworkFileName {fileName} {
    global  this macType2Suff
    
    set fileTail [file tail $fileName]
    set fext [string tolower [file extension $fileTail]]
    if {[string equal $this(platform) "macintosh"]} {
	if {[string length $fext] > 0} {
	    set fileTailNetwork $fileTail
	} else {
	    set macType [file attributes $fileName -type]
	    if {[info exists macType2Suff($macType)]} {
		set fileTailNetwork ${fileTail}$macType2Suff($macType)
	    } else {
		set fileTailNetwork {}
	    }
	}	
    } else {
	set fileTailNetwork $fileTail
    }
    return $fileTailNetwork
}    

# VerifyPackagesForMimeTypes --
#
#       Goes through all the logic of verifying the 'mimeTypeDoWhat' 
#       and the actual packages available on our system.
#       The 'mimeTypeDoWhat' is stored in our preference file, but the
#       'prefMimeType2Package' is partly determined at runtime, and depends
#       on which packages found at launch.
#       
# Arguments:
#       none.
#   
# Results:
#       updates the 'mimeTypeDoWhat' and 'prefMimeType2Package' arrays.

proc VerifyPackagesForMimeTypes { } {
    global  prefMimeType2Package mimeTypeDoWhat mimeType2Packages
    
    foreach mime [array names mimeTypeDoWhat] {
	switch -- $mimeTypeDoWhat($mime) {
	    unavailable {
		if {[llength $prefMimeType2Package($mime)]} {
		    
		    # In case there was a new package(s) added, pick that one.
		    set mimeTypeDoWhat($mime) $prefMimeType2Package($mime)
		}
	    }
	    reject {
		if {[llength $prefMimeType2Package($mime)] == 0} {
		    
		    # In case a package was removed.
		    set mimeTypeDoWhat($mime) unavailable
		}
	    }    
	    save - ask {
		# Do nothing.
	    }
	    default {
		
		# This should be a package name. 
		if {![info exists mimeType2Packages($mime)] ||  \
		  ([lsearch -exact $mimeType2Packages($mime)   \
		  $mimeTypeDoWhat($mime)] < 0)} {
		    
		    # There are either no package that supports this mime,
		    # or the selected package is not there.
		    if {[llength $prefMimeType2Package($mime)]} {
			set mimeTypeDoWhat($mime) $prefMimeType2Package($mime)
		    } else {
			set mimeTypeDoWhat($mime) unavailable
		    }
		} else {		
		    set prefMimeType2Package($mime) $mimeTypeDoWhat($mime)
		}
	    }
	}
    }
}

# GetPreferredPackage --
#
#       Utility function for the 'mimeTypeDoWhat' 
#       
# Arguments:
#       mime        a mime type.
#   
# Results:
#       package name or empty if not importing.

proc GetPreferredPackage {mime} {
    global  mimeTypeDoWhat
    
    set doWhat $mimeTypeDoWhat($mime)
    switch -- $doWhat {
	reject - unavailable - ask - save {
	    return ""
	}
	default {
	    return $doWhat
	}
    }
}

# ::Importers::DispatchToImporter --
# 
# 

proc ::Importers::DispatchToImporter {filePath mime optList} {
    global  prefs wapp
    
    upvar ::.::wapp wapp

    if {[string equal $prefs(protocol) "jabber"]} {
	::Jabber::WB::DispatchToImporter $filePath $mime $optList
    } else {
	set importPackage [GetPreferredPackage $mime]
	if {[llength $importPackage]} {
	    eval [list $plugin($importPackage,importProc) $wapp(servCan)  \
	      $optList -file $filePath -where "local"]
	}
    }
}

#-------------------------------------------------------------------------------
