#  Emoticons.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements handling and parsing of emoticons (smileys).
#      
#  Copyright (c) 2004-2007  Mats Bengtsson
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
# $Id: Emoticons.tcl,v 1.65 2008-02-29 12:55:36 matben Exp $

package provide Emoticons 1.0

namespace eval ::Emoticons:: {

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Emoticons::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Emoticons::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Emoticons::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Emoticons::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Emoticons::UserDefaultsHook
    ::hooks::register initHook               ::Emoticons::Init

    ::hooks::register launchFinalHook        ::Emoticons::ParseCommandLine
    if {[tk windowingsystem] eq "aqua"} {
	::hooks::register macOpenDocument    ::Emoticons::MacOpenDocument
    }
    
    variable priv
    set priv(defaultSet) "default"
}

proc ::Emoticons::Init {} {
    global  this
    
    variable priv
    upvar ::Jabber::jprefs jprefs

    # 'tmpicons(name,key)' map from a text string (key) and iconset name
    # to an image name.
    variable tmpicons
    
    # 'tmpiconsInv(name,image)' map from an image and named iconset to a
    # list of keys, which is the inverse of the above.
    variable tmpiconsInv

    ::Debug 2 "::Emoticons::Init"
    
    # We need the 'vfs::zip' package and if not using starkit we also need
    # the 'Memchan' package which is not automatically checked for.
    # 'rechan' is the tclkits built in version of 'Memchan'.
    if {[catch {package require vfs::zip}]} {
	set priv(havezip) 0
    } elseif {![catch {package require rechan}]} {
	set priv(havezip) 1
    } elseif {![catch {package require Memchan}]} {
	set priv(havezip) 1
    } else {
	set priv(havezip) 0
    }

    # Cache stuff we need later.
    set priv(havepng)      [::Media::HaveImporterForMime image/png]
    set priv(QuickTimeTcl) [::Media::HavePackage QuickTimeTcl]
    set priv(Img)          [::Media::HavePackage Img]
    if {$priv(Img)} {
	set priv(needtmp)   0
	set priv(pngformat) [list -format png]
    } else {
	set priv(needtmp)   1
	set priv(pngformat) {}
    }
    ::Debug 4 "sets=[GetAllSets]"
    
    # Load set.
    # Even if we succeed to get the vfs::zip package, it doesn't check
    # the Memchan package, and can therefore still fail.
    # NB: We may have "None" set which has a value "-".

    if {$jprefs(emoticonSet) ne "-"} {
	if {[catch {
	    LoadTmpIconSet [GetPrefSetPathExists]
	} err]} {
	    ::Debug 4 "\t catch: $err"
	    set priv(havezip) 0
	    set jprefs(emoticonSet) $priv(defaultSet)
	    LoadTmpIconSet [GetPrefSetPathExists]
	}
	SetPermanentSet $jprefs(emoticonSet)
    } else {
	# empty
    }
    if {[tk windowingsystem] eq "win32"} {
	InitWin
    }
}

proc ::Emoticons::InitWin {} {
    global  this
    
    if {[catch {package require RegisterFileType}]} {
	return
    }
    # Find the exe we are running. Starkits?
    if {[info exists ::starkit::topdir]} {
	set exe [file nativename [info nameofexecutable]]
	set cmd "\"$exe\" -file \"%1\""
    } else {
	set exe [file nativename [info nameofexecutable]]
	set app [file nativename $this(script)]
	set cmd "\"$exe\" \"$app\" -file \"%1\""
    }
    catch {
	RegisterFileType::RegisterFileType .jisp jispArchive \
	  "Emoticon Archive"  $cmd
    }
}

proc ::Emoticons::Exists {word} {
    variable smiley
    return [info exists smiley($word)]
}

proc ::Emoticons::Get {word} {
    variable smiley
    return $smiley($word)
}

