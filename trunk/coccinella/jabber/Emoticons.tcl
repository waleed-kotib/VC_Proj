#  Emoticons.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements handling and parsing of emoticons (smileys).
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Emoticons.tcl,v 1.3 2004-04-04 13:37:26 matben Exp $


package provide Emoticons 1.0


namespace eval ::Emoticons:: {

    ::hooks::add initHook ::Emoticons::Init


}

proc ::Emoticons::Init { } {
    global  this
    
    variable priv
    variable smiley
    variable smileyExp
    variable smileyLongNames

    # 'iconsets(name,key)' map from a text string (key) and iconset name
    # to an image name.
    variable iconsets
    
    # 'iconsetsInv(name,image)' map from an image and named iconset to a
    # list of keys, which is the inverse of the above.
    variable iconsetsInv

    ::Debug 2 "::Emoticons::Init"
    
    # Cache stuff we need later.
    if {[catch {package require vfs::zip}]} {
	set priv(havezip) 0
    } else {
	set priv(havezip) 1
    }
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
    #parray priv
    
    # Smiley icons. The "short" types.
    foreach {key name} {
	":-)"          classic 
	":-("          sad 
	":-0"          shocked 
	";-)"          wink
	";("           cry
	":o"           embarrassed
	":D"           grin
	"x)"           knocked
	":|"           normal
	":S"           puzzled
	":p"           silly
	":O"           shocked
	":x"           speechless} {
	    set imSmile($name) [image create photo -format gif  \
	      -file [file join $this(imagePath) smileys "smiley-${name}.gif"]]
	    set smiley($key) $imSmile($name)
    }
	
    # Duplicates:
    foreach {key name} {
	":)"           classic 
	";)"           wink} {
	    set smiley($key) $imSmile($name)
    }
    set smileyExp {(}
    foreach key [array names smiley] {
	append smileyExp "$key|"
    }
    set smileyExp [string trimright $smileyExp "|"]
    append smileyExp {)}
    regsub  {[)(|]} $smileyExp {\\\0} smileyExp
    
    # The "long" smileys are treated differently; only loaded when needed.
    set smileyLongNames {
	:alien:
	:angry:
	:bandit:
	:beard:
	:bored:
	:calm:
	:cat:
	:cheeky:
	:cheerful:
	:chinese:
	:confused:
	:cool:
	:cross-eye:
	:cyclops:
	:dead:
	:depressed:
	:devious:
	:disappoin:
	:ditsy:
	:dog:
	:ermm:
	:evil:
	:evolved:
	:gasmask:
	:glasses:
	:happy:
	:hurt:
	:jaguar:
	:kommie:
	:laugh:
	:lick:
	:mad:
	:nervous:
	:ninja:
	:ogre:
	:old:
	:paranoid:
	:pirate:
	:ponder:
	:puzzled:
	:rambo:
	:robot:
	:eek:
	:shocked:
	:smiley:
	:sleeping:
	:smoker:
	:surprised:
	:tired:
	:vampire:
    }
}
    
# Emoticons::Parse --
# 
#       Parses text into a list with every second element an image create command.
#       
# Arguments:
#       str         the text string, tcl special chars already protected
#       
# Results:
#       A list {str {image create ..} ?str {image create ..} ...?}

