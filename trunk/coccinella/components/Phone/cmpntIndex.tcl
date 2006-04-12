# See contrib/component.tcl for explanations.
#

component::attempt AddressBook [file join $dir AddressBook.tcl] ::AddressBook::Init
component::attempt Phone       [file join $dir Phone.tcl]       ::Phone::Init
component::attempt NotifyCall  [file join $dir NotifyCall.tcl]  ::NotifyCall::Init