proc ::Emoticons::Make {w word} {
    variable smiley
    
    if {[info exists smiley($word)]} {
	$w image create insert -image $smiley($word) -name $word
    }
}

proc ::Emoticons::None {} {
    upvar ::Jabber::jprefs jprefs
    return [expr {$jprefs(emoticonSet) eq "-"}]
}

proc ::Emoticons::GetAllSets {} {
    global  this
    variable priv
    variable state
    
    set setList [list]
    foreach path [list $this(emoticonsPath) $this(altEmoticonsPath)] {
	foreach f [glob -nocomplain -directory $path *] {
	    set name [file tail $f]
	    set name [file rootname $name]
	    if {[string equal [file extension $f] ".jisp"] && $priv(havezip)} {
		lappend setList $name
		set state($name,path) $f
	    } elseif {[file isdirectory $f]} {
		if {[file exists [file join $f icondef.xml]]} {
		    lappend setList $name
		    set state($name,path) $f
		}
	    }
	}
    }
    return $setList
}

# Emoticons::GetPrefSetPathExists --
# 
#       Gets the full path to our emoticons file/folder.
#       Verifies that it exists and that can be mounted if zip archive.

proc ::Emoticons::GetPrefSetPathExists {} {
    global  this
    variable priv
    upvar ::Jabber::jprefs jprefs

    # Start with the failsafe set.
    set path [file join $this(emoticonsPath) $priv(defaultSet)]
    
    foreach dir [list $this(emoticonsPath) $this(altEmoticonsPath)] {
	set f [file join $dir $jprefs(emoticonSet)]
	set fjisp $f.jisp
	if {[file exists $f]} {
	    set path $f
	    break
	} elseif {[file exists $fjisp] && $priv(havezip)} {
	    set path $fjisp
	    break
	}
    }
    set jprefs(emoticonSet) [file rootname [file tail $path]]
    return $path
}
    
proc ::Emoticons::LoadTmpIconSet {path} {
    
    variable state
    variable priv
    
    # The dir variable points to the (virtual) directory containing it all.
    set dir $path
    set name [file rootname [file tail $path]]
    
    if {[string equal [file extension $path] ".jisp"]} {
	if {$priv(havezip)} {
	    set mountpath [file join [file dirname $path] $name]
	    if {[catch {
		#puts "path=$path, mountpath=$mountpath"
		set fdzip [vfs::zip::Mount $path $mountpath]
	    } err]} {
		return -code error $err
	    }
	    
	    # We cannot be sure of that the name of the archive is identical 
	    # with the name of the original directory.
	    set zipdir [lindex [glob -nocomplain -directory $mountpath *] 0]
	    set dir $zipdir
	} else {
	    return -code error "Cannot read jisp archive without vfs::zip"
	}
    }
    set icondefPath [file join $dir icondef.xml]
    if {![file isfile $icondefPath]} {
	return -code error "missing icondef.xml file in archive"
    }
    set fd [open $icondefPath]
    fconfigure $fd -encoding utf-8
    set xmldata [read $fd]
    close $fd
    
    #FreeTmpSet $name
    
    # Parse data.
    ParseIconDef $name $dir $xmldata
    
    if {[info exists mountpath]} {
	vfs::zip::Unmount $fdzip $mountpath
    }
    set state($name,loaded) 1
}

proc ::Emoticons::ParseIconDef {name dir xmldata} {
    variable tmpicons
    variable tmpiconsInv

    set token [tinydom::parse $xmldata]
    set xmllist [tinydom::documentElement $token]

    # @@@ Any images shall be freed!!!
    array unset tmpicons $name,*
    array unset tmpiconsInv $name,*

    foreach elem [tinydom::children $xmllist] {
	
	switch -- [tinydom::tagname $elem] {
	    meta {
		ParseMeta $name $dir $elem
	    }
	    icon {
		ParseIcon $name $dir $elem
	    }
	}
    }
    tinydom::cleanup $token
}

