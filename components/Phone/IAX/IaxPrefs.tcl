# IaxPrefs.tcl --
# 
#       iaxClient phone UI
#       
#  Copyright (c) 2006 Antonio Cano damas
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
#  
# $Id: IaxPrefs.tcl,v 1.9 2007-07-18 09:40:10 matben Exp $

package provide IaxPrefs 0.1

namespace eval ::IaxPrefs {

    ::hooks::register prefsInitHook             ::IaxPrefs::InitPrefsHook
    ::hooks::register prefsBuildHook            ::IaxPrefs::BuildPrefsHook
    ::hooks::register prefsSaveHook             ::IaxPrefs::SavePrefsHook
    ::hooks::register prefsCancelHook           ::IaxPrefs::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook     ::IaxPrefs::UserDefaultsHook
}

################## Preferences Stuff ###################
proc ::IaxPrefs::InitPrefsHook { } {
    global  prefs

    set prefs(iaxPhone,user)          ""
    set prefs(iaxPhone,password)      "" ;# Was 0
    set prefs(iaxPhone,host)          "" ;# Was 0
    set prefs(iaxPhone,cidnum)        0
    set prefs(iaxPhone,cidname)       ""
    set prefs(iaxPhone,codec)         ""
    set prefs(iaxPhone,inputDevices)  ""
    set prefs(iaxPhone,outputDevices) ""
    set prefs(iaxPhone,agc)           0
    set prefs(iaxPhone,aagc)          0
    set prefs(iaxPhone,noise)         0
    set prefs(iaxPhone,comfort)       0
#    set prefs(iaxPhone,echo)          0

    variable allKeys 
    set allKeys {user password host cidnum cidname codec  \
      inputDevices outputDevices agc aagc noise comfort}
    # echo 

    set plist {}
    foreach key $allKeys {
	set name prefs(iaxPhone,$key)
	set rsrc prefs_iaxPhone_$key
	set val  [set $name]
	lappend plist [list $name $rsrc $val]
    }
    ::PrefUtils::Add $plist
    VerifySanity
}

proc ::IaxPrefs::VerifySanity { } {
    global  prefs
    
    # Verify booleans.
    foreach key {cidnum agc aagc noise comfort} {
	set value $prefs(iaxPhone,$key)
	if {!(($value == 0) || ($value == 1))} {
	    set prefs(iaxPhone,$key) 0
	}
    }
}

# IaxPrefs::GetAll --
# 
#       A way to get all relevant IAX prefs with simple names.

proc ::IaxPrefs::GetAll { } {
    global  prefs
    variable allKeys 
    
    set plist {}
    foreach key $allKeys {
	lappend plist $key $prefs(iaxPhone,$key)
    }
    return $plist
}

proc ::IaxPrefs::BuildPrefsHook {wtree nbframe} {
    global  prefs
    variable tmpPrefs

    if {![::Preferences::HaveTableItem {phone}]} {
        ::Preferences::NewTableItem {phone} [mc Phone]
    }
    ::Preferences::NewTableItem {phone iax} [mc iaxPhone]

    set wpage [$nbframe page {iax}]
    BuildPage $wpage
 
}

proc ::IaxPrefs::BuildPage {page} {
    global  prefs
    variable tmpPrefs
        
    set wc $page.i
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]    
    
    set waccount $wc.ac
    AccountFrame $waccount

    set wnb $wc.nb
    ttk::notebook $wnb -padding {8 12 8 8}

    grid  $waccount  -sticky ew -padx 8
    grid  $wnb       -sticky ew
    
    # Switch off devices since can create a misery for some users!
    #$wnb add [DevicesFrame $wnb.de] -text [mc Devices]
    $wnb add [FiltersFrame $wnb.fi] -text [mc Filters]
    #$wnb add [CodecsFrame  $wnb.co] -text [mc Codecs]

    bind $page <Destroy> +[namespace current]::Free
}

proc ::IaxPrefs::AccountFrame {win} {
    global  prefs
    variable tmpPrefs

    ttk::labelframe $win -text [mc iaxPhoneAccount] \
      -padding [option get . groupSmallPadding {}]
    pack $win -side top -anchor w

    foreach key {user password host cidnum cidname} {
	set tmpPrefs($key) $prefs(iaxPhone,$key)
    }
    
    ttk::label $win.luser -text "[mc iaxPhoneUser]:"
    ttk::entry $win.user -textvariable [namespace current]::tmpPrefs(user)

    ttk::label $win.lpassword -text "[mc iaxPhonePassword]:"
    ttk::entry $win.password -textvariable [namespace current]::tmpPrefs(password)

    ttk::label $win.lhost -text "[mc iaxPhoneHost]:"
    ttk::entry $win.host -textvariable [namespace current]::tmpPrefs(host)

    ttk::label $win.lcidnum -text "[mc iaxPhoneCidNum]:"
    ttk::entry $win.cidnum -textvariable [namespace current]::tmpPrefs(cidnum)

    ttk::label $win.lcidname -text "[mc iaxPhoneCidName]:"
    ttk::entry $win.cidname -textvariable [namespace current]::tmpPrefs(cidname)

    grid  $win.luser      $win.user      -sticky e -pady 2
    grid  $win.lpassword  $win.password  -sticky e -pady 2
    grid  $win.lhost      $win.host      -sticky e -pady 2
    grid  $win.lcidnum    $win.cidnum    -sticky e -pady 2
    grid  $win.lcidname   $win.cidname   -sticky e -pady 2
    
    return $win
}

