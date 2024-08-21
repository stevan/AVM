#!perl

use v5.40;
use experimental qw[ class builtin ];

use Test::More;

use AVM;
use AVM::Assembler::Assembly;

=pod

# plain Perl version of recursive multipler ...

sub mul ($x, $y) {
    return 0  if $y == 0;
    return $x if $y == 1;
    return $x + mul( $x, $y - 1 );
}

# pseudo code for Actor multipler

muliplier {
    recv (msg) {
        if (msg.body.1 == 0) {
            msg.sender ! [0];
        }
        else if (msg.body.1 == 1) {
            msg.sender ! msg.body.0;
        }
        else {
            mul = spawn(muliplier);
            mul ! [ msg.body.0, (msg.body.1 - 1) ];

            recv (msg2) {
                add = spawn(adder);
                add ! [ msg.body.0, msg2.body ];

                recv (msg3) {
                    msg.sender ! msg3.body;
                }
            }
        }
        stop;
    }
}

adder {
    recv (msg) {
        msg.from ! [ msg.body.0 + msg.body.2 ];
        stop;
    }
}

main {
    mul = spawn(muliplier);

    mul ! [4, 10];

    recv (msg) {
        put msg;

        stop;
    }
}

=cut

my $vm = AVM->new(
    monitor => AVM::Monitor->new,
)->assemble('main', [
    '.multiplier',
        # (0 = $msg, 1 = $msg->body[0], 2 = $msg->body[1] )
        RECV,

        LOAD, 0,
        MSG_BODY_AT, 0,

        LOAD, 0,
        MSG_BODY_AT, 1,

        DUP,
        PUSH, 1,
        EQ_INT,
        JUMP_IF_TRUE, '#multiplier.return.early.1',

        DUP,
        PUSH, 0,
        EQ_INT,
        JUMP_IF_TRUE, '#multiplier.return.early.0',

        LOAD, 2,
        DEC_INT,
        LOAD, 1,
        SPAWN, '#multiplier',
        NEW_MSG2,
        SEND,

        RECV,
        MSG_BODY,
        LOAD, 1,
        SPAWN, '#adder',
        NEW_MSG2,
        SEND,

        RECV,
        MSG_BODY,
        JUMP, '#multiplier.return',

        '.multiplier.return.early.1',
            LOAD, 1,
            JUMP, '#multiplier.return',

        '.multiplier.return.early.0',
            LOAD, 2,
            JUMP, '#multiplier.return',

        '.multiplier.return',
            LOAD, 0,
            MSG_FROM,
            NEW_MSG,
            SEND,

        POP, POP, POP, # clear the locals
        STOP,

    '.adder',
        RECV,

        LOAD, 0,
        MSG_BODY_AT, 0,
        LOAD, 0,
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

        POP, # clear the local
        STOP,
])->run;

subtest '... checking the end state' => sub {
    isa_ok($vm, 'AVM');
};

done_testing;

