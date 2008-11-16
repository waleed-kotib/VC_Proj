# Mood.tcl --
# 
#       User Mood using PEP recommendations over PubSub library code.
#
#  Copyright (c) 2007-2008 Mats Bengtsson
#  Copyright (c) 2006 Antonio Cano Damas
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
#  $Id: Mood.tcl,v 1.50 2008-08-19 12:40:41 matben Exp $

package require jlib::pep

namespace eval ::Mood {

    component::define Mood "Communicate information about user moods"
    
    # Shall we display all moods in menus or just a subset?
    set ::config(mood,showall) 1
}

proc ::Mood::Init {} {
    global  config

    component::register Mood

    ::Debug 2 "::Mood::Init"

    # Add event hooks.
    ::hooks::register jabberInitHook        ::Mood::JabberInitHook
    ::hooks::register loginHook             ::Mood::LoginHook
    ::hooks::register logoutHook            ::Mood::LogoutHook

    variable moodNode
    set moodNode "http://jabber.org/protocol/mood"

    variable xmlns
    set xmlns(mood)        "http://jabber.org/protocol/mood"
    set xmlns(mood+notify) "http://jabber.org/protocol/mood+notify"
    set xmlns(node_config) "http://jabber.org/protocol/pubsub#node_config"

    variable state

    variable myMoods
    set myMoods {
	angry       anxious     ashamed     bored
	curious     depressed   excited     happy
	in_love     invincible  jealous     nervous
	sad         sleepy      stressed    worried
    }
    
    variable allMoods
    set allMoods {
	afraid 	    amazed      angry       annoyed 
	anxious     aroused     ashamed     bored 
	brave       calm        cold        confused 
	contented   cranky      curious     depressed 
	disappointed disgusted  distracted  embarrassed 
	excited     flirtatious frustrated  grumpy 
	guilty      happy       hot         humbled 
	humiliated  hungry      hurt        impressed 
	in_awe      in_love     indignant   interested 
	intoxicated invincible  jealous     lonely 
	mean        moody       nervous     neutral 
	offended    playful     proud       relieved 
	remorseful  restless    sad         sarcastic 
	serious     shocked     shy         sick 
	sleepy      stressed    surprised   thirsty 
	worried 
    }

    # Mood text strings.
    variable moodText
    set moodText [dict create]
    dict set moodText afraid [mc "Afraid"]
    dict set moodText amazed [mc "Amazed"]
    dict set moodText angry [mc "Angry"]
    dict set moodText annoyed [mc "Annoyed"]
    dict set moodText anxious [mc "Anxious"]
    dict set moodText aroused [mc "Aroused"]
    dict set moodText ashamed [mc "Ashamed"]
    dict set moodText bored [mc "Bored"]
    dict set moodText brave [mc "Brave"]
    dict set moodText calm [mc "Calm"]
    dict set moodText cold [mc "Cold"]
    dict set moodText confused [mc "Confused"]
    dict set moodText contented [mc "Contented"]
    dict set moodText cranky [mc "Cranky"]
    dict set moodText curious [mc "Curious"]
    dict set moodText depressed [mc "Depressed"]
    dict set moodText disappointed [mc "Disappointed"]
    dict set moodText disgusted [mc "Disgusted"]
    dict set moodText distracted [mc "Distracted"]
    dict set moodText embarrassed [mc "Embarrassed"]
    dict set moodText excited [mc "Excited"]
    dict set moodText flirtatious [mc "Flirtatious"]
    dict set moodText frustrated [mc "Frustrated"]
    dict set moodText grumpy [mc "Grumpy"]
    dict set moodText guilty [mc "Guilty"]
    dict set moodText happy [mc "Happy"]
    dict set moodText hot [mc "Hot"]
    dict set moodText humbled [mc "Humbled"]
    dict set moodText humiliated [mc "Humiliated"]
    dict set moodText hungry [mc "Hungry"]
    dict set moodText hurt [mc "Hurt"]
    dict set moodText impressed [mc "Impressed"]
    dict set moodText in_awe [mc "In awe"]
    dict set moodText in_love [mc "In love"]
    dict set moodText indignant [mc "Indignant"]
    dict set moodText interested [mc "Interested"]
    dict set moodText intoxicated [mc "Intoxicated"]
    dict set moodText invincible [mc "Invincible"]
    dict set moodText jealous [mc "Jealous"]
    dict set moodText lonely [mc "Lonely"]
    dict set moodText mean [mc "Mean"]
    dict set moodText moody [mc "Moody"]
    dict set moodText nervous [mc "Nervous"]
    dict set moodText neutral [mc "Neutral"]
    dict set moodText offended [mc "Offended"]
    dict set moodText playful [mc "Playful"]
    dict set moodText proud [mc "Proud"]
    dict set moodText relieved [mc "Relieved"]
    dict set moodText remorseful [mc "Remorseful"]
    dict set moodText restless [mc "Restless"]
    dict set moodText sad [mc "Sad"]
    dict set moodText sarcastic [mc "Sarcastic"]
    dict set moodText serious [mc "Serious"]
    dict set moodText shocked [mc "Shocked"]
    dict set moodText shy [mc "Shy"]
    dict set moodText sick [mc "Sick"]
    dict set moodText sleepy [mc "Sleepy"]
    dict set moodText stressed [mc "Stressed"]
    dict set moodText surprised [mc "Surprised"]
    dict set moodText thirsty [mc "Thirsty"]
    dict set moodText worried [mc "Worried"]

    variable moodTextSmall
    set moodTextSmall [dict create]
    dict set moodTextSmall afraid [mc "afraid"]
    dict set moodTextSmall amazed [mc "amazed"]
    dict set moodTextSmall angry [mc "angry"]
    dict set moodTextSmall annoyed [mc "annoyed"]
    dict set moodTextSmall anxious [mc "anxious"]
    dict set moodTextSmall aroused [mc "aroused"]
    dict set moodTextSmall ashamed [mc "ashamed"]
    dict set moodTextSmall bored [mc "bored"]
    dict set moodTextSmall brave [mc "brave"]
    dict set moodTextSmall calm [mc "calm"]
    dict set moodTextSmall cold [mc "cold"]
    dict set moodTextSmall confused [mc "confused"]
    dict set moodTextSmall contented [mc "contented"]
    dict set moodTextSmall cranky [mc "cranky"]
    dict set moodTextSmall curious [mc "curious"]
    dict set moodTextSmall depressed [mc "depressed"]
    dict set moodTextSmall disappointed [mc "disappointed"]
    dict set moodTextSmall disgusted [mc "disgusted"]
    dict set moodTextSmall distracted [mc "distracted"]
    dict set moodTextSmall embarrassed [mc "embarrassed"]
    dict set moodTextSmall excited [mc "excited"]
    dict set moodTextSmall flirtatious [mc "flirtatious"]
    dict set moodTextSmall frustrated [mc "frustrated"]
    dict set moodTextSmall grumpy [mc "grumpy"]
    dict set moodTextSmall guilty [mc "guilty"]
    dict set moodTextSmall happy [mc "happy"]
    dict set moodTextSmall hot [mc "hot"]
    dict set moodTextSmall humbled [mc "humbled"]
    dict set moodTextSmall humiliated [mc "humiliated"]
    dict set moodTextSmall hungry [mc "hungry"]
    dict set moodTextSmall hurt [mc "hurt"]
    dict set moodTextSmall impressed [mc "impressed"]
    dict set moodTextSmall in_awe [mc "in awe"]
    dict set moodTextSmall in_love [mc "in love"]
    dict set moodTextSmall indignant [mc "indignant"]
    dict set moodTextSmall interested [mc "interested"]
    dict set moodTextSmall intoxicated [mc "intoxicated"]
    dict set moodTextSmall invincible [mc "invincible"]
    dict set moodTextSmall jealous [mc "jealous"]
    dict set moodTextSmall lonely [mc "lonely"]
    dict set moodTextSmall mean [mc "mean"]
    dict set moodTextSmall moody [mc "moody"]
    dict set moodTextSmall nervous [mc "nervous"]
    dict set moodTextSmall neutral [mc "neutral"]
    dict set moodTextSmall offended [mc "offended"]
    dict set moodTextSmall playful [mc "playful"]
    dict set moodTextSmall proud [mc "proud"]
    dict set moodTextSmall relieved [mc "relieved"]
    dict set moodTextSmall remorseful [mc "remorseful"]
    dict set moodTextSmall restless [mc "restless"]
    dict set moodTextSmall sad [mc "sad"]
    dict set moodTextSmall sarcastic [mc "sarcastic"]
    dict set moodTextSmall serious [mc "serious"]
    dict set moodTextSmall shocked [mc "shocked"]
    dict set moodTextSmall shy [mc "shy"]
    dict set moodTextSmall sick [mc "sick"]
    dict set moodTextSmall sleepy [mc "sleepy"]
    dict set moodTextSmall stressed [mc "stressed"]
    dict set moodTextSmall surprised [mc "surprised"]
    dict set moodTextSmall thirsty [mc "thirsty"]
    dict set moodTextSmall worried [mc "worried"]
    
    if {$config(mood,showall)} {
	set moodL $allMoods
    } else {
	set moodL $myMoods
    }
    
    # Sort the localized list of moods.
    variable sortedLocMoods [list]
    set moodLocL [list]
    foreach mood $moodL {
	lappend moodLocL [list $mood [dict get $moodText $mood]]
    }
    set moodLocL [lsort -dictionary -index 1 $moodLocL]
    foreach spec $moodLocL {
	lappend sortedLocMoods [lindex $spec 0]
    }
    
    variable menuDef
    set menuDef [list cascade mMood {} {} {} {}]
    set subMenu [list]
    set opts [list -variable ::Mood::menuMoodVar -value "-"]
    lappend subMenu [list radio None ::Mood::MenuCmd {} $opts]
    lappend subMenu {separator}
    foreach mood $sortedLocMoods {
	set label [dict get $moodText $mood]
	set opts [list -variable ::Mood::menuMoodVar -value $mood]
	lappend subMenu [list radio $label ::Mood::MenuCmd {} $opts]
    }
    lappend subMenu {separator}
    lappend subMenu [list command mCustomMood... ::Mood::CustomMoodDlg {} {}]
    lset menuDef 5 $subMenu
    
    variable menuMoodVar
    set menuMoodVar "-"
    
}

