#  Jabber.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements the "glue" between the whiteboard and jabberlib.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: Jabber.tcl,v 1.20 2003-09-13 06:39:25 matben Exp $
#
#  The $address is an ip name or number.
#
#  jserver(all)               list of all profiles in array
#  jserver(profile,selected)  profile picked in user info
#  jserver(this)              present connected $address
#  jserver(profile):          {$profile1 {$server1 $username $password $resource} \
#                              $profile2 {$server2 $username2 $password2 $resource2} ... }

package provide Jabber 1.0

package require tree
package require jlib
package require roster
package require browse
package require chasearrows
package require http 2.3
package require balloonhelp
package require tablelist
package require mactabnotebook
package require combobox
package require tinyfileutils
package require uriencode
package require JForms
package require MailBox
package require NewMsg
package require GotMsg
package require OOB
package require Chat
package require Agents
package require Browse
package require Roster
package require GroupChat
package require MUC

namespace eval ::Jabber:: {
    global  this
    
    # Jabber internal storage.
    variable jstate
    variable jprefs
    variable jserver
    variable jerror
        
    # The trees 'directories' which should always be there.
    set jprefs(treedirs) {Online Offline {Subscription Pending}}
    set jprefs(closedtreedirs) {}
    
    # Our own jid, and jid/resource respectively.
    set jstate(mejid) ""
    set jstate(mejidres) ""
    
    #set jstate(alljid) {}   not implemented yet...
    set jstate(sock) {}
    set jstate(ipNum) {}
    set jstate(inroster) 0
    set jstate(status) "unavailable"
    
    # Server port actually used.
    set jstate(servPort) {}
    set jstate(debug) 0

    # Login server.
    set jserver(this) ""

    # Regexp pattern for username etc. Ascii no. 0-32 (deci) not allowed.
    set jprefs(invalsExp) {.*([\x00-\x20]|[\r\n\t@:' <>&"/])+.*}
    set jprefs(valids) {[^\x00-\x20]|[^\r\n\t@:' <>&"]}
    
    # List all iq:register personal info elements.
    set jprefs(iqRegisterElem)   \
      {first last nick email address city state phone url}
    
    # Popup menus.
    set jstate(wpopup,roster) .jpopupro
    set jstate(wpopup,browse) .jpopupbr
    set jstate(wpopup,groupchat) .jpopupgc
    set jstate(wpopup,agents) .jpopupag
    
    # Keep noncritical error text here.
    set jerror {}
    
    # Get/put ip numbers.
    variable getid 1001
    # Records any callback procs, index from 'getid'.
    variable getcmd
    
    # Array that maps 'jid' to its ip number.
    variable jidToIP
    
    # Array that acts as a data base for the public storage on the server.
    # Typically: jidPublic(matben@athlon.se,home,serverport).
    # Not used for the moment.
    variable jidPublic
    set jidPublic(haveit) 0
    
    # Mappings from <show> element to displayable text and vice versa.
    # chat away xa dnd
    variable mapShowElemToText
    variable mapShowTextToElem
    
    array set mapShowElemToText  \
      [list [::msgcat::mc mAvailable] available  \
      [::msgcat::mc mAway]            away       \
      [::msgcat::mc mDoNotDisturb]    dnd        \
      [::msgcat::mc mExtendedAway]    xa         \
      [::msgcat::mc mInvisible]       invisible  \
      [::msgcat::mc mNotAvailable]    unavailable]
    array set mapShowTextToElem  \
      [list available [::msgcat::mc mAvailable]     \
      away            [::msgcat::mc mAway]          \
      dnd             [::msgcat::mc mDoNotDisturb]  \
      xa              [::msgcat::mc mExtendedAway]  \
      invisible       [::msgcat::mc mInvisible]     \
      unavailable     [::msgcat::mc mNotAvailable]]
        
    # Array that maps namespace (ns) to a descriptive name.
    variable nsToText
    array set nsToText {
      jabber:iq:agent              {Server component properties}
      jabber:iq:agents             {Server component properties}
      jabber:iq:auth               {Client authentization}      
      jabber:iq:autoupdate         {Release information}
      jabber:iq:browse             {Browsing services}
      jabber:iq:conference         {Conferencing service}
      jabber:iq:gateway            {Gateway}
      jabber:iq:last               {Last time}
      jabber:iq:oob                {Out of band data}
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
      
    # Templates for popup menus for the roster, browse, and groupchat windows.
    # The roster:
    set jstate(popup,roster,def) {
      mMessage       users     {::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to &jid}
      mChat          user      {::Jabber::Chat::StartThread &jid}
      mWhiteboard    wb        {::Jabber::WB::NewWhiteboard &jid}
      separator      {}        {}
      mLastLogin/Activity user {::Jabber::GetLast &jid}
      mvCard         user      {::VCard::Fetch .jvcard other &jid}
      mAddNewUser    any       {
	  ::Jabber::Roster::NewOrEditItem $wDlgs(jrostnewedit) new
      }
      mEditUser      user      {
	  ::Jabber::Roster::NewOrEditItem $wDlgs(jrostnewedit) edit -jid &jid
      }
      mVersion       user      {::Jabber::GetVersion &jid3}
      mChatHistory   user      {::Jabber::Chat::BuildHistory &jid}
      mRemoveUser    user      {::Jabber::Roster::SendRemove &jid}
      separator      {}        {}
      mStatus        any       @::Jabber::Roster::BuildPresenceMenu
      mRefreshRoster any       {::Jabber::Roster::Refresh}
    }  
  
    # Can't run our http server on macs :-(
    if {![string equal $this(platform) "macintosh"]} {
	set jstate(popup,roster,def) [linsert $jstate(popup,roster,def) 9  \
	  mSendFile     user      {::Jabber::OOB::BuildSet .joobs &jid}]
    }
    
    # The browse:
    set jstate(popup,browse,def) {
      mMessage       user      {::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to &jid}
      mChat          user      {::Jabber::Chat::StartThread &jid}
      mWhiteboard    wb        {::Jabber::WB::NewWhiteboard &jid}
      mEnterRoom     room      {
	  ::Jabber::GroupChat::EnterOrCreate enter -roomjid &jid -autoget 1
      }
      mCreateRoom    conference {::Jabber::GroupChat::EnterOrCreate create}
      separator      {}        {}
      mLastLogin/Activity jid  {::Jabber::GetLast &jid}
      mLocalTime     jid       {::Jabber::GetTime &jid}
      mvCard         jid       {::VCard::Fetch .jvcard other &jid}
      mVersion       jid       {::Jabber::GetVersion &jid}
      separator      {}        {}
      mSearch        search    {
	  ::Jabber::Search::Build .jsearch -server &jid -autoget 1
      }
      mRegister      register  {
	  ::Jabber::GenRegister::BuildRegister .jreg -server &jid -autoget 1
      }
      mUnregister    register  {::Jabber::Register::Remove &jid}
      separator      {}        {}
      mRefresh       jid       {::Jabber::Browse::Refresh &jid}
      mAddServer     any       {::Jabber::Browse::AddServer}
    }
    
    # The groupchat:
    set jstate(popup,groupchat,def) {
      mMessage       user      {::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to &jid}
      mChat          user      {::Jabber::Chat::StartThread &jid}
      mWhiteboard    wb        {::Jabber::WB::NewWhiteboard &jid}
    }    
    
    # The agents stuff:
    set jstate(popup,agents,def) {
      mSearch        search    {
	  ::Jabber::Search::Build .jsearch -server &jid -autoget 1
      }
      mRegister      register  {
	  ::Jabber::GenRegister::BuildRegister .jreg -server &jid -autoget 1
      }
      mUnregister    register  {::Jabber::Register::Remove &jid}
      separator      {}        {}
      mEnterRoom     groupchat {::Jabber::GroupChat::EnterOrCreate enter}
      mLastLogin/Activity jid  {::Jabber::GetLast &jid}
      mLocalTime     jid       {::Jabber::GetTime &jid}
      mVersion       jid       {::Jabber::GetVersion &jid}
   }    
  
    variable killerId 
}

proc ::Jabber::Debug {num str} {
    variable jstate
    if {$num <= $jstate(debug)} {
	puts $str
    }
}

# Jabber::FactoryDefaults --
#
#       Makes reasonable default settings for a number of variables and
#       preferences.

proc ::Jabber::FactoryDefaults { } {
    global  sysFont this env prefs wDlgs

    variable jstate
    variable jprefs
    variable jserver
    
    # Network.
    set jprefs(port) 5222
    set jprefs(sslport) 5223
    set jprefs(usessl) 0
    
    # Other
    set jprefs(defSubscribe) 1
    set jprefs(rost,rmIfUnsub) 1
    set jprefs(rost,allowSubNone) 1
    set jprefs(rost,clrLogout) 1
    set jprefs(rost,dblClk) normal
    set jprefs(subsc,inrost) ask
    set jprefs(subsc,notinrost) ask
    set jprefs(subsc,auto) 0
    set jprefs(subsc,group) {}
    set jprefs(chat,showtime) 1
    set jprefs(block,notinrost) 0
    set jprefs(block,list) {}
    set jprefs(speakMsg) 0
    set jprefs(speakChat) 0
    
    # Preferred groupchat protocol (gc-1.0|muc).
    # 'muc' uses 'conference' as fallback.
    set jprefs(prefgchatproto) "muc"
    
    # Automatically browse users with resource?
    set jprefs(autoBrowseUsers) 1
    
    # Show special icons for foreign IM systems?
    set jprefs(haveIMsysIcons) 0
    
    # Dialog pane positions.
    set prefs(paneGeom,$wDlgs(jchat)) {0.75 0.25}
    set prefs(paneGeom,$wDlgs(jinbox)) {0.5 0.5}
    set prefs(paneGeom,groupchatDlgVert) {0.8 0.2}
    set prefs(paneGeom,groupchatDlgHori) {0.8 0.2}
    
    # Autoupdate; be sure to use version key since a new version must not inherit.
    # Abondened!!!!!!!
    set jprefs(autoupdateCheck) 0
    set jprefs(autoupdateShow,$prefs(fullVers)) 1
        
    # Sounds.
    set jprefs(snd,online) 1
    set jprefs(snd,offline) 1
    set jprefs(snd,newmsg) 1
    set jprefs(snd,statchange) 1
    set jprefs(snd,connected) 1

    set jprefs(showMsgNewWin) 1
    set jprefs(inbox2click) "newwin"
    
    # Save inbox when quit?
    set jprefs(inboxSave) 0
    
    set jprefs(autoaway) 0
    set jprefs(xautoaway) 0
    set jprefs(awaymin) 0
    set jprefs(xawaymin) 0
    set jprefs(awaymsg) {}
    set jprefs(xawaymsg) {User has been inactive for a while}
    
    set jprefs(logoutStatus) ""
    
    set jprefs(chatFont) $sysFont(s)
    set jprefs(useXDataSearch) 1
    
    # Service discovery method: "agents" or "browse"
    set jprefs(agentsOrBrowse) "browse"
    
    set jstate(rosterVis) 1
    set jstate(browseVis) 0
    set jstate(rostBrowseVis) 1
    set jstate(debugCmd) 0
    
    # Personal info corresponding to the iq:register namespace.
    foreach key $jprefs(iqRegisterElem) {
	set jprefs(iq:register,$key) {}
    }
    
    # Query these jabber servers for services. Login server is automatically
    # queried.
    set jprefs(browseServers) {}
    set jprefs(agentsServers) {}
    
    # The User Info of servers.    
    set jserver(this) ""
    
    #
    set jprefs(urlServersList) "http://www.jabber.org/servers.php"
    
    # New... Profiles
    set jserver(profile)  \
      {jabber.org {jabber.org myUsername myPassword home}}
    set jserver(profile,selected)  \
      [lindex $jserver(profile) 0]
    set jserver(all) {}
    foreach {name spec} $jserver(profile) {
	lappend jserver(all) $name
    }
    
    switch $this(platform) {
	macintosh - macosx {
	    set jprefs(inboxPath) [file join $prefs(prefsDir) Inbox.tcl]
	}
	windows {
	    set jprefs(inboxPath) [file join $prefs(prefsDir) Inbox.tcl]
	}
	unix {
	    set jprefs(inboxPath) [file join $prefs(prefsDir) inbox.tcl]
	}
    }
}

# Generic ::Jabber:: stuff -----------------------------------------------------

# Jabber::InitWhiteboard --
#
#       Initialize jabber things for this specific whiteboard instance.

proc ::Jabber::InitWhiteboard {wtop} {
    variable jstate
    
    set jstate($wtop,doSend) 0
    # The current receiver of our messages. 'textvariable' in UI entry.
    set jstate($wtop,tojid) ""
    # Identical to 'tojid' for standard chats, but a list of jid's
    # with /nick for groupchat's.
}

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
    
    # Make the roster object.
    set jstate(roster) [::roster::roster ::Jabber::Roster::PushProc]
    
    # Make the browse object.
    set jstate(browse) [::browse::browse ::Jabber::Browse::Callback]
    
    # Check if we need to set any auto away options.
    set opts {}
    if {$jprefs(autoaway) || $jprefs(xautoaway)} {
	foreach name {autoaway xautoaway awaymin xawaymin awaymsg xawaymsg} {
	    lappend opts -$name $jprefs($name)
	}
    }
    
    # Add the three element callbacks.
    lappend opts -iqcommand ::Jabber::IqCallback  \
      -messagecommand ::Jabber::MessageCallback   \
      -presencecommand ::Jabber::PresenceCallback

    # Make an instance of jabberlib and fill in our roster object.
    set jstate(jlib) [eval {
	::jlib::new $jstate(roster) ::Jabber::ClientProc  \
	  -browsename $jstate(browse)} $opts]
    
    # Set the priority order of groupchat protocols.
    $jstate(jlib) setgroupchatpriority [list $jprefs(prefgchatproto) "gc-1.0"]
      
    if {[string equal $prefs(protocol) "jabber"]} {
	
	# Make the combined window.
	if {1 || $jstate(rostBrowseVis)} {
	    ::Jabber::UI::Show $wDlgs(jrostbro)
	} else {
	    ::Jabber::UI::Build $wDlgs(jrostbro)
	    wm withdraw $wDlgs(jrostbro)
	}
    }
    
    # Take care of things like translating any old version mailbox etc.
    ::Jabber::MailBox::Init
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
    
    ::Jabber::Debug 2 "::Jabber::IqCallback type=$type, args='$args'"
    
    array set attrArr $args
    set xmlns [wrapper::getattribute $attrArr(-query) xmlns]
    set stat 1
    
    switch -- $type {
	result {
	    # Unhandled result callback?
	}
	get {
	    
	    # jabber:iq:time and jabber:iq:last handled in jabberlib.
	    switch -- $xmlns {
		jabber:iq:version {
		    set stat [eval {::Jabber::ParseGetVersion} $args]
		}
		jabber:iq:browse {
		    set stat [eval {::Jabber::ParseGetBrowse} $args]
		}
		default {
		    set stat 0
		}
	    }	    
	}
	set {
	    switch -- $xmlns {
		jabber:iq:oob {
		    eval {::Jabber::OOB::ParseSet $attrArr(-from)  \
		      $attrArr(-query)} $args
		}
		default {

		}
	    }	    
	}
	error {
	    # Unhandled error callback?
	}
    }
    return $stat
}

# ::Jabber::MessageCallback --
#
#       Registered callback proc for <message> elements.
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
    
    ::Jabber::Debug 2 "::Jabber::MessageCallback type=$type, args='$args'"
    
    array set attrArr {-body ""}
    array set attrArr $args
    
    set from $attrArr(-from)
    
    # Check if any blockers.
    if {$jprefs(block,notinrost) && ($type == "normal")} {
	
	# Reject if not in roster.
	set allUsers [$jstate(roster) getusers]
	if {[lsearch -exact $allUsers $from] < 0} {
	    puts "Rejected message from: $from"
	    return
	}
    }
    if {[llength $jprefs(block,list)] > 0} {
	foreach blkjid $jprefs(block,list) {
	    if {[string match $blkjid $from]} {
		puts "Rejected message from: $from"
		return
	    }
	}
    }
    
    # We must check if there is an error element sent along with the
    # body element. In that case the body element shall not be processed.
    if {[string equal $type "error"] && [info exists attrArr(-error)]} {
	set errcode [lindex $attrArr(-error) 0]
	set errmsg [lindex $attrArr(-error) 1]
	
	tk_messageBox -title [::msgcat::mc Error] -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrsend $attrArr(-from) $errcode $errmsg]]  \
	  -icon error -type ok		
    } else {
	
	# Check if we've got an <x xmlns='coccinella:wb'><raw> element...
	set haveCoccinellaNS 0
	set rawElemList {}
	if {[info exists attrArr(-x)]} {
	    foreach xlist $attrArr(-x) {
		
		# Take each <x> element in turn.
		foreach {xtag xattrlist xempty xchdata xsub} $xlist break
		array set xattrArr $xattrlist
		if {![info exists xattrArr(xmlns)]} {
		    continue
		}
		switch -- $xattrArr(xmlns) {
		    "jabber:x:coccinella" - "coccinella:wb" {
			set haveCoccinellaNS 1
			foreach xsubtag $xsub {
			    if {[string equal [lindex $xsubtag 0] "raw"]} {
				lappend rawElemList [lindex $xsubtag 3]
			    }
			}
		    }
		    "jabber:x:conference" {
			
			# Invitation for the conference (undocumented).
		    }
		    "http://jabber.org/protocol/muc#user" {
			::Jabber::MUC::MUCMessage $from $xlist
		    }
		}
	    }
	}
		
	# If a room message sent from us we don't want to duplicate it.
	# Whiteboard only.
	set doShow 1
	if {$haveCoccinellaNS} {
	    if {[string equal $type "groupchat"]} {
		if {[regexp {^(.+@[^/]+)(/(.*))?} $attrArr(-from) match roomJid x]} {
		    foreach {meHash nick}  \
		      [$jstate(jlib) service hashandnick $roomJid] break
		    if {[string equal $meHash $attrArr(-from)]} {
			set doShow 0
		    }
		}
	    }
	}
	
	# Send message to dispatcher for 'type' and whiteboard.
	set msgArgs $args
	if {$doShow && $haveCoccinellaNS} {
	    lappend msgArgs -whiteboard $rawElemList
	}
	
	# Interpret this as an ordinary jabber message element.
	eval {::Jabber::MessageDispatcher $type $attrArr(-body)} $msgArgs    
    }
}

# ::Jabber::MessageDispatcher --
#
#       Dispatch a jabber message to either the "normal" dialog, chat window,
#       or groupchat window.
#       
# Arguments:
#       type        message type attribute
#       body        the <body> element. Empty if have -whiteboard.
#       args        -type, -from, -whiteboard, -x, -thread
#       
# Results:
#       dispatch procedure called.

proc ::Jabber::MessageDispatcher {type body args} {
    
    set iswb 0
    if {[lsearch -exact $args "-whiteboard"] >= 0} {
	set iswb 1
    }
    
    switch -- $type {
	chat {
	    if {$iswb} {
		eval {::Jabber::WB::ChatMsg} $args
	    } else {
		eval {::Jabber::Chat::GotMsg $body} $args
	    }	    
	}
	groupchat {
	    if {$iswb} {
		eval {::Jabber::WB::GroupChatMsg} $args
	    } else {
		eval {::Jabber::GroupChat::GotMsg $body} $args
	    }	    
	}
	default {
	
	    # Normal message. Handles whiteboard stuff as well.
	    eval {::Jabber::DispatchNormalMessage $body $iswb} $args
	}
    }
}

# ::Jabber::DispatchNormalMessage --
# 
#       Take care of commands that must be responded to, and forward rest
#       to inbox.

proc ::Jabber::DispatchNormalMessage {body iswb args} {
    variable  jstate
    
    # We need to split up whiteboard commands (messages) that must be
    # handled immediately and those destined for drawing etc. 
    if {$iswb} {
	array set argsArr $args
	set restCmds {}
	foreach raw $argsArr(-whiteboard) {
	    switch -glob -- $raw {
		"GET IP:*" {
		    if {[regexp {^GET IP: +([^ ]+)$} $raw m id]} {
			::Jabber::PutIPnumber $argsArr(-from) $id
		    }
		}
		"PUT IP:*" {
			
		    # We have got the requested ip number from the client.
		    if {[regexp {^PUT IP: +([^ ]+) +([^ ]+)$} $raw m id ip]} {
			::Jabber::GetIPCallback $argsArr(-from) $id $ip
		    }		
		}	
		"IDENTITY:*" - "IPS CONNECTED:*" - "CLIENT:*" -  \
		  "DISCONNECTED:*" - "RESIZE:*" {
		    
		    # Junk.
		}
		default {
		    lappend restCmds $raw
		}
	    }
	}
	if {[llength $restCmds] > 0} {
	    set argsArr(-whiteboard) $restCmds
	    eval {::Jabber::MailBox::GotMsg $body} [array get argsArr]
	}
    } else {
	eval {::Jabber::MailBox::GotMsg $body} $args
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
    variable jerror
    
    ::Jabber::Debug 2 "::Jabber::PresenceCallback type=$type, args='$args'"
    
    array set attrArr $args
    set from $attrArr(-from)
    
    switch -- $type {
	subscribe {
	    
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
		    set msg [::msgcat::mc jamessautoaccepted $from]
		}
		reject {
		    $jstate(jlib) send_presence -to $from -type "unsubscribed"
		    set msg [::msgcat::mc jamessautoreject $from]
		}
		ask {
		    eval {::Jabber::Subscribe::Subscribe $wDlgs(jsubsc) $from} $args
		}
	    }
	    if {$msg != ""} {
		tk_messageBox -title [::msgcat::mc Info] -icon info -type ok \
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
		set msg [::msgcat::mc jamessautosubs $from]
		tk_messageBox -title [::msgcat::mc Info] -icon info -type ok \
		  -message [FormatTextForMessageBox $msg]			  
	    }
	}
	subscribed {
	    tk_messageBox -title [::msgcat::mc Subscribed] -icon info -type ok  \
	      -message [FormatTextForMessageBox [::msgcat::mc jamessallowsub $from]]
	}
	unsubscribe {	    
	    if {$jprefs(rost,rmIfUnsub)} {
		
		# Remove completely from our roster.
		$jstate(jlib) roster_remove $from ::Jabber::Roster::PushProc
		tk_messageBox -title [::msgcat::mc Unsubscribe] \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox [::msgcat::mc jamessunsub $from]]
	    } else {
		
		$jstate(jlib) send_presence -to $from -type "unsubscribed"
		tk_messageBox -title [::msgcat::mc Unsubscribe] -icon info -type ok  \
		  -message [FormatTextForMessageBox [::msgcat::mc jamessunsubpres $from]]
		
		# If there is any subscription to this jid's presence.
		set sub [$jstate(roster) getsubscription $from]
		if {[string equal $sub "both"] ||  \
		  [string equal $sub "to"]} {
		    
		    set ans [tk_messageBox -title [::msgcat::mc Unsubscribed]  \
		      -icon question -type yesno -default yes \
		      -message [FormatTextForMessageBox  \
		      [::msgcat::mc jamessunsubask $from $from]]]
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
		set msg "Failed making a subscription to $from."
		if {[info exists attrArr(-status)]} {
		    append msg " Status message: $attrArr(-status)"
		}
		tk_messageBox -title "Subscription Failed"  \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox $msg]
		if {$jprefs(rost,rmIfUnsub)} {
		
		    # Remove completely from our roster.
		    $jstate(jlib) roster_remove $from ::Jabber::Roster::PushProc
		}
	    } else {		
		tk_messageBox -title [::msgcat::mc Unsubscribed]  \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox  \
		  [::msgcat::mc jamessunsubscribed $from]]
	    }
	}
	error {
	    foreach {errcode errmsg} $attrArr(-error) break		
	    set msg [::msgcat::mc jamesserrpres $errcode $errmsg]
	    if {$prefs(talkative)} {
		tk_messageBox -icon error -type ok  \
		  -title [::msgcat::mc {Presence Error}] \
		  -message [FormatTextForMessageBox $msg]	
	    } else {
		lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
		  $from $msg]
	    }
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
    
