#  FilesAndCanvas.tcl ---
#  
#      This file is part of the whiteboard application. It implements procedures
#      for transfering the items of a canvas to and from files.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: FilesAndCanvas.tcl,v 1.9 2003-09-21 13:02:12 matben Exp $
 
package require can2svg
package require undo
package provide FilesAndCanvas 1.0

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
    
    set wCan [::UI::GetCanvasFromWtop $wtop]

    # Opens the data file.
    if {[catch {open $filePath r} fd]} {
	set tail [file tail $filePath]
	tk_messageBox -icon error -type ok -parent $wCan -message  \
	  [FormatTextForMessageBox [::msgcat::mc messfailopread $tail $fd]]
	return
    }
    eval {::CanvasFile::FileToCanvas $wCan $fd $filePath} $args
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
		lappend opts -zoomfactor $zoomOpts
	    }
	    
	    # Need to preserve the stacking order for images on remote clients.
	    # Add stacking order to the 'opts'.
	    if {[info exists previousUtag]} {
		lappend opts -above $previousUtag
	    }
	    
	    # Let the import procedure do the job; manufacture an option list.
	    ::ImageAndMovie::DoImport $w $opts -file $filePath \
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
		::CanvasUtils::Command $wtop $cmdoneline "remote"
	    } elseif {![string equal $where "local"]} {
		
		# Write only to specified client with ip number 'where'.
		::CanvasUtils::Command $wtop $cmdoneline $where
	    }
		
	    # Speak...
	    if {[string equal $where "all"] || [string equal $where "local"]} {
		if {$prefs(SpeechOn) && [string equal $type "text"]} {
		    ::UserActions::Speak [$w itemcget $ittag -text] $prefs(voiceUs)
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
    upvar ::UI::icons icons
    
    Debug 2 "FileToCanvasVer2 absPath=$absPath args='$args'"
    
    array set argsArr {
	-showbroken   1
	-tryimport    1
	-where        all
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
    
    set numImports 0
    
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
	    set utag [::CanvasUtils::GetUtagFromCmd $line]
	}
	
	switch -- $cmd {
	    create {
	    
		# Draw ordinary item not image nor window (movie).
		set type [lindex $line 1]
	
		# Make newline substitutions.
		set cmdnl [subst -nocommands -novariables $line]
		if {[string equal $where "all"] || \
		  [string equal $where "local"]} {
		    
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
		if {[string equal $where "all"] || \
		  [string equal $where "remote"]} {
		    ::CanvasUtils::Command $wtop $cmdoneline "remote"
		} elseif {![string equal $where "local"]} {
		    
		    # Write only to specified client with ip number 'where'.
		    ::CanvasUtils::Command $wtop $cmdoneline $where
		}
		
		# Speak...
		if {[string equal $where "all"] || \
		  [string equal $where "local"]} {
		    if {$prefs(SpeechOn) && [string equal $type "text"]} {
			::UserActions::Speak [$w itemcget $utag -text] $prefs(voiceUs)
		    }
		}
	    }
	    import {
		set errMsg ""

		# Assume the order in the file is also stacking order.
		if {[info exists previousUtag]} {
		    lappend line -above $previousUtag
		} 
		    
		# To get the -below value we need a trick.
		# Make the next utag to use.
		set nextUtag [::CanvasUtils::NewUtag]
		lappend line -below $nextUtag

		if {$argsArr(-tryimport)} {
		    
		    # This is typically an image or movie (QT or Snack).
		    set errMsg [::ImageAndMovie::HandleImportCmd $w $line \
		      -where $where -basepath $dirPath \
		      -progess [list ::ImageAndMovie::ImportProgress $line] \
		      -command [list ::ImageAndMovie::ImportCommand $line]]
		}
		if {$argsArr(-showbroken) &&  \
		  (($errMsg != "") || !$argsArr(-tryimport))} {

		    # Display a broken image to indicate for the user.
		    eval {::ImageAndMovie::NewBrokenImage $w [lrange $line 1 2]} \
		      [lrange $line 3 end]
		}
		incr numImports
	    }
	    default {

		# Here we should provide some hooks for plugins to handle
		# their own stuff. ???
		# Or handled elsewhere???
	    }
	}
	set previousUtag $utag
    }
    return $numImports
}

# CanvasFile::CanvasToFile --
#
#       Writes line by line to file. Each line contains an almost complete 
#       canvas command except for the widget path. 
#       The file must be opened and file id given as 'fd'.
#       If 'filePathsAbsolute' the -file option contains the full path name, 
#       else relative path name to this script path.
#
# Arguments:
#       w                canvas widget path.
#       fd               file descriptor of the saved file.
#       absPath          absolute path to the saved file.
#       
# Results:
#       none

proc ::CanvasFile::CanvasToFile {w fd absPath} {
    global  this prefs
    
    Debug 2 "::CanvasFile::CanvasToFile absPath=$absPath"
    
    # When saving images or movies, save relative or absolute path names?
    # It is perhaps best to choose a path relative the actual file path of the 
    # file?
    
    set filePathsAbsolute 0    
    puts $fd "# Version: 2"
    
    foreach id [$w find all] {
	
	# Do not save grid or markers.
	set tags [$w gettags $id]
	if {([lsearch $tags grid] >= 0) || ([lsearch $tags tbbox] >= 0)} {
	    continue
	}
	set type [$w type $id]

	switch -- $type {
	    image {
		set line [::CanvasUtils::GetOnelinerForImage $w $id  \
		  -basepath $absPath]
		puts $fd $line
	    } 
	    window {
		
		# A movie: for QT we have a complete widget; 
		set windowName [$w itemcget $id -window]
		set windowClass [winfo class $windowName]
		
		switch -- $windowClass {
		    QTFrame {
			set line [::CanvasUtils::GetOnelinerForQTMovie $w $id \
			  -basepath $absPath]
			puts $fd $line		    
		    }
		    SnackFrame {			
			set line [::CanvasUtils::GetOnelinerForSnack $w $id \
			  -basepath $absPath]
			puts $fd $line		    
		    }
		    XanimFrame {
			# ?
		    }
		    default {
			if {[::Plugins::HaveSaveProcForWinClass $windowClass]} {
			    set procName \
			      [::Plugins::GetSaveProcForWinClass $windowClass]
			    set line [$procName $w $id]
			    if {$line != ""} {
				puts $fd $line		    
			    }
			}
		    }
		}
	    }
	    default {
	
		# A standard canvas item.	
		# Skip text items without any text.	
		if {($type == "text") && ([$w itemcget $id -text] == "")} {
		    continue
		}
		set cmd [::CanvasUtils::GetOnelinerForItem $w $id]
		puts $fd $cmd
	    }
	}
    }
}

# CanvasFile::DataToFile --
#
#       Writes a list of canvas commands to a file.

proc ::CanvasFile::DataToFile {filePath canvasList} {
    
    if {[catch {open $filePath w} fd]} {
	set tail [file tail $filePath]
	tk_messageBox -message [::msgcat::mc messfailopread $tail $fd] \
	  -icon error -type ok
	return
    }
    puts $fd "# Version: 2"

    # Be sure to strip off the "CANVAS:" prefix.
    foreach line $canvasList {
	if {[string equal [lindex $line 0] "CANVAS:"]} {
	    puts $fd [lrange $line 1 end]
	} else {
	    puts $fd $line
	}
    }
    close $fd
}

# DoOpenCanvasFile --
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

proc ::CanvasFile::DoOpenCanvasFile {wtop {filePath {}}} {
    global  prefs
    
    set w [::UI::GetToplevel $wtop]
    set wCan [::UI::GetCanvasFromWtop $wtop]
    
    if {[string length $filePath] == 0} {
	set typelist {
	    {"Canvas"     {.can}}
	    {"Text"       {.txt}}
	}
	set ans [tk_messageBox -icon warning -type okcancel -default ok \
	  -parent $w -message [::msgcat::mc messcanerasewarn]]
	if {$ans == "cancel"} {
	    return
	}
	set userDir [::Utils::GetDirIfExist $prefs(userDir)]
	set ans [tk_getOpenFile -title [::msgcat::mc {Open Canvas}]  \
	  -filetypes $typelist -defaultextension ".can"  \
	  -initialdir $userDir]
	if {$ans == ""} {
	    return
	}
	set prefs(userDir) [file dirname $ans]
	set fileName $ans
    } else {
	set fileName $filePath
    }  
    
    # Opens the data file.
    if {[catch {open $fileName r} fd]} {
	set tail [file tail $fileName]
	tk_messageBox -message [::msgcat::mc messfailopread $tail $fd] \
	  -icon error -type ok
	return
    }
    ::undo::reset [::UI::GetUndoToken $wtop]
    ::UserActions::DoEraseAll $wtop     
    FileToCanvas $wCan $fd $fileName
    close $fd
}

# DoSaveCanvasFile --
#
#       Creates a standard file save dialog, opens the file, and calls
#       'CanvasToFile' to write into it, closes it.
#
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       none

proc ::CanvasFile::DoSaveCanvasFile {wtop} {
    global  prefs this
        
    set wCan [::UI::GetCanvasFromWtop $wtop]
    set typelist {
	{"Canvas"            {.can}}
	{"Adobe XML/SVG"     {.svg}}
	{"Text"              {.txt}}
    }
    set userDir [::Utils::GetDirIfExist $prefs(userDir)]
    set opts [list -initialdir $userDir]
    if {$prefs(haveSaveFiletypes)} {
	lappend opts -filetypes $typelist
    }
    if {[string match "mac*" $this(platform)]} {
	lappend opts -message "Pick .svg suffix for XML, .can as default"
    }
    set ans [eval {tk_getSaveFile -title [::msgcat::mc {Save Canvas}] \
      -defaultextension ".can"} $opts]
    if {$ans == ""} {
	return
    }
    set prefs(userDir) [file dirname $ans]
    set fileName $ans
    set ext [file extension $fileName]
    switch -- $ext {
	".svg" {
	    ::can2svg::canvas2file $wCan $fileName	    
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
		  -message [::msgcat::mc messfailopwrite $tail $fd]
		return
	    }	    
	    ::CanvasFile::CanvasToFile $wCan $fd $fileName
	    close $fd
	}
    }
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
#-------------------------------------------------------------------------------