#  Jabber.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the "glue" between the whiteboard and jabberlib.
#      
#  Copyright (c) 2001-2004  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: Jabber.tcl,v 1.111 2004-10-12 13:48:56 matben Exp $

package require balloonhelp
package require browse
package require chasearrows
package require combobox
package require disco
package require http 2.3
package require jlib
package require roster
package require sha1pure
package require tinyfileutils
package require tree
package require uriencode
package require wavelabel

# We should have some component mechanism that lets packages load themselves.
package require Agents
package require Browse
package require Chat
package require Conference
package require Disco
package require Emoticons
package require GotMsg
package require GroupChat
package require JForms
package require JPrefs
package require JUI
package require JUser
package require JWB
package require Login
package require MailBox
package require MUC
package require NewMsg
package require OOB
package require Privacy
package require Profiles
package require Register
package require Roster
package require Search
package require Subscribe
package require VCard

package provide Jabber 1.0

namespace eval ::Jabber:: {
    global  this prefs
    
    # Add all event hooks.
    ::hooks::register quitAppHook        ::Jabber::EndSession

    # Jabber internal storage.
    variable jstate
    variable jprefs
    variable jserver
    variable jerror
    
    # Our own jid, and jid/resource respectively.
    set jstate(mejid) ""
    set jstate(mejidres) ""
    set jstate(meres) ""
    
    #set jstate(alljid) {}   not implemented yet...
    set jstate(sock) {}
    set jstate(ipNum) {}
    set jstate(inroster) 0
    set jstate(status) "unavailable"
    
    # Server port actually used.
    set jstate(servPort) {}
    
    set jstate(haveJabberUI) 0

    # Login server.
    set jserver(this) ""
    
    # Popup menus.
    set jstate(wpopup,disco)     .jpopupdi
    set jstate(wpopup,roster)    .jpopupro
    set jstate(wpopup,browse)    .jpopupbr
    set jstate(wpopup,groupchat) .jpopupgc
    set jstate(wpopup,agents)    .jpopupag
    
    # Keep noncritical error text here.
    set jerror {}
    
    # Array that acts as a data base for the public storage on the server.
    # Typically: jidPublic(matben@athlon.se,home,serverport).
    # Not used for the moment.
    variable jidPublic
    set jidPublic(haveit) 0
    
    # Mappings from <show> element to displayable text and vice versa.
    # chat away xa dnd
    variable mapShowElemToText
    variable mapShowTextToElem
    
    array set mapShowElemToText [list \
      [mc mAvailable]       available  \
      [mc mAway]            away       \
      [mc mChat]            chat       \
      [mc mDoNotDisturb]    dnd        \
      [mc mExtendedAway]    xa         \
      [mc mInvisible]       invisible  \
      [mc mNotAvailable]    unavailable]
    array set mapShowTextToElem [list \
      available       [mc mAvailable]     \
      away            [mc mAway]          \
      chat            [mc mChat]          \
      dnd             [mc mDoNotDisturb]  \
      xa              [mc mExtendedAway]  \
      invisible       [mc mInvisible]     \
      unavailable     [mc mNotAvailable]]
        
    # Array that maps namespace (ns) to a descriptive name.
    variable nsToText
    array set nsToText {
	iq                           {Info/query}
	message                      {Message handling}
	presence                     {Presence notification}
	presence-invisible           {Allows invisible users}
	jabber:client                {Client entity}
	jabber:iq:agent              {Server component properties}
	jabber:iq:agents             {Server component properties}
	jabber:iq:auth               {Client authentization}      
	jabber:iq:autoupdate         {Release information}
	jabber:iq:browse             {Browsing services}
	jabber:iq:conference         {Conferencing service}
	jabber:iq:gateway            {Gateway}
	jabber:iq:last               {Last time}
	jabber:iq:oob                {Out of band data}
	jabber:iq:privacy            {Blocking communication}
	jabber:iq:private            {Store private data}
	jabber:iq:register           {Interactive registration}
	jabber:iq:roster             {Roster management}
	jabber:iq:search             {Searching user database}
	jabber:iq:time               {Client time}
	jabber:iq:version            {Client version}
	jabber:x:autoupdate          {Client update notification}
	jabber:x:conference          {Conference invitation}
	jabber:x:delay               {Object delayed}
	jabber:x:encrypted           {Encrypted message}
	jabber:x:envelope            {Message envelope}
	jabber:x:event               {Message events}
	jabber:x:expire              {Message expiration}
	jabber:x:oob                 {Out of band attachment}
	jabber:x:roster              {Roster item in message}
	jabber:x:signed              {Signed presence}
	vcard-temp                   {Business card exchange}
	http://jabber.org/protocol/muc   {Multi user chat}
	http://jabber.org/protocol/disco {Feature discovery}
	http://jabber.org/protocol/caps  {Entity capabilities}
    }    
    
    # XML namespaces defined here.
    variable coccixmlns
    array set coccixmlns {
	coccinella      http://coccinella.sourceforge.net/protocol/coccinella
	servers         http://coccinella.sourceforge.net/protocol/servers
	whiteboard      http://coccinella.sourceforge.net/protocol/whiteboard
	public          http://coccinella.sourceforge.net/protocol/private
	caps            http://coccinella.sourceforge.net/protocol/caps
    }
    
    # Standard xmlns supported. Components add their own.
    variable clientxmlns
    set clientxmlns {
	"jabber:client"
	"jabber:iq:last"
	"jabber:iq:oob"
	"jabber:iq:time"
	"jabber:iq:version"
	"jabber:x:event"
    }    
    foreach {key xmlns} [array get coccixmlns] {
	lappend clientxmlns $xmlns
    }
    
    # Short error names.
    variable errorCodeToShort
    array set errorCodeToShort {
      301 {Moved Permanently}
      307 {Moved Temporarily}
      400 {Bad Request}
      401 {Unauthorized}
      404 {Not Found}
      405 {Not Allowed}
      406 {Not Acceptable}
      407 {Registration Required}
      408 {Request Timeout}
    }
    
