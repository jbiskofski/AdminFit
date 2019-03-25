package model::base;

use strict;
use global::sqlquote;
use Sort::Key 'rnkeysort';
use Data::Dumper::HTML 'dumper_html';
use Data::Dumper 'Dumper';
$Data::Dumper::Sortkeys = 1;
use Clone 'clone';

sub dbh {

	my $x = shift;
	return $x->{dbh};

}

sub get_quote {

	my %quote;
	tie( %quote, 'global::sqlquote' );
	return \%quote;

}

sub get_log_tagger {

	my %tagger;
	tie( %tagger, 'global::logtagger' );
	return \%tagger;

}

sub generate_in {

	my ( $x, %pp ) = @_;

	return '' if ( ref( $pp{items} ) ne 'ARRAY' || !scalar( @{ $pp{items} } ) ) && !$pp{empty_as_false};

	my $where_or_and = $pp{where}  ? 'WHERE'  : 'AND';
	my $in           = $pp{negate} ? 'NOT IN' : 'IN';

	$where_or_and = '' if $pp{no_and};

	return "$where_or_and FALSE " if ( ref( $pp{items} ) ne 'ARRAY' || !scalar( @{ $pp{items} } ) );

	my %unique = map { $_ => 1 } @{ $pp{items} };
	return unless scalar keys %unique;

	my $q = __PACKAGE__->get_quote();

	my $table_sql = '';
	if ( !defined( $pp{no_table} ) || !$pp{no_table} ) {
		$table_sql = "$pp{table}.";
	}
	my $sql = $pp{just_items} ? '(' : "$where_or_and $table_sql$pp{field} $in (";

	foreach my $ii ( keys %unique ) {
		$sql .= $q->{$ii} . ',';
	}

	chop($sql);
	$sql .= ') ';

	return $sql;

}

sub generate_sql_where {

	my ( $x, %pp ) = @_;

	my $where;

	my $q = $x->get_quote();

	foreach my $kk ( keys %{ $pp{where} } ) {
		my $field = $pp{ignore_case} ? "UPPER($kk)" : $kk;
		my $value = $pp{ignore_case} ? "UPPER($q->{$pp{where}->{$kk}})" : $q->{ $pp{where}->{$kk} };
		$where .= " AND $field = $value ";
	}

	if ( ref( $pp{or} ) eq 'HASH' ) {
		$where .= $x->_get_or_sql_string( $pp{or}, $pp{table} );
	}

	if ( ref( $pp{or} ) eq 'ARRAY' ) {

		my $or_string = 'AND (';

		foreach my $or_hash ( @{ $pp{or} } ) {

			my $or_where_string .= '( ';

			foreach my $kk ( keys %{$or_hash} ) {
				$or_where_string .= " $kk = $q->{$or_hash->{$kk}} AND ";
			}

			if ( length($or_where_string) > 5 ) {
				$or_where_string =~ s/^(.*) AND $/$1/;
				$or_where_string .= ')';
			}

			$or_string .= $or_where_string . ' OR ';

		}

		if ( length($or_string) > 5 ) {
			$or_string =~ s/^(.*) OR $/$1/;
			$or_string .= ')';
			$where .= $or_string;
		}

	}

	foreach my $kk ( keys %{ $pp{not} } ) {
		$where .= " AND $kk != $q->{$pp{not}->{$kk}} ";
	}

	if ( $pp{alpha} ) {
		foreach my $kk ( keys %{ $pp{alpha} } ) {
			$where .= " AND UNACCENT_STRING($kk) ILIKE $q->{$pp{alpha}->{$kk} . '%' } ";
		}
	}

	foreach my $kk ( keys %{ $pp{like} } ) {
		$where .= " AND $kk ILIKE $q->{'%' . $pp{like}->{$kk} . '%'} ";
	}

	foreach my $kk ( keys %{ $pp{match} } ) {
		$where .= " AND $kk ~ $q->{$pp{match}->{$kk}} ";
	}

	foreach my $kk ( keys %{ $pp{gt} } ) {
		$where .= " AND $kk > $q->{$pp{gt}->{$kk}} ";
	}

	foreach my $kk ( keys %{ $pp{ge} } ) {
		$where .= " AND $kk >= $q->{$pp{ge}->{$kk}} ";
	}

	foreach my $kk ( keys %{ $pp{lt} } ) {
		$where .= " AND $kk < $q->{$pp{lt}->{$kk}} ";
	}

	foreach my $kk ( keys %{ $pp{le} } ) {
		$where .= " AND $kk <= $q->{$pp{le}->{$kk}} ";
	}

	foreach my $kk ( @{ $pp{is_null} } ) {
		$where .= " AND $kk IS NULL ";
	}

	foreach my $kk ( @{ $pp{not_null} } ) {
		$where .= " AND $kk IS NOT NULL ";
	}

	if ( $pp{in} ) {
		if ( ref( $pp{in} ) eq 'ARRAY' ) {
			foreach my $in ( @{ $pp{in} } ) {
				$where .= $x->generate_in( %{$in} ) . "\n";
			}
		}
		else {
			$where .= $x->generate_in( %{ $pp{in} } );
		}
	}

	if ( $pp{not_in} ) {
		$where .= $x->generate_in( %{ $pp{not_in} }, negate => 1 );
	}

	if ( $pp{between} ) {
		$where .= $x->generate_between(
			table => $pp{between}->{table},
			field => $pp{between}->{field},
			high  => $pp{between}->{high},
			low   => $pp{between}->{low}
		);
	}

	if ( $pp{several_and_or} ) {
		$where .= $x->generate_several_group_and_or( %{ $pp{several_and_or} } );
	}

	return $where;

}

