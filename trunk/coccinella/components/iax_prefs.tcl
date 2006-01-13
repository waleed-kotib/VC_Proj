# iaxClient.tcl --
# 
#       iaxClient phone UI
#       
# $Id: iax_prefs.tcl,v 1.1 2006-01-13 13:23:12 matben Exp $
namespace eval ::iaxClientPrefs:: { }

proc ::iaxClientPrefs::Init { } {
    global  this    

    if {[catch {package require iaxclient}]} {
	return
    }

    component::register iaxClientPrefs  \
      "Provides iaxClient Phone Preferences"

    ::hooks::register prefsInitHook                  ::iaxClientPrefs::InitPrefsHook
    ::hooks::register prefsBuildHook                 ::iaxClientPrefs::BuildPrefsHook
    ::hooks::register prefsSaveHook                  ::iaxClientPrefs::SavePrefsHook
    ::hooks::register prefsCancelHook                ::iaxClientPrefs::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook          ::iaxClientPrefs::UserDefaultsHook
    ::hooks::register prefsDestroyHook               ::iaxClientPrefs::DestroyPrefsHook
}

################## Preferences Stuff ###################
proc ::iaxClientPrefs::InitPrefsHook { } {
    global  prefs

    set prefs(iaxPhone,user) ""
    set prefs(iaxPhone,password) 0
    set prefs(iaxPhone,host) 0
    set prefs(iaxPhone,cidnum) 0
    set prefs(iaxPhone,cidname) ""
    set prefs(iaxPhone,codec) ""
    set prefs(iaxPhone,inputDevices) ""
    set prefs(iaxPhone,outputDevices) ""
    set prefs(iaxPhone,agc) ""
    set prefs(iaxPhone,aagc) ""
    set prefs(iaxPhone,noise) ""
    set prefs(iaxPhone,comfort) ""
    set prefs(iaxPhone,echo) ""

    ::PrefUtils::Add [list  \
      [list prefs(iaxPhone,user) prefs_iaxPhone_user $prefs(iaxPhone,user)] \
      [list prefs(iaxPhone,password) prefs_iaxPhone_password $prefs(iaxPhone,password)] \
      [list prefs(iaxPhone,host) prefs_iaxPhone_host $prefs(iaxPhone,host)] \
      [list prefs(iaxPhone,cidnum) prefs_iaxPhone_cidnum $prefs(iaxPhone,cidnum)] \
      [list prefs(iaxPhone,cidname) prefs_iaxPhone_cidname $prefs(iaxPhone,cidname)] \
      [list prefs(iaxPhone,codec) prefs_iaxPhone_codec $prefs(iaxPhone,codec)] \
      [list prefs(iaxPhone,inputDevices) prefs_iaxPhone_inputDevices $prefs(iaxPhone,inputDevices)] \
      [list prefs(iaxPhone,outputDevices))     prefs_iaxPhone_outputDevices     $prefs(iaxPhone,outputDevices)] \
     [list prefs(iaxPhone,agc) prefs_iaxPhone_agc $prefs(iaxPhone,agc)] \
      [list prefs(iaxPhone,aagc) prefs_iaxPhone_aagc $prefs(iaxPhone,aagc)] \
      [list prefs(iaxPhone,noise) prefs_iaxPhone_noise $prefs(iaxPhone,noise)] \
      [list prefs(iaxPhone,comfort) prefs_iaxPhone_comfort $prefs(iaxPhone,comfort)] \
      [list prefs(iaxPhone,echo) prefs_iaxPhone_echo $prefs(iaxPhone,echo)] ] 

}

proc ::iaxClientPrefs::BuildPrefsHook {wtree nbframe} {
    global  prefs
    variable tmpPrefs

    if {![::Preferences::HaveTableItem iaxPhone]} {
        ::Preferences::NewTableItem {iaxPhone} [mc iaxPhone]
    }
    ::Preferences::NewTableItem {iaxPhone Devices} [mc Devices]
    ::Preferences::NewTableItem {iaxPhone Filters} [mc Filters]
    ::Preferences::NewTableItem {iaxPhone Codecs} [mc Codecs]

    set wpage [$nbframe page {iaxPhone}]
    BuildIaxPage $wpage
 
    # Edit Account page ----------------------------------------------------------
#    set wpage [$nbframe page {Account}]
#    BuildAccountPage $wpage
   
    # Devices page -------------------------------------------------------------
    set wpage [$nbframe page {Devices}]
    BuildDevicesPage $wpage

    # Filters page -------------------------------------------------------------
    set wpage [$nbframe page {Filters}]
    BuildFiltersPage $wpage

    # Codecs page -------------------------------------------------------------
    set wpage [$nbframe page {Codecs}]
    BuildCodecsPage $wpage
}

