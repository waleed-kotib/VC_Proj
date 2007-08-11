# Mood.tcl --
# 
#       User Mood using PEP recommendations over PubSub library code.
#
#  Copyright (c) 2007 Mats Bengtsson
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
#  $Id: Mood.tcl,v 1.30 2007-08-11 06:44:34 matben Exp $

package require jlib::pep
package require ui::optionmenu

namespace eval ::Mood:: { }

proc ::Mood::Init { } {

    component::register Mood "This is User Mood (XEP-0107)."

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
    set subMenu {}
    set opts [list -variable ::Mood::menuMoodVar -value "-"]
    lappend subMenu [list radio None ::Mood::MenuCmd {} $opts]
    lappend subMenu {separator}
    foreach mood $myMoods {
	set opts [list -variable ::Mood::menuMoodVar -value $mood]
	lappend subMenu [list radio $mood2mLabel($mood) ::Mood::MenuCmd {} $opts]
    }
    lappend subMenu {separator}
    lappend subMenu [list command mCustomMood ::Mood::CustomMoodDlg {} {}]
    lset menuDef 5 $subMenu
    
    variable menuMoodVar
    set menuMoodVar "-"
    
    variable mapMoodTextToElem
    array set mapMoodTextToElem [list \
      [mc mAngry]       angry      \
      [mc mAnxious]     anxious    \
      [mc mAshamed]     ashamed    \
      [mc mBored]       bored      \
      [mc mCurious]     curious    \
      [mc mDepressed]   depressed  \
      [mc mExcited]     excited    \
      [mc mHappy]       happy      \
      [mc mInLove]      in_love    \
      [mc mInvincible]  invincible \
      [mc mJealous]     jealous    \
      [mc mNervous]     nervous    \
      [mc mSad]         sad        \
      [mc mSleepy]      sleepy     \
      [mc mStressed]    stressed   \
      [mc mWorried]     worried]
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
    set server [::Jabber::JlibCmd getserver]
    ::Jabber::JlibCmd pep have $server [namespace code HavePEP]
    ::Jabber::JlibCmd pubsub register_event [namespace code Event] \
      -node $xmlns(mood)
}

proc ::Mood::HavePEP {jlibname have} {
    variable menuDef
    variable xmlns

    if {$have} {

	# Get our own published mood and fill in.
	set myjid2 [::Jabber::JlibCmd  myjid2]
	::Jabber::JlibCmd pubsub items $myjid2 $xmlns(mood) \
	  -command [namespace code ItemsCB]
	::JUI::RegisterMenuEntry action $menuDef
    }
}

proc ::Mood::LogoutHook {} {
    variable state
    
    ::JUI::DeRegisterMenuEntry jabber mMood
    unset -nocomplain state
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

    #   NB:  It is currently unclear there should be an id attribute in the item
    #        element since PEP doesn't use it but pubsub do, and the experimental
    #        OpenFire PEP implementation.
    #set itemE [wrapper::createtag item -subtags [list $moodE]]
    set itemE [wrapper::createtag item \
      -attrlist [list id current] -subtags [list $moodE]]

    ::Jabber::JlibCmd pep publish $xmlns(mood) $itemE
}

proc ::Mood::Retract {} {
    variable xmlns
    
    ::Jabber::JlibCmd pep retract $xmlns(mood) -notify 1
}

#--------------------------------------------------------------
#----------------- UI for Custom Mood Dialog ------------------
#--------------------------------------------------------------

proc ::Mood::CustomMoodDlg {} {
    variable myMoods
    variable mood2mLabel
    variable menuMoodVar
    variable moodMessageDlg
    variable moodStateDlg
    
    set moodStateDlg $menuMoodVar
    set moodMessageDlg ""
    
    set str "Pick your mood that will be shown to other users."
    set dtl "Only users with clients that understand this protocol will be able to display your mood."
    set w [ui::dialog -message $str -detail $dtl -icon info \
      -type okcancel -modal 1 -geovariable ::prefs(winGeom,customMood) \
      -title [mc selectCustomMood] -command [namespace code CustomCmd]]
    set fr [$w clientframe]

    set mDef [list]
    lappend mDef [list [mc None] -value "-"]
    lappend mDef [list separator]
    foreach mood $myMoods {
	lappend mDef [list [mc $mood2mLabel($mood)] -value $mood] 
    }
    ttk::label $fr.lmood -text "[mc {mMood}]:"     
    ui::optionmenu $fr.cmood -menulist $mDef -direction flush \
      -variable [namespace current]::moodStateDlg

    ttk::label $fr.ltext -text "[mc {moodMessage}]:"
    ttk::entry $fr.etext -textvariable [namespace current]::moodMessageDlg

    grid  $fr.lmood    $fr.cmood  -sticky e -pady 2
    grid  $fr.ltext    $fr.etext  -sticky e -pady 2
    grid $fr.cmood $fr.etext -sticky ew
    grid columnconfigure $fr 1 -weight 1

    set mbar [::UI::GetMainMenu]
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