# Mood::JabberInitHook --
# 
#       Here we announce that we have mood support and is interested in
#       getting notifications.

proc ::Mood::JabberInitHook {jlibname} {
    variable xmlns
    
    set E [list]
    lappend E [wrapper::createtag "identity"  \
      -attrlist [list category hierarchy type leaf name "User Mood"]]
    lappend E [wrapper::createtag "feature" \
      -attrlist [list var $xmlns(mood)]]    
    lappend E [wrapper::createtag "feature" \
      -attrlist [list var $xmlns(mood+notify)]]
    
    $jlibname caps register mood $E [list $xmlns(mood) $xmlns(mood+notify)]
}

# Setting own mood -------------------------------------------------------------
#
#       Disco server for PEP, disco own bare JID, create pubsub node.
#       
#       1) Disco server for pubsub/pep support
#       2) Publish mood

proc ::Mood::LoginHook {} {
    variable xmlns
   
    # Disco server for pubsub/pep support.
    set server [::Jabber::Jlib getserver]
    ::Jabber::Jlib pep have $server [namespace code HavePEP]
    ::Jabber::Jlib pubsub register_event [namespace code Event] \
      -node $xmlns(mood)
}

proc ::Mood::HavePEP {jlibname have} {
    variable menuDef
    variable xmlns

    if {$have} {

	# Get our own published mood and fill in.
	# NB: I thought that this should work automatically but seems not.
	set myjid2 [::Jabber::Jlib myjid2]
	::Jabber::Jlib pubsub items $myjid2 $xmlns(mood) \
	  -command [namespace code ItemsCB]
	::JUI::RegisterMenuEntry action $menuDef
	
	if {[MPExists]} {
	    [MPWin] state {!disabled}
	}
    }
}