    ::Jabber::Debug 2 "::Jabber::ClientProc: jlibName=$jlibName, what=$what, args='$args'"
    
    # For each 'what', split the argument list into the proper arguments,
    # and make the necessary calls.
    array set attrArr $args
    
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
	    ::Jabber::DoCloseClientConnection $jstate(ipNum)
	    
	    tk_messageBox -icon error -type ok  \
	      -message [::msgcat::mc jamessconnbroken]
	}
	away - xaway {
	    
	    set tm [clock format [clock seconds] -format "%H:%M:%S"]
	    set ans [tk_messageBox -icon info -type yesno -default yes \
	      -message [FormatTextForMessageBox \
	      [::msgcat::mc jamessautoawayset $tm]]
	    if {$ans == "yes"} {
		::Jabber::SetStatus available
	    }
	}
	xmlerror {
	    
	    # XML parsing error.
	    # Disconnect. This should reset both wrapper and XML parser!
	    ::Jabber::DoCloseClientConnection $jstate(ipNum)
	    if {[info exists attrArr(-errormsg)]} {
		set msg "Receieved a fatal XML parsing error:\
		  $attrArr(-errormsg). The connection is closed down."
	    } else {
		set msg {Receieved a fatal XML parsing error.\
		  The connection is closed down.}
	    }
	    tk_messageBox -title [::msgcat::mc {Fatal Error}] -icon error -type ok \
	      -message [FormatTextForMessageBox $msg]
	}
	networkerror {
	    
	    # Disconnect. This should reset both wrapper and XML parser!
	    ::Jabber::DoCloseClientConnection $jstate(ipNum)
	    tk_messageBox -title [::msgcat::mc {Network Error}] \
	      -message [FormatTextForMessageBox $attrArr(-body)] \
	      -icon error -type ok	    
	}
    }
}

proc ::Jabber::IsConnected { } {
    variable jserver
    return [expr [string length $jserver(this)] == 0 ? 0 : 1]
}

# Jabber::InvokeRosterCmd, InvokeBrowseCmd --
# 
#       Access functions for invoking these commands from the outside.

proc ::Jabber::InvokeRosterCmd {args}  {
    variable jstate
    
    eval {$jstate(roster)} $args
}

proc ::Jabber::InvokeBrowseCmd {args}  {
    variable jstate
    
    eval {$jstate(browse)} $args
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
	    if {$jstate(debug) == 0} {
		console hide
	    }
	}
	jlib::setdebug 0
    }
}

# Jabber::ErrorLogDlg

proc ::Jabber::ErrorLogDlg {w} {
    global  this sysFont
    
    variable jerror

    if {[winfo exists $w]} {
	raise $w
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w {Error Log (noncriticals)}
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Text.
    set wtxt $w.frall.frtxt
    pack [frame $wtxt] -side top -fill both -expand 1 -padx 4 -pady 4
    set wtext $wtxt.text
    set wysc $wtxt.ysc
    text $wtext -height 12 -width 48 -font $sysFont(s) -wrap word \
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
    pack [button $frbot.btset -text [::msgcat::mc Close] -width 8 \
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
#       type:       "error" or "ok".
#       thequery:   if type="error", this is a list {errcode errmsg},
#                   else it is the query element as a xml list structure.
#       
# Results:
#       none.

proc ::Jabber::IqSetGetCallback {method jlibName type theQuery} {    
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::IqSetGetCallback, method=$method, type=$type,\
	  theQuery='$theQuery'"
	
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $theQuery break
	switch -- $method {
	    default {
		set msg "Found an error for $method with code $errcode,\
		  and with message: $errmsg"
	    }
	}
	tk_messageBox -icon error -type ok -title [::msgcat::mc Error] -message \
	  [FormatTextForMessageBox $msg]
    }
}

# Jabber::SendWhiteboardMessage --
#
#       This is just a shortcut for sending a message. Practical in the
#       whiteboard since it hides the internal jabber vars.
#       
# Arguments:
#       wtop
#       msg
#       args        ?-key value ...?
#                   -force 0|1   (D=0) override doSend checkbutton?
#       
# Results:
#       none.

proc ::Jabber::SendWhiteboardMessage {wtop msg args} {
    variable jstate
    
    array set opts {-force 0}
    array set opts $args
    set tojid $jstate($wtop,tojid)
    
    # Here we shall decide the 'type' of message sent (normal, chat, groupchat)
    # depending on the type of whiteboard (via wtop).
    set argsList [::Jabber::SendWhiteboardArgs $wtop]
    
    if {$jstate($wtop,doSend) || $opts(-force)} {
	if {[::Jabber::VerifyJIDWhiteboard $wtop]} {
	    eval {::Jabber::SendMessage $tojid $msg} $argsList
	} else {
	    
	    # Perhaps we should give some aid here; set focus?
	}
    }
}

# Jabber::SendWhiteboardMessageList --
#
#       As above but for a list of commands.

proc ::Jabber::SendWhiteboardMessageList {wtop msgList args} {
    variable jstate
    
    array set opts {-force 0}
    array set opts $args
    set tojid $jstate($wtop,tojid)

    set argsList [::Jabber::SendWhiteboardArgs $wtop]
    if {$jstate($wtop,doSend) || $opts(-force)} {
	if {[::Jabber::VerifyJIDWhiteboard $wtop]} {
	    eval {::Jabber::SendMessageList $tojid $msgList} $argsList
	} else {
	    
	    # Perhaps we should give some aid here; set focus?
	}
    }
}

proc ::Jabber::SendWhiteboardArgs {wtop} {

    set argsList {}
    set type [::UI::GetJabberType $wtop]
    if {[llength $type] > 0} {
	lappend argsList -type $type
	if {[string equal $type "chat"]} {
		lappend argsList -thread [::UI::GetJabberChatThread $wtop]
	}
    }
    return $argsList
}

# Jabber::SendMessage --
#
#       Sends a message, typically in an <x xmlns='coccinella:wb'><raw> element.
#       
# Arguments:
#       jid
#       msg
#       args    ?-key value? list to use for 'send_message'.
#       
# Results:
#       none.

proc ::Jabber::SendMessage {jid msg args} {    
    variable jstate
    
    # Form an <x xmlns='coccinella:wb'><raw> element in message.
    set subx [list [wrapper::createtag "raw" -chdata $msg]]
    set xlist [list [wrapper::createtag x -attrlist  \
      {xmlns coccinella:wb} -subtags $subx]]
    if {[catch {
	eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
    } err]} {
	::Jabber::DoCloseClientConnection $jstate(ipNum)
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    }
}

# Jabber::SendMessageList --
#
#       As above but for a list of commands.

proc ::Jabber::SendMessageList {jid msgList args} {
    variable jstate
    
    # Form <x xmlns='coccinella:wb'> element with any number of <raw>
    # elements as childs.
    set subx {}
    foreach msg $msgList {
	lappend subx [wrapper::createtag "raw" -chdata $msg]
    }
    set xlist [list [wrapper::createtag x -attrlist  \
      {xmlns coccinella:wb} -subtags $subx]]
    if {[catch {
	eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
    } err]} {
	::Jabber::DoCloseClientConnection $jstate(ipNum)
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    }
}

# Jabber::DoSendCanvas --
# 
#       Wrapper for ::UserActions::DoSendCanvas.

proc ::Jabber::DoSendCanvas {wtop} {
    global  prefs
    variable jstate

    set wtoplevel [::UI::GetToplevel $wtop]
    set jid $jstate($wtop,tojid)

    if {[::Jabber::IsWellFormedJID $jid]} {
	
	# The Classic mac can't run the http server!
	if {!$prefs(haveHttpd)} {
	    set ans [tk_messageBox -icon warning -type yesno  \
	      -parent $wtoplevel  \
	      -message [FormatTextForMessageBox "The Classic Mac can't run\
	      the internal http server which is needed for transporting any\
	      images etc. in this message.\
	      Do you want to send it anyway?"]]
	    if {$ans == "no"} {
		return
	    }
	}
	
	# If user not online no files may be sent off.
	if {![$jstate(roster) isavailable $jid]} {
	    set ans [tk_messageBox -icon warning -type yesno  \
	      -parent $wtoplevel  \
	      -message [FormatTextForMessageBox "The user you are sending to,\
	      \"$jid\", is not online, and if this message contains any images\
	      or other similar entities, this user will not get them unless\
	      you happen to be online while this message is being read.\
	      Do you want to send it anyway?"]]
	    if {$ans == "no"} {
		return
	    }
	}
	::UserActions::DoSendCanvas $wtop
	::UI::CloseMain $wtop
    } else {
	tk_messageBox -icon warning -type ok -parent $wtoplevel -message \
	  [FormatTextForMessageBox [::msgcat::mc jamessinvalidjid]]
    }
}

# Jabber::UpdateAutoAwaySettings --
#
#       If changed present auto away settings, may need to configure
#       our jabber object.

proc ::Jabber::UpdateAutoAwaySettings { } {    
    variable jstate
    variable jprefs
    
    array set oldopts [$jstate(jlib) config]
    set reconfig 0
    foreach name {autoaway xautoaway awaymin xawaymin} {
	if {$oldopts(-$name) != $jprefs($name)} {
	    set reconfig 1
	    break
	}
    }
    if {$reconfig} {
	set opts {}
	if {$jprefs(autoaway) || $jprefs(xautoaway)} {
	    foreach name {autoaway xautoaway awaymin xawaymin awaymsg xawaymsg} {
		lappend opts -$name $jprefs($name)
	    }
	}
	eval {$jstate(jlib) config} $opts
    }
}

# Jabber::DoCloseClientConnection --
#
#       Handle closing down the client side connection (the 'to' part).
#       Try to be silent if called as a response to a server shutdown.
#       
# Arguments:
#       ipNum     the ip number.
#       args      -status, 
#       
# Results:
#       none

proc ::Jabber::DoCloseClientConnection {ipNum args} {
    global  prefs
        
    variable jstate
    variable jserver
    variable jprefs
    
    ::Jabber::Debug 2 "::Jabber::DoCloseClientConnection ipNum=$ipNum"
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
    
    # Disable all buttons in groupchat windows.
    ::Jabber::GroupChat::Logout
    
    # Do the actual closing.
    #       There is a potential problem if called from within a xml parser 
    #       callback which makes the subsequent parsing to fail. (after idle?)
    after idle $jstate(jlib) disconnect
    
    # Update the communication frame; remove connection 'to'.
    if {$prefs(jabberCommFrame)} {
	::UI::ConfigureAllJabberEntries $ipNum -netstate "disconnect"
    }
    ::Jabber::UI::SetStatusMessage "Logged out"

    # Multiinstance whiteboard UI stuff.
    foreach w [::UI::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]
	#::UI::SetStatusMessage $wtop [::msgcat::mc jaservclosed]

	# If no more connections left, make menus consistent.
	::UI::FixMenusWhen $wtop "disconnect"
    }
    ::Network::RegisterIP $ipNum "none"
    ::Jabber::Roster::SetUIWhen "disconnect"
    ::Jabber::UI::FixUIWhen "disconnect"
    ::Jabber::UI::WhenSetStatus "unavailable"
    if {[lsearch [::Jabber::UI::Pages] "Browser"] >= 0} {
	::Jabber::Browse::SetUIWhen "disconnect"
    }
    
    # Be sure to kill the wave; could end up here when failing to connect.
    ::Jabber::UI::StartStopAnimatedWave 0
    
    # Clear roster and browse windows.
    $jstate(roster) reset
    if {$jprefs(rost,clrLogout)} {
	::Jabber::Roster::Clear
    }
    if {[lsearch [::Jabber::UI::Pages] "Browser"] >= 0} {
	::Jabber::Browse::Clear
    }
    ::Jabber::UI::LogoutClear
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
	    ::Jabber::SetStatus unavailable
	    #eval {$jstate(jlib) send_presence -type unavailable} $opts
	}
	
	# Do the actual closing.
	#       There is a potential problem if called from within a xml parser 
	#       callback which makes the subsequent parsing to fail. (after idle?)
	$jstate(jlib) disconnect
    }
    
    # Either save inbox or delete.
    ::Jabber::MailBox::Exit
}

# Jabber::BuildJabberEntry --
#
#       A utility procedure to build a persistant jabber entry.
#       Used to hide jabber stuff away from ::UI

proc ::Jabber::BuildJabberEntry {wtop args} {
    
    eval {::UI::BuildJabberEntry $wtop  \
      -servervariable ::Jabber::jserver(this)  \
      -jidvariable ::Jabber::jstate($wtop,tojid) \
      -dosendvariable ::Jabber::jstate($wtop,doSend)} $args
      
    eval {::Jabber::ConfigureJabberEntry $wtop} $args
}

# Jabber::ConfigureJabberEntry --
#
#       A utility procedure to configure the jabber entry.
#       Used to hide jabber stuff away from ::UI

proc ::Jabber::ConfigureJabberEntry {wtop args} {
    variable jstate

    Debug 2 "::Jabber::ConfigureJabberEntry wtop=$wtop args='$args'"
    foreach {key value} $args {
    	switch -- $key {
    	    -jid {
    	    	set jstate($wtop,tojid) $value
	    }

	}
    }
}

# Jabber::IsWellFormedJID --
#
#       Is this a well formed Jabber ID?. What abot the resource (/home) part?
#       
# Arguments:
#       jid     Jabber ID, such as 'matben@athlon.se', if well formed.
#       
# Results:
#       boolean

proc ::Jabber::IsWellFormedJID {jid args} {    
    variable jprefs
    
    array set argsArr {
	-type   user
    }
    array set argsArr $args
    
    switch -- $argsArr(-type) {
	user {
	    if {[regexp {(.+)@([^/]+)(/(.*))?} $jid match name host junk res]} {
		if {[regexp $jprefs(invalsExp) $name match junk]} {
		    return 0
		} elseif {[regexp $jprefs(invalsExp) $host match junk]} {
		    return 0
		}
		return 1
	    } else {
		return 0
	    }
	}
	any {
	    
	    # Be sure to remove any separators @ and /.
	    regsub -all / $jid "" jidStrip
	    regsub -all @ $jidStrip "" jidStrip
	    if {[regexp $jprefs(invalsExp) $jidStrip match]} {
		return 0
	    } else {
		return 1
	    }
	}
    }
}

