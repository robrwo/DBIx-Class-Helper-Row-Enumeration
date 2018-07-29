package DBIx::Class::Helper::Row::Enumeration;

# ABSTRACT: Add methods for emum values

use v5.10;

use strict;
use warnings;

use parent 'DBIx::Class::Core';

use Ref::Util  ();
use Sub::Quote ();

our $VERSION = 'v0.1.0';

sub add_columns {
    my ( $self, @cols ) = @_;

    $self->next::method(@cols);

    my $class = Ref::Util::is_ref($self) || $self;

    foreach my $col (@cols) {

        next if ref $col;

        $col =~ s/^\+//;

        my $info = $self->column_info($col);

        next unless $info->{data_type} eq 'enum';

        my $handlers = $info->{extra}{handles} //= sub { "is_" . $_[0] };

        next unless $handlers;

        if ( Ref::Util::is_plain_coderef($handlers) ) {
            $info->{extra}{handles} =
              { map { $handlers->( $_, $col, $class ) => $_ }
                  @{ $info->{extra}{list} } };
            $handlers = $info->{extra}{handles};
        }

        DBIx::Class::Exception->throw("handles is not a hashref")
            unless Ref::Util::is_plain_hashref($handlers);

        foreach my $handler ( keys %$handlers ) {
            my $value = $handlers->{$handler} or next;

            my $method = "${class}::${handler}";

            DBIx::Class::Exception->throw("${method} is already defined")
                if $self->can($method);

            Sub::Quote::quote_sub $method,
                qq{ \$_[0]->get_column("${col}") eq "${value}" };

        }

    }

    return $self;
}

1;
