#  Emoticons.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements handling and parsing of emoticons (smileys).
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Emoticons.tcl,v 1.31 2005-06-05 14:54:12 matben Exp $

package provide Emoticons 1.0

namespace eval ::Emoticons:: {

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Emoticons::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Emoticons::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Emoticons::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Emoticons::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Emoticons::UserDefaultsHook

    ::hooks::register initHook               ::Emoticons::Init

    variable priv
    set priv(defaultSet) "default"
}

proc ::Emoticons::Init { } {
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
    if {[catch {package require vfs::zip}]} {
	set priv(havezip) 0
    } elseif {[info exists starkit::topdir]} {
	set priv(havezip) 1
    } elseif {[catch {package require Memchan}]} {
	set priv(havezip) 0
    } else {
	set priv(havezip) 1
    }

    # Cache stuff we need later.
    set priv(havepng)      [::Plugins::HaveImporterForMime image/png]
    set priv(QuickTimeTcl) [::Plugins::HavePackage QuickTimeTcl]
    set priv(Img)          [::Plugins::HavePackage Img]
    if {$priv(Img)} {
	set priv(needtmp)   0
	set priv(pngformat) [list -format png]
    } else {
	set priv(needtmp)   1
	set priv(pngformat) {}
    }
    ::Debug 4 "sets=[::Emoticons::GetAllSets]"
    ::Debug 4 "\t [::Emoticons::GetPrefSetPathExists]"
    
    # Load set.
    # Even if we succeed to get the vfs::zip package, it doesn't check
    # the Memchan package, and can therefore still fail.
    if {[catch {
	::Emoticons::LoadTmpIconSet [::Emoticons::GetPrefSetPathExists]
    } err]} {
	::Debug 4 "\t catch: $err"
	set priv(havezip) 0
	set jprefs(emoticonSet) $priv(defaultSet)
	::Emoticons::LoadTmpIconSet [::Emoticons::GetPrefSetPathExists]
    }
    ::Emoticons::SetPermanentSet $jprefs(emoticonSet)
}

proc ::Emoticons::Exists {word} {
    variable smiley
    
    if {[info exists smiley($word)]} {
	return 1
    } else {
	return 0
    }
}

proc ::Emoticons::Make {w word} {
    variable smiley
    
    if {[info exists smiley($word)]} {
	$w image create end -image $smiley($word) -name $word
    }
}

proc ::Emoticons::GetAllSets { } {
    global  this
    variable priv
    variable state
    
    set setList {}
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

proc ::Emoticons::GetPrefSetPathExists { } {
    global  this
    variable priv
    upvar ::Jabber::jprefs jprefs

    # Start with the failsafe set.
    set path [file join $this(emoticonsPath) $priv(defaultSet)]
    
    foreach dir [list $this(emoticonsPath) $this(altEmoticonsPath)] {
	set f [file join $dir $jprefs(emoticonSet)]
	set fjisp ${f}.jisp
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
		set fdzip [vfs::zip::Mount $path $mountpath]
	    } err]} {
		return -code error $err
	    }
	    
	    # We cannot be sure of that the name of the archive is identical 
	    # with the name of the original directory.
	    set zipdir [lindex [glob -nocomplain -directory $mountpath *] 0]
	    set dir $zipdir
	} else {
	    return -code error "cannot read jisp archive without vfs::zip"
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

    set token [tinydom::parse $xmldata]
    set xmllist [tinydom::documentElement $token]
    
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
		# graphic does not comply with JEP-0038!
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

    #puts "::Emoticons::SetPermanentSet selected=$selected"
    set setsLoaded {}
    foreach ind [array names state *,loaded] {
	set name [string map [list ",loaded" ""] $ind]
	lappend setsLoaded $name
    }
    #puts "\t setsLoaded=$setsLoaded"
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
}

proc ::Emoticons::SetSmileyArr {name} {
    variable tmpicons
    variable tmpiconsInv
    variable smiley
    variable smileyInv
    
    #puts "::Emoticons::SetSmileyArr name=$name"
    foreach ind [array names tmpiconsInv $name,*] {
	set im [string map [list "$name," ""] $ind]
	foreach key $tmpiconsInv($ind) {
	    set smiley($key) $im
	}
	set smileyInv($im) $tmpiconsInv($ind)
    }
}

proc ::Emoticons::FreeSmileyArr { } {
    variable smiley
    variable smileyInv
    
    #puts "::Emoticons::FreeSmileyArr"
    
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
    
    #puts "::Emoticons::FreeTmpSet name=$name"
    set ims {}
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

proc ::Emoticons::FreeAllTmpSets { } {
    variable meta
    variable state
    variable tmpicons
    variable tmpiconsInv

    set ims {}
    foreach {key photo} [array get tmpicons ] {
	lappend ims $photo
    }
    #puts ">>>>>>>>>>{image delete} [lsort -unique $ims]"
    eval {image delete} [lsort -unique $ims]
    unset -nocomplain meta state tmpicons tmpiconsInv
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
    variable smiley

    # If we have -compound left -image ... -label ... working.
    set prefs(haveMenuImage) 0
    if {([package vcompare [info tclversion] 8.4] >= 0) &&  \
      ![string equal $this(platform) "macosx"]} {
	set prefs(haveMenuImage) 1
    }
    if {[string match "mac*" $this(platform)]} {
	set btbd 2
    } else {
	set btbd 1
    }

    # Workaround for missing -image option on my macmenubutton.
    if {[string equal $this(platform) "macintosh"] && \
      [string length [info command menubuttonOrig]]} {
	set menubuttonImage menubuttonOrig
    } else {
	set menubuttonImage button
    }
    
    # Button image.
    set btim ""
    set size 16
    foreach key {:) :-) ;) ;-) :( :-(} {
	if {[info exists smiley($key)]} {
	    set btim $smiley($key)
	    set size [image width $btim]
	    if {$size < 16} {
		set size 16
	    }
	    break
	}
    }
    set wmenu ${w}.m
    $menubuttonImage $w -image $btim -bd $btbd -width $size -height $size
    
    eval {::Emoticons::BuildMenu $wmenu} $args

    bind $w <Button-1> [list [namespace current]::PostMenu $w $wmenu %X %Y]
    return $w
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
	$w insert insert "[string totitle $key]:\t" tmeta
	foreach val $meta($ind) {
	    $w insert insert "$val, " tmeta
	}
	$w delete "end - 3 chars" end
	$w insert insert "\n"
    }
    
    $w insert insert "\t[mc Image]\t[mc Text]\n"
    
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

