#!/usr/bin/perl
use strict;
use warnings;
use Spreadsheet::ParseExcel;
use Pod::Usage;
use Text::CSV;

my $excel = Spreadsheet::ParseExcel->new();

my $csv = Text::CSV->new({ binary => 1, eol => "\015\012" }) or die Text::CSV->error_diag;

for my $xls (@ARGV) {

    my $book = $excel->Parse($xls);

    my $last_sheet = $book->{SheetCount} - 1;

    for my $worksheet ( @{ $book->{Worksheet} }[ 0 .. $last_sheet ] ) {

        next
            if not defined $worksheet->{MaxRow}
            or not defined $worksheet->{MaxCol};

        my $filename = $worksheet->{Name} . '.csv';
        open my $fh, ">", $filename
            or die "Can open $filename to write: $!\n";

        my @row_nums = $worksheet->{MinRow} .. $worksheet->{MaxRow};
        my @col_nums = $worksheet->{MinCol} .. $worksheet->{MaxCol};

        for my $row ( @{ $worksheet->{Cells} }[ @row_nums ] ) {
            my @cellvalues = map {
                $_ = $_->Value() if ref $_;
                $_ = '' if not defined $_;
                $_;
            } @$row[ @col_nums ];
            $csv->print( $fh, \@cellvalues );
        }

        close $fh;
    }
}

__END__

=pod

=head1 NAME

excel2csv - dump all worksheets from an Excel file to CSV files

=head1 SYNOPSIS

F<excel2csv>
S<B<-h>>

F<excel2csv>
S<B<--man>>

F<rename>
S<B<[ -s ]>>
S<B<[ -S ]>>
S<B<[ -v ]>>
S<B<file.xls [ F<file2.xls> F<file3.xls> ... ]>>

=head1 DESCRIPTION

C<excel2csv> takes any number of Excel files on the command line, reads them, and dumps each worksheet therein to a separate CSV file, named after the worksheet.

=head1 ARGUMENTS

=over 4

=item B<-h>, B<--help>

See a synopsis.

=item B<--man>

Browse the manpage.

=back

=head1 OPTIONS

=over 4

=item B<-s>, B<--suffix>

The suffix for the CSV files generated. Default is C<.csv>.

=item B<-S>, B<--separator>

The field separator used in the generated CSV files. Default is C<;>.

=item B<-v>, B<--verbose>

Print additional information about the operations (not) executed.

=back

=head1 BUGS

CSV generation is fudged -- no quoting issues are taken into consideration. 
SV generation should rely on one of the modules available for the purpose instead.

=head1 AUTHORS

Drew Broadley, with contributions from Aristotle Pagaltzis, cleaned up and packaged by Leo Charre.

=head1 LICENSE

This package is free software; you can redistribute it and/or modify it under the same terms as Perl itself, i.e., under the terms of the "Artistic License" or the "GNU General Public License".

=head1 DISCLAIMER

This package is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the "GNU General Public License" for more details.

=cut

