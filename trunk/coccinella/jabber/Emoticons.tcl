#  Emoticons.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements handling and parsing of emoticons (smileys).
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Emoticons.tcl,v 1.1 2004-03-31 07:53:59 matben Exp $


package provide Emoticons 1.0


namespace eval ::Emoticons:: {

    ::hooks::add initHook ::Emoticons::Init


}

proc ::Emoticons::Init { } {
    global  this
    
    variable smiley
    variable smileyExp
    variable smileyLongNames
    
    ::Debug 2 "::Emoticons::Init"    
    
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


proc ::Emoticons::Load {dir} {
    
    
    
}

proc ::Emoticons::ParseIconDef {dir xmldata} {

    
    
}

#-------------------------------------------------------------------------------
