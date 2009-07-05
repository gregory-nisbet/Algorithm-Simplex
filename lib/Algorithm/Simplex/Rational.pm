package Algorithm::Simplex::Rational;
use Moose;
use Algorithm::Simplex::Types;
use namespace::autoclean;
extends 'Algorithm::Simplex';
with 'Algorithm::Simplex::Role::Solve';
use Math::Cephes::Fraction qw(:fract);

has tableau => (
    is       => 'rw',
    isa      => 'FractMatrix',
    required => 1,
    coerce   => 1,
);


my $one     = fract( 1, 1 );
my $neg_one = fract( 1, -1 );

=head1 Name

Algorithm::Simplex::Rational - Rational model of the Simplex Algorithm

=head1 Methods

=head2 pivot

Do the algebra of a Tucker/Bland pivot.  i.e. Traverse from one node to and 
adjacent node along the Simplex of feasible solutions.

=cut

sub pivot {

    my $self                = shift;
    my $pivot_row_number    = shift;
    my $pivot_column_number = shift;

    # Do tucker algebra on pivot row
    my $scale =
      $one->rdiv(
        $self->tableau->[$pivot_row_number]->[$pivot_column_number] );
    for my $j ( 0 .. $self->number_of_columns ) {
        $self->tableau->[$pivot_row_number]->[$j] =
          $self->tableau->[$pivot_row_number]->[$j]->rmul($scale);
    }
    $self->tableau->[$pivot_row_number]->[$pivot_column_number] = $scale;

    # Do tucker algebra elsewhere
    for my $i ( 0 .. $self->number_of_rows ) {
        if ( $i != $pivot_row_number ) {

            my $neg_a_ic =
              $self->tableau->[$i]->[$pivot_column_number]->rmul($neg_one);
            for my $j ( 0 .. $self->number_of_columns ) {
                $self->tableau->[$i]->[$j] =
                  $self->tableau->[$i]->[$j]->radd(
                    $neg_a_ic->rmul(
                        $self->tableau->[$pivot_row_number]->[$j]
                    )
                  );
            }
            $self->tableau->[$i]->[$pivot_column_number] =
              $neg_a_ic->rmul($scale);
        }
    }
}

sub determine_simplex_pivot_columns {
    my $self = shift;

    my @simplex_pivot_column_numbers;
    for my $col_num ( 0 .. $self->number_of_columns - 1 ) {
        my $bottom_row_fraction =
          $self->tableau->[ $self->number_of_rows ]->[$col_num];
        my $bottom_row_numeric =
          $bottom_row_fraction->{n} / $bottom_row_fraction->{d};
        if ( $bottom_row_numeric > 0 ) {
            push( @simplex_pivot_column_numbers, $col_num );
        }
    }
    return (@simplex_pivot_column_numbers);
}

sub determine_positive_ratios {
    my $self                = shift;
    my $pivot_column_number = shift;

# Build Ratios and Choose row(s) that yields min for the bland simplex column as a candidate pivot point.
# To be a Simplex pivot we must not consider negative entries
    my %pivot_for;
    my @positive_ratios;
    my @positive_ratio_row_numbers;

    #print "Column: $possible_pivot_column\n";
    for my $row_num ( 0 .. $self->number_of_rows - 1 ) {
        my $bottom_row_fraction =
          $self->tableau->[$row_num]->[$pivot_column_number];
        my $bottom_row_numeric =
          $bottom_row_fraction->{n} / $bottom_row_fraction->{d};

        if ( $bottom_row_numeric > 0 ) {
            push(
                @positive_ratios,
                (
                    $self->tableau->[$row_num]
                      ->[ $self->number_of_columns ]->{n} *
                      $self->tableau->[$row_num]->[$pivot_column_number]
                      ->{d}
                  ) / (
                    $self->tableau->[$row_num]->[$pivot_column_number]
                      ->{n} *
                      $self->tableau->[$row_num]
                      ->[ $self->number_of_columns ]->{d}
                  )
            );

            # Track the rows that give ratios
            push @positive_ratio_row_numbers, $row_num;
        }
    }
    return ( \@positive_ratios, \@positive_ratio_row_numbers );
}
sub is_optimal {
    my $self = shift;

    # check basement row for having non-positive entries which
    # would => optimal when in phase 2.
    my $optimal_flag = 1;

    # if a positve entry exists in the basement row we don't have optimality
    for my $j ( 0 .. $self->number_of_columns - 1 ) {
        my $basement_row_fraction = $self->tableau->[ $self->number_of_rows ]->[$j];
        my $basement_row_numeric = $basement_row_fraction->{n} / $basement_row_fraction->{d};
        if ( $basement_row_numeric > 0 ) {
            $optimal_flag = 0;
            last;
        }
    }
    return $optimal_flag;
}

sub current_solution {
    my $self = shift;

    # Report the Current Solution as primal dependents and dual dependents.
    my @y = @{ $self->y_variables };
    my @u = @{ $self->u_variables };

    # Dependent Primal Variables
    my %primal_solution;
    for my $i ( 0 .. $#y ) {
        my $rational =  $self->tableau->[$i]->[ $self->number_of_columns ];
        $primal_solution{ $y[$i]->{generic} } = $rational->as_string;
    }

    # Dependent Dual Variables
    my %dual_solution;
    for my $j ( 0 .. $#u ) {
       my $rational = $self->tableau->[ $self->number_of_rows ]->[$j]->rmul($neg_one);
       $dual_solution{ $u[$j]->{generic} } = $rational->as_string;
    }
    
    return (\%primal_solution, \%dual_solution);
}

__PACKAGE__->meta->make_immutable;

1;
