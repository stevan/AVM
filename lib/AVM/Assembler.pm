#!perl

use v5.40;
use experimental qw[ class builtin ];
use builtin      qw[ created_as_string created_as_number ];

class AVM::Assembler {
    field $code          :reader;
    field $label_to_addr :reader;
    field $addr_to_label :reader;

    method assemble ($source) {
        my @source = @$source;

        # build the table of labels ...
        my %label_to_addr;
        my %addr_to_label;

        my $label_addr = 0;
        foreach my $token (@source) {
            if ( created_as_string($token) && $token =~ /^\.(.*)/ ) {
                my $label = $1;
                $label_to_addr{ $label      } = $label_addr;
                $addr_to_label{ $label_addr } = $label;
            } else {
                $label_addr++;
            }
        }

        # replace all the anchors with the label
        foreach my ($i, $token) (indexed @source) {
            if ( created_as_string($token) && $token =~ /^#(.*)/ ) {
                my $label = $1;
                $source[$i] = $label_to_addr{ $label };
            }
        }

        my @code;
        foreach my $token (@source) {
            unless ( created_as_string($token) && $token =~ /^(\#|\.)(.*)/ ) {
                push @code => $token;
            }
        }


        $code          = \@code;
        $label_to_addr = \%label_to_addr;
        $addr_to_label = \%addr_to_label;

        return;
    }
}