    # Jabber specific mappings from three digit error code to text.
    variable errorCodeToText
    array set errorCodeToText {\
      conf_pres,301           {The room has changed names}     \
      conf_pres,307           {This room has changed location temporarily}  \
      conf_pres,401           {An authentization step is needed at the service\
      level before you can communicate with this room}      \
      conf_pres,403           {You are being denied access to rooms at the\
      service level}     \
      conf_pres,404           {The server only allows predefined rooms, and\
      the room specified does not exist}    \
      conf_pres,405           {You are being denied access to this specific\
      room, due to being on a ban list}\
      conf_pres,407           {A registration step is needed at the service\
      level before you can communicate with this room}     \
      conf_create,301         {The server has changed addresses}   \
      conf_create,307         {This server has changed location temporarily} \
      conf_create,401         {An authorization step is needed with this\
      service before interactions can occur with it}    \
      conf_create,403         {You are not allowed to interact with this\
      service}    \
      conf_create,407         {Registration with the service is required for\
      all interactions}   \
      conf_message,400        {The message was malformed in some manner,\
      such as sending a message that was of not of type "groupchat" to a room} \
      conf_message,401        {The user is not authorized to speak in this\
      room. This may be because the user does not have voice within the room}
      conf_message,404        {The client is sending a message to a room\
	which does not exist}    \
      conf_message,406        {Additional data was forwarded through the room\
      which the room is not configured to handle}    \
      conf_message,407        {The user is not a participant within the room,\
      and the room does not allow non-participant to speak within the room}  \
      conf_message,408        {The message timed out while being sent,\
      the user may resend}   \
      conf_message_dir,400    {The message was malformed, for instance,\
      it may have had type "groupchat"}   \
      conf_message_dir,401    {The user is not authorized to send directed\
      messages in this room}   \
      conf_message_dir,404    {The user could not be found within the room,\
      or the room does not exist}  \
      conf_message_dir,405    {The conferencing service does not support\
      directed messages}   \
      conf_message_dir,406    {A required extension is stopping this message}  \
      conf_message_dir,407    {The client is required to be in the room in\
      order to send a message to its participants}   \
      conf_message_dir,408    {The message timed out while being sent,\
      the user may resend}  \
    }
  
    variable killerId 
}

# Jabber::FactoryDefaults --
#
#       Makes reasonable default settings for a number of variables and
#       preferences.

proc ::Jabber::FactoryDefaults { } {
    global  this env prefs wDlgs sysFont
    
    variable jstate
    variable jprefs
    variable jserver
    
    # Network.
    set jprefs(port) 5222
    set jprefs(sslport) 5223
    set jprefs(usessl) 0
    
    # Protocol parts
    set jprefs(useSVGT) 0
    
    # Other
    set jprefs(defSubscribe)        1
    set jprefs(logonWhenRegister)   1
    
    # Shall we query ip number directly when verified Coccinella?
    set jprefs(preGetIP) 1
    
    # Get ip addresses through <iq> element.
    # Switch off the raw stuff in later version.
    set jprefs(getIPraw) 0
    
    # Automatically browse users with resource?
    set jprefs(autoBrowseUsers) 1
    
    # Automatically browse conference items?
    set jprefs(autoBrowseConference) 0
    
    # Dialog pane positions.
    set prefs(paneGeom,$wDlgs(jchat)) {0.75 0.25}
    set prefs(paneGeom,$wDlgs(jinbox)) {0.5 0.5}
    set prefs(paneGeom,groupchatDlgVert) {0.8 0.2}
    set prefs(paneGeom,groupchatDlgHori) {0.8 0.2}
    
    set jprefs(useXDataSearch) 1
    
    set jstate(rosterVis) 1
    set jstate(browseVis) 0
    set jstate(rostBrowseVis) 1
    set jstate(debugCmd) 0
    
    # Query these jabber servers for services. Login server is automatically
    # queried.
    set jprefs(browseServers) {}
    set jprefs(agentsServers) {}
    
    # The User Info of servers.    
    set jserver(this) ""
    
    # New... Profiles. These are just leftovers that shall be removed later.
    set jserver(profile)  \
      {jabber.org {jabber.org myUsername myPassword home}}
    set jserver(profile,selected)  \
      [lindex $jserver(profile) 0]
    
    #
    set jprefs(urlServersList) "http://www.jabber.org/servers.php"
    
    switch $this(platform) {
	macintosh - macosx {
	    set jprefs(inboxPath) [file join $this(prefsPath) Inbox.tcl]
	}
	windows {
	    set jprefs(inboxPath) [file join $this(prefsPath) Inbox.tcl]
	}
	unix {
	    set jprefs(inboxPath) [file join $this(prefsPath) inbox.tcl]
	}
    }
    
    # Menu definitions for the Roster/services window. Collects minimal Jabber
    # stuff.
    variable menuDefs
    
    set menuDefs(min,edit) {    
	{command   mCut              {::UI::CutCopyPasteCmd cut}           disabled X}
	{command   mCopy             {::UI::CutCopyPasteCmd copy}          disabled C}
	{command   mPaste            {::UI::CutCopyPasteCmd paste}         disabled V}
    }    
}

# Jabber::SetUserPreferences --
# 
#       Set defaults in the option database for widget classes.
#       First, on all platforms...
#       Set the user preferences from the preferences file if they are there,
#       else take the hardcoded defaults.
#       'thePrefs': a list of lists where each sublist defines an item in the
#       following way:  {theVarName itsResourceName itsHardCodedDefaultValue
#                 {thePriority 20}}.

proc ::Jabber::SetUserPreferences { } {
    
    variable jstate
    variable jprefs
    variable jserver
    
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(port)             jprefs_port              $jprefs(port)]  \
      [list ::Jabber::jprefs(sslport)          jprefs_sslport           $jprefs(sslport)]  \
      [list ::Jabber::jprefs(agentsServers)    jprefs_agentsServers     $jprefs(agentsServers)]  \
      [list ::Jabber::jprefs(browseServers)    jprefs_browseServers     $jprefs(browseServers)]  \
      [list ::Jabber::jserver(profile)         jserver_profile          $jserver(profile)      userDefault] \
      [list ::Jabber::jserver(profile,selected) jserver_profile_selected $jserver(profile,selected) userDefault] \
      ]
}

# Jabber::GetjprefsArray, GetjserverArray, ... --
# 
#       Accesor functions for various preference arrays.

proc ::Jabber::GetjprefsArray { } {
    variable jprefs
    
    return [array get jprefs]
}

proc ::Jabber::GetjserverArray { } {
    variable jserver
    
    return [array get jserver]
}

proc ::Jabber::SetjprefsArray {jprefsArrList} {
    variable jprefs
    
    array set jprefs $jprefsArrList
}

proc ::Jabber::GetIQRegisterElements { } {
    variable jprefs

    return $jprefs(iqRegisterElem)
}

proc ::Jabber::GetServerJid { } {
    variable jserver

    return $jserver(this)
}

proc ::Jabber::GetServerIpNum { } {
    variable jstate
    
    return $jstate(ipNum)
}

proc ::Jabber::GetMyJid {{roomjid {}}} {
    variable jstate

    set jid ""
    if {$roomjid == ""} {
	set jid $jstate(mejidres)
    } else {
	if {[$jstate(jlib) service isroom $roomjid]} {
	    set hashandnick [$jstate(jlib) service hashandnick $roomjid]
	    set jid [lindex $hashandnick 0]   
	}
    }
    return $jid
}

proc ::Jabber::GetMyStatus { } {
    variable jstate
    
    return $jstate(status)
}

proc ::Jabber::GetStatusText {status} {    
    variable mapShowTextToElem
    
    if {[info exists mapShowTextToElem($status)]} {
	return $mapShowTextToElem($status)
    } else {
	return ""
    }
}

proc ::Jabber::JlibCmd {args} {
    variable jstate
    
    eval {$jstate(jlib)} $args
}

