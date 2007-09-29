
	  The Coccinella : Jabber application with Whiteboard
	  ---------------------------------------------------

		       by Mats Bengtsson

First:

    The most recent and up to data information you probably find at the
    Coccinella home http://coccinella.im

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

    * Jabber Server: The Jabber Instant Messaging system is an XML based 
      system that works similar to ICQ, AIM etc.  It delivers messages 
      seamlessly between many instant messaging system and Jabber clients.  
      This application is a Jabber client, but it is not a normal Jabber 
      client since it delivers much more than just text messages.  Visit 
      "www.jabber.org" or "www.jabberstudio.org" for more information, 
      and to obtain your own server.

    * To get started with a Jabber server, register an account (if you 
      haven't already) using the Jabber/New Account...  menu, and fill in 
      the fields.  When you later log on, you do it from the Jabber/Login...
      menu, and pick the server you have an account at. Or just use the
      Setup Assistant menu command.

Installation:

    * No installation whatsoever is needed. Just unzip and double click.

    * If you want to run from sources the simplest is to get a tclkit from
      http://www.equi4.com/pub/tk/downloads.html, 8.4.6 or later. A complete
      Tcl/Tk installation can be obtained from http://tcl.activestate.com.
      Be sure to have at least 8.4.6 for Coccinella 0.95.9 or later.

Documentation:

    See the home site for current info: http://coccinella.im

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
    Korean:     Dylan Park

Developers:

    The main SourceForge page: http://coccinella.sourceforge.net/
    For building the coccinella from sources see: 
      http://coccinella.sourceforge.net/build/

    o It is possible to run and build the Coccinella without whiteboard support.
      You just drag out the coccinella/whiteboard/ folder.

Distribution:

    It is distributed under the standard GPL license.
    (c) Copyright by Mats Bengtsson (1999-2007).
    Whiteboard tool buttons are stolen from Gimp and slightly changed (Thank You!).
    Other graphics elements, see README-Crystal-icons.

Home:

    The present home of the Coccinella is at
    "http://coccinella.im", where links to the extensions also 
    can be found.
    Look at "http://coccinella.sourceforge.net" which is the official
    developer home.

The Beetle:

    Don't be afraid for the 'Coccinella' (ladybug), it's tame!

Who:

    It has been developed by:
    Mats Bengtsson   
    matben@users.sourceforge.net

--------------------------------------------------------------------------------
