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
#  $Id: Mood.tcl,v 1.44 2008-08-16 15:24:30 matben Exp $

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
    
    variable mood2mLabel
    array set mood2mLabel {
	angry       mAngry
	anxious     mAnxious
	ashamed     mAshamed
	bored       mBored
	curious     mCurious
	depressed   mDepressed
	excited     mExcited
	happy       mHappy
	in_love     mInLove
	invincible  mInvincible
	jealous     mJealous
	nervous     mNervous
	sad         mSad
	sleepy      mSleepy
	stressed    mStressed
	worried     mWorried
    }
  
    variable menuDef
    set menuDef [list cascade mMood {} {} {} {}]
    set subMenu [list]
    set opts [list -variable ::Mood::menuMoodVar -value "-"]
    lappend subMenu [list radio None ::Mood::MenuCmd {} $opts]
    lappend subMenu {separator}
    if {$config(mood,showall)} {
	set moodL $allMoods
    } else {
	set moodL $myMoods
    }
    foreach mood $moodL {
	set label "m[string totitle $mood]"
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
	MPSetMood $menuMoodVar
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
    global  config
    variable myMoods
    variable allMoods
    variable mood2mLabel
    variable menuMoodVar
    variable moodMessageDlg
    variable moodStateDlg
    
    set moodStateDlg $menuMoodVar
    set moodMessageDlg ""
    
    set w [ui::dialog -message [mc moodPickMsg] -detail [mc moodPickDtl] \
      -icon info \
      -type okcancel -modal 1 -geovariable ::prefs(winGeom,customMood) \
      -title [mc "Custom Mood"] -command [namespace code CustomCmd]]
    set fr [$w clientframe]

    set mDef [list]
    lappend mDef [list [mc None] -value "-"]
    lappend mDef [list separator]
    if {$config(mood,showall)} {
	set moodL $allMoods
    } else {
	set moodL $myMoods
    }
    foreach mood $moodL {
	set label "m[string totitle $mood]"
	lappend mDef [list [mc $label] -value $mood \
	  -image [::Theme::FindIconSize 16 mood-$mood]] 
    }
    ttk::label $fr.lmood -text "[mc mMood]:"     
    ui::optionmenu $fr.cmood -menulist $mDef -direction flush \
      -variable [namespace current]::moodStateDlg

    ttk::label $fr.ltext -text "[mc Message]:"
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
    }
}

# Mood::Event --
# 
#       Mood event handler for incoming mood messages.

proc ::Mood::Event {jlibname xmldata} {
    variable state
    variable xmlns
        
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
		    set msg "[mc mMood]: [mc $mood] $text"
		}
	    }
	    ::RosterTree::BalloonRegister mood $from $msg
	    
	    ::hooks::run moodEvent $xmldata $mood $text
	}
    }
}

#--- Mega Presence Hook --------------------------------------------------------

namespace eval ::Mood {
    
    ::MegaPresence::Register mood [mc Mood] [namespace code MPBuild]
    
    variable mpwin "-"
    variable imblank
    set imblank [image create photo -height 16 -width 16]
    $imblank blank
}

proc ::Mood::MPBuild {win} {
    global  config
    variable imblank
    variable mpwin
    variable myMoods
    variable allMoods
    variable mood2mLabel
    variable mpMood

    set mpwin $win
    ttk::menubutton $win -style SunkenMenubutton \
      -image $imblank -compound image

    set m $win.m
    menu $m -tearoff 0
    $win configure -menu $m
    $win state {disabled}
    
    $m add radiobutton -label [mc None] -value "-" \
      -variable [namespace current]::mpMood \
      -command [namespace code MPCmd]
    $m add separator
    if {$config(mood,showall)} {
	set moodL $allMoods
    } else {
	set moodL $myMoods
    }      
    foreach mood $moodL {
	set label "m[string totitle $mood]"
	$m add radiobutton -label [mc $label] -value $mood \
	  -image [::Theme::FindIconSize 16 mood-$mood] \
	  -variable [namespace current]::mpMood \
	  -command [namespace code MPCmd] -compound left
    }    
    $m add separator
    $m add command -label [mc Dialog]... \
      -command [namespace code CustomMoodDlg]
    set mpMood "-"
    return
}

proc ::Mood::MPCmd {} {
    variable mpwin
    variable mpMood
    variable imblank
    variable mood2mLabel
    variable menuMoodVar
    
    if {$mpMood eq "-"} {
	$mpwin configure -image $imblank
	::balloonhelp::balloonforwindow $mpwin "[mc Mood]: [mc None]"
	Retract
    } else {
	$mpwin configure -image [::Theme::FindIconSize 16 mood-$mpMood]	
        ::balloonhelp::balloonforwindow $mpwin "[mc Mood]: [mc $mood2mLabel($mpMood)]"
	Publish $mpMood ""
    }
    set menuMoodVar $mpMood
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

