#!perl

use v5.40;
use experimental qw[ class ];

class AVM::Message {
    use overload '""' => \&to_string;

    field $to   :param :reader;
    field $from :param :reader;
    field $body :param :reader;

    method to_string { sprintf 'msg<to:%s from:%s body:[%s]>', $to, $from // '~', $body // '~' }
}
