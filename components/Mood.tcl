# Mood.tcl --
# 
#       User Mood using PEP recommendations over PubSub library code.
#       The current code reflects the PEP XEP prior to the simplification
#       of version 0.15. NEW PEP means version 0.15+
#
#  Copyright (c) 2006 Mats Bengtsson
#  Copyright (c) 2006 Antonio Cano Damas
#  
#  @@@ TODO: There seems to be a problem resetting mood to none (retract?)
#  
#  $Id: Mood.tcl,v 1.16 2006-12-01 08:55:13 matben Exp $

package require jlib::pep
package require ui::optionmenu

namespace eval ::Mood:: { }

proc ::Mood::Init { } {

    component::register Mood "This is User Mood (XEP-0107)."

    ::Debug 2 "::Mood::Init"

    # Add event hooks.
    ::hooks::register loginHook             ::Mood::LoginHook
    ::hooks::register logoutHook            ::Mood::LogoutHook

    variable moodNode
    set moodNode "http://jabber.org/protocol/mood"

    variable xmlns
    set xmlns(mood)        "http://jabber.org/protocol/mood"
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
    ::Jabber::JlibCmd pep have $server ::Mood::HavePEP
    ::Jabber::JlibCmd pubsub register_event ::Mood::Event -node $xmlns(mood)
}

proc ::Mood::HavePEP {jlibname have} {
    variable xmlns
    variable menuDef

    if {$have} {
	::JUI::RegisterMenuEntry jabber $menuDef
	::Jabber::JlibCmd pep set_auto_subscribe $xmlns(mood)
    }
}

proc ::Mood::LogoutHook {} {
    variable xmlns
    variable state
    
    ::JUI::DeRegisterMenuEntry jabber mMood

    ::Jabber::JlibCmd pubsub deregister_event ::Mood::Event -node $xmlns(mood)
    ::Jabber::JlibCmd pep unset_auto_subscribe $xmlns(mood)

    unset -nocomplain state
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
    set itemE [wrapper::createtag item -subtags [list $moodE]]

    ::Jabber::JlibCmd pep publish mood $itemE
    
}

proc ::Mood::Retract {} {
    ::Jabber::JlibCmd pep retract mood
}

#--------------------------------------------------------------
#----------------- UI for Custom Mood Dialog ------------------
#--------------------------------------------------------------

proc ::Mood::CustomMoodDlg {} {
    global  this wDlgs
    variable moodMessageDlg
    variable moodState
    variable menuMoodVar
    variable myMoods
    variable mood2mLabel
    variable moodStateDlg

    set w ".mumdlg"
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w \
      -macstyle documentProc -macclass {document closeBox} -usemacmainmenu 1 \
      -closecommand [namespace current]::CloseCmd
    wm title $w [mc {moodDlg}]

    ::UI::SetWindowPosition $w ".mumdlg"
    
    set moodStateDlg $menuMoodVar
    set moodMessageDlg ""

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg  \
      -padding {0 0 0 6} -wraplength 260 -justify left -text [mc selectCustomMood]
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.lmood -text "[mc {mMood}]:" 
    
    set mDef {}
    lappend mDef [list [mc None] -value "-"]
    foreach mood $myMoods {
	lappend mDef [list [mc $mood2mLabel($mood)] -value $mood] 
    }
    ui::optionmenu $frmid.cmood -menulist $mDef -direction flush \
      -variable [namespace current]::moodStateDlg

    ttk::label $frmid.ltext -text "[mc {moodMessage}]:"
    ttk::entry $frmid.etext -textvariable [namespace current]::moodMessageDlg

    grid  $frmid.lmood    $frmid.cmood  -sticky e -pady 2
    grid  $frmid.ltext    $frmid.etext  -sticky e -pady 2
    grid $frmid.cmood $frmid.etext -sticky ew
    grid columnconfigure $frmid 1 -weight 1

    # Button part.
    set frbot $wbox.b
    set wenter  $frbot.btok
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $wenter -text [mc OK] \
      -default active -command [list [namespace current]::sendMoodEnter $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelEnter $w]


    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x

    wm resizable $w 0 0

    bind $w <Return> [list $wenter invoke]

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wbox.msg $w]
    after idle $script
}

proc ::Mood::sendMoodEnter {w} {
    variable moodStateDlg
    variable moodMessageDlg
    variable mapMoodTextToElem
    variable menuMoodVar

    if {$moodStateDlg eq "-"} {
        Retract
    } else {
        Publish $moodStateDlg $moodMessageDlg
    }
    set menuMoodVar $moodStateDlg

    ::UI::SaveWinGeom $w
    destroy $w
}

proc ::Mood::CancelEnter {w} {

    ::UI::SaveWinGeom $w
    destroy $w
}

proc ::Mood::CloseCmd {w} {
    ::UI::SaveWinGeom $w
}

#------------------------------------------------------------------

# Mood::Event --
# 
#       Mood event handler for incoming mood messages.

proc ::Mood::Event {jlibname xmldata} {
    variable state
    
    # The server MUST set the 'from' address on the notification to the 
    # bare JID (<node@domain.tld>) of the account owner.
    set from [wrapper::getattribute $xmldata from]
    set eventE [wrapper::getfirstchildwithtag $xmldata event]
    if {[llength $eventE]} {
	set itemsE [wrapper::getfirstchildwithtag $eventE items]
	if {[llength $itemsE]} {
	    set node [wrapper::getattribute $itemsE node]    
	    set itemE [wrapper::getfirstchildwithtag $itemsE item]
	    set moodE [wrapper::getfirstchildwithtag $itemE mood]
	
	    set text ""
	    set mood ""
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
	    set mjid [jlib::jidmap $from]
	    
	    # Cache the result.
	    set state($mjid,mood) $mood
	    set state($mjid,text) $text
	    
	    if {$mood eq ""} {
		set msg ""
	    } else {
		set msg "[mc mMood]: [mc $mood] $text"
	    }
	    ::RosterTree::BalloonRegister mood $from $msg
	    
	    ::hooks::run moodEvent $xmldata $mood $text
	}
    }
}


