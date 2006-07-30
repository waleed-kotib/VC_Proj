# Mood.tcl --
# 
#       User Mood using PubSub library code.

namespace eval ::Mood:: { }

proc ::Mood::Init { } {

    component::register Mood \
      "This is User Mood (JEP-0107)."

    ::Debug 2 "::Mood::Init"

    # Add event hooks.
    ::hooks::register newMessageHook        ::Mood::MessageHook
    ::hooks::register presenceHook          ::Mood::PresenceHook
    ::hooks::register loginHook             ::Mood::LoginHook

    variable server
    variable psjid
    variable myjid
    variable moodjlib

    variable nodeUser
    variable nodeMood

    variable xmlnsMood
    set xmlnsMood "http://jabber.org/protocol/mood"

    variable state
}

proc ::Mood::LoginHook { } {
    variable server
    variable psjid
    variable myjid
    variable moodjlib
    variable nodeUser
    variable nodeMood
 
    variable xmlnsMood

    set menuMood [list  \
      command mMood [namespace current]::Cmd  normal {}]

#    lappend menuMood [list radio angry [namespace current]::Cmd normal {} {}]
#    lappend menuMood [list radio bored [namespace current]::Cmd normal {} {}]

    ::Jabber::UI::RegisterMenuEntry jabber $menuMood

    #----- Initialize variables ------
    set moodjlib jlib::jlib1
    set myjid [$moodjlib myjid2]
    set server [$moodjlib getserver]
    set psjid pubsub.$server

    set nodeUser /home/$server/antoniofcano
    set nodeMood $nodeUser/mood

    #Disco server for pubsub support
    ::Jabber::JlibCmd disco get_async items $server ::Mood::OnDiscoServer
}

proc ::Mood::OnDiscoServer {jlibname type from subiq args} {
    variable state
    variable psjid
    variable myjid
    variable moodjlib
    variable nodeUser
    variable nodeMood
    variable xmlnsMood
 
    ::Debug 2 "::Mood::OnDiscoServer"
        
    if {$type eq "result"} {
        set childs [::Jabber::JlibCmd disco children $from]
        foreach service $childs {
            set name [::Jabber::JlibCmd disco name $service]

            ::Debug 2 "\t service=$service, name=$name"
#           @@@ $name equal null ??
#           if {$name eq "pubsub"} {
            if { [string first "pubsub" $service] != -1 } {
                # Caps specific Mood stuff.
                set subtags [list [wrapper::createtag "identity"  \
                  -attrlist [list category hierarchy type leaf name "User Mood"]]]
                lappend subtags [wrapper::createtag "feature" \
                  -attrlist [list var $xmlnsMood]]
                ::Jabber::RegisterCapsExtKey mood $subtags

                #---- Checks if node User exists in server ----
                $moodjlib pubsub items $psjid $nodeUser -command ::Mood::PubSubItemUserCB

                #---- Register to PubSub service
                #$moodjlib pubsub subscribe $psjid $myjid -node $nodeMood -command ::Mood::PubSubCB
                #$moodjlib pubsub register_event ::Mood::PubSubCBEvent -from $psjid -node $nodeMood

                break
            }
#            }
        }
    }
}
proc ::Mood::Cmd {{mood ""} {text ""}} {    
    variable server
    variable psjid
    variable myjid
    variable moodjlib
    variable nodeMood
    variable xmlnsMood

    #@@@ This comes from UI
    set mood "happy"
    set text "nobody"

    set moodValues [list afraid amazed angry annoyed anxious aroused ashamed bored brave calm cold confused contented cranky \
                         courious depressed disappointed disgusted distracted embarrassed excited flirtatious frustated grumpy \
                         guilty happy hot humbled humiliated hungry hurt impressed in_awe in_love indignant interested intoxicated \
                         invincible jealous lonely mean moody nervous neutral offended playful proud relieved remorseful restless \
                         sad sarcastic serious shocked shy sick sleepy stressed surprised thirsty worried]

    if {[lsearch $moodValues $mood] >= 0} {
	set moodTextTag [wrapper::createtag text -chdata $text] 

        set moodStateTag [wrapper::createtag $mood]
        set moodTag [wrapper::createtag mood -attrlist [list xmlns $xmlnsMood] -subtags [list  $moodStateTag $moodTextTag] ]

        set itemElem [wrapper::createtag item -attrlist [list id current] -subtags [list $moodTag]]

        $moodjlib pubsub publish $psjid $nodeMood  -items [list $itemElem]
    }
}

proc ::Mood::PubSubCB {type args} { 
	puts "@@@@@ (PubSub) ---> $args"
}

proc ::Mood::PubSubCBEvent {args} {
     puts "@@@@@ (Event) ----> $args"
}