proc ::Emoticons::ParseMeta {name dir xmllist} {
    variable meta
    
    array unset meta $name,*
    foreach elem [tinydom::children $xmllist] {
	set tag [tinydom::tagname $elem]
	lappend meta($name,$tag) [tinydom::chdata $elem]
    }
}

proc ::Emoticons::ParseIcon {name dir xmllist} {
    global  this
    
    variable tmpicons
    variable tmpiconsInv
    variable priv

    set keyList {}
    set mime ""
    
    foreach elem [tinydom::children $xmllist] {
	set tag [tinydom::tagname $elem]
	
	switch -- $tag {
	    text {
		lappend keyList [tinydom::chdata $elem]
	    }
	    object - graphic {
		# graphic does not comply with XEP-0038!
		set object [tinydom::chdata $elem]
		array set attrArr [tinydom::attrlist $elem]
		set mime $attrArr(mime)
	    }
	}
    }
    
    switch -- $mime {
	image/gif {
	    set im [::Utils::CreateGif [file join $dir $object]]
	    foreach key $keyList {
		set tmpicons($name,$key) $im
	    }
	}
	image/png {
	    # If we rely on QuickTimeTcl here we cannot be in vfs.
	    set f [file join $dir $object]
	    if {$priv(needtmp)} {
		set tmp [::tfileutils::tempfile $this(tmpPath) [file rootname $object]]
		append tmp [file extension $object]
		file copy -force $f $tmp
		set f $tmp
	    }
	    set im [eval {image create photo -file $f} $priv(pngformat)]
	    foreach key $keyList {
		set tmpicons($name,$key) $im
	    }
	}
    }
    if {[info exists im]} {
	set tmpiconsInv($name,$im) $keyList
    }
}

# Emoticons::SetPermanentSet --
# 
#       Takes an iconset and makes it the permanent iconset.
#       Must be careful to free all unused images and arrays etc.

proc ::Emoticons::SetPermanentSet {selected} {
    variable state
    variable smiley
    
    set setsLoaded [list]
    foreach ind [array names state *,loaded] {
	set name [string map [list ",loaded" ""] $ind]
	lappend setsLoaded $name
    }
    if {[info exists smiley]} {
	FreeSmileyArr
    }
    foreach name $setsLoaded {
	if {[string equal $selected $name]} {
	    SetSmileyArr $name
	} else {
	    FreeTmpSet $name   
	}
    }
    unset -nocomplain state
    
    MenuButtonsUpdate
}

proc ::Emoticons::SetSmileyArr {name} {
    variable tmpicons
    variable tmpiconsInv
    variable smiley
    variable smileyInv
    
    foreach ind [array names tmpiconsInv $name,*] {
	set im [string map [list "$name," ""] $ind]
	foreach key $tmpiconsInv($ind) {
	    set smiley($key) $im
	}
	set smileyInv($im) $tmpiconsInv($ind)
    }
}

proc ::Emoticons::FreeSmileyArr {} {
    variable smiley
    variable smileyInv
    
    # This could create empty images for any open dialogs. BAD?
    # @@@ MEMLEAK!
    #eval {image delete} [array names smileyInv]
    unset -nocomplain smiley smileyInv
}

proc ::Emoticons::FreeTmpSet {name} {
    variable meta
    variable state
    variable tmpicons
    variable tmpiconsInv
    
    set ims [list]
    foreach ind [array names tmpiconsInv $name,*] {
	lappend ims [string map [list "$name," ""] $ind]
    }
    # This could create empty images for any open dialogs. BAD?
    # @@@ MEMLEAK!
    #eval {image delete} $ims
    array unset meta $name,*
    array unset tmpicons $name,*
    array unset tmpiconsInv $name,*
    array unset state $name,*
}

proc ::Emoticons::FreeAllTmpSets {} {
    variable meta
    variable state
    variable tmpicons
    variable tmpiconsInv

    set ims [list]
    foreach {key photo} [array get tmpicons ] {
	lappend ims $photo
    }
    eval {image delete} [lsort -unique $ims]
    unset -nocomplain meta state tmpicons tmpiconsInv
}