proc ::Mood::LogoutHook {} {
    variable state
    
    ::JUI::DeRegisterMenuEntry action mMood
    unset -nocomplain state
    if {[MPExists]} {
	[MPWin] state {disabled}
    }
}

proc ::Mood::ItemsCB {type subiq args} {
    variable xmlns
    variable menuMoodVar
    variable moodMessageDlg
    
    if {$type eq "error"} {
	return
    }
    foreach itemsE [wrapper::getchildren $subiq] {
	set tag [wrapper::gettag $itemsE]
	set node [wrapper::getattribute $itemsE "node"]
	if {[string equal $tag "items"] && [string equal $node $xmlns(mood)]} {
	    set itemE [wrapper::getfirstchildwithtag $itemsE item]
	    set moodE [wrapper::getfirstchildwithtag $itemE mood]
	    if {![llength $moodE]} {
		return
	    }
	    set text ""
	    set mood ""
	    foreach E [wrapper::getchildren $moodE] {
		set tag [wrapper::gettag $E]
		switch -- $tag {
		    text {
			set moodMessageDlg [wrapper::getcdata $E]
		    }
		    default {
			set menuMoodVar $tag
			if {[MPExists]} {
			    MPSetMood $tag
			}
		    }
		}
	    }
	}
    }
}

