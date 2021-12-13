use strict;

if (int(@ARGV) != 2) {
    printf("Usage: perl reader.pl </path/to/device> <number of bytes> (%d)\n", int(@ARGV));
    exit 1;
}

my $INPUT = $ARGV[0];
open(my $fd, '<', $INPUT) or die "Cannot open ${INPUT}: $!";
binmode $fd;
my $n=0;
while($n++ < $ARGV[1]) {
    my $data;
    my $s;
    read($fd, $data, 4) == 4 or die "Error while reading ${INPUT}: $!";
    printf("%x", $data);
    printf(unpack("H$s", $data));
}
print("\n");
close($fd);