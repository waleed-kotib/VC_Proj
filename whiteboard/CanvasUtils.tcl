#  CanvasUtils.tcl ---
#  
#      This file is part of The Coccinella application. It implements some
#      miscellaneous utilities for canvas operations.
#      
#  Copyright (c) 2000-2004  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: CanvasUtils.tcl,v 1.9 2004-08-02 14:06:21 matben Exp $

package require sha1pure

package provide CanvasUtils 1.0


namespace eval ::CanvasUtils:: {
    
    variable itemAfterId
    variable popupVars
}

proc ::CanvasUtils::Init { } {
    global  this prefs env
    variable utaguid
    variable utagpref
    variable utagpref2
    variable importAnchor
    
    ::Debug 2 "::CanvasUtils::Init"
    
    # Present anchor coordinates when importing images and movies.
    # Gets translated with 'prefs(offsetCopy)' for each new imported item.
    set importAnchor(x) $prefs(offsetCopy)
    set importAnchor(y) $prefs(offsetCopy)
    
    # Running tag number must be unique for each item.
    # It is always used in conjunction with the local prefix as $prefix/$itno.
    # It is *never* reused during the lifetime of the application.
    # It is updated *only* when writing to own canvas.
    # When the server part writes to the canvas it is the prefix/no of the
    # remote client that is used.
    # Need to make sure we don't get: "integer value too large to represent"
    
    if {[catch {
        set utaguid [format %i 0x[string range [sha1pure::sha1 [clock clicks]$this(hostname)] 0 6]]
    }]} {
        set utaguid [string trimleft [string range [expr rand()] 2 10] 0]
    }
    
    # Unique tag prefix for items created by this client.
    set utagpref $this(hostname)
    if {$utagpref == ""} {
        set utagpref $this(internalIPname)
    }
    
    # Incompatible change!!!
    if {$this(ipver) == 4} {
	set utagpref2 "u[eval {format %02x%02x%02x%02x} [split $this(ipnum) .]]"
    } else {
	
	# Needs to be investigated!
	set utagpref2 "u[join [split $this(ipnum) :] ""]"
    }
    
    # On multiuser platforms (unix) prepend the user name; no spaces allowed.
    if {[string equal $this(platform) "unix"] && [info exists env(USER)]} {
        set user $this(username)
        regsub -all " " $user "" user
        set utagpref ${user}@${utagpref}
    }

    # Popup menu definitions for the canvas. First definitions of individual entries.
    variable menuDefs
    
    set menuDefs(pop,thickness)  \
      {cascade     mThickness     {}                                       normal   {} {} {
	{radio   1 {::CanvasUtils::ItemConfigure $w $id -width 1}          normal   {} \
	  {-variable ::CanvasUtils::popupVars(-width)}}
	{radio   2 {::CanvasUtils::ItemConfigure $w $id -width 2}          normal   {} \
	  {-variable ::CanvasUtils::popupVars(-width)}}
	{radio   4 {::CanvasUtils::ItemConfigure $w $id -width 4}          normal   {} \
	  {-variable ::CanvasUtils::popupVars(-width)}}
	{radio   6 {::CanvasUtils::ItemConfigure $w $id -width 6}          normal   {} \
	  {-variable ::CanvasUtils::popupVars(-width)}}}
    }
    set menuDefs(pop,brushthickness)  \
      {cascade     mBrushThickness  {}                                     normal   {} {} {
	{radio   8 {::CanvasUtils::ItemConfigure $w $id -width 8}          normal   {} \
	  {-variable ::CanvasUtils::popupVars(-brushwidth)}}
	{radio  10 {::CanvasUtils::ItemConfigure $w $id -width 10}         normal   {} \
	  {-variable ::CanvasUtils::popupVars(-brushwidth)}}
	{radio  12 {::CanvasUtils::ItemConfigure $w $id -width 12}         normal   {} \
	  {-variable ::CanvasUtils::popupVars(-brushwidth)}}
	{radio  14 {::CanvasUtils::ItemConfigure $w $id -width 14}         normal   {} \
	  {-variable ::CanvasUtils::popupVars(-brushwidth)}}}
    }
    set menuDefs(pop,arcs)  \
      {cascade   mArcs      {}                                      normal   {} {} {
	{radio   mPieslice  {::CanvasUtils::ItemConfigure $w $id -style pieslice}  normal   {} \
	  {-value pieslice -variable ::CanvasUtils::popupVars(-arc)}}
	{radio   mChord     {::CanvasUtils::ItemConfigure $w $id -style chord}     normal   {} \
	  {-value chord -variable ::CanvasUtils::popupVars(-arc)}}
	{radio   mArc       {::CanvasUtils::ItemConfigure $w $id -style arc}       normal   {} \
	  {-value arc -variable ::CanvasUtils::popupVars(-arc)}}}
    }
    set menuDefs(pop,color)  \
      {command   mColor        {::CanvasUtils::SetItemColorDialog $w $id -fill}  normal {}}
    set menuDefs(pop,fillcolor)  \
      {command   mFillColor    {::CanvasUtils::SetItemColorDialog $w $id -fill}  normal {}}
    set menuDefs(pop,outline)  \
      {command   mOutlineColor {::CanvasUtils::SetItemColorDialog $w $id -outline}  normal {}}
    set menuDefs(pop,inspect)  \
      {command   mInspectItem  {::ItemInspector::ItemInspector $wtop $id}   normal {}}
    set menuDefs(pop,inspectqt)  \
      {command   mInspectItem  {::ItemInspector::Movie $wtop $winfr}        normal {}}
    set menuDefs(pop,saveimageas)  \
      {command   mSaveImageAs  {::Import::SaveImageAsFile $w $id}    normal {}}
    set menuDefs(pop,imagelarger)  \
      {command   mImageLarger  {::Import::ResizeImage $wtop 2 $id auto}   normal {}}
    set menuDefs(pop,imagesmaller)  \
      {command   mImageSmaller {::Import::ResizeImage $wtop -2 $id auto}   normal {}}
    set menuDefs(pop,exportimage)  \
      {command   mExportImage  {::Import::ExportImageAsFile $w $id}  normal {}}
    set menuDefs(pop,exportmovie)  \
      {command   mExportMovie  {::Import::ExportMovie $wtop $winfr}  normal {}}
    set menuDefs(pop,inspectbroken)  \
      {command   mInspectItem  {::ItemInspector::Broken $wtop $id}          normal {}}
    set menuDefs(pop,reloadimage)  \
      {command   mReloadImage  {::Import::ReloadImage $wtop $id}     normal {}}
    set menuDefs(pop,smoothness)  \
      {cascade     mLineSmoothness   {}                                    normal   {} {} {
	{radio None {::CanvasUtils::ItemConfigure $w $id -smooth 0 -splinesteps  0} normal {} \
	  {-value 0 -variable ::CanvasUtils::popupVars(-smooth)}}
	{radio 2    {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps  2} normal {} \
	  {-value 2 -variable ::CanvasUtils::popupVars(-smooth)}}
	{radio 4    {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps  4} normal {} \
	  {-value 4 -variable ::CanvasUtils::popupVars(-smooth)}}
	{radio 6    {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps  6} normal {} \
	  {-value 6 -variable ::CanvasUtils::popupVars(-smooth)}}
	{radio 10   {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps 10} normal {} \
	  {-value 10 -variable ::CanvasUtils::popupVars(-smooth)}}}
    }
    set menuDefs(pop,smooth)  \
      {checkbutton mLineSmoothness   {::CanvasUtils::ItemSmooth $w $id}    normal   {} \
      {-variable ::CanvasUtils::popupVars(-smooth) -offvalue 0 -onvalue 1}}
    set menuDefs(pop,straighten)  \
      {command     mStraighten       {::CanvasUtils::ItemStraighten $w $id} normal   {} {}}
    set menuDefs(pop,font)  \
      {cascade     mFont             {}                                    normal   {} {} {}}
    set menuDefs(pop,fontsize)  \
      {cascade     mSize             {}                                    normal   {} {} {
	{radio   1  {::CanvasUtils::SetTextItemFontSize $w $id 1}          normal   {} \
	  {-variable ::CanvasUtils::popupVars(-fontsize)}}
	{radio   2  {::CanvasUtils::SetTextItemFontSize $w $id 2}          normal   {} \
	  {-variable ::CanvasUtils::popupVars(-fontsize)}}
	{radio   3  {::CanvasUtils::SetTextItemFontSize $w $id 3}          normal   {} \
	  {-variable ::CanvasUtils::popupVars(-fontsize)}}
	{radio   4  {::CanvasUtils::SetTextItemFontSize $w $id 4}          normal   {} \
	  {-variable ::CanvasUtils::popupVars(-fontsize)}}
	{radio   5  {::CanvasUtils::SetTextItemFontSize $w $id 5}          normal   {} \
	  {-variable ::CanvasUtils::popupVars(-fontsize)}}
	{radio   6  {::CanvasUtils::SetTextItemFontSize $w $id 6}          normal   {} \
	  {-variable ::CanvasUtils::popupVars(-fontsize)}}}
    }
    set menuDefs(pop,fontweight)  \
      {cascade     mWeight           {}                                    normal   {} {} {
	{radio   mNormal {::CanvasUtils::SetTextItemFontWeight $w $id normal} normal   {} \
	  {-value normal -variable ::CanvasUtils::popupVars(-fontweight)}}
	{radio   mBold {::CanvasUtils::SetTextItemFontWeight $w $id bold}  normal   {} \
	  {-value bold   -variable ::CanvasUtils::popupVars(-fontweight)}}
	{radio   mItalic {::CanvasUtils::SetTextItemFontWeight $w $id italic} normal   {} \
	  {-value italic -variable ::CanvasUtils::popupVars(-fontweight)}}}
    }	
    set menuDefs(pop,speechbubble)  \
      {command   mAddSpeechBubble  {::CanvasDraw::MakeSpeechBubble $w $id}   normal {}}
    
    # Dashes need a special build process.
    set dashList {}
    foreach dash [lsort -decreasing [array names ::WB::dashFull2Short]] {
	set dashval $::WB::dashFull2Short($dash)
	if {[string equal " " $dashval]} {
	    set dopts {-value { } -variable ::CanvasUtils::popupVars(-dash)}
	} else {
	    set dopts [format {-value %s -variable ::CanvasUtils::popupVars(-dash)} $dashval]
	}
	lappend dashList [list radio $dash {} normal {} $dopts]
    }
    set menuDefs(pop,dash)  \
      [list cascade   mDash          {}              normal   {} {} $dashList]
    
    # Now assemble menus from the individual entries above. List of which entries where.
    array set menuArr {
	arc        {thickness fillcolor outline dash arcs inspect}
	brush      {brushthickness color smooth inspect}
	image      {saveimageas imagelarger imagesmaller exportimage inspect}
	line       {thickness dash smooth straighten inspect}
	oval       {thickness outline fillcolor dash inspect}
	pen        {thickness smooth inspect}
	polygon    {thickness outline fillcolor dash smooth straighten inspect}
	rectangle  {thickness fillcolor dash inspect}
	text       {font fontsize fontweight color speechbubble inspect}
	window     {}
	qt         {inspectqt exportmovie}
	snack      {}
	broken     {inspectbroken reloadimage}
    }
    foreach name [array names menuArr] {
	set menuDefs(pop,$name) {}
	foreach key $menuArr($name) {
	    lappend menuDefs(pop,$name) $menuDefs(pop,$key)
	}
    }    
}

