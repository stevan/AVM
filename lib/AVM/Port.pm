#!perl

use v5.40;
use experimental qw[ class ];

class AVM::Port {
    field @buffer :reader;

    method is_empty     { scalar @buffer == 0 }
    method is_not_empty { scalar @buffer != 0 }

    method flush { my @b = @buffer; @buffer = (); @b }

    method put ($v) { push @buffer => $v }

    method get {
        return unless @buffer;
        return shift @buffer
    }
}
