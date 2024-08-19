#!perl

use v5.40;
use experimental qw[ class builtin ];
use builtin      qw[ export_lexically ];

use importer 'Sub::Util' => qw[ set_subname ];

use AVM::Instruction;

package AVM::Assembler::Assembly {
    sub import ($,@) {
        my %exports;

        foreach my $opcode ( AVM::Instruction->ALL->@* ) {
            $exports{ sprintf '&%s' => $opcode } = set_subname( $opcode, sub () { $opcode } );
        }

        export_lexically( %exports );
    }
}