# Jabber::ValidateJIDChars --
#
#       Validate entry for username etc.
#       
# Arguments:
#       str     username etc.
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::ValidateJIDChars {str} {    
    variable jprefs

    if {[regexp $jprefs(invalsExp) $str match junk]} {
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

# Jabber::SetStatus --
#
#       Sends presence status information.
#       
# Arguments:
#       type        any of 'available', 'unavailable', 'invisible',
#                   'away', 'dnd', 'xa'.
#       to          (optional) sets any to='jid' attribute.
#       
# Results:
#       None.

proc ::Jabber::SetStatus {type {to {}}} {    
    variable jprefs
    variable jstate
    
    if {$to != ""} {
	set toArgs "-to $to"
    } else {
	set toArgs {}
	::Jabber::UI::WhenSetStatus $type
    }
    
    # Trap network errors.
    if {[catch {
	switch -- $type {
	    available - unavailable - invisible {
		eval {$jstate(jlib) send_presence -type $type} $toArgs
	    }
	    away - dnd - xa {
		eval {$jstate(jlib) send_presence -type "available"}  \
		  -show $type $toArgs
	    }
	}	
    } err]} {
	
	# Close down?	
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    }
}

# Jabber::SetStatusWithMessage --
#
#       Dialog for setting user's status with message.
#       
# Arguments:
#       w
#       
# Results:
#       "cancel" or "set".

proc ::Jabber::SetStatusWithMessage {w} {
    global  this sysFont
    
    variable finishedStat
    variable show
    variable wtext
    variable jprefs
    variable jstate

    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc {Set Status}]
    set finishedStat -1
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Top frame.
    set frtop $w.frall.frtop
    set fr [LabeledFrame2 $frtop [::msgcat::mc {My Status}]]
    pack $frtop -side top -fill x -padx 4 -pady 4
    foreach val {available chat away xa dnd invisible} {
	radiobutton ${fr}.${val} -text [::msgcat::mc jastat${val}]  \
	  -variable "[namespace current]::show" -value $val
	grid ${fr}.${val} -sticky w -padx 12 -pady 3
    }
    
    # Set present status.
    set show $jstate(status)
    
    pack [label $w.frall.lbl -text "[::msgcat::mc {Status message}]:" \
      -font $sysFont(sb)]  \
      -side top -anchor w -padx 6 -pady 0
    set wtext $w.frall.txt
    text $wtext -height 4 -width 36 -font $sysFont(s) -wrap word \
      -borderwidth 1 -relief sunken
    pack $wtext -expand 1 -fill both -padx 6 -pady 4    
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btset -text [::msgcat::mc Set] -default active -width 8 \
      -command [list [namespace current]::BtSetStatus $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
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
    if {[string length $allText]} {
	set statusOpt [list -status $allText]
    }  
    
    # Set present status.
    set jstate(status) $show
    switch -- $show {
	invisible {
	    eval {$jstate(jlib) send_presence -type "invisible" -show $show} \
	      $statusOpt
	}
	default {
	    eval {$jstate(jlib) send_presence -type "available" -show $show} \
	      $statusOpt
	}
    }
    ::Jabber::UI::WhenSetStatus $show
    
    set finishedStat 1
    destroy $w
}

# Jabber::GetIPnumber / PutIPnumber --
#
#       Utilites to put/get ip numbers from clients.
#
# Arguments:
#       jid:        fully qualified "username@host/resource".
#       cmd:        (optional) callback command when gets ip number.
#       
# Results:
#       none.

proc ::Jabber::GetIPnumber {jid {cmd {}}} {    
    variable jstate
    variable getcmd
    variable getid
    variable jidToIP

    ::Jabber::Debug 2 "::Jabber::GetIPnumber:: jid=$jid, cmd='$cmd'"
    
    if {[string length $cmd]} {
	set getcmd($getid) $cmd
	
	# What shall we do when we already have the IP number?
	if {[info exists jidToIP($jid)]} {
	    ::Jabber::GetIPCallback $jid $getid $jidToIP($jid)
	} else {
	    ::Jabber::SendMessage $jid "GET IP: $getid"
	}
    }
    incr getid
}

# Jabber::GetIPCallback --
#
#       This proc gets called when a requested ip number is received
#       by our server.
#
# Arguments:
#       fromjid     fully qualified  "username@host/resource"
#       id
#       ip
#       
# Results:
#       Any registered callback proc is eval'ed.

proc ::Jabber::GetIPCallback {fromjid id ip} {    
    variable jstate
    variable getcmd
    variable jidToIP

    ::Jabber::Debug 2 "::Jabber::GetIPCallback: fromjid=$fromjid, id=$id, ip=$ip"

    set jidToIP($fromjid) $ip
    if {[info exists getcmd($id)]} {
	::Jabber::Debug 2 "   getcmd($id)='$getcmd($id)'"
	eval $getcmd($id) $fromjid
	unset getcmd($id)
    }
}

proc ::Jabber::PutIPnumber {jid id} {
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::PutIPnumber:: jid=$jid, id=$id"
    
    set ip [::Network::GetThisOutsideIPAddress]
    ::Jabber::SendMessage $jid "PUT IP: $id $ip"
}

# Jabber::PutFileAndSchedule --
# 
#       Handles everything needed to put a file to the jid's corresponding
#       to the 'wtop'. Users that we haven't got ip number from are scheduled
#       for delivery as a callback.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       fileName    the path to the file to be put.
#       'optList'   a list of 'key: value' pairs, resembling the html 
#                   protocol for getting files, but where most keys correspond
#                   to a valid "canvas create" option.
#       
# Results:
#       none.

proc ::Jabber::PutFileAndSchedule {wtop fileName optList} {    
    variable jidToIP
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::PutFileAndSchedule: \
      wtop=$wtop, fileName=$fileName, optList='$optList'"
    
    # Before doing anything check that the Send checkbutton is on. ???
    if {!$jstate($wtop,doSend)} {
    	::Jabber::Debug 2 "    doSend=0 => return"
	return
    }
    
    # Verify that jid is well formed.
    if {![::Jabber::VerifyJIDWhiteboard $wtop]} {
	return
    }
    
    # This must never fail (application/octet-stream as fallback).
    set mime [::Types::GetMimeTypeForFileName $fileName]
    
    # Need to add jabber specific info to the 'optList', such as
    # to:, from:, type:, thread: etc.
    # 
    # -type and 'tojid' shall never be in conflict???
    foreach {key value} [::UI::ConfigureMain $wtop] {
	switch -- $key {
	    -type - -thread {
		lappend optList [string trimleft $key -]: $value
	    }
	}
    }
    
    set tojid $jstate($wtop,tojid)
    set isRoom 0
    
    if {[regexp {^(.+)@([^/]+)/([^/]*)} $tojid match name host res]} {
	
	# The 'tojid' is already complete with resource.
	set allJid3 $tojid
    	lappend optList from: $jstate(mejidres)
    } else {
	
	# If 'tojid' is without a resource, it can be a room.
	if {[$jstate(jlib) service isroom $tojid]} {
	    set isRoom 1
	    set allJid3 [$jstate(jlib) service roomparticipants $tojid]
	    
	    # Exclude ourselves.
	    foreach {meRoomJid nick} [$jstate(jlib) service hashandnick $tojid] \
	      break
	    set ind [lsearch $allJid3 $meRoomJid]
	    if {$ind >= 0} {
		set allJid3 [lreplace $allJid3 $ind $ind]
	    }
	    
	    # Be sure to have our room jid and not the real one.
     	    lappend optList from: $meRoomJid
	} else {
	    
	    # Else put to resource with highest priority.
	    set res [$jstate(roster) gethighestresource $tojid]
	    if {$res == ""} {
		
		# This is someone we haven't got presence from.
		set allJid3 $tojid
	    } else {
		set allJid3 $tojid/$res
	    }
	    lappend optList from: $jstate(mejidres)
	}
    }
    
    ::Jabber::Debug 2 "   allJid3=$allJid3"
    
    # We shall put to all resources. Treat each in turn.
    foreach jid3 $allJid3 {
	
	# If we are in a room all must be available, else check.
	if {$isRoom} {
	    set avail 1
	} else {
	    set avail [$jstate(roster) isavailable $jid3]
	}
	
	# Each jid must get its own to: attribute.
	set optjidList [concat $optList to: $jid3]
	
	::Jabber::Debug 2 "   jid3=$jid3, avail=$avail"
	
	if {$avail} {
	    if {[info exists jidToIP($jid3)]} {
		
		# This one had already told us its ip number, good!
		::Jabber::PutFile $wtop $fileName $mime $optjidList $jid3
	    } else {
		
		# This jid is online but has not told us its ip number.
		# We need to get this jid's ip number and register the
		# PutFile as a callback when receiving this ip.
		::Jabber::GetIPnumber $jid3 \
		  [list ::Jabber::PutFile $wtop $fileName $mime $optjidList]
	    }
	} else {
	    
	    # We need to tell this jid to get this file from a server,
	    # possibly as an OOB http transfer.
	    array set optArr $optList
	    if {[info exists optArr(Get-Url:)]} {
		$jstate(jlib) oob_set $jid3 ::Jabber::OOB::SetCallback  \
		  $optArr(Get-Url:)  \
		  -desc {This file is part of a whiteboard conversation.\
		  You were not online when I opened this file}
	    } else {
		puts "   missing optArr(Get-Url:)"
	    }
	}
    }
        
    # This is an activity that may not be registered with jabberlib's auto away
    # functions, and must therefore schedule it here. ???????
    $jstate(jlib) schedule_auto_away
}

# Jabber::PutFile --
#
#       Puts the file to the given jid provided the client has
#       told us its ip number.
#       Calls '::PutFileIface::PutFile' to do the real work for us.
#
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       fileName    the path to the file to be put.
#       'optList'   a list of 'key: value' pairs, resembling the html 
#                   protocol for getting files, but where most keys correspond
#                   to a valid "canvas create" option.
#       jid         fully qualified  "username@host/resource"
#       
# Results:

proc ::Jabber::PutFile {wtop fileName mime optList jid} {
    global  prefs
    variable jidToIP
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::PutFile: fileName=$fileName, optList='$optList', jid=$jid"
 
    if {![info exists jidToIP($jid)]} {
	puts "::Jabber::PutFile: Houston, we have a problem. \
	  jidToIP($jid) not there"
	return
    }
    
    # Check first that the user has not closed the window since this
    # call may be async.
    if {$wtop == "."} {
	set win .
    } else {
	set win [string trimright $wtop "."]
    }    
    if {![winfo exists $win]} {
	return
    }
    
    # Get the remote (network) file name (no path, no uri encoding).
    set dstFile [::Types::GetFileTailAddSuffix $fileName]

    if {[catch {
	::putfile::put $fileName $jidToIP($jid) $prefs(remotePort)   \
	  -mimetype $mime -timeout $prefs(timeoutMillis)                   \
	  -optlist $optList -filetail $dstFile                       \
	  -progress ::PutFileIface::PutProgress                      \
	  -command [list ::PutFileIface::PutCommand $wtop]
    } tok]} {
	tk_messageBox -title [::msgcat::mc {File Transfer Error}]  \
	  -type ok -message $tok
    } else {
	::PutFileIface::RegisterPutSession $tok $wtop
    }
}

# Jabber::HandlePutRequest --
# 
#       Takes care of a PUT command from the server.
#       The problem is that we get a direct connection with
#       PUT/GET request outside the Jabber framework.

proc ::Jabber::HandlePutRequest {channel fileName optList} {
        
    # The whiteboard must exist!
    set wtop [::Jabber::WB::MakeWhiteboardExist $optList]
    
    # Be sure to strip off any path. (this(path))??? Mac bug for /file?
    set tail [file tail $fileName]
    ::GetFileIface::GetFile $wtop $channel $tail $optList
}

# Jabber::SetPrivateData --
#
#       Set ip & port of our two servers at out public space at the server
#       for others to fetch.
#       
# Arguments:
#       
# Results:
#       none.

proc ::Jabber::SetPrivateData { } {
    global  prefs
    
    variable jstate
    
    # Build tag and attributes lists to 'private_set'.
    set ip [::Network::GetThisOutsideIPAddress]
    $jstate(jlib) private_set "coccinella:public"     \
      [list ::Jabber::SetPrivateDataCallback private_set]   \
      -server [list $ip [list resource $jstate(meres)  \
      port $prefs(thisServPort)]]       \
      -httpd [list $ip [list resource $jstate(meres)   \
      port $prefs(httpdPort)]]
}

# Jabber::SetPrivateDataCallback --
#
#       Records if this was succesful or not. Be silent.

proc ::Jabber::SetPrivateDataCallback {jid jlibName what theQuery} {    
    variable jidPublic

    if {[string equal $what "error"]} {
	set jidPublic(haveit) 0
    } else {
	set jidPublic(haveit) 1
    }
}

# Jabber::GetPrivateData --
#
#       Gets ip & port of the two servers for the specified jid.
#       
# Arguments:
#       jid         get data from this jid.
#       
# Results:
#       shows window.

proc ::Jabber::GetPrivateData {jid} {
    variable jstate
    
    # Build tag and attributes lists to 'private_set'.
    $jstate(jlib) private_get {coccinella:public} {server httpd}  \
      [list ::Jabber::GetPrivateDataCallback $jid]
}

# Jabber::GetPrivateDataCallback --
#
#       Parses the callback when receiving the iq result (or error).

proc ::Jabber::GetPrivateDataCallback {jid jlibName what theQuery} {    
    variable jidPublic
    
    if {[string equal $what "error"]} {
	foreach {errcode errmsg} $theQuery {}
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrgetpublic $jid $errcode $errmsg]]
	return
    }
    
    # Parse the query element:
    # theQuery='{query {xmlns coccinella:public} 0 {} {
    #     {server {resource home port 8235} 0 192.168.0.4 {}} 
    #     {httpd {resource home port 8077} 0 192.168.0.4 {}}}}'
    set childList [lindex $theQuery 4]
    foreach {tag attrlist empty chdata c} $childList {
	foreach {name val} $attrlist {
	    set $name $val
	}
	set jidPublic($jid,$resource,$tag) $chdata
	foreach {name val} $attrlist {
	    if {[string equal $name "resource"]} {
		continue
	    }
	    
	    # Typically: jidPublic(matben@athlon.se,home,serverport).
	    set jidPublic($jid,$resource,$tag$name) $val
	}
    }
}

# Jabber::SetUserProfile --
#
#       Sets or replaces a user profile. Format:
#  jserver(profile,selected)  profile picked in user info
#  jserver(profile):          {$profile1 {$server1 $username $password $resource} \
#                              $profile2 {$server2 $username2 $password2 $resource2} ... }
#       
# Arguments:
#       profile     if empty, make a new unique profile, else, create this,
#                   possibly replace if exists already.
#       server      Jabber server name.
#       username
#       password
#       
# Results:
#       none.

proc ::Jabber::SetUserProfile {profile server username password {res {coccinella}}} {    
    variable jserver
    
    ::Jabber::Debug 2 "profile=$profile, s=$server, u=$username, p=$password, r=$res"

    # Be sure to sync jserver(all) first.
    set jserver(all) {}
    array set jserverArr $jserver(profile)
    foreach prof [array names jserverArr] {
	lappend jserver(all) $prof
    }
    
    # Create a new unique profile name.
    if {[string length $profile] == 0} {
	set profile $server

	# Make sure that 'profile' is unique.
	if {[lsearch -exact $jserver(all) $profile] >= 0} {
	    set i 2
	    set tmpprof $profile
	    set profile ${tmpprof}-${i}
	    while {[lsearch -exact $jserver(all) $profile] >= 0} {
		incr i
		set profile ${tmpprof}-${i}
	    }
	}
    }
    set jserverArr($profile) [list $server $username $password $res]
    set jserver(profile) [array get jserverArr]
    set jserver(profile,selected) $profile
    lappend jserver(all) $profile
    set jserver(all) [lsort -unique $jserver(all)]
    return ""
}

proc ::Jabber::GetAllWinGeom { } {
    
    set geomList {}
    set geomList [concat $geomList [::Jabber::GroupChat::GetWinGeom]]
    return $geomList
}

proc ::Jabber::GetAllPanePos { } {
    global  prefs wDlgs
            
    # Each proc below return any stored pane position, but returns empty if
    # dialog was never built.
    set paneList {}
    
    # Chat:
    set pos [::Jabber::Chat::GetPanePos]
    if {$pos == ""} {
	set pos [list $wDlgs(jchat) $prefs(paneGeom,$wDlgs(jchat))]
    }
    set paneList [concat $paneList $pos]
    
    # Mailbox:
    set pos [::Jabber::MailBox::GetPanePos]
    if {$pos == ""} {
	set pos [list $wDlgs(jinbox) $prefs(paneGeom,$wDlgs(jinbox))]
    }
    set paneList [concat $paneList $pos]
    
    # Groupchat:
    set pos [::Jabber::GroupChat::GetPanePos]
    if {$pos == ""} {
	set pos [list groupchatDlgVert $prefs(paneGeom,groupchatDlgVert) \
	  groupchatDlgHori $prefs(paneGeom,groupchatDlgHori)]
    }
    set paneList [concat $paneList $pos]
    
    return $paneList
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
#       jabber:x:delay stamp attribute or empty.

proc ::Jabber::GetAnyDelayElem {xlist} {
    
    set ans ""
    foreach xelem $xlist {
	foreach {tag attrlist empty chdata sub} $xelem break
	catch {unset attrArr}
	array set attrArr $attrlist
	if {[info exists attrArr(xmlns)] &&  \
	  [string equal $attrArr(xmlns) "jabber:x:delay"]} {
	    
	    # This is ISO 8601.
	    if {[info exists attrArr(stamp)]} {
		set ans $attrArr(stamp)
		break
	    }
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
    variable jerror

    if {[string equal $type "error"]} {
	set msg [::msgcat::mc jamesserrlastactive $from [lindex $subiq 1]]
	if {$silent} {
	    lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
	      $from $msg]	    
	} else {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox $msg]
	}
    } else {
	array set attrArr [lindex $subiq 1]
	if {![info exists attrArr(seconds)]} {
	    tk_messageBox -title [::msgcat::mc {Last Activity}] -icon info  \
	      -type ok -message [FormatTextForMessageBox \
	      [::msgcat::mc jamesserrnotimeinfo $from]]
	} else {
	    set secs [expr [clock seconds] - $attrArr(seconds)]
	    set uptime [clock format $secs -format "%a %b %d %H:%M:%S"]
	    if {[lindex $subiq 3] != ""} {
		set msg "The message: [lindex $subiq 3]"
	    } else {
		set msg {}
	    }
	    
	    # Time interpreted differently for different jid types.
	    if {$from != ""} {
		if {[regexp {^[^@]+@[^/]+/.*$} $from match]} {
		    set msg1 [::msgcat::mc jamesstimeused $from]
		} elseif {[regexp {^.+@[^/]+$} $from match]} {
		    set msg1 [::msgcat::mc jamesstimeconn $from]
		} else {
		    set msg1 [::msgcat::mc jamesstimeservstart $from]
		}
	    } else {
		set msg1 [::msgcat::mc jamessuptime]
	    }
	    tk_messageBox -title [::msgcat::mc {Last Activity}] -icon info  \
	      -type ok -message \
	      [FormatTextForMessageBox "$msg1 $uptime. $msg"]
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
    variable jerror

    if {[string equal $type "error"]} {
	if {$silent} {
	    lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
	      $from "We received an error when quering its time info.\
	      The error was: [lindex $subiq 1]"]	    
	} else {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox \
	      [::msgcat::mc jamesserrtime $from [lindex $subiq 1]]]
	}
    } else {
	
	# Display the cdata of <display>, or <utc>.
	foreach child [lindex $subiq 4] {
	    set tag [lindex $child 0]
	    set $tag [lindex $child 3]
	}
	if {[info exists display]} {
	    set msg $display
	} elseif {[info exists utc]} {
	    set msg $utc
	} elseif {[info exists tz]} {
	    set msg $tz
	} else {
	    set msg {unknown}
	}
	tk_messageBox -title [::msgcat::mc {Local Time}] -icon info -type ok -message \
	  [FormatTextForMessageBox [::msgcat::mc jamesslocaltime $from $msg]]
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
    global  sysFont prefs this
    
    variable jerror
    variable uidvers
    
    if {[string equal $type "error"]} {
	if {$silent} {
	    lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
	      $from [::msgcat::mc jamesserrvers $from [lindex $subiq 1]]]
	} else {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox \
	      [::msgcat::mc jamesserrvers $from [lindex $subiq 1]]]
	}
    } else {
	set w .jvers[incr uidvers]
	toplevel $w -background $prefs(bgColGeneral)
	if {[string match "mac*" $this(platform)]} {
	    eval $::macWindowStyle $w documentProc
	} else {

	}
	wm title $w [::msgcat::mc {Version Info}]
	pack [label $w.icon -bitmap info] -side left -anchor n -padx 10 -pady 10
	pack [label $w.msg -text [::msgcat::mc javersinfo $from] -font $sysFont(sb)] \
	  -side top -padx 8 -pady 4
	pack [frame $w.fr] -padx 10 -pady 4 -side top 
	set i 0
	foreach child [lindex $subiq 4] {
	    label $w.fr.l$i -font $sysFont(sb) -text "[lindex $child 0]:"
	    label $w.fr.lr$i -text [lindex $child 3]
	    grid $w.fr.l$i -column 0 -row $i -sticky e
	    grid $w.fr.lr$i -column 1 -row $i -sticky w
	    incr i
	}
	pack [button $w.ok -text [::msgcat::mc OK] -width 8 \
	  -command "destroy $w"] -side right -padx 10 -pady 8
	wm resizable $w 0 0
	bind $w <Return> "$w.ok invoke"
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
    foreach child [lindex $subiq 4] {
	set tag [lindex $child 0]
	set $tag [lindex $child 3]
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

proc ::Jabber::ParseGetVersion {args} {
    global  prefs tcl_platform
    variable jstate
    
    ::Jabber::Debug 2 "Jabber::ParseGetVersion args='$args'"
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    set os $tcl_platform(os)
    if {[info exists tcl_platform(osVersion)]} {
	append os " $tcl_platform(osVersion)"
    }
    set subtags [list  \
      [wrapper::createtag name -chdata "Coccinella"]  \
      [wrapper::createtag version  \
      -chdata $prefs(majorVers).$prefs(minorVers).$prefs(releaseVers)]  \
      [wrapper::createtag os -chdata $os] ]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist {xmlns jabber:iq:version}]
    if {[info exists argsArr(-from)]} {
	lappend opts -to $argsArr(-from)
    }
    eval {$jstate(jlib) send_iq "result" $xmllist} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}
    
# Jabber::ParseGetTime --
#
#       Respond to an incoming 'jabber:iq:time' get query.

proc ::Jabber::ParseGetTime {args} {
    global  prefs
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::ParseGetTime args='$args'"
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    set secs [clock seconds]
    set gmt [clock format $secs -format "%Y%m%dT%H:%M:%S" -gmt 1]
    set display [clock format $secs -gmt 1]
    set subtags [list  \
      [wrapper::createtag utc -chdata $gmt]  \
      [wrapper::createtag display -chdata $display]  \
      [wrapper::createtag tz -chdata GMT]]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist {xmlns jabber:iq:time}]
    if {[info exists argsArr(-from)]} {
	lappend opts -to $argsArr(-from)
    }
    eval {$jstate(jlib) send_iq "result" $xmllist} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}
        
# Jabber::ParseGetBrowse --
#
#       Respond to an incoming 'jabber:iq:browse' get query.
#       
# Results:
#       boolean (0/1) telling if this was handled or not.

proc ::Jabber::ParseGetBrowse {args} {
    global  prefs    
    variable jstate

    ::Jabber::Debug 2 "::Jabber::ParseGetBrowse: args='$args'"
    
    array set argsArr $args
    if {![info exists argsArr(-from)]} {
	return 0
    }
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }

    # List everything this client supports.
    set subtags [list  \
      [wrapper::createtag "ns" -chdata "jabber:client"]         \
      [wrapper::createtag "ns" -chdata "jabber:iq:autoupdate"]  \
      [wrapper::createtag "ns" -chdata "jabber:iq:browse"]      \
      [wrapper::createtag "ns" -chdata "jabber:iq:conference"]  \
      [wrapper::createtag "ns" -chdata "jabber:iq:last"]        \
      [wrapper::createtag "ns" -chdata "jabber:iq:oob"]         \
      [wrapper::createtag "ns" -chdata "jabber:iq:roster"]      \
      [wrapper::createtag "ns" -chdata "jabber:iq:time"]        \
      [wrapper::createtag "ns" -chdata "jabber:iq:version"]     \
      [wrapper::createtag "ns" -chdata "jabber:x:autoupdate"]   \
      [wrapper::createtag "ns" -chdata "jabber:x:data"]         \
      [wrapper::createtag "ns" -chdata "coccinella:public"]     \
      [wrapper::createtag "ns" -chdata "coccinella:wb"]]
    
    set attr [list xmlns jabber:iq:browse jid $jstate(mejidres)  \
      type client category user]
    set xmllist [wrapper::createtag "user" -subtags $subtags -attrlist $attr]
    eval {$jstate(jlib) send_iq "result" $xmllist -to $argsArr(-from)} $opts
    
    # Tell jlib's iq-handler that we handled the event.
    return 1
}