# CanvasUtils::Command --
#
#       Executes a canvas command both in the local canvas and all remotely
#       connected. Useful for implementing Undo/Redo.
#       
# Arguments:
#       wtop    namespaced toplevel (.top.)
#       cmd     canvas command without canvasPath
#       where   (D="all"):
#               "local"  only local canvas
#               "remote" only remote canvases
#               ip       name or number; send only to this address, not local.

proc ::CanvasUtils::Command {wtop cmd {where all}} {
    
    set w [::WB::GetCanvasFromWtop $wtop]
    if {[string equal $where "all"] || [string equal $where "local"]} {
	
	# Make drawing in own canvas.
        eval {$w} $cmd
    }
    if {![string equal $where "local"]} {
	
	# This call just invokes any registered drawing hook.
	::WB::SendMessageList $wtop [list $cmd]
    }
}

# CanvasUtils::CommandList --
#
#       Gives an opportunity to have a list of commands to be executed.

proc ::CanvasUtils::CommandList {wtop cmdList {where all}} {
    
    foreach cmd $cmdList {
        ::CanvasUtils::Command $wtop $cmd $where
    }
}

# CanvasUtils::CommandExList --
#
#       Makes it possible to have different commands local and remote.

proc ::CanvasUtils::CommandExList {wtop cmdExList} {
    
    foreach cmdList $cmdExList {
        foreach {cmd where} $cmdList {
            ::CanvasUtils::Command $wtop $cmd $where
        }
    }
}

# CanvasUtils::GenCommand, ... --
# 
#       Identical to the procedures above but are not constrained to the
#       "CANVAS:" prefix. The prefix shall be included in 'cmd'.

proc ::CanvasUtils::GenCommand {wtop cmd {where all}} {
    
    set w [::WB::GetCanvasFromWtop $wtop]
    if {[string equal $where "all"] || [string equal $where "local"]} {
        eval {$w} $cmd
    }
    if {![string equal $where "local"]} {
	
	# This call just invokes any registered drawing hook.
	::WB::SendGenMessageList $wtop [list $cmd]
    }
}

proc ::CanvasUtils::GenCommandList {wtop cmdList {where all}} {
    
    foreach cmd $cmdList {
        ::CanvasUtils::GenCommand $wtop $cmd $where
    }
}

proc ::CanvasUtils::GenCommandExList {wtop cmdExList} {
    
    foreach cmdList $cmdExList {
        foreach {cmd where} $cmdList {
            ::CanvasUtils::GenCommand $wtop $cmd $where
        }
    }
}

# CanvasUtils::NewUtag --
#
#       Return unique id tag for a canvas item.

proc ::CanvasUtils::NewUtag {{doincr 1}} {
    variable utaguid
    variable utagpref
    variable utagpref2
    
    if {$doincr} {
        incr utaguid
    }
    
    # Incompatible change!
    return ${utagpref}/${utaguid}
    #return ${utagpref2}/${utaguid}
}

# CanvasUtils::GetUtag --
#   
#       Finds the specific item identifier from 'fromWhat'.
#      If 'privacy' then returns empty string of not item made here or
#      if made by xxx...
#   
# Arguments:
#       c         the canvas widget path.
#       fromWhat  "current": picks the current item
#                 "focus": picks the item that has focus
#                 canvas id number: takes the specified canvas id
#       force     If 'force' then do not respect privacy.
#       
# Results:
#       app specific item identifier

proc ::CanvasUtils::GetUtag {c fromWhat {force 0}} {
    global  prefs
    variable utagpref
    variable utagpref2
    
    # Find the 'utag'.
    set pre_ {[^/ ]+}
    set digits_ {[0-9]+}
    set wild_ {[xX\*]+}
    set utagpre_ ${wild_}|${utagpref}|${utagpref2}
    
    if {[string equal $fromWhat "current"]} {
        set tags [$c gettags current]
    } elseif {[string equal $fromWhat "focus"]} {
        set tags [$c gettags [$c focus]]
    } else {
        set tags [$c gettags $fromWhat]
    }
    if {$tags == ""} {
        return ""
    }
    if {$prefs(privacy) && !$force} {
	
	# Need to be compatible with both 'utagpref' and 'utagpref2'!
	# Introduced with 0.94.4
	return [lsearch -inline -regexp $tags "${utagpre_}/${digits_}"]
    } else {
	return [lsearch -inline -regexp $tags "${pre_}/${digits_}"]
    }
}

# CanvasUtils::GetUtagPrefix --
#
#       Returns the unique tag prefix for this client.

proc ::CanvasUtils::GetUtagPrefix { } {
    variable utagpref
    
    return $utagpref
}

# CanvasUtils::GetUtagFromCmd --
#
#       Takes a canvas command and returns the utag if any.

proc ::CanvasUtils::GetUtagFromCmd {str} {
    
    set ind [lsearch -exact $str "-tags"]
    if {$ind >= 0} {
	return [lsearch -inline -regexp [lindex $str [incr ind]]  \
	  {^[^/ ]+/[0-9]+$}]
    } else {  
	return ""
    }
}

proc ::CanvasUtils::GetUtagFromTagList {tags} {
    
    return [lsearch -inline -regexp $tags {^[^/ ]+/[0-9]+$}]
}

# CanvasUtils::ReplaceUtag --
#
#       Takes a canvas command and replaces the utag with new utag.

proc ::CanvasUtils::ReplaceUtag {str newUtag} {
    
    set ind [lsearch -exact $str "-tags"]
    if {$ind >= 0} {
        set tags [lindex $str [incr ind]]
        if {[regsub {[^/ ]+/[0-9]+} $tags $newUtag tags]} {
            lset str $ind $tags
	}
    }    
    return $str
}

proc ::CanvasUtils::ReplaceUtagPrefix {str prefix} {
    
    set ind [lsearch -exact $str "-tags"]
    if {$ind >= 0} {
	set tags [lindex $str [incr ind]]
	if {[regsub {[^/ ]+(/[0-9]+)} $tags $prefix\\1 tags]} {
	    lset str $ind $tags
	}
    }    
    return $str
}

# CanvasUtils::GetUndoCommand --
#
#       Finds the inverse canvas command. The actual item is assumed
#       to exist except for the 'create' method.
#   
# Arguments:
#       cmd         a canvas command without pathName.
#       
# Results:
#       a complete command