sub optimize {

	my ( $x, $sql_query ) = @_;

	my $all_lines = $sql_query;
	$all_lines =~ s/\s+/ /g;
	$sql_query = global::standard->cutcut( $sql_query, 1 ) if $all_lines =~ /CUTCUT/;

	my @lines;

	my $sth = $x->dbh()->prepare( 'EXPLAIN ' . $sql_query ) || die($DBI::errstr);
	$sth->execute() || die($DBI::errstr);
	while ( my $line = $sth->fetchrow() ) {
		next unless $line =~ /Seq Scan/;
		$line =~ s/\s+/ /g;
		$line =~ s/\-\>//g;
		$line =~ s/^\s+//;
		$line =~ /cost=\d+\.\d+\.\.(\d+\.\d+)/;
		my $cost = $1;
		push @lines, { cost => $cost, line => $line };
	}
	$sth->finish();

	my @sorted = rnkeysort { $_->{cost} } @lines;

	if ( $ENV{SERVER_PROTOCOL} && $ENV{SERVER_PROTOCOL} =~ /HTTP/ ) {
		my $data = dumper_html( \@sorted );
		global::standard->shout( $data, $sql_query );
	}
	else {
		print Dumper( \@sorted );
		die $sql_query;
	}

}

sub update {

	my ( $x, %pp ) = @_;

	my @update_value_pairs;

	my $q = $x->get_quote();

	foreach my $field ( sort keys %{ $pp{update} } ) {
		next if $field =~ /^_.*/;
		my $value;
		if ( ref( $pp{update}->{$field} ) eq 'ARRAY' ) {
			if ( scalar( @{ $pp{update}->{$field} } ) ) {
				$value = 'ARRAY[' . join( ',', map { $q->{$_} } @{ $pp{update}->{$field} } ) . ']';
			}
			else {
				$value = 'NULL';
			}
		}
		elsif ( $pp{update}->{$field} eq 'NULL' ) {
			$value = 'NULL';
		}
		elsif ( $field eq 'ts_vector' ) {
			my $ts_string = global::standard->strip_html( global::standard->unaccent( $pp{update}->{$field} ) );
			$ts_string =~ s/\s+/ /g;
			$ts_string =~ s/\s+$//;
			$value = "TO_TSVECTOR('english', UNACCENT_STRING($q->{$ts_string}))";
		}
		elsif ( $field =~ /date/ && $pp{update}->{$field} =~ /NOW().*/ ) {
			$value = $pp{update}->{$field};
		}
		elsif ( $pp{update}->{$field} =~ 'TOGGLE()' ) {
			$value = "NOT $field";
		}
		else {
			$value = $q->{ $pp{update}->{$field} };
		}

		# $value = $if ( $field =~ /date/ && $pp{update}->{$field} eq 'now()' );
		push( @update_value_pairs, "$field = $value" );
	}

	my $update_values = join( ',', @update_value_pairs );

	my @where_value_pairs;

	foreach my $field ( sort keys %{ $pp{where} } ) {
		next if $field =~ /^_.*/;
		push( @where_value_pairs, "$field = $q->{$pp{where}->{$field}}" );
	}

	my $where_values = join( ' AND ', @where_value_pairs );
	$where_values = " AND ($where_values) " if $where_values;

	my $in = $x->generate_in( %{ $pp{in} } ) if $pp{in};
	my $not_in = $x->generate_in( %{ $pp{not_in} }, negate => 1 ) if $pp{not_in};

	my $sql = qq {
	UPDATE	$pp{table}
	SET	$update_values
	WHERE	TRUE
	$where_values
	$in
	$not_in
	};

	$x->optimize($sql)            if $ENV{DEBUG} eq 'optimize';
	die($sql)                     if $ENV{DEBUG} eq 'die';
	print($sql)                   if $ENV{DEBUG} eq 'print';
	global::standard->log($sql)   if $ENV{DEBUG} eq 'log';
	global::standard->shout($sql) if $ENV{DEBUG} eq 'shout';

	my $sth = $x->{dbh}->prepare($sql) || die $DBI::errstr;
	$sth->execute() || die $DBI::errstr;
	my $rows_affected = $sth->rows();
	$sth->finish();

	return $rows_affected;

}