proc ::Jabber::IsConnected { } {
    variable jserver

    return [expr [string length $jserver(this)] == 0 ? 0 : 1]
}

# Jabber::RosterCmd, BrowseCmd --
# 
#       Access functions for invoking these commands from the outside.

proc ::Jabber::RosterCmd {args}  {
    variable jstate
    
    eval {$jstate(roster)} $args
}

proc ::Jabber::BrowseCmd {args}  {
    variable jstate
    
    eval {$jstate(browse)} $args
}

proc ::Jabber::DiscoCmd {args}  {
    variable jstate
    
    eval {$jstate(disco)} $args
}

# Generic ::Jabber:: stuff -----------------------------------------------------

# Jabber::Init --
#
#       Make all the necessary initializations, create roster object,
#       jlib object etc.
#       
# Arguments:
#       
# Results:
#       none.

proc ::Jabber::Init { } {
    global  wDlgs prefs
    
    variable jstate
    variable jprefs
    variable coccixmlns
    
    ::Debug 2 "::Jabber::Init"
    
    # Make the roster object.
    set jstate(roster) [::roster::roster ::Jabber::Roster::PushProc]
    
    # Check if we need to set any auto away options.
    set opts {}
    if {$jprefs(autoaway) || $jprefs(xautoaway)} {
	foreach name {autoaway xautoaway awaymin xawaymin awaymsg xawaymsg} {
	    lappend opts -$name $jprefs($name)
	}
    }
    
    # Add the three element callbacks.
    lappend opts  \
      -iqcommand       ::Jabber::IqCallback       \
      -messagecommand  ::Jabber::MessageCallback  \
      -presencecommand ::Jabber::PresenceCallback

    # Make an instance of jabberlib and fill in our roster object.
    set jstate(jlib) [eval {
	::jlib::new $jstate(roster) ::Jabber::ClientProc
    } $opts]

    # Register handlers for various iq elements.
    $jstate(jlib) iq_register get jabber:iq:version      ::Jabber::ParseGetVersion
    $jstate(jlib) iq_register get $coccixmlns(servers) ::Jabber::ParseGetServers
    
    # Set the priority order of groupchat protocols.
    $jstate(jlib) service setgroupchatpriority  \
      [list $jprefs(prefgchatproto) "gc-1.0"]
    
    if {[string equal $prefs(protocol) "jabber"]} {
	::Jabber::UI::Show $wDlgs(jrostbro)
	set jstate(haveJabberUI) 1
    }
    
    # Stuff that need an instance of jabberlib register here.
    ::Debug 4 "--> jabberInitHook"
    ::hooks::run jabberInitHook $jstate(jlib)
}

# ::Jabber::IqCallback --
#
#       Registered callback proc for <iq> elements. Most handled elsewhere,
#       in roster, browser and registered callbacks.
#       
# Results:
#       boolean (0/1) telling if this was handled or not. Only for 'get'.

proc ::Jabber::IqCallback {jlibName type args} {
    variable jstate
    variable jprefs
    
    ::Debug 2 "::Jabber::IqCallback type=$type, args='$args'"
    
    array set attrArr $args
    set xmlns [wrapper::getattribute $attrArr(-query) xmlns]
    set stat 0
    
    return $stat
}

# ::Jabber::MessageCallback --
#
#       Registered callback proc for <message> elements.
#       Not all messages may be delivered here; some may be intersected by
#       the 'register_message hook', some whiteboard messages for instance.
#       
# Arguments:
#       type        normal|chat|groupchat
#       args        ?-key value ...?
#       
# Results:
#       none.

proc ::Jabber::MessageCallback {jlibName type args} {    
    variable jstate
    variable jprefs
    
    ::Debug 2 "::Jabber::MessageCallback type=$type, args='$args'"
    
    array set attrArr {-body ""}
    array set attrArr $args
    
    set from $attrArr(-from)
        
    switch -- $type {
	error {
	    
	    # We must check if there is an error element sent along with the
	    # body element. In that case the body element shall not be processed.
	    if {[info exists attrArr(-error)]} {
		set errcode [lindex $attrArr(-error) 0]
		set errmsg [lindex $attrArr(-error) 1]
		
		tk_messageBox -title [mc Error] \
		  -message [FormatTextForMessageBox \
		  [mc jamesserrsend $attrArr(-from) $errcode $errmsg]]  \
		  -icon error -type ok		
	    }
	    eval {::hooks::run newErrorMessageHook} $args
	}
	chat {
	    eval {::hooks::run newChatMessageHook $attrArr(-body)} $args
	}
	groupchat {
	    eval {::hooks::run newGroupChatMessageHook $attrArr(-body)} $args
	}
	headline {
	    eval {::hooks::run newHeadlineMessageHook $attrArr(-body)} $args
	}
	default {
	    
	    # Normal message. Handles whiteboard stuff as well.
	    eval {::hooks::run newMessageHook $attrArr(-body)} $args
	}
    }
}

# ::Jabber::PresenceCallback --
#
#       Registered callback proc for <presence> elements.
#       
# Arguments:
#       jlibName    Name of jabberlib instance.
#       type        the type attribute of the presence element
#       args        Is a list of '-key value' pairs.
#       
# Results:
#       none.