namespace eval ::Emoticons {
    
    # Keep track of all menu buttons to be able to do "live updates" when
    # the emoticon set changes.
    variable allButtons [list]
}

# Emoticons::MenuButton --
# 
#       A kind of general menubutton for inserting smileys into a text widget.
#       
# Arguments:
#       w           widget path
#       args        -text     inserts directly into text widget
#                   -command  callback command
#       
# Results:
#       chattoken

proc ::Emoticons::MenuButton {w args} {
    global  prefs this    
    variable allButtons

    variable $w
    upvar 0 $w state    

    set state(w)    $w
    set state(args) $args
    
    # If we have -compound left -image ... -label ... working.
    set prefs(haveMenuImage) 0
    if {![string equal $this(platform) "macosx"]} {
	set prefs(haveMenuImage) 1
    }    
    ttk::menubutton $w -style MiniMenubutton -compound image
    eval {MenuButtonConfigure $w} $args
    if {[None]} {
	$w state {disabled}
    }
    lappend allButtons $w
    bind $w <Destroy> +[namespace code [list MenuButtonFree %W]]
    
    return $w
}

proc ::Emoticons::MenuButtonConfigure {w args} {
    variable smiley
    
    # Button image.
    set btim ""
    foreach key {:) :-) ;) ;-) :( :-(} {
	if {[info exists smiley($key)]} {
	    set btim $smiley($key)
	    break
	}
    }
    $w configure -image $btim
    set wmenu $w.m
    destroy $wmenu
    eval {BuildMenu $wmenu} $args
    $w configure -menu $wmenu
    if {[None]} {
	$w state {disabled}
    } else {
	$w state {!disabled}
    }
}

proc ::Emoticons::MenuButtonFree {w} {
    variable $w
    variable allButtons
    
    lprune allButtons $w
    unset -nocomplain $w
}

proc ::Emoticons::MenuButtonsUpdate {} {
    variable allButtons

    foreach w $allButtons {
	variable $w
	upvar 0 $w state    

	eval {MenuButtonConfigure $w} $state(args)
    }
}

proc ::Emoticons::BuildMenu {wmenu args} {
    global  prefs
    variable smiley
    variable smileyInv
    
    foreach {key value} $args {
	
	switch -- $key {
	    -text {
		set type text
		set wtext $value
	    }
	    -command {
		set type command
		set cmd $value
	    }
	}
    }

    set m [menu $wmenu -tearoff 0]
    set ims [lsort -dictionary [array names smileyInv]]

    if {$prefs(haveMenuImage)} {
	
	# Figure out a reasonable width and height.
	set len [llength $ims]
	set nheight [expr int(sqrt($len/1.4)) + 1]

	set i 0
	foreach im $ims {
	    set key [lindex $smileyInv($im) 0]
	    if {[string equal $type "text"]} {
		set mcmd [list Emoticons::InsertSmiley $wtext $im $key]
	    } else {
		set mcmd [concat $cmd [list $im $key]]
	    }
	    set opts {-hidemargin 1}
	    if {$i && ([expr $i % $nheight] == 0)} {
		lappend opts -columnbreak 1
	    }
	    eval {$m add command -image $im -command $mcmd} $opts
	    incr i
	}
    } else {
	foreach im $ims {
	    set key [lindex $smileyInv($im) 0]
	    if {[string equal $type "text"]} {
		set mcmd [list Emoticons::InsertSmiley $wtext $im $key]
	    } else {
		set mcmd [concat $cmd [list $im $key]]
	    }
	    $m add command -label $key -command $mcmd
	}
    }
}

proc ::Emoticons::SortLength {str1 str2} {
    
    return [expr {[string length $str1] < [string length $str2]} ? -1 : 1]
}