#--------------------------------------------------------------------
#-------             Checks and create if node exists ---------------
#-----------            before the publish tasks     ----------------
#--------------------------------------------------------------------
proc ::Mood::PubSubItemUserCB {type args} {
variable server
variable psjid
variable myjid
variable moodjlib
variable nodeUser
variable nodeMood

    ### Not Supported by Ejabberd -> $moodjlib pubsub delete $psjid $nodeMood 

    #@@@@ control that error is item-not-found
    if {$type eq "error"} {
	#Create User Node
        $moodjlib pubsub create $psjid -node $nodeUser -command ::Mood::PubSubCreateCB
    }

    #Check for Mood node
    $moodjlib pubsub items $psjid $nodeMood -command ::Mood::PubSubItemMoodCB
}

proc ::Mood::PubSubItemMoodCB {type args} {
variable server
variable psjid
variable myjid
variable moodjlib
variable nodeMood

        #Configure setup for open access
        set valueAccessModel [wrapper::createtag value -chdata open]
        #@@@ In Jep Version 1.8 the field name is: access_model
        set fieldAccessModelElem [wrapper::createtag field -attrlist [list var "pubsub#subscription_model"] -subtags [list $valueAccessModel]]
        set xElem [wrapper::createtag x -attrlist [list xmlns "jabber:x:data" type submit] -subtags [list $fieldAccessModelElem]]

        $moodjlib pubsub configure set $psjid $nodeMood -x $xElem -command ::Mood::PubSubOptions
#        $moodjlib pubsub configure get $psjid $nodeMood -command ::Mood::PubSubOptions

    if {$type eq "error"} {
        $moodjlib pubsub create $psjid -node $nodeMood -command ::Mood::PubSubCreateCB -configure $xElem
    }
}

proc ::Mood::PubSubOptions {args} {
    puts "(Configure)----> $args"
}
proc ::Mood::PubSubCreateCB {type args} {
        puts "---> $args"
}


#-------------------------------------------------------------------------
#---------------------- (Extended Presence) ------------------------------
#-------------------------------------------------------------------------

proc ::Mood::PresenceHook {jid type args} {
    variable state
    variable moodjlib

    # Beware! jid without resource!
    ::Debug 2 "::Mood::PresenceHook jid=$jid, type=$type"

    if {$type ne "available"} {
        return
    }

    if {![::Jabber::RosterCmd isitem $jid]} {
        return
    }

    # Some transports propagate the complete prsence stanza.
    if {[::Roster::IsTransportHeuristics $jid]} {
        return
    }

    array set aargs $args
    set from $aargs(-from)
    jlib::splitjidex $from node jidserver res
    set jid2 $node@$jidserver

    if { ![info exists state($jidserver,pubsubsupport)] } {
        ::Jabber::JlibCmd disco get_async items $jidserver [list ::Mood::OnDiscoContactServer $node]
    } else {
        if { $state($jidserver,pubsubsupport) eq true } {
            set nodeMood /home/$jidserver/$node/mood
            $moodjlib pubsub subscribe $state($jidserver,pubsubservice) $jid2 -node $nodeMood -command ::Mood::PubSubCB
        }
    }    
}

#-------------------------------------------------------------------------
#----------------------------- (Disco) -----------------------------------
#-------------------------------------------------------------------------
proc ::Mood::OnDiscoContactServer {node jlibname type from subiq args} {
    variable state
    variable moodjlib

    ::Debug 2 "::Mood::OnDiscoContactServer"

    if {$type eq "result"} {
        set childs [::Jabber::JlibCmd disco children $from]
        foreach service $childs {
            set name [::Jabber::JlibCmd disco name $service]

            ::Debug 2 "\t service=$service, name=$name"
#           @@@ $name equal null ??
#           if {$name eq "pubsub"} {
            if { [string first "pubsub" $service] != -1 } {
                set state($from,pubsubsupport) true
                set state($from,pubsubservice) $service
            
                set jid2 $node@$from
                set nodeMood /home/$from/$node/mood
                $moodjlib pubsub subscribe $service $jid2 -node $nodeMood -command ::Mood::PubSubCB
                break
            }
#           }
        }
    }
}

#-------------------------------------------------------------------------
#---------------------- (Incoming Mood Handling) -------------------------
#-------------------------------------------------------------------------
proc ::Mood::MessageHook {body args} {
    array set aargs $args
    set event $aargs(-xmldata)

    set eventElem [wrapper::getfirstchildwithtag $event event]

    set itemsElem [wrapper::getfirstchildwithtag $eventElem items]
    set node [wrapper::getattribute $itemsElem node]

    set itemElem [wrapper::getfirstchildwithtag $itemsElem item]
    set moodElem [wrapper::getfirstchildwithtag $itemElem mood]

    set moodElemTemp [wrapper::getchildren $moodElem] 
    set elem1 [lindex $moodElemTemp 0]
    set elem2 [lindex $moodElemTemp 1]

    if { [wrapper::gettag $elem1] eq "text" } {
        set textElem $elem1
        set mood [wrapper::gettag $elem2]
    } else {
        set textElem $elem2
        set mood [wrapper::gettag $elem1]
    }
 
    set text ""
    if {$textElem ne {}} {
        set text [wrapper::getcdata $textElem]
    }

    puts "Node: $node"
    puts "Text: $text"
    puts "Mood: $mood"

   #@@@ Add Mood info into user ballon
   #???
}