# Jabber::SetSendState --
#
#       Set from the checkbutton.

proc ::Jabber::SetSendState {wtop state} {    
    variable jstate

    set jstate($wtop,doSend) $state
}

proc ::Jabber::GetSendState {wtop} {    
    variable jstate

    return $jstate($wtop,doSend)
}

# The ::Jabber::WB:: namespace -------------------------------------------------

namespace eval ::Jabber::WB:: {
   
}

# Jabber::WB::NewWhiteboard --
#
#       Starts a new whiteboard session.
#       
# Arguments:
#       jid         2-tier jid with no /resource (room participants???)
#       args        -thread, -from, -to, -type, -x
#       
# Results:
#       $wtop; may create new toplevel whiteboard

proc ::Jabber::WB::NewWhiteboard {jid args} {
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::WB::NewWhiteboard jid=$jid, args='$args'"
    
    array set argsArr $args    
    
    # Make a fresh whiteboard window. Use any -type argument.
    # Note that the jid can belong to a room but we may still have a p2p chat.
    #    jid is room: groupchat live
    #    jid is ordinary available user: chat
    #    jid is ordinary but unavailable user: normal message
    set isRoom 0
    if {[info exists argsArr(-type)]} {
	if {[string equal $argsArr(-type) "groupchat"]} {
	    set isRoom 1
	}	
    } elseif {[$jstate(jlib) service isroom $jid]} {
	set isRoom 1
    }
    set isAvailable [$jstate(roster) isavailable $jid]
    
    ::Jabber::Debug 2 "    isRoom=$isRoom, isAvailable=$isAvailable"
    
    if {$isRoom} {
	
	# Must enter room in the usual way if not there already.
	set allRooms [$jstate(jlib) service allroomsin]
	::Jabber::Debug 3 "\tallRooms=$allRooms"
	
	if {[lsearch $allRooms $jid] < 0} {
	    set ans [::Jabber::GroupChat::EnterOrCreate \
	      enter -roomjid $jid -autoget 1]
	    if {$ans == "cancel"} {
		return
	    }
	}
	set roomName [$jstate(browse) getname $jid]    
	if {[llength $roomName]} {
	    set title "Groupchat room $roomName"
	} else {
	    set title "Groupchat room $jid"
	}
	set wbOpts [list -type groupchat -title $title -jid $jid \
	  -toentrystate disabled -sendbuttonstate disabled \
	  -serverentrystate disabled]
	set sendLive 1
    } elseif {$isAvailable} {
	if {[info exists argsArr(-thread)]} {
	    set threadID $argsArr(-thread)
	} else {
	    
	    # Make unique thread id.
	    set threadID [::sha1pure::sha1 "$jstate(mejid)[clock seconds]"]
	}
	set name [$jstate(roster) getname $jid]
	if {[string length $name]} {
	    set title "Chat with $name"
	} else {
	    set title "Chat with $jid"
	}
	set wbOpts [list -type chat -thread $threadID -title $title  \
	  -toentrystate disabled -jid $jid -sendbuttonstate disabled  \
	  -serverentrystate disabled]
	set sendLive 1
    } else {
	set name [$jstate(roster) getname $jid]
	if {[string length $name]} {
	    set title "Send Message to $name"
	} else {
	    set title "Send Message to $jid"
	}
	set wbOpts [list -type normal -title $title -jid $jid  \
	  -toentrystate disabled -serverentrystate disabled]
	set sendLive 0
    }
    
    set wtop [eval {::UI::NewMain} $wbOpts]
    set jstate($wtop,doSend) $sendLive
    
    return $wtop
}

# ::Jabber::WB::ChatMsg, GroupChatMsg --
# 
#       Handles incoming chat/groupchat message aimed for a whiteboard.
#       It may not exist, for instance, if we receive a new chat thread.
#       Then create a specific whiteboard for this chat/groupchat.
#       
# Arguments:
#       args        -from, -to, -type, -thread,...

proc ::Jabber::WB::ChatMsg {args} {    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    ::Jabber::Debug 2 "::Jabber::WB::ChatMsg args='$args'"
    
    set jid2 $argsArr(-from)
    regexp {^(.+@[^/]+)(/.*)?$} $argsArr(-from) match jid2 res

    # This one returns empty if not exists.
    set wtop [::UI::GetWtopFromJabberType "chat" $argsArr(-from)  \
      $argsArr(-thread)]
    if {$wtop == ""} {
	set wtop [eval {::Jabber::WB::NewWhiteboard $jid2} $args]
    }
    foreach line $argsArr(-whiteboard) {
	eval {ExecuteClientRequest $wtop $jstate(sock) ip port $line} $args
    }     
}

proc ::Jabber::WB::GroupChatMsg {args} {    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    ::Jabber::Debug 2 "::Jabber::WB::GroupChatMsg args='$args'"
    
    # The -from argument is either the room itself, or usually a user in
    # the room.
    if {![regexp {(^[^@]+@[^/]+)(/.*)?} $argsArr(-from) match roomjid]} {
	return -code error "The jid we got \"$argsArr(-from)\" was not well-formed!"
    }
    set wtop [::UI::GetWtopFromJabberType "groupchat" $roomjid]
    if {$wtop == ""} {
	set wtop [eval {::Jabber::WB::NewWhiteboard $roomjid} $args]
    }
    foreach line $argsArr(-whiteboard) {
	eval {ExecuteClientRequest $wtop $jstate(sock) ip port $line} $args
    } 
}

# Jabber::WB::MakeWhiteboardExist --
# 
#       Verifies that there exists a whiteboard for this message.
#       
# Arguments:
#       optList
#       
# Results:
#       $wtop; may create new toplevel whiteboard

proc ::Jabber::WB::MakeWhiteboardExist {optList} {

    ::Jabber::Debug 2 "::Jabber::WB::MakeWhiteboardExist"

    array set optArr $optList
    
    switch -- $optArr(type:) {
	chat {
	    set wtop [::UI::GetWtopFromJabberType chat $optArr(from:) \
	      $optArr(thread:)]
	    if {$wtop == ""} {
		set wtop [::Jabber::WB::NewWhiteboard $optArr(from:)  \
		  -thread $optArr(thread:)]
	    }
	}
	groupchat {
	    if {![regexp {(^[^@]+@[^/]+)(/.*)?} $optArr(from:) match roomjid]} {
		return -code error  \
		  "The jid we got \"$optArr(from:)\" was not well-formed!"
	    }
	    set wtop [::UI::GetWtopFromJabberType groupchat $optArr(from:)]
	    if {$wtop == ""} {
		set wtop [::Jabber::WB::NewWhiteboard $roomjid]
	    }
	}
	default {
	    # Normal message. Shall go in inbox ???????????
	    set wtop [::UI::GetWtopFromJabberType normal $optArr(from:)]
	}
    }
    return $wtop
}

# ::Jabber::WB::DispatchToImporter --
# 
#       Is called as a response to a GET file event. 
#       We've received a file that should be imported somewhere.
#       
# Arguments:
#       mime
#       optList
#       args        -file, -where; for importer proc.

proc ::Jabber::WB::DispatchToImporter {mime optList args} {
        
    ::Jabber::Debug 2 "::Jabber::WB::DispatchToImporter"

    array set optArr $optList

    # Creates WB if not exists.
    set wtop [::Jabber::WB::MakeWhiteboardExist $optList]

    switch -- $optArr(type:) {
	chat - groupchat {
	    set display 1
	}
	default {
	    set display 0
	}
    }
    
    if {$display && [::Plugins::HaveImporterForMime $mime]} {
	set wCan [::UI::GetCanvasFromWtop $wtop]
	eval {::ImageAndMovie::DoImport $wCan $optList} $args
    }
}

# The ::Jabber::UI:: namespace -------------------------------------------

namespace eval ::Jabber::UI:: {
    
    # Collection of useful and common widget paths.
    variable jwapp
}

proc ::Jabber::UI::Show {w args} {
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    if {[info exists argsArr(-visible)]} {
	set jstate(rostBrowseVis) $argsArr(-visible)
    }
    ::Jabber::Debug 2 "::Jabber::UI::Show w=$w, jstate(rostBrowseVis)=$jstate(rostBrowseVis)"

    if {$jstate(rostBrowseVis)} {
	if {[winfo exists $w]} {
	    wm deiconify $w
	} else {
	    ::Jabber::UI::Build $w
	}
    } else {
	catch {wm withdraw $w}
    }
}

# Jabber::UI::Build --
#
#       A combination tabbed window with roster/agents/browser...
#       Must be persistant since roster/browser etc. are built once.

proc ::Jabber::UI::Build {w} {
    global  this sysFont prefs wDlgs
    
    upvar ::UI::icons icons
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    variable jwapp

    if {[winfo exists $w]} {
	return
    }
    ::Jabber::Debug 2 "::Jabber::UI::Build w=$w"
    
    if {$w != "."} {
	toplevel $w -class RostServ
	if {[string match "mac*" $this(platform)]} {
	    eval $::macWindowStyle $w documentProc
	} else {
	    
	}
    }
    set jwapp(wtopRost) $w
    wm title $w "The Coccinella"
    wm protocol $w WM_DELETE_WINDOW [list ::Jabber::UI::CloseRoster $w]

    # Build minimal menu for Jabber stuff.
    set wmenu ${w}.menu
    set jwapp(wmenu) $wmenu
    menu $wmenu -tearoff 0
    if {[string match "mac*" $this(platform)] && $prefs(haveMenus)} {
	set haveAppleMenu 1
    } else {
	set haveAppleMenu 0
    }
    if {$haveAppleMenu} {
	::UI::NewMenu ${w}. ${wmenu}.apple {}      "main,apple" normal
    }
    ::UI::NewMenu ${w}. ${wmenu}.file    mFile     "rost,file"  normal
    if {[string match "mac*" $this(platform)]} {
	::UI::NewMenu ${w}. ${wmenu}.edit  mEdit   "min,edit"   normal
    }
    ::UI::NewMenu ${w}. ${wmenu}.jabber  mJabber   "rost,jabber" normal
    $w configure -menu $wmenu
        
    # Shortcut button part.
    set frtop [frame ${w}.top -bd 1 -relief raised]
    pack $frtop -side top -fill x
    ::UI::InitShortcutButtonPad $w $frtop 50
    ::UI::NewButton $w connect Connect $icons(btconnect) $icons(btconnectdis)  \
      [list ::Jabber::Login::Login $wDlgs(jlogin)]
    if {[::Jabber::MailBox::HaveMailBox]} {
	::UI::NewButton $w inbox Inbox $icons(btinboxLett) $icons(btinboxLettdis)  \
	  [list ::Jabber::MailBox::Show -visible 1]
    } else {
	::UI::NewButton $w inbox Inbox $icons(btinbox) $icons(btinboxdis)  \
	  [list ::Jabber::MailBox::Show -visible 1]
    }
    ::UI::NewButton $w newuser "New User" $icons(btnewuser) $icons(btnewuserdis)  \
      [list ::Jabber::Roster::NewOrEditItem $wDlgs(jrostnewedit) new] \
      -state disabled
    ::UI::NewButton $w stop Stop $icons(btstop) $icons(btstopdis)  \
      [list ::Jabber::UI::StopConnect] -state disabled
    set shortBtWidth [::UI::ShortButtonPadMinWidth $w]

    # Build bottom and up to handle clipping when resizing.
    # Jid entry with electric plug indicator.
    set jwapp(elplug) ${w}.jid.icon
    set jwapp(mystatus) ${w}.jid.stat
    pack [frame ${w}.jid -relief raised -borderwidth 1]  \
      -side bottom -fill x -pady 0
    pack [label $jwapp(mystatus) -image [::Jabber::Roster::GetMyPresenceIcon]] \
      -side left -pady 0 -padx 4
    pack [entry ${w}.jid.e -state disabled -width 0  \
      -textvariable ::Jabber::jstate(mejid)] \
      -side left -fill x -expand 1 -pady 0 -padx 0
    pack [label ${w}.jid.size -image $icons(resizehandle)]  \
      -padx 0 -pady 0 -side right -anchor s
    pack [label $jwapp(elplug) -image $icons(contact_off)]  \
      -side right -pady 0 -padx 0
    
    # Build status feedback elements.
    pack [frame ${w}.st -relief raised -borderwidth 1]  \
      -side bottom -fill x -pady 0
    pack [frame ${w}.st.g -relief groove -bd 2]  \
      -side top -fill x -padx 8 -pady 2
    set jwapp(statmess) ${w}.st.g.c
    pack [canvas $jwapp(statmess) -bd 0 -highlightthickness 0 -height 14]  \
      -side left -pady 1 -padx 6 -fill x -expand true
    $jwapp(statmess) create text 0 0 -anchor nw -text {} -font $sysFont(s) \
      -tags stattxt
    
    # Notebook frame.
    set frtbook ${w}.fnb
    pack [frame $frtbook -bd 1 -relief raised] -fill both -expand 1    
    set nbframe [::mactabnotebook::mactabnotebook ${frtbook}.tn]
    pack $nbframe -fill both -expand 1
    set jwapp(nbframe) $nbframe
    
    # Make the notebook pages.
    # Start with the Roster page -----------------------------------------------
    set ro [$nbframe newpage {Roster} -text [::msgcat::mc Roster]]    
    pack [::Jabber::Roster::Build $ro.ro] -fill both -expand 1

    # Build only Browser and/or Agents page when needed.
    if {[info exists prefs(winGeom,$w)]} {
	wm geometry $w $prefs(winGeom,$w)
    }
    set minWidth [expr $shortBtWidth > 200 ? $shortBtWidth : 200]
    wm minsize $w $minWidth 360
    wm maxsize $w 420 2000
}


proc ::Jabber::UI::GetRosterWmenu { } {
    variable jwapp

    return $jwapp(wmenu)
}

# Jabber::UI::NewPage --
#
#       Makes sure that there exists a page in the notebook with the
#       given name. Build it if missing. On return the page always exists.

proc ::Jabber::UI::NewPage {name} {   
    variable jwapp

    set nbframe $jwapp(nbframe)
    set pages [$nbframe pages]
    ::Jabber::Debug 2 "------::Jabber::UI::NewPage name=$name, pages=$pages"
    
    switch -exact $name {
	Agents {

	    # Agents page
	    if {[lsearch $pages Agents] < 0} {
		set ag [$nbframe newpage {Agents}]    
		pack [::Jabber::Agents::Build $ag.ag] -fill both -expand 1
	    }
	}
	Browser {
    
	    # Browser page
	    if {[lsearch $pages Browser] < 0} {
		set br [$nbframe newpage {Browser}]    
		pack [::Jabber::Browse::Build $br.br] -fill both -expand 1
	    }
	}
	default {
	    # Nothing
	    return -code error "Not recognized page name $name"
	}
    }    
}

proc ::Jabber::UI::StopConnect { } {
    
    ::Network::KillAll
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    ::Jabber::UI::FixUIWhen disconnect
}    

proc ::Jabber::UI::CloseRoster {w} {    
    upvar ::Jabber::jstate jstate

    ::UserActions::DoQuit -warning 1
    
    if {0} {
	set jstate(rostBrowseVis) 0
	if {[winfo exists $w]} {
	    catch {wm withdraw $w}
	    ::UI::SaveWinGeom $w
	}
    }
}

proc ::Jabber::UI::Pages { } {
    variable jwapp
    
    return [$jwapp(nbframe) pages]
}

proc ::Jabber::UI::LogoutClear { } {
    variable jwapp
    
    set nbframe $jwapp(nbframe)
    foreach page [$nbframe pages] {
	if {![string equal $page "Roster"]} {
	    $nbframe deletepage $page
	}
    }
}

proc ::Jabber::UI::StartStopAnimatedWave {start} {
    variable jwapp
    
    ::UI::StartStopAnimatedWave $jwapp(statmess) $start
}

proc ::Jabber::UI::SetStatusMessage {msg} {
    variable jwapp

    $jwapp(statmess) itemconfigure stattxt -text $msg
}

# Jabber::UI::MailBoxState --
# 
#       Sets icon to display empty|nonempty inbox state.

proc ::Jabber::UI::MailBoxState {mailboxstate} {
    variable jwapp    
    upvar ::UI::icons icons
    
    set w $jwapp(wtopRost)
    
    switch -- $mailboxstate {
	empty {
	    ::UI::ButtonConfigure $w inbox -image $icons(btinbox)
	}
	nonempty {
	    ::UI::ButtonConfigure $w inbox -image $icons(btinboxLett)
	}
    }
}

# Jabber::UI::WhenSetStatus --
#
#       Updates UI when set own presence status information.
#       
# Arguments:
#       type        any of 'available', 'unavailable', 'invisible',
#                   'away', 'dnd', 'xa'.
#       
# Results:
#       None.

proc ::Jabber::UI::WhenSetStatus {type} {
    variable jwapp
        
    $jwapp(mystatus) configure -image [::Jabber::Roster::GetMyPresenceIcon]
}

# Jabber::UI::GroupChat --
# 
#       Updates UI when enter/exit groupchat room.
#       
# Arguments:
#       what        any of 'enter' or 'exit'.
#       roomJid
#       
# Results:
#       None.

proc ::Jabber::UI::GroupChat {what roomJid} {
    variable jwapp
    
    set wmenu $jwapp(wmenu)
    set wmjexit ${wmenu}.jabber.mexitroom

    ::Jabber::Debug 4 "::Jabber::UI::GroupChat what=$what, roomJid=$roomJid"

    switch $what {
	enter {
	    $wmjexit add command -label $roomJid  \
	      -command [list ::Jabber::GroupChat::Exit $roomJid]	    
	}
	exit {
	    catch {$wmjexit delete $roomJid}	    
	}
    }
}

# Jabber::UI::Popup --
#
#       Handle popup menus in jabber dialogs, typically from right-clicking
#       a thing in the roster, browser, etc.
#       
# Arguments:
#       what        any of "roster", "browse", or "groupchat", or "agents"
#       w           widget that issued the command
#       v           for the tree widget it is the item path, 
#                   for text the jidhash.
#       
# Results:
#       popup menu displayed