# Preference page --------------------------------------------------------------

proc  ::Emoticons::InitPrefsHook { } {
    variable priv
    upvar ::Jabber::jprefs jprefs

    set jprefs(emoticonSet) $priv(defaultSet)
    
    # Do NOT store the complete path!
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(emoticonSet) jprefs_emoticonSet $jprefs(emoticonSet)]]
}

proc ::Emoticons::BuildPrefsHook {wtree nbframe} {

    $wtree newitem {Jabber Emoticons} -text [mc {Emoticons}]
    
    set wpage [$nbframe page {Emoticons}]    
    ::Emoticons::BuildPrefsPage $wpage
}

proc ::Emoticons::BuildPrefsPage {wpage} {
    variable wpreftext 
    variable tmpSet
    variable priv
    upvar ::Jabber::jprefs jprefs
    
    set fontS  [option get . fontSmall {}]    
    set fontSB [option get . fontSmallBold {}]    

    set wpop $wpage.pop
    set wfr $wpage.fr
    set wpreftext $wfr.t
    set wysc $wfr.ysc
    set allSets [::Emoticons::GetAllSets]
    
    # This should never happen!
    if {[llength $allSets] == 0} {
	set allSets None
    }
    label $wpage.l -text [mc preficonsel]
    pack  $wpage.l -side top -anchor w -padx 8 -pady 4
    eval {tk_optionMenu $wpop [namespace current]::tmpSet} $allSets
    labelframe $wfr -labelwidget $wpop -padx 6 -pady 4
    pack $wfr -side top -anchor w -padx 8 -pady 4 -fill both -expand 1
    
    scrollbar $wysc -orient vertical -command [list $wpreftext yview]
    text $wpreftext -yscrollcommand [list $wysc set] -width 20 -height 10
    grid $wpreftext -row 0 -column 0 -sticky news
    grid $wysc -row 0 -column 1 -sticky ns
    grid columnconfigure $wfr 0 -weight 1
    grid rowconfigure    $wfr 0 -weight 1

    trace add variable [namespace current]::tmpSet write  \
      [namespace current]::PopCmd

    if {[lsearch $allSets $jprefs(emoticonSet)] < 0} {
	set tmpSet $priv(defaultSet)
    } else {
	set tmpSet $jprefs(emoticonSet)
    }
}

proc ::Emoticons::PopCmd {name1 name2 op} {
    variable wpreftext 
    variable state
    variable tmpSet
    variable priv
    upvar ::Jabber::jprefs jprefs
    upvar $name1 var

    if {![info exists state($var,loaded)]} {
	if {[catch {
	    ::Emoticons::LoadTmpIconSet $state($var,path)
	} err]} {
	    ::UI::MessageBox -icon error -title [mc Error] \
	      -message "Failed loading iconset $var. $err" \
	      -parent [winfo toplevel $wpreftext]
	    set priv(havezip) 0
	    set jprefs(emoticonSet) $priv(defaultSet)
	    set tmpSet $priv(defaultSet)
	    ::Emoticons::LoadTmpIconSet [::Emoticons::GetPrefSetPathExists]
	    return
	}
    }
    ::Emoticons::InsertTextLegend $wpreftext $var
}

proc ::Emoticons::FreePrefsPage { } {
    
    trace remove variable [namespace current]::tmpSet write  \
      [namespace current]::PopCmd
}

proc ::Emoticons::SavePrefsHook { } {
    variable tmpSet
    upvar ::Jabber::jprefs jprefs

    if {![string equal $jprefs(emoticonSet) $tmpSet]} {
	::Emoticons::SetPermanentSet $tmpSet

    }
    ::Emoticons::FreePrefsPage
    set jprefs(emoticonSet) $tmpSet
}

proc ::Emoticons::CancelPrefsHook { } {
    variable tmpSet
    upvar ::Jabber::jprefs jprefs

    # Since the menubutton is used both for viewing and setting,
    # I think we skip this warning.
    if {![string equal $jprefs(emoticonSet) $tmpSet]} {
	#::Preferences::HasChanged
    }
    ::Emoticons::FreePrefsPage
    ::Emoticons::FreeAllTmpSets
}

proc ::Emoticons::UserDefaultsHook { } {
    variable tmpSet
    upvar ::Jabber::jprefs jprefs
    
    set allSets [::Emoticons::GetAllSets]
    if {[lsearch $allSets $jprefs(emoticonSet)] < 0} {
	set tmpSet $priv(defaultSet)
    } else {
	set tmpSet $jprefs(emoticonSet)
    }
}

#-------------------------------------------------------------------------------