proc ::CanvasUtils::GetUndoCommand {wtop cmd} {
    
    set w [::WB::GetCanvasFromWtop $wtop]
    set undo {}
    
    switch -- [lindex $cmd 0] {
	coords {
	    set utag [lindex $cmd 1]
	    set canUndo [concat [list coords $utag] [$w coords $utag]]
	    set undo [list ::CanvasUtils::Command $wtop $canUndo]	
	}
	create {
	    set utag [::CanvasUtils::GetUtagFromCmd $cmd]
	    if {$utag != ""} {
		set canUndo [list delete $utag]
		set undo [list ::CanvasUtils::Command $wtop $canUndo]	
	    }
	}
	dchars {
	    set utag [lindex $cmd 1]
	    set ind [lindex $cmd 2]
	    set ilast [lindex $cmd end]
	    set thetext [$w itemcget $utag -text]
	    set str [string range $thetext $ind $ilast]
	    set canUndo [list insert $utag $ind $str]
	    set undo [list ::CanvasUtils::Command $wtop $canUndo]	
	}
	delete {
	    set utag [lindex $cmd 1]
	    set type [$w type $utag]
	    
	    switch -- $type {
		image - window {
		    set line [::CanvasUtils::GetOneLinerForAny $w $utag \
		      -usehtmlsize 0 -encodenewlines 0]
		    if {[string equal [lindex $line 0] "import"]} {
			set undo [list ::Import::HandleImportCmd $w $line \
			  -addundo 0]
		    } else {
			set stackCmd [::CanvasUtils::GetStackingCmd $w $utag]
			set canUndoList [list $line $stackCmd]
			set undo [list ::CanvasUtils::CommandList $wtop $canUndoList]	
		    }
		}
		default {
		    set co [$w coords $utag]
		    set opts [GetItemOpts $w $utag]
		    set createCmd [concat [list create $type] $co $opts]
		    set stackCmd [::CanvasUtils::GetStackingCmd $w $utag]
		    set canUndoList [list $createCmd $stackCmd]
		    set undo [list ::CanvasUtils::CommandList $wtop $canUndoList]	
		}
	    }
	}
	insert {
	    foreach {dum utag ind str} $cmd break
	    set canUndo [list dchars $utag $ind [expr $ind + [string length $str]]]
	    set undo [list ::CanvasUtils::Command $wtop $canUndo]	
	}
	move {
	    foreach {dum utag dx dy} $cmd break
	    set canUndo [list move $utag [expr -$dx] [expr -$dy]]
	    set undo [list ::CanvasUtils::Command $wtop $canUndo]	
	}
	lower - raise {
	    set utag [lindex $cmd 1]
	    set canUndo [GetStackingCmd $w $utag]
	    set undo [list ::CanvasUtils::Command $wtop $canUndo]	
	}
    }
    return $undo
}

# CanvasUtils::GetOneLinerForAny --
#
#       Dispatcher for the GetOneLiner procs.
#       
# Arguments:
#       w           canvas
#       id          item id or tag
#       args:
#           -basepath absolutePath    translate image -file to a relative path.
#           -uritype ( file | http )
#           -keeputag 0|1
#           -usehtmlsize 0|1
#           -encodenewlines 0|1
#       
# Results:
#       a single command line.

proc ::CanvasUtils::GetOneLinerForAny {w id args} {
    global  prefs

    array set argsArr {
	-keeputag     1
    }
    array set argsArr $args
    set keeputag $argsArr(-keeputag)
    
    set tags [$w gettags $id]
    set type [$w type $id]
    set havestd [expr [lsearch -exact $tags std] < 0 ? 0 : 1]
    set line ""
 
    switch -glob -- $type,$havestd {
	image,1 {
	    set line [eval {::CanvasUtils::GetOnelinerForImage $w $id} $args]
	    if {!$keeputag} {
		set line [::CanvasUtils::ReplaceUtagPrefix $line *]
	    }
	} 
	window,* {
	    set line [eval {::CanvasUtils::GetOneLinerForWindow $w $id} $args]
	    if {$line != {}} {
		if {!$keeputag} {
		    set line [::CanvasUtils::ReplaceUtagPrefix $line *]
		}
	    }
	}
	*,1 {
    
	    # A standard canvas item with 'std' tag.	
	    # Skip text items without any text.	
	    if {($type == "text") && ([$w itemcget $id -text] == "")} {
		# empty
	    } else {
		set line [eval {::CanvasUtils::GetOneLinerForItem $w $id} $args]
		if {!$keeputag} {
		    set line [::CanvasUtils::ReplaceUtagPrefix $line *]
		}
	    }
	}
	default {
	    
	    # A non window item witout 'std' tag.
	    # Look for any Itcl object with a Save method.
	    if {$prefs(haveItcl)} {
		if {[regexp {object:([^ ]+)} $tags match object]} {
		    if {![catch {
			eval {$object Save $id} $args
		    } ans]} {
			set line $ans
		    }
		}
	    }
	}
    }
    return $line
}

proc ::CanvasUtils::GetOneLinerForWindow {w id args} {
       
    # A movie: for QT we have a complete widget; 
    set windowName [$w itemcget $id -window]
    set windowClass [winfo class $windowName]
    set line {}
    
    switch -- $windowClass {
	QTFrame {
	    set line [eval {
		::CanvasUtils::GetOnelinerForQTMovie $w $id} $args]
	}
	SnackFrame {			
	    set line [eval {
		::CanvasUtils::GetOnelinerForSnack $w $id} $args]
	}
	XanimFrame {
	    # ?
	}
	default {
	    if {[::Plugins::HaveSaveProcForWinClass $windowClass]} {
		set procName \
		  [::Plugins::GetSaveProcForWinClass $windowClass]
		set line [eval {$procName $w $id} $args]
	    }
	}
    }
    return $line
}

# CanvasUtils::GetOneLinerForItem --
#
#       Returns an item as a single line suitable for storing on file or
#       sending on network. Not for images or windows!
#       Doesn't add values equal to defaults.

proc ::CanvasUtils::GetOneLinerForItem {w id args} {
    global  prefs fontPoints2Size
    
    array set argsArr {
	-encodenewlines 1
	-usehtmlsize    1
    }
    array set argsArr $args
    
    set opts [$w itemconfigure $id]
    set type [$w type $id]
    if {[string equal $type "image"] || [string equal $type "window"]} {
	return -code error "items of type \"$type\" not allowed here"
    }
    set opcmd {}
    set nl_ {\\n}
    
    foreach opt $opts {
	set op [lindex $opt 0]
	set defval [lindex $opt 3]
	set val [lindex $opt 4]
	if {[string equal $defval $val]} {
	    continue
	}
	
	switch -- $op {
	    -text {
		if {$argsArr(-encodenewlines)} {
		    
		    # If multine text, encode as one line with explicit "\n".
		    regsub -all "\n" $val $nl_ oneliner
		    regsub -all "\r" $oneliner $nl_ oneliner
		    set val $oneliner
		}
	    }
	    -tags {
	    
		# Any tags "current" or "selected" must be removed 
		# before save, else when writing them on canvas things 
		# become screwed up.		
		set val [lsearch -all -not -inline $val current]
		set val [lsearch -all -not -inline $val selected]
		
		# Verify that we have a correct taglist.
		set val [lsort -unique [concat std $type $val]]
	    }
	    -smooth {
	    
		# Seems to be a bug in tcl8.3; -smooth should be 0/1, 
		# not bezier.		
		if {$val == "bezier"} {
		    set val 1
		}
	    }
	}
	if {($op == "-font") && $argsArr(-usehtmlsize) && $prefs(useHtmlSizes)} {
	    set val [lreplace $val 1 1 $fontPoints2Size([lindex $val 1])]
	}
	lappend opcmd $op $val
    }
    
    return [concat "create" $type [$w coords $id] $opcmd]
}

# CanvasUtils::GetOnelinerForImage, ..QTMovie, ..Snack --
#
#       Makes a line that is suitable for file storage. Shall be understood
#       by '::Import::HandleImportCmd'.
#       It takes an existing image in a canvas and returns an 'import ...' 
#       command.
#
# Arguments:
#       w           the canvas widget
#       id
#       args:
#           -basepath absolutePath    translate image -file to a relative path.
#           -uritype ( file | http )

proc ::CanvasUtils::GetOnelinerForImage {w id args} {
    
    set type [$w type $id]
    if {![string equal $type "image"]} {
	return -code error "must have an \"image\" item type"
    }
    array set argsArr {
	-uritype file
    }
    array set argsArr $args
    set wtop [::UI::GetToplevelNS $w]
    
    # The 'broken image' options are cached.
    # This can be anything imported, it is just represented as an image.
    set isbroken [expr {[lsearch [$w itemcget $id -tags] broken] < 0} ? 0 : 1]
    array set impArr [::CanvasUtils::ItemCGet $wtop $id]
        
    # Real images needs more processing.
    if {!$isbroken} {
	set imageName [$w itemcget $id -image]
   
	# Find out if zoomed.		
	if {[regexp {(.+)_zoom(|-)([0-9]+)} $imageName match origImName \
	  sign factor]} {
	    
	    # Find out the '-file' option from the original image.
	    set imageFile [$origImName cget -file]
	    set impArr(-zoom-factor) ${sign}${factor}
	} else {
	    set imageFile [$imageName cget -file]		    
	}
	set impArr(-width) [image width $imageName]
	set impArr(-height) [image height $imageName]
	
	unset -nocomplain impArr(-file) impArr(-url)
	array set impArr [eval {
	    ::CanvasUtils::GetImportOptsURI $argsArr(-uritype) $imageFile
	} $args]
	set impArr(-mime) [::Types::GetMimeTypeForFileName $imageFile]
    }
    
    # -above & -below??? Be sure to overwrite any cached options.
    array set impArr [::CanvasUtils::GetStackingOption $w $id]
    set impArr(-tags) [::CanvasUtils::GetUtag $w $id 1]

    return [concat import [$w coords $id] [array get impArr]]
}