proc ::Emoticons::PostMenu {w m x y} {

    if {![string equal [$w cget -state] "disabled"]} {
	tk_popup $m [expr int($x)] [expr int($y)]
    }
}

proc ::Emoticons::InsertSmiley {wtext imname name} {
 
    $wtext insert insert " "
    $wtext image create insert -image $imname -name $name
    $wtext insert insert " "
}

proc ::Emoticons::InsertTextLegend {w name args} {
    variable meta
    variable tmpiconsInv
    
    array set argsArr {-tabs {20 60} -spacing1 2 -wrap word}
    array set argsArr $args
    eval {$w configure} [array get argsArr]
    $w configure -state normal
    $w tag configure tmeta -spacing1 1 -spacing3 1 -lmargin1 10 -lmargin2 20 \
      -tabs [expr [font measure [$w cget -font] Description] + 30]
    $w delete 1.0 end
    
    # Meta data:
    foreach ind [array names meta $name,*] {
	set key [string map [list "$name," ""] $ind]
	$w insert insert "[mc [string totitle $key]]:\t" tmeta
	foreach val $meta($ind) {
	    $w insert insert "$val, " tmeta
	}
	$w delete "end - 3 chars" end
	$w insert insert "\n"
    }
    
    $w insert insert "\t[mc Image]\t[mc text]\n"
    
    # Smileys:
    foreach ind [lsort -dictionary [array names tmpiconsInv $name,*]] {
	set im [string map [list "$name," ""] $ind]
	$w insert insert \t
	$w image create insert -image $im
	$w insert insert \t
	foreach key $tmpiconsInv($ind) {
	    $w insert insert "$key   "
	}
	$w insert insert "\n"
    }
    $w delete "end - 1 chars" end
    $w configure -state disabled
}

proc ::Emoticons::ImportSet {} {
    global  this
    
    set types [list [list [mc "Iconset Archive"] {.jisp}]]
    set fileName [tk_getOpenFile -filetypes $types \
      -title [mc "Import Iconset"]]
    if {[file exists $fileName]} {
	ImportFile $fileName
    }    
    return $fileName
}

proc ::Emoticons::ImportFile {fileName} {
    global  this
    
    set tail [file tail $fileName]
    set name [file rootname $tail]
    if {[lsearch [GetAllSets] $name] >= 0} {
	::UI::MessageBox -icon error -title [mc Error] \
	  -message "Iconset \"$name\" already exists."
	return
    }
    file copy $fileName $this(altEmoticonsPath)
    set dst [file join $this(altEmoticonsPath) $tail]
    if {[catch {
	LoadTmpIconSet $dst
    } err]} {
	::UI::MessageBox -icon error -title [mc Error] \
	  -message "Failed loading iconset \"$name\". $err"
	return
    }
}

# Emoticons::ParseCommandLine --
# 
#       A launchFinalHook that detects any jisp archive files on the command
#       line.

proc ::Emoticons::ParseCommandLine {args} {
    global  argv
   
    if {$args eq {}} {
	set args $argv
    }
    set idx [lsearch $args -file]
    if {$idx < 0} {
	return
    }
    set fileName [lindex $args [incr idx]]
    if {[file extension $fileName] ne ".jisp"} {
	return
    }
    ImportFile $fileName
}

proc ::Emoticons::MacOpenDocument {args} {
    
    foreach fileName $args {
	if {[file extension $fileName] eq ".jisp"} {
	    ImportFile $fileName
	}
    }
}

# Preference page --------------------------------------------------------------

proc  ::Emoticons::InitPrefsHook {} {
    variable priv
    upvar ::Jabber::jprefs jprefs

    set jprefs(emoticonSet) $priv(defaultSet)
    
    # Do NOT store the complete path!
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(emoticonSet) jprefs_emoticonSet $jprefs(emoticonSet)]]
}

