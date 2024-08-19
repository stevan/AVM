#!perl

use v5.40;
use experimental qw[ class builtin ];

use AVM;

my $vm = AVM->new(
    monitor => AVM::Monitor->new,
)->assemble('main', [
    '.echo',
        AVM::Instruction->RECV,

        AVM::Instruction->MSG_BODY,
        AVM::Instruction->DUP,

        AVM::Instruction->PUT,

        AVM::Instruction->DUP,
        AVM::Instruction->PUSH, 0,
        AVM::Instruction->EQ_INT,
        AVM::Instruction->JUMP_IF_TRUE, '#echo.stop',

        AVM::Instruction->DEC_INT,

        AVM::Instruction->SELF,
        AVM::Instruction->CREATE_MSG,
        AVM::Instruction->SEND,

        AVM::Instruction->NEXT, '#echo',
        AVM::Instruction->YIELD,
    '.echo.stop',
        AVM::Instruction->STOP,

    '.main',
        AVM::Instruction->SPAWN, '#echo',
        AVM::Instruction->SPAWN, '#echo',

        AVM::Instruction->PUSH, 10,
        AVM::Instruction->SWAP,
        AVM::Instruction->CREATE_MSG,
        AVM::Instruction->SEND,

        AVM::Instruction->PUSH, 5,
        AVM::Instruction->SWAP,
        AVM::Instruction->CREATE_MSG,
        AVM::Instruction->SEND,

        AVM::Instruction->STOP,
])->run;

