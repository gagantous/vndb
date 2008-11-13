
package VNDB::DB::Producers;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw|dbProducerGet dbProducerMod dbProducerEdit|;


# options: results, page, id, search, char, rev
# what: changes, vn
sub dbProducerGet {
  my $self = shift;
  my %o = (
    results => 10,
    page => 1,
    what => '',
    @_
  );

  $o{search} =~ s/%//g if $o{search};

  my %where = (
    !$o{id} && !$o{rev} ? (
      'p.hidden = FALSE' => 1 ) : (),
    $o{id} ? (
      'p.id = ?' => $o{id} ) : (),
    $o{search} ? (
      '(pr.name ILIKE ? OR pr.original ILIKE ?)', [ '%%'.$o{search}.'%%', '%%'.$o{search}.'%%' ] ) : (),
    $o{char} ? (
      'LOWER(SUBSTR(pr.name, 1, 1)) = ?' => $o{char} ) : (),
    defined $o{char} && !$o{char} ? (
      '(ASCII(pr.name) < 97 OR ASCII(pr.name) > 122) AND (ASCII(pr.name) < 65 OR ASCII(pr.name) > 90)' => 1 ) : (),
    $o{rev} ? (
      'c.rev = ?' => $o{rev} ) : (),
  );

  my @join;
  push @join, $o{rev} ? 'JOIN producers p ON p.id = pr.pid' : 'JOIN producers p ON pr.id = p.latest';
  push @join, 'JOIN changes c ON c.id = pr.id' if $o{what} =~ /changes/ || $o{rev};
  push @join, 'JOIN users u ON u.id = c.requester' if $o{what} =~ /changes/;

  my $select = 'p.id, p.locked, p.hidden, pr.type, pr.name, pr.original, pr.website, pr.lang, pr.desc';
  $select .= ', c.added, c.requester, c.comments, p.latest, pr.id AS cid, u.username, c.rev' if $o{what} =~ /changes/;

  my($r, $np) = $self->dbPage(\%o, q|
    SELECT !s
      FROM producers_rev pr
      !s
      !W
      ORDER BY pr.name ASC|,
    $select, join(' ', @join), \%where,
  );

  if(@$r && $o{what} =~ /vn/) {
    my %r = map {
      $r->[$_]{vn} = [];
      ($r->[$_]{id}, $_)
    } 0..$#$r;

    push @{$r->[$r{$_->{pid}}]{vn}}, $_ for (@{$self->dbAll(q|
      SELECT MAX(vp.pid) AS pid, v.id, MAX(vr.title) AS title, MAX(vr.original) AS original, MIN(rr.released) AS date
        FROM releases_producers vp
        JOIN releases_rev rr ON rr.id = vp.rid
        JOIN releases r ON r.latest = rr.id
        JOIN releases_vn rv ON rv.rid = rr.id
        JOIN vn v ON v.id = rv.vid
        JOIN vn_rev vr ON vr.id = v.latest
        WHERE vp.pid IN(!l)
          AND v.hidden = FALSE
        GROUP BY v.id
        ORDER BY date|,
      [ keys %r ]
    )});
  }
  
  return wantarray ? ($r, $np) : $r;
}


# arguments: id, %options ->( hidden, locked )
sub dbProducerMod {
  my($self, $id, %o) = @_;
  $self->dbExec('UPDATE producers !H WHERE id = ?', {
      map { ($_.' = ?', int $o{$_}) } keys %o
    }, $id);
}


# arguments: id, %options ->( editsum + columns in producers_rev )
# returns: ( local revision, global revision )
sub dbProducerEdit {
  my($self, $pid, %o) = @_;

  my $c = $self->dbRow(q|
    INSERT INTO changes (type, requester, ip, comments, rev)
      VALUES (2, ?, ?, ?, (
        SELECT c.rev+1
        FROM changes c
        JOIN producers_rev pr ON pr.id = c.id
        WHERE pr.pid = ?
        ORDER BY c.id DESC
        LIMIT 1
      ))
      RETURNING id, rev|,
    $self->authInfo->{id}, $self->reqIP, $o{editsum}, $pid);

  $self->dbExec(q|
    INSERT INTO producers_rev (id, pid, name, original, website, type, lang, "desc")
      VALUES (!l)|,
    [ $c->{id}, $pid, @o{qw| name original website type lang desc|} ]
  );

  $self->dbExec(q|UPDATE producers SET latest = ? WHERE id = ?|, $c->{id}, $pid);
  return ($c->{rev}, $c->{id});
}


1;
