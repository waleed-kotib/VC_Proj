package require xml

set _wspc {[ \t\n\r]*}
proc CData {data args} {
    global indent _wspc

    if {![regexp "^${_wspc}$" $data]} {
	puts "$indent  $data"
    }
}
proc EStart {name attlist args} {
    global indent

    set attrs {}
    foreach {key value} $attlist {
	lappend attrs "$key='$value'"
    }
    puts "${indent}<$name $attrs>"
    append indent {    }
}
proc EEnd {name args} {
    global indent

    set indent [string range $indent 0 end-4]
    puts "${indent}</$name>"
}

set indent {}
set parser [::xml::parser -characterdatacommand CData -elementstartcommand EStart  \
  -elementendcommand EEnd]

proc Format {} {
    global  parser
    
    set fileName [tk_getOpenFile]
    set fd [open $fileName]
    $parser parse [read $fd]
    close $fd
}
Format