proc ::Mood::MenuCmd {} {
    variable menuMoodVar
    
    if {$menuMoodVar eq "-"} {
	Retract
    } else {
	Publish $menuMoodVar
    }
    if {[MPExists]} {
	MPDisplayMood $menuMoodVar
    }
}

#--------------------------------------------------------------------

proc ::Mood::Publish {mood {text ""}} {
    variable moodNode
    variable xmlns
   
    # Create Mood stanza before publish 
    set moodChildEs [list [wrapper::createtag $mood]]
    if {$text ne ""} {
	lappend moodChildEs [wrapper::createtag text -chdata $text] 
    }
    set moodE [wrapper::createtag mood  \
      -attrlist [list xmlns $xmlns(mood)] -subtags $moodChildEs]

    # NB: It is currently unclear there should be an id attribute in the item
    #     element since PEP doesn't use it but pubsub do, and the experimental
    #     OpenFire PEP implementation.
    # set itemE [wrapper::createtag item -subtags [list $moodE]]
    set itemE [wrapper::createtag item \
      -attrlist [list id current] -subtags [list $moodE]]

    ::Jabber::Jlib pep publish $xmlns(mood) $itemE
}

proc ::Mood::Retract {} {
    variable xmlns
    
    ::Jabber::Jlib pep retract $xmlns(mood) -notify 1
}

#--------------------------------------------------------------
#----------------- UI for Custom Mood Dialog ------------------
#--------------------------------------------------------------

proc ::Mood::CustomMoodDlg {} {
    variable sortedLocMoods
    variable menuMoodVar
    variable moodMessageDlg
    variable moodStateDlg
    variable moodText
    
    set moodStateDlg $menuMoodVar
    set moodMessageDlg ""
    
    set w [ui::dialog -message [mc "Select your mood to show to your contacts."] -detail [mc "Only contacts with compatible software will see your mood."] \
      -buttons {ok cancel remove} -icon info \
      -modal 1 -geovariable ::prefs(winGeom,customMood) \
      -title [mc "Custom Mood"] -command [namespace code CustomCmd]]
    set fr [$w clientframe]

    set mDef [list]
    lappend mDef [list [mc "None"] -value "-"]
    lappend mDef [list separator]
    foreach mood $sortedLocMoods {
	set label [dict get $moodText $mood]
	lappend mDef [list [mc $label] -value $mood \
	  -image [::Theme::FindIconSize 16 mood-$mood]] 
    }
    set label "[string map {& ""} [mc mMood]]:"
    ttk::label $fr.lmood -text $label     
    ui::optionmenu $fr.cmood -menulist $mDef -direction flush \
      -variable [namespace current]::moodStateDlg

    ttk::label $fr.ltext -text [mc "Message"]:
    ttk::entry $fr.etext -textvariable [namespace current]::moodMessageDlg

    grid  $fr.lmood    $fr.cmood  -sticky e -pady 2
    grid  $fr.ltext    $fr.etext  -sticky e -pady 2
    grid $fr.cmood $fr.etext -sticky ew
    grid columnconfigure $fr 1 -weight 1

    bind $fr.cmood <Map> { focus %W }
    
    set mbar [::JUI::GetMainMenu]
    ui::dialog defaultmenu $mbar
    ::UI::MenubarDisableBut $mbar edit
    $w grab
    ::UI::MenubarEnableAll $mbar
}

proc ::Mood::CustomCmd {w bt} {
    variable moodStateDlg
    variable moodMessageDlg
    variable menuMoodVar
    
    if {$bt eq "ok"} {
	if {$moodStateDlg eq "-"} {
	    Retract
	} else {
	    Publish $moodStateDlg $moodMessageDlg
	}
	set menuMoodVar $moodStateDlg	
	if {[MPExists]} {
	    MPSetMood $moodStateDlg
	}
    } elseif {$bt eq "remove"} {
	Retract
	set menuMoodVar -	
	if {[MPExists]} {
	    MPSetMood -
	}
    }
}

# Mood::Event --
# 
#       Mood event handler for incoming mood messages.