proc ::Jabber::PresenceCallback {jlibName type args} {
    global  wDlgs prefs
    
    variable jstate
    variable jprefs
    
    ::Debug 2 "::Jabber::PresenceCallback type=$type, args='$args'"
    
    array set attrArr $args
    set from $attrArr(-from)
    
    switch -- $type {
	subscribe {
	    
	    jlib::splitjid $from jid2 resource
	    
	    # Treat the case where the sender is a transport component.
	    # We must be indenpendent of method; agent, browse, disco
	    # The icq transports gives us subscribe from icq.host/registered
	    
	    set jidtype [$jstate(jlib) service gettype $jid2]
	    
	    ::Debug 4 "\t jidtype=$jidtype"
	    
	    if {[regexp {^(service|gateway)/.*} $jidtype]} {
		$jstate(jlib) send_presence -to $from -type "subscribed"
		$jstate(jlib) roster_set $from ::Jabber::Subscribe::ResProc
		
		set subtype [lindex [split $jidtype /] 1]
		set typename [::Jabber::Roster::GetNameFromTrpt $subtype]
		tk_messageBox -title [mc {Transport Suscription}] \
		  -icon info -type ok \
		  -message [mc jamesstrptsubsc $typename]
	    } else {
		
		# Another user request to subscribe to our presence.
		# Figure out what the user's prefs are.
		set allUsers [$jstate(roster) getusers]
		if {[lsearch -exact $allUsers $from] >= 0} {
		    set key inrost
		} else {
		    set key notinrost
		}		
		
		# No resource here!
		set subState [$jstate(roster) getsubscription $from]
		set isSubscriberToMe 0
		if {[string equal $subState "from"] ||  \
		  [string equal $subState "both"]} {
		    set isSubscriberToMe 1
		}
		
		# Accept, deny, or ask depending on preferences we've set.
		set msg ""
		set autoaccepted 0
		
		switch -- $jprefs(subsc,$key) {
		    accept {
			$jstate(jlib) send_presence -to $from -type "subscribed"
			set autoaccepted 1
			set msg [mc jamessautoaccepted $from]
		    }
		    reject {
			$jstate(jlib) send_presence -to $from -type "unsubscribed"
			set msg [mc jamessautoreject $from]
		    }
		    ask {
			eval {::Jabber::Subscribe::NewDlg $from} $args
		    }
		}
		if {$msg != ""} {
		    tk_messageBox -title [mc Info] -icon info -type ok \
		      -message [FormatTextForMessageBox $msg]			      
		}
		
		# Auto subscribe to subscribers to me.
		if {$autoaccepted && $jprefs(subsc,auto)} {
		    
		    # Explicitly set the users group.
		    if {[string length $jprefs(subsc,group)]} {
			$jstate(jlib) roster_set $from ::Jabber::Subscribe::ResProc \
			  -groups [list $jprefs(subsc,group)]
		    }
		    $jstate(jlib) send_presence -to $from -type "subscribe"
		    set msg [mc jamessautosubs $from]
		    tk_messageBox -title [mc Info] -icon info -type ok \
		      -message [FormatTextForMessageBox $msg]			  
		}
	    }
	}
	subscribed {
	    tk_messageBox -title [mc Subscribed] -icon info -type ok  \
	      -message [FormatTextForMessageBox [mc jamessallowsub $from]]
	}
	unsubscribe {	    
	    if {$jprefs(rost,rmIfUnsub)} {
		
		# Remove completely from our roster.
		$jstate(jlib) roster_remove $from ::Jabber::Roster::PushProc
		tk_messageBox -title [mc Unsubscribe] \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox [mc jamessunsub $from]]
	    } else {
		
		$jstate(jlib) send_presence -to $from -type "unsubscribed"
		tk_messageBox -title [mc Unsubscribe] -icon info -type ok  \
		  -message [FormatTextForMessageBox [mc jamessunsubpres $from]]
		
		# If there is any subscription to this jid's presence.
		set sub [$jstate(roster) getsubscription $from]
		if {[string equal $sub "both"] ||  \
		  [string equal $sub "to"]} {
		    
		    set ans [tk_messageBox -title [mc Unsubscribed]  \
		      -icon question -type yesno -default yes \
		      -message [FormatTextForMessageBox  \
		      [mc jamessunsubask $from $from]]]
		    if {$ans == "yes"} {
			$jstate(jlib) roster_remove $from \
			  ::Jabber::Roster::PushProc
		    }
		}
	    }
	}
	unsubscribed {
	    
	    # If we fail to subscribe someone due to a technical reason we
	    # have sunscription='none'
	    set sub [$jstate(roster) getsubscription $from]
	    if {$sub == "none"} {
		set msg [mc jamessfailedsubsc $from]
		if {[info exists attrArr(-status)]} {
		    append msg " Status message: $attrArr(-status)"
		}
		tk_messageBox -title [mc {Subscription Failed}]  \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox $msg]
		if {$jprefs(rost,rmIfUnsub)} {
		    
		    # Remove completely from our roster.
		    $jstate(jlib) roster_remove $from ::Jabber::Roster::PushProc
		}
	    } else {		
		tk_messageBox -title [mc Unsubscribed]  \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox  \
		  [mc jamessunsubscribed $from]]
	    }
	}
	error {
	    foreach {errcode errmsg} $attrArr(-error) break		
	    set msg [mc jamesserrpres $errcode $errmsg]
	    if {$prefs(talkative)} {
		tk_messageBox -icon error -type ok  \
		  -title [mc {Presence Error}] \
		  -message [FormatTextForMessageBox $msg]	
	    }
	    ::Jabber::AddErrorLog $from $msg
	}
    }
}

# Jabber::ClientProc --
#
#       This is our standard client procedure for callbacks from jabberlib.
#       It is supposed to handle every event that is not the arrival of any of
#       the <iq>, <message>, or <presence> elements.
#       
# Arguments:
#       jlibName    Name of jabberlib instance.
#       what        Any of "connect", "disconnect", "xmlerror", "networkerror",
#                   "away", or "xaway"
#       args        Is a list of '-key value' pairs.
#       
# Results:
#       none.

proc ::Jabber::ClientProc {jlibName what args} {
    global  wDlgs
    
    variable jstate
    variable jprefs
    
    ::Debug 2 "::Jabber::ClientProc: jlibName=$jlibName, what=$what, args='$args'"
    
    # For each 'what', split the argument list into the proper arguments,
    # and make the necessary calls.
    array set argsArr $args
    set ishandled 0
    
    switch -- $what {
	connect {
	    
	    # We just got the <stream> element from the server.
	    # Handled via direct callback from 'jlibName connect' instead.
	}
	disconnect {	    
	    
	    # This is as a response to a </stream> element.
	    # If we close the socket and don't wait for the close element
	    # we never end up here.
	    
	    # Disconnect. This should reset both wrapper and XML parser!
	    ::Jabber::DoCloseClientConnection
	    
	    tk_messageBox -icon error -type ok  \
	      -message [mc jamessconnbroken]
	}
	away - xaway {
	    
	    set tm [clock format [clock seconds] -format "%H:%M:%S"]
	    set ans [tk_messageBox -icon info -type yesno -default yes \
	      -message [FormatTextForMessageBox \
	      [mc jamessautoawayset $tm]]]
	    if {$ans == "yes"} {
		::Jabber::SetStatus available
	    }
	}
	streamerror {
	    ::Jabber::DoCloseClientConnection
	    if {[info exists argsArr(-errormsg)]} {
		set msg "Receieved a fatal error:\
		  $argsArr(-errormsg). The connection is closed."
	    } else {
		set msg "Receieved a fatal error. The connection is closed."
	    }
	    tk_messageBox -title [mc {Fatal Error}] -icon error -type ok \
	      -message [FormatTextForMessageBox $msg]
	}
	xmlerror {
	    
	    # XML parsing error.
	    # Disconnect. This should reset both wrapper and XML parser!
	    ::Jabber::DoCloseClientConnection
	    if {[info exists argsArr(-errormsg)]} {
		set msg "Receieved a fatal XML parsing error:\
		  $argsArr(-errormsg). The connection is closed down."
	    } else {
		set msg "Receieved a fatal XML parsing error.\
		  The connection is closed down."
	    }
	    tk_messageBox -title [mc {Fatal Error}] -icon error -type ok \
	      -message [FormatTextForMessageBox $msg]
	}
	networkerror {
	    
	    # Disconnect. This should reset both wrapper and XML parser!
	    ::Jabber::DoCloseClientConnection
	    tk_messageBox -title [mc {Network Error}] \
	      -message [FormatTextForMessageBox $argsArr(-body)] \
	      -icon error -type ok	    
	}
    }
    return $ishandled
}

# Jabber::DebugCmd --
#
#       Hides or shows console on mac and windows, sets debug for XML I/O.