proc ::Jabber::UI::Popup {what w v x y} {
    global  wDlgs this
    
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::UI::Popup what=$what, w=$w, v='$v', x=$x, y=$y"
    
    # The last element of $v is either a jid, (a namespace,) 
    # a header in roster, a group, or an agents xml tag.
    # The variables name 'jid' is a misnomer.
    # Find also type of thing clicked, 'typeClicked'.
    
    set typeClicked ""
    
    switch -- $what {
	roster {
	    
	    # The last element of atree item if user is a 3-tier jid for
	    # online users and a 2-tier jid else.
	    set jid [lindex $v end]
	    set jid3 $jid
	    set status [string tolower [lindex $v 0]]
	    
	    switch -- [llength $v] {
		1 {
		    set typeClicked head
		}
		default {
		    
		    # Must let 'jid' refer to 2-tier jid for commands to work!
		    if {[regexp {^(.+@[^/]+)(/.*)?$} $jid match jid2 res]} {
			
			set jid3 $jid
			set jid $jid2
			if {[$jstate(browse) havenamespace $jid3 "coccinella:wb"]} {
			    set typeClicked wb
			} else {
			    set typeClicked user
			}			
		    } elseif {[llength $v] == 2} {
			
			# Get a list of all jid's in this group. type=user.
			# Must strip off all resources.
			set typeClicked group
			set jid {}
			foreach jid3 [$w children $v] {
			    set jid2 $jid3
			    regexp {^(.+@[^/]+)(/.*)?$} $jid3 match jid2
			    lappend jid $jid2
			}
			set jid [list $jid]
		    }
		}
	    }
	}
	browse {
	    set jid [lindex $v end]
	    set jid3 $jid
	    set typesubtype [$jstate(browse) gettype $jid]
	    if {[regexp {^.+@[^/]+(/.*)?$} $jid match res]} {
		set typeClicked user
		if {[$jstate(jlib) service isroom $jid]} {
		    set typeClicked room
		}
	    } elseif {[string match -nocase "conference/*" $typesubtype]} {
		set typeClicked conference
	    } elseif {$jid != ""} {
		set typeClicked jid
	    }
	}
	groupchat {	    
	    set jid $v
	    set jid3 $jid
	    if {[regexp {^.+@[^/]+(/.*)?$} $jid match res]} {
		set typeClicked user
	    }
	}
	agents {
	    set jid [lindex $v end]
	    set jid3 $jid
	    set childs [$w children $v]
	    if {[regexp {(register|search|groupchat)} $jid match service]} {
		set typeClicked $service
		set jid [lindex $v end-1]
	    } elseif {$jid != ""} {
		set typeClicked jid
	    }
	    set services {}
	    foreach c $childs {
		if {[regexp {(register|search|groupchat)} $c match service]} {
		    lappend services $service
		}
	    }
	}
    }
    if {[string length $jid] == 0} {
	set typeClicked ""	
    }
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    
    ::Jabber::Debug 2 "    jid=$jid, typeClicked=$typeClicked"
    
    # Mads Linden's workaround for menu post problem on mac:
    # all in menubutton commands i add "after 40 the_command"
    # this way i can never have to posting error.
    # it is important after the tk_popup f.ex to
    #
    # destroy .mb
    # update
    #
    # this way the .mb is destroyd before the next window comes up, thats how I
    # got around this.
    
    # Make the appropriate menu.
    set m $jstate(wpopup,$what)
    set i 0
    catch {destroy $m}
    menu $m -tearoff 0
    
    foreach {item type cmd} $jstate(popup,$what,def) {
	if {[string index $cmd 0] == "@"} {
	    set mt [menu ${m}.sub${i} -tearoff 0]
	    set locname [::msgcat::mc $item]
	    $m add cascade -label $locname -menu $mt -state disabled
	    eval [string range $cmd 1 end] $mt
	    incr i
	} elseif {[string equal $item "separator"]} {
	    $m add separator
	    continue
	} else {
	    
	    # Really bad solution here!
	    regsub -all &jid3 $cmd [list $jid3] cmd
	    regsub -all &jid $cmd [list $jid] cmd
	    set cmd [subst -nocommands $cmd]
	    set locname [::msgcat::mc $item]
	    $m add command -label $locname -command "after 40 $cmd" -state disabled
	}
	
	# Special BAD BAD!!! ------
	if {$what == "roster" && $typeClicked == "user" && \
	  [string match -nocase "*chat history*" $item]} {
	    $m entryconfigure $locname -state normal
	}
	#--------
	
	if {![::Jabber::IsConnected]} {
	    continue
	}
	if {[string equal $type "any"]} {
	    $m entryconfigure $locname -state normal
	    continue
	}
	
	# State of menu entry. We use the 'type' and 'typeClicked' to sort
	# out which capabilities to offer for the clicked item.
	set state disabled
	
	switch -- $what {
	    roster {
		
		switch -- $type {
		    user {
			if {[string equal $typeClicked "user"] || \
			  [string equal $typeClicked "wb"]} {
			    set state normal
			}
			if {[string equal $status "offline"]} {
			    if {[string match -nocase "mchat" $item] || \
			      [string match -nocase "*version*" $item]} {
				set state disabled
			    }
			}
		    }
		    users {
			if {($typeClicked == "user") ||  \
			  ($typeClicked == "group") ||  \
			  ($typeClicked == "wb")} {
			    set state normal
			}
		    }
		    wb {
			if {[string equal $typeClicked "wb"]} {
			    set state normal
			}
		    }
		}
	    }
	    browse {
		switch -- $type {
		    user {
			if {[string equal $typeClicked "user"]} {
			    set state normal
			}
		    }
		    room {
			if {[string equal $typeClicked "room"]} {
			    set state normal
			}
		    }
		    jid {
			switch -- $typeClicked {
			    jid - user - conference {
				set state normal
			    }
			}
		    } 
		    search - register {
			if {[$jstate(browse) havenamespace $jid "jabber:iq:${type}"]} {
			    set state normal
			}
		    }
		    conference {
			switch -- $typeClicked {
			    conference {
				set state normal
			    }
			}
		    }
		    wb {
			switch -- $typeClicked {
			    room - user {
				set state normal
			    }
			}
		    }
		}
	    }
	    groupchat {	    
		if {($type == "user") && ($typeClicked == "user")} {
		    set state normal
		}
		if {($type == "wb") && ($typeClicked == "user")} {
		    set state normal
		}
	    }
	    agents {
		if {[string equal $type $typeClicked]} {
		    set state normal
		} elseif {[lsearch $services $type] >= 0} {
		    set state normal
		}
	    }
	}

	if {[string equal $state "normal"]} {
	    $m entryconfigure $locname -state normal
	}
    }   
    
    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks
    
    # Post popup menu.
    tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
    
    # Mac bug... (else can't post menu while already posted if toplevel...)
    if {[string match "mac*" $this(platform)]} {
	catch {destroy $m}
	update
    }
}

# Jabber::UI::FixUIWhen --
#       
#       Sets the correct state for menus and buttons when 'what'.
#       
# Arguments:
#       what        'connectinit', 'connectfin', 'connect', 'disconnect'
#
# Results:

proc ::Jabber::UI::FixUIWhen {what} {
    global  allIPnumsToSend wDlgs
    variable jwapp
    
    upvar ::UI::icons icons
    
    set w $jwapp(wtopRost)
    set wtop ${w}.
    set wmenu $jwapp(wmenu)
    set wmj ${wmenu}.jabber
    
    switch -exact -- $what {
	connectinit {
	    ::UI::ButtonConfigure $w connect -state disabled
	    ::UI::ButtonConfigure $w stop -state normal
	    ::UI::MenuMethod $wmj entryconfigure mLogin -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mNewAccount -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mSetupAssistant -state disabled
	}
	connectfin - connect {
	    ::UI::ButtonConfigure $w connect -state disabled
	    ::UI::ButtonConfigure $w newuser -state normal
	    ::UI::ButtonConfigure $w stop -state disabled
	    $jwapp(elplug) configure -image $icons(contact_on)
	    ::UI::MenuMethod $wmj entryconfigure mNewAccount -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mLogin  \
	      -label [::msgcat::mc Logout] -state normal -command \
	      [list ::Jabber::DoCloseClientConnection $allIPnumsToSend]
	    ::UI::MenuMethod $wmj entryconfigure mLogoutWith -state normal
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state normal
	    ::UI::MenuMethod $wmj entryconfigure mSearch -state normal
	    ::UI::MenuMethod $wmj entryconfigure mAddNewUser -state normal
	    ::UI::MenuMethod $wmj entryconfigure mSendMessage -state normal
	    ::UI::MenuMethod $wmj entryconfigure mChat -state normal
	    ::UI::MenuMethod $wmj entryconfigure mStatus -state normal
	    ::UI::MenuMethod $wmj entryconfigure mvCard -state normal
	    ::UI::MenuMethod $wmj entryconfigure mEnterRoom -state normal
	    ::UI::MenuMethod $wmj entryconfigure mExitRoom -state normal
	    ::UI::MenuMethod $wmj entryconfigure mCreateRoom -state normal
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state normal
	    ::UI::MenuMethod $wmj entryconfigure mRemoveAccount -state normal
	    ::UI::MenuMethod $wmj entryconfigure mSetupAssistant -state disabled
	}
	disconnect {
	    ::UI::ButtonConfigure $w connect -state normal
	    ::UI::ButtonConfigure $w newuser -state disabled
	    ::UI::ButtonConfigure $w stop -state disabled
	    $jwapp(elplug) configure -image $icons(contact_off)
	    ::UI::MenuMethod $wmj entryconfigure mNewAccount -state normal
	    ::UI::MenuMethod $wmj entryconfigure mLogin  \
	      -label "[::msgcat::mc Login]..." -state normal \
	      -command [list ::Jabber::Login::Login $wDlgs(jlogin)]
	    ::UI::MenuMethod $wmj entryconfigure mLogoutWith -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mSearch -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mAddNewUser -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mSendMessage -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mChat -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mStatus -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mvCard -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mEnterRoom -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mExitRoom -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mCreateRoom -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mRemoveAccount -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mSetupAssistant -state normal
	}
    }
}

proc ::Jabber::UI::SmileyMenuButton {w wtext} {
    global  prefs this
    upvar ::UI::smiley smiley
    
    # Workaround for missing -image option on my macmenubutton.
    if {[string equal $this(platform) "macintosh"] && \
      [string length [info command menubuttonOrig]]} {
	set menubuttonImage menubuttonOrig
    } else {
	set menubuttonImage menubutton
    }
    set wmenu ${w}.m
    $menubuttonImage $w -menu $wmenu -image $smiley(:\))
    set m [menu $wmenu -tearoff 0]
 
    if {$prefs(haveMenuImage)} {
	foreach name [array names smiley] {
	    $m add command -image $smiley($name) \
	      -command [list ::Jabber::UI::SmileyInsert $wtext $smiley($name) $name]
	}
    } else {
	foreach name [array names smiley] {
	    $m add command -label $name \
	      -command [list ::Jabber::UI::SmileyInsert $wtext $smiley($name) $name]
	}
    }
    return $w
}

proc ::Jabber::UI::SmileyInsert {wtext imname name} {
 
    $wtext insert insert " "
    $wtext image create insert -image $imname -name $name
    $wtext insert insert " "
}

# The ::Jabber::Register:: namespace -------------------------------------------

namespace eval ::Jabber::Register:: {

    variable server
    variable username
    variable password
}

# Jabber::Register::Register --
#
#       Registers new user with a server.
#
# Arguments:
#       w      the toplevel window.
#       args   -server, -username, -password
#       
# Results:
#       "cancel" or "new".

proc ::Jabber::Register::Register {w args} {
    global  this sysFont
    
    variable finished -1
    variable server
    variable username
    variable password
    variable topw $w
    
    if {[winfo exists $w]} {
	return
    }
    set finished -1
    array set argsArr $args
    foreach name {server username password} {
	if {[info exists argsArr(-$name)]} {
	    set $name $argsArr(-$name)
	}
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc {Register New Account}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    label $w.frall.head -text [::msgcat::mc {New Account}] -font $sysFont(l)  \
      -anchor w -padx 10 -pady 4
    pack $w.frall.head -side top -fill both -expand 1
    message $w.frall.msg -width 260 -font $sysFont(s) -text [::msgcat::mc janewaccount]
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.lserv -text "[::msgcat::mc {Jabber server}]:"  \
      -font $sysFont(sb) -anchor e
    entry $frmid.eserv -width 26    \
      -textvariable "[namespace current]::server" -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.luser -text "[::msgcat::mc Username]:" -font $sysFont(sb)  \
      -anchor e
    entry $frmid.euser -width 26   \
      -textvariable "[namespace current]::username" -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.lpass -text "[::msgcat::mc Password]:" -font $sysFont(sb)  \
      -anchor e
    entry $frmid.epass -width 26   \
      -textvariable "[namespace current]::password" -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    grid $frmid.lserv -column 0 -row 0 -sticky e
    grid $frmid.eserv -column 1 -row 0 -sticky w
    grid $frmid.luser -column 0 -row 1 -sticky e
    grid $frmid.euser -column 1 -row 1 -sticky w
    grid $frmid.lpass -column 0 -row 2 -sticky e
    grid $frmid.epass -column 1 -row 2 -sticky w
    pack $frmid -side top -fill both -expand 1

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc New] -width 8 -default active \
      -command [list [namespace current]::Doit]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8   \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    #bind $w <Return> "$frbot.btconn invoke"
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "new"}]
}

proc ::Jabber::Register::Cancel {w} {
    variable finished

    set finished 0
    destroy $w
}

# Jabber::Register::Doit --
#
#       Initiates a register operation.
# Arguments:
#       w
#       
# Results:
#       .

proc ::Jabber::Register::Doit { } {
    global  errorCode prefs

    variable finished
    variable server
    variable username
    variable password
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Register::Doit"
    
    # Kill any pending open states.
    ::Network::KillAll
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    
    # Check 'server', 'username' if acceptable.
    foreach name {server username} {
	set what $name
	if {[string length $what] <= 1} {
	    tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	      [::msgcat::mc jamessnamemissing $name]]
	    return
	}
	if {[regexp $jprefs(invalsExp) $what match junk]} {
	    tk_messageBox -icon error -type ok -message [FormatTextForMessageBox  \
	      [::msgcat::mc jamessillegalchar $name $what]]
	    return
	}
    }    
    
    ::Jabber::UI::SetStatusMessage [::msgcat::mc jawaitresp $server]
    ::Jabber::UI::StartStopAnimatedWave 1
    update idletasks

    # Set callback procedure for the async socket open.
    set jstate(servPort) $jprefs(port)
    set cmd [namespace current]::SocketIsOpen
    ::Network::OpenConnection $server $jprefs(port) $cmd -timeout $prefs(timeoutSecs)
    
    # Not sure about this...
    if {0} {
	if {$ssl} {
	    set port $jprefs(sslport)
	} else {
	    set port $jprefs(port)
	}
	::Network::OpenConnection $server $port $cmd -timeout $prefs(timeoutSecs) \
	  -tls $ssl
    }
}

# Jabber::Register::SocketIsOpen --
#
#       Callback when socket has been opened. Registers.
#       
# Arguments:
#       
#       status      "error", "timeout", or "ok".
# Results:
#       .

proc ::Jabber::Register::SocketIsOpen {sock ip port status {msg {}}} {    
    variable server
    variable username
    variable password
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Register::SocketIsOpen"

    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    update idletasks
    
    if {[string equal $status "error"]} {
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessnosocket $ip $msg]]
	return {}
    } elseif {[string equal $status "timeout"]} {
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesstimeoutserver $server]]
	return {}
    }    
    
    # Initiate a new stream. Perhaps we should wait for the server <stream>?
    if {[catch {$jstate(jlib) connect $server -socket $sock} err]} {
	tk_messageBox -icon error -title [::msgcat::mc {Open Failed}] -type ok \
	  -message [FormatTextForMessageBox $err]
	return
    }

    # Make a new account. Perhaps necessary to get additional variables
    # from some user preferences.
    $jstate(jlib) register_set $username $password   \
      [namespace current]::ResponseProc

    # Just wait for a callback to the procedure.
}

# Jabber::Register::ResponseProc --
#
#       Callback for register iq element.
#       
# Arguments:
#       
# Results:
#       .

proc ::Jabber::Register::ResponseProc {jlibName type theQuery} {    
    variable topw
    variable finished
    variable server
    variable username
    variable password
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Register::ResponseProc jlibName=$jlibName,\
      type=$type, theQuery=$theQuery"
    
    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	if {$errcode == 409} {
	    set msg "The registration failed with the error code $errcode\
	      message: \"$errmsg\",\
	      because this username is already in use by another user.\
	      If this user is you, try to login instead."
	} else {
	    set msg "The registration failed with the error code $errcode and\
	      message: \"$errmsg\""
	}
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $msg] \	  
    } else {
	tk_messageBox -icon info -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessregisterok $server]]
    
	# Save to our jserver variable. Create a new profile.
	::Jabber::SetUserProfile {} $server $username $password
    }
    
    # Disconnect. This should reset both wrapper and XML parser!
    # Beware: we are in the middle of a callback from the xml parser,
    # and need to be sure to exit from it before resetting!
    after idle $jstate(jlib) disconnect
    set finished 1
    destroy $topw
}

# Jabber::Register::Remove --
#
#       Removes an existing user account from your login server.
#
# Arguments:
#       jid:        Optional, defaults to login server
#       
# Results:
#       Remote callback from server scheduled.

proc ::Jabber::Register::Remove {{jid {}}} {
    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    set ans "yes"
    if {$jid == ""} {
	set jid $jserver(this)
	set ans [tk_messageBox -icon warning -title [::msgcat::mc Unregister] \
	  -type yesno -default no -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessremoveaccount]]]
    }
    if {$ans == "yes"} {
	
	# Do we need to obtain a key for this???
	$jstate(jlib) register_remove $jid  \
	  [list ::Jabber::Register::RemoveCallback $jid]
    }
}

proc ::Jabber::Register::RemoveCallback {jid jlibName type theQuery} {
    
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $theQuery break
	tk_messageBox -icon error -title [::msgcat::mc Unregister] -type ok  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrunreg $jid $errcode $errmsg]]
    } elseif {[string equal $type "ok"]} {
	tk_messageBox -icon info -title [::msgcat::mc Unregister] -type ok  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessokunreg $jid]]
    }
}

# The ::Jabber::Passwd:: namespace -------------------------------------------
#  jserver(profile): {$profile1 {$server1 $username $password $resource} \
#                     $profile2 {$server2 $username2 $password2 $resource2} ... }

namespace eval ::Jabber::Passwd:: {

    variable password
}

# Jabber::Passwd::Build --
#
#       Sets new password.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       "cancel" or "set".

proc ::Jabber::Passwd::Build {w} {
    global  this sysFont
    
    variable finished -1
    variable password
    variable validate
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $w]} {
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc {New Password}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] \
      -fill both -expand 1 -ipadx 12 -ipady 4
    set password ""
    set validate ""
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.ll -font $sysFont(sb) -text [::msgcat::mc janewpass]
    label $frmid.le -font $sysFont(sb) -text $jstate(mejid)
    label $frmid.lserv -text "[::msgcat::mc {New password}]:" -anchor e
    entry $frmid.eserv -width 18 -show *  \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    label $frmid.lvalid -text "[::msgcat::mc {Retype password}]:" -anchor e
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
    pack [button $frbot.btset -text [::msgcat::mc Set] -width 8 -default active \
      -command [list [namespace current]::Doit $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8   \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btset invoke"
    
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
    
    ::Jabber::Debug 2 "::Jabber::Passwd::Doit"

    if {![string equal $validate $password]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox [::msgcat::mc jamesspasswddiff]]
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
    upvar ::Jabber::jserver jserver

    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	set msg 
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox  \
	  [::msgcat::mc jamesspasswderr $errcode $errmsg]] \
    } else {
	
	# Make sure the new password is stored in our internal state array.
	set ind [lsearch $jserver(profile) $jserver(profile,selected)]
	if {$ind >= 0} {
	    set userSpec [lindex $jserver(profile) [expr $ind + 1]]
	    #set userSpec [lreplace $userSpec 2 2 $password]
	    lset userSpec 2 $password
	   
	    # Save to our jserver variable. Create a new profile.
	    eval {::Jabber::SetUserProfile {}} $userSpec
	}
	
	tk_messageBox -title [::msgcat::mc {New Password}] -icon info -type ok \
	  -message [FormatTextForMessageBox [::msgcat::mc jamesspasswdok]]
    }
}

