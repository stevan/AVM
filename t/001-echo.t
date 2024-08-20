#!perl

use v5.40;
use experimental qw[ class builtin ];

use Test::More;

use AVM;
use AVM::Assembler::Assembly;

my $vm = AVM->new(
    monitor => AVM::Monitor->new,
)->assemble('main', [
    '.echo',
        RECV,

        MSG_BODY,
        DUP,

        PUT,

        DUP,
        PUSH, 0,
        EQ_INT,
        JUMP_IF_TRUE, '#echo.stop',

        DEC_INT,

        SELF,
        NEW_MSG,
        SEND,

        NEXT, '#echo',
        YIELD,
    '.echo.stop',
        STOP,

    '.main',
        SPAWN, '#echo',
        SPAWN, '#echo',

        PUSH, 10,
        SWAP,
        NEW_MSG,
        SEND,

        PUSH, 5,
        SWAP,
        NEW_MSG,
        SEND,

        STOP,
])->run;

subtest '... checking the end state' => sub {
    isa_ok($vm, 'AVM');
    my ($main, $echo1, $echo2) = $vm->reaped;
    is($main->name, 'main', '... got the expected name for main');

    is($echo1->name, 'echo', '... got the expected name for echo (1)');
    ok($echo1->sod->is_not_empty, '... got output for echo (1)');
    is_deeply(
        [ $echo1->sod->buffer ],
        [ 5, 4, 3, 2, 1, 0 ],
        '... got the expected output for echo (1)'
    );

    is($echo2->name, 'echo', '... got the expected name for echo (2)');
    ok($echo2->sod->is_not_empty, '... got output for echo (2)');
    is_deeply(
        [ $echo2->sod->buffer ],
        [ 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 ],
        '... got the expected output for echo (1)'
    );
};

done_testing;

