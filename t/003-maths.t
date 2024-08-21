#!perl

use v5.40;
use experimental qw[ class builtin ];

use Test::More;

use AVM;
use AVM::Assembler::Assembly;

=pod

sub mul ($x, $y) {
    return 0  if $y == 0;
    return $x if $y == 1;
    return $x + mul( $x, $y - 1 );
}

=cut

my $vm = AVM->new(
    monitor => AVM::Monitor->new,
)->assemble('main', [
    '.multiplier',
        PUSH, 0,
        # (0 = $acc, 1 = $msg, 2 = $msg->body[0], 3 = $msg->body[1] as $i )
        RECV,

        LOAD, 1,
        MSG_BODY_AT, 0,

        LOAD, 1,
        MSG_BODY_AT, 1,

        DUP,
        PUSH, 1,
        EQ_INT,
        JUMP_IF_TRUE, '#multiplier.return.early',

        DUP,
        PUSH, 0,
        EQ_INT,
        JUMP_IF_TRUE, '#multiplier.return',

        LOAD, 3,
        DEC_INT,
        LOAD, 2,
        SPAWN, '#multiplier',
        NEW_MSG2,
        SEND,

        RECV,
        MSG_BODY,
        LOAD, 2,
        SPAWN, '#adder',
        NEW_MSG2,
        SEND,

        RECV,
        MSG_BODY,
        STORE, 0,
        JUMP, '#multiplier.return',

        '.multiplier.return.early',
            LOAD, 2,
            STORE, 0,

        '.multiplier.return',
            LOAD, 0,
            LOAD, 1,
            MSG_FROM,
            NEW_MSG,
            SEND,

        STOP,

    '.adder',
        RECV,

        DUP,
        DUP,
        DUP,
        MSG_BODY_AT, 0,
        SWAP,
        MSG_BODY_AT, 1,
        ADD_INT,
        SWAP,

        MSG_FROM,
        NEW_MSG,
        SEND,

        STOP,

    '.main',
        SPAWN, '#multiplier',

        PUSH, 10,
        PUSH, 4,
        LOAD, 0,
        NEW_MSG2,
        SEND,

        RECV,
        MSG_BODY,
        PUT,

        STOP,
])->run;

subtest '... checking the end state' => sub {
    isa_ok($vm, 'AVM');
};

done_testing;