proc ::Emoticons::BuildPrefsHook {wtree nbframe} {

    ::Preferences::NewTableItem {Jabber Emoticons} [mc Emoticons]
    
    set wpage [$nbframe page {Emoticons}]    
    BuildPrefsPage $wpage
}

proc ::Emoticons::BuildPrefsPage {wpage} {
    variable wprefpage $wpage
    variable wpreftext
    variable wprefmb
    variable tmpSet
    variable priv
    upvar ::Jabber::jprefs jprefs
    
    set allSets [GetAllSets]

    # This should never happen!
    if {$allSets eq {}} {
	set allSets None
    }

    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -fill both -expand 1 \
      -anchor [option get . dialogAnchor {}]
        
    ttk::label $wc.l -text [mc preficonsel2]
    pack  $wc.l  -side top -anchor w -pady 4
    
    set wmb $wc.mb    
    set wprefmb $wmb
    set menuDef [list]
    foreach name $allSets {
	if {$name eq "default"} {
	    lappend menuDef [list [mc Default] -value default]
	} else {
	    lappend menuDef [list $name -value $name]
	}
    }
    lappend menuDef separator
    lappend menuDef [list [mc None] -value "-"]
    ui::optionmenu $wmb -menulist $menuDef -variable [namespace current]::tmpSet \
      -command [namespace code PrefsSetCmd]
    pack $wmb -side top -anchor w
    
    set wfr $wc.fr
    ttk::frame $wfr -padding [option get . groupSmallPadding {}]
    pack $wfr -side top -anchor w -fill both -expand 1
    
    ttk::scrollbar $wfr.ysc -orient vertical -command [list $wfr.t yview]
    text $wfr.t -yscrollcommand [list $wfr.ysc set] -width 20 -height 14 \
      -highlightthickness 0 -bd 0
    
    grid  $wfr.t   $wfr.ysc  -sticky ns
    grid  $wfr.t   -sticky news
    grid columnconfigure $wfr 0 -weight 1
    grid rowconfigure    $wfr 0 -weight 1
    
    set wpreftext $wfr.t
    
    ttk::button $wc.imp -text "[mc {Import Iconset}]..." \
      -command [namespace current]::ImportSetToPrefs
    pack $wc.imp -side top -anchor w -pady 4
    
    if {$jprefs(emoticonSet) eq "-"} {
	set tmpSet "-"
    } elseif {[lsearch $allSets $jprefs(emoticonSet)] < 0} {
	set tmpSet $priv(defaultSet)
    } else {
	set tmpSet $jprefs(emoticonSet)
    }
    PrefsSetCmd $tmpSet
    
    if {[tk windowingsystem] ne "aqua"} {
	if {![catch {package require tkdnd}]} {
	    DnDInit $wpreftext
	}
    }
}

proc ::Emoticons::PrefsSetCmd {value} {
    variable wprefpage
    variable wpreftext 
    variable state
    variable tmpSet
    variable priv
    upvar ::Jabber::jprefs jprefs
    
    if {$tmpSet eq "-"} {
	$wpreftext configure -state normal
	$wpreftext delete 1.0 end
	$wpreftext configure -state disabled
    } else {
	if {![info exists state($tmpSet,loaded)]} {
	    if {[catch {
		LoadTmpIconSet $state($tmpSet,path)
	    } err]} {
		puts "catch LoadTmpIconSet err=$err"
		set str [mc jamessemoticonfail2 $tmpSet]
		append str "\n" "[mc Error]: $err"
		::UI::MessageBox -icon error -title [mc Error] \
		  -message $str -parent [winfo toplevel $wprefpage]
		set priv(havezip) 0
		set jprefs(emoticonSet) $priv(defaultSet)
		set tmpSet $priv(defaultSet)
		LoadTmpIconSet [GetPrefSetPathExists]
		return
	    }
	}
	InsertTextLegend $wpreftext $tmpSet
    }
}