proc ::CanvasUtils::GetOnelinerForQTMovie {w id args} {
        
    array set argsArr {
	-uritype file
    }
    array set argsArr $args

    set wtop [::UI::GetToplevelNS $w]
    set opts [::CanvasUtils::GetItemOpts $w $id]
    set opts [concat $opts [::CanvasUtils::ItemCGet $wtop $id]]
    set cmd  [concat create window [$w coords $id] $opts]
    return [eval {::CanvasUtils::GetImportCmdForQTMovie $cmd} $args]
}

proc ::CanvasUtils::GetOnelinerForSnack {w id args} {
    
    array set argsArr {
	-uritype file
    }
    array set argsArr $args
    
    set wtop [::UI::GetToplevelNS $w]
    set opts [::CanvasUtils::GetItemOpts $w $id]
    set opts [concat $opts [::CanvasUtils::ItemCGet $wtop $id]]
    set cmd  [concat create window [$w coords $id] $opts]
    return [eval {::CanvasUtils::GetImportCmdForSnack $cmd} $args]
}

proc ::CanvasUtils::GetImportCmdForQTMovie {cmd args} {
    
    array set argsArr {
	-uritype file
    }
    array set argsArr $args
    
    # Need this here to get the windows size.
    update idletasks

    # 'create window 0 0 -window ...'
    set indopts [lsearch -regexp $cmd {^-[a-z]}]
    set coords [lrange $cmd 2 [expr $indopts-1]]
    array set optsArr [lrange $cmd $indopts end]
    set windowName [lindex $cmd [expr [lsearch $cmd -window] + 1]]
    
    set movieName   [lindex [winfo children $windowName] 0]
    set movFile     [$movieName cget -file]
    set movUrl      [$movieName cget -url]
    set optsArr(-width)  [winfo width $windowName]
    set optsArr(-height) [winfo height $windowName]

    switch -- $argsArr(-uritype) {
	file {
	    if {$movFile != ""} {
		if {[info exists argsArr(-basepath)]} {
		    set movFile [filerelative $argsArr(-basepath) $movFile]	    
		} 
		set optsArr(-file) $movFile
		unset -nocomplain impArr(-url)
	    } elseif {$movUrl != ""} {
		
		# In this case we don't have access to QT's internal cache.
		set optsArr(-url) $movUrl
	    }
	}
	http {
	    if {$movFile != ""} {
		set optsArr(-url) [::Utils::GetHttpFromFile $movFile]
	    } elseif {$movUrl != ""} {
		set optsArr(-url) $movUrl
	    }	    
	    unset -nocomplain optsArr(-file)
	}
	default {
	    return -code error "Unknown -uritype \"$argsArr(-uritype)\""
	}
    }
    set optsArr(-tags) [::CanvasUtils::GetUtagFromCmd $cmd]
    set optsArr(-mime) [::Types::GetMimeTypeForFileName $movFile]
    
    return [concat import $coords [array get optsArr]]
}

proc ::CanvasUtils::GetImportCmdForSnack {cmd args} {
    
    array set argsArr {
	-uritype file
    }
    array set argsArr $args
    
    # 'create window 0 0 -window ...'
    set indopts [lsearch -regexp $cmd {^-[a-z]}]
    set coords [lrange $cmd 2 [expr $indopts-1]]
    array set optsArr [lrange $cmd $indopts end]
    set windowName [lindex $cmd [expr [lsearch $cmd -window] + 1]]

    set movieName   [lindex [winfo children $windowName] 0]
    set soundObject [$movieName cget -snacksound]
    set soundFile   [$soundObject cget -file]
    set optsArr(-width)  [winfo width $windowName]
    set optsArr(-height) [winfo height $windowName]
    
    unset -nocomplain optsArr(-file) optsArr(-url)
    array set optsArr [eval {
	::CanvasUtils::GetImportOptsURI $argsArr(-uritype) $soundFile
    } $args]
    set optsArr(-tags) [::CanvasUtils::GetUtagFromCmd $cmd]
    set optsArr(-mime) [::Types::GetMimeTypeForFileName $soundFile]
    
    return [concat import $coords [array get optsArr]]
}

proc ::CanvasUtils::GetImportOptsURI {uritype filePath args} {
    
    array set argsArr $args
    
    switch -- $uritype {
	file {
	    if {[info exists argsArr(-basepath)]} {
		set opts [list -file [filerelative $argsArr(-basepath) $filePath]]
	    } else {
		set opts [list -file $filePath]
	    }
	}
	http {
	    lappend opts -url [::Utils::GetHttpFromFile $filePath]
	}
	default {
	    return -code error "Unknown -uritype \"$-uritype\""
	}
    }
    return $opts
}

# CanvasUtils::GetSVGForeignFromWindowItem --
# 
#       The 'cmd' is typically 'create window 80.0 80.0 -height 58 -window ...'
#       a canvas create command for window items.

proc ::CanvasUtils::GetSVGForeignFromWindowItem {cmd args} {
    
    ::Debug 2 "::CanvasUtils::GetSVGForeignFromWindowItem cmd=$cmd, args='$args'"
    
    set windowName  [lindex $cmd [expr [lsearch $cmd -window] + 1]]
    set windowClass [winfo class $windowName]
    
    switch -- $windowClass {
	QTFrame {
	    set line [eval {
		::CanvasUtils::GetImportCmdForQTMovie $cmd} $args]
	}
	SnackFrame {			
	    set line [eval {
	    ::CanvasUtils::GetImportCmdForSnack $cmd} $args]
	}
	XanimFrame {
	    # ?
	}
	default {
	    if {[::Plugins::HaveSaveProcForWinClass $windowClass]} {
		set procName \
		  [::Plugins::GetSaveProcForWinClass $windowClass]
		set line [eval {$procName $cmd} $args]
	    }
	}
    }
    return [eval {::CanvasUtils::GetSVGForeignFromImportCmd $line} $args]
}

# CanvasUtils::GetSVGForeignFromImportCmd --
# 
#       Makes an xmllist from an 'import' command that is not an image.
 