proc ::Jabber::DebugCmd { } {
    global  this
    
    variable jstate
    
    if {$jstate(debugCmd)} {
	if {$this(platform) == "windows" || [string match "mac*" $this(platform)]} {
	    console show
	}
	jlib::setdebug 2
    } else {
	if {$this(platform) == "windows" || [string match "mac*" $this(platform)]} {
	    console hide
	}
	jlib::setdebug 0
    }
}

proc ::Jabber::AddErrorLog {jid msg} {    
    variable jerror
    
    set tm [clock format [clock seconds] -format "%H:%M:%S"]
    lappend jerror [list $tm $jid $msg]
}

# Jabber::ErrorLogDlg

proc ::Jabber::ErrorLogDlg { } {
    global  this wDlgs
    
    variable jerror

    set w $wDlgs(jerrdlg)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w {Error Log (noncriticals)}
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Text.
    set wtxt $w.frall.frtxt
    pack [frame $wtxt] -side top -fill both -expand 1 -padx 4 -pady 4
    set wtext $wtxt.text
    set wysc $wtxt.ysc
    text $wtext -height 12 -width 48 -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set]
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1
    
    set space 2
    $wtext tag configure timetag -spacing1 $space -foreground blue
    $wtext tag configure jidtag -spacing1 $space -foreground red
    $wtext tag configure msgtag -spacing1 $space -spacing3 $space   \
      -lmargin1 20 -lmargin2 30
        
    $wtext configure -state normal
    foreach line $jerror {
	foreach {tm jid msg} $line break
	$wtext insert end "<$tm>:  " timetag
	$wtext insert end "$jid   " jidtag
	$wtext insert end $msg msgtag
	$wtext insert end "\n"
    }
    $wtext configure -state disabled
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btset -text [mc Close]  \
      -command "destroy $w"] -side right -padx 5 -pady 5
    pack $frbot -side top -fill x -padx 8 -pady 6
}

# Jabber::IqSetGetCallback --
#
#       Generic callback procedure when sending set/get iq element.
#       
# Arguments:
#       method      description of the original call.
#       jlibName:   the instance of this jlib.
#       type:       "error" or "result".
#       thequery:   if type="error", this is a list {errcode errmsg},
#                   else it is the query element as a xml list structure.
#       
# Results:
#       none.

proc ::Jabber::IqSetGetCallback {method jlibName type theQuery} {    
    variable jstate
    
    ::Debug 2 "::Jabber::IqSetGetCallback, method=$method, type=$type,\
	  theQuery='$theQuery'"
	
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $theQuery break
	
	switch -- $method {
	    default {
		set msg "Found an error for $method with code $errcode,\
		  and with message: $errmsg"
	    }
	}
	tk_messageBox -icon error -type ok -title [mc Error] -message \
	  [FormatTextForMessageBox $msg]
    }
}

# Jabber::DoCloseClientConnection --
#
#       Handle closing down the client side connection (the 'to' part).
#       Try to be silent if called as a response to a server shutdown.
#       
# Arguments:
#       args      -status, 
#       
# Results:
#       none

proc ::Jabber::DoCloseClientConnection {args} {
    global  prefs
        
    variable jstate
    variable jserver
    variable jprefs
    
    ::Debug 2 "::Jabber::DoCloseClientConnection"
    array set argsArr [list -status $jprefs(logoutStatus)]    
    array set argsArr $args
    
    # Ourself.
    set jstate(mejid) ""
    set jstate(meres) ""
    set jstate(mejidres) ""
    set jstate(status) "unavailable"
    set jserver(this) ""

    # Send unavailable information. Silently in case we got network error.
    set opts {}
    if {[string length $argsArr(-status)] > 0} {
	lappend opts -status $argsArr(-status)
    }
    catch {
	eval {$jstate(jlib) send_presence -type unavailable} $opts
    }
        
    # Do the actual closing.
    #       There is a potential problem if called from within a xml parser 
    #       callback which makes the subsequent parsing to fail. (after idle?)
    after idle $jstate(jlib) closestream
    
    set jstate(ipNum) ""
    
    # Run all logout hooks.
    ::hooks::run logoutHook
}

# Jabber::EndSession --
#
#       This is supposed to be called only when doing Quit.
#       Things are not cleaned up properly, since we kill ourselves.

proc ::Jabber::EndSession { } {    
    variable jstate
    variable jserver
    variable jprefs

    # Send unavailable information. Silently in case we got network error.
    if {[::Jabber::IsConnected]} {
	set opts {}
	if {[string length $jprefs(logoutStatus)] > 0} {
	    lappend opts -status $jprefs(logoutStatus)
	}
	catch {
	    eval {$jstate(jlib) send_presence -type unavailable} $opts
	}
	
	# Do the actual closing.
	#       There is a potential problem if called from within a xml parser 
	#       callback which makes the subsequent parsing to fail. (after idle?)
	$jstate(jlib) closestream
    }
}

# Jabber::Validate... --
#
#       Validate entry for username etc.
#       
# Arguments:
#       str     username etc.
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::ValidateDomainStr {str} {
    
    if {[catch {jlib::nameprep $str} err]} {
	bell
	return 0
    } else {
	return 1
    }
}

proc ::Jabber::ValidateUsernameStr {str} {
    
    if {[catch {jlib::nodeprep $str} err]} {
	bell
	return 0
    } else {
	return 1
    }
}

proc ::Jabber::ValidateResourceStr {str} {
    
    if {[catch {jlib::resourceprep $str} err]} {
	bell
	return 0
    } else {
	return 1
    }
}

# Jabber::ValidatePasswdChars --
#
#       Validate entry for password. Not so sure about this. Docs?
#       
# Arguments:
#       str     password
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::ValidatePasswdChars {str} {
    
    if {[regexp {[ ]} $str match junk]} {
	bell
	return 0
    } else {
	return 1
    }
}

# Jabber::IsMyGroupchatJid --
# 
#       Is the jid our own used in groupchat?

proc ::Jabber::IsMyGroupchatJid {jid} {
    variable jstate
    
    jlib::splitjid $jid room resource
    foreach {meHash nick} [$jstate(jlib) service hashandnick $room] break
    set isme 0
    if {[string equal $meHash $jid]} {
	set isme 1
    }
    return $isme
}

# Jabber::SetStatus --
#
#       Sends presence status information. 
#       It should take care of everything (almost) when setting status.
#       
# Arguments:
#       type        any of 'available', 'unavailable', 'invisible',
#                   'away', 'dnd', 'xa', 'chat'.
#       args
#                -to      sets any to='jid' attribute.
#                -notype  0|1 see XMPP 5.1
#                -priority
#                -status  text message
#                -xlist
#                -extras
#       
# Results:
#       None.

