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
    set sortedLocMoods [list]
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
    # TRANSLATORS: Moods, more information at http://xmpp.org/extensions/xep-0107.html#moods
    # TRANSLATORS: Impressed with fear or apprehension; in fear; apprehensive.
    dict set moodText afraid [mc "Afraid"]
    # TRANSLATORS: Astonished; confounded with fear, surprise or wonder.
    dict set moodText amazed [mc "Amazed"]
    # TRANSLATORS: Displaying or feeling anger, i.e., a strong feeling of displeasure, hostility or antagonism towards someone or something, usually combined with an urge to harm.
    dict set moodText angry [mc "Angry"]
    # TRANSLATORS: To be disturbed or irritated, especially by continued or repeated acts.
    dict set moodText annoyed [mc "Annoyed"]
    # TRANSLATORS: Full of anxiety or disquietude; greatly concerned or solicitous, esp. respecting something future or unknown; being in painful suspense.
    dict set moodText anxious [mc "Anxious"]
    # TRANSLATORS: To be stimulated in one's feelings, especially to be sexually stimulated.
    dict set moodText aroused [mc "Aroused"]
    # TRANSLATORS: Feeling shame or guilt.
    dict set moodText ashamed [mc "Ashamed"]
    # TRANSLATORS: Suffering from boredom; uninterested, without attention.
    dict set moodText bored [mc "Bored"]
    # TRANSLATORS: Strong in the face of fear; courageous.
    dict set moodText brave [mc "Brave"]
    # TRANSLATORS: Peaceful, quiet.
    dict set moodText calm [mc "Calm"]
    # TRANSLATORS: Feeling the sensation of coldness, especially to the point of discomfort.
    dict set moodText cold [mc "Cold"]
    # TRANSLATORS: Chaotic, jumbled or muddled.
    dict set moodText confused [mc "Confused"]
    # TRANSLATORS: Pleased at the satisfaction of a want or desire; satisfied.
    dict set moodText contented [mc "Contented"]
    # TRANSLATORS: Grouchy, irritable; easily upset.
    dict set moodText cranky [mc "Cranky"]
    # TRANSLATORS: Inquisitive; tending to ask questions, investigate, or explore.
    dict set moodText curious [mc "Curious"]
    # TRANSLATORS: Severely despondent and unhappy.
    dict set moodText depressed [mc "Depressed"]
    # TRANSLATORS: Defeated of expectation or hope; let down.
    dict set moodText disappointed [mc "Disappointed"]
    # TRANSLATORS: Filled with disgust; irritated and out of patience.
    dict set moodText disgusted [mc "Disgusted"]
    # TRANSLATORS: Having one's attention diverted; preoccupied.
    dict set moodText distracted [mc "Distracted"]
    # TRANSLATORS: Having a feeling of shameful discomfort.
    dict set moodText embarrassed [mc "Embarrassed"]
    # TRANSLATORS: Having great enthusiasm.
    dict set moodText excited [mc "Excited"]
    # TRANSLATORS: In the mood for flirting.
    dict set moodText flirtatious [mc "Flirtatious"]
    # TRANSLATORS: Suffering from frustration; dissatisfied, agitated, or discontented because one is unable to perform an action or fulfill a desire.
    dict set moodText frustrated [mc "Frustrated"]
    # TRANSLATORS: Unhappy and irritable.
    dict set moodText grumpy [mc "Grumpy"]
    # TRANSLATORS: Feeling responsible for wrongdoing; feeling blameworthy.
    dict set moodText guilty [mc "Guilty"]
    # TRANSLATORS: Experiencing the effect of favourable fortune; having the feeling arising from the consciousness of well-being or of enjoyment; enjoying good of any kind, as peace, tranquillity, comfort; contented; joyous.
    dict set moodText happy [mc "Happy"]
    # TRANSLATORS: Feeling the sensation of heat, especially to the point of discomfort.
    dict set moodText hot [mc "Hot"]
    # TRANSLATORS: Having or showing a modest or low estimate of one's own importance; feeling lowered in dignity or importance.
    dict set moodText humbled [mc "Humbled"]
    # TRANSLATORS: Feeling deprived of dignity or self-respect.
    dict set moodText humiliated [mc "Humiliated"]
    # TRANSLATORS: Having a physical need for food.
    dict set moodText hungry [mc "Hungry"]
    # TRANSLATORS: Wounded, injured, or pained, whether physically or emotionally.
    dict set moodText hurt [mc "Hurt"]
    # TRANSLATORS: Favourably affected by something or someone.
    dict set moodText impressed [mc "Impressed"]
    # TRANSLATORS: Feeling amazement at something or someone; or feeling a combination of fear and reverence.
    dict set moodText in_awe [mc "In awe"]
    # TRANSLATORS: Feeling strong affection, care, liking, or attraction.
    dict set moodText in_love [mc "In love"]
    # TRANSLATORS: Showing anger or indignation, especially at something unjust or wrong.
    dict set moodText indignant [mc "Indignant"]
    # TRANSLATORS: Showing great attention to something or someone; having or showing interest.
    dict set moodText interested [mc "Interested"]
    # TRANSLATORS: Under the influence of alcohol; drunk.
    dict set moodText intoxicated [mc "Intoxicated"]
    # TRANSLATORS: Feeling as if one cannot be defeated, overcome or denied.
    dict set moodText invincible [mc "Invincible"]
    # TRANSLATORS: Fearful of being replaced in position or affection.
    dict set moodText jealous [mc "Jealous"]
    # TRANSLATORS: Feeling isolated, empty, or abandoned.
    dict set moodText lonely [mc "Lonely"]
    # TRANSLATORS: Causing or intending to cause intentional harm; bearing ill will towards another; cruel; malicious.
    dict set moodText mean [mc "Mean"]
    # TRANSLATORS: Given to sudden or frequent changes of mind or feeling; temperamental.
    dict set moodText moody [mc "Moody"]
    # TRANSLATORS: Easily agitated or alarmed; apprehensive or anxious.
    dict set moodText nervous [mc "Nervous"]
    # TRANSLATORS: Not having a strong mood or emotional state.
    dict set moodText neutral [mc "Neutral"]
    # TRANSLATORS: Feeling emotionally hurt, displeased, or insulted. 
    dict set moodText offended [mc "Offended"]
    # TRANSLATORS: Interested in play; fun, recreational, unserious, lighthearted; joking, silly.
    dict set moodText playful [mc "Playful"]
    # TRANSLATORS: Feeling a sense of one's own worth or accomplishment.
    dict set moodText proud [mc "Proud"]
    # TRANSLATORS: Feeling uplifted because of the removal of stress or discomfort.
    dict set moodText relieved [mc "Relieved"]
    # TRANSLATORS: Feeling regret or sadness for doing something wrong.
    dict set moodText remorseful [mc "Remorseful"]
    # TRANSLATORS: Without rest; unable to be still or quiet; uneasy; continually moving.
    dict set moodText restless [mc "Restless"]
    # TRANSLATORS: Feeling sorrow; sorrowful, mournful.
    dict set moodText sad [mc "Sad"]
    # TRANSLATORS: Mocking and ironical.
    dict set moodText sarcastic [mc "Sarcastic"]
    # TRANSLATORS: Without humor or expression of happiness; grave in manner or disposition; earnest; thoughtful; solemn.
    dict set moodText serious [mc "Serious"]
    # TRANSLATORS: Surprised, startled, confused, or taken aback.
    dict set moodText shocked [mc "Shocked"]
    # TRANSLATORS: Feeling easily frightened or scared; timid; reserved or coy.
    dict set moodText shy [mc "Shy"]
    # TRANSLATORS: Feeling in poor health; ill.
    dict set moodText sick [mc "Sick"]
    # TRANSLATORS: Feeling the need for sleep.
    dict set moodText sleepy [mc "Sleepy"]
    # TRANSLATORS: Suffering emotional pressure.
    dict set moodText stressed [mc "Stressed"]
    # TRANSLATORS: Experiencing a feeling caused by something unexpected.
    dict set moodText surprised [mc "Surprised"]
    # TRANSLATORS: Feeling the need to drink.
    dict set moodText thirsty [mc "Thirsty"]
    # TRANSLATORS: Thinking about unpleasant things that have happened or that might happen; feeling afraid and unhappy.
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
    # bug: this should be M&ood but this does not work!
    set menuDef [list cascade mMood {[mc "Mood"]...} {} {} {} {}]
    set subMenu [list]
    set opts [list -variable ::Mood::menuMoodVar -value "-"]
    lappend subMenu [list radio None {[mc "None"]} ::Mood::MenuCmd {} $opts]
    lappend subMenu {separator}
    foreach mood $sortedLocMoods {
	set label [dict get $moodText $mood]
	set opts [list -variable ::Mood::menuMoodVar -value $mood]
	lappend subMenu [list radio $mood $label ::Mood::MenuCmd {} $opts]
    }
    lappend subMenu {separator}
    lappend subMenu [list command mCustomMood... {[mc "&Custom Mood"]...} ::Mood::CustomMoodDlg {} {}]
    lset menuDef 6 $subMenu
    
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
    set label "[string map {& ""} [mc Mood]]:"
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
		    set mstr [string map {& ""} [mc "Mood"]]
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
    
    set label [string map {& ""} [mc "Mood"]]
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
    $m add command -label [string map {& ""} [mc "&Custom Mood"]...] \
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
    
    set mstr [string map {& ""} [mc "Mood"]]
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