proc ::iaxClientPrefs::BuildIaxPage { page } {
    global  prefs
    variable tmpPrefs
    set wc $page.i
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set lfr $wc.fr
    ttk::labelframe $lfr -text [mc {iaxPhone Account}] \
      -padding [option get . groupSmallPadding {}]
    pack $lfr -side top -anchor w

    set tmpPrefs(iaxPhone,user) $prefs(iaxPhone,user) 
    set tmpPrefs(iaxPhone,password)  $prefs(iaxPhone,password)
    set tmpPrefs(iaxPhone,host) $prefs(iaxPhone,host)
    set tmpPrefs(iaxPhone,cidnum) $prefs(iaxPhone,cidnum)
    set tmpPrefs(iaxPhone,cidname) $prefs(iaxPhone,cidname) 

    ttk::label $lfr.luser -text "[mc iaxPhoneUser]:"
    ttk::entry $lfr.user -textvariable [namespace current]::tmpPrefs(iaxPhone,user)

    ttk::label $lfr.lpassword -text "[mc iaxPhonePassword]:"
    ttk::entry $lfr.password -textvariable [namespace current]::tmpPrefs(iaxPhone,password)

    ttk::label $lfr.lhost -text "[mc iaxPhoneHost]:"
    ttk::entry $lfr.host -textvariable [namespace current]::tmpPrefs(iaxPhone,host)

    ttk::label $lfr.lcidnum -text "[mc iaxPhoneCidNum]:"
    ttk::entry $lfr.cidnum -textvariable [namespace current]::tmpPrefs(iaxPhone,cidnum)

    ttk::label $lfr.lcidname -text "[mc iaxPhoneCidName]:"
    ttk::entry $lfr.cidname -textvariable [namespace current]::tmpPrefs(iaxPhone,cidname)

    grid  $lfr.luser $lfr.user    -sticky w
    grid  $lfr.lpassword  $lfr.password -sticky w
    grid  $lfr.lhost  $lfr.host    -sticky w
    grid  $lfr.lcidnum $lfr.cidnum    -sticky w
    grid  $lfr.lcidname $lfr.cidname  -sticky w
}

proc ::iaxClientPrefs::BuildDevicesPage { page } {
    global  prefs
    variable tmpPrefs

    set wc $page.d
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set lfr $wc.fr
    ttk::labelframe $lfr -text [mc {Devices}] \
      -padding [option get . groupSmallPadding {}]
    pack $lfr -side top -anchor w

    set tmpPrefs(iaxPhone,inputDevices) $prefs(iaxPhone,inputDevices)
    set tmpPrefs(iaxPhone,outputDevices) $prefs(iaxPhone,outputDevices)

    ttk::label $lfr.linputDev -text "[mc iaxPhoneInputDev]:"
    ttk::combobox $lfr.input_dev \
      -textvariable [namespace current]::tmpPrefs(iaxPhone,inputDevices) -values [iaxclient::devices "input"] 

    ttk::label $lfr.loutputDev -text "[mc iaxPhoneOutputDev]:"
    ttk::combobox $lfr.output_dev \
      -textvariable [namespace current]::tmpPrefs(iaxPhone,outputDevices) -values [iaxclient::devices "output"]

    grid  $lfr.linputDev $lfr.input_dev   -sticky w
    grid  $lfr.loutputDev $lfr.output_dev    -sticky w

}

proc ::iaxClientPrefs::BuildFiltersPage { page } {
    global  prefs
    variable tmpPrefs

    set wc $page.f
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set lfr $wc.fr
    ttk::labelframe $lfr -text [mc {Filters}] \
      -padding [option get . groupSmallPadding {}]
    pack $lfr -side top -anchor w

    set tmpPrefs(iaxPhone,agc) $prefs(iaxPhone,agc)
    set tmpPrefs(iaxPhone,aagc) $prefs(iaxPhone,aagc)
    set tmpPrefs(iaxPhone,noise) $prefs(iaxPhone,noise)
    set tmpPrefs(iaxPhone,comfort) $prefs(iaxPhone,comfort)
    set tmpPrefs(iaxPhone,echo) $prefs(iaxPhone,echo)

    ttk::label $lfr.lagc -text "[mc iaxPhoneAGC]:"
    ttk::checkbutton $lfr.agc -text [mc AGC]  \
      -variable [namespace current]::tmpPrefs(iaxPhone,agc)

    ttk::label $lfr.laagc -text "[mc iaxPhoneAAGC]:"
    ttk::checkbutton $lfr.aagc -text [mc AAGC]  \
      -variable [namespace current]::tmpPrefs(iaxPhone,aagc)

    ttk::label $lfr.lnoise -text "[mc iaxPhoneNoise]:"
    ttk::checkbutton $lfr.noise -text [mc Noise]  \
      -variable [namespace current]::tmpPrefs(iaxPhone,noise)

    ttk::label $lfr.lcomfort -text "[mc iaxPhoneComfort]:"
    ttk::checkbutton $lfr.comfort -text [mc Comfort]  \
      -variable [namespace current]::tmpPrefs(iaxPhone,comfort)

    ttk::label $lfr.lecho -text "[mc iaxPhoneEcho]:"
    ttk::checkbutton $lfr.echo -text [mc Echo]  \
      -variable [namespace current]::tmpPrefs(iaxPhone,echo)

    grid  $lfr.lagc $lfr.agc   -sticky w
    grid  $lfr.laagc $lfr.aagc    -sticky w
    grid  $lfr.lnoise $lfr.noise   -sticky w
    grid  $lfr.lcomfort $lfr.comfort    -sticky w
    grid  $lfr.lecho $lfr.echo   -sticky w
}