proc ::Jabber::SetStatus {type args} {    
    variable jstate
    variable jserver
    
    array set argsArr {
	-notype         0
    }
    array set argsArr $args
    
    # This way clients get the info necessary for file transports.
    # Necessary for each status change since internal cache cleared.
    if {$type != "unavailable"} {
	set cocciElem [CreateCoccinellaPresElement]
	set capsElem  [CreateCapsPresElement]
	lappend argsArr(-extras) $cocciElem $capsElem
    }
    set presArgs {}
    foreach {key value} [array get argsArr] {
	
	switch -- $key {
	    -to - -priority - -status - -xlist - -extras {
		lappend presArgs $key $value
	    }
	}
    }
    if {!$argsArr(-notype)} {
	
	switch -- $type {
	    available {
		# empty
	    }
	    invisible - unavailable {
		lappend presArgs -type $type
	    }
	    away - dnd - xa - chat {
		# Seems Psi gets confused by this.
		#lappend presArgs -type "available" -show $type
		lappend presArgs -show $type
	    }
	}	
    }
    
    # Trap network errors.
    # It is somewhat unclear here if we should have a type attribute
    # when sending initial presence, see XMPP 5.1.
    if {[catch {	
	eval {$jstate(jlib) send_presence} $presArgs
    } err]} {
	
	# Close down?	
	DoCloseClientConnection
	tk_messageBox -title [mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    } else {
	
	eval {::hooks::run setPresenceHook $type} $args
	
	# Do we target a room or the server itself?
	set toServer 0
	if {[info exists argsArr(-to)]} {
	    if {[jlib::jidequal $jserver(this) $argsArr(-to)]} {
		set toServer 1
	    }
	} else {
	    set toServer 1
	}
	if {$toServer && ($type == "unavailable")} {
	    DoCloseClientConnection
	}
    }
}

# Jabber::CreateCoccinellaPresElement --
# 
#       Used when sending inital presence. This way clients get the info
#       necessary for file transports.
#       
#  <coccinella 
#      xmlns='http://coccinella.sourceforge.net/protocol/servers'>
#                <ip protocol='putget' port='8235'>212.214.113.57</ip>
#                <ip protocol='http' port='8077'>212.214.113.57</ip>
#  </coccinella>

proc ::Jabber::CreateCoccinellaPresElement { } {
    global  prefs
    
    variable jstate
    variable coccixmlns
	
    set ip [::Network::GetThisPublicIPAddress]

    set attrputget [list protocol putget port $prefs(thisServPort)]
    set attrhttpd  [list protocol http   port $prefs(httpdPort)]
    set subelem [list  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrputget]  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrhttpd]]
    set xmllist [wrapper::createtag coccinella -subtags $subelem \
      -attrlist [list xmlns $coccixmlns(servers) ver $prefs(fullVers)]]

    return $xmllist
}

# Jabber::CreateCapsPresElement --
# 
#       Used when sending inital presence. This way clients get various info.
#       See [JEP 0115]
#       Note that this doesn't replace the 'coccinella' element since caps
#       are not instance specific (can't send ip addresses).

proc ::Jabber::CreateCapsPresElement { } {
    global  prefs
    variable coccixmlns

    set capsxmlns "http://jabber.org/protocol/caps"
    set node $coccixmlns(caps)
    set ext "ftrans"
    set xmllist [wrapper::createtag c \
      -attrlist [list xmlns $capsxmlns node $node ver $prefs(fullVers) ext $ext]]

    return $xmllist
}

# Jabber::SetStatusWithMessage --
#
#       Dialog for setting user's status with message.
#       
# Arguments:
#       
# Results:
#       "cancel" or "set".

proc ::Jabber::SetStatusWithMessage { } {
    global  this wDlgs
    
    variable finishedStat
    variable show
    variable wtext
    variable jprefs
    variable jstate

    set w $wDlgs(jpresmsg)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {Set Status}]
    set finishedStat -1
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Top frame.
    set frtop $w.frall.frtop
    labelframe $frtop -text [mc {My Status}]
    pack $frtop -side top -fill x -padx 4 -pady 4
    set i 0
    foreach val {available chat away xa dnd invisible} {
	label ${frtop}.l${val} -image [::Jabber::Roster::GetPresenceIconFromKey $val]
	radiobutton ${frtop}.${val} -text [mc jastat${val}]  \
	  -variable [namespace current]::show -value $val
	grid ${frtop}.l${val} -sticky e -column 0 -row $i -padx 4 -pady 3
	grid ${frtop}.${val} -sticky w -column 1 -row $i -padx 8 -pady 3
	incr i
    }
    
    # Set present status.
    set show $jstate(status)
    
    pack [label $w.frall.lbl -text "[mc {Status message}]:" \
      -font $fontSB]  \
      -side top -anchor w -padx 6 -pady 0
    set wtext $w.frall.txt
    text $wtext -height 4 -width 36 -wrap word \
      -borderwidth 1 -relief sunken
    pack $wtext -expand 1 -fill both -padx 6 -pady 4    
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Set] -default active \
      -command [list [namespace current]::BtSetStatus $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::SetStatusCancel $w]] \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> {}
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finishedStat <= 0) ? "cancel" : "set"}]
}

proc ::Jabber::SetStatusCancel {w} {    
    variable finishedStat

    set finishedStat 0
    destroy $w
}

proc ::Jabber::BtSetStatus {w} {
    variable finishedStat
    variable show
    variable wtext
    variable jstate
    
    set statusOpt {}
    set allText [string trim [$wtext get 1.0 end] " \n"]
    
    # Set present status.
    set jstate(status) $show
    SetStatus $show -status $allText    
    set finishedStat 1
    destroy $w
}

# Jabber::ParseAndInsertText --
#
#       Parses for smileys and url's and insert into text widget.
#       
# Arguments:
#       w           text widget
#       str         raw text to process
#       
# Results:
#       none.

proc ::Jabber::ParseAndInsertText {w str tag linktag} {
    
    # Smileys.
    set cmdList [::Emoticons::Parse $str]
    
    # Http links.
    set textCmdList {}
    foreach {txt icmd} $cmdList {
	set httpCmd [::Text::ParseHttpLinks $txt $tag $linktag]
	if {$icmd == ""} {
	    eval lappend textCmdList $httpCmd
	} else {
	    eval lappend textCmdList $httpCmd [list $icmd]
	}
    }

    # Insert into text widget.
    foreach cmd $textCmdList {
	eval {$w} $cmd
    }
    $w insert end "\n"
}
    
# Jabber::GetAnyDelayElem --
#
#       Takes a list of x-elements, finds any 'jabber:x:delay' x-element.
#       If no such element it returns empty.
#       
# Arguments:
#       xlist       Must be an hierarchical xml list of <x> elements.  
#       
# Results:
#       jabber:x:delay stamp attribute or empty. This is ISO 8601.

proc ::Jabber::GetAnyDelayElem {xlist} {
    
    set ans ""
    
    set delayList [wrapper::getnamespacefromchilds $xlist x "jabber:x:delay"]
    if {[llength $delayList]} {
	array set attrArr [wrapper::getattrlist [lindex $delayList 0]]
	if {[info exists attrArr(stamp)]} {
	    set ans $attrArr(stamp)
	}
    }
    return $ans
}