sub delete {

	my ( $x, %pp ) = @_;

	my $sql_where = $x->generate_sql_where(%pp);
	return undef unless $sql_where;

	my $sql = "DELETE FROM $pp{table} WHERE TRUE $sql_where";

	$x->optimize($sql)            if $ENV{DEBUG} eq 'optimize';
	die($sql)                     if $ENV{DEBUG} eq 'die';
	print($sql)                   if $ENV{DEBUG} eq 'print';
	global::standard->log($sql)   if $ENV{DEBUG} eq 'log';
	global::standard->shout($sql) if $ENV{DEBUG} eq 'shout';

	my $sth = $x->dbh()->prepare($sql) || die $DBI::errstr;
	$sth->execute() || die $DBI::errstr;
	$sth->finish();

}

sub upsert {

	my ( $x, %pp ) = @_;

	my %conflict_field_skip = map { $_ => 1 } @{ $pp{conflict_fields} };

	if ( $pp{try_update_first} && scalar keys %conflict_field_skip ) {

		my %update_where;
		my $update = clone( $pp{insert} );

		foreach my $key ( keys %conflict_field_skip ) {
			next unless $pp{insert}->{$key};
			$update_where{$key} = $pp{insert}->{$key};
			delete $update->{$key};
		}

		if ( scalar keys %update_where ) {
			my $rows_affected = $x->update(
				update => $update,
				where  => \%update_where,
				table  => $pp{table},
			);
			return $rows_affected if $rows_affected;
		}

	}

	my @insert_fields;
	my @insert_values;
	my @update_value_pairs;

	my $q = $x->get_quote();

	foreach my $field ( sort keys %{ $pp{insert} } ) {

		next if $conflict_field_skip{$field} && !defined( $pp{insert}->{$field} );
		next if $field =~ /^_.*/;

		my $value;

		if ( ref( $pp{insert}->{$field} ) eq 'ARRAY' ) {
			if ( scalar( @{ $pp{insert}->{$field} } ) ) {
				$value = 'ARRAY[' . join( ',', map { $q->{$_} } @{ $pp{insert}->{$field} } ) . ']';
			}
			else {
				$value = 'NULL';
			}
		}
		elsif ( $pp{insert}->{$field} eq 'NULL' ) {
			$value = 'NULL';
		}
		elsif ( $field eq 'ts_vector' ) {
			my $ts_string = global::standard->strip_html( global::standard->unaccent( $pp{insert}->{$field} ) );
			$ts_string =~ s/\s+/ /g;
			$ts_string =~ s/\s+$//;
			$value = "TO_TSVECTOR('english', UNACCENT_STRING($q->{$ts_string}))";
		}
		elsif ( $field =~ /date/ && $pp{insert}->{$field} =~ /NOW().*/ ) {
			$value = $pp{insert}->{$field};
		}
		else {
			$value = $q->{ $pp{insert}->{$field} };
		}

		push @insert_fields, $field;
		push @insert_values, $value;

		push( @update_value_pairs, "$field = EXCLUDED.$field" ) unless $conflict_field_skip{$field};

	}

	my $update_values   = join( ',', @update_value_pairs );
	my $fields          = join( ',', @insert_fields );
	my $values          = join( ',', @insert_values );
	my $conflict_fields = join( ',', sort keys %conflict_field_skip );

	my %insert_field_unique = map { $_ => 1 } @insert_fields;
	my $conflict_field_skip_signature = join( '', sort keys %conflict_field_skip );
	my $insert_field_signature        = join( '', sort keys %insert_field_unique );

	my $sql = qq {
	INSERT 	INTO $pp{table} ( $fields )
	VALUES	( $values )
	ON CONFLICT ( $conflict_fields )
	};

	if ( $conflict_field_skip_signature eq $insert_field_signature ) {
		$sql .= ' DO NOTHING ';
	}
	else {
		$sql .= " DO UPDATE SET $update_values ";
	}

	$x->optimize($sql)            if $ENV{DEBUG} eq 'optimize';
	die($sql)                     if $ENV{DEBUG} eq 'die';
	print($sql)                   if $ENV{DEBUG} eq 'print';
	global::standard->log($sql)   if $ENV{DEBUG} eq 'log';
	global::standard->shout($sql) if $ENV{DEBUG} eq 'shout';

	my $sth = $x->{dbh}->prepare($sql) || die $DBI::errstr;
	$sth->execute() || die $DBI::errstr;
	my $rows_affected = $sth->rows();
	$sth->finish();

	return $rows_affected;

}