# The ::Jabber::GenRegister:: namespace -----------------------------------------

namespace eval ::Jabber::GenRegister:: {


}

# Jabber::GenRegister::BuildRegister --
#
#       Initiates the process of registering with a service. 
#       Uses iq get-set method.
#       
# Arguments:
#       w           toplevel widget
#       args   -server, -autoget 0/1
#       
# Results:
#       "cancel" or "register".
     
proc ::Jabber::GenRegister::BuildRegister {w args} {
    global  this sysFont

    variable wtop
    variable wbox
    variable wbtregister
    variable wbtget
    variable wcomboserver
    variable server
    variable wsearrows
    variable stattxt
    variable UItype 2
    variable finished -1
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::GenRegister::BuildRegister"
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc {Register Service}]
    set wtop $w
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 240 -font $sysFont(s) -text  \
      [::msgcat::mc jaregmsg] -anchor w -justify left
    pack $w.frall.msg -side top -fill x -anchor w -padx 4 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -expand 0 -anchor w -padx 10
    label $frtop.lserv -text "[::msgcat::mc {Service server}]:" -font $sysFont(sb)
    
    # Get all (browsed) services that support registration.
    set regServers [$jstate(jlib) service getjidsfor "register"]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20 -font $sysFont(s)   \
      -textvariable "[namespace current]::server" -editable 0
    eval {$frtop.eserv list insert end} $regServers
    
    # Find the default registration server.
    if {[llength $regServers]} {
	set server [lindex $regServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    label $frtop.ldesc -text "[::msgcat::mc Specifications]:" -font $sysFont(sb)
    label $frtop.lstat -textvariable [namespace current]::stattxt

    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $wcomboserver -column 1 -row 0 -sticky ew
    grid $frtop.ldesc -column 0 -row 1 -sticky e -padx 4 -pady 2
    grid $frtop.lstat -column 1 -row 1 -sticky w
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtregister $frbot.btenter
    set wbtget $frbot.btget
    pack [button $wbtget -text [::msgcat::mc Get] -width 8 -default active \
      -command [namespace current]::Get]  \
      -side right -padx 5 -pady 5
    pack [button $wbtregister -text [::msgcat::mc Register] -width 8 -state disabled \
      -command [namespace current]::DoRegister]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side bottom -fill both -expand 1 -padx 8 -pady 6

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.

    if {$UItype == 0} {
	set wfr $w.frall.frlab
	set wcont [LabeledFrame2 $wfr [::msgcat::mc Specifications]]
	pack $wfr -side top -fill both -padx 2 -pady 2
	
	set wbox $wcont.box
	frame $wbox
	pack $wbox -side top -fill x -padx 4 -pady 10
	pack [label $wbox.la -textvariable "[namespace current]::stattxt"]  \
	  -padx 0 -pady 10
    }
    if {$UItype == 2} {
	
	# Not same wbox as above!!!
	set wbox $w.frall.frmid
	::Jabber::Forms::BuildScrollForm $wbox -height 160 \
	  -width 220
	pack $wbox -side top -fill both -expand 1 -padx 8 -pady 4
    }
    
    set stattxt "-- [::msgcat::mc jasearchwait] --"
    wm minsize $w 300 300
        
    # Grab and focus.
    set oldFocus [focus]
    catch {grab $w}
    
    if {[info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	::Jabber::GenRegister::Get
    }
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "register"}]
}

# Jabber::GenRegister::Simple --
#
#       Initiates the process of registering with a service. 
#       Uses straight iq set method with fixed fields (username and password).
#       
# Arguments:
#       w           toplevel widget
#       args   -server
#       
# Results:
#       "cancel" or "register".
     
proc ::Jabber::GenRegister::Simple {w args} {
    global  this sysFont

    variable wtop
    variable wbtregister
    variable server
    variable finished -1
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::GenRegister::Simple"
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc {Register Service}]
    set wtop $w
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 240 -font $sysFont(s) -text  \
      [::msgcat::mc jaregmsg]
    pack $w.frall.msg -side top -fill x -anchor w -padx 4 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -fill x
    label $frtop.lserv -text "[::msgcat::mc {Service server}]:" -font $sysFont(sb)
    
    # Get all (browsed) services that support registration.
    set regServers [$jstate(jlib) service getjidsfor "register"]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20 -font $sysFont(s)   \
      -textvariable [namespace current]::server -editable 0
    eval {$frtop.eserv list insert end} $regServers
    
    # Find the default conferencing server.
    if {[llength $regServers]} {
	set server [lindex $regServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $wcomboserver -column 1 -row 0 -sticky ew
    
    label $frtop.luser -text "[::msgcat::mc Username]:" -font $sysFont(sb) \
      -anchor e
    entry $frtop.euser -width 26   \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frtop.lpass -text "[::msgcat::mc Password]:" -font $sysFont(sb) \
      -anchor e
    entry $frtop.epass -width 26   \
      -textvariable [namespace current]::password -validate key \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    
    grid $frtop.luser -column 0 -row 1 -sticky e
    grid $frtop.euser -column 1 -row 1 -sticky ew
    grid $frtop.lpass -column 0 -row 2 -sticky e
    grid $frtop.epass -column 1 -row 2 -sticky ew
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wbtregister $frbot.btenter
    pack [button $wbtregister -text [::msgcat::mc Register] \
      -default active -command [namespace current]::DoSimple]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
        
    wm resizable $w 0 0
        
    # Grab and focus.
    set oldFocus [focus]
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "register"}]
}

proc ::Jabber::GenRegister::Cancel {w} {
    variable finished
    
    set finished 0
    destroy $w
}

proc ::Jabber::GenRegister::Get { } {    
    variable server
    variable wsearrows
    variable wcomboserver
    variable wbtget
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    # Verify.
    if {[string length $server] == 0} {
	tk_messageBox -type ok -icon error  \
	  -message [::msgcat::mc jamessregnoserver]
	return
    }	
    $wcomboserver configure -state disabled
    $wbtget configure -state disabled
    set stattxt "-- [::msgcat::mc jawaitserver] --"
    
    # Send get register.
    $jstate(jlib) register_get ::Jabber::GenRegister::GetCB -to $server    
    $wsearrows start
}

proc ::Jabber::GenRegister::GetCB {jlibName type subiq} {    
    variable wtop
    variable wbox
    variable wsearrows
    variable wbtregister
    variable wbtget
    variable UItype
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::GenRegister::GetCB type=$type, subiq='$subiq'"

    if {![winfo exists $wtop]} {
	return
    }
    $wsearrows stop
    
    if {[string equal $type "error"]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrregget [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }

    set subiqChildList [wrapper::getchildren $subiq]
    if {$UItype == 0} {
	catch {destroy $wbox}
	::Jabber::Forms::Build $wbox $subiqChildList -template "register"
	pack $wbox -side top -fill x -anchor w -padx 2 -pady 10
    }
    if {$UItype == 2} {
    	set stattxt ""
	::Jabber::Forms::FillScrollForm $wbox $subiqChildList \
	   -template "register"
    }
    
    $wbtregister configure -state normal -default active
    $wbtget configure -state normal -default disabled    
}

proc ::Jabber::GenRegister::DoRegister { } {   
    variable server
    variable wsearrows
    variable wtop
    variable wbox
    variable finished
    variable UItype
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $wsearrows]} {
	$wsearrows start
    }
    if {$UItype != 2} {
    	set subelements [::Jabber::Forms::GetXML $wbox]
    } else {
    	set subelements [::Jabber::Forms::GetScrollForm $wbox]
    }
    
    # We need to do it the crude way.
    $jstate(jlib) send_iq "set"  \
      [wrapper::createtag "query" -attrlist {xmlns jabber:iq:register}   \
      -subtags $subelements] -to $server   \
      -command [list [namespace current]::ResultCallback $server]
    set finished 1
    destroy $wtop
}

proc ::Jabber::GenRegister::DoSimple { } {    
    variable wtop
    variable server
    variable username
    variable password
    variable finished
    upvar ::Jabber::jstate jstate
    
    $jstate(jlib) register_set $username $password  \
      [list [namespace current]::SimpleCallback $server] -to $server
    set finished 1
    destroy $wtop
}

# Jabber::GenRegister::ResultCallback --
#
#       This is our callback procedure from 'jabber:iq:register' stuffs.

proc ::Jabber::GenRegister::ResultCallback {server type subiq} {

    ::Jabber::Debug 2 "::Jabber::GenRegister::ResultCallback server=$server, type=$type, subiq='$subiq'"

    if {[string equal $type "error"]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrregset $server [lindex $subiq 0] [lindex $subiq 1]]]
    } else {
	tk_messageBox -type ok -icon info -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessokreg $server]]
    }
}

proc ::Jabber::GenRegister::SimpleCallback {server jlibName type subiq} {

    ::Jabber::Debug 2 "::Jabber::GenRegister::ResultCallback server=$server, type=$type, subiq='$subiq'"

    if {[string equal $type "error"]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrregset $server [lindex $subiq 0] [lindex $subiq 1]]]
    } else {
	tk_messageBox -type ok -icon info -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessokreg $server]]
    }
}

# The ::Jabber::Login:: namespace ----------------------------------------------

namespace eval ::Jabber::Login:: {
    
    variable server
    variable username
    variable password
}

# Jabber::Login::Login --
#
#       Log in to a server with an existing user account.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       name of button pressed; "cancel" or "login".

proc ::Jabber::Login::Login {w} {
    global  this sysFont prefs
    
    variable wtoplevel $w
    variable finished -1
    variable menuVar
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable digest
    variable ssl 0
    variable invisible 0
    variable tmpJServArr
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    if {[winfo exists $w]} {
	return
    }
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc Login]
    set digest 1
    set ssl $jprefs(usessl)
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    label $w.frall.head -text [::msgcat::mc Login] -font $sysFont(l)  \
      -anchor w -padx 10 -pady 4
    pack $w.frall.head -side top -fill both -expand 1
    message $w.frall.msg -width 260 -font $sysFont(s) -text [::msgcat::mc jalogin]
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill both -expand 1
    
    # Sync $jserver(all)
    set jserver(all) {}
    foreach {name spec} $jserver(profile) {
	lappend jserver(all) $name
    }
    
    # Option menu for selecting user profile.
    label $frmid.lpop -text "[::msgcat::mc Profile]:" -font $sysFont(sb) -anchor e
    set wpopup $frmid.popup
    eval {tk_optionMenu $wpopup [namespace current]::menuVar} $jserver(all)
    $wpopup configure -highlightthickness 0  \
      -background $prefs(bgColGeneral) -foreground black
    grid $frmid.lpop -column 0 -row 0 -sticky e
    grid $wpopup -column 1 -row 0 -sticky e

    # Verify that the selected also in array.
    if {[lsearch -exact $jserver(profile) $jserver(profile,selected)] < 0} {
	set jserver(profile,selected) [lindex $jserver(profile) 0]
    }
    set profile $jserver(profile,selected)
    set menuVar $jserver(profile,selected)
    
    # Make temp array for servers. Handy fo filling in the entries.
    foreach {name spec} $jserver(profile) {
	foreach [list  \
	  tmpJServArr($name,server)     \
	  tmpJServArr($name,username)   \
	  tmpJServArr($name,password)   \
	  tmpJServArr($name,resource)] $spec break
    }
    set server $tmpJServArr($menuVar,server)
    set username $tmpJServArr($menuVar,username)
    set password $tmpJServArr($menuVar,password)
    set resource $tmpJServArr($menuVar,resource)
    
    label $frmid.lserv -text "[::msgcat::mc {Jabber server}]:" -font $sysFont(sb) -anchor e
    entry $frmid.eserv -width 26    \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.luser -text "[::msgcat::mc Username]:" -font $sysFont(sb) -anchor e
    entry $frmid.euser -width 26   \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.lpass -text "[::msgcat::mc Password]:" -font $sysFont(sb) -anchor e
    entry $frmid.epass -width 26   \
      -textvariable [namespace current]::password -show {*} -validate key \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    label $frmid.lres -text "[::msgcat::mc Resource]:" -font $sysFont(sb) -anchor e
    entry $frmid.eres -width 26   \
      -textvariable [namespace current]::resource -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    checkbutton $frmid.cdig -text "  [::msgcat::mc {Scramble password}]"  \
      -variable [namespace current]::digest
    checkbutton $frmid.cssl -text "  [::msgcat::mc {Use SSL for security}]"  \
      -variable [namespace current]::ssl
    checkbutton $frmid.cinv  \
      -text "  [::msgcat::mc {Login as invisible}]"  \
      -variable [namespace current]::invisible

    grid $frmid.lserv -column 0 -row 1 -sticky e
    grid $frmid.eserv -column 1 -row 1 -sticky w
    grid $frmid.luser -column 0 -row 2 -sticky e
    grid $frmid.euser -column 1 -row 2 -sticky w
    grid $frmid.lpass -column 0 -row 3 -sticky e
    grid $frmid.epass -column 1 -row 3 -sticky w
    grid $frmid.lres -column 0 -row 4 -sticky e
    grid $frmid.eres -column 1 -row 4 -sticky w
    grid $frmid.cdig -column 1 -row 5 -sticky w -pady 2
    grid $frmid.cssl -column 1 -row 6 -sticky w -pady 2
    grid $frmid.cinv -column 1 -row 7 -sticky w -pady 2

    if {!$prefs(tls)} {
	set ssl 0
	$frmid.cssl configure -state disabled
    }
	
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Login] -width 8 \
      -default active -command [namespace current]::Doit]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::DoCancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    # Necessary to trace the popup menu variable.
    trace variable [namespace current]::menuVar w  \
      [namespace current]::TraceMenuVar
        
    if {[info exists prefs(winGeom,$w)]} {
	regexp {^[^+-]+((\+|-).+$)} $prefs(winGeom,$w) match pos
	wm geometry $w $pos
    }
    wm resizable $w 0 0
    bind $w <Return> ::Jabber::Login::Doit
    bind $w <Escape> [list ::Jabber::Login::DoCancel $w]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    # Clean up.
    catch {grab release $w}
    ::Jabber::Login::Close $w
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "login"}]
}

proc ::Jabber::Login::DoCancel {w} {
    variable finished
    
    ::UI::SaveWinGeom $w
    set finished 0
    catch {destroy $w}
}

proc ::Jabber::Login::Close {w} {
    variable menuVar
    upvar ::Jabber::jserver jserver
    
    # Clean up.
    set jserver(profile,selected) $menuVar
    trace vdelete [namespace current]::menuVar w  \
      [namespace current]::TraceMenuVar
    catch {grab release $w}
    catch {destroy $w}    
}

proc ::Jabber::Login::TraceMenuVar {name key op} {
    
    # Call by name.
    upvar #0 $name locName

    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable menuVar
    variable tmpJServArr
    
    set profile $locName
    set server $tmpJServArr($locName,server)
    set username $tmpJServArr($locName,username)
    set password $tmpJServArr($locName,password)
    set resource $tmpJServArr($locName,resource)
}

# Jabber::Login::Doit --
#
#       Initiates a login to a server with an existing user account.
#
# Arguments:
#       
# Results:
#       .

proc ::Jabber::Login::Doit { } {
    global  errorCode prefs

    variable wtoplevel
    variable finished
    variable server
    variable username
    variable password
    variable resource
    variable ssl
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Login::Doit"
    
    # Kill any pending open states.
    ::Network::KillAll
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    
    # Check 'server', 'username' and 'password' if acceptable.
    foreach name {server username password} {
	upvar 0 $name var
	if {[string length $var] <= 1} {
	    tk_messageBox -icon error -type ok -message  \
	      [FormatTextForMessageBox [::msgcat::mc jamessnamemissing $name]]	      
	    return
	}
	if {$name == "password"} {
	    continue
	}
	if {[regexp $jprefs(invalsExp) $var match junk]} {
	    tk_messageBox -icon error -type ok -message  \
	      [FormatTextForMessageBox [::msgcat::mc jamessillegalchar $name $var]]
	    return
	}
    }    
    set finished 1
    ::UI::SaveWinGeom $wtoplevel
    catch {destroy $wtoplevel}
    
    ::Jabber::UI::SetStatusMessage [::msgcat::mc jawaitresp $server]
    ::Jabber::UI::StartStopAnimatedWave 1
    ::Jabber::UI::FixUIWhen "connectinit"
    update idletasks

    # Async socket open with callback.
    if {$ssl} {
	set port $jprefs(sslport)
    } else {
	set port $jprefs(port)
    }
    ::Network::OpenConnection $server $port [namespace current]::SocketIsOpen  \
      -timeout $prefs(timeoutSecs) -tls $ssl
}

# Jabber::Login::SocketIsOpen --
#
#       Callback when socket has been opened. Logins.
#       
# Arguments:
#       
#       status      "error", "timeout", or "ok".
# Results:
#       Callback initiated.

proc ::Jabber::Login::SocketIsOpen {sock ip port status {msg {}}} {    
    variable server
    variable username
    variable password
    variable resource
    variable digest
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Login::SocketIsOpen"
    
    switch $status {
	error - timeout {
	    ::Jabber::UI::SetStatusMessage ""
	    ::Jabber::UI::StartStopAnimatedWave 0
	    ::Jabber::UI::FixUIWhen "disconnect"
	    if {$status == "error"} {
		tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
		  [::msgcat::mc jamessnosocket $ip $msg]]
	    } elseif {$status == "timeout"} {
		tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
		  [::msgcat::mc jamesstimeoutserver $server]]
	    }
	    return ""
	}
	default {
	    # Just go ahead
	}
    }    
    set jstate(sock) $sock
    ::Jabber::UI::SetStatusMessage [::msgcat::mc jawaitxml $server]
    
    # Initiate a new stream. Perhaps we should wait for the server <stream>?
    if {[catch {
	$jstate(jlib) connect $server -socket $sock  \
	  -cmd [namespace current]::ConnectProc
    } err]} {
	::Jabber::UI::SetStatusMessage ""
	::Jabber::UI::StartStopAnimatedWave 0
	::Jabber::UI::FixUIWhen "disconnect"
	tk_messageBox -icon error -title [::msgcat::mc {Open Failed}] -type ok \
	  -message [FormatTextForMessageBox $err]
	return
    }

    # Just wait for a callback to the procedure.
}

# Jabber::Login::ConnectProc --
#
#       Callback procedure for the 'connect' command of jabberlib.
#       
# Arguments:
#       jlibName    name of jabber lib instance
#       args        attribute list
#       
# Results:
#       Callback initiated.

proc ::Jabber::Login::ConnectProc {jlibName args} {    
    variable server
    variable username
    variable password
    variable resource
    variable digest
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Login::ConnectProc jlibName=$jlibName, args='$args'"

    array set argsArray $args
    ::Jabber::UI::SetStatusMessage [::msgcat::mc jasendauth $server]
    
    # Send authorization info for an existing account.
    # Perhaps necessary to get additional variables
    # from some user preferences.
    if {$resource == ""} {
    	set resource coccinella
    }
    if {$digest} {
	if {![info exists argsArray(id)]} {
	    error "no id for digest in receiving <stream>"
	}
	
	::Jabber::Debug 3 "argsArray(id)=$argsArray(id), password=$password"
	
	set digestedPw [::sha1pure::sha1 $argsArray(id)$password]
	$jstate(jlib) send_auth $username $resource   \
	  ::Jabber::Login::ResponseProc -digest $digestedPw
    } else {
	$jstate(jlib) send_auth $username $resource   \
	  ::Jabber::Login::ResponseProc -password $password
    }
    
    # Just wait for a callback to the procedure.
}

# Jabber::Login::ResponseProc --
#
#       Callback for Login iq element.
#       
# Arguments:
#       
# Results:
#       .

