#!perl

use v5.40;
use experimental qw[ class builtin ];

use Test::More;

use AVM;
use AVM::MultiCore;
use AVM::Assembler::Assembly;

#my $vm = AVM->new(
#    monitor => AVM::Monitor->new,
#);

my $vm = AVM::MultiCore->new(
    monitor => AVM::Monitor->new,
    num_cores     => 4,
    process_quota => 1024,
    clock_slice   => 2,
);

$vm->assemble('main', [
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
        PUSH, 10,
        PUSH, 10,
        SPAWN, '#adder',
        NEW_MSG2,
        SEND,

        PUSH, 25,
        PUSH, 50,
        SPAWN, '#adder',
        NEW_MSG2,
        SEND,

        PUSH, 125,
        PUSH, 500,
        SPAWN, '#adder',
        NEW_MSG2,
        SEND,

        PUSH, 325,
        PUSH, 250,
        SPAWN, '#adder',
        NEW_MSG2,
        SEND,

        RECV,
        MSG_BODY,
        PUT,

        RECV,
        MSG_BODY,
        PUT,

        RECV,
        MSG_BODY,
        PUT,

        RECV,
        MSG_BODY,
        PUT,

        STOP,
])->run;

subtest '... checking the end state' => sub {
    isa_ok($vm, 'AVM::MultiCore');
    my ($main, $adder) = sort { $a->pid <=> $b->pid } $vm->reaped;
    is($main->name, 'main', '... got the expected name for main');
    is($adder->name, 'adder', '... got the expected name for adder');

    ok($main->sod->is_not_empty, '... got sod for main');
    is_deeply(
        [ $main->sod->buffer ],
        [ 20, 75, 625, 575 ],
        '... got the expected sod for main'
    );

};

done_testing;

