# test wrapper. Must be run with wish, or tclsh with event loop!

package require wrapper

set data1 {<?xml version='1.0'?><stream><message><body myattr="slask">Some text here</body></message></stream>}
set data2 {<stream><message><subject>Cool</subject><body>Some text here</body></message></stream>}
set data3 {<stream><message type="standard"><body>Some text here</body></message></stream>}
set data4 {<stream><body xmlns="jabber:iq:roster"><item>Scrap</item></body></stream>}
set data5 {<stream><body>Hello &quot;new World&quot;</body></stream>}
set data6 {<stream><body>CANVAS: create text -text {Hello &quot;new World&quot;}</body></stream>}

proc streamstartcmd {args} {
    puts "-->streamstartcmd: attrlist=$args"
}
proc streamendcmd { } {
    puts "-->streamendcmd: "
}
proc parsecmd {xmldata} {
    puts "-->parsecmd: xmldata=$xmldata"
}
proc errorcmd {args} {
    puts "-->errorcmd: args='$args'"
}
set wrapid [wrapper::new streamstartcmd streamendcmd parsecmd errorcmd]

if {0} {
    wrapper::parse $wrapid $data2
}
