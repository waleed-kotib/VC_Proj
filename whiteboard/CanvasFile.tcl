#  CanvasFile.tcl ---
#  
#      This file is part of The Coccinella application. It implements procedures
#      for transfering the items of a canvas to and from files.
#      
#  Copyright (c) 2002-2004  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: CanvasFile.tcl,v 1.12 2004-09-24 12:14:15 matben Exp $
 
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
#       wtop        the toplevel's namespace (::.main.::)
#       filePath    the file with canvas data.
#       
# Results:
#       none

proc ::CanvasFile::DrawCanvasItemFromFile {wtop filePath args} {
    
    set wCan [::WB::GetCanvasFromWtop $wtop]

    # Opens the data file.
    if {[catch {open $filePath r} fd]} {
	set tail [file tail $filePath]
	tk_messageBox -icon error -type ok -parent $wCan -message  \
	  [FormatTextForMessageBox [mc messfailopread $tail $fd]]
	return
    }
    eval {::CanvasFile::FileToCanvas $wCan $fd $filePath} $args
    close $fd
}

# CanvasFile::OpenCanvas --
# 
#       Just a wrapper for FileToCanvas.

proc ::CanvasFile::OpenCanvas {w fileName args} {
    
    set wtop [::UI::GetToplevelNS $w]

    # Opens the data file.
    if {[catch {open $fileName r} fd]} {
	set tail [file tail $fileName]
	tk_messageBox -message [mc messfailopread $tail $fd] \
	  -icon error -type ok
	return
    }
    ::CanvasCmd::DoEraseAll $wtop     
    ::undo::reset [::WB::GetUndoToken $wtop]
    eval {FileToCanvas $w $fd $fileName} $args
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

proc ::CanvasFile::FileToCanvasVer1 {w fd absPath args} {
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
	    puts "FileToCanvas:: Warning, didn't match tags! tags=$tags"
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
	    
	    if {$previousImageOrMovieCmd != ""} {
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
	        puts "FileToCanvas:: couldn't localize image/window"
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
	    if {$zoomOpts != ""} {
		lappend opts -zoom-factor $zoomOpts
	    }
	    
	    # Need to preserve the stacking order for images on remote clients.
	    # Add stacking order to the 'opts'.
	    if {[info exists previousUtag]} {
		lappend opts -above $previousUtag
	    }
	    
	    # Let the import procedure do the job; manufacture an option list.
	    ::Import::DoImport $w $opts -file $filePath \
	      -where $where
	    
	} else {
	    set wtop [::UI::GetToplevelNS $w]
	    
	    # Draw ordinary item not image nor window (movie).
	    if {[string equal $where "all"] || [string equal $where "local"]} {
	
		# If html font sizes, then translate these to point sizes.
		if {$prefs(useHtmlSizes) && [string equal $type "text"]} {
		    set cmdlocal [::CanvasUtils::FontHtmlToPointSize $cmdnl]
		} else {
		    set cmdlocal $cmdnl
		}
		eval {$w} $cmdlocal
	    }
	    
	    # Encode all newlines as \n .
	    regsub -all "\n" $line $nl_ cmdoneline
	    
	    # Write to other clients.
	    if {[string equal $where "all"] || [string equal $where "remote"]} {
		::CanvasUtils::Command $wtop $cmdoneline remote
	    } elseif {![string equal $where "local"]} {
		
		# Write only to specified client with ip number 'where'.
		::CanvasUtils::Command $wtop $cmdoneline $where
	    }
		
	    if {[string equal $where "all"] || [string equal $where "local"]} {

		# Run all registered hookd like speech.
		if {[string equal $type "text"]} {
		    ::hooks::run whiteboardTextInsertHook me  \
		      [$w itemcget $ittag -text]
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

proc ::CanvasFile::FileToCanvasVer2 {w fd absPath args} {
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
    set wtop [::UI::GetToplevelNS $w]
    
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
		    eval {$w} $cmdlocal
		}
		
		# Write to other clients.
		if {[string equal $where "all"] || \
		  [string equal $where "remote"]} {
		    ::CanvasUtils::Command $wtop $line "remote"
		} elseif {![string equal $where "local"]} {
		    
		    # Write only to specified client with ip number 'where'.
		    ::CanvasUtils::Command $wtop $line $where
		}
		
		# Speak...
		switch -- $where {
		    all - local {
			if {[string equal $type "text"]} {
			    ::hooks::run whiteboardTextInsertHook me \
			      [$w itemcget $utag -text]
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
		    ::Import::HandleImportCmd $w $line  \
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

# CanvasFile::SaveCanvas --
# 
#       Just a wrapper for CanvasToFile.

proc ::CanvasFile::SaveCanvas {w fileName args} {
    
    # If not .txt make sure it's .can extension.
    if {[file extension $fileName] != ".txt"} {
	set fileName "[file rootname $fileName].can"
    }

    # Opens the data file.
    if {[catch {open $fileName w} fd]} {
	set tail [file tail $fileName]
	tk_messageBox -icon error -type ok \
	  -message [mc messfailopwrite $tail $fd]
	return
    }	    
    ::CanvasFile::CanvasToFile $w $fd $fileName
    close $fd
}

# CanvasFile::CanvasToFile --
#
#       Writes line by line to file. Each line contains an almost complete 
#       canvas command except for the widget path. 
#       The file must be opened and file id given as 'fd'.
#
# Arguments:
#       w                canvas widget path.
#       fd               file descriptor of the saved file.
#       absPath          absolute path to the saved file.
#       
# Results:
#       none

proc ::CanvasFile::CanvasToFile {w fd absPath args} {
    global  this prefs
    
    Debug 2 "::CanvasFile::CanvasToFile absPath=$absPath"
    
    # When saving images or movies, save relative or absolute path names?
    # It is perhaps best to choose a path relative the actual file path of the 
    # file?
    
    array set argsArr {
	-keeputag     1
    }
    array set argsArr $args
    set argsArr(-basepath) $absPath
    
    puts $fd "# Version: 2"
    
    foreach id [$w find all] {
	set line [eval {::CanvasUtils::GetOneLinerForAny $w $id} \
	  [array get argsArr]]
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
	tk_messageBox -message [mc messfailopread $tail $fd] \
	  -icon error -type ok
	return
    }
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
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       filePath      absolute path to the save file.
#       
# Results:
#       none

proc ::CanvasFile::OpenCanvasFileDlg {wtop {filePath {}}} {
    global  prefs this
    
    set w [::UI::GetToplevel $wtop]
    set wCan [::WB::GetCanvasFromWtop $wtop]
    
    if {[string length $filePath] == 0} {
	set typelist {
	    {"Canvas"     {.can}}
	    {"XML/SVG"    {.svg}}
	    {"Text"       {.txt}}
	}
	set ans [tk_messageBox -icon warning -type okcancel -default ok \
	  -parent $w -message [mc messcanerasewarn]]
	if {$ans == "cancel"} {
	    return
	}
	set userDir [::Utils::GetDirIfExist $prefs(userPath)]
	set ans [tk_getOpenFile -title [mc {Open Canvas}]  \
	  -filetypes $typelist -defaultextension ".can"  \
	  -initialdir $userDir]
	if {$ans == ""} {
	    return
	}
	set prefs(userPath) [file dirname $ans]
	set fileName $ans
    } else {
	set fileName $filePath
    }  
    
    switch -- [file extension $fileName] {
	.svg {
	    ::undo::reset [::WB::GetUndoToken $wtop]
	    ::CanvasCmd::DoEraseAll $wtop     
	    ::CanvasFile::SVGFileToCanvas $wtop $fileName
	}
	.can {	    
	    OpenCanvas $wCan $fileName
	}
    }
}

# SaveCanvasFileDlg --
#
#       Creates a standard file save dialog, opens the file, and calls
#       'CanvasToFile' to write into it, closes it.
#
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       none

proc ::CanvasFile::SaveCanvasFileDlg {wtop} {
    global  prefs this
        
    set wCan [::WB::GetCanvasFromWtop $wtop]
    set typelist {
	{"Canvas"            {.can}}
	{"XML/SVG"           {.svg}}
	{"Text"              {.txt}}
    }
    set userDir [::Utils::GetDirIfExist $prefs(userPath)]
    set opts [list -initialdir $userDir]
    if {$prefs(haveSaveFiletypes)} {
	lappend opts -filetypes $typelist
    }
    if {[string match "mac*" $this(platform)]} {
	lappend opts -message "Pick .svg suffix for SVG, .can as default"
    }
    set ans [eval {tk_getSaveFile -title [mc {Save Canvas}] \
      -defaultextension ".can"} $opts]
    if {$ans == ""} {
	return
    }
    set prefs(userPath) [file dirname $ans]
    set fileName $ans
    set ext [file extension $fileName]
    
    switch -- $ext {
	.svg {
	    
	    # Not completely sure about -usetags.
	    ::can2svg::canvas2file $wCan $fileName -uritype file -usetags all \
	      -allownewlines 0  \
	      -windowitemhandler ::CanvasUtils::GetSVGForeignFromWindowItem
	}
	default {
	    
	    # If not .txt make sure it's .can extension.
	    if {$ext != ".txt"} {
		set fileName "[file rootname $fileName].can"
	    }
	    
	    # Opens the data file.
	    if {[catch {open $fileName w} fd]} {
		set tail [file tail $fileName]
		tk_messageBox -icon error -type ok \
		  -message [mc messfailopwrite $tail $fd]
		return
	    }	    
	    ::CanvasFile::CanvasToFile $wCan $fd $fileName
	    close $fd
	}
    }
}

# CanvasCmd::DoSaveAsItem --
# 
# 

proc ::CanvasCmd::DoSaveAsItem {wtop} {
    global  prefs this
	
    set wCan [::WB::GetCanvasFromWtop $wtop]
    set typelist {
	{"Canvas"            {.can}}
    }
    set ans [tk_getSaveFile -title [mc {Save Canvas Item}] \
      -defaultextension ".can" -initialdir $this(altItemPath) \
      -initialfile Untitled.can]
    if {$ans == ""} {
	return
    }
    set fileName $ans
    if {[catch {open $fileName w} fd]} {
	set tail [file tail $fileName]
	tk_messageBox -icon error -type ok \
	  -message [mc messfailopwrite $tail $fd]
	return
    }	    
    ::CanvasFile::CanvasToFile $wCan $fd $fileName -keeputag 0
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
	if {$absImPath != ""} {
	    set newOptList [lreplace $optList   \
	      [expr $ind + 1] [expr $ind + 1]   \
	      [filerelative $absFilePath $absImPath]]
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

proc ::CanvasFile::SVGFileToCanvas {wtop filePath} {
    
    set wCan [::WB::GetCanvasFromWtop $wtop]

    # Opens the data file.
    if {[catch {open $filePath r} fd]} {
	set tail [file tail $filePath]
	tk_messageBox -icon error -type ok -parent $wCan -message  \
	  [FormatTextForMessageBox [mc messfailopread $tail $fd]]
	return
    }
    set xml [read $fd]
    set xmllist [tinydom::documentElement [tinydom::parse $xml]]
    
    # Update the utags...
    set cmdList [svg2can::parsesvgdocument $xmllist  \
      -imagehandler [list ::CanvasFile::SVGImageHandler $wtop] \
      -foreignobjecthandler [list ::CanvasUtils::SVGForeignObjectHandler $wtop]]
    foreach cmd $cmdList {
	set utag [::CanvasUtils::NewUtag]
	set cmd [::CanvasUtils::ReplaceUtag $cmd $utag]
	eval $wCan $cmd
    }
    close $fd
}

# CanvasFile::SVGImageHandler --
# 
#       Callback for svg to canvas translator to be able to garbage collect
#       image when window closed.

proc ::CanvasFile::SVGImageHandler {wtop cmd} {
    
    #puts "::CanvasFile::SVGImageHandler cmd=$cmd"
    set idx [lsearch -regexp $cmd {-[a-z]+}]
    array set argsArr [lrange $cmd $idx end]
    return [::WB::CreateImageForWtop $wtop "" -file $argsArr(-file)]
}

#-------------------------------------------------------------------------------