proc ::Jabber::Login::ResponseProc {jlibName type theQuery} {
    global  ipName2Num prefs wDlgs
    
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable invisible
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Jabber::Debug 2 "::Jabber::Login::ResponseProc  theQuery=$theQuery"

    ::Jabber::UI::StartStopAnimatedWave 0
    
    if {[string equal $type "error"]} {	
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	::Jabber::UI::SetStatusMessage [::msgcat::mc jaerrlogin $server $errmsg]
	::Jabber::UI::FixUIWhen "disconnect"
	if {$errcode == 409} {
	    set msg [::msgcat::mc jamesslogin409 $errcode]
	} else {
	    set msg [::msgcat::mc jamessloginerr $errcode $errmsg]
	}
	tk_messageBox -icon error -type ok -title [::msgcat::mc Error]  \
	  -message [FormatTextForMessageBox $msg]

	#       There is a potential problem if called from within a xml parser 
	#       callback which makes the subsequent parsing to fail. (after idle?)
	after idle $jstate(jlib) disconnect
	return
    } 
    
    # Collect ip num name etc. in arrays.
    if {![::OpenConnection::SetIpArrays $server $jstate(sock)  \
      $jstate(servPort)]} {
	::Jabber::UI::SetStatusMessage ""
	return
    }
    if {[IsIPNumber $server]} {
	set ipNum $server
    } else {
	set ipNum $ipName2Num($server)
    }
    set jstate(ipNum) $ipNum
    
    # Ourself.
    set jstate(mejid) "${username}@${server}"
    set jstate(meres) $resource
    set jstate(mejidres) "${username}@${server}/${resource}"
    set jserver(profile,selected) $profile
    set jserver(this) $server
    
    # Set communication entry in UI.
    if {$prefs(jabberCommFrame)} {
	::UI::ConfigureAllJabberEntries $ipNum -netstate "connect"	
    } else {
	::UI::SetCommEntry $wDlgs(mainwb) $ipNum 1 -1 -jidvariable ::Jabber::jstate(.,tojid)  \
	  -dosendvariable ::Jabber::jstate(.,doSend)
	# We skip this.
	#  -validatecommand ::Jabber::VerifyJID
    }
    set ::Jabber::Roster::servtxt $server
    ::Jabber::Roster::SetUIWhen "connect"
    ::Jabber::Browse::SetUIWhen "connect"

    # Multiinstance whiteboard UI stuff.
    foreach w [::UI::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]
	set ::Jabber::jstate($wtop,tojid) "@${server}"
	#::UI::SetStatusMessage $wtop [::msgcat::mc jaauthok $server]

	# Make menus consistent.
	::UI::FixMenusWhen $wtop "connect"
    }
    ::Network::RegisterIP $ipNum "to"
    
    # Update UI in Roster window.
    ::Jabber::UI::SetStatusMessage [::msgcat::mc jaauthok $server]
    ::Jabber::UI::FixUIWhen "connectfin"
    
    # Login was succesful. Get my roster, and set presence.
    $jstate(jlib) roster_get ::Jabber::Roster::PushProc
    if {$invisible} {
	set jstate(status) "invisible"
	::Jabber::SetStatus invisible
    } else {
	set jstate(status) "available"
	::Jabber::SetStatus available
    }
    
    # Store our own ip number in a public storage at the server.
    ::Jabber::SetPrivateData
    
    # Get the services for all our servers on the list. Depends on our settings:
    # If browsing fails must use "agents" as a fallback.
    if {[string equal $jprefs(agentsOrBrowse) "browse"]} {
	::Jabber::Browse::GetAll
    } elseif {[string equal $jprefs(agentsOrBrowse) "agents"]} {
	::Jabber::Agents::GetAll
    }
    

    # Any noise.
    ::Sounds::Play "connected"
}

# Jabber::VerifyJIDWhiteboard --
#
#       Validate entry for jid.
#       
# Arguments:
#       #jid     username@server
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::VerifyJIDWhiteboard {wtop} {

    upvar ::Jabber::jstate jstate
    
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    set jid $jstate($wtop,tojid)
    if {$jstate($wtop,doSend)} {
	if {![::Jabber::IsWellFormedJID $jid]} {
	    tk_messageBox -icon warning -type ok -parent $w -message  \
	      [FormatTextForMessageBox [::msgcat::mc jamessinvalidjid]]
	    return 0
	}
    }
    return 1
}

# The ::Jabber::Logout:: namespace ---------------------------------------------

namespace eval ::Jabber::Logout:: {}

proc ::Jabber::Logout::WithStatus {w} {
    global  prefs this sysFont

    variable finished -1
    variable status ""
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Logout::WithStatus"

    if {[winfo exists $w]} {
	return
    }
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w {Logout With Message}
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]  \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    label $w.frall.head -text {Logout} -font $sysFont(l)  \
      -anchor w -padx 10 -pady 4
    pack $w.frall.head -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill both -expand 1
    
    label $frmid.lstat -text "Status:" -font $sysFont(sb) -anchor e
    entry $frmid.estat -width 36  \
      -textvariable [namespace current]::status
    grid $frmid.lstat -column 0 -row 1 -sticky e
    grid $frmid.estat -column 1 -row 1 -sticky w
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btout -text [::msgcat::mc Logout] -width 8 \
      -default active -command [list [namespace current]::DoLogout $w]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::DoCancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    if {[info exists prefs(winGeom,$w)]} {
	regexp {^[^+-]+((\+|-).+$)} $prefs(winGeom,$w) match pos
	wm geometry $w $pos
    }
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
    ::Jabber::DoCloseClientConnection $jstate(ipNum) -status $status
}

# The ::Jabber::Subscribe:: namespace ------------------------------------------

namespace eval ::Jabber::Subscribe:: {

    # Store everything in 'locals($uid, ... )'.
    variable locals   
    variable uid 0
}

# Jabber::Subscribe::Subscribe --
#
#       Ask for user response on a subscribe presence element.
#
# Arguments:
#       wbase  the toplevel window's base path.
#       jid    the jid we receive a 'subscribe' presence element from.
#       args   ?-key value ...? look for any '-status' only.
#       
# Results:
#       "deny" or "accept".

proc ::Jabber::Subscribe::Subscribe {wbase jid args} {
    global  this sysFont prefs wDlgs
    
    variable locals   
    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Subscribe::Subscribe jid=$jid"

    incr uid
    set w ${wbase}${uid}
    set locals($uid,finished) -1
    set locals($uid,wtop) $w
    set locals($uid,jid) $jid
    array set argsArr $args
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc Subscribe]
    
    # Find our present groups.
    set allGroups [$jstate(roster) getgroups]
        
    # This gets a list '-name ... -groups ...' etc. from our roster.
    # Note! -groups PLURAL!
    array set itemAttrArr {-name {} -groups {} -subscription none}
    array set itemAttrArr [$jstate(roster) getrosteritem $jid]
    
    # Textvariables for entry and combobox.
    set locals($uid,name) $itemAttrArr(-name)
    if {[llength $itemAttrArr(-groups)] > 0} {
	set locals($uid,group) [lindex $itemAttrArr(-groups) 0]
    }
    
    # Figure out if we shall send a 'subscribe' presence to this user.
    set maySendSubscribe 1
    if {$itemAttrArr(-subscription) == "to" ||  \
      $itemAttrArr(-subscription) == "both"} {
	set maySendSubscribe 0
    }

    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]  \
      -fill both -expand 1 -ipadx 4
    
    label $w.frall.head -text [::msgcat::mc Subscribe] -font $sysFont(l)  \
      -anchor w -padx 10 -pady 4
    pack $w.frall.head -side top -fill both -expand 1
    message $w.frall.msg -width 260 -font $sysFont(s)  \
      -text [::msgcat::mc jasubwant $jid]
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Any -status attribute?
    if {[info exists argsArr(-status)] && [string length $argsArr(-status)]} {
    	set txt "Message: \"$argsArr(-status)\""
    	label $w.frall.status -wraplength 260 -text $txt
    	pack $w.frall.status -side top -anchor w -padx 10
    }
        
    # Some action buttons.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.lvcard -text "[::msgcat::mc jasubgetvcard]:" -font $sysFont(sb) \
      -anchor e
    button $frmid.bvcard -text "[::msgcat::mc {Get vCard}]..."   \
      -command [list ::VCard::Fetch .kass other $jid]
    label $frmid.lmsg -text [::msgcat::mc jasubsndmsg]   \
      -font $sysFont(sb) -anchor e
    button $frmid.bmsg -text "[::msgcat::mc Send]..."    \
      -command [list ::Jabber::Subscribe::SendMsg $uid]
    grid $frmid.lvcard -column 0 -row 0 -sticky e -padx 6 -pady 2
    grid $frmid.bvcard -column 1 -row 0 -sticky ew -padx 6 -pady 2
    grid $frmid.lmsg -column 0 -row 1 -sticky e -padx 6 -pady 2
    grid $frmid.bmsg -column 1 -row 1 -sticky ew -padx 6 -pady 2
    pack $frmid -side top -fill both -expand 1

    # The option part.
    set locals($uid,allow) 1
    set locals($uid,add) $jprefs(defSubscribe)
    set fropt $w.frall.fropt
    set frcont [LabeledFrame2 $fropt {Options}]
    pack $fropt -side top -fill both -ipadx 10 -ipady 6
    checkbutton $frcont.pres -text "  [::msgcat::mc jasuballow $jid]" \
      -variable [namespace current]::locals($uid,allow)
    
    checkbutton $frcont.add -text "  [::msgcat::mc jasubadd $jid]" \
      -variable [namespace current]::locals($uid,add)
    pack $frcont.pres $frcont.add -side top -anchor w -padx 10 -pady 4
    set frsub [frame $frcont.frsub]
    pack $frsub -expand 1 -fill x -side top
    label $frsub.lnick -text "[::msgcat::mc {Nick name}]:" -font $sysFont(sb) \
      -anchor e
    entry $frsub.enick -width 26  \
      -textvariable [namespace current]::locals($uid,name)
    label $frsub.lgroup -text "[::msgcat::mc Group]:" -font $sysFont(sb) -anchor e
    
    ::combobox::combobox $frsub.egroup -font $sysFont(s) -width 18  \
      -textvariable [namespace current]::locals($uid,group)
    eval {$frsub.egroup list insert end} "None $allGroups"
    
    grid $frsub.lnick -column 0 -row 0 -sticky e
    grid $frsub.enick -column 1 -row 0 -sticky ew
    grid $frsub.lgroup -column 0 -row 1 -sticky e
    grid $frsub.egroup -column 1 -row 1 -sticky w
    
    # If we may NOT send a 'subscribe' presence to this user.
    if {!$maySendSubscribe} {
	set locals($uid,add) 0
	$frcont.add configure -state disabled
	$frsub.enick configure -state disabled
	$frsub.egroup configure -state disabled
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Accept] -width 8 -default active \
      -command [list [namespace current]::Doit $uid]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Deny] -width 8   \
      -command [list [namespace current]::Cancel $uid]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btconn invoke"
    focus $w
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    # Cleanup.
    set finito $locals($uid,finished)
    foreach key [array names locals "$uid,*"] {
	unset locals($key)
    }
    return [expr {($finito <= 0) ? "deny" : "accept"}]
}

proc ::Jabber::Subscribe::SendMsg {uid} {
    global  wDlgs
    variable locals   
        
    ::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to $locals($uid,jid)
}

# Jabber::Subscribe::Doit --
#
#	Execute the subscription.

proc ::Jabber::Subscribe::Doit {uid} {    
    variable locals   
    upvar ::Jabber::jstate jstate
    
    set jid $locals($uid,jid)
    ::Jabber::Debug 2 "::Jabber::Subscribe::Doit jid=$jid, locals($uid,add)=$locals($uid,add), locals($uid,allow)=$locals($uid,allow)"
    
    # Accept (allow) or deny subscription.
    if {$locals($uid,allow)} {
	$jstate(jlib) send_presence -to $jid -type "subscribed"
    } else {
	$jstate(jlib) send_presence -to $jid -type "unsubscribed"
    }
	
    # Add user to my roster. Send subscription request.	
    if {$locals($uid,add)} {
	set arglist {}
	if {[string length $locals($uid,name)]} {
	    lappend arglist -name $locals($uid,name)
	}
	if {($locals($uid,group) != "") && ($locals($uid,group) != "None")} {
	    lappend arglist -groups [list $locals($uid,group)]
	}
	eval {$jstate(jlib) roster_set $jid ::Jabber::Subscribe::ResProc} \
	  $arglist
	$jstate(jlib) send_presence -to $jid -type "subscribe"
    }
    set locals($uid,finished) 1
    destroy $locals($uid,wtop)
}

proc ::Jabber::Subscribe::Cancel {uid} {    
    variable locals   
    upvar ::Jabber::jstate jstate
    
    set jid $locals($uid,jid)

    ::Jabber::Debug 2 "::Jabber::Subscribe::Cancel jid=$jid"
    
    # Deny presence to this user.
    $jstate(jlib) send_presence -to $jid -type {unsubscribed}

    set locals($uid,finished) 0
    destroy $locals($uid,wtop)
}

# Jabber::Subscribe::ResProc --
#
#       This is our callback proc when setting the roster item from the
#       subscription dialog. Catch any errors here.

proc ::Jabber::Subscribe::ResProc {jlibName what} {
    
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Subscribe::ResProc: jlibName=$jlibName, what=$what"

    if {[string equal $what "error"]} {
	tk_messageBox -type ok -message "We got an error from the\
	  Jabber::Subscribe::ResProc callback"
    }
    
}

# The ::Jabber::Conference:: namespace -----------------------------------------

# This uses the 'jabber:iq:conference' namespace and therefore requires
# that we use the 'jabber:iq:browse' for this to work.
# We only handle the enter/create dialogs here since the rest is handled
# in ::GroupChat::
# The 'jabber:iq:conference' is in a transition to be replaced by MUC.
# 
# Added MUC stuff...

namespace eval ::Jabber::Conference:: {

    # Keep track of me for each room.
    # locals($roomJid,own) {room@server/hash nickname}
    variable locals
    variable enteruid 0
    variable createuid 0
    variable dlguid 0
}

# Jabber::Conference::BuildEnter --
#
#       Initiates the process of entering a room using the
#       'jabber:iq:conference' method.
#       
# Arguments:
#       args        -server, -roomjid, -roomname, -autoget 0/1
#       
# Results:
#       "cancel" or "enter".
     
proc ::Jabber::Conference::BuildEnter {args} {
    global  this sysFont wDlgs

    variable enteruid
    variable dlguid
    variable UItype 2
    variable canHeight 120
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::BuildEnter"
    array set argsArr $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::enter[incr enteruid]
    variable $token
    upvar 0 $token enter
    
    set w $wDlgs(jenterroom)[incr dlguid]    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc {Enter Room}]
    set enter(w) $w
    array set enter {
	finished    -1
	server      ""
	roomname    ""
    }
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 280  -justify left -font $sysFont(s)  \
    	-text [::msgcat::mc jamessconfmsg]
    pack $w.frall.msg -side top -anchor w -padx 2 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -fill x
    label $frtop.lserv -text "[::msgcat::mc {Conference server}]:" \
      -font $sysFont(sb) 
    
    set confServers [$jstate(browse) getconferenceservers]
    
    ::Jabber::Debug 2 "BuildEnterRoom: confServers='$confServers'"

    set wcomboserver $frtop.eserv
    set wcomboroom $frtop.eroom

    ::combobox::combobox $wcomboserver -width 20 -font $sysFont(s)  \
      -textvariable $token\(server) -editable 0  \
      -command [list [namespace current]::ConfigRoomList $wcomboroom]
    eval {$frtop.eserv list insert end} $confServers
    label $frtop.lroom -text "[::msgcat::mc {Room name}]:" -font $sysFont(sb)
    
    # Find the default conferencing server.
    if {[info exists argsArr(-server)]} {
	set enter(server) $argsArr(-server)
    } elseif {[llength $confServers]} {
	set enter(server) [lindex $confServers 0]
    }
    set roomList {}
    if {[string length $enter(server)] > 0} {
	set allRooms [$jstate(browse) getchilds $enter(server)]
	
	::Jabber::Debug 2 "BuildEnterRoom: allRooms='$allRooms'"
	
	foreach roomJid $allRooms {
	    regexp {([^@]+)@.+} $roomJid match room
	    lappend roomList $room
	}
    }
    ::combobox::combobox $wcomboroom -width 20 -font $sysFont(s)   \
      -textvariable $token\(roomname) -editable 0
    eval {$frtop.eroom list insert end} $roomList
    if {[info exists argsArr(-roomjid)]} {
	regexp {^([^@]+)@([^/]+)} $argsArr(-roomjid) match enter(roomname)  \
	  enter(server)	
	$wcomboserver configure -state disabled
	$wcomboroom configure -state disabled
    }
    if {[info exists argsArr(-server)]} {
	set enter(server) $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    if {[info exists argsArr(-roomname)]} {
	set enter(roomname) $argsArr(-roomname)
	$wcomboroom configure -state disabled
    }

    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $frtop.eserv -column 1 -row 0 -sticky w
    grid $frtop.lroom -column 0 -row 1 -sticky e
    grid $frtop.eroom -column 1 -row 1 -sticky w

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
        
    if {$UItype == 0} {
	set wfr $w.frall.frlab
	set wcont [LabeledFrame2 $wfr [::msgcat::mc Specifications]]
	pack $wfr -side top -fill both -padx 2 -pady 2
	
	set wbox $wcont.box
	frame $wbox
	pack $wbox -side top -fill x -padx 4 -pady 10
	pack [label $wbox.la -textvariable $token\(stattxt)]  \
	  -padx 0 -pady 10
    }
    
    if {$UItype == 2} {
	
	# Not same wbox as above!!!
	set wbox $w.frall.frmid
	::Jabber::Forms::BuildScrollForm $wbox -height $canHeight \
	  -width 240
	pack $wbox -side top -fill both -expand 1 -padx 8 -pady 4
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtenter $frbot.btenter
    set wbtget $frbot.btget
    pack [button $wbtget -text [::msgcat::mc Get] -width 8 -default active \
      -command [list [namespace current]::EnterGet $token]]  \
      -side right -padx 5 -pady 5
    pack [button $wbtenter -text [::msgcat::mc Enter] -width 8 -state disabled \
      -command [list [namespace current]::DoEnter $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::CancelEnter $token]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
        
    wm resizable $w 0 0

    set enter(wsearrows) $wsearrows
    set enter(wcomboserver) $wcomboserver
    set enter(wcomboroom) $wcomboroom
    set enter(wbtget) $wbtget
    set enter(wbtenter) $wbtenter
    set enter(wbox) $wbox
    set enter(stattxt) "-- [::msgcat::mc jasearchwait] --"    
        
    # Grab and focus.
    set oldFocus [focus]
    
    if {[info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	::Jabber::Conference::EnterGet $token
    }
    #bind $w <Return> "$wbtget invoke"
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {focus $oldFocus}
    set finished $enter(finished)
    unset enter
    return [expr {($finished <= 0) ? "cancel" : "enter"}]
}

proc ::Jabber::Conference::CancelEnter {token} {
    variable $token
    upvar 0 $token enter

    set enter(finished) 0
    catch {destroy $enter(w)}
}

proc ::Jabber::Conference::ConfigRoomList {wcomboroom wcombo pickedServ} {    
    upvar ::Jabber::jstate jstate

    set allRooms [$jstate(browse) getchilds $pickedServ]
    set roomList {}
    foreach roomJid $allRooms {
	regexp {([^@]+)@.+} $roomJid match room
	lappend roomList $room
    }
    $wcomboroom list delete 0 end
    eval {$wcomboroom list insert end} $roomList
}

proc ::Jabber::Conference::EnterGet {token} {    
    variable $token
    upvar 0 $token enter
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    # Verify.
    if {($enter(roomname) == "") || ($enter(server) == "")} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessenterroomempty]]
	return
    }	
    $enter(wcomboserver) configure -state disabled
    $enter(wcomboroom) configure -state disabled
    $enter(wbtget) configure -state disabled
    set enter(stattxt) "-- [::msgcat::mc jawaitserver] --"
    
    # Send get enter room.
    set roomJid [string tolower $enter(roomname)@$enter(server)]
    
    $jstate(jlib) conference get_enter $roomJid  \
      [list [namespace current]::EnterGetCB $token]

    $enter(wsearrows) start
}

proc ::Jabber::Conference::EnterGetCB {token jlibName type subiq} {   
    variable $token
    upvar 0 $token enter
    upvar ::Jabber::jstate jstate
    variable UItype
    
    ::Jabber::Debug 2 "::Jabber::Conference::EnterGetCB type=$type, subiq='$subiq'"
    
    if {![info exists enter(w)]} {
	return
    }
    $enter(wsearrows) stop
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrconfget [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }
    $enter(wbtenter) configure -state normal -default active
    $enter(wbtget) configure -state normal -default disabled

    set childList [wrapper::getchildren $subiq]

    if {$UItype == 0} {
	catch {destroy $enter(wbox)}
	::Jabber::Forms::Build $enter(wbox) $childList -template "room"  \
	-width 260
	pack $enter(wbox) -side top -fill x -padx 2 -pady 10
    }
    if {$UItype == 2} {
	::Jabber::Forms::FillScrollForm $enter(wbox) $childList -template "room"
    }
}

