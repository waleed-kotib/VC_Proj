#  CanvasFile.tcl ---
#  
#      This file is part of The Coccinella application. It implements procedures
#      for transfering the items of a canvas to and from files.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: CanvasFile.tcl,v 1.31 2007-09-14 13:17:09 matben Exp $
 
package require can2svg
package require svg2can
package require tinydom
package require undo

package provide CanvasFile 1.0

namespace eval ::CanvasFile:: {}

# DrawCanvasItemFromFile --
#
#       Opens a canvas file, calls 'FileToCanvas' to draw all its content in 
#       canvas, and closes the file.
#
# Arguments:
#       w           toplevel widget path
#       filePath    the file with canvas data.
#       
# Results:
#       none

proc ::CanvasFile::DrawCanvasItemFromFile {w filePath args} {
    
    set wcan [::WB::GetCanvasFromWtop $w]

    # Opens the data file.
    if {[catch {open $filePath r} fd]} {
	set tail [file tail $filePath]
	::UI::MessageBox -icon error -title [mc Error] -type ok  \
	  -message [mc messfailopread2 $tail $fd]
	return
    }
    fconfigure $fd -encoding utf-8
    eval {FileToCanvas $wcan $fd $filePath} $args
    close $fd
}

# CanvasFile::OpenCanvas --
# 
#       Just a wrapper for FileToCanvas.

proc ::CanvasFile::OpenCanvas {wcan fileName args} {
    
    set w [winfo toplevel $wcan]

    # Opens the data file.
    if {[catch {open $fileName r} fd]} {
	set tail [file tail $fileName]
	::UI::MessageBox -message [mc messfailopread2 $tail $fd] \
	  -icon error -title [mc Error] -type ok
	return
    }
    ::CanvasCmd::DoEraseAll $wcan   
    ::undo::reset [::WB::GetUndoToken $wcan]
    fconfigure $fd -encoding utf-8
    eval {FileToCanvas $wcan $fd $fileName} $args
    close $fd
}
	  
# FileToCanvas --
#
#       Dispatches to the canvas reader for the specific file version number.
#
# Arguments:
#       w      the canvas widget.
#       fd    the file identifier.
#       absPath    the file with canvas data.
#       -where = "all":     write to this canvas and all others.
#               "remote":  write only to remote client canvases.
#               "local":   write only to this canvas and not to any other.
#               ip number: write only to this remote client canvas and not to own.
#       
# Results:
#       none