#-------------------------------------------------------------------------------
    
# Jabber::GetLast --
#
#       Makes a jabber:iq:last query.
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::GetLast {to args} {
    variable jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args    
    $jstate(jlib) get_last $to [list ::Jabber::GetLastResult $to $opts(-silent)]
}

# Jabber::GetLastResult --
#
#       Callback for '::Jabber::GetLast'.

proc ::Jabber::GetLastResult {from silent jlibname type subiq} {    

    if {[string equal $type "error"]} {
	set msg [mc jamesserrlastactive $from [lindex $subiq 1]]
	::Jabber::AddErrorLog $from $msg	    
	if {!$silent} {
	    tk_messageBox -title [mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox $msg]
	}
    } else {
	array set attrArr [wrapper::getattrlist $subiq]
	if {![info exists attrArr(seconds)]} {
	    tk_messageBox -title [mc {Last Activity}] -icon info  \
	      -type ok -message [FormatTextForMessageBox \
	      [mc jamesserrnotimeinfo $from]]
	} else {
	    set secs [expr [clock seconds] - $attrArr(seconds)]
	    set uptime [clock format $secs -format "%a %b %d %H:%M:%S"]
	    if {[wrapper::getcdata $subiq] != ""} {
		set msg "The message: [wrapper::getcdata $subiq]"
	    } else {
		set msg {}
	    }
	    
	    # Time interpreted differently for different jid types.
	    if {$from != ""} {
		if {[regexp {^[^@]+@[^/]+/.*$} $from match]} {
		    set msg1 [mc jamesstimeused $from]
		} elseif {[regexp {^.+@[^/]+$} $from match]} {
		    set msg1 [mc jamesstimeconn $from]
		} else {
		    set msg1 [mc jamesstimeservstart $from]
		}
	    } else {
		set msg1 [mc jamessuptime]
	    }
	    tk_messageBox -title [mc {Last Activity}] -icon info  \
	      -type ok -message [FormatTextForMessageBox "$msg1 $uptime. $msg"]
	}
    }
}

# Jabber::GetTime --
#
#       Makes a jabber:iq:time query.
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::GetTime {to args} {
    variable jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args    
    $jstate(jlib) get_time $to [list ::Jabber::GetTimeResult $to $opts(-silent)]
}

proc ::Jabber::GetTimeResult {from silent jlibname type subiq} {

    if {[string equal $type "error"]} {
	::Jabber::AddErrorLog $from  \
	  "We received an error when quering its time info.\
	  The error was: [lindex $subiq 1]"	    
	if {!$silent} {
	    tk_messageBox -title [mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox \
	      [mc jamesserrtime $from [lindex $subiq 1]]]
	}
    } else {
	
	# Display the cdata of <display>, or <utc>.
	foreach child [wrapper::getchildren $subiq] {
	    set tag [lindex $child 0]
	    set $tag [lindex $child 3]
	}
	if {[info exists display]} {
	    set msg $display
	} elseif {[info exists utc]} {
	    set msg [clock format [clock scan $utc]]
	} elseif {[info exists tz]} {
	    # ???
	} else {
	    set msg "unknown"
	}
	tk_messageBox -title [mc {Local Time}] -icon info -type ok -message \
	  [FormatTextForMessageBox [mc jamesslocaltime $from $msg]]
    }
}

namespace eval ::Jabber:: {
    
    # Running uid for dialog window path.
    variable uidvers 0
}

# Jabber::GetVersion --
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::GetVersion {to args} {
    variable jstate

    array set opts {
	-silent 0
    }
    array set opts $args    
    $jstate(jlib) get_version $to [list ::Jabber::GetVersionResult $to $opts(-silent)]
}

proc ::Jabber::GetVersionResult {from silent jlibname type subiq} {
    global  prefs this
    
    variable uidvers
    
    set fontSB [option get . fontSmallBold {}]
    
    if {[string equal $type "error"]} {
	::Jabber::AddErrorLog $from  \
	  [mc jamesserrvers $from [lindex $subiq 1]]
	if {!$silent} {
	    tk_messageBox -title [mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox \
	      [mc jamesserrvers $from [lindex $subiq 1]]]
	}
    } else {
	set w .jvers[incr uidvers]
	::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
	  -macclass {document closeBox}
	wm title $w [mc {Version Info}]
	set iconInfo [::Theme::GetImage info]
	pack [label $w.icon -image $iconInfo] -side left -anchor n -padx 10 -pady 10
	pack [label $w.msg -text [mc javersinfo $from] -font $fontSB] \
	  -side top -padx 8 -pady 4
	pack [frame $w.fr] -padx 10 -pady 4 -side top 
	set i 0
	foreach child [wrapper::getchildren $subiq] {
	    label $w.fr.l$i -font $fontSB -text "[lindex $child 0]:"
	    label $w.fr.lr$i -text [lindex $child 3]
	    grid $w.fr.l$i -column 0 -row $i -sticky e
	    grid $w.fr.lr$i -column 1 -row $i -sticky w
	    incr i
	}
	pack [button $w.btok -text [mc OK] \
	  -command "destroy $w"] -side right -padx 10 -pady 8
	wm resizable $w 0 0
	bind $w <Return> "$w.btok invoke"
    }
}

# Jabber::CacheGroupchatType --
#
#       Callback from a 'jabber:iq:version' query called from either the agent,
#       or the browse callback procs to see which protocols may be used:
#       'conference' and 'groupchat' or only 'groupchat'.
#

proc ::Jabber::CacheGroupchatType {confjid jlibname type subiq} {    
    variable jstate
    
    if {[string equal $type "error"]} {
	
	# Perhaps we should log it in our error log?
	return
    }
    
    # The conference component:
    # <query xmlns='jabber:iq:version'><name>conference</name><version>0.4</version>
    #   <os>Linux 2.4.2-2</os></query>
    
    # The MUC, Multi User Chat (MUC) component:
    # <query xmlns='jabber:iq:version'><name>MU-Conference</name><version>0.4cvs</version>
    #	<os>Linux 2.4.17</os></query>
    
    set name ""
    set version ""
    foreach child [wrapper::getchildren $subiq] {
	set tag  [wrapper::gettag $child]
	set $tag [wrapper::getcdata $child]
    }
		
    # This is a VERY rude ad hoc method of figuring out if the
    # server has a conference component.
    if {($name == "conference") && ($version != "1.0") && ($version != "1.1")} {
	set jstate(conference,$confjid) 1
	set jstate(groupchatprotocol,$confjid) "conference"
    } elseif {[string match -nocase "*mu*" $name]} {
	set jstate(groupchatprotocol,$confjid) "muc"
    }
}
    
# Jabber::ParseGetVersion --
#
#       Respond to an incoming 'jabber:iq:version' get query.

