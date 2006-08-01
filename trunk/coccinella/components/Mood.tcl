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
    variable myjid
    variable moodjlib

    variable node
    set node "http://jabber.org/protocol/moodee"

    variable xmlnsMood
    set xmlnsMood "http://jabber.org/protocol/mood"

    variable state

    variable menuMood
    set menuMood [list  \
      command mMood [namespace current]::Cmd  normal {}]
}

proc ::Mood::LoginHook { } {
    variable server
    variable myjid
    variable moodjlib

#    lappend menuMood [list radio angry [namespace current]::Cmd normal {} {}]
#    lappend menuMood [list radio bored [namespace current]::Cmd normal {} {}]

    #----- Initialize variables ------
    set moodjlib jlib::jlib1
    set myjid [$moodjlib myjid2]
    set server [$moodjlib getserver]

    #----- Disco server for pubsub support -----
    ::Jabber::JlibCmd disco get_async items $server ::Mood::OnDiscoServer
}

proc ::Mood::OnDiscoServer {jlibname type from subiq args} {
    variable state
    variable myjid
    variable moodjlib
    variable node
    variable xmlnsMood
    variable menuMood
 
    ::Debug 2 "::Mood::OnDiscoServer"

    if {$type eq "result"} {
        set childs [::Jabber::JlibCmd disco children $from]
        foreach service $childs {
            set name [::Jabber::JlibCmd disco name $service]

            ::Debug 2 "\t service=$service, name=$name"
#           @@@ Has to look for identity=pep 
#           if {$name eq "pubsub"} {
            if { [string first "pubsub" $service] != -1 } {
                #------ Initialize User Interface -------
                ::Jabber::UI::RegisterMenuEntry jabber $menuMood

                #----- Create Node for Mood -------------
                ::Jabber::JlibCmd disco get_async items $myjid [list ::Mood::CreateNode]
                break
            }
#            }
        }
    }
}
proc ::Mood::Cmd {{moodState ""} {text ""}} {    
    variable server
    variable myjid
    variable moodjlib
    variable node
    variable xmlnsMood

    #@@@ This comes from UI
    set moodState "happy"
    set text "nobody"

    set moodValues [list afraid amazed angry annoyed anxious aroused ashamed bored brave calm cold confused contented cranky \
                         courious depressed disappointed disgusted distracted embarrassed excited flirtatious frustated grumpy \
                         guilty happy hot humbled humiliated hungry hurt impressed in_awe in_love indignant interested intoxicated \
                         invincible jealous lonely mean moody nervous neutral offended playful proud relieved remorseful restless \
                         sad sarcastic serious shocked shy sick sleepy stressed surprised thirsty worried]

    if {[lsearch $moodValues $moodState] >= 0} {
	set moodTextTag [wrapper::createtag text -chdata $text] 

        set moodStateTag [wrapper::createtag $moodState]
        set moodTag [wrapper::createtag mood -attrlist [list xmlns $xmlnsMood] -subtags [list  $moodStateTag $moodTextTag] ]

        set itemElem [wrapper::createtag item -subtags [list $moodTag]]

        $moodjlib pubsub publish $node  -items [list $itemElem] -command ::Mood::PubSubPublishCB
    }
}

proc ::Mood::PubSubPublishCB {args} {
     puts "(Publish Results)----> $args"
}

#--------------------------------------------------------------------
#-------             Checks and create if node exists ---------------
#-----------            before the publish tasks     ----------------
#--------------------------------------------------------------------
proc ::Mood::CreateNode {jlibname type from subiq args} {
variable server
variable myjid
variable moodjlib
variable node

    #------- Before create a node checks if it is created ---------
    set findMood false
    if {$type eq "result"} {
        set nodes [::Jabber::JlibCmd disco nodes $from]
        foreach nodeItem $nodes {
            if { [string first "moodee" $nodeItem] != -1 } {
                set findMood true
                break
            }
        }
    }

    #---------- Create the node for mood information -------------
    if { !$findMood } {
        #Configure setup for PEP node
        set valueFormElem  [wrapper::createtag value -chdata "http://jabber.org/protocol/pubsub#node_config"]
        set fieldFormElem [wrapper::createtag field -attrlist [list var "FORM_TYPE" type hidden] -subtags [list $valueFormElem]]

        #PEP Values for access_model: roster / presence / open or authorize / whitelist
        set valueAccessModel [wrapper::createtag value -chdata roster]
        set fieldAccessModelElem [wrapper::createtag field -attrlist [list var "pubsub#access_model"] -subtags [list $valueAccessModel]]

        set xElem [wrapper::createtag x -attrlist [list xmlns "jabber:x:data" type submit] -subtags [list $fieldFormElem $fieldAccessModelElem]]

        $moodjlib pubsub create -node $node -command ::Mood::PubSubCreateCB -configure $xElem
    }
}

proc ::Mood::PubSubCreateCB {type args} {

    if { $type ne 'result' } {
        puts "(CreateNode error)----> $args"
    }
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

    if { ![info exists state($from,pubsubsupport)] } {
        #------------- Check(disco#items) If the User supports PEP before subscribe
        ::Jabber::JlibCmd disco get_async items $jid2 [list ::Mood::OnDiscoContact]
    } 
}

proc ::Mood::OnDiscoContact {jlibname type from subiq args} {
    variable state
    variable moodjlib
    variable myjid
    variable node

    ::Debug 2 "::Mood::OnDiscoContactServer"

    # --- Check if contact supports Mood node ----
    if {$type eq "result"} {
        set nodes [::Jabber::JlibCmd disco nodes $from]
        foreach nodeItem $nodes {
            if { [string first "mood" $nodeItem] != -1 } {
                set state($from,pubsubsupport) true
           
                jlib::splitjidex $from nodeFrom jidserver res
                set jid2 $nodeFrom@$jidserver 
                $moodjlib pubsub subscribe $jid2 $myjid -node $node -command ::Mood::PubSubscribeCB
                break
            }
        }
    }
}

proc ::Mood::PubSubscribeCB {type args} {
        puts "@@@@@ (PubSub) ---> $args"
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

   #@@@ Add Mood info into user ballon
   #???
    puts "Node: $node"
    puts "Text: $text"
    puts "Mood: $mood"
}