proc ::iaxClientPrefs::BuildCodecsPage { page } {
    global  prefs
    variable tmpPrefs

    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set lfr $wc.fr
    ttk::labelframe $lfr -text [mc {Codecs}] \
      -padding [option get . groupSmallPadding {}]
    pack $lfr -side top -anchor w

    set tmpPrefs(iaxPhone,codec) $prefs(iaxPhone,codec)

    ttk::label $lfr.lcodec -text "[mc iaxPhoneCodec]:"

    ttk::radiobutton $lfr.codeca -text "[mc aLaw]" -variable [namespace current]::tmpPrefs(iaxPhone,codec) -value "a" 
    ttk::radiobutton $lfr.codecu -text "[mc uLaw]" -variable [namespace current]::tmpPrefs(iaxPhone,codec) -value "u"
    ttk::radiobutton $lfr.codecg -text "[mc GSM]" -variable [namespace current]::tmpPrefs(iaxPhone,codec) -value "g"
    ttk::radiobutton $lfr.codeci -text "[mc iLBC]" -variable [namespace current]::tmpPrefs(iaxPhone,codec) -value "i"

    grid  $lfr.lcodec -sticky w
    grid  $lfr.codeca -sticky w
    grid  $lfr.codecu -sticky w
    grid  $lfr.codecg -sticky w
    grid  $lfr.codeci -sticky w
}

proc ::iaxClientPrefs::SavePrefsHook { } {
    global  prefs
    variable tmpPrefs

    set prefs(iaxPhone,user) $tmpPrefs(iaxPhone,user)
    set prefs(iaxPhone,password)  $tmpPrefs(iaxPhone,password)
    set prefs(iaxPhone,host) $tmpPrefs(iaxPhone,host)
    set prefs(iaxPhone,cidnum) $tmpPrefs(iaxPhone,cidnum)
    set prefs(iaxPhone,cidname) $tmpPrefs(iaxPhone,cidname)
    set prefs(iaxPhone,codec) $tmpPrefs(iaxPhone,codec)
    set prefs(iaxPhone,inputDevices) $tmpPrefs(iaxPhone,inputDevices)
    set prefs(iaxPhone,outputDevices) $tmpPrefs(iaxPhone,outputDevices)
    set prefs(iaxPhone,agc) $tmpPrefs(iaxPhone,agc)
    set prefs(iaxPhone,aagc) $tmpPrefs(iaxPhone,aagc)
    set prefs(iaxPhone,noise) $tmpPrefs(iaxPhone,noise)
    set prefs(iaxPhone,comfort) $tmpPrefs(iaxPhone,comfort)
    set prefs(iaxPhone,echo) $tmpPrefs(iaxPhone,echo)

    eval {::hooks::run iaxClientReload} 
}

proc ::iaxClientPrefs::CancelPrefsHook { } {
    global  prefs
    variable tmpPrefs

    set key iaxPhone,user
    if {![string equal $prefs($key) $tmpPrefs($key)]} {
        ::Preferences::HasChanged
    }


}

proc ::iaxClientPrefs::UserDefaultsHook { } {
    global  prefs
    variable tmpPrefs

    set tmpPrefs(iaxPhone,user) $prefs(iaxPhone,user)
    set tmpPrefs(iaxPhone,password)  $prefs(iaxPhone,password)
    set tmpPrefs(iaxPhone,host) $prefs(iaxPhone,host)
    set tmpPrefs(iaxPhone,cidnum) $prefs(iaxPhone,cidnum)
    set tmpPrefs(iaxPhone,cidname) $prefs(iaxPhone,cidname)
    set tmpPrefs(iaxPhone,codec) $prefs(iaxPhone,codec)
    set tmpPrefs(iaxPhone,inputDevices) $prefs(iaxPhone,inputDevices)
    set tmpPrefs(iaxPhone,outputDevices) $prefs(iaxPhone,outputDevices)
    set tmpPrefs(iaxPhone,agc) $prefs(iaxPhone,agc)
    set tmpPrefs(iaxPhone,aagc) $prefs(iaxPhone,aagc)
    set tmpPrefs(iaxPhone,noise) $prefs(iaxPhone,noise)
    set tmpPrefs(iaxPhone,comfort) $prefs(iaxPhone,comfort)
    set tmpPrefs(iaxPhone,echo) $prefs(iaxPhone,echo)
}

proc ::iaxClientPrefs::DestroyPrefsHook { } {
    variable tmpPrefs

    unset -nocomplain tmpPrefs
}


############## TO-DO ##################
# Basic features:
# 2. Separate AddressBook from JivePhone and add last dialed numbers into the AddressBook
# 3. Show missed calls into a Chat Window
# 4. On incoming calls change the buttons Dial to Accept and Hangup to Reject
#
# Advanced features:
# 6. Makes UI nicer, using custom widgets.
# 7. Use the Netstats callback for adjusting options
#
# Known bugs and errors:
# 1. From Callback functions there are problems setting state of widgets.
# ..... A lot of Debug work