proc ::Jabber::ParseGetVersion {jlibname from subiq args} {
    global  prefs tcl_platform
    variable jstate
    
    ::Debug 2 "Jabber::ParseGetVersion args='$args'"
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    lappend opts -to $from
   
    set os $tcl_platform(os)
    if {[info exists tcl_platform(osVersion)]} {
	append os " $tcl_platform(osVersion)"
    }
    set version $prefs(majorVers).$prefs(minorVers).$prefs(releaseVers)
    set subtags [list  \
      [wrapper::createtag name    -chdata "Coccinella"]  \
      [wrapper::createtag version -chdata $version]      \
      [wrapper::createtag os      -chdata $os]]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist {xmlns jabber:iq:version}]
     eval {$jstate(jlib) send_iq "result" $xmllist} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}

# Jabber::ParseGetServers --
# 
#       Sends something like:
#       <iq type='result' id='1012' to='matben@jabber.dk/coccinella'>
#           <query xmlns='http://coccinella.sourceforge.net/protocol/servers'>
#                <ip protocol='putget' port='8235'>212.214.113.57</ip>
#                <ip protocol='http' port='8077'>212.214.113.57</ip>
#            </query>
#       </iq>
#       

proc ::Jabber::ParseGetServers  {jlibname from subiq args} {
    global  prefs
    
    variable jstate
    variable coccixmlns
    
    # Build tag and attributes lists.
    set ip [::Network::GetThisPublicIPAddress]
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    lappend opts -to $from
    
    set attrputget [list protocol putget port $prefs(thisServPort)]
    set attrhttpd  [list protocol http port $prefs(httpdPort)]
    set subtags [list  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrputget]  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrhttpd]]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist [list xmlns $coccixmlns(servers)]]
     eval {$jstate(jlib) send_iq "result" $xmllist} $opts
    
     # Tell jlib's iq-handler that we handled the event.
    return 1
}

proc ::Jabber::AddClientXmlns {xmlnsList} {
    variable clientxmlns
    
    set clientxmlns [concat $clientxmlns $xmlnsList]
}

proc ::Jabber::GetClientXmlnsList { } {
    variable clientxmlns
    
    return $clientxmlns
}

# The ::Jabber::Passwd:: namespace -------------------------------------------

namespace eval ::Jabber::Passwd:: {

    variable password
}

# Jabber::Passwd::Build --
#
#       Sets new password.
#
# Arguments:
#       
# Results:
#       "cancel" or "set".

proc ::Jabber::Passwd::Build { } {
    global  this wDlgs
    
    variable finished -1
    variable password
    variable validate
    upvar ::Jabber::jstate jstate
    
    set w $wDlgs(jpasswd)
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {New Password}]
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    set password ""
    set validate ""
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.ll -font $fontSB -text [mc janewpass]
    label $frmid.le -font $fontSB -text $jstate(mejid)
    label $frmid.lserv -text "[mc {New password}]:" -anchor e
    entry $frmid.eserv -width 18 -show *  \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    label $frmid.lvalid -text "[mc {Retype password}]:" -anchor e
    entry $frmid.evalid -width 18 -show * \
      -textvariable [namespace current]::validate -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    grid $frmid.ll -column 0 -row 0 -sticky e
    grid $frmid.le -column 1 -row 0 -sticky w
    grid $frmid.lserv -column 0 -row 1 -sticky e
    grid $frmid.eserv -column 1 -row 1 -sticky w
    grid $frmid.lvalid -column 0 -row 2 -sticky e
    grid $frmid.evalid -column 1 -row 2 -sticky w
    pack $frmid -side top -fill both -expand 1

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Set] -default active \
      -command [list [namespace current]::Doit $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]   \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btok invoke"
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "set"}]
}

proc ::Jabber::Passwd::Cancel {w} {
    variable finished
    
    set finished 0
    destroy $w
}

# Jabber::Passwd::Doit --
#
#       Initiates a register operation. Must be connected already!
#
# Arguments:
#       
# Results:
#       .

proc ::Jabber::Passwd::Doit {w} {
    global  errorCode prefs

    variable validate
    variable password
    variable finished
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Debug 2 "::Jabber::Passwd::Doit"

    if {![string equal $validate $password]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox [mc jamesspasswddiff]]
	return
    }
    set finished 1
    regexp -- {^([^@]+)@.+$} $jstate(mejid) match username
    $jstate(jlib) register_set $username $password \
      [list [namespace current]::ResponseProc] -to $jserver(this)
    destroy $w

    # Just wait for a callback to the procedure.
}

proc ::Jabber::Passwd::ResponseProc {jlibName type theQuery} {    
    variable password
    upvar ::Jabber::jstate jstate

    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	set msg 
	tk_messageBox -title [mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox  \
	  [mc jamesspasswderr $errcode $errmsg]] \
    } else {
		
	# Make sure the new password is stored in our profiles.
	set name [::Profiles::FindProfileNameFromJID $jstate(mejid)]
	if {$name != ""} {
	    set spec [::Profiles::GetProfile $name]
	    if {[llength $spec] > 0} {
		lset spec 2 $password
		eval {::Profiles::Set {}} $spec
	    }
	}
	tk_messageBox -title [mc {New Password}] -icon info -type ok \
	  -message [FormatTextForMessageBox [mc jamesspasswdok]]
    }
}

# Jabber::LoginLogout --
# 
#       Toggle login/logout. Useful for binding in menu.

proc ::Jabber::LoginLogout { } {
    
    ::Debug 2 "::Jabber::LoginLogout"
    if {[::Jabber::IsConnected]} {
	::Jabber::DoCloseClientConnection
    } else {
	::Jabber::Login::Dlg
    }    
}

# The ::Jabber::Logout:: namespace ---------------------------------------------

namespace eval ::Jabber::Logout:: { }

proc ::Jabber::Logout::WithStatus { } {
    global  prefs this wDlgs

    variable finished -1
    variable status ""
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Jabber::Logout::WithStatus"

    set w $wDlgs(joutst)
    if {[winfo exists $w]} {
	return
    }
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {Logout With Message}]
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    
    ::headlabel::headlabel $w.frall.head -text [mc Logout]
    pack $w.frall.head -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill both -expand 1 -pady 6
    
    label $frmid.lstat -text "[mc Message]:" -font $fontSB -anchor e
    entry $frmid.estat -width 36  \
      -textvariable [namespace current]::status
    grid $frmid.lstat -column 0 -row 1 -sticky e
    grid $frmid.estat -column 1 -row 1 -sticky w
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btout -text [mc Logout]  \
      -default active -command [list [namespace current]::DoLogout $w]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::DoCancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    ::UI::SetWindowPosition $w
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btout invoke"
    
    # Grab and focus.
    set oldFocus [focus]
    focus $frmid.estat
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    # Clean up.
    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "logout"}]
}

proc ::Jabber::Logout::DoCancel {w} {
    variable finished
    
    set finished 0
    destroy $w
}

proc ::Jabber::Logout::DoLogout {w} {
    variable finished
    variable status
    upvar ::Jabber::jstate jstate
    
    set finished 1
    destroy $w
    ::Jabber::DoCloseClientConnection -status $status
}


#-------------------------------------------------------------------------------
