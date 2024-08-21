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
            ADD_INT
            SUB_INT
            MUL_INT
            DIV_INT
            MOD_INT

            EQ_INT
            LT_INT
            LTE_INT
            GT_INT
            GTE_INT

            PUT

            JUMP
            JUMP_IF_TRUE
            JUMP_IF_FALSE
            JUMP_TO

            NEW_MSG
            NEW_MSG2
            NEW_MSG3
            CREATE_MSG
            CREATE_MSG2
            CREATE_MSG3
            MSG_TO
            MSG_FROM
            MSG_BODY
            MSG_BODY_AT

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