proc ::CanvasFile::FileToCanvas {w fd absPath args} {
    
    # Dispatch to the actual file reader depending on file format version.
    set version 0
    if {[gets $fd line] >= 0} { 
	if {![regexp -nocase {^ *# *version: *([0-9]+)} $line match version]} {
	    set version 1
	}
    }
    set ans {}
    seek $fd 0 start
    switch -- $version {
	1 {
	    set ans [eval {::CanvasFile::FileToCanvasVer1 $w $fd $absPath} $args]
	}
	2 {
	    set ans [eval {::CanvasFile::FileToCanvasVer2 $w $fd $absPath} $args]
	}
	default {
	    return -code error "Unrecognized file version: $version"
	}
    }
    return $ans
}

# CanvasFile::FileToCanvasVer1 --
# 
#       Takes the canvas items in the 'filePath' and draws them in the canvas 'w'.
#       Reads line by line from file. Each line contains an almost complete 
#       canvas command except for the widget path. 
#       Lines can also contain 'image create ...' commands.
#       The file must be opened and file id given as 'fd'.

proc ::CanvasFile::FileToCanvasVer1 {wcan fd absPath args} {
    global  prefs
    
    Debug 2 "FileToCanvasVer1 absPath=$absPath"
    
    array set argsArr {
	-where    all
    }
    array set argsArr $args
    set where $argsArr(-where)

    # Should file names in file be translated to native path?
    set fileNameToNative 1
    set nl_ "\\n"
    
    # New freash 'utags' only if writing to own canvas as well.
    if {[string equal $where "all"] || [string equal $where "local"]} {
	set updateUtags 1
    } else {
	set updateUtags 0
    }
    set dirPath [file dirname $absPath]
    
    # Read line by line; each line contains an almost complete canvas command.
    # Item prefix and item numbers need to be taken care of.
    
    while {[gets $fd line] >= 0} { 
	
	# Skip any comment lines and empty lines.
	if {[string match "#*" $line]} {
	    continue
	}
	set previousImageOrMovieCmd {}
	set cmd [lindex $line 0]
	
	# Figure out if image create command...or movie command.
	if {[string equal $cmd "image"] || [string equal -nocase $cmd "movie"]} {
	    set previousImageOrMovieCmd $line
	    
	    # Get the next line as well.
	    gets $fd line
	} 
	
	# This must be a canvas command.
	set type [lindex $line 1]	
	set ind [lsearch -exact $line "-tags"]
	if {$ind >= 0} {
	    set tagInd [expr $ind + 1]
	    set tags [lindex $line $tagInd]
	} else {
	    continue
	}
	
	# The it tags must get new numbers since 'utags' may never be reused.
	# This is only valid when writing on this canvas, see 'updateUtags'.
	# Be sure to replace any other prefix with own prefix; else 
	# a complete mess is the result.
	
	if {![regexp {(^| )([^/ ]+/[0-9]+)} $tags match junk oldUtag]} {
	    continue
	}
	if {$updateUtags} {
	    set utag [::CanvasUtils::NewUtag]
	    regsub {(^| )[^/ ]+/[0-9]+} $tags " $utag" newTags
	    
	    # Replace tags.
	    set line [lreplace $line $tagInd $tagInd $newTags]
	    set ittag $utag
	} else {
	    set ittag $oldUtag
	}
	
	# Make newline substitutions.
	set cmdnl [subst -nocommands -novariables $line]
	
	# Images and movies. Handle in a different manner.
	
	if {[string equal $type "image"] || [string equal $type "window"]} {
	    	    
	    # First, try to localize the original file. If unknown just skip.
	    # Use the image create command on the previous line if exist.
	    # Extract the complete file path.
	    
	    if {$previousImageOrMovieCmd ne ""} {
		set ind [lsearch -exact $previousImageOrMovieCmd "-file"]
		if {$ind >= 0} {
		    set filePath [lindex $previousImageOrMovieCmd [expr $ind + 1]]
		}
		
		# Translate to native file path? Useful if want to have
		# platform independent canvas file format.
		# Bug if path contains '/' on Mac, or ':' on unix?
		# The relative path in the file is relative that file
		# and not relative present directory!
		
		set filePath [addabsolutepathwithrelative $dirPath $filePath]
		if {$fileNameToNative} {
		    set filePath [file nativename $filePath]
		}
	    } else {
	        continue
	    }
		
	    # An image can be zoomed, need to tell 'DoImport' 
	    # through the option list.
	    set zoomOpts ""
	    if {[string equal $type "image"]} {
		set ind [lsearch -exact $line "-image"]
		if {$ind >= 0} {
		    set imageName [lindex $line [expr $ind + 1]]

		    # Find out if zoomed.
		    if {[regexp {(.+)_zoom(|-)([0-9]+)} $imageName   \
		      match origImName sign factor]} {
			set zoomOpts $sign$factor
		    }
		}
	    }
	    
	    # Need to know the coordinates.
	    set x [lindex $line 2]
	    set y [lindex $line 3]
	    set opts [list -coords [list $x $y] -tags $ittag]
	    if {$zoomOpts ne ""} {
		lappend opts -zoom-factor $zoomOpts
	    }
	    
	    # Need to preserve the stacking order for images on remote clients.
	    # Add stacking order to the 'opts'.
	    if {[info exists previousUtag]} {
		lappend opts -above $previousUtag
	    }
	    
	    # Let the import procedure do the job; manufacture an option list.
	    ::Import::DoImport $wcan $opts -file $filePath -where $where
	    
	} else {
	    set w [winfo toplevel $wcan]
	    
	    # Draw ordinary item not image nor window (movie).
	    if {[string equal $where "all"] || [string equal $where "local"]} {
	
		# If html font sizes, then translate these to point sizes.
		if {$prefs(useHtmlSizes) && [string equal $type "text"]} {
		    set cmdlocal [::CanvasUtils::FontHtmlToPointSize $cmdnl]
		} else {
		    set cmdlocal $cmdnl
		}
		eval {$wcan} $cmdlocal
	    }
	    
	    # Encode all newlines as \n .
	    regsub -all "\n" $line $nl_ cmdoneline
	    
	    # Write to other clients.
	    if {[string equal $where "all"] || [string equal $where "remote"]} {
		::CanvasUtils::Command $w $cmdoneline remote
	    } elseif {![string equal $where "local"]} {
		
		# Write only to specified client with ip number 'where'.
		::CanvasUtils::Command $w $cmdoneline $where
	    }
		
	    if {[string equal $where "all"] || [string equal $where "local"]} {

		# Run all registered hookd like speech.
		if {[string equal $type "text"]} {
		    ::hooks::run whiteboardTextInsertHook me  \
		      [$wcan itemcget $ittag -text]
		}
	    }
	}
	set previousUtag $oldUtag
    }
    return 0
}

# CanvasFile::FileToCanvasVer2 --
#
#       Reads a canvas file version 2 into canvas. 
#       Handles any 'import' commands.

proc ::CanvasFile::FileToCanvasVer2 {wcan fd absPath args} {
    global  prefs
    
    Debug 2 "FileToCanvasVer2 absPath=$absPath args='$args'"
    
    array set argsArr {
	-showbroken   1
	-tryimport    1
	-where        all
	-acceptcache  1
    }
    array set argsArr $args
    set where $argsArr(-where)
    
    # Should file names in file be translated to native path?
    set fileNameToNative 1
    set nl_ "\\n"
    
    # New fresh 'utags' only if writing to own canvas as well.
    if {[string equal $where "all"] || [string equal $where "local"]} {
	set updateUtags 1
    } else {
	set updateUtags 0
    }
    set dirPath [file dirname $absPath]
    set w [winfo toplevel $wcan]
    
    set nimports 0
    set undoCmdList {}
    
    # Read line by line; each line contains an almost complete canvas command.
    # Item prefix and item numbers need to be taken care of.
    
    while {[gets $fd line] >= 0} { 
	
	# Skip any comment lines and empty lines.
	if {[regexp {(^ *#|^[ \n\t]*$)} $line]} {
	    continue
	}
	set cmd [lindex $line 0]
	
	# This fails if not  $updateUtags !!!
	if {[info exists nextUtag]} {
	    set utag $nextUtag
	    set line [::CanvasUtils::ReplaceUtag $line $utag]
	    unset nextUtag
	} elseif {$updateUtags} {
	    set utag [::CanvasUtils::NewUtag]
	    set line [::CanvasUtils::ReplaceUtag $line $utag]
	} else {
	    set utag [::CanvasUtils::GetUtagFromCreateCmd $line]
	}
	
	switch -- $cmd {
	    create {
	    
		# Draw ordinary item not image nor window (movie).
		set type [lindex $line 1]
		if {[string equal $where "all"] || \
		  [string equal $where "local"]} {
		    set cmdlocal $line
		    
		    # Make newline substitutions.
		    # If html font sizes, then translate these to point sizes.
		    if {[string equal $type "text"]} {
			set cmdlocal [subst -nocommands -novariables $cmdlocal]
			set cmdlocal [::CanvasUtils::FontHtmlToPointSize $cmdlocal]
		    }
		    eval {$wcan} $cmdlocal
		}
		
		# Write to other clients.
		if {[string equal $where "all"] || \
		  [string equal $where "remote"]} {
		    ::CanvasUtils::Command $w $line "remote"
		} elseif {![string equal $where "local"]} {
		    
		    # Write only to specified client with ip number 'where'.
		    ::CanvasUtils::Command $w $line $where
		}
		
		# Speak...
		switch -- $where {
		    all - local {
			if {[string equal $type "text"]} {
			    ::hooks::run whiteboardTextInsertHook me \
			      [$wcan itemcget $utag -text]
			}
		    }
		}
	    }
	    import {
		set errMsg ""

		# Be sure to remove any existing -above and -below since
		# they refer to wrong utags.
		foreach key {-above -below} {
		    set ind [lsearch $line $key]
		    if {$ind >= 0} {
			set line [lreplace $line $ind [expr $ind+1]]
		    }
		}
		
		# Assume the order in the file is also stacking order.
		if {[info exists previousUtag]} {
		    lappend line -above $previousUtag
		} 
		    
		# To get the -below value we need a trick.
		# Make the next utag to use.
		set nextUtag [::CanvasUtils::NewUtag]
		lappend line -below $nextUtag

		# This is typically an image or movie (QT or Snack).
		set errMsg [eval {
		    ::Import::HandleImportCmd $wcan $line  \
		      -addundo 0 -basepath $dirPath  \
		      -progress [list ::Import::ImportProgress $line]  \
		      -command  [list ::Import::ImportCommand $line]
		} [array get argsArr]]
		incr nimports
	    }
	    default {

		# Here we should provide some hooks for plugins to handle
		# their own stuff. ???
		# Or handled elsewhere???
	    }
	}
	set previousUtag $utag
    }
    return $nimports
}

# CanvasFile::CanvasToChannel --
#
#       Writes line by line to file. Each line contains an almost complete 
#       canvas command except for the widget path. 
#       The file must be opened and file id given as 'fd'.
#
# Arguments:
#       wcan             canvas widget path.
#       fd               file descriptor of the saved file.
#       absPath          absolute path to the saved file.
#       args:            -pathtype absolute|relative(D)
#                        anyone for GetOneLiner*
#       
# Results:
#       none

proc ::CanvasFile::CanvasToChannel {wcan fd absPath args} {
    global  this prefs
    
    Debug 2 "::CanvasFile::CanvasToChannel absPath=$absPath"
    
    # When saving images or movies, save relative or absolute path names?
    # It is perhaps best to choose a path relative the actual file path of the 
    # file?
    
    array set argsA {
	-keeputag     1
	-pathtype     relative
    }
    array set argsA $args
    if {$argsA(-pathtype) eq "relative"} {
	set argsA(-basepath) $absPath
    }
    
    puts $fd "# Version: 2"
    
    foreach id [$wcan find all] {
	set line [eval {::CanvasUtils::GetOneLinerForAny $wcan $id}  \
	  [array get argsA]]
	if {$line != {}} {
	    puts $fd $line		    
	}
    }
}

# CanvasFile::DataToFile --
#
#       Writes a list of canvas commands to a file.

proc ::CanvasFile::DataToFile {filePath canvasList} {
    
    if {[catch {open $filePath w} fd]} {
	set tail [file tail $filePath]
	::UI::MessageBox -message [mc messfailopread2 $tail $fd] \
	  -icon error -title [mc Error] -type ok
	return
    }
    fconfigure $fd -encoding utf-8
    puts $fd "# Version: 2"

    # Be sure to strip off the "CANVAS:" prefix. ???
    foreach line $canvasList {
	if {[string equal [lindex $line 0] "CANVAS:"]} {
	    puts $fd [lrange $line 1 end]
	} else {
	    puts $fd $line
	}
    }
    close $fd
}

# OpenCanvasFileDlg --
#
#       Creates a standard file open dialog, opens the file, and draws to
#       canvas via 'FileToCanvas'. If 'filePath' given, dont show file
#       open dialog.
#
# Arguments:
#       wcan        canvas widget
#       filePath    absolute path to the save file.
#       
# Results:
#       none

proc ::CanvasFile::OpenCanvasFileDlg {wcan {filePath {}}} {
    global  prefs this
    variable regOpen
    
    set w [winfo toplevel $wcan]
    
    if {[string length $filePath] == 0} {
	set typelist {
	    {"Canvas"     {.can}}
	    {"XML/SVG"    {.svg}}
	    {"Text"       {.txt}}
	}

	foreach {key name} [array get regOpen *,name] {
	    lappend typelist [list $regOpen($name,label) $regOpen($name,suffix)]
	}

	set ans [::UI::MessageBox -icon warning -title [mc Warning] -type okcancel -default ok \
	  -parent $w -message [mc messcanerasewarn2]]
	if {$ans eq "cancel"} {
	    return
	}
	set userDir [::Utils::GetDirIfExist $prefs(userPath)]
	set ans [tk_getOpenFile -title [mc "Open File"]  \
	  -filetypes $typelist -defaultextension ".can"  \
	  -initialdir $userDir]
	if {$ans eq ""} {
	    return
	}
	set prefs(userPath) [file dirname $ans]
	set fileName $ans
    } else {
	set fileName $filePath
    }  
    set ext [file extension $fileName]
    
    switch -- $ext {
	.svg {
	    ::undo::reset [::WB::GetUndoToken $wcan]
	    ::CanvasCmd::DoEraseAll $wcan
	    ::CanvasFile::SVGFileToCanvas $w $fileName
	}
	.can {	    
	    OpenCanvas $wcan $fileName
	}
	default {
	    if {[info exists regOpen($ext,suff-openProc)]} {
		uplevel #0 $regOpen($ext,suff-openProc) [list $wcan $fileName]
	    }
	}
    }
}
    
# ::CanvasFile::Save --
#
#       Executes the menu File/Save command. If not linked to a file it
#       displays a Save As dialog instead.
#       
# Arguments:
#       wcan        canvas widget
#       
# Results:
#       file save dialog shown if needed, file written.

proc ::CanvasFile::Save {wcan} {
    set w [winfo toplevel $wcan]
    upvar ::WB::${w}::state state
    
    if {$state(fileName) eq ""} {
	set fileName [SaveAsDlg $wcan]
    } else {
	set fileName [SaveCanvas $wcan $state(fileName)]
    }
    return $fileName
}
    
# ::CanvasFile::SaveAsDlg --
#
#       Displays a Save As dialog and acts correspondingly.
#       
# Arguments:
#       wcan        canvas widget
#       
# Results:
#       file save dialog shown, file written.

proc ::CanvasFile::SaveAsDlg {wcan} {
    set w [winfo toplevel $wcan]
    upvar ::WB::${w}::state state
    
    set fileName [SaveCanvasFileDlg $wcan]
    if {$fileName ne ""} {
	set state(fileName) $fileName
    }
    set title [wm title $w]
    if {[string first " : " $title] < 0} {
	wm title $w "$title : [file tail $fileName]"
    }
}

# SaveCanvasFileDlg --
#
#       Creates a standard file save dialog, opens the file, and calls
#       'CanvasToChannel' to write into it, closes it.
#
# Arguments:
#       wcan        canvas widget
#       
# Results:
#       fileName or empty

proc ::CanvasFile::SaveCanvasFileDlg {wcan} {
    global  prefs this
    variable regSave
            
    set typelist {
	{"Canvas"            {.can}}
	{"XML/SVG"           {.svg}}
	{"Postscript File"   {.ps} }
	{"Text"              {.txt}}
    }
    
    foreach {key name} [array get regSave *,name] {
	lappend typelist [list $regSave($name,label) $regSave($name,suffix)]
    }
    
    set userDir [::Utils::GetDirIfExist $prefs(userPath)]
    set opts [list -initialdir $userDir]
    if {$prefs(haveSaveFiletypes)} {
	lappend opts -filetypes $typelist
    }
    if {[string match "mac*" $this(platform)]} {
	lappend opts -message "Pick .svg suffix for SVG, .can as default"
    }
    set fileName [eval {tk_getSaveFile -title [mc Save] \
      -defaultextension ".can"} $opts]
    if {$fileName eq ""} {
	return
    }
    set prefs(userPath) [file dirname $fileName]
    SaveCanvas $wcan $fileName
    
    return $fileName
}

# CanvasFile::SaveCanvas --
# 
#       Write canvas to specified file name taking any specific file
#       extension as an indication of format.

proc ::CanvasFile::SaveCanvas {wcan fileName args} {
    global  prefs this
    variable regSave
    
    set ext [file extension $fileName]

    switch -- $ext {
	.svg {
	    
	    # Not completely sure about -usetags.
	    ::can2svg::canvas2file $wcan $fileName -uritype file -usetags all \
	      -allownewlines 0  \
	      -windowitemhandler ::CanvasUtils::GetSVGForeignFromWindowItem
	}
	.ps {
	    eval {$wcan postscript} $prefs(postscriptOpts) {-file $fileName}
	    if {[string equal $this(platform) "macintosh"]} {
		file attributes $ans -type TEXT -creator vgrd
	    }
	}
	default {
	    
	    if {[info exists regSave($ext,suff-saveProc)]} {
		uplevel #0 $regSave($ext,suff-saveProc) [list $wcan $fileName]
	    } else {
		
		# If not .txt make sure it's .can extension.
		if {$ext ne ".txt"} {
		    set fileName "[file rootname $fileName].can"
		}
		
		# Opens the data file.
		if {[catch {open $fileName w} fd]} {
		    set tail [file tail $fileName]
		    ::UI::MessageBox -icon error -title [mc Error] -type ok \
		      -message [mc messfailopwrite2 $tail $fd]
		    return
		}	    
		fconfigure $fd -encoding utf-8
		CanvasToChannel $wcan $fd $fileName
		close $fd
	    }
	}
    }
}

# CanvasFile::DoSaveAsItem --
# 
# 

proc ::CanvasFile::DoSaveAsItem {wcan} {
    global  prefs this
	
    set typelist {
	{"Canvas"            {.can}}
    }
    set ans [tk_getSaveFile -title [mc {Save Canvas Item}] \
      -defaultextension ".can" -initialdir $this(altItemPath) \
      -initialfile Untitled.can]
    if {$ans eq ""} {
	return
    }
    set fileName $ans
    if {[catch {open $fileName w} fd]} {
	set tail [file tail $fileName]
	::UI::MessageBox -icon error -title [mc Error] -type ok \
	  -message [mc messfailopwrite2 $tail $fd]
	return
    }	    
    fconfigure $fd -encoding utf-8
    CanvasToChannel $wcan $fd $fileName -keeputag 0
    close $fd
}

# CanvasFile::ObjectConfigure --
#
#       As 'thing' configure but only the actual options returned.
#       
# Arguments:
#       object   the name of the image/movie etc.
#       
# Results:
#       list of options and values as '-option value' ....

proc ::CanvasFile::ObjectConfigure {object} {
    
    set opcmd {}
    set opts [$object configure]
    foreach oplist $opts {
	foreach {op x y defval val} $oplist {
	    if {![string equal $defval $val]} {
		lappend opcmd $op $val
	    }
	}
    }
    return $opcmd
}

# CanvasFile::ImagePathTranslation --
#
#       Translate any 'file' options to point to a relative file path
#       instead of an absolute file path.
#       
# Arguments:
#       optList     list of options and values as '-option value' ....
#       absFilePath the absolute file path to be relative to.
#       
# Results:
#       list of options and values as '-option value' ....

proc ::CanvasFile::ImagePathTranslation {optList absFilePath} {
       
    # If any file path, make sure it is relative if requested.
    set ind [lsearch $optList "-file"]
    if {$ind >= 0} {
	set absImPath [lindex $optList [expr $ind + 1]]
	if {$absImPath ne ""} {
	    set newOptList [lreplace $optList   \
	      [expr $ind + 1] [expr $ind + 1]   \
	      [::tfileutils::relative $absFilePath $absImPath]]
	} else {
	    set newOptList $optList
	}
    } else {
	set newOptList $optList
    }
    return $newOptList
}

# CanvasFile::SVGFileToCanvas --
# 
#       Imports an svg file to canvas.

proc ::CanvasFile::SVGFileToCanvas {w filePath} {
    
    set wcan [::WB::GetCanvasFromWtop $w]

    # Opens the data file.
    if {[catch {open $filePath r} fd]} {
	set tail [file tail $filePath]
	::UI::MessageBox -icon error -title [mc Error] -type ok -parent $w \
	  -message [mc messfailopread2 $tail $fd]
	return
    }
    fconfigure $fd -encoding utf-8
    set xml [read $fd]
    set xmllist [tinydom::documentElement [tinydom::parse $xml]]
    
    # Update the utags...
    set cmdList [svg2can::parsesvgdocument $xmllist \
      -imagehandler [list ::CanvasFile::SVGImageHandler $w] \
      -foreignobjecthandler [list ::CanvasUtils::SVGForeignObjectHandler $w]]
    foreach cmd $cmdList {
	set utag [::CanvasUtils::NewUtag]
	set cmd [::CanvasUtils::ReplaceUtag $cmd $utag]
	eval $wcan $cmd
    }
    close $fd
}

# CanvasFile::SVGImageHandler --
# 
#       Callback for svg to canvas translator to be able to garbage collect
#       image when window closed.

proc ::CanvasFile::SVGImageHandler {w cmd} {
    
    set idx [lsearch -regexp $cmd {-[a-z]+}]
    array set argsArr [lrange $cmd $idx end]
    return [::WB::CreateImageForWtop $w "" -file $argsArr(-file)]
}

# CanvasFile::FlattenToDir --
# 
#       Takes an existing canvas file and puts it inside 'dir' together
#       with all its referenced files. Files may be renamed to avoid
#       name collisions. The 'dir' must already exist and can be a VFS.

proc ::CanvasFile::FlattenToDir {fileName dir} {
    global  this
    
    set origfd [open $fileName {RDONLY}]
    fconfigure $origfd -encoding utf-8

    set tmp [::tfileutils::tempfile $this(tmpPath) ""]
    set tmpfd [open $tmp {CREAT WRONLY}]
    fconfigure $tmpfd -encoding utf-8
    
    # Must process all -file options to point to the ones in 'dir'.
    while {[gets $origfd line] >= 0} { 
	if {[regexp {(^ *#|^[ \n\t]*$)} $line]} {
	    puts $tmpfd $line
	    continue
	}
	set cmd [lindex $line 0]
	if {$cmd ne "import"} {
	    puts $tmpfd $line
	    continue
	}
	set idx [lsearch -exact $line -file]
	if {$idx >= 0} {
	    set src [lindex $line [incr idx]]
	    	    
	    # Protect for duplicate tails.
	    set tail [file tail $src]
	    if {[info exists tailA($tail)]} {
		set suff [file extension $src]
		set root [file rootname $tail]
		set n 0
		set newTail ${root}-[incr n]$suff
		while {[info exists tailA($newTail)]} {
		    set newTail ${root}-[incr n]$suff
		}
		set dstTail $newTail
	    } else {
		set dstTail $tail
	    }
	    set tailA($dstTail) 1
	    set dst [file join $dir $dstTail]

	    # Map from original file name to vfs file name.
	    set map($src) $dst

	    lset line $idx $dstTail
	    puts $tmpfd $line
	}
    }
    close $origfd
    close $tmpfd    

    # Save as an ordinary can file inside vfs.
    set canFile [file join $dir [file tail $fileName]]
    file copy $tmp $canFile
    
    # Copy all files. Do not overwrite if already exists.
    foreach {src dst} [array get map] {
	if {![file exists $dst]} {
	    file copy $src $dst
	}
    }
}

# CanvasFile::RegisterSaveFormat, RegisterOpenFormat --
# 
#       Mechanisms for components to register new open/save formats.

proc ::CanvasFile::RegisterSaveFormat {name label suffix saveProc} {
    variable regSave
    
    set regSave($name,name)     $name
    set regSave($name,label)    $label
    set regSave($name,suffix)   $suffix
    set regSave($name,saveProc) $saveProc
    
    set regSave($suffix,suff-saveProc) $saveProc
}

proc ::CanvasFile::RegisterOpenFormat {name label suffix openProc} {
    variable regOpen
    
    set regOpen($name,name)     $name
    set regOpen($name,label)    $label
    set regOpen($name,suffix)   $suffix
    set regOpen($name,openProc) $openProc

    set regOpen($suffix,suff-openProc) $openProc
}
    
#-------------------------------------------------------------------------------