sub insert {

	my ( $x, %pp ) = @_;

	die 'WRONG USAGE UN MODEL::BASE->INSERT()' unless $pp{table} && $pp{insert};

	if ( !$pp{insert}->{id} && !$pp{no_id_column} ) {
		$pp{insert}->{id} = global::standard->uuid();
	}

	my $q = $x->get_quote();

	my $fields;
	my $insert;

	foreach my $field ( sort keys %{ $pp{insert} } ) {
		next if $field =~ /^_.*/;
		$fields .= "$field,";
		if ( ref( $pp{insert}->{$field} ) eq 'ARRAY' ) {
			$insert .= 'ARRAY[' . join( ',', map { $q->{$_} } @{ $pp{insert}->{$field} } ) . '],';
		}
		elsif ( $pp{insert}->{$field} eq 'NULL' ) {
			$insert .= 'NULL,';
		}
		elsif ( uc( $pp{insert}->{$field} ) eq 'NOW()'
			|| substr( uc( $pp{insert}->{$field} ), 0, 10 ) eq 'DATE_PART(' )
		{
			# dont quote this
			$insert .= $pp{insert}->{$field} . ',';
		}
		else {
			$insert .= $q->{ $pp{insert}->{$field} } . ',';
		}
	}

	$fields =~ s/ /_/g;
	$fields =~ s/^(.*),$/$1/;
	chop($insert);

	my $sql = "INSERT INTO $pp{table} ($fields) VALUES ($insert)";

	$x->optimize($sql)            if $ENV{DEBUG} eq 'optimize';
	die($sql)                     if $ENV{DEBUG} eq 'die';
	print($sql)                   if $ENV{DEBUG} eq 'print';
	global::standard->log($sql)   if $ENV{DEBUG} eq 'log';
	global::standard->shout($sql) if $ENV{DEBUG} eq 'shout';

	my $sth = $x->dbh->prepare($sql) || die($DBI::errstr);
	$sth->execute() || die($DBI::errstr);
	$sth->finish();

	return $pp{insert}->{id};

}