proc ::Jabber::Conference::DoEnter {token} {   
    variable $token
    upvar 0 $token enter
    upvar ::Jabber::jstate jstate
    variable UItype
    
    $enter(wsearrows) start

    if {$UItype != 2} {
    	set subelements [::Jabber::Forms::GetXML $enter(wbox)]
    } else {
    	set subelements [::Jabber::Forms::GetScrollForm $enter(wbox)]
    }
    set roomJid [string tolower $enter(roomname)@$enter(server)]
    $jstate(jlib) conference set_enter $roomJid $subelements  \
      [list [namespace current]::ResultCallback $roomJid]
    
    # This triggers the tkwait, and destroys the enter dialog.
    set enter(finished) 1
    catch {destroy $enter(w)}
}

# Jabber::Conference::ResultCallback --
#
#       This is our callback procedure from 'jabber:iq:conference' and muc stuffs.

proc ::Jabber::Conference::ResultCallback {roomJid jlibName type subiq} {
    variable locals
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::ResultCallback roomJid=$roomJid, type=$type, subiq='$subiq'"
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessconffailed $roomJid [lindex $subiq 0] [lindex $subiq 1]]]
    } else {
	
	# Handle the wb UI. Could be the room's name.
	#set jstate(.,tojid) $roomJid
    
	# This should be something like:
	# <query><id>myroom@server/7y3jy7f03</id><nick/>snuffie<nick><query/>
	# Use it to cache own room jid.
	
	#  OUTDATED!!!!!!!!!!!!!
	
	foreach child [wrapper::getchildren $subiq] {
	    set tagName [lindex $child 0]
	    set value [lindex $child 3]
	    set $tagName $value
	}
	if {[info exists id] && [info exists nick]} {
	    set locals($roomJid,own) [list $id $nick]
	}
	if {[info exists name]} {
	    set locals($roomJid,roomname) $name
	}
    }
}

#... Create Room ...............................................................

# Jabber::Conference::BuildCreate --
#
#       Initiates the process of creating a room.
#       
# Arguments:
#       args    -server, -roomname
#       
# Results:
#       "cancel" or "create".
     
proc ::Jabber::Conference::BuildCreate {args} {
    global  this sysFont wDlgs
    
    variable createuid
    variable dlguid
    variable UItype 2
    variable canHeight 250
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    array set argsArr $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::create[incr createuid]
    variable $token
    upvar 0 $token create
    
    set w $wDlgs(jcreateroom)[incr dlguid]    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	
    }
    wm title $w [::msgcat::mc {Create Room}]

    set create(w) $w
    array set create {
	finished    -1
	server      ""
	roomname    ""
    }
    
    # Only temporary setting of 'usemuc'.
    if {$jprefs(prefgchatproto) == "muc"} {
	set create(usemuc) 1
    } else {
	set create(usemuc) 0
    }
   
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -font $sysFont(s) -anchor w -justify left  \
      -text [::msgcat::mc jacreateroom] -width 300
    pack $w.frall.msg -side top -fill x -anchor w -padx 10 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -expand 0 -anchor w -padx 10
    label $frtop.lserv -text "[::msgcat::mc {Conference server}]:"  \
      -font $sysFont(sb)
    
    set confServers [$jstate(browse) getconferenceservers]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20 -font $sysFont(s)   \
      -textvariable $token\(server) -editable 0
    eval {$frtop.eserv list insert end} $confServers
    
    # Find the default conferencing server.
    if {[llength $confServers]} {
	set create(server) [lindex $confServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set create(server) $argsArr(-server)
	$frtop.eserv configure -state disabled
    }
    
    label $frtop.lroom -text "[::msgcat::mc {Room name}]:" \
      -font $sysFont(sb)    
    entry $frtop.eroom -textvariable $token\(roomname)  \
      -validate key -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frtop.lnick -text "[::msgcat::mc {Nick name}]:"  \
      -font $sysFont(sb)    
    entry $frtop.enick -textvariable $token\(nickname)  \
      -validate key -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frtop.ldesc -text "[::msgcat::mc Specifications]:" -font $sysFont(sb)
    label $frtop.lstat -textvariable $token\(stattxt)
    
    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $frtop.eserv -column 1 -row 0 -sticky ew
    grid $frtop.lroom -column 0 -row 1 -sticky e
    grid $frtop.eroom -column 1 -row 1 -sticky ew
    grid $frtop.lnick -column 0 -row 2 -sticky e
    grid $frtop.enick -column 1 -row 2 -sticky ew
    grid $frtop.ldesc -column 0 -row 3 -sticky e -padx 4 -pady 2
    grid $frtop.lstat -column 1 -row 3 -sticky w
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtenter $frbot.btenter
    set wbtget $frbot.btget
    pack [button $wbtget -text [::msgcat::mc Get] -width 8 -default active \
      -command [list [namespace current]::CreateGet $token]]  \
      -side right -padx 5 -pady 5
    pack [button $wbtenter -text [::msgcat::mc Create] -width 8 -state disabled \
      -command [list [namespace current]::DoCreate $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::CancelCreate $token]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side bottom -fill x -expand 0 -padx 8 -pady 6
	
    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
    
    if {$UItype == 0} {
	set wfr $w.frall.frlab
	set wcont [LabeledFrame2 $wfr [::msgcat::mc Specifications]]
	pack $wfr -side top -fill both -padx 2 -pady 2
	
	set wbox $wcont.box
	frame $wbox
	pack $wbox -side top -fill x -padx 4 -pady 10
	pack [label $wbox.la -textvariable $token\(stattxt)]  \
	  -padx 0 -pady 10
    }
    
    if {$UItype == 2} {
	
	# Not same wbox as above!!!
	set wbox $w.frall.frmid
	::Jabber::Forms::BuildScrollForm $wbox -height $canHeight \
	  -width 320
	pack $wbox -side top -fill both -expand 1 -padx 8 -pady 4
    }
    
    set create(wsearrows) $wsearrows
    set create(wcomboserver) $wcomboserver
    set create(wbtget) $wbtget
    set create(wbtenter) $wbtenter
    set create(wbox) $wbox
    set create(stattxt) "-- [::msgcat::mc jasearchwait] --"
    
    bind $w <Return> [list $wbtget invoke]
    
    # Grab and focus.
    focus $frtop.eroom
    
    # Wait here for a button press and window to be destroyed. BAD?
    tkwait window $w
    
    catch {focus $oldFocus}
    set finished $create(finished)
    unset create
    return [expr {($finished <= 0) ? "cancel" : "create"}]
}

proc ::Jabber::Conference::CancelCreate {token} {
    variable $token
    upvar 0 $token create
    upvar ::Jabber::jstate jstate
    
    set roomJid [string tolower $create(roomname)@$create(server)]
    if {$create(usemuc) && ($roomJid != "")} {
	catch {$jstate(jlib) muc setroom $roomJid cancel}
    }
    set create(finished) 0
    catch {destroy $create(w)}
}

proc ::Jabber::Conference::CreateGet {token} {    
    variable $token
    upvar 0 $token create
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs

    # Figure out if 'conference' or 'muc' protocol.
    if {$jprefs(prefgchatproto) == "muc"} {
	set create(usemuc) [$jstate(browse) havenamespace $create(server)  \
	  "http://jabber.org/protocol/muc"]
    } else {
	set create(usemuc) 0
    }
    
    # Verify.
    if {($create(server) == "") || ($create(roomname) == "") || \
    ($create(usemuc) && ($create(nickname) == ""))} {
	tk_messageBox -type ok -icon error  \
	  -message "Must provide a nickname to use in the room"
	return
    }	
    $create(wcomboserver) configure -state disabled
    $create(wbtget) configure -state disabled
    set create(stattxt) "-- [::msgcat::mc jawaitserver] --"
    
    # Send get create room. NOT the server!
    set roomJid [string tolower $create(roomname)@$create(server)]
    set create(roomjid) $roomJid

    ::Jabber::Debug 2 "::Jabber::Conference::CreateGet usemuc=$create(usemuc)"

    if {$create(usemuc)} {
	$jstate(jlib) muc create $roomJid $create(nickname) \
	  [list [namespace current]::CreateMUCCB $token]
    } else {
	$jstate(jlib) conference get_create $roomJid  \
	  [list [namespace current]::CreateGetGetCB $token]
    }

    $create(wsearrows) start
}

# Jabber::Conference::CreateMUCCB --
#
#       Presence callabck from the 'muc create' command.
#
# Arguments:
#       jlibName 
#       type    presence typ attribute, 'available' etc.
#       args    -from, -id, -to, -x ...
#       
# Results:
#       None.

proc ::Jabber::Conference::CreateMUCCB {token jlibName type args} {
    variable $token
    upvar 0 $token create
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::CreateMUCCB type=$type, args='$args'"
    
    if {![info exists create(w)]} {
	return
    }
    $create(wsearrows) stop
    array set argsArr $args
    
    if {$type == "error"} {
    	set errcode ???
    	set errmsg ""
    	if {[info exists argsArr(-error)]} {
    	    set errcode [lindex $argsArr(-error) 0]
    	    set errmsg [lindex $argsArr(-error) 1]
	}
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrconfgetcre $errcode $errmsg]]
        set create(stattxt) "-- [::msgcat::mc jasearchwait] --"
        $create(wcomboserver) configure -state normal
        $create(wbtget) configure -state normal
	return
    }
    
    # We should check that we've got an 
    # <created xmlns='http://jabber.org/protocol/muc#owner'/> element.
    if {![info exists argsArr(-created)]} {
    
    }
    $jstate(jlib) muc getroom $create(roomjid)  \
      [list [namespace current]::CreateGetGetCB $token]
}

# Jabber::Conference::CreateGetGetCB --
#
#

proc ::Jabber::Conference::CreateGetGetCB {token jlibName type subiq} {    
    variable $token
    upvar 0 $token create
    
    variable UItype
    variable canHeight
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::CreateGetGetCB type=$type"
    
    if {![info exists create(w)]} {
	return
    }
    $create(wsearrows) stop
    set create(stattxt) ""
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrconfgetcre [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }

    set childList [wrapper::getchildren $subiq]

    if {$UItype == 0} {
	catch {destroy $create(wbox)}
	::Jabber::Forms::Build $create(wbox) $childList -template "room" -width 320
	pack $create(wbox) -side top -fill x -padx 2 -pady 10
    }
    if {$UItype == 2} {
	::Jabber::Forms::FillScrollForm $create(wbox) $childList -template "room"
    }
    
    $create(wbtenter) configure -state normal -default active
    $create(wbtget) configure -state normal -default disabled
    bind $create(w) <Return> {}
}

proc ::Jabber::Conference::DoCreate {token} {   
    variable $token
    upvar 0 $token create

    variable UItype
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::DoCreate"

    $create(wsearrows) stop
    
    set roomJid [string tolower $create(roomname)@$create(server)]
    if {$UItype != 2} {
    	set subelements [::Jabber::Forms::GetXML $create(wbox)]
    } else {
    	set subelements [::Jabber::Forms::GetScrollForm $create(wbox)]
    }
    
    # Ask jabberlib to create the room for us.
    if {$create(usemuc)} {
	$jstate(jlib) muc setroom $roomJid form -form $subelements \
	  -command [list [namespace current]::ResultCallback $roomJid]
    } else {
	$jstate(jlib) conference set_create $roomJid $subelements  \
	  [list [namespace current]::ResultCallback $roomJid]
    }
	
    # Cache groupchat protocol type (muc|conference|gc-1.0).
    if {$create(usemuc)} {
	::Jabber::GroupChat::SetProtocol $roomJid "muc"
    } else {
	::Jabber::GroupChat::SetProtocol $roomJid "conference"
    }
    
    # This triggers the tkwait, and destroys the create dialog.
    set create(finished) 1
    catch {destroy $create(w)}
}

# The ::Jabber::Search:: namespace ---------------------------------------------

namespace eval ::Jabber::Search:: {

    # Wait for this variable to be set.
    variable finished  
}

# Jabber::Search::Build --
#
#       Initiates the process of searching a service.
#       
# Arguments:
#       w           toplevel widget
#       args   -server, -autoget 0/1
#       
# Results:
#       .
     
proc ::Jabber::Search::Build {w args} {
    global  this sysFont prefs

    variable wtop
    variable wbox
    variable wbtsearch
    variable wbtget
    variable wcomboserver
    variable wtb
    variable wxsc
    variable wysc
    variable woob
    variable server
    variable wsearrows
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    set finished -1
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc {Search Service}]
    set wtop $w
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 6 -ipady 4
    
    # Left half.
    set wleft $w.frall.fl
    pack [frame $wleft] -side left -fill y
    
    # Right half.
    set wright $w.frall.fr
    pack [frame $wright] -side right -expand 1 -fill both
    
    message $wleft.msg -width 200 -font $sysFont(s)  \
      -text [::msgcat::mc jasearch] -anchor w
    pack $wleft.msg -side top -fill x -anchor w -padx 4 -pady 2
    set frtop $wleft.top
    pack [frame $frtop] -side top -fill x -anchor w -padx 4 -pady 2
    label $frtop.lserv -text "[::msgcat::mc {Search Service}]:" -font $sysFont(sb)
    
    # Button part.
    set frbot [frame $wleft.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtsearch $frbot.btenter
    pack [button $wbtsearch -text [::msgcat::mc Search] -width 8 -state disabled \
      -command [namespace current]::DoSearch]  \
      -side right -padx 5 -pady 2
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command "destroy $w"]  \
      -side right -padx 5 -pady 2
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 2
    pack $frbot -side bottom -fill x -padx 8 -pady 6
    
    # OOB alternative.
    set woob [frame $wleft.foob]
    pack $woob -side bottom -fill x -padx 8 -pady 0
    
    # Get all (browsed) services that support search.
    set searchServ [$jstate(jlib) service getjidsfor "search"]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20 -font $sysFont(s)   \
      -textvariable [namespace current]::server -editable 0
    eval {$frtop.eserv list insert end} $searchServ
    
    # Find the default search server.
    if {[llength $searchServ]} {
	set server [lindex $searchServ 0]
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    
    # Get button.
    set wbtget $frtop.btget
    button $wbtget -text [::msgcat::mc Get] -width 6 -default active \
      -command [list ::Jabber::Search::Get]

    grid $frtop.lserv -sticky w
    grid $wcomboserver -row 1 -column 0 -sticky ew
    grid $wbtget -row 1 -column 1 -sticky e -padx 2

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
    set wfr $wleft.frlab
    set wcont [LabeledFrame2 $wfr [::msgcat::mc {Search Specifications}]]
    pack $wfr -side top -fill both -padx 2 -pady 2

    set wbox [frame $wcont.box]
    pack $wbox -side left -fill both -padx 4 -pady 4 -expand 1
    pack [label $wbox.la -textvariable "[namespace current]::stattxt"]  \
      -padx 0 -pady 10 -side left
    set stattxt "-- [::msgcat::mc jasearchwait] --"
    
    # The Search result tablelist widget.
    set frsearch $wright.se
    pack [frame $frsearch -borderwidth 1 -relief sunken] -side top -fill both \
      -expand 1 -padx 4 -pady 4
    set wtb $frsearch.tb
    set wxsc $frsearch.xsc
    set wysc $frsearch.ysc
    tablelist::tablelist $wtb \
      -columns [list 60 [::msgcat::mc {Search results}]]  \
      -font $sysFont(s) -labelfont $sysFont(s) -background white  \
      -xscrollcommand [list $wxsc set] -yscrollcommand [list $wysc set]  \
      -labelbackground #cecece -stripebackground #dedeff -width 60 -height 20
    #-labelcommand "[namespace current]::LabelCommand"  \
    
    scrollbar $wysc -orient vertical -command [list $wtb yview]
    scrollbar $wxsc -orient horizontal -command [list $wtb xview]
    grid $wtb $wysc -sticky news
    grid $wxsc -sticky ew -column 0 -row 1
    grid rowconfigure $frsearch 0 -weight 1
    grid columnconfigure $frsearch 0 -weight 1
    
    wm minsize $w 400 320
            
    # If only a single search service, or if specified as argument.
    if {([llength $searchServ] == 1) ||  \
      [info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	::Jabber::Search::Get
    }
}

proc ::Jabber::Search::Get { } {    
    variable server
    variable wsearrows
    variable wcomboserver
    variable wbtget
    variable wtb
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    # Verify.
    if {[string length $server] == 0} {
	tk_messageBox -type ok -icon error  \
	  -message [::msgcat::mc jamessregnoserver]
	return
    }	
    $wcomboserver configure -state disabled
    $wbtget configure -state disabled
    set stattxt "-- [::msgcat::mc jawaitserver] --"
    
    # Send get register.
    $jstate(jlib) search_get $server ::Jabber::Search::GetCB    
    $wsearrows start
    
    $wtb configure -columns [list 60 [::msgcat::mc {Search results}]]
    $wtb delete 0 end
}

# Jabber::Search::GetCB --
#
#       This is the 'get' iq callback.
#       It should be possible to receive multiple callbacks for a single
#       search, but this is untested.

proc ::Jabber::Search::GetCB {jlibName type subiq} {
    global  sysFont
    
    variable wtop
    variable wbox
    variable wtb
    variable wxsc
    variable wysc
    variable woob
    variable wsearrows
    variable wbtsearch
    variable wbtget
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Search::GetCB type=$type, subiq='$subiq'"
    
    if {![winfo exists $wtop]} {
	return
    }
    $wsearrows stop
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrsearch [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }
    catch {destroy $wbox}
    catch {destroy $woob.oob}
    set subiqChildList [wrapper::getchildren $subiq]
    
    # We must figure out if we have an oob thing.
    set hasOOBForm 0
    foreach c $subiqChildList {
	if {[string equal [lindex $c 0] "x"]} {
	    array set cattrArr [lindex $c 1]
	    if {[info exists cattrArr(xmlns)] &&  \
	      [string equal $cattrArr(xmlns) "jabber:x:oob"]} {
		set hasOOBForm 1
		set xmlOOBElem $c
	    }
	}
    }
	
    # Build form dynamically from XML.
    ::Jabber::Forms::Build $wbox $subiqChildList -template "search" -width 160
    pack $wbox -side left -padx 2 -pady 10
    if {$hasOOBForm} {
	set woobtxt [::Jabber::OOB::BuildText ${woob}.oob $xmlOOBElem]
	pack $woobtxt -side top -fill x
    }
    $wbtsearch configure -state normal -default active
    $wbtget configure -state normal -default disabled   
}

proc ::Jabber::Search::DoSearch { } {    
    variable server
    variable wsearrows
    variable wbox
    variable wtb
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    $wsearrows start
    $wtb delete 0 end

    # Returns the hierarchical xml list starting with the <x> element.
    set subelements [::Jabber::Forms::GetXML $wbox]    
    $jstate(jlib) search_set $server  \
      [list [namespace current]::ResultCallback $server] -subtags $subelements
}

# Jabber::Search::ResultCallback --
#
#       This is the 'result' and 'set' iq callback We may get a number of server
#       pushing 'set' elements, finilized by the 'result' element.
#       
#       Update: the situation with jabber:x:data seems unclear here.
#       
# Arguments:
#       server:
#       type:       "ok", "error", or "set"
#       subiq:

proc ::Jabber::Search::ResultCallback {server type subiq} {   
    variable wtop
    variable wtb
    variable wbox
    variable wsearrows
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Search::ResultCallback server=$server, type=$type, \
      subiq='$subiq'"
    
    if {![winfo exists $wtop]} {
	return
    }
    $wsearrows stop
    if {[string equal $type "error"]} {
	foreach {ecode emsg} [lrange $subiq 0 1] break
	if {$ecode == "406"} {
	    set msg "There was an invalid field. Please correct it: $emsg"
	} else {
	    set msg "Failed searching service. Error code $ecode with message: $emsg"
	}
	tk_messageBox -type ok -icon error -message [FormatTextForMessageBox $msg]
	return
    } elseif {[string equal $type "ok"]} {
	
	# This returns the search result and sets the reported stuff.
	set columnSpec {}
	set resultList [::Jabber::Forms::ResultList $wbox $subiq]
	foreach {var label} [::Jabber::Forms::GetReported $wbox] {
	    lappend columnSpec 0 $label	    
	}
	$wtb configure -columns $columnSpec
	if {[llength $resultList] == 0} {
	    $wtb insert end {{No matches found}}
	} else {
	    foreach row $resultList {
		$wtb insert end $row
	    }
	}
    }
}

#-------------------------------------------------------------------------------
