#!perl

use v5.40;
use experimental qw[ class builtin ];

use Test::More;

use AVM;
use AVM::Assembler::Assembly;

my $vm = AVM->new(
    monitor => AVM::Monitor->new,
)->assemble('main', [
    '.ping',
        PUSH, 0,
    '.ping.loop',
        RECV,
        DUP,

        LOAD, 0,
        PUSH, 10,
        EQ_INT,
        JUMP_IF_TRUE, '#ping.exit',

        MSG_BODY,
        JUMP_TO,
        '.ping.exit',
            PUSH, 'E',
            PUT,

            MSG_FROM,
            PUSH, '#ping.stop',
            SWAP,
            NEW_MSG,
            SEND,
        '.ping.stop',
            STOP,

        '.ping.start',
            POP, # discard the message, we don't need it
            SPAWN, '#ping',

            PUSH, '#ping.ping',
            SWAP,
            NEW_MSG,
            SEND,
            JUMP, '#ping.break',

        '.ping.ping',
            PUSH, 'I',
            PUT,

            MSG_FROM,
            PUSH, '#ping.pong',
            SWAP,
            NEW_MSG,
            SEND,

            JUMP, '#ping.break',

        '.ping.pong',
            PUSH, 'O',
            PUT,

            MSG_FROM,
            PUSH, '#ping.ping',
            SWAP,
            NEW_MSG,
            SEND,

            JUMP, '#ping.break',

    '.ping.break',
        LOAD, 0,
        INC_INT,
        STORE, 0,

        NEXT, '#ping.loop',
        YIELD,

    '.main',
        SPAWN, '#ping',

        PUSH, '#ping.start',
        SWAP,
        NEW_MSG,
        SEND,

        STOP

])->run;

subtest '... checking the end state' => sub {
    isa_ok($vm, 'AVM');

    my ($main, $ping1, $ping2) = $vm->reaped;
    is($main->name, 'main', '... got the expected name for main');

    is($ping1->name, 'ping', '... got the expected name for ping (1)');
    ok($ping1->sod->is_not_empty, '... got output for ping (1)');
    is_deeply(
        [ $ping1->sod->buffer ],
        [ 'O', 'O', 'O', 'O', 'O', 'O', 'O', 'O', 'O', 'E' ],
        '... got the expected output for ping (1)'
    );

    is($ping2->name, 'ping', '... got the expected name for ping (2)');
    ok($ping2->sod->is_not_empty, '... got output for ping (2)');
    is_deeply(
        [ $ping2->sod->buffer ],
        [ 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'I', 'E' ],
        '... got the expected output for ping (1)'
    );


};

done_testing;

