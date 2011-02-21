
package VNDB::DB::Chars;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw|dbCharGet dbCharRevisionInsert dbCharImageId|;


# options: id rev traitspoil trait_inc trait_exc what results page
# what: extended traits changes
sub dbCharGet {
  my $self = shift;
  my %o = (
    page => 1,
    results => 10,
    what => '',
    traitspoil => 0,
    @_
  );

  my %where = (
    !$o{id} && !$o{rev} ? ( 'c.hidden = FALSE' => 1 ) : (),
    $o{id}  ? ( 'c.id = ?'  => $o{id} ) : (),
    $o{rev} ? ( 'h.rev = ?' => $o{rev} ) : (),
    $o{trait_inc} ? (
      'c.id IN(SELECT cid FROM traits_chars WHERE tid IN(!l) AND spoil <= ? GROUP BY cid HAVING COUNT(tid) = ?)',
      [ ref $o{trait_inc} ? $o{trait_inc} : [$o{trait_inc}], $o{traitspoil}, ref $o{trait_inc} ? $#{$o{trait_inc}}+1 : 1 ]) : (),
    $o{trait_exc} ? (
      'c.id NOT IN(SELECT cid FROM traits_chars WHERE tid IN(!l))' => [ ref $o{trait_exc} ? $o{trait_exc} : [$o{trait_exc}] ] ) : (),
  );

  my @select = (qw|c.id cr.name cr.original|, 'cr.id AS cid');
  push @select, qw|c.hidden c.locked cr.alias cr.desc cr.image cr.b_month cr.b_day cr.s_bust cr.s_waist cr.s_hip cr.height cr.weight cr.bloodt| if $o{what} =~ /extended/;
  push @select, qw|h.requester h.comments c.latest u.username h.rev h.ihid h.ilock|, "extract('epoch' from h.added) as added" if $o{what} =~ /changes/;

  my @join;
  push @join, $o{rev} ? 'JOIN chars c ON c.id = cr.cid' : 'JOIN chars c ON cr.id = c.latest';
  push @join, 'JOIN changes h ON h.id = cr.id' if $o{what} =~ /changes/ || $o{rev};
  push @join, 'JOIN users u ON u.id = h.requester' if $o{what} =~ /changes/;

  my($r, $np) = $self->dbPage(\%o, q|
    SELECT !s
      FROM chars_rev cr
      !s
      !W|,
    join(', ', @select), join(' ', @join), \%where
  );

  if(@$r && $o{what} =~ /traits/) {
    my %r = map {
      $_->{traits} = [];
      ($_->{cid}, $_->{traits})
    } @$r;

    push @{$r{ delete $_->{cid} }}, $_ for (@{$self->dbAll(q|
      SELECT ct.cid, ct.tid, ct.spoil, t.name, t."group", tg.name AS groupname
        FROM chars_traits ct
        JOIN traits t ON t.id = ct.tid
        LEFT JOIN traits tg ON tg.id = t."group"
       WHERE cid IN(!l)|, [ keys %r ]
    )});
  }

  return wantarray ? ($r, $np) : $r;
}


# Updates the edit_* tables, used from dbItemEdit()
# Arguments: { columns in chars_rev + traits },
sub dbCharRevisionInsert {
  my($self, $o) = @_;

  my %set = map exists($o->{$_}) ? (qq|"$_" = ?|, $o->{$_}) : (),
    qw|name original alias desc image b_month b_day s_bust s_waist s_hip height weight bloodt|;
  $self->dbExec('UPDATE edit_char !H', \%set) if keys %set;

  if($o->{traits}) {
    $self->dbExec('DELETE FROM edit_char_traits');
    $self->dbExec('INSERT INTO edit_char_traits (tid, spoil) VALUES (?,?)', $_->[0],$_->[1]) for (@{$o->{traits}});
  }
}


# fetches an ID for a new image
sub dbCharImageId {
  return shift->dbRow("SELECT nextval('charimg_seq') AS ni")->{ni};
}


1;