proc ::Mood::Event {jlibname xmldata} {
    variable state
    variable xmlns
    variable moodTextSmall
        
    # The server MUST set the 'from' address on the notification to the 
    # bare JID (<node@domain.tld>) of the account owner.
    set from [wrapper::getattribute $xmldata from]
    set eventE [wrapper::getfirstchildwithtag $xmldata event]
    if {[llength $eventE]} {
	set itemsE [wrapper::getfirstchildwithtag $eventE items]
	if {[llength $itemsE]} {

	    set node [wrapper::getattribute $itemsE node]    
	    if {$node ne $xmlns(mood)} {
		return
	    }

	    set mjid [jlib::jidmap $from]
	    set text ""
	    set mood ""

	    set retractE [wrapper::getfirstchildwithtag $itemsE retract]
	    if {[llength $retractE]} {
		set msg ""
		set state($mjid,mood) ""
		set state($mjid,text) ""
	    } else {
		set itemE [wrapper::getfirstchildwithtag $itemsE item]
		set moodE [wrapper::getfirstchildwithtag $itemE mood]
		if {![llength $moodE]} {
		    return
		}
		foreach E [wrapper::getchildren $moodE] {
		    set tag [wrapper::gettag $E]
		    switch -- $tag {
			text {
			    set text [wrapper::getcdata $E]
			}
			default {
			    set mood $tag
			}
		    }
		}
	    
		# Cache the result.
		set state($mjid,mood) $mood
		set state($mjid,text) $text
	    
		if {$mood eq ""} {
		    set msg ""
		} else {
		    set mstr [string map {& ""} [mc mMood]]
		    set msg "$mstr: [dict get $moodTextSmall $mood] $text"
		}
	    }
	    ::RosterTree::BalloonRegister mood $from $msg
	    
	    ::hooks::run moodEvent $xmldata $mood $text
	}
    }
}

#--- Mega Presence Hook --------------------------------------------------------

namespace eval ::Mood {
    
    set label [string map {& ""} [mc mMood]]
    ::MegaPresence::Register mood $label [namespace code MPBuild]
    
    variable imsize 16
    variable mpwin "-"
    variable imblank
    set imblank [image create photo -height $imsize -width $imsize]
    $imblank blank
}

proc ::Mood::MPBuild {win} {
    variable imsize
    variable imblank
    variable mpwin
    variable mpMood
    variable sortedLocMoods
    variable moodText

    set mpwin $win
    ttk::menubutton $win -style SunkenMenubutton \
      -image $imblank -compound image

    set m $win.m
    menu $m -tearoff 0
    $win configure -menu $m
    $win state {disabled}
    
    $m add radiobutton -label [mc "None"] -value "-" \
      -variable [namespace current]::mpMood \
      -command [namespace code MPCmd]
    $m add separator
    foreach mood $sortedLocMoods {
	set label [dict get $moodText $mood]
	$m add radiobutton -label [mc $label] -value $mood \
	  -image [::Theme::FindIconSize $imsize mood-$mood] \
	  -variable [namespace current]::mpMood \
	  -command [namespace code MPCmd] -compound left
    }    
    $m add separator
    $m add command -label [string map {& ""} [mc mCustomMood...]] \
      -command [namespace code CustomMoodDlg]
    set mpMood "-"
    return
}

proc ::Mood::MPCmd {} {
    variable mpMood
    variable menuMoodVar
    
    if {$mpMood eq "-"} {
	Retract
    } else {
	Publish $mpMood ""
    }
    set menuMoodVar $mpMood
    MPDisplayMood $mpMood
}

proc ::Mood::MPDisplayMood {mood} {
    variable imsize
    variable mpwin
    variable imblank
    variable moodTextSmall
    
    set mstr [string map {& ""} [mc mMood]]
    if {$mood eq "-"} {
	$mpwin configure -image $imblank
	set msg "$mstr: "
	append msg [mc "None"]
	::balloonhelp::balloonforwindow $mpwin $msg
    } else {
	$mpwin configure -image [::Theme::FindIconSize $imsize mood-$mood]	
        ::balloonhelp::balloonforwindow $mpwin "$mstr: [dict get $moodTextSmall $mood]"
    }
}

proc ::Mood::MPSetMood {mood} {
    variable mpMood
    set mpMood $mood
    MPCmd
}

proc ::Mood::MPExists {} {
    variable mpwin
    return [winfo exists $mpwin]
}

proc ::Mood::MPWin {} {
    variable mpwin
    return $mpwin
}

# Test
if {0} {
    set xmlns(mood)        "http://jabber.org/protocol/mood"
    proc cb {args} {puts "---> $args"}
    set jlib ::jlib::jlib1
    set myjid2 [$jlib myjid2]
    $jlib pubsub items $myjid2 $xmlns(mood)
    $jlib disco send_get items $myjid2 cb
    $jlib pep retract $xmlns(mood)
    
    
    
    
}

#-------------------------------------------------------------------------------

