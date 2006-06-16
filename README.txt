
	  The Coccinella : Jabber application with Whiteboard
	  ---------------------------------------------------

		       by Mats Bengtsson



What is this?

    This is a  Jabber  client which has a  complete system  for instant 
    messages, chat, groupchat etc. But more importantly, it extends the
    Jabber instant messages system to a kind of whiteboard system. Just
    like ordinary text messages,  you may send complete  whiteboards to 
    other users, share a whiteboard in a one-to-one chat, or groupchat.

    	Perhaps it is  better to describe it  using the  desktop  metaphor.
    Just like your computer has a desktop with files, symbols  and windows,
    this whiteboard is  similar, but  instead of using  files  and folders,
    it actually  shows the  contents of these files.  That is, for an image
    file we show the actual image, an mp3 is shown as a minimal player etc.
    This should work in a modular way using a plugin architecture; a plugin
    is responsible for a set of MIME types, how they should be displayed in
    the whiteboard, user interactions, any playback or whatever is relevant.
    And most importantly, these items are shared with other users in a form
    that  depends on the  type,  such as single  message (like an email), 
    one-to-one chat, or groupchat.

The Jabber system:

    The Coccinella can be configured into two main modes.  The services
    supported by these two modes are very different.  You switch between 
    these two modes using the Preferences/Preferences...  menu, and the
    "General/Network Setup" panel.
    	The recommended way of running this application is the Jabber way.

    * Jabber Server: The Jabber Instant Messaging system is an XML based 
      system that works similar to ICQ, AIM etc.  It delivers messages 
      seamlessly between many instant messaging system and Jabber clients.  
      This application is a Jabber client, but it is not a normal Jabber 
      client since it delivers much more than just text messages.  Visit 
      "www.jabber.org" or "www.jabberstudio.org" for more information, 
      and to obtain your own server.

      To get started with a Jabber server, register an account (if you 
      haven't already) using the Jabber/New Account...  menu, and fill in 
      the fields.  When you later log on, you do it from the Jabber/Login...
      menu, and pick the server you have an account at. Or just use the
      Setup Assistant menu command.

    * Peer-to-peer: This is the "raw" configuration, where users connect 
      directly to each other, and not via an external server.  This mode 
      does not deliver the kind of user administration that is supplied by 
      the Jabber system, such as contact lists, online/offline, offline 
      delivery etc. It is therefore NOT recommended to use.

Installation:

    * No installation whatsoever is needed. Just unzip and double click.

    * If you want to run from sources the simplest is to get a tclkit from
      http://www.equi4.com/pub/tk/downloads.html, 8.4.6 or later. A complete
      Tcl/Tk installation can be obtained from http://tcl.activestate.com.
      Be sure to have at least 8.4.6 for Coccinella 0.95.9 or later.

Testing:

    It is to be considered as a developer release, so beware.  *It is far 
    from being bug free*.  The current releases get tested on Mac OS X 10.2,
    Linux RH 9, Windows 2000, and Windows XP. 

    I would judge this as a beta quality application, which is 
    reflected in the version number ( < 1.0). No instabilities are known, 
    however.

Additional Notes:
    
    * This client delivers more data than an ordinary Jabber client, and 
      data may "get stuck" in the server if karma is too low. This only
      happend if you does a lot of drawings in a short period of time.

Documentation:

    The source code is the only documentation. At least so far ;-)
    See also the Info/Help menu.

    There are a few additional README files, README-sounds, README-resources,
    which may be helpful if you want to do customization.

Translations:

    Many thanks to contributors. See coccinella/msgs/README_encodings if you
    feel like contributing.

    Swedish:    myself
    German:     Hermann J. Beckers
    Dutch:      Sander Devrieze
    French:     Guillaume Ayoub
    Italian:    Mirko Graziani
    Spanish:    Nestor Diaz & Antonio Cano damas
    Polish:     Zbigniew Baniewski
    Danish:     Mogens Pedersen
    Russian:    Gescheit

Bug Reports:

    Either send them to me directly: matben@users.sourceforge.net , or report them
    at Source Forge: http://sourceforge.net/tracker/?group_id=68334&atid=520863
    This address can be reached via the Info/Report Bug menu.

Known Bugs:

    * Althogh the server is using a safe interpreter for the critical parts
      of canvas drawings which uses the dangerous eval, it probably does not 
      cover all possible attacks from an evil client.

    * If large items are transported between clients, such as images, or
      movies, operations on these items before they have been completely 
      received by remote clients are lost.

    * There are synchronization issues if two users happen to edit an item
      exactly simultanously. This applies only to some operations, and is 
      not very likely to happen, but must anyway be considered.

      Similar synchronization problems exist in some other areas, applets
      for instance.

    * It may sometimes happen that the internal settings become confused 
      which results in a corrupt preference file. If you suspect this then
      delete this file:
          Unix/Linux       ~/.coccinella/whiteboard
	  Windows          .../Coccinella/WBPREFS.TXT     (search for it)
	  Mac OS X         ~/Library/Preferences/Coccinella/Whiteboard Prefs

    * Printer support is still in its infacy. You may export the canvas to
      XML/SVG format which can be imported into a web browser using the free
      plugin from www.adobe.com, and print from inside your browser.

    * There are numerous "details" that need to be fixed. After all, it is an 
      alpha quality software!

    * If you run from sources: some versions of the ActiveState distro (8.4.10->)
      have problems with the Img package which can cause a startup crash.
      The solutions is to trash /usr/local/ActiveState/lib/Img. These versions
      may also create problems with the emoticon sets. If this happens try to
      run the single file executable tclkit for your platform instead, see:
      http://coccinella.sf.net for a link.

    As always, the code needs cleaning and restructuring.  If you want to see
    what is happening "inside" you may set the debug level to a nonzero value.
    You set this either in the source file Coccinella.tcl, or specified
    at the command line as:

    set argv "-debugLevel 4"

    and launch it. You need to have the source distribution and a Tcl/Tk
    installation to do this.
    As an alternative on mac and windows, pick the Jabber/Debug menu, and do:

    set debugLevel 4


XML/SVG:

    You may try using SVG for drawing. Start Coccinella with arguments:
    "-jprefs_useSVGT 1 -jprefs_getIPraw 0 -prefs_trptMethod http"
    Still in its infancy, though.

Distribution:

    It is distributed under the standard GPL license.
    (c) Copyright by Mats Bengtsson (1999-2005).
    Whiteboard tool buttons are stolen from Gimp and slightly changed (Thank You!).
    Other graphics elements, see README-Crystal-icons.

Home:

    The present home of the Coccinella is at
    "http://hem.fyristorg.com/matben", where links to the extensions also 
    can be found.
    Look at "http://coccinella.sourceforge.net" which is the official
    developer home.

The Beetle:

    Don't be afraid for the 'Coccinella' (ladybug), it's tame!

Special Contributions:

    * Raymond Tang: resolving links, adding ImageMagick support, local
      incoming dir...

Who:

    It has been developed by:

    Mats Bengtsson   
    matben@users.sourceforge.net
    phone: +46 13 136114

    MADE IN SWEDEN

--------------------------------------------------------------------------------