proc ::IaxPrefs::DevicesFrame {win} {
    global  prefs
    variable tmpPrefs

    ttk::frame $win -padding [option get . groupSmallPadding {}]
    pack $win -side top -anchor w

    set listInputDevices  [iaxclient::devices input]
    set listOutputDevices [iaxclient::devices output]

    # Workaround for old buggy linux build.
    if {[catch {
	set prefs(iaxPhone,inputDevices)  [lindex [iaxclient::devices input -current] 0]
	set prefs(iaxPhone,outputDevices) [lindex [iaxclient::devices output -current] 0]
    }]} {
	set prefs(iaxPhone,inputDevices)  [lindex $listInputDevices 0 0]
	set prefs(iaxPhone,outputDevices) [lindex $listOutputDevices 0 0]
    }
    set tmpPrefs(inputDevices)  $prefs(iaxPhone,inputDevices)
    set tmpPrefs(outputDevices) $prefs(iaxPhone,outputDevices)
    
    foreach device $listInputDevices {
        lappend inputDevices [lindex $device 0]
    } 
    ttk::label $win.linputDev -text "[mc iaxPhoneInputDev]:"
    ttk::combobox $win.input_dev -state readonly  \
      -textvariable [namespace current]::tmpPrefs(inputDevices) -values $inputDevices

    foreach device $listOutputDevices {
        lappend outputDevices [lindex $device 0]
    }
    ttk::label $win.loutputDev -text "[mc iaxPhoneOutputDev]:"
    ttk::combobox $win.output_dev -state readonly  \
      -textvariable [namespace current]::tmpPrefs(outputDevices)  \
      -values $outputDevices
    
    grid  $win.linputDev   $win.input_dev   -sticky e -pady 2
    grid  $win.loutputDev  $win.output_dev  -sticky e -pady 2
    
    return $win
}

proc ::IaxPrefs::FiltersFrame {win} {
    global  prefs
    variable tmpPrefs

    ttk::frame $win -padding [option get . groupSmallPadding {}]
    pack $win -side top -anchor w

    foreach key {agc aagc noise comfort} {
	set tmpPrefs($key) $prefs(iaxPhone,$key)
    }
#    set tmpPrefs(echo) $prefs(iaxPhone,echo)

    ttk::checkbutton $win.agc -text "[mc iaxPhoneAGC]"  \
      -variable [namespace current]::tmpPrefs(agc)
    ttk::checkbutton $win.aagc -text "[mc iaxPhoneAAGC]"  \
      -variable [namespace current]::tmpPrefs(aagc)
    ttk::checkbutton $win.noise -text "[mc iaxPhoneNoise]"  \
      -variable [namespace current]::tmpPrefs(noise)
    ttk::checkbutton $win.comfort -text "[mc iaxPhoneComfort]"  \
      -variable [namespace current]::tmpPrefs(comfort)
#    ttk::checkbutton $win.echo -text "[mc iaxPhoneEcho]"  \
#      -variable [namespace current]::tmpPrefs(echo)

    grid  $win.agc      -sticky w
    grid  $win.aagc     -sticky w
    grid  $win.noise    -sticky w
    grid  $win.comfort  -sticky w
#    grid  $win.echo   -sticky w
    
    return $win
}

proc ::IaxPrefs::CodecsFrame {win} {
    global  prefs
    variable tmpPrefs

    ttk::frame $win -padding [option get . groupSmallPadding {}]
    pack $win -side top -anchor w

    set tmpPrefs(codec) $prefs(iaxPhone,codec)

    ttk::label $win.lcodec -text "[mc iaxPhoneCodec]:"

    ttk::radiobutton $win.codeci -text "iLBC" -variable [namespace current]::tmpPrefs(codec) -value "ILBC"
    ttk::radiobutton $win.codecs -text "Speex" -variable [namespace current]::tmpPrefs(codec) -value "SPEEX"
    ttk::radiobutton $win.codeca -text "aLaw" -variable [namespace current]::tmpPrefs(codec) -value "ALAW" 
    ttk::radiobutton $win.codecu -text "uLaw" -variable [namespace current]::tmpPrefs(codec) -value "ULAW"
    ttk::radiobutton $win.codecg -text "GSM"  -variable [namespace current]::tmpPrefs(codec) -value "GSM"

    # If you add more codecs use a new column.
    grid  $win.lcodec  $win.codeci  -sticky w
    grid  x            $win.codecs  -sticky w
    grid  x            $win.codeca  -sticky w
    grid  x            $win.codecu  -sticky w
    grid  x            $win.codecg  -sticky w
    grid $win.lcodec -padx 4
    
    return $win
}

proc ::IaxPrefs::SavePrefsHook { } {
    global  prefs
    variable tmpPrefs
    variable allKeys 

    foreach key $allKeys {
	if {[info exists tmpPrefs($key)]} {
	    set prefs(iaxPhone,$key) $tmpPrefs($key)
	}
    }    
    VerifySanity
    ::Iax::Reload
}

proc ::IaxPrefs::CancelPrefsHook { } {
    global  prefs
    variable tmpPrefs
    variable allKeys 

    foreach key $allKeys {
	if {[info exists tmpPrefs($key)]} {
	    if {![string equal $prefs(iaxPhone,$key) $tmpPrefs($key)]} {
		::Preferences::HasChanged
		break
	    }
	}
    }
}

proc ::IaxPrefs::UserDefaultsHook { } {
    global  prefs
    variable tmpPrefs
    variable allKeys 

    foreach key $allKeys {
	set tmpPrefs($key) $prefs(iaxPhone,$key)
    }
}

proc ::IaxPrefs::Free { } {
    variable tmpPrefs

    unset -nocomplain tmpPrefs
}