proc ::Emoticons::Parse {str} {
    global  this
    
    variable smiley
    variable smileyExp
    variable smileyLongNames
	
    # Protect Tcl special characters, quotes included.
    regsub -all {([][$\\{}"])} $str {\\\1} str
    
    # Since there are about 60 smileys we need to be economical here.    
    # Check first if there are any short smileys.
	
    # Protect all  *regexp*  special characters. Regexp hell!!!
    # Carefully embrace $smile since may contain ; etc.
    
    foreach smile [array names smiley] {
	set sub "\} \{image create end -image $smiley($smile) -name \{$smile\}\} \{"
	regsub -all {[);(|]} $smile {\\\0} smileExp
	regsub -all $smileExp $str $sub str
    }
	
    # Now check for any "long" names, such as :angry: :cool: etc.
    set candidateList {}
    set ndx 0
    
    while {[regexp -start $ndx -indices -- {:[a-zA-Z]+:} $str ind]} {
	set ndx [lindex $ind 1]
	set candidate [string range $str [lindex $ind 0] [lindex $ind 1]]
	if {[lsearch $smileyLongNames $candidate] >= 0} {
	    lappend candidateList $candidate
	    
	    # Load image if not done that.
	    if {![info exists smileyLongIm($candidate)]} {
		set fileName "smiley-[string trim $candidate :].gif"
		set smileyLongIm($candidate) [image create photo -format gif  \
		  -file [file join $this(imagePath) smileys $fileName]]	    
	    }
	}
    }
    if {[llength $candidateList]} {
	regsub -all {\\|&} $str {\\\0} str
	foreach smile $candidateList {
	    set sub "\} \{image create end -image $smileyLongIm($smile) -name $smile\} \{"
	    regsub -all $smile $str $sub str
	}
    }
    
    return "\{$str\}"
}


proc ::Emoticons::Load {path} {
    
    variable priv
    
    # The dir variable points to the (virtual) directory containing it all.
    set dir $path
    set name [file rootname [file tail $path]]
    cd [file dirname $path]
    puts "1: [pwd]: [glob *]"
    
    if {[file extension $path] == ".jisp"} {
	if {$priv(havezip)} {
	    set name [file rootname [file tail $path]]
	    if {[catch {
		set fd [vfs::zip::Mount $path $name]
		puts "mounts $path"
		puts "2: [pwd]: [glob *]"
	    } err]} {
		return -code error $err
	    }
	    set dir1 [file join [file dirname $path] $name]
	    puts "dir1=$dir1"
	    cd $dir1
	    puts "name=$name"
	    puts "3: [pwd]: [glob *]"
	    set dir [file join [file dirname $path] $name $name]
	} else {
	    return -code error "cannot read jisp archive without vfs::zip"
	}
    }
    puts "path=$path"
    puts "dir =$dir"
    set icondefPath [file join $dir icondef.xml]
    puts "icondefPath=$icondefPath"
    cd $dir
    puts "4: [pwd]: [glob *]"
    if {![file isfile $icondefPath]} {
	return -code error "missing icondef.xml file in archive"
    }
    set f [open $icondefPath]
    set xmldata [read $f]
    close $f
    
    FreeSet $name
    
    # Parse data.
    ParseIconDef $name $dir $xmldata
    
    cd $::this(path)
    if {[info exists name]} {
	#vfs::zip::Unmount $fd $name
    }
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
    
    foreach elem [tinydom::children $xmllist] {
	set tag [tinydom::tagname $elem]
	lappend meta($name,$tag) [tinydom::chdata $elem]
    }
    parray meta
}

proc ::Emoticons::ParseIcon {name dir xmllist} {
    global  this
    
    variable iconsets
    variable iconsetsInv
    variable priv

    foreach elem [tinydom::children $xmllist] {
	set tag [tinydom::tagname $elem]
	
	switch -- $tag {
	    text {
		lappend keyList [tinydom::chdata $elem]
	    }
	    object {
		set object [tinydom::chdata $elem]
		array set attrArr [tinydom::attrlist $elem]
		set mime $attrArr(mime)
	    }
	}
    }
    
    switch -- $mime {
	image/gif {
	    set im [image create photo -format gif  \
	      -file [file join $dir $object]]
	    foreach key $keyList {
		set iconsets($name,$key) $im
	    }
	}
	image/png {
	    # If we rely on QuickTimeTcl here we cannot be in vfs.
	    puts "object=$object,\t keyList=$keyList"
	    set f [file join $dir $object]
	    if {$priv(needtmp)} {
		set tmp [file join $this(tmpPath) $object]
		file copy -force $f $tmp
		set f $tmp
	    }
	    set im [eval {image create photo -file $f} $priv(pngformat)]
	    foreach key $keyList {
		set iconsets($name,$key) $im
	    }
	}
    }
    if {[info exists im]} {
	set iconsetsInv($name,$im) $keyList
    }
}

proc ::Emoticons::FreeSet {name} {
    variable meta
    variable iconsets
    variable iconsetsInv
    
    array unset meta $name,*
    array unset iconsets $name,*
    array unset iconsetsInv $name,*
}

# Emoticons::MenuButton --
# 
#       A kind of general menubutton for inserting smileys into a text widget.

proc ::Emoticons::MenuButton {w wtext} {
    global  prefs this
    
    variable smiley

    # If we have -compound left -image ... -label ... working.
    set prefs(haveMenuImage) 0
    if {([package vcompare [info tclversion] 8.4] >= 0) &&  \
      ![string equal $this(platform) "macosx"]} {
	set prefs(haveMenuImage) 1
    }

    # Workaround for missing -image option on my macmenubutton.
    if {[string equal $this(platform) "macintosh"] && \
      [string length [info command menubuttonOrig]]} {
	set menubuttonImage menubuttonOrig
    } else {
	#set menubuttonImage menubutton
	set menubuttonImage button
    }
    set wmenu ${w}.m
    #$menubuttonImage $w -menu $wmenu -image $smiley(:\))
    $menubuttonImage $w -image $smiley(:\)) -bd 2 -width 16 -height 16
    
    ::Emoticons::BuildMenu $wmenu $wtext

    bind $w <Button-1> [list [namespace current]::PostMenu $wmenu %X %Y]
    return $w
}

proc ::Emoticons::BuildMenu {wmenu wtext} {
    global  prefs
    variable smiley
    
    set m [menu $wmenu -tearoff 0]

    if {$prefs(haveMenuImage)} {
	set names [array names smiley]
	set i 0
	foreach name $names {
	    set cmd [list Emoticons::InsertSmiley $wtext $smiley($name) $name]
	    set opts {-hidemargin 1}
	    if {$i && ([expr $i % 4] == 0)} {
		lappend opts -columnbreak 1
	    }
	    eval {$m add command -image $smiley($name) -command $cmd} $opts
	    incr i
	}
    } else {
	foreach name [array names smiley] {
	    set cmd [list Emoticons::InsertSmiley $wtext $smiley($name) $name]
	    $m add command -label $name -command $cmd
	}
    }
}

proc ::Emoticons::BuildMenuNEW {name wmenu wtext} {
    global  prefs
    variable iconsets
    variable iconsetsInv
    
    set m [menu $wmenu -tearoff 0]
    set ims [array names iconsetsInv]

    if {$prefs(haveMenuImage)} {
	
	# Figure out a reasonable width and height.
	set len [llength $ims]
	set nheight [expr int(sqrt($len/1.4)) + 1]
	
	set i 0
	foreach im $ims {
	    set key [lindex $iconsetsInv($name,$im)]
	    set cmd [list Emoticons::InsertSmiley $wtext $im $key]
	    set opts {-hidemargin 1}
	    if {$i && ([expr $i % $nheight] == 0)} {
		lappend opts -columnbreak 1
	    }
	    eval {$m add command -image $im -command $cmd} $opts
	    incr i
	}
    } else {
	foreach im $ims {
	    set key [lindex $iconsetsInv($name,$im)]
	    set cmd [list Emoticons::InsertSmiley $wtext $im $key]
	    $m add command -label $iconsetsInv($name,$im) -command $cmd
	}
    }
}

proc ::Emoticons::PostMenu {m x y} {

    tk_popup $m [expr int($x)] [expr int($y)]
}

proc ::Emoticons::InsertSmiley {wtext imname name} {
 
    $wtext insert insert " "
    $wtext image create insert -image $imname -name $name
    $wtext insert insert " "
}

proc ::Emoticons::TextLegend {w name args} {
    variable meta
    variable iconsetsInv
    
    array set argsArr {-tabs {20 60} -spacing1 2 -wrap word}
    array set argsArr $args
    eval {text $w} [array get argsArr]
    $w tag configure tmeta -spacing1 1 -spacing3 1 -lmargin1 10 -lmargin2 20 \
      -tabs [expr [font measure [$w cget -font] Description] + 30]
    
    # Meta data:
    foreach ind [array names meta $name,*] {
	set key [string map [list "$name," ""] $ind]
	$w insert insert "[string totitle $key]:\t" tmeta
	foreach val $meta($ind) {
	    $w insert insert $val tmeta
	}
	$w insert insert "\n"
    }
    
    $w insert insert "\tImage\tText\n"
    
    foreach ind [array names iconsetsInv $name,*] {
	set im [string map [list "$name," ""] $ind]
	$w insert insert \t
	$w image create insert -image $im
	$w insert insert \t
	foreach key $iconsetsInv($ind) {
	    $w insert insert "$key   "
	}
	$w insert insert "\n"
    }
    return $w
}

#-------------------------------------------------------------------------------
