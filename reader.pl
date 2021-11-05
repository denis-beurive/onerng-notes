use strict;

open(my $fd, '<', '/dev/ttyACM0') or die "Cannot open /dev/ttyACM0: $!";
binmode $fd;
my $n=0;
while($n++ < $ARGV[0]) {
    my $data;
    my $s;
    read($fd, $data, 4) == 4 or die "Error while reading /dev/ttyACM0: $!";
    printf("%x", $data);
    print(unpack("H$s", $data));
}
close($fd);