proc ::CanvasUtils::GetSVGForeignFromImportCmd {cmd args} {

    # Assuming '-anchor nw'
    set attr [list x [lindex $cmd 1] y [lindex $cmd 2]]
    set embedattr [list xmlns http://jabber.org/protocol/svgwb/embed/]
    set indopts [lsearch -regexp $cmd {^-[a-z]}]
    foreach {key value} [lrange $cmd $indopts end] {
	
	switch -- $key {
	    -height - -width {
		lappend attr [string trimleft $key -] $value
	    }
	    -file {
		lappend embedattr xlink:href [can2svg::FileUriFromLocalFile $value]
		lappend embedattr size [file size $value]
		lappend embedattr mime [::Types::GetMimeTypeForFileName $value]
	    }
	    -tags {
		lappend embedattr id $value
	    }
	    -url {
		lappend embedattr xlink:href $value
		lappend embedattr mime [::Types::GetMimeTypeForFileName $value]
	    }
	}
    }
    set embedElem [wrapper::createtag "embed" -attrlist $embedattr]
    set xmllist [wrapper::createtag "foreignObject" -attrlist $attr \
      -subtags [list $embedElem]]
   
    return $xmllist
}

# CanvasUtils::SVGForeignObjectHandler --
# 
#       Tries to import a 'foreignObject' element to canvas using any
#       suitable importer.

proc ::CanvasUtils::SVGForeignObjectHandler {wtop xmllist paropts transformList args} {
    
    ::Debug 4 "::CanvasUtils::SVGForeignObjectHandler \n\
      \t xmllist=$xmllist\n\t args=$args"
    
    # xmllist=foreignObject {x 32.0 y 32.0 width 166 height 22} 0 {} {
    #     {embed {xmlns http://jabber.org/protocol/svgwb/embed/ 
    #        id foo113-120.visit.se/219777630 
    #        xlink:href file:///Users/sounds/startup.wav 
    #        size 22270 mime audio/wav} 0 {} {}}}

    set w [::WB::GetCanvasFromWtop $wtop]
    set embedElems [wrapper::getchildwithtaginnamespace $xmllist "embed" \
      "http://jabber.org/protocol/svgwb/embed/"]
    if {[llength $embedElems]} {
	set x 0
	set y 0
	set basecmd {}
	foreach {key val} [wrapper::getattrlist $xmllist] {
	    switch -- $key {
		x - y {
		    set $key $val
		} 
		height - width {
		    lappend basecmd -$key $val
		}
	    }
	}
	
	foreach elem $embedElems {
	    set haveXlink 0
	    set cmd [concat import $x $y $basecmd] 
	    foreach {key val} [wrapper::getattrlist $elem] {
		switch -- $key {
		    id {
			lappend cmd -tags $val
		    }
		    size - mime {
			lappend cmd -$key $val
		    }
		    xlink:href {
			if {[string match "file:/*" $val]} {
			    set haveXlink 1
			    set path [uriencode::decodefile $val]
			    set path [string map {file:/// /} $path]
			    lappend cmd -file $path
			} elseif {[string match "http:/*" $val]} {
			    set haveXlink 1
			    lappend cmd -url $val
			}
		    }
		}
	    }
	    if {$haveXlink} {
		::Import::HandleImportCmd $w $cmd  \
		  -progess [list ::Import::ImportProgress $cmd]  \
		  -command [list ::Import::ImportCommand $cmd]
	    }
	}
    }
}


proc ::CanvasUtils::CreateItem {w args} {
    
    Debug 2 "::CanvasUtils::CreateItem args=$args"
    
    set wtop [::UI::GetToplevelNS $w]

    set utag [::CanvasUtils::GetUtagFromCmd $args]
    set cmd [concat create $args]
    set undocmd [list delete $utag]
    
    set redo [list ::CanvasUtils::CommandList $wtop [list $cmd]]
    set undo [list ::CanvasUtils::CommandList $wtop [list $undocmd]]
    
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
}

# CanvasUtils::ItemConfigure --
#
#       Makes an canvas itemconfigure that propagates to all clients.
#       Selection, if any, redone.
#       
# Arguments:
#       w      the canvas.
#       id     the item id to configure, could be "current" etc.
#       args   list of '-key value' pairs.
#       
# Results:
#       item configured, here and there.

proc ::CanvasUtils::ItemConfigure {w id args} {
    
    Debug 2 "::CanvasUtils::ItemConfigure id=$id, args=$args"

    set wtop [::UI::GetToplevelNS $w]
    
    # Be sure to get the real id (number).
    set id [$w find withtag $id]
    set utag [::CanvasUtils::GetUtag $w $id]
    set cmd [concat itemconfigure $utag $args]
    set undocmd [concat itemconfigure $utag \
      [::CanvasUtils::GetItemOpts $w $utag $args]]
    
    # Handle font points -> size for the network command.
    set cmdremote [::CanvasUtils::FontHtmlToPointSize $cmd -1]
    set undocmdremote [::CanvasUtils::FontHtmlToPointSize $undocmd -1]
    
    set redo [list ::CanvasUtils::CommandExList $wtop  \
      [list [list $cmd local] [list $cmdremote remote]]]
    set undo [list ::CanvasUtils::CommandExList $wtop  \
      [list [list $undocmd local] [list $undocmdremote remote]]]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
    
    # If selected, redo the selection to fit.
    set idsMarker [$w find withtag id$id]
    if {[string length $idsMarker] > 0} {
	$w delete id$id
	::CanvasDraw::MarkBbox $w 1 $id
    }
}

# CanvasUtils::ItemCoords --
#
#       Makes an canvas coords that propagates to all clients.
#       Selection, if any, redone.
#       
# Arguments:
#       w      the canvas.
#       id     the item id to configure, could be "current" etc.
#       coords
#       
# Results:
#       item coords set, here and there.

proc ::CanvasUtils::ItemCoords {w id coords} {
    
    Debug 2 "::CanvasUtils::ItemCoords id=$id"

    set wtop [::UI::GetToplevelNS $w]
    
    # Be sure to get the real id (number).
    set id [$w find withtag $id]
    set utag [::CanvasUtils::GetUtag $w $id]
    set cmd "coords $utag $coords"
    set undocmd "coords $utag [$w coords $id]"
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
    
    # If selected, redo the selection to fit.
    set idsMarker [$w find withtag id$id]
    if {[string length $idsMarker] > 0} {
	$w delete id$id
	::CanvasDraw::MarkBbox $w 1 $id
    }
}

# CanvasUtils::StartTimerToItemPopup --
#
#       Sets a timer (after) for the item popup menu.
#       
# Arguments:
#       w           the canvas.
#       x           mouse in global coords.
#       y           mouse in global coords.
#       
# Results:
#       none

proc ::CanvasUtils::StartTimerToItemPopup {w x y} {

    variable itemAfterId
    
    if {[info exists itemAfterId]} {
	catch {after cancel $itemAfterId}
    }
    set itemAfterId [after 1000 [list ::CanvasUtils::DoItemPopup $w $x $y]]
}

proc ::CanvasUtils::StopTimerToItemPopup { } {
    variable itemAfterId
    
    if {[info exists itemAfterId]} {
	catch {after cancel $itemAfterId}
    }
}

# Same as above but hardcoded to windows.

proc ::CanvasUtils::StartTimerToWindowPopup {w x y} {

    variable winAfterId
    
    if {[info exists winAfterId]} {
	catch {after cancel $winAfterId}
    }
    set winAfterId [after 1000 [list ::CanvasUtils::DoWindowPopup $w $x $y]]
}

proc ::CanvasUtils::StopTimerToWindowPopup { } {
    variable winAfterId
    
    if {[info exists winAfterId]} {
	catch {after cancel $winAfterId}
    }
}

# CanvasUtils::DoItemPopup --
#
#       Posts the item popup menu depending on item type.
#       
# Arguments:
#       w           the canvas.
#       x           mouse in global coords.
#       y           mouse in global coords.
#       
# Results:
#       none

proc ::CanvasUtils::DoItemPopup {w x y} {
    global  prefs fontPoints2Size
    variable itemAfterId
    variable popupVars
    variable menuDefs
    
    Debug 2 "::CanvasUtils::DoItemPopup: w=$w"

    set wtop [::UI::GetToplevelNS $w]
    
    # Cancel the gray box drag rectangle. x and y must be canvas local coords.
    set xloc [expr $x - [winfo rootx $w]]
    set yloc [expr $y - [winfo rooty $w]]
    
    # Clear and cancel the triggering of any selections.
    ::CanvasDraw::CancelBox $w
    set id [$w find withtag current]
    if {$id == ""} {
	return
    }
    
    # Get 'type', broken is a special form of image.
    set type [$w type $id]
    set tags [$w gettags $id]
    if {[lsearch $tags broken] >= 0} {
	set type broken
    }
    Debug 2 "   type=$type"
        
    # In order to get the present value of id it turned out to be 
    # easiest to make a fresh menu each time.
        
    # Build popup menu.
    set m .popup${type}
    catch {destroy $m}
    if {![winfo exists $m]} {	
	::UI::NewMenu $wtop $m {} $menuDefs(pop,$type) normal -id $id -w $w
	if {[string equal $type "text"]} {
	    ::CanvasUtils::BuildCanvasPopupFontMenu $w ${m}.mfont $id $prefs(canvasFonts)
	}
	
	# This one is needed on the mac so the menu is built before
	# it is posted.
	update idletasks
    }
    
    # Set actual values for this particular item.
    if {[regexp {arc|line|oval|rectangle|polygon} $type]} {
	set popupVars(-width) [expr int([$w itemcget $id -width])]
	set dashShort [$w itemcget $id -dash]
	if {$dashShort == ""} {
	    set dashShort " "
	}
	set popupVars(-dash) $dashShort
	if {!$prefs(haveDash)} {
	    $m entryconfigure [msgcat::mc mDash] -state disabled
	}
    }
    if {[regexp {line|polygon} $type]} {
	set smooth [$w itemcget $id -smooth]
	if {[string equal $smooth "bezier"]} {
	    set smooth 1
	}
	set popupVars(-smooth) $smooth
    }
    if {[regexp {text} $type]} {
	set fontOpt [$w itemcget $id -font]
	if {[llength $fontOpt] >= 3} {
	    set popupVars(-fontfamily) [lindex $fontOpt 0]
	    set pointSize [lindex $fontOpt 1]
	    if {[info exists fontPoints2Size($pointSize)]} {
		set popupVars(-fontsize) $fontPoints2Size($pointSize)
	    }
	    set popupVars(-fontweight) [lindex $fontOpt 2]
	}
    }
    if {$type == "arc"} {
	set popupVars(-arc) [$w itemcget $id -style]
    }
    
    # Post popup menu.
    tk_popup $m [expr int($x) - 10] [expr int($y) - 10]
}

proc ::CanvasUtils::BuildCanvasPopupFontMenu {w wmenu id allFonts} {

    set mt $wmenu    
    $mt delete 0 end
    foreach afont $allFonts {
	$mt add radio -label $afont -variable ::CanvasUtils::popupVars(-fontfamily)  \
	  -command [list ::CanvasUtils::SetTextItemFontFamily $w $id $afont]
    }
}

proc ::CanvasUtils::DoWindowPopup {w x y} {
    variable menuDefs
    
    switch -- [winfo class $w] {
	QTFrame {
	    ::CanvasUtils::PostGeneralMenu $w $x $y .popupqt \
	      $menuDefs(pop,qt)
	}
	SnackFrame {
	    ::CanvasUtils::PostGeneralMenu $w $x $y .popupsnack \
	      $menuDefs(pop,snack)
	}
	default {
	    
	    # Add a hook here for plugin support.
	    
	}
    }
}

proc ::CanvasUtils::PostGeneralMenu {w x y m mDef} {
            
    set wtop [::UI::GetToplevelNS $w]    

    set xloc [expr $x - [winfo rootx $w]]
    set yloc [expr $y - [winfo rooty $w]]
        
    # Build popup menu.
    catch {destroy $m}
    if {![winfo exists $m]} {
	::UI::BuildMenu $wtop $m {} $mDef normal -winfr $w
	
	# This one is needed on the mac so the menu is built before
	# it is posted.
	update idletasks
    }
    
    # Post popup menu.
    tk_popup $m [expr int($x) - 10] [expr int($y) - 10]
}
    
# SetItemColorDialog, SetTextItemFontFamily, SetTextItemFontSize, 
#    SetTextItemFontWeight --
#
#       Some handy utilities for the popup menu callbacks.

proc ::CanvasUtils::ItemSmooth {w id} {
    
    set smooth [$w itemcget $id -smooth]
    if {[string equal $smooth "bezier"]} {
	set smooth 1
    }
    
    # Just toggle smooth state.
    ::CanvasUtils::ItemConfigure $w $id -smooth [expr 1 - $smooth]
}

proc ::CanvasUtils::ItemStraighten {w id} {
    global  prefs
    
    set frac $prefs(straightenFrac)
    set coords [$w coords $id]
    set len [expr [llength $coords]/2]
    set type [$w type $id]
    
    switch -- $type {
	line {
	    if {$len <= 2} {
		return
	    }
	}
	polygon {
	    if {$len <= 3} {
		return
	    }
	}
    }
    set dsorted [lsort -real [::CanvasDraw::GetDistList $coords]]
    set dlimit [lindex $dsorted [expr int($len * $frac + 1)]]
    set coords [::CanvasDraw::StripClosePoints $coords $dlimit]
    ::CanvasUtils::ItemCoords $w $id $coords
    
    if {[::CanvasDraw::IsSelected $w $id]} {
	::CanvasDraw::DeselectItem $w $id
	::CanvasDraw::SelectItem $w $id
    }
}

proc ::CanvasUtils::SetItemColorDialog {w id opt} {
    
    set presentColor [$w itemcget $id $opt]
    if {$presentColor == ""} {
	set presentColor black
    }
    set color [tk_chooseColor -initialcolor $presentColor  \
      -title [mc {New Color}]]
    if {$color != ""} {
	::CanvasUtils::ItemConfigure $w $id $opt $color
    }
}

proc ::CanvasUtils::SetTextItemFontFamily {w id fontfamily} {
    
    # First, get existing font value.
    set fontOpts [$w itemcget $id -font]
    
    # Then configure with new one.
    set fontOpts [list {-font} [lreplace $fontOpts 0 0 $fontfamily]]
    eval {CanvasUtils::ItemConfigure $w $id} $fontOpts    
}
    
proc ::CanvasUtils::SetTextItemFontSize {w id fontsize} {
    
    # First, get existing font value.
    set fontOpts [$w itemcget $id -font]
    
    # Then configure with new one.
    set fontOpts [lreplace $fontOpts 1 1 $fontsize]
    set fontOpts [::CanvasUtils::FontHtmlToPointSize [list {-font} $fontOpts]]
    eval {CanvasUtils::ItemConfigure $w $id} $fontOpts
}

proc ::CanvasUtils::SetTextItemFontWeight {w id fontweight} {
    
    # First, get existing font value.
    set fontOpts [$w itemcget $id -font]
    
    # Then configure with new one.
    set fontOpts [list {-font} [lreplace $fontOpts 2 2 $fontweight]]
    eval {CanvasUtils::ItemConfigure $w $id} $fontOpts    
}

# CanvasUtils::NewImportAnchor --
#
#       Creates new coordinates that takes care of the finite size of
#       the canvas. Uses cyclic boundary conditions.
#            
# Arguments:
#       
# Results:
#       list of x and y.

proc ::CanvasUtils::NewImportAnchor {wcan} {
    global  prefs
    
    variable importAnchor
    
    set x $importAnchor(x)
    set y $importAnchor(y)
    
    # Update 'importAnchor'.
    incr importAnchor(x) $prefs(offsetCopy)
    incr importAnchor(y) $prefs(offsetCopy)
    
    # This returns an empty list if not yet displayed.
    foreach {x0 y0 width height} [$wcan cget -scrollregion] break
    if {![info exists width]} {
	set width [winfo reqwidth $wcan]
	set height [winfo reqheight $wcan]
    }
    if {($importAnchor(x) > [expr $width - 60]) ||   \
      ($importAnchor(y) > [expr $height - 60])} {
	set importAnchor(x) $prefs(offsetCopy)
	set importAnchor(y) $prefs(offsetCopy)
    }
    return [list $x $y]
}

# CanvasUtils::GetItemOpts --
#
#       As canvas itemconfigure but only the actual options.
#       
# Arguments:
#       w         the canvas widget path.
#       id        item tag or id.
#       which   nondef:  return only values that are not identical to defaults.
#               all:     return all options.
#               -key value ... list: pick only options in this list.
#       
# Results:
#       list of options and values as '-option value' ....

proc ::CanvasUtils::GetItemOpts {w id {which "nondef"}} {
    
    set opcmd {}
    if {[llength $which] > 1} {
	foreach {op val} $which {
	    lappend opcmd $op [$w itemcget $id $op]
	}
    } else {
	set all [string equal $which "all"]
	set opts [$w itemconfigure $id]
	foreach oplist $opts {
	    foreach {op x y defval val} $oplist {
		if {[string equal $op "-tags"]} {
		    regsub current $val "" val
		    regsub selected $val "" val
		}
		if {[string equal $op "-smooth"]} {
		    regsub bezier $val 1 val
		}
		if {$all || ![string equal $defval $val]} {
		    lappend opcmd $op $val
		}
	    }
	}
    }
    return $opcmd
}

# CanvasUtils::FindAboveUtag, FindBelowUtag --
# 
#       As 'canvasPath find above/below tagOrId' but that only returns
#       ordinary items, for which there is a utag, and not markers etc.
#       Returns a utag if found, else empty.

proc ::CanvasUtils::FindAboveUtag {w id} {

    set aboveutag ""
    set aboveid [$w find above $id]
    while {[set aboveutag [GetUtag $w $aboveid 1]] == ""} {
	if {[set aboveid [$w find above $id]] == ""} {
	    break
	}
	set id $aboveid
    }
    return $aboveutag
}

proc ::CanvasUtils::FindBelowUtag {w id} {

    set belowutag ""
    set belowid [$w find below $id]
    while {[set belowutag [GetUtag $w $belowid 1]] == ""} {
	if {[set belowid [$w find below $id]] == ""} {
	    break
	}
	set id $belowid
    }
    return $belowutag
}

# CanvasUtils::GetStackingOption --
#
#       Returns a list '-below utag', '-above utag' or empty.

proc ::CanvasUtils::GetStackingOption {w id} {
    
    # below before above since stacking order when saving to file.
    set opt {}
    set belowutag [FindBelowUtag $w $id]
    if {[string length $belowutag]} {
	lappend opt -above $belowutag
    }
    set aboveutag [FindAboveUtag $w $id]
    if {[string length $aboveutag]} {
	lappend opt -below $aboveutag
    }
    return $opt
}

# CanvasUtils::GetStackingCmd --
#
#       Returns a canvas command (without pathName) that restores the
#       stacking order of $utag.

proc ::CanvasUtils::GetStackingCmd {w utag} {
    
    set aboveid [$w find above $utag]
    if {[string length $aboveid]} {
	set cmd [list lower $utag [GetUtag $w $aboveid 1]]
    } else {
	set belowid [$w find below $utag]
	if {[string length $belowid]} {
	    set cmd [list raise $utag [GetUtag $w $belowid 1]]
	} else {
	    
	    # If a single item on canvas, do dummy.
	    set cmd [list raise $utag]
	}
    }
    return $cmd
}

# CanvasUtils::UniqueImageName --
#
#       Uses the ip number to create a unique image name.

proc ::CanvasUtils::UniqueImageName { } {
    global  this
    variable utaguid
    
    set str ""
    foreach i [split $this(ipnum) .] {
	append str [format "%02x" $i]
    }
    append str [format "%x" $utaguid]
    incr utaguid
    return "im${str}"
}

# CanvasUtils::FindTypeFromOverlapping --
#   
#       Finds the specific item at given coords and with tag 'type'.
#   
# Arguments:
#       c         the canvas widget path.
#       x, y      coords
#       type
#       
# Results:
#       item id or empty if none.

proc ::CanvasUtils::FindTypeFromOverlapping {c x y type} {    
    
    set ids [$c find overlapping [expr $x-2] [expr $y-2]  \
      [expr $x+2] [expr $y+2]]
    set id {}
    
    # Choose the first item with tags $type.
    foreach i $ids {
	if {[lsearch [$c gettags $i] $type] >= 0} {
	    
	    # Found "$type".
	    set id $i
	    break
	}
    }
    return $id
}

# CanvasUtils::FontHtmlToPointSize --
#
#       Change the -font option in a canvas command from html size type
#       to point size, or vice versa if 'inverse'.
#
# Arguments:
#       canCmd     a canvas command which need not have the widget prepended.
#       inverse    (optional, defaults to 0) if 1, PointSizeToHtml size instead.
# 
# Results:
#       the modified canvas command.

proc ::CanvasUtils::FontHtmlToPointSize {canCmd {inverse 0}} {
    global  fontSize2Points fontPoints2Size
    
    set ind [lsearch -exact $canCmd {-font}]
    if {$ind < 0} {
	return $canCmd
    }
    set fontSpec [lindex $canCmd [incr ind]]
    set fontSize [lindex $fontSpec 1]
    
    # If we already have the size in pixels (-36) do nothing.
    if {$fontSize < 0} {
	return $canCmd
    }
    
    if {!$inverse} {
	
	# This is the default  html->points.
	# Check that it is between 1 and 6.
	if {$fontSize >= 1 && $fontSize <= 6} {
	    lset fontSpec 1 $fontSize2Points($fontSize)
	    
	    # Replace font specification in drawing command.
	    set canCmd [lreplace $canCmd $ind $ind $fontSpec]
	}
    } else {
	
	# This is points->html.
	lset fontSpec 1 $fontPoints2Size($fontSize)
	
	# Replace font specification in drawing command.
	set canCmd [lreplace $canCmd $ind $ind $fontSpec]
    }
    return $canCmd
}

proc ::CanvasUtils::FontHtmlToPixelSize {canCmd {inverse 0}} {
    global  fontSize2Pixels fontPixels2Size
    
    set ind [lsearch -exact $canCmd "-font"]
    if {$ind < 0} {
	return $canCmd
    }
    set fontSpec [lindex $canCmd [incr ind]]
    set fontSize [expr abs([lindex $fontSpec 1])]
    
    if {!$inverse} {
	
	# This is the default  html->pixels.
	# Check that it is between 1 and 6.
	if {$fontSize >= 1 && $fontSize <= 6} {
	    lset fontSpec 1 -$fontSize2Pixels($fontSize)
	    set canCmd [lreplace $canCmd $ind $ind $fontSpec]
	}
    } else {
	# Test leaving the minus sign there.
	if {0} {
	    # This is pixels->html.
	    lset fontSpec 1 $fontPoints2Size($fontSize)
	    
	    # Replace font specification in drawing command.
	    set canCmd [lreplace $canCmd $ind $ind $fontSpec]
	}
    }
    return $canCmd
}

# CanvasUtils::CreateFontSizeMapping --
#
#       Creates the mapping between Html sizes (1 2 3 4 5 6) and font point
#       sizes on this specific platform dynamically by measuring the length in
#       pixels of a fixed reference string.
#
# Results:
#       is put in the global variables 'fontSize2Points' and 'fontPoints2Size'.

proc ::CanvasUtils::CreateFontSizeMapping { } {
    global  fontSize2Points fontPoints2Size fontSize2Pixels fontPixels2Size this
    
    # The reference is chosen to get point sizes on Mac as: 10, 12, 14, 18, 
    # 24, 36. Found via 'font measure {Times 10} {Mats Bengtsson}'.
    
    array set refHtmlSizeToLength {1 64 2 76 3 88 4 116 5 154 6 231}
    set refStr {Mats Bengtsson}
    
    # Pick to point sizes and reconstruct a linear relation from the font size
    # in points and the reference string length in pixels: y = kx + m.
    
    set p0 10
    set p1 36
    
    # Points.
    set y0 [font measure "Times $p0" $refStr]
    set y1 [font measure "Times $p1" $refStr]
    set k [expr ($y1 - $y0)/double($p1 - $p0)]
    set m [expr $y1 - $k*$p1]
    
    # Pixels.
    #set y0 [font measure "Times -10" $refStr]
    #set y1 [font measure "Times -36" $refStr]
    #set kpix [expr ($y1 - $y0)/double($p1 - $p0)]
    #set mpix [expr $y1 - $kpix*$p1]
    
    # For what x (font size in points) do we get 'refHtmlSizeToLength(1)', etc.
    # x = (y - m)/k
    # Mac and Windows are hardcoded for optimal view.
    
    switch -- $this(platform) {
	macintosh - macosx {
	    array set fontSize2Points {1 10 2 12 3 14 4 18 5 24 6 36}
	}
	windows {
	    array set fontSize2Points {1 7 2 9 3 11 4 14 5 18 6 28}
	}
	default {
	    foreach htmlSize {1 2 3 4 5 6} {
		set fontSize2Points($htmlSize)  \
		  [expr int( ($refHtmlSizeToLength($htmlSize) - $m)/$k + 0.9)]
	    }
	}
    }
    
    # Same for all.
    array set fontSize2Pixels {1 10 2 12 3 14 4 18 5 24 6 36}
    
    # We also need the inverse mapping.    
    foreach pt [array names fontSize2Points] {
	set fontPoints2Size($fontSize2Points($pt)) $pt
    }
    foreach pix [array names fontSize2Pixels] {
	set fontPixels2Size($fontSize2Points($pix)) $pix
    }
}

# CanvasUtils::HandleCanvasDraw --
# 
#       Handle a CANVAS drawing command from the server.
#       
# Arguments:
#       wtop        toplevel window. ("." or ".main2." with extra dot!)
#       instr       everything after CANVAS:
#       args
#               -tryimport (0|1)
#
# Returns:
#       none.

proc ::CanvasUtils::HandleCanvasDraw {wtop instr args} {
    global  prefs canvasSafeInterp
    
    # Special chars.
    set bs_ {\\}
    set lb_ {\{}
    set rb_ {\}}
    set punct_ {[.,;?!]}
    
    # Regular drawing commands in the canvas.
    set wServCan [::WB::GetServerCanvasFromWtop $wtop]
    
    # If html sizes in text items, be sure to translate them into
    # platform specific point sizes.
    
    if {$prefs(useHtmlSizes) && ([lsearch -exact $instr "-font"] >= 0)} {
	set instr [::CanvasUtils::FontHtmlToPointSize $instr]
    }
    
    # Careful, make newline (backslash) substitutions only for the command
    # being eval'd, else the tcl interpretation may be screwed up.
    # Fix special chars such as braces since they are parsed 
    # when doing 'subst' below. Pad extra backslash for each '\{' and
    # '\}' to protect them.
    # Seems like an identity operation but is not!
    
    regsub -all "$bs_$lb_" $instr "$bs_$lb_" instr
    regsub -all "$bs_$rb_" $instr "$bs_$rb_" instr
    set bsinstr [subst -nocommands -novariables $instr]
    
    # Intercept the canvas command if delete to remove any markers
    # *before* it is deleted! See below for other commands.
    
    set cmd [lindex $instr 0]
    if {[string equal $cmd "delete"]} {
	set utag [lindex $instr 1]
	set id [$wServCan find withtag $utag]
	$wServCan delete id$id
    }
    
    # Find and register the undo command (and redo), and push
    # on our undo/redo stack. Security ???
    if {$prefs(privacy) == 0} {
	set redo [list ::CanvasUtils::Command $wtop $instr]
	set undo [::CanvasUtils::GetUndoCommand $wtop $instr]
	undo::add [::WB::GetUndoToken $wtop] $undo $redo
    }
    
    # The 'import' command is an exception case (for the future). 
    if {[string equal $cmd "import"]} {
	eval {::Import::HandleImportCmd $wServCan $bsinstr -where local} $args
    } else {
		
	# Make the actual canvas command, either straight or in the 
	# safe interpreter.
	if {$prefs(makeSafeServ)} {
	    if {[catch {$canvasSafeInterp eval SafeCanvasDraw  \
	      $wServCan $bsinstr} idnew]} {
		puts stderr "--->error: did not understand: $idnew"
		return
	    }
	} else {
	    if {[catch {eval $wServCan $bsinstr} idnew]} {
		puts stderr "--->error: did not understand: $idnew"
		return
	    }
	}
    }
	
    # Intercept the canvas command in certain cases:
    # If moving a selected item, be sure to move the markers with it.
    # The item can either be selected by remote client or here.
    
    switch -- $cmd {
	move - coords - scale - itemconfigure {
	    set utag [lindex $instr 1]
	    set id [$wServCan find withtag $utag]
	    set idsMarker [$wServCan find withtag id$id]
	    
	    # If we have selected the item in question.
	    if {[string length $idsMarker] > 0} {
		$wServCan delete id$id
		$wServCan dtag $id "selected"
		::CanvasDraw::MarkBbox $wServCan 1 $id
	    }
	}
	create - insert {
	    
	    # If text then invoke hook.
	    if {[string equal $cmd "create"]} {
		set utag $idnew
	    } else {
		set utag [lindex $instr 1]
	    }
	    set type [$wServCan type $utag]
	    if {[string equal $type "text"]} {
		
		# Extract the actual text. TclSpeech not foolproof!
		set theText [$wServCan itemcget $utag -text]
		::hooks::run whiteboardTextInsertHook other $theText
	    }
	}
    }
}

# CanvasUtils::CanvasDrawSafe --
# 
#       This is the drawing procedure that is necessary for the alias command.

proc ::CanvasUtils::CanvasDrawSafe {w args} {
    eval $w $args
}    

# CanvasUtils::DefineWhiteboardBindtags --
# 
#       Defines a number of binding tags for the whiteboard canvas.
#       This is helpful when switching bindings depending on which tool is 
#       selected. It defines only widget bindtags, not item bindings!

proc ::CanvasUtils::DefineWhiteboardBindtags { } {
    global  this
    
    # WhiteboardPoint
    bind WhiteboardPoint <Button-1> {
	::CanvasDraw::PointButton %W [%W canvasx %x] [%W canvasy %y]
	::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] rectangle
    }
    bind WhiteboardPoint <Shift-Button-1> {
	::CanvasDraw::PointButton %W [%W canvasx %x] [%W canvasy %y] shift
	::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] rectangle
    }
    bind WhiteboardPoint <B1-Motion> {
	::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 0 rectangle 1
	::CanvasUtils::StopTimerToItemPopup
    }
    bind WhiteboardPoint <ButtonRelease-1> {
	::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 0 rectangle 1
    }
    
    # WhiteboardMove
    # Bindings for moving items; movies need special class.
    # The frame with the movie the mouse events, not the canvas.
    # Binds directly to canvas widget since we want to move selected items
    # as well.
    # With shift constrained move.
    bind WhiteboardMove <Button-1> {
	::CanvasDraw::InitMoveSelected %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardMove <B1-Motion> {
	::CanvasDraw::DragMoveSelected %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardMove <ButtonRelease-1> {
	::CanvasDraw::FinalMoveSelected %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardMove <Shift-B1-Motion> {
	::CanvasDraw::DragMoveSelected %W [%W canvasx %x] [%W canvasy %y] shift
    }    
    
    # WhiteboardLine
    bind WhiteboardLine <Button-1> {
	::CanvasDraw::InitLine %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardLine <B1-Motion> {
	::CanvasDraw::LineDrag %W [%W canvasx %x] [%W canvasy %y] 0
    }
    bind WhiteboardLine <Shift-B1-Motion> {
	::CanvasDraw::LineDrag %W [%W canvasx %x] [%W canvasy %y] 1
    }
    bind WhiteboardLine <ButtonRelease-1> {
	::CanvasDraw::FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 0
    }
    bind WhiteboardLine <Shift-ButtonRelease-1> {
	::CanvasDraw::FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 1
    }

    # WhiteboardArrow
    bind WhiteboardArrow <Button-1> {
	::CanvasDraw::InitLine %W [%W canvasx %x] [%W canvasy %y] arrow
    }
    bind WhiteboardArrow <B1-Motion> {
	::CanvasDraw::LineDrag %W [%W canvasx %x] [%W canvasy %y] 0 arrow
    }
    bind WhiteboardArrow <Shift-B1-Motion> {
	::CanvasDraw::LineDrag %W [%W canvasx %x] [%W canvasy %y] 1 arrow
    }
    bind WhiteboardArrow <ButtonRelease-1> {
	::CanvasDraw::FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 0 arrow
    }
    bind WhiteboardArrow <Shift-ButtonRelease-1> {
	::CanvasDraw::FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 1 arrow
    }
    
    # WhiteboardRect
    bind WhiteboardRect <Button-1> {
	::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] rectangle
    }
    bind WhiteboardRect <B1-Motion> {
	::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 0 rectangle
    }
    bind WhiteboardRect <Shift-B1-Motion> {
	::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 1 rectangle
    }
    bind WhiteboardRect <ButtonRelease-1> {
	::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 0 rectangle
    }
    bind WhiteboardRect <Shift-ButtonRelease-1> {
	::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 1 rectangle
    }
    
    # WhiteboardOval
    bind WhiteboardOval <Button-1> {
	::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] oval
    }
    bind WhiteboardOval <B1-Motion> {
	::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 0 oval
    }
    bind WhiteboardOval <Shift-B1-Motion> {
	::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 1 oval
    }
    bind WhiteboardOval <ButtonRelease-1> {
	::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 0 oval
    }
    bind WhiteboardOval <Shift-ButtonRelease-1> {
	::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 1 oval
    }

    # WhiteboardText
    bind WhiteboardText <Button-1> {
	::CanvasText::CanvasFocus %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardText <Button-2> {
	::CanvasCCP::CanvasTextPaste %W [%W canvasx %x] [%W canvasy %y]
    }
    # Stop certain keyboard accelerators from firing:
    bind WhiteboardText <Control-a> break

    # WhiteboardDel
    bind WhiteboardDel <Button-1> {
	# empty
    }
    
    # WhiteboardPen
    bind WhiteboardPen <Button-1> {
	::CanvasDraw::InitStroke %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardPen <B1-Motion> {
	::CanvasDraw::StrokeDrag %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardPen <ButtonRelease-1> {
	::CanvasDraw::FinalizeStroke %W [%W canvasx %x] [%W canvasy %y]
    }

    # WhiteboardBrush
    bind WhiteboardBrush <Button-1> {
	::CanvasDraw::InitStroke %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardBrush <B1-Motion> {
	::CanvasDraw::StrokeDrag %W [%W canvasx %x] [%W canvasy %y] 1
    }
    bind WhiteboardBrush <ButtonRelease-1> {
	::CanvasDraw::FinalizeStroke %W [%W canvasx %x] [%W canvasy %y] 1
    }

    # WhiteboardPaint
    bind WhiteboardPaint  <Button-1> {
	::CanvasDraw::DoPaint %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardPaint  <Shift-Button-1> {
	::CanvasDraw::DoPaint %W [%W canvasx %x] [%W canvasy %y] 1
    }

    # WhiteboardPoly
    bind WhiteboardPoly  <Button-1> {
	::CanvasDraw::PolySetPoint %W [%W canvasx %x] [%W canvasy %y]
    }

    # WhiteboardArc
    bind WhiteboardArc <Button-1> {
	::CanvasDraw::InitArc %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardArc <Shift-Button-1> {
	::CanvasDraw::InitArc %W [%W canvasx %x] [%W canvasy %y] 1
    }

    # WhiteboardRot
    bind WhiteboardRot <Button-1> {
	::CanvasDraw::InitRotateItem %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardRot <B1-Motion> {
	::CanvasDraw::DoRotateItem %W [%W canvasx %x] [%W canvasy %y] 0
    }
    bind WhiteboardRot <Shift-B1-Motion> {
	::CanvasDraw::DoRotateItem %W [%W canvasx %x] [%W canvasy %y] 1
    }
    bind WhiteboardRot <ButtonRelease-1> {
	::CanvasDraw::FinalizeRotate %W [%W canvasx %x] [%W canvasy %y]
    }
    
    # Generic nontext bindings.
    bind WhiteboardNonText <BackSpace> {
	::CanvasDraw::DeleteSelected %W
    }
    bind WhiteboardNonText <Control-d> {
	::CanvasDraw::DeleteSelected %W
    }
}

# CanvasUtils::ItemSet, ItemCGet, ItemFree --
#
#       Handling cached info for items not set elsewhere.
#       Automatically garbage collected.

proc ::CanvasUtils::ItemSet {wtop id args} {
    upvar ::WB::${wtop}::itemopts itemopts

    set itemopts($id) $args
}

proc ::CanvasUtils::ItemCGet {wtop id} {
    upvar ::WB::${wtop}::itemopts itemopts
    
    if {[info exists itemopts($id)]} {
	return $itemopts($id)
    } else {
	return ""
    }
}

proc ::CanvasUtils::ItemFree {wtop} {
    upvar ::WB::${wtop}::itemopts itemopts
    
    unset -nocomplain itemopts
}

# CanvasUtils::GetCompleteCanvas --
# 
#       Gets a list of canvas commands without the widgetPath or "CANVAS:".
#       May use 'import' command.

proc ::CanvasUtils::GetCompleteCanvas {wcan} {
    
    set cmdList {}
    
    foreach id [$wcan find all] {
	set tags [$wcan gettags $id]
	if {([lsearch $tags grid] >= 0) || ([lsearch $tags tbbox] >= 0)} {
	    continue
	}
	set line [::CanvasUtils::GetOneLinerForAny $wcan $id -uritype http]
	if {$line != ""} {
	    lappend cmdList $line
	}
    }
    return $cmdList
}

#-------------------------------------------------------------------------------