proc ::Emoticons::ImportSetToPrefs {} {
    global  this
    variable wprefpage
    variable wprefmb
    
    set types [list [list [mc "Iconset Archive"] {.jisp}]]
    set fileName [tk_getOpenFile -parent [winfo toplevel $wprefpage] \
      -filetypes $types -title [mc "Import Iconset"]]
    if {[file exists $fileName]} {
	ImportFileToPrefs $fileName
    }
}

proc ::Emoticons::ImportFileToPrefs {fileName} {
    global  this
    variable wprefpage
    variable wprefmb
    
    set tail [file tail $fileName]
    set name [file rootname $tail]
    if {[lsearch [GetAllSets] $name] >= 0} {
	::UI::MessageBox -icon error -title [mc Error] \
	  -message [mc jamessemoticonexists $name] \
	  -parent [winfo toplevel $wprefpage]
	return
    }
    file copy $fileName $this(altEmoticonsPath)
    set dst [file join $this(altEmoticonsPath) $tail]
    if {[catch {
	LoadTmpIconSet $dst
    } err]} {
	set str [mc jamessemoticonfail2 $name]
	append str "\n" "[mc Error]: $err"
	::UI::MessageBox -icon error -title [mc Error] \
	  -message $str -parent [winfo toplevel $wprefpage]
    } else {
	if {[winfo exists $wprefmb]} {
	    set mDef [$wprefmb cget -menulist]
	    set idx [lsearch $mDef separator]
	    set mDef [linsert $mDef $idx [list $name -value $name]]
	    $wprefmb configure -menulist $mDef
	}
    }
}

proc ::Emoticons::DnDInit {win} {
    
    dnd bindtarget $win text/uri-list <Drop> \
      [namespace code [list DnDDrop %W %D %T]]
    dnd bindtarget $win text/uri-list <DragEnter> \
      [namespace code [list DnDEnter %W %A %D %T]]
    dnd bindtarget $win text/uri-list <DragLeave> \
      [namespace code [list DnDLeave %W %D %T]]
}

proc ::Emoticons::DnDDrop {win data dndtype} {
    
    # Take only first file.
    set f [lindex $data 0]
    if {[file extension $f] eq ".jisp"} {
	
	# Strip off any file:// prefix.
	set f [string map {file:// ""} $f]
	set f [::uri::urn::unquote $f]
	ImportFileToPrefs $f
    }
}

proc ::Emoticons::DnDEnter {win action data dndtype} {
    set f [lindex $data 0]
    if {[file extension $f] eq ".jisp"} {
	focus $win
	set act "default"
    } else {
	set act "none"
    }
    return $act
}

proc ::Emoticons::DnDLeave {win data dndtype} {	
    focus [winfo toplevel $win] 
}

proc ::Emoticons::FreePrefsPage {} {
    
}

proc ::Emoticons::SavePrefsHook {} {
    variable tmpSet
    upvar ::Jabber::jprefs jprefs
    
    set new 0
    if {![string equal $jprefs(emoticonSet) $tmpSet]} {
	set new 1
    }
    FreePrefsPage
    set jprefs(emoticonSet) $tmpSet
    if {$new} {
	SetPermanentSet $tmpSet
    }
}

proc ::Emoticons::CancelPrefsHook {} {
    variable tmpSet
    upvar ::Jabber::jprefs jprefs

    # Since the menubutton is used both for viewing and setting,
    # I think we skip this warning.
    if {![string equal $jprefs(emoticonSet) $tmpSet]} {
	#::Preferences::HasChanged
    }
    FreePrefsPage
    FreeAllTmpSets
}

proc ::Emoticons::UserDefaultsHook {} {
    variable tmpSet
    upvar ::Jabber::jprefs jprefs
    
    set allSets [GetAllSets]
    if {[lsearch $allSets $jprefs(emoticonSet)] < 0} {
	set tmpSet $priv(defaultSet)
    } else {
	set tmpSet $jprefs(emoticonSet)
    }
}

#-------------------------------------------------------------------------------
