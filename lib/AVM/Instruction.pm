#!perl

use v5.40;
use experimental qw[ class ];

use importer 'Scalar::Util' => qw[ dualvar ];
use constant ();

class AVM::Instruction {
    our @OPS;
    BEGIN {
        my $x = 0;
        @OPS = map {
            my $x = dualvar($x++, "$_");
            constant->import( $_ => $x );
            $x;
        } qw[
            PUSH
            POP
            DUP
            SWAP

            INC_INT
            DEC_INT

            EQ_INT
            LT_INT
            GT_INT

            PUT

            JUMP
            JUMP_IF_TRUE
            JUMP_IF_FALSE

            CREATE_MSG
            MSG_TO
            MSG_FROM
            MSG_BODY

            LOAD
            STORE

            SPAWN
            SELF
            NEXT
            SEND
            RECV

            YIELD
            STOP
        ];
    }

    use constant ALL => \@OPS;
}
