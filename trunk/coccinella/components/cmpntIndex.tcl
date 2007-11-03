# See contrib/component.tcl for explanations.
#

component::attempt AppleEvents      [file join $dir AppleEvents.tcl]    ::AppleEvents::Init
component::attempt AutoUpdate       [file join $dir AutoUpdate.tcl]     ::AutoUpdate::Init
component::attempt BuddyPounce      [file join $dir BuddyPounce.tcl]    ::BuddyPounce::Init
component::attempt ChatShorts       [file join $dir ChatShorts.tcl]     ::ChatShorts::Init
component::attempt Geolocation      [file join $dir Geolocation.tcl]    ::Geolocation::Init
component::attempt GnomeMeeting     [file join $dir GMeeting.tcl]       ::GMeeting::Init
component::attempt ICQ              [file join $dir ICQ.tcl]            ::ICQ::Init
component::attempt IRCActions       [file join $dir IRCActions.tcl]     ::IRCActions::Init
component::attempt ImageMagic       [file join $dir ImageMagic.tcl]     ::ImageMagic::Init
component::attempt JivePhone        [file join $dir JivePhone.tcl]      ::JivePhone::Init
component::attempt MailtoURI        [file join $dir MailtoURI.tcl]      ::MailtoURI::Init
component::attempt LiveRosterImage  [file join $dir LiveRosterImage.tcl]  ::LiveRosterImage::Init
component::attempt MeBeam           [file join $dir MeBeam.tcl]         ::MeBeam::Init
component::attempt Mood             [file join $dir Mood.tcl]           ::Mood::Init
component::attempt Notifier         [file join $dir Notifier.tcl]       ::Notifier::Init
component::attempt NotifyOnline     [file join $dir NotifyOnline.tcl]   ::NotifyOnline::Init
component::attempt ParseStyledText  [file join $dir ParseStyledText.tcl]  ::ParseStyledText::Init
component::attempt ParseURI         [file join $dir ParseURI.tcl]       ::ParseURI::Init
component::attempt SlideShow        [file join $dir SlideShow.tcl]      ::SlideShow::Load  
component::attempt Sounds           [file join $dir Sounds.tcl]         ::Sounds::Load    
component::attempt Spell            [file join $dir Spell.tcl]          ::Spell::Init
component::attempt Speech           [file join $dir Speech.tcl]         ::Speech::Load    
component::attempt SpotLight        [file join $dir SpotLight.tcl]      ::SpotLight::Init    
component::attempt Totd             [file join $dir Totd.tcl]           ::Totd::Init
component::attempt TtkDialog        [file join $dir TtkDialog.tcl]      ::TtkDialog::Init
component::attempt URIRegistry      [file join $dir URIRegistry.tcl]    ::URIRegistry::Init
component::attempt URIRegisterKDE   [file join $dir URIRegisterKDE.tcl] ::URIRegisterKDE::Init
component::attempt UserActivity     [file join $dir UserActivity.tcl]   ::UserActivity::Init
component::attempt WhiteboardMK     [file join $dir WhiteboardMK.tcl]   ::WhiteboardMK::Init
component::attempt XMLConsole       [file join $dir XMLConsole.tcl]     ::XMLConsole::Init

if {[tk windowingsystem] eq "aqua"} {
    component::attempt Carbon       [file join $dir Carbon.tcl]         ::Carbon::Init
    component::attempt Growl        [file join $dir Growl.tcl]          ::Growl::Init
}

# This is just an example plugin. Uncomment to test.
# component::attempt ComponentExample [file join $dir ComponentExample.tcl] ::ComponentExample::Init