sub get {

	my ( $x, %pp ) = @_;

	my $sql_where = $x->generate_sql_where(%pp);
	return undef unless $sql_where;

	my $sql = "SELECT * FROM $pp{table} WHERE TRUE $sql_where";

	$x->optimize($sql)            if $ENV{DEBUG} eq 'optimize';
	die($sql)                     if $ENV{DEBUG} eq 'die';
	print($sql)                   if $ENV{DEBUG} eq 'print';
	global::standard->log($sql)   if $ENV{DEBUG} eq 'log';
	global::standard->shout($sql) if $ENV{DEBUG} eq 'shout';

	my $sth = $x->dbh->prepare($sql) || die($DBI::errstr);
	$sth->execute() || die($DBI::errstr);
	my $item = $sth->fetchrow_hashref();
	$sth->finish();

	return $item;

}

sub count {

	my ( $x, %pp ) = @_;

	my $sql_where = $x->generate_sql_where(%pp);
	my $sql = "SELECT COUNT(*) FROM $pp{table} WHERE TRUE $sql_where";

	$x->optimize($sql)            if $ENV{DEBUG} eq 'optimize';
	die($sql)                     if $ENV{DEBUG} eq 'die';
	print($sql)                   if $ENV{DEBUG} eq 'print';
	global::standard->log($sql)   if $ENV{DEBUG} eq 'log';
	global::standard->shout($sql) if $ENV{DEBUG} eq 'shout';

	my $sth = $x->dbh->prepare($sql) || die($DBI::errstr);
	$sth->execute() || die($DBI::errstr);
	my $count = $sth->fetchrow();
	$sth->finish();

	return $count;

}

sub _get_or_sql_string {

	my ( $x, $or_hash, $table ) = @_;

	my $q  = $x->get_quote();
	my $or = 'AND (';

	foreach my $kk ( keys %{$or_hash} ) {
		my $field = ( $kk =~ /\./ ) ? $kk : "$table.$kk";
		$or .= "$field = $q->{$or_hash->{$kk}} OR ";
	}

	if ( length($or) > 5 ) {
		$or =~ s/^(.*) OR $/$1/;
		$or .= ')';
	}

	return $or;

}

sub exists_not_me {

	my ( $x, %pp ) = @_;

	my $q = $x->get_quote();

	my $sql = "SELECT COUNT(*) FROM $pp{table} WHERE TRUE ";
	$sql .= " AND id != $q->{$pp{id}} " if $pp{id};

	foreach my $kk ( keys %{ $pp{where} } ) {
		$sql .= " AND $kk = $q->{$pp{where}->{$kk}} ";
	}

	my $sth = $x->dbh()->prepare($sql) || die $DBI::errstr;
	$sth->execute() || die $DBI::errstr;

	my $exists = $sth->fetchrow();

	$sth->finish();

	return $exists;

}

sub bulk_insert {

	my ( $x, %pp ) = @_;

	return undef unless scalar( @{ $pp{items} } );

	my $insert_sql = "INSERT INTO $pp{table} (";

	foreach my $key ( sort keys %{ $pp{items}->[0] } ) {
		$insert_sql .= "$key,";
	}
	chop($insert_sql);
	$insert_sql .= ') VALUES (';

	foreach my $key ( sort keys %{ $pp{items}->[0] } ) {
		$insert_sql .= '?,';
	}

	chop($insert_sql);
	$insert_sql .= ')';

	my $insert_handle = $x->dbh()->prepare_cached($insert_sql) || die( $DBI::errstr . $insert_sql );

	foreach my $item ( @{ $pp{items} } ) {

		my @values;

		foreach my $key ( sort keys %{$item} ) {
			push( @values, $item->{$key} );
		}

		$insert_handle->execute(@values) || global::standard->inspect( 'BULK-INSERT-ERROR!', $DBI::errstr, $insert_sql, @values );

	}

	$insert_handle->finish();

	return 1;

}

1;
