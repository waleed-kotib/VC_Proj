##################################################
#
# sha1.tcl - SHA1 in Tcl
# Author: Don Libes <libes@nist.gov>, May 2001
# Version 1.0.0
#
# SHA1 defined by FIPS 180-1, "The SHA1 Message-Digest Algorithm",
#          http://www.itl.nist.gov/fipspubs/fip180-1.htm
# HMAC defined by RFC 2104, "Keyed-Hashing for Message Authentication"
#
# Some of the comments below come right out of FIPS 180-1; That's why
# they have such peculiar numbers.  In addition, I have retained
# original syntax, etc. from the FIPS.  All remaining bugs are mine.
#
# HMAC implementation by D. J. Hagberg <dhagberg@millibits.com> and
# is based on C code in FIPS 2104.
#
# For more info, see: http://expect.nist.gov/sha1pure
#
# - Don
##################################################

namespace eval sha1pure {
    variable i
    variable j
    variable t
    variable K

    set j 0
    foreach t {
	0x5A827999
	0x6ED9EBA1
	0x8F1BBCDC
	0xCA62C1D6
    } {
	for {set i 0} {$i < 20} {incr i; incr j} {
	    set K($j) $t
	}
    }
}

proc sha1pure::sha1 {msg} {
    variable K

    #
    # 4. MESSAGE PADDING
    #

    # pad to 512 bits (512/8 = 64 bytes)

    set msgLen [string length $msg]

    # last 8 bytes are reserved for msgLen
    # plus 1 for "1"

    set padLen [expr {56 - $msgLen%64}]
    if {$msgLen % 64 >= 56} {
	incr padLen 64
    }

    # 4a. and b. append single 1b followed by 0b's
    append msg [binary format "a$padLen" \200]

    # 4c. append 64-bit length
    # Our implementation obviously limits string length to 32bits.
    append msg \0\0\0\0[binary format "I" [expr {8*$msgLen}]]
    
    #
    # 7. COMPUTING THE MESSAGE DIGEST
    #

    # initial H buffer

    set i 0
    foreach t {
	0x67452301
	0xEFCDAB89
	0x98BADCFE
	0x10325476
	0xC3D2E1F0
    } {
	set H($i) [expr $t]
	incr i
    }

    #
    # process message in 16-word blocks (64-byte blocks)
    #

    # convert message to array of 32-bit integers
    # each block of 16-words is stored in M($i,0-16)

    binary scan $msg I* words
    set i 1
    set j 0
    foreach w $words {
	lappend M($i) $w
	if {[incr j] == 16} {
	    incr i
	    set j 0
	}
    }

    set blockLen [expr {$i-1}]

    for {set i 1} {$i <= $blockLen} {incr i} {
	    # 7a. Divide M[i] into 16 words W[0], W[1], ...
	    set t 0
	    foreach m $M($i) {
		set W($t) $m
		incr t
	    }

	    # 7b. For t = 16 to 79 let W[t] = ....
	    set t   16
	    set t3  12
	    set t8   7
	    set t14  1
	    set t16 -1
	    for {} {$t < 80} {incr t} {
		set x [expr {$W([incr t3]) ^ $W([incr t8]) ^ $W([incr t14]) ^ $W([incr t16])}]
		set W($t) [expr {($x << 1) | (($x >> 31) & 1)}]
	    }

	    # 7c. Let A = H[0] ....
	    set A $H(0)
	    set B $H(1)
	    set C $H(2)
	    set D $H(3)
	    set E $H(4)

	    # 7d. For t = 0 to 79 do
	    for {set t 0} {$t < 80} {incr t} {
		set TEMP [expr {(($A << 5) | (($A >> 27) & 0x1f)) + [f $t $B $C $D] + $E + $W($t) + $K($t)}]
		set E $D
		set D $C
		set C [expr {($B << 30) | (($B >> 2) & 0x3fffffff)}]
		set B $A
		set A $TEMP
	    }

	    incr H(0) $A
	    incr H(1) $B
	    incr H(2) $C
	    incr H(3) $D
	    incr H(4) $E
    }
    return [bytes $H(0)][bytes $H(1)][bytes $H(2)][bytes $H(3)][bytes $H(4)]
}

proc sha1pure::f {t B C D} {
    switch [expr {$t/20}] {
	0 {
	    expr {($B & $C) | ((~$B) & $D)}
	} 1 - 3 {
	    expr {$B ^ $C ^ $D}
	} 2 {
	    expr {($B & $C) | ($B & $D) | ($C & $D)}
	}
    }
}

proc sha1pure::byte0 {i} {expr {0xff & $i}}
proc sha1pure::byte1 {i} {expr {(0xff00 & $i) >> 8}}
proc sha1pure::byte2 {i} {expr {(0xff0000 & $i) >> 16}}
proc sha1pure::byte3 {i} {expr {((0xff000000 & $i) >> 24) & 0xff}}

proc sha1pure::bytes {i} {
    format %0.2x%0.2x%0.2x%0.2x [byte3 $i] [byte2 $i] [byte1 $i] [byte0 $i]
}

# hmac: hash for message authentication
proc sha1pure::hmac {key text} {
    # if key is longer than 64 bytes, reset it to SHA1(key).  If shorter, 
    # pad it out with null (\x00) chars.
    set keyLen [string length $key]
    if {$keyLen > 64} {
        set key [binary format H32 [sha1 $key]]
        set keyLen [string length $key]
    }

    # ensure the key is padded out to 64 chars with nulls.
    set padLen [expr {64 - $keyLen}]
    append key [binary format "a$padLen" {}]

    # Split apart the key into a list of 16 little-endian words
    binary scan $key i16 blocks

    # XOR key with ipad and opad values
    set k_ipad {}
    set k_opad {}
    foreach i $blocks {
        append k_ipad [binary format i [expr {$i ^ 0x36363636}]]
        append k_opad [binary format i [expr {$i ^ 0x5c5c5c5c}]]
    }
    
    # Perform inner sha1, appending its results to the outer key
    append k_ipad $text
    append k_opad [binary format H* [sha1 $k_ipad]]

    # Perform outer sha1
    sha1 $k_opad
}

package provide sha1pure 1.0
