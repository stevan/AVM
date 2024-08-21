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
    clock_slice   => 10,
);

$vm->assemble('main', [
    '.echo',
        RECV,

        MSG_BODY,
        DUP,

        PUT,

        DUP,
        JUMP_IF_ZERO, '#echo.stop',

        DEC_INT,

        SELF,
        NEW_MSG,
        SEND,

        NEXT, '#echo',
        YIELD,
    '.echo.stop',
        STOP,

    '.main',
        PUSH, 5,
        SPAWN, '#echo',
        NEW_MSG,
        SEND,

        PUSH, 3,
        SPAWN, '#echo',
        NEW_MSG,
        SEND,

        PUSH, 8,
        SPAWN, '#echo',
        NEW_MSG,
        SEND,

        PUSH, 2,
        SPAWN, '#echo',
        NEW_MSG,
        SEND,

        STOP,
])->run;

subtest '... checking the end state' => sub {
    isa_ok($vm, 'AVM::MultiCore');
    my ($main, $echo1, $echo2, $echo3, $echo4) = $vm->reaped;
    is($main->name, 'main', '... got the expected name for main');

    is($echo1->name, 'echo', '... got the expected name for echo (1)');
    ok($echo1->sod->is_not_empty, '... got output for echo (1)');
    is_deeply(
        [ $echo1->sod->buffer ],
        [ 2, 1, 0 ],
        '... got the expected output for echo (1)'
    );

    is($echo2->name, 'echo', '... got the expected name for echo (2)');
    ok($echo2->sod->is_not_empty, '... got output for echo (2)');
    is_deeply(
        [ $echo2->sod->buffer ],
        [ 3, 2, 1, 0 ],
        '... got the expected output for echo (1)'
    );

    is($echo3->name, 'echo', '... got the expected name for echo (3)');
    ok($echo3->sod->is_not_empty, '... got output for echo (3)');
    is_deeply(
        [ $echo3->sod->buffer ],
        [ 5, 4, 3, 2, 1, 0 ],
        '... got the expected output for echo (3)'
    );

    is($echo4->name, 'echo', '... got the expected name for echo (4)');
    ok($echo4->sod->is_not_empty, '... got output for echo (4)');
    is_deeply(
        [ $echo4->sod->buffer ],
        [ 8, 7, 6, 5, 4, 3, 2, 1, 0 ],
        '... got the expected output for echo (4)'
    );

};

done_testing;